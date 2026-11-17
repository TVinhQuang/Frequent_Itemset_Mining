"""SHA-256 of the implementation files, independent of output or test data."""
function implementation_fingerprint()
    root=dirname(@__DIR__)
    files=[joinpath(root,"Project.toml")]
    append!(files,sort!(filter(path -> endswith(path,".jl"), readdir(@__DIR__;join=true))))
    stream=IOBuffer()
    for path in files
        write(stream,replace(relpath(path,root),'\\'=>'/'),'\0',read(path),'\0')
    end
    return bytes2hex(sha256(take!(stream)))
end

const PHASE_NAMES = Dict(
    :normalize=>"Chuẩn hóa giao dịch", :threshold=>"Tính ngưỡng support",
    :singleton_count=>"Đếm item đơn", :generate_candidates=>"Sinh ứng viên (join + prune)",
    :build_counter=>"Dựng bộ đếm / hash-tree", :count_support=>"Quét giao dịch và đếm support",
    :filter=>"Lọc tập phổ biến", :level_total=>"Tổng thời gian mức k",
    :read_input=>"Đọc và parse dữ liệu", :write_output=>"Ghi kết quả SPMF",
    :warmup_total=>"Các lượt warmup", :mining_total=>"Toàn bộ mine()",
    :cli_total=>"Xử lý CLI đến trước ghi bundle")

elapsed_ms(ns::UInt64)=Float64(ns)/1_000_000
csv_cell(value)="\"" * replace(string(value),'"'=>"\"\"") * "\""
report_path_key(path)=Sys.iswindows() ? lowercase(normpath(abspath(path))) : normpath(abspath(path))

function report_timings(result, read_ns, write_ns, warmup_ns, cli_ns)
    rows=PhaseTiming[PhaseTiming(:read_input,0,read_ns,0,0)]
    push!(rows,PhaseTiming(:warmup_total,0,warmup_ns,0,0))
    append!(rows,result.timings)
    push!(rows,PhaseTiming(:mining_total,0,result.mining_ns,0,length(result.itemsets)))
    push!(rows,PhaseTiming(:write_output,0,write_ns,0,length(result.itemsets)))
    push!(rows,PhaseTiming(:cli_total,0,cli_ns,0,length(result.itemsets)))
    return rows
end

