const CLI_HELP = """
Plain Apriori from the original paper (Julia, no FIM library).
Usage: julia --project=. bin/apriori.jl --input INPUT [--output OUTPUT]
       (--minsup RATIO | --min-count COUNT) [--counter scan|hash-tree] [--trace]
       [--explain | --explain-file PATH] [--explain-limit N]
       [--report-dir PATH] [--warmup N] [--quiet]

--minsup     Minimum support ratio in (0, 1], e.g. 0.5
--min-count  Minimum absolute transaction count >= 1
--counter    scan or hash-tree (default: hash-tree)
--trace      Print per-level C_k / L_k statistics to stderr
--explain    Explain the actual Apriori steps in Vietnamese on stderr
--explain-file PATH  Write the explanation as UTF-8 to a separate file
--explain-limit N    Maximum detail lines (positive integer; default: 5000)
--report-dir PATH   New directory for this run's immutable report bundle
--warmup N          Untraced mining runs before the measured run (default: 0)
--quiet             Suppress success messages; reports are still written
--help       Show this help
Reports default to output/runs/<dataset>-N/ or <output-parent>/runs/<dataset>-N/.
Without --output, itemsets.txt is written directly inside the report directory.
Output parent must exist unless it is inside the new report directory.
"""

function parse_cli(args)
    values = Dict{String,String}()
    trace = false
    explain = false
    quiet = false
    index = 1
    while index <= length(args)
        option = args[index]
        if option == "--trace"
            trace && throw(ArgumentError("duplicate --trace"))
            trace = true
            index += 1
        elseif option == "--explain"
            explain && throw(ArgumentError("duplicate --explain"))
            explain = true
            index += 1
        elseif option == "--quiet"
            quiet && throw(ArgumentError("duplicate --quiet"))
            quiet = true
            index += 1
        elseif option in ("--input", "--output", "--minsup", "--min-count", "--counter",
                          "--explain-file", "--explain-limit", "--report-dir", "--warmup")
            haskey(values, option) && throw(ArgumentError("duplicate $option"))
            index < length(args) || throw(ArgumentError("missing value for $option"))
            values[option] = args[index + 1]
            index += 2
        else
            throw(ArgumentError("unknown option: $option"))
        end
    end
    haskey(values, "--input") || throw(ArgumentError("required option: --input"))
    haskey(values, "--minsup") == haskey(values, "--min-count") &&
        throw(ArgumentError("provide exactly one of --minsup or --min-count"))
    return values, trace, explain, quiet
end

function cli_same_path(left, right)
    a, b = cli_resolved_path(left), cli_resolved_path(right)
    Sys.iswindows() && ((a, b) = (lowercase(a), lowercase(b)))
    return a == b || (ispath(left) && ispath(right) && samefile(left, right))
end

function cli_inside(path, directory)
    candidate, parent = cli_resolved_path(path), cli_resolved_path(directory)
    Sys.iswindows() && ((candidate, parent) = (lowercase(candidate), lowercase(parent)))
    relative = relpath(candidate, parent)
    return relative != "." && !isabspath(relative) &&
           first(splitpath(relative)) != ".."
end

function check_cli_report_paths(report_dir, input, output, explanation_path)
    destinations = isnothing(explanation_path) ? [output] : [output, explanation_path]
    for destination in destinations
        islink(destination) && !ispath(destination) &&
            throw(ArgumentError("destination is a dangling symlink: $destination"))
        cli_same_path(destination, report_dir) &&
            throw(ArgumentError("destination must be a file, not the report directory"))
        cli_inside(report_dir,destination) &&
            throw(ArgumentError("report directory cannot be inside a destination file path"))
        isdir(destination) && throw(ArgumentError("destination is a directory: $destination"))
        if !isdir(dirname(abspath(destination))) && !cli_inside(destination, report_dir)
            throw(ArgumentError("destination parent directory must already exist: $destination"))
        end
    end
    paths = isnothing(explanation_path) ? [input, output] : [input, output, explanation_path]
    for name in ("report.txt", "timings.csv", "metadata.toml", "itemsets.txt", "trace.txt")
        artifact = joinpath(report_dir, name)
        for (index, path) in enumerate(paths)
            allowed = name == "itemsets.txt" && index == 2 ||
                      name == "trace.txt" && index == 3
            if (cli_same_path(path, artifact) && !allowed) || cli_inside(path, artifact)
                throw(ArgumentError("path conflicts with reserved report artifact $name"))
            end
        end
    end
    # Check ancestors without creating them, including a file where a directory
    # would be needed. The final directory itself is claimed with mkdir below.
    ancestor = dirname(abspath(report_dir))
    while !ispath(ancestor)
        ancestor = dirname(ancestor)
    end
    isdir(ancestor) || throw(ArgumentError("report parent is not a directory: $ancestor"))
    return nothing
end

# Resolve existing ancestors too, so an output that does not yet exist is
# still compared correctly when its parent is reached through a symlink.
function cli_resolved_path(path)
    absolute = normpath(abspath(path))
    ispath(absolute) && return realpath(absolute)
    parent = dirname(absolute)
    parent == absolute && return absolute
    return joinpath(cli_resolved_path(parent), basename(absolute))
end

