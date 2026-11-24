#!/usr/bin/env julia
# So sánh baseline Apriori hiện tại với mine_bitset và mine_streaming.
# Mỗi engine chạy trong process con riêng để đo peak RSS độc lập.
# Benchmark được lặp trên các tập con lồng nhau gồm 10%, 25%, 50%, 75%, 100% giao tác.

using FrequentItemsetMining
using SHA

const PROJECT_ROOT = dirname(@__DIR__)
const SCRIPT_PATH = abspath(@__FILE__)
const SAMPLE_PERCENTAGES = (10, 25, 50, 75, 100)
const HELP_TEXT = """
So sánh 3 engine Apriori trên 5 quy mô dữ liệu: 10%, 25%, 50%, 75%, 100% giao tác.

Cách chạy từ thư mục gốc repository:
  julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/mushrooms.txt --minsup 0.10
  julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/retail.txt --min-count 500 --repeats 5 --seed 42

Tham số:
  --input PATH       File transaction SPMF (bắt buộc)
  --minsup RATIO     Support ratio dạng thập phân, ví dụ 0.05; được áp dụng lại
                     theo số giao tác của TỪNG tập con
  --min-count N      Support count tuyệt đối, giữ nguyên N ở mọi tập con
  --baseline MODE    hash-tree (mặc định) hoặc scan
  --warmup N         Số lượt warm-up mỗi engine (mặc định 1)
  --repeats N        Số lượt đo mỗi engine (mặc định 3)
  --seed N           Seed trong SHA-256 rank TID, tái lập được (mặc định 42)
  --candidate-batch-size N  Số ứng viên tối đa mỗi batch (mặc định 10000)
  --sample-percentages LIST  Tỷ lệ cần chạy, ví dụ 10 hoặc 10,25 (mặc định tất cả)
  --engines LIST     Engine cần chạy: baseline,bitset,streaming (mặc định tất cả)
  --output PATH      CSV đầu ra (mặc định output/apriori_optimization_results.csv)

Bộ nhớ:
  Benchmark dùng đường chạy external-memory: mỗi level frequent được ghi ra file
  tạm, chỉ giữ batch ứng viên và summary trong RAM. File tạm tự xóa sau mỗi lượt.
  --help             Hiện trợ giúp

Cách lấy mẫu (giao thức APRIORI-V1):
  Chuẩn hóa giao tác theo parser SPMF: bỏ dòng trống/metadata, sắp item,
  loại item trùng trong mỗi giao tác nhưng giữ giao tác trùng nội dung.
  Xếp hạng TID theo SHA256("apriori-v1|SEED|TID"), tăng dần; lấy đúng
  floor(N*p/100) TID đầu, rồi ghi theo thứ tự nguồn. Seed mặc định là 42.
  Các tập con lồng nhau; mọi engine dùng cùng file mẫu ở mỗi tỷ lệ.
  Mẫu, manifest và hash kiểm toán được lưu cạnh CSV.

Đo thời gian:
  median_ms đo end-to-end từng lượt, gồm parse file + khai phá. Tạo tập con không
  nằm trong thời gian đo. Peak RAM là peak working set/RSS của process con, gồm
  Julia runtime và warm-up; so sánh các engine trong cùng một tỷ lệ.

Worker nội bộ:
  Smoke test một engine:
  julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/chess.txt --minsup 0.10 --sample-percentages 10 --engines baseline --warmup 0 --repeats 1 --output output/chess-external-smoke.csv

  --worker INPUT MIN_COUNT ENGINE BASELINE WARMUP REPEATS BATCH_SIZE
"""

"""SHA-256 của file, dùng để kiểm toán input và các file mẫu."""
function sha256_file(path::AbstractString)
    return open(path, "r") do source
        bytes2hex(sha256(source))
    end
end

"""Trả về TID xếp theo SHA256(apriori-v1|seed|TID), có tie-break theo TID."""
function rank_transaction_indices(total::Int, seed::UInt64)
    total >= 1 || throw(ArgumentError("total must be >= 1"))
    digests = [bytes2hex(sha256("apriori-v1|$(seed)|$(tid)")) for tid in 1:total]
    ranked = collect(1:total)
    sort!(ranked; by=tid -> (digests[tid], tid))
    return ranked
