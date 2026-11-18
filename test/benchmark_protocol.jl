using Test
include(joinpath(@__DIR__, "..", "bin", "benchmark.jl"))

@testset "Nested transaction samples and support comparisons" begin
    mktempdir() do scratch
        source = joinpath(scratch, "transactions.txt")
        write(source, "@ITEM=9=name\n\n" * join(1:29, "\n") * "\n")
        samples = write_samples(source, scratch)
        @test [samples[p].n for p in SIZES] == [2, 7, 14, 21, 29]
        previous = Int[]
        for p in SIZES
            indices = parse.(Int, readlines(samples[p].path))
            @test issorted(indices) && allunique(indices)
            @test issubset(previous, indices)
            @test samples[p].idsha == filehash(samples[p].path)
            previous = indices
        end
        other = write_samples(source, mkpath(joinpath(scratch, "again")))
        @test all(samples[p].sha == other[p].sha for p in SIZES)

        output = joinpath(scratch, "spmf.txt")
        write(output, "@FILETYPE=\"Frequent itemsets\"\n@SOURCE=SPMF\n2 1 #SUP: 4\n9 #SUP: 2\n")
        got = patterns(output, 2, 10)
        @test got == Dict("1 2" => 4, "9" => 2)
        @test compare(got, got).match_pct == 100
        @test compare(Dict(), Dict()).match_pct == 100
        diff = compare(got, Dict("1 2" => 3, "4" => 2))
        @test (diff.missing, diff.extra, diff.wrong, diff.match_pct) == (1, 1, 1, 0)
        @test signature(got) == signature(Dict("9" => 2, "1 2" => 4))
        write(output, "1 2 #SUP: 4\n2 1 #SUP: 4\n")
        @test_throws ErrorException patterns(output, 2, 10)
        @test percent.(Int[1000,750,500,25,1]) == ["10","7.5","5","0.25","0.01"]
    end
end
