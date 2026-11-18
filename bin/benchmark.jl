using SHA, Dates, Printf, FrequentItemsetMining

const ROOT = dirname(@__DIR__)
const SIZES = (10, 25, 50, 75, 100)
const ENGINES = ("scan", "hash-tree", "spmf")
const SEED = 42
const PROTOCOL = "apriori-cold-v1"
filehash(path) = open(io -> bytes2hex(sha256(io)), path)
percent(bp) = string(bp ÷ 100, bp % 100 == 0 ? "" : "." * rstrip(lpad(string(bp % 100), 2, '0'), '0'))

function write_samples(input, parent)
    rows = read_spmf(input)
    length(rows) >= 10 || error("At least 10 transactions required")
    ranks = sortperm([bytes2hex(sha256("apriori-v1|$SEED|$i")) for i in eachindex(rows)])
    samples = Dict{Int,NamedTuple}()
    for pct in SIZES
        indices = sort(ranks[1:fld(length(rows) * pct, 100)])
        path = joinpath(parent, "sample-$pct.txt")
        items = Set{Int}()
        entries = 0
        open(path, "w") do io
            for i in indices
                println(io, join(rows[i], ' '))
                union!(items, rows[i])
                entries += length(rows[i])
            end
        end
        samples[pct] = (;path, n=length(indices), sha=filehash(path),
            idsha=bytes2hex(sha256(join(indices, "\n") * "\n")),
            distinct=length(items), mean_width=entries / length(indices))
    end
    return samples
end

function patterns(path, minimum, n)
    result = Dict{String,Int}()
    open(path) do io
      for line in eachline(io)
        (isempty(strip(line)) || startswith(line, '@')) && continue
        parts = split(line, "#SUP:")
        length(parts) == 2 || error("Invalid itemset in $path")
        items = sort(parse.(Int, split(parts[1])))
        count = parse(Int, strip(parts[2]))
        key = join(items, ' ')
        isempty(items) && error("Empty itemset in $path")
        allunique(items) && !haskey(result, key) || error("Duplicate item or itemset in $path")
        minimum <= count <= n || error("Invalid support in $path: $line")
        result[key] = count
      end
    end
    return result
end

function signature(result)
    io = IOBuffer()
    for key in sort!(collect(keys(result)))
        println(io, key, " #SUP: ", result[key])
    end
    return bytes2hex(sha256(take!(io)))
end

function compare(ref, got)
    missing = count(k -> !haskey(got, k), keys(ref))
    extra = count(k -> !haskey(ref, k), keys(got))
    wrong = count(k -> haskey(got, k) && got[k] != ref[k], keys(ref))
    total = length(ref) + extra
    return (;missing, extra, wrong, match_pct=total == 0 ? 100.0 : 100 * (total-missing-extra-wrong)/total)
end

struct WinMemory
    size::UInt32
    faults::UInt32
    peak_ws::UInt
    remaining::NTuple{7,UInt}
end

function peak_working_set(handle)
    info = Ref(WinMemory(sizeof(WinMemory), 0, 0, ntuple(_ -> UInt(0), 7)))
    ok = ccall((:GetProcessMemoryInfo, "psapi"), stdcall, Int32,
        (Ptr{Cvoid}, Ref{WinMemory}, UInt32), handle, info, sizeof(WinMemory))
    return ok == 0 ? 0 : Int(info[].peak_ws)
end