end

"""Hash TID đã chọn theo thứ tự nguồn; mỗi TID kết thúc bằng LF."""
function selected_tid_sha256(indices::AbstractVector{<:Integer})
    buffer = IOBuffer()
    for tid in indices
        print(buffer, tid, '\n')
    end
    return bytes2hex(sha256(take!(buffer)))
end

csv_field(value) = "\"" * replace(string(value), "\"" => "\"\"") * "\""

"""
Tạo các tập con lồng nhau theo giao thức APRIORI-V1.
Giao tác được parse/chuẩn hóa bằng read_spmf, xếp hạng bằng SHA-256,
chọn floor(N*p/100) TID và ghi theo thứ tự nguồn.
"""
function create_transaction_samples(input::String, output::String, seed::UInt64;
                                    percentages=SAMPLE_PERCENTAGES)
    transactions = read_spmf(input)
    total = length(transactions)
    total > 0 || error("Input không chứa transaction hợp lệ")
    isempty(percentages) && throw(ArgumentError("percentages cannot be empty"))
    all(pct -> 1 <= pct <= 100, percentages) ||
        throw(ArgumentError("sample percentages must be between 1 and 100"))
    length(unique(percentages)) == length(percentages) ||
        throw(ArgumentError("sample percentages must be unique"))

    ranked_indices = rank_transaction_indices(total, seed)
    source_sha = sha256_file(input)
    sample_directory = output * ".samples"
    mkpath(sample_directory)
    samples = NamedTuple[]

    manifest_path = joinpath(sample_directory, "manifest.csv")
    open(manifest_path, "w") do manifest
        println(manifest, "protocol,source_sha256,sample_pct,transactions,seed,sample_sha256,selected_tid_sha256,sample_file")
        for percentage in percentages
            sample_count = fld(total * percentage, 100)
            sample_count >= 1 || error(
                "The APRIORI-V1 floor rule selects zero transactions at $(percentage)% of N=$total")

            # Prefix of SHA-ranked TIDs, restored to source order before writing.
            selected_indices = sort!(ranked_indices[1:sample_count])
            sample_path = joinpath(sample_directory, "transactions_$(percentage)pct.txt")
            open(sample_path, "w") do target
                for transaction_index in selected_indices
                    print(target, join(transactions[transaction_index], ' '), '\n')
                end
            end

            sample_sha = sha256_file(sample_path)
            tid_sha = selected_tid_sha256(selected_indices)
            push!(samples, (; percentage, transactions=sample_count, path=sample_path,
                            sample_sha256=sample_sha, selected_tid_sha256=tid_sha))
            fields = ("apriori-v1", source_sha, percentage, sample_count, seed,
                      sample_sha, tid_sha, sample_path)
            println(manifest, join(csv_field.(fields), ','))
        end
    end
    return samples, total, manifest_path
end

"""Một lượt chạy; elapsed bao gồm đọc input và mine, không serialize output."""
function run_once(input::String, min_count::Int, engine::String, baseline::String,
                  candidate_batch_size::Int)
    started = time_ns()
    result = if engine == "baseline"
        transactions = read_spmf(input)
        counter = baseline == "scan" ? :scan : :hash_tree
        mine_external(transactions; min_count=min_count, counter=counter, candidate_batch_size,
                      normalized=true, progress=true)
    elseif engine == "bitset"
        mine_bitset_external(input; min_count=min_count, candidate_batch_size, progress=true)
    elseif engine == "streaming"
        mine_streaming_external(input; min_count=min_count, candidate_batch_size, progress=true)
    else
        error("Unknown engine: $engine")
    end
    return time_ns() - started, result
end

"""Mix 64-bit xác định, không phụ thuộc seed hash ngẫu nhiên của từng process."""
@inline function mix64(value::UInt64)
    value ⊻= value >> 30
    value *= 0xbf58476d1ce4e5b9
    value ⊻= value >> 27
    value *= 0x94d049bb133111eb
    value ⊻= value >> 31
    return value
end

"""Fingerprint giao hoán của itemset->support, tính không cần sort/copy keys."""
summarize_result(result::ExternalMiningSummary) = result

