module SpmfTestKit

using Test, TOML
include(joinpath(@__DIR__, "..", "bin", "benchmark.jl"))  # patterns, filehash and the Julia miner

@testset "Apriori vs SPMF on the small test databases" begin
    kit = joinpath(@__DIR__, "..", "data", "test-kit")
    evidence = TOML.parsefile(joinpath(kit, "spmf-2.68.toml"))
    cases = evidence["cases"]
    datasets = readdir(joinpath(kit, "datasets"))
    @test length(cases) >= 5
    @test Set(name * ".txt" for name in keys(cases)) == Set(datasets)

    jar = get(ENV, "SPMF_JAR", "")
    if !isempty(jar)
        @test filehash(jar) == evidence["jar_sha256"]
    end

    mktempdir() do scratch
        @testset "$name" for name in sort!(collect(keys(cases)))
            case = cases[name]
            input = joinpath(kit, "datasets", name * ".txt")
            @test filehash(input) == case["input_sha256"]
            rows = read_spmf(input)
            minsup = case["minsup"]
            n = length(rows)

            # Each SPMF capture includes its header, even when zero itemsets qualify.
            capture = joinpath(scratch, "$(name)-capture.txt")
            write(capture, case["output"])
            reference = patterns(capture, 1, n)
            @test patterns(joinpath(kit, "expected", name * ".txt"), 1, n) == reference

            if !isempty(jar)
                live = joinpath(scratch, name * ".txt")
                stats = read(`java -jar $jar run Apriori $input $live $minsup`, String)
                reported = match(r"Frequent itemsets count\s*:\s*(\d+)", stats)
                @test !isnothing(reported) && parse(Int, reported[1]) == length(reference)
                @test patterns(live, 1, n) == reference
            end

            @testset "$counter" for counter in (:scan, :hash_tree)
                result = mine(rows; min_support=minsup, counter=counter)
                output = joinpath(scratch, "$(name)-$(counter).txt")
                write_spmf(result.itemsets, output)
                @test patterns(output, 1, n) == reference
            end
        end
    end
end

end