"""Persist a successful run as human-readable and machine-readable artifacts.

The caller owns a freshly created report_dir. Existing report artifacts are
never overwritten. itemsets.txt / trace.txt may already be the explicit CLI
destinations within that directory. Report serialization and input/source
fingerprinting are outside cli_ns and mining_ns; process wall time includes them.
"""
function write_run_report(report_dir::AbstractString,result::MiningResult;
                          metadata::AbstractDict,output_path::AbstractString,
                          explanation_path=nothing,read_ns::UInt64=UInt64(0),
                          write_ns::UInt64=UInt64(0),warmup_ns::UInt64=UInt64(0),
                          cli_ns::UInt64=UInt64(0))
    isdir(report_dir) || throw(ArgumentError("report directory must already exist"))
    report=joinpath(report_dir,"report.txt")
    timings=joinpath(report_dir,"timings.csv")
    metapath=joinpath(report_dir,"metadata.toml")
    snapshot=joinpath(report_dir,"itemsets.txt")
    tracepath=joinpath(report_dir,"trace.txt")
    for path in (report,timings,metapath)
        ispath(path) && throw(ArgumentError("report artifact already exists: $path"))
    end
    same_output=report_path_key(snapshot)==report_path_key(output_path)
    ispath(snapshot) && !same_output && throw(ArgumentError("itemset snapshot already exists"))
    same_trace=!isnothing(explanation_path) && report_path_key(tracepath)==report_path_key(explanation_path)
    !isnothing(explanation_path) && ispath(tracepath) && !same_trace &&
        throw(ArgumentError("trace snapshot already exists"))

    meta=Dict{String,Any}(string(k)=>v for (k,v) in metadata)
    input=abspath(meta["input_path"])
    meta["schema_version"]=1
    meta["input_path"]=input
    input_final_hash=isfile(input) ? open(io -> bytes2hex(sha256(io)),input) : ""
    meta["input_final_sha256"]=input_final_hash
    meta["input_sha256"]=get(meta,"input_sha256",input_final_hash)
    meta["input_bytes"]=get(meta,"input_bytes",isfile(input) ? filesize(input) : -1)
    meta["input_hash_scope"]=get(meta,"input_hash_scope","file_at_report_time")
    meta["input_changed_after_read"]=meta["input_sha256"]!=input_final_hash
    source_final_hash=implementation_fingerprint()
    meta["implementation_final_sha256"]=source_final_hash
    meta["implementation_sha256"]=get(meta,"implementation_sha256",source_final_hash)
    meta["implementation_changed_during_run"]=meta["implementation_sha256"]!=source_final_hash
    meta["report_written_utc"]=Dates.format(now(UTC),dateformat"yyyy-mm-ddTHH:MM:SS.sss") * "Z"
    meta["julia_version"]=string(VERSION)
    meta["os"]=string(Sys.KERNEL)
    meta["architecture"]=string(Sys.ARCH)
    meta["cpu"]=Sys.CPU_NAME
    meta["julia_threads"]=Threads.nthreads()
    meta["cpu_threads"]=Sys.CPU_THREADS
    meta["word_size"]=Sys.WORD_SIZE
    meta["transactions"]=result.transaction_count
    meta["min_support_count"]=result.min_support_count
    meta["itemset_count"]=length(result.itemsets)
    meta["mining_ns"]=Int(result.mining_ns)
    meta["read_ns"]=Int(read_ns)
    meta["write_ns"]=Int(write_ns)
    meta["warmup_ns"]=Int(warmup_ns)
    meta["cli_ns"]=Int(cli_ns)
    meta["timing_policy"]=meta["warmup_runs"]==0 ? "cold_call_may_include_jit" :
                          "warmup_requested_jit_may_remain"
    meta["timing_unit"]="nanoseconds; CSV also includes elapsed_ms"
    meta["timing_scope"]="mining excludes input/output; cli excludes startup and report serialization; nested level/phase rows must not be summed"
    meta["output_path"]=abspath(output_path)
    meta["itemsets_path"]=abspath(snapshot)
    meta["report_path"]=abspath(report)
    meta["timings_path"]=abspath(timings)
    meta["trace_path"]=isnothing(explanation_path) ? "" : abspath(tracepath)
    rows=report_timings(result,read_ns,write_ns,warmup_ns,cli_ns)

    !same_output && write_spmf(result.itemsets,snapshot)
    !isnothing(explanation_path) && !same_trace && cp(explanation_path,tracepath)
    open(timings,"w") do stream
        println(stream,"run_id,k,phase,elapsed_ns,elapsed_ms,candidates,frequent")
        for row in rows
            println(stream,join(csv_cell.(
                (meta["run_id"],row.size,row.phase,row.elapsed_ns,elapsed_ms(row.elapsed_ns),
                 row.candidates,row.frequent)),','))
        end
    end
    open(metapath,"w") do stream
        TOML.print(stream,meta;sorted=true)
    end
    open(report,"w") do stream
        println(stream,"BÁO CÁO MỘT LẦN CHẠY APRIORI")
        for key in ("run_id","started_utc","input_path","input_sha256","input_hash_scope",
                    "input_changed_after_read","implementation_sha256","implementation_changed_during_run",
                    "transactions","minsup_argument","min_support_count","counter",
                    "itemset_count","julia_version","os","architecture","cpu","julia_threads",
                    "warmup_runs","explain_enabled","explain_limit","timing_policy")
            println(stream,key," = ",meta[key])
        end
        println(stream,"\nPHẠM VI ĐO THỜI GIAN")
        println(stream,"Đơn vị: ms để đọc; CSV giữ elapsed_ns gốc. time_ns() là đồng hồ monotonic.")
        println(stream,"read_input gồm đọc snapshot, SHA256 và parse cùng nội dung; mining không gồm bước này.")
        println(stream,"Mining đo mine(); không gồm ghi output hoặc serialize báo cáo.")
        println(stream,"CLI đo xử lý đến trước ghi bundle; không gồm khởi động Julia hoặc ghi bundle.")
        println(stream,"level_total và các phase con lồng nhau: không cộng mọi dòng thành tổng.")
        println(stream,"Thời gian có thể chứa JIT/GC/dispatch. Warmup không bảo đảm bỏ hết JIT.")
        println(stream,"Bật explain có chi phí format/IO trong các phase; chỉ so cùng chế độ.")
        println(stream,"Scan có build_counter = 0; generate_candidates gồm join và prune.")
        println(stream,"Mức cuối C_k rỗng vẫn có timing, nhưng không thêm LevelStats đã đếm giả.")
        println(stream,"Đối chiếu hash cuối và serialize báo cáo nằm ngoài mining/CLI; hash snapshot nằm trong read_input.")
        if meta["input_changed_after_read"] || meta["implementation_changed_during_run"]
            println(stream,"CẢNH BÁO: file input hoặc source đã đổi sau snapshot; metadata giữ hash ban đầu và hash cuối riêng.")
        end
        println(stream,"\nk | phase | mô tả | elapsed_ms | candidates | frequent")
        for row in rows
            println(stream,row.size," | ",row.phase," | ",get(PHASE_NAMES,row.phase,string(row.phase)),
                    " | ",round(elapsed_ms(row.elapsed_ns);digits=6)," | ",row.candidates," | ",row.frequent)
        end
        println(stream,"\nTOÀN BỘ FREQUENT ITEMSETS")
        println(stream,"itemset | support_count | support_relative")
        for itemset in sort!(collect(keys(result.itemsets));by=items -> (length(items),items))
            count=result.itemsets[itemset]
            ratio=iszero(result.transaction_count) ? 0.0 : count/result.transaction_count
            println(stream,item_text(itemset)," | ",count," | ",round(ratio;digits=10))
        end
        isempty(result.itemsets) && println(stream,"(Không có itemset đạt ngưỡng.)")
        println(stream,"\nFile chuẩn SPMF: ",abspath(snapshot))
        println(stream,"Dữ liệu thời gian: ",abspath(timings))
        println(stream,"Metadata: ",abspath(metapath))
        !isnothing(explanation_path) && println(stream,"Luồng chi tiết: ",abspath(tracepath))
        println(stream,"Đây là lần chạy thực tế; chưa phải benchmark lặp lại hoặc đối chiếu SPMF/Java.")
    end
    return report
end