function summarize_result(result::MiningResult)
    fingerprint_sum = UInt64(0)
    fingerprint_xor = UInt64(0)
    support_sum = UInt128(0)
    for (itemset, support) in result.itemsets
        hash_value = mix64(UInt64(length(itemset)) ⊻ (UInt64(support) << 1))
        for item in itemset
            hash_value = mix64(hash_value ⊻ UInt64(item))
        end
        hash_value = mix64(hash_value ⊻ UInt64(support))
        fingerprint_sum += hash_value
        fingerprint_xor ⊻= hash_value
        support_sum += UInt128(support)
    end
    candidate_total = 0
    for level in result.levels
        candidate_total += level.candidates
    end
    return (; transaction_count=result.transaction_count,
              min_count=result.min_support_count,
              itemsets=length(result.itemsets), support_sum,
              candidate_total, level_count=length(result.levels),
              fingerprint_sum, fingerprint_xor)
end

function median_value(values::Vector{Float64})
    ordered = sort(values)
    middle = length(ordered) ÷ 2
    return isodd(length(ordered)) ? ordered[middle + 1] :
           (ordered[middle] + ordered[middle + 1]) / 2
end

"""Process worker. Chỉ in summary nhỏ, không serialize toàn bộ itemsets."""
function worker(args)
    length(args) == 7 || error("Invalid worker arguments; expected 7 arguments")
    input = abspath(args[1])
    min_count = parse(Int, args[2])
    engine, baseline = args[3], args[4]
    warmups, repeats = parse(Int, args[5]), parse(Int, args[6])
    candidate_batch_size = parse(Int, args[7])
    candidate_batch_size >= 1 || error("candidate_batch_size must be >= 1")
    warmups >= 0 || error("warmup must be >= 0")
    repeats >= 1 || error("repeats must be >= 1")

    for _ in 1:warmups
        _, warm_result = run_once(input, min_count, engine, baseline, candidate_batch_size)
        warm_result = nothing
        GC.gc(true)
    end

    times_ms = Float64[]
    last_summary = nothing
    for _ in 1:repeats
        elapsed_ns, result = run_once(input, min_count, engine, baseline, candidate_batch_size)
        push!(times_ms, elapsed_ns / 1e6)
        last_summary = summarize_result(result)
        result = nothing
        GC.gc(true)
    end

    label = engine == "baseline" ? "baseline-$baseline" : engine
    println(join(("RESULT", label,
        string(round(median_value(times_ms); digits=6)),
        string(round(minimum(times_ms); digits=6)),
        string(round(maximum(times_ms); digits=6)),
        last_summary.transaction_count, last_summary.min_count,
        last_summary.itemsets, last_summary.support_sum,
        last_summary.candidate_total, last_summary.level_count,
        last_summary.fingerprint_sum, last_summary.fingerprint_xor), '|'))
    flush(stdout)
    return 0
end

struct WinMemoryCounters
    size::UInt32
    page_faults::UInt32
    peak_working_set::UInt
    remaining::NTuple{7,UInt}
end

function windows_peak_working_set(handle)
    info = Ref(WinMemoryCounters(sizeof(WinMemoryCounters), 0, 0, ntuple(_ -> UInt(0), 7)))
    ok = ccall((:GetProcessMemoryInfo, "psapi"), stdcall, Int32,
        (Ptr{Cvoid}, Ref{WinMemoryCounters}, UInt32), handle, info, sizeof(WinMemoryCounters))
    return ok == 0 ? 0 : Int(info[].peak_working_set)
end

