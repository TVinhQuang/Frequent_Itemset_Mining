function explain_run(rows; counter=:hash_tree, limit=5000, kwargs...)
    stream = IOBuffer()
    result = mine(rows; counter, explain=ExplainTrace(stream; limit), kwargs...)
    return result, String(take!(stream))
end

@testset "Actual Apriori explanation" begin
    for counter in (:scan, :hash_tree)
        result, log = explain_run(PAPER_ROWS; min_count=2, counter)
        @test result.itemsets == PAPER_ANSWER
        @test occursin("N=4; min_count=2", log)
        @test occursin("JOIN {2,3} + {2,5} -> {2,3,5}", log)
        @test occursin("T1 chứa {1,3}: count 0 -> 1", log)
        @test occursin("T3 chứa {1,3}: count 1 -> 2", log)
        @test occursin("LOẠI {1,2}: support=1 < 2", log)
        @test occursin("GIỮ {2,3,5}: support=2 >= 2", log)
        @test occursin("C_4 rỗng", log)
        @test occursin("KẾT THÚC: 9 frequent itemsets", log)
        expected_levels = mine(PAPER_ROWS; min_count=2, counter).levels
        @test [(s.size,s.candidates,s.frequent) for s in result.levels] ==
              [(s.size,s.candidates,s.frequent) for s in expected_levels]
    end

    fixture = [[1,2],[1,2],[1,3],[1,3]]
    result, log = explain_run(fixture; min_count=2)
    @test result.itemsets == exhaustive(fixture, 2)
    @test occursin("JOIN {1,2} + {1,3} -> {1,2,3}", log)
    @test occursin("PRUNE {1,2,3}: thiếu tập con {2,3} trong L_2", log)
    @test occursin("C_3 rỗng", log)

    kit = read_spmf(joinpath(@__DIR__, "..", "Apriori_Test_Kit_8_Datasets", "datasets", "01_spmf_example.txt"))
    for counter in (:scan, :hash_tree)
        result, log = explain_run(kit; min_support="0.40", counter)
        @test length(result.itemsets) == 15
        @test occursin("ceil(0.40 × 5) = 2", log)
        @test occursin("T5 chứa {1,2,3,5}: count 1 -> 2", log)
        @test occursin("C_5 rỗng", log)
    end
    _, first = explain_run(PAPER_ROWS; min_count=2)
    _, second = explain_run(PAPER_ROWS; min_count=2)
    @test first == second

    # Ten colliding pairs force the default hash-tree to split. Trace only
    # records candidates actually counted, once per transaction.
    ids = [0,17,34,51,68]
    candidates = [(ids[i],ids[j]) for i in 1:4 for j in (i+1):5]
    stream = IOBuffer()
    trace = ExplainTrace(stream)
    counts = FrequentItemsetMining.count_candidates(candidates,[ids,ids],Val(:hash_tree),trace)
    @test counts == fill(2,10)
    log = String(take!(stream))
    for candidate in candidates
        text = "{" * join(candidate,',') * "}"
        @test length(findall("T1 chứa $text: count 0 -> 1",log)) == 1
        @test length(findall("T2 chứa $text: count 1 -> 2",log)) == 1
    end
end

@testset "Explanation limits and stopping conditions" begin
    result, log = explain_run(PAPER_ROWS; min_count=2, limit=3)
    @test result.itemsets == PAPER_ANSWER
    @test occursin("đã đạt giới hạn 3", log)
    @test occursin("vẫn tiếp tục tính đầy đủ", log)
    @test occursin("KẾT THÚC: 9 frequent itemsets", log)
    for invalid in (0, -1, true, 1.5)
        @test_throws ArgumentError ExplainTrace(IOBuffer(); limit=invalid)
    end
    for (rows, threshold, reason) in ((Vector{Int}[],1,"CSDL rỗng"),
                                      ([[1],[2]],2,"L_1 rỗng"),
                                      ([[1],[1],[2],[2]],2,"L_2 rỗng"))
        _, log = explain_run(rows; min_count=threshold)
        @test occursin(reason, log)
        @test occursin("KẾT THÚC", log)
    end
end

@testset "Explanation CLI and file preservation" begin
    mktempdir() do scratch
        input, output, logpath = joinpath.(scratch, ("input.txt", "output.txt", "explanation.txt"))
        write(input, "1 3 4\n2 3 5\n1 2 3 5\n2 5\n")
        status, out, err = invoke_cli(input, output, "--min-count", "2", "--explain")
        @test status == 0
        @test isempty(out)
        @test occursin("JOIN", err)
        @test read(output,String) == EXPECTED_SPMF
        status, _, err = invoke_cli(input, output, "--min-count", "2", "--explain-file", logpath)
        @test status == 0
        @test isempty(err)
        @test occursin("KẾT THÚC", read(logpath,String))
        @test read(output,String) == EXPECTED_SPMF
        status, _, _ = invoke_cli(input, output, "--min-count", "2", "--explain-file", logpath, "--explain-limit", "2")
        @test status == 0
        @test occursin("đã đạt giới hạn 2", read(logpath,String))

        original_input, original_output = read(input,String), read(output,String)
        for alias in (input, output, joinpath(scratch,"unused","..","input.txt"))
            status, _, err = invoke_cli(input, output, "--min-count", "2", "--explain-file", alias)
            @test status != 0
            @test occursin("same file", err)
            @test read(input,String) == original_input
            @test read(output,String) == original_output
        end
        link = joinpath(scratch,"linked-input.txt")
        hardlink(input,link)
        status, _, err = invoke_cli(input, output, "--min-count", "2", "--explain-file", link)
        @test status != 0
        @test occursin("same file", err)
        @test read(input,String) == original_input

        write(logpath,"keep log")
        for options in (("--minsup","NaN"), ("--min-count","0"),
                        ("--min-count","2","--counter","unknown"),
                        ("--min-count","2","--explain-limit","0"))
            status, _, _ = invoke_cli(input, output, options..., "--explain-file", logpath)
            @test status != 0
            @test read(logpath,String) == "keep log"
            @test read(output,String) == original_output
        end
        write(input,"bad\n")
        status, _, _ = invoke_cli(input, output, "--min-count","2","--explain-file",logpath)
        @test status != 0
        @test read(logpath,String) == "keep log"
    end
end