function timed_process(command, logpath)
    timerfile = logpath * ".rss"
    measured = if Sys.iswindows()
        command
    elseif Sys.islinux() && isfile("/usr/bin/time")
        `/usr/bin/time -o $timerfile -f %M $command`
    else
        error("Use Windows or Linux with GNU /usr/bin/time")
    end
    open(logpath, "w") do log
        start_ns = time_ns()
        proc = run(pipeline(measured; stdout=log, stderr=log); wait=false)
        peak = 0
        try
            if Sys.iswindows()
                handle = ccall((:OpenProcess, "kernel32"), stdcall, Ptr{Cvoid},
                    (UInt32, Int32, UInt32), 0x0410, 0, getpid(proc))
                handle == C_NULL && error("Cannot open process for memory measurement")
                try
                    while process_running(proc)
                        peak = max(peak, peak_working_set(handle))
                        sleep(0.01)
                    end
                    peak = max(peak, peak_working_set(handle))
                finally
                    ccall((:CloseHandle, "kernel32"), stdcall, Int32, (Ptr{Cvoid},), handle)
                end
            end
            wait(proc)
        finally
            if process_running(proc)
                kill(proc)
                wait(proc)
            end
        end
        wall = (time_ns() - start_ns) / 1e6
        success(proc) || error("Child failed ($(proc.exitcode)); see $logpath")
        Sys.islinux() && (peak = 1024 * parse(Int, strip(read(timerfile, String))))
        peak > 0 || error("Peak RAM unavailable: $logpath")
        return (;wall, mib=peak/2^20)
    end
end

function capture(command)
    io = IOBuffer()
    run(pipeline(command; stdout=io, stderr=io))
    return strip(String(take!(io)))
end

function write_csv(path, rows)
    names = keys(first(rows))
    escaped(x) = "\"" * replace(string(x), "\"" => "\"\"") * "\""
    open(path, "w") do io
        println(io, join(names, ','))
        for row in rows
            println(io, join(escaped.(values(row)), ','))
        end
    end
end

