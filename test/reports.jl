using TOML

function report_metadata(input; id="writer-test", explain=false)
    Dict{String,Any}("run_id"=>id, "started_utc"=>"2026-11-17T00:00:00.000Z",
        "input_path"=>input, "minsup_argument"=>"0.5", "counter"=>"hash-tree",
        "warmup_runs"=>0, "explain_enabled"=>explain, "explain_limit"=>5000)
end

@testset "Persistent measured run reports" begin
    mktempdir() do scratch
        input, output = joinpath.(scratch,("input.txt","output.txt"))
        write(input,"1 3 4\n2 3 5\n1 2 3 5\n2 5\n")
        result=mine(read_spmf(input);min_support="0.5")
        write_spmf(result.itemsets,output)
        bundle=mkdir(joinpath(scratch,"run1"))
        FrequentItemsetMining.write_run_report(bundle,result; metadata=report_metadata(input),
            output_path=output, read_ns=UInt64(100),write_ns=UInt64(200),cli_ns=UInt64(300))
        @test read(joinpath(bundle,"itemsets.txt"),String)==EXPECTED_SPMF
        report=read(joinpath(bundle,"report.txt"),String)
        @test occursin("writer-test",report)
        @test occursin("{2,3,5}",report)
        @test occursin("support_count",report)
        @test occursin("normalize",report)
        @test occursin("generate_candidates",report)
        @test occursin("JIT",report)
        @test occursin("không cộng",report)
        meta=TOML.parsefile(joinpath(bundle,"metadata.toml"))
        @test meta["schema_version"]==1
        @test meta["run_id"]=="writer-test"
        @test meta["transactions"]==4
        @test meta["min_support_count"]==2
        @test meta["itemset_count"]==9
        @test meta["input_sha256"]==bytes2hex(FrequentItemsetMining.SHA.sha256(read(input)))
        @test length(meta["implementation_sha256"])==64
        @test meta["mining_ns"]==Int(result.mining_ns)
        @test meta["read_ns"]==100
        @test meta["write_ns"]==200
        @test meta["cli_ns"]==300
        @test meta["warmup_runs"]==0
        @test meta["explain_enabled"]==false
        @test meta["timing_policy"]=="cold_call_may_include_jit"
        lines=readlines(joinpath(bundle,"timings.csv"))
        @test occursin("elapsed_ns",lines[1])
        @test occursin("elapsed_ms",lines[1])
        @test occursin("phase",lines[1])
        @test any(line -> occursin("mining_total",line),lines)
        @test any(line -> occursin("read_input",line),lines)
        @test any(line -> occursin("level_total",line),lines)
        original=read(joinpath(bundle,"report.txt"))
        @test_throws ArgumentError FrequentItemsetMining.write_run_report(bundle,result;
            metadata=report_metadata(input),output_path=output)
        @test read(joinpath(bundle,"report.txt"))==original
        # The snapshot remains independent when the latest output is replaced.
        write(output,"a later run\n")
        @test read(joinpath(bundle,"itemsets.txt"),String)==EXPECTED_SPMF

        bundle2=mkdir(joinpath(scratch,"run2"))
        tracepath=joinpath(bundle2,"trace.txt")
        explain_result=open(tracepath,"w") do stream
            mine(PAPER_ROWS;min_count=2,explain=ExplainTrace(stream))
        end
        itempath=joinpath(bundle2,"itemsets.txt")
        write_spmf(explain_result.itemsets,itempath)
        meta2=report_metadata(input;id="writer-test-2",explain=true)
        meta2["warmup_runs"]=1
        FrequentItemsetMining.write_run_report(bundle2,explain_result;metadata=meta2,
            output_path=itempath,explanation_path=tracepath,warmup_ns=UInt64(50))
        @test occursin("KẾT THÚC",read(tracepath,String))
        saved=TOML.parsefile(joinpath(bundle2,"metadata.toml"))
        @test saved["explain_enabled"]==true
        @test saved["warmup_runs"]==1
        @test saved["timing_policy"]=="warmup_requested_jit_may_remain"
        @test saved["trace_path"]==abspath(tracepath)
        @test isfile(joinpath(bundle,"report.txt"))

        original_bytes=read(input)
        captured=report_metadata(input;id="snapshot-test")
        captured["input_sha256"]=bytes2hex(FrequentItemsetMining.SHA.sha256(original_bytes))
        captured["input_bytes"]=length(original_bytes)
        captured["input_hash_scope"]="exact_bytes_parsed"
        captured["implementation_sha256"]=repeat("0",64)
        write(input,"99\n")
        bundle3=mkdir(joinpath(scratch,"run3"))
        FrequentItemsetMining.write_run_report(bundle3,result;metadata=captured,output_path=output)
        snapshot_meta=TOML.parsefile(joinpath(bundle3,"metadata.toml"))
        @test snapshot_meta["input_sha256"]==captured["input_sha256"]
        @test snapshot_meta["input_bytes"]==length(original_bytes)
        @test get(snapshot_meta,"input_changed_after_read",false)
        @test snapshot_meta["implementation_sha256"]==repeat("0",64)
        @test get(snapshot_meta,"implementation_changed_during_run",false)
        @test read(joinpath(bundle3,"itemsets.txt"),String)==EXPECTED_SPMF
    end
end