"""Run worker và đo peak RSS/working set của process con."""
function measured_process(command::Cmd, log_path::String)
    rss_path = log_path * ".rss"
    measured = if Sys.iswindows()
        command
    elseif Sys.islinux() && isfile("/usr/bin/time")
        `/usr/bin/time -o $rss_path -f %M $command`
    else
        error("Peak RAM measurement được hỗ trợ trên Windows và Linux (GNU /usr/bin/time)")
    end

    open(log_path, "w") do log
        started = time_ns()
        process = run(pipeline(measured; stdout=log, stderr=stderr); wait=false)
        peak_bytes = 0
        try
            if Sys.iswindows()
                handle = ccall((:OpenProcess, "kernel32"), stdcall, Ptr{Cvoid},
                    (UInt32, Int32, UInt32), 0x0410, 0, getpid(process))
                handle == C_NULL && error("Cannot open worker process for RAM measurement")
                try
                    while process_running(process)
                        peak_bytes = max(peak_bytes, windows_peak_working_set(handle))
                        sleep(0.01)
                    end
                    peak_bytes = max(peak_bytes, windows_peak_working_set(handle))
                finally
                    ccall((:CloseHandle, "kernel32"), stdcall, Int32, (Ptr{Cvoid},), handle)
                end
            end
            wait(process)
        finally
            if process_running(process)
                kill(process)
                wait(process)
            end
        end
        process_wall_ms = (time_ns() - started) / 1e6
        success(process) || error("Worker failed ($(process.exitcode)); inspect $log_path")
        if Sys.islinux()
            peak_bytes = 1024 * parse(Int, strip(read(rss_path, String)))
        end
        peak_bytes > 0 || error("Peak RAM measurement unavailable; inspect $log_path")
        return (; process_wall_ms, peak_ram_mib=peak_bytes / 2^20)
    end
end

function parse_worker_result(log_path::String)
    log_text = read(log_path, String)
    matches = filter(line -> startswith(line, "RESULT|"), split(log_text, '\n'))
    isempty(matches) && error("Worker did not emit RESULT; inspect $log_path")
    fields = split(last(matches), '|')
    length(fields) == 13 || error("Malformed worker RESULT; inspect $log_path")
    return (; label=fields[2], median_ms=parse(Float64, fields[3]),
        minimum_ms=parse(Float64, fields[4]), maximum_ms=parse(Float64, fields[5]),
        transaction_count=parse(Int, fields[6]), min_count=parse(Int, fields[7]),
        itemsets=parse(Int, fields[8]), support_sum=parse(UInt128, fields[9]),
        candidate_total=parse(Int, fields[10]), level_count=parse(Int, fields[11]),
        fingerprint_sum=parse(UInt64, fields[12]), fingerprint_xor=parse(UInt64, fields[13]))
end