function bench(args)
    length(args) == 5 || error("Usage: benchmark.jl DATASET INPUT SPMF.jar BASIS_POINTS_LIST MIDDLE_BP")
    dataset, input_arg, jar_arg, grid_arg, middle_arg = args
    dataset in ("Retail", "Chess", "Mushrooms", "Pumsb") || error("Unknown dataset")
    input, jar = abspath(input_arg), abspath(jar_arg)
    grid = parse.(Int, split(grid_arg, ','))
    middle = parse(Int, middle_arg)
    5 <= length(grid) <= 7 && allunique(grid) && issorted(grid; rev=true) &&
        all(bp -> 0 < bp <= 10000, grid) && middle in grid || error("Invalid minsup grid")
    launcher = something(Sys.which("java"), "java")
    settings = capture(`$launcher -XshowSettings:properties -version`)
    home = match(r"(?m)^\s*java\.home\s*=\s*([^\r\n]+)", settings)
    isnothing(home) && error("Cannot locate the JVM from java.home")
    # Oracle's PATH shim on Windows spawns the JVM as another process.
    # Measuring the executable in java.home gives the JVM's working set.
    java = joinpath(strip(home[1]), "bin", Sys.iswindows() ? "java.exe" : "java")
    isfile(java) || error("Missing Java executable: $java")
    java_version = first(split(capture(`$java -version`), '\n')) |> strip
    version_output = capture(`$java -jar $jar version`)
    spmf_version = match(r"(?i)SPMF version\s+([\d.]+)", version_output)
    isnothing(spmf_version) && error("Cannot identify SPMF version: $version_output")
    base = joinpath(ROOT, "benchmarks", dataset)
    bundle = FrequentItemsetMining.numbered_run_directory(base, "run")
    raw_parent = mkpath(joinpath(ROOT, "output", "benchmarks", dataset))
    evidence = mkdir(joinpath(raw_parent, basename(bundle)))
    samples = write_samples(input, evidence)
    samples[100].n > 0 || error("Empty sample")
    worker = joinpath(@__DIR__, "benchmark-worker.jl")
    julia = joinpath(Sys.BINDIR, Base.julia_exename())
    common = (;protocol=PROTOCOL, dataset, run=basename(evidence), seed=SEED, raw_sha256=filehash(input),
        source_sha256=FrequentItemsetMining.implementation_fingerprint(), harness_sha256=bytes2hex(sha256(vcat(read(@__FILE__),read(worker)))),
        spmf_version=spmf_version.captures[1], jar_sha256=filehash(jar), julia_version=string(VERSION), java_version,
        os=string(Sys.KERNEL), arch=string(Sys.ARCH), cpu=Sys.cpu_info()[1].model, host_ram_bytes=Sys.total_memory(),
        os_threads=Sys.CPU_THREADS, julia_threads=1, java_active_processors=1, started_utc=string(now(UTC)))
    cases = vcat([(100,bp) for bp in grid], [(pct,middle) for pct in SIZES if pct != 100])
    rows = NamedTuple[]
    println("Evidence: ", evidence)
    flush(stdout)
    for (pct,bp) in cases
        sample = samples[pct]
        minimum = cld(sample.n * bp, 10000)
        for rep in 1:3
            order = circshift(collect(ENGINES), 1-rep)
            trial = mkpath(joinpath(evidence, "p$pct-bp$bp", "rep-$rep"))
            metrics = Dict{String,NamedTuple}()
            for engine in order
                output = joinpath(trial, "$engine.txt")
                cmd = if engine == "spmf"
                    # Relative data paths also work with Windows Java launchers
                    # whose argument encoding cannot represent the project path.
                    Cmd(`$java -XX:ActiveProcessorCount=1 -jar $jar run Apriori $(relpath(sample.path,trial)) $(basename(output)) $(percent(bp)*"%")`; dir=trial)
                else
                    `$julia --startup-file=no --threads=1 --project=$ROOT $worker $(sample.path) $output $minimum $engine`
                end
                timing = timed_process(cmd, joinpath(trial, "$engine.log"))
                isfile(output) || error("Engine produced no itemsets file: $trial/$engine")
                metrics[engine] = (;timing..., output)
            end
            ref = patterns(metrics["spmf"].output, minimum, sample.n)
            spmf_log = read(joinpath(trial, "spmf.log"), String)
            stated = match(r"Frequent itemsets count\s*:\s*(\d+)", spmf_log)
            !isnothing(stated) && parse(Int, stated[1]) == length(ref) || error("Incomplete SPMF output at $trial")
            matched = true
            fields = (;)
            for engine in ENGINES
                m = metrics[engine]
                got = engine == "spmf" ? ref : patterns(m.output, minimum, sample.n)
                diff = compare(ref, got)
                matched &= (diff.missing + diff.extra + diff.wrong == 0)
                native_time = engine == "spmf" ? match(r"Total time\s*~\s*([\d.]+) ms", spmf_log) :
                    match(r"mining_ms=([\d.eE+-]+)", read(joinpath(trial,"$engine.log"), String))
                vals = (;itemsets=length(got), output_sha256=signature(got), wall_ms=m.wall, peak_mib=m.mib,
                    native_ms=parse(Float64, only(native_time.captures)),
                    missing=diff.missing, extra=diff.extra, wrong_support=diff.wrong, match_pct=diff.match_pct)
                prefix = replace(engine, '-'=>'_')
                fields = merge(fields, (;(Symbol(prefix,"_",k)=>v for (k,v) in pairs(vals))...))
            end
            row = (;common..., sample_pct=pct, transactions=sample.n, distinct_items=sample.distinct,
                mean_width=sample.mean_width, sample_sha256=sample.sha, selected_tid_sha256=sample.idsha,
                minsup_bp=bp, min_count=minimum, rep, engine_order=join(order,"/"),
                evidence=relpath(trial,ROOT), fields..., status=matched ? "PASS" : "MISMATCH")
            push!(rows, row)
            write_csv(joinpath(evidence, "progress.csv"), rows)
            println("$(length(rows))/$(3*length(cases)) | sample=$pct% minsup=$(percent(bp))% rep=$rep | $(row.status) | $(length(ref)) itemsets")
            flush(stdout)
        end
    end
    csv = joinpath(bundle, "results.csv")
    cp(joinpath(evidence,"progress.csv"), csv; force=false)
    println("CSV: ", csv)
    all(row -> row.status == "PASS", rows) || error("Support mismatch; see CSV and raw outputs")
end

if abspath(PROGRAM_FILE) == @__FILE__
    bench(ARGS)
end