function check_cli_paths(paths)
    resolved = cli_resolved_path.(paths)
    Sys.iswindows() && (resolved = lowercase.(resolved))
    for left in eachindex(paths), right in (left + 1):length(paths)
        same_path = resolved[left] == resolved[right]
        same_existing = ispath(paths[left]) && ispath(paths[right]) &&
                        samefile(paths[left], paths[right])
        (same_path || same_existing) &&
            throw(ArgumentError("input, output and explanation must not refer to the same file"))
        (cli_inside(paths[left], paths[right]) || cli_inside(paths[right], paths[left])) &&
            throw(ArgumentError("a file destination cannot also be another path's parent directory"))
    end
    return nothing
end

function main(args=ARGS; out=stdout, err=stderr)
    if args == ["--help"]
        print(out, CLI_HELP)
        return 0
    end
    try
        values, trace, explain, quiet = parse_cli(args)
        cli_start = time_ns()
        started = Dates.now(Dates.UTC)
        run_id = Dates.format(started, dateformat"yyyymmddTHHMMSSsss") * "_" * string(uuid4())
        input = abspath(values["--input"])
        requested_output = haskey(values, "--output") ? abspath(values["--output"]) : nothing
        explanation_path = haskey(values, "--explain-file") ? abspath(values["--explain-file"]) : nothing
        output_for(dir) = something(requested_output, joinpath(dir, "itemsets.txt"))
        function validate_paths(dir)
            output = output_for(dir)
            paths = [input, output]
            !isnothing(explanation_path) && push!(paths, explanation_path)
            check_cli_paths(paths)
            check_cli_report_paths(dir, input, output, explanation_path)
        end
        min_count = nothing
        if haskey(values, "--min-count")
            min_count = tryparse(Int, values["--min-count"])
            isnothing(min_count) && throw(ArgumentError("--min-count must be an integer"))
        end
        limit = tryparse(Int, get(values, "--explain-limit", "5000"))
        isnothing(limit) && throw(ArgumentError("--explain-limit must be a positive integer"))
        explanation = ExplainTrace(err; limit)
        warmup = tryparse(Int, get(values, "--warmup", "0"))
        (isnothing(warmup) || warmup < 0) &&
            throw(ArgumentError("--warmup must be a nonnegative integer"))
        min_support = get(values, "--minsup", nothing)
        counter = get(values, "--counter", "hash-tree")
        # Validate all input and mining options before opening either destination.
        read_start = time_ns()
        # Parse and fingerprint the same immutable byte snapshot. A file
        # changed after this read cannot be relabelled as the mined input.
        input_bytes=read(input)
        input_sha256=bytes2hex(sha256(input_bytes))
        rows = read_spmf(IOBuffer(input_bytes))
        read_ns = time_ns() - read_start
        support_threshold(length(rows), min_support, min_count)
        counter_mode(counter)
        source_sha256=implementation_fingerprint()
        # All validation has finished before any destination is created/opened.
        if haskey(values, "--report-dir")
            report_dir = abspath(values["--report-dir"])
            (ispath(report_dir) || islink(report_dir)) &&
                throw(ArgumentError("report directory must not already exist: $report_dir"))
            validate_paths(report_dir)
            mkpath(dirname(report_dir))
            mkdir(report_dir)
        else
            parent = isnothing(requested_output) ? abspath("output") : dirname(requested_output)
            stem = splitext(basename(input))[1]
            report_dir = numbered_run_directory(joinpath(parent, "runs"), stem; validate=validate_paths)
        end
        output = output_for(report_dir)
        for destination in (output, explanation_path)
            if !isnothing(destination) && cli_inside(destination, report_dir)
                mkpath(dirname(destination))
            end
        end
        warmup_ns = UInt64(0)
        if warmup > 0
            warmup_start = time_ns()
            for _ in 1:warmup
                mine(rows; min_support, min_count, counter)
            end
            warmup_ns = time_ns() - warmup_start
        end
        result = if !isnothing(explanation_path)
            open(explanation_path, "w") do stream
                mine(rows; min_support, min_count, counter,
                     explain=ExplainTrace(stream; limit))
            end
        else
            mine(rows; min_support, min_count, counter,
                 explain=explain ? explanation : nothing)
        end
        write_start = time_ns()
        write_spmf(result.itemsets, output)
        write_ns = time_ns() - write_start
        if trace
            println(err, "transactions=", result.transaction_count, " min_count=",
                    result.min_support_count, " itemsets=", length(result.itemsets))
            for level in result.levels
                println(err, "k=", level.size, " candidates=", level.candidates,
                        " frequent=", level.frequent)
            end
        end
        cli_ns = time_ns() - cli_start
        metadata = Dict{String,Any}(
            "run_id" => run_id,
            "started_utc" => Dates.format(started, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
            "input_path" => input, "minsup_argument" => get(values, "--minsup", ""),
            "input_sha256" => input_sha256, "input_bytes" => length(input_bytes),
            "input_hash_scope" => "exact_bytes_parsed", "implementation_sha256" => source_sha256,
            "counter" => counter, "warmup_runs" => warmup,
            "explain_enabled" => explain || !isnothing(explanation_path), "explain_limit" => limit)
        write_run_report(report_dir, result; metadata, output_path=output, explanation_path,
                         read_ns, write_ns, warmup_ns, cli_ns)
        if !quiet
            println(out, "Report: ", report_dir)
            println(out, "MiningMs: ", result.mining_ns / 1_000_000)
        end
        return 0
    catch exc
        if exc isa ArgumentError || exc isa SystemError || exc isa Base.IOError
            print(err, "apriori: error: ")
            showerror(err, exc)
            println(err)
            return 2
        end
        rethrow()
    end
end