function write_markdown_report(path::String, rows; input::String, original_transactions::Int,
                               minsup, fixed_min_count, warmups::Int, repeats::Int,
                               baseline::String, seed::UInt64, manifest_path::String,
                               candidate_batch_size::Int, sample_percentages,
                               input_sha256::String)
    open(path, "w") do report
        println(report, "# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác")
        println(report)
        println(report, "- **Input gốc:** `", input, "`")
        println(report, "- **Input SHA-256:** `", input_sha256, "`")
        println(report, "- **Số giao tác gốc:** ", original_transactions)
        println(report, "- **Tỷ lệ lấy mẫu:** ", join((string(pct, "%") for pct in sample_percentages), ", "))
        println(report, "- **Seed:** ", seed, " (có thể tái lập)")
        if !isnothing(minsup)
            println(report, "- **Minsup:** ", minsup, " (quy đổi thành min_count riêng theo từng tập con)")
        else
            println(report, "- **Min-count:** ", fixed_min_count, " (giữ nguyên ở mọi tập con được chọn)")
        end
        println(report, "- **Baseline:** `", baseline, "`")
        println(report, "- **Warm-up / repeats:** ", warmups, " / ", repeats)
        println(report, "- **Candidate batch size:** ", candidate_batch_size)
        println(report, "- **Julia / OS / kiến trúc:** ", first(rows).julia_version,
                " / ", first(rows).os, " / ", first(rows).architecture)
        println(report, "- **Manifest và các file mẫu:** `", manifest_path, "`")
        println(report)

        for percentage in sample_percentages
            subset_rows = filter(row -> row.sample_pct == percentage, rows)
            isempty(subset_rows) && continue
            reference = only(filter(row -> startswith(row.engine, "baseline-"), subset_rows))
            println(report, "## Tập con ", percentage, "%")
            println(report)
            println(report, "- **Số giao tác:** ", reference.transactions)
            println(report, "- **min_count áp dụng:** ", reference.min_count)
            println(report, "- **Sample SHA-256:** `", reference.sample_sha256, "`")
            println(report, "- **Selected TID SHA-256:** `", reference.selected_tid_sha256, "`")
            println(report)
            println(report, "| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |")
            println(report, "|---|---:|---:|---:|---:|---|")
            for row in subset_rows
                println(report, "| ", row.engine, " | ", string(round(row.median_ms; digits=3)),
                    " | ", string(round(row.peak_ram_mib; digits=2)),
                    " | ", string(round(row.speedup_vs_baseline; digits=2), "×"),
                    " | ", string(round(row.ram_reduction_pct; digits=2)),
                    " | ", row.same_as_baseline ? "PASS" : "MISMATCH", " |")
            end
            println(report)
            for row in subset_rows
                startswith(row.engine, "baseline-") && continue
                time_change = 100 * (reference.median_ms - row.median_ms) / reference.median_ms
                ram_change = 100 * (reference.peak_ram_mib - row.peak_ram_mib) /
                             reference.peak_ram_mib
                time_text = time_change >= 0 ?
                    "nhanh hơn baseline " * string(round(time_change; digits=2), "%") :
                    "chậm hơn baseline " * string(round(-time_change; digits=2), "%")
                ram_text = ram_change >= 0 ?
                    "giảm peak RAM " * string(round(ram_change; digits=2), "%") :
                    "tăng peak RAM " * string(round(-ram_change; digits=2), "%")
                println(report, "- **", row.engine, "**: ", time_text, "; ", ram_text,
                        ". Fingerprint: ", row.same_as_baseline ? "PASS" : "MISMATCH", ".")
            end
            println(report)
        end

        println(report, "## Quy trình lấy mẫu và giới hạn đo")
        println(report, "Giao thức APRIORI-V1: parse SPMF theo thứ tự nguồn; bỏ dòng trống và metadata; ")
        println(report, "sắp item và bỏ item trùng trong mỗi giao tác, nhưng giữ giao tác trùng nội dung. ")
        println(report, "Xếp hạng TID theo SHA-256 của chuỗi `apriori-v1|seed|tid` tăng dần, tie-break bằng TID; ")
        println(report, "chọn đúng `floor(N*p/100)` TID đầu, rồi ghi lại theo thứ tự nguồn. ")
        println(report, "Mẫu 100% giữ toàn bộ giao tác theo thứ tự nguồn sau chuẩn hóa. ")
        println(report, "Mỗi engine ở cùng tỷ lệ nhận cùng một file mẫu. Việc tạo file mẫu nằm ngoài thời gian ")
        println(report, "và peak RAM của process engine. `median_ms` gồm đọc/parse file mẫu và khai phá. ")
        println(report, "`peak_ram_mib` là peak RSS/working set của process con, gồm Julia runtime và warm-up. ")
        println(report, "Với `--minsup`, support count được tính lại theo số transaction của từng tập con; ")
        println(report, "với `--min-count`, ngưỡng đếm tuyệt đối được giữ nguyên ở cả năm quy mô. ")
        println(report, "Manifest lưu SHA-256 của input, sample và danh sách TID được chọn để kiểm toán. ")
        println(report, "Fingerprint là kiểm tra nhất quán giữa các engine; test oracle nên đối chiếu ")
        println(report, "mapping itemset → support đầy đủ.")
    end
    return path
end

function parse_options(args)
    options = Dict{String,String}()
    allowed = Set(("--input", "--minsup", "--min-count", "--baseline",
                   "--warmup", "--repeats", "--seed", "--candidate-batch-size",
                   "--sample-percentages", "--engines", "--output"))
    index = 1
    while index <= length(args)
        key = args[index]
        key in allowed || error("Unknown option: $key\n\n$HELP_TEXT")
        index < length(args) || error("Missing value for $key")
        haskey(options, key) && error("Option repeated: $key")
        options[key] = args[index + 1]
        index += 2
    end
    return options
end

function write_csv(path::String, rows)
    isempty(rows) && error("No benchmark rows to write")
    names = keys(first(rows))
    escape_csv(value) = "\"" * replace(string(value), "\"" => "\"\"") * "\""
    mkpath(dirname(path))
    open(path, "w") do output
        println(output, join(names, ','))
        for row in rows
            println(output, join((escape_csv(value) for value in values(row)), ','))
        end
    end
    return path
end

function benchmark(args)
    isempty(args) && error(HELP_TEXT)
    "--help" in args && (println(HELP_TEXT); return 0)
    options = parse_options(args)
    haskey(options, "--input") || error("--input is required\n\n$HELP_TEXT")
    haskey(options, "--minsup") ⊻ haskey(options, "--min-count") ||
        error("Provide exactly one of --minsup or --min-count")

    input = abspath(options["--input"])
    isfile(input) || error("Input file does not exist: $input")
    baseline = get(options, "--baseline", "hash-tree")
    baseline in ("hash-tree", "scan") || error("--baseline must be hash-tree or scan")
    warmups = parse(Int, get(options, "--warmup", "1"))
    repeats = parse(Int, get(options, "--repeats", "3"))
    candidate_batch_size = parse(Int, get(options, "--candidate-batch-size", "10000"))
    candidate_batch_size >= 1 || error("--candidate-batch-size must be >= 1")
    seed_value = parse(Int64, get(options, "--seed", "42"))
    seed_value >= 0 || error("--seed must be >= 0")
    seed = UInt64(seed_value)
    warmups >= 0 || error("--warmup must be >= 0")
    repeats >= 1 || error("--repeats must be >= 1")

    output = abspath(get(options, "--output", joinpath(PROJECT_ROOT, "output",
                                                       "apriori_optimization_results.csv")))
    sample_percentages = parse.(Int, split(get(options, "--sample-percentages",
        join(SAMPLE_PERCENTAGES, ',')), ','))
    isempty(sample_percentages) && error("--sample-percentages cannot be empty")
    length(unique(sample_percentages)) == length(sample_percentages) ||
        error("--sample-percentages contains duplicates")
    all(pct -> pct in SAMPLE_PERCENTAGES, sample_percentages) ||
        error("--sample-percentages values must be selected from $(join(SAMPLE_PERCENTAGES, ", "))")
    requested_engines = split(get(options, "--engines", "baseline,bitset,streaming"), ',')
    isempty(requested_engines) && error("--engines cannot be empty")
    length(unique(requested_engines)) == length(requested_engines) || error("--engines contains duplicates")
    all(engine -> engine in ("baseline", "bitset", "streaming"), requested_engines) ||
        error("--engines accepts baseline, bitset, streaming")
    "baseline" in requested_engines || error("--engines must include baseline as reference")

    samples, original_transactions, manifest_path =
        create_transaction_samples(input, output, seed; percentages=sample_percentages)
    input_sha256 = sha256_file(input)
    minsup = get(options, "--minsup", nothing)
    fixed_min_count = isnothing(minsup) ? parse(Int, options["--min-count"]) : nothing

    julia = joinpath(Sys.BINDIR, Base.julia_exename())
    metrics_by_sample = Dict{Int,Vector{NamedTuple}}()

    println("Input gốc: $input")
    println("Input SHA-256: $input_sha256")
    println("Giao tác gốc: $original_transactions | seed: $seed")
    println("Sampler: APRIORI-V1 SHA-256 rank + floor(N*p/100), source order")
    println("Tỷ lệ: $(join(sample_percentages, ", "))%")
    println("Engine: $(join(requested_engines, ", "))")
    engine_lookup = Dict("baseline" => ("baseline", "baseline-$baseline"),
                         "bitset" => ("bitset", "bitset"),
                         "streaming" => ("streaming", "streaming"))
    engine_specs = [engine_lookup[name] for name in requested_engines]
    println("Số cấu hình: $(length(samples) * length(engine_specs))")
    flush(stdout)

    for sample in samples
        min_count = isnothing(minsup) ?
            FrequentItemsetMining.support_threshold(sample.transactions, nothing, fixed_min_count) :
            FrequentItemsetMining.support_threshold(sample.transactions, minsup, nothing)
        println("\n--- $(sample.percentage)%: $(sample.transactions) transactions | min_count=$min_count ---")
        sample_metrics = NamedTuple[]

        for (engine, label) in engine_specs
            log_directory = output * ".logs"
            log_path = joinpath(log_directory, string(sample.percentage) * "pct_" *
                                replace(label, '-' => '_') * ".log")
            mkpath(log_directory)
            command = `$julia --startup-file=no --threads=1 --project=$PROJECT_ROOT $SCRIPT_PATH --worker $(sample.path) $min_count $engine $baseline $warmups $repeats $candidate_batch_size`
            println("  Starting $label (warmup=$warmups, repeats=$repeats)...")
            flush(stdout)
            process_metrics = measured_process(command, log_path)
            worker_metrics = parse_worker_result(log_path)
            worker_metrics.label == label || error("Engine label mismatch in $log_path")
            worker_metrics.transaction_count == sample.transactions ||
                error("Transaction count mismatch in $log_path")
            worker_metrics.min_count == min_count || error("min_count mismatch in $log_path")
            push!(sample_metrics, merge(worker_metrics, process_metrics))
            println("  $label | median=$(round(worker_metrics.median_ms; digits=3)) ms | " *
                    "peak=$(round(process_metrics.peak_ram_mib; digits=2)) MiB | " *
                    "$(worker_metrics.itemsets) itemsets")
            flush(stdout)
        end
        metrics_by_sample[sample.percentage] = sample_metrics
    end

    rows = NamedTuple[]
    all_match = true
    for sample in samples
        sample_metrics = metrics_by_sample[sample.percentage]
        reference = only(filter(metric -> startswith(metric.label, "baseline-"), sample_metrics))
        for metric in sample_metrics
            same = metric.transaction_count == reference.transaction_count &&
                   metric.min_count == reference.min_count &&
                   metric.itemsets == reference.itemsets &&
                   metric.support_sum == reference.support_sum &&
                   metric.candidate_total == reference.candidate_total &&
                   metric.level_count == reference.level_count &&
                   metric.fingerprint_sum == reference.fingerprint_sum &&
                   metric.fingerprint_xor == reference.fingerprint_xor
            all_match &= same
            speedup = reference.median_ms / metric.median_ms
            memory_reduction = 100 * (reference.peak_ram_mib - metric.peak_ram_mib) /
                               reference.peak_ram_mib
            push!(rows, (; protocol="apriori-v1", sample_pct=sample.percentage,
                sample_input=sample.path, original_transactions, engine=metric.label,
                input, input_sha256, minsup_ratio=isnothing(minsup) ? "" : string(minsup),
                sample_sha256=sample.sample_sha256,
                selected_tid_sha256=sample.selected_tid_sha256,
                transactions=metric.transaction_count, seed, min_count=metric.min_count,
                warmups, repeats, candidate_batch_size, median_ms=metric.median_ms,
                minimum_ms=metric.minimum_ms, maximum_ms=metric.maximum_ms,
                process_wall_ms=metric.process_wall_ms, peak_ram_mib=metric.peak_ram_mib,
                frequent_itemsets=metric.itemsets, support_sum=metric.support_sum,
                candidates_total=metric.candidate_total, counted_levels=metric.level_count,
                fingerprint_sum=metric.fingerprint_sum, fingerprint_xor=metric.fingerprint_xor,
                same_as_baseline=same, speedup_vs_baseline=speedup,
                ram_reduction_pct=memory_reduction, julia_version=string(VERSION),
                os=string(Sys.KERNEL), architecture=string(Sys.ARCH)))
        end
    end

    write_csv(output, rows)
    report_path = splitext(output)[1] * ".md"
    write_markdown_report(report_path, rows; input, original_transactions, minsup,
        fixed_min_count, warmups, repeats, baseline, seed, manifest_path,
        candidate_batch_size, sample_percentages, input_sha256)
    println("\nCSV: $output")
    println("Markdown report: $report_path")
    println("Sample files + manifest: $(output).samples")
    println("Logs: $(output).logs")
    if !all_match
        error("Kết quả các engine không đồng nhất ở ít nhất một tỷ lệ. CSV đã được lưu; kiểm tra logs.")
    end
    println("ĐỐI CHIẾU: PASS — fingerprint và thống kê khớp baseline ở các tỷ lệ đã chọn.")
    return 0
end

if abspath(PROGRAM_FILE) == SCRIPT_PATH
    if !isempty(ARGS) && ARGS[1] == "--worker"
        exit(worker(ARGS[2:end]))
    else
        exit(benchmark(ARGS))
    end
end
