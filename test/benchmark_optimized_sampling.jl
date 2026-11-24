module BenchmarkOptimizedSamplingTests
using Test
using SHA
include(joinpath(@__DIR__, "..", "bin", "benchmark-optimized.jl"))

@testset "Optimized benchmark APRIORI-V1 transaction sampling" begin
    mktempdir() do scratch
        source = joinpath(scratch, "transactions.txt")
        # Distinct TIDs make it possible to verify exact selected source rows.
        write(source, "@RELATION=sha-sampler\n\n" * join(1:29, "\n") * "\n")
        output = joinpath(scratch, "run", "results.csv")
        samples, total, manifest = create_transaction_samples(
            source, output, UInt64(42); percentages=(10, 25, 50, 75, 100))

        @test total == 29
        @test [sample.transactions for sample in samples] == [2, 7, 14, 21, 29]
        @test isfile(manifest)
        manifest_text = read(manifest, String)
        @test occursin("protocol,source_sha256,sample_pct,transactions,seed,sample_sha256,selected_tid_sha256,sample_file", manifest_text)
        @test occursin("apriori-v1", manifest_text)

        # Independent expression of the protocol: SHA256("apriori-v1|42|i"),
        # lexical digest order, then source-order output of each selected prefix.
        expected_rank = sort(collect(1:29); by=i ->
            (bytes2hex(sha256("apriori-v1|42|$(i)")), i))
        previous = Int[]
        for (sample, percentage) in zip(samples, (10, 25, 50, 75, 100))
            count = fld(29 * percentage, 100)
            expected_ids = sort(expected_rank[1:count])
            actual_ids = parse.(Int, readlines(sample.path))

            @test actual_ids == expected_ids
            @test issubset(previous, actual_ids)
            @test sample.transactions == count
            actual_sample_sha = open(sample.path, "r") do io
                bytes2hex(sha256(io))
            end
            @test sample.sample_sha256 == actual_sample_sha
            @test sample.selected_tid_sha256 == bytes2hex(sha256(join(expected_ids, "\n") * "\n"))
            previous = actual_ids
        end

        # Re-running with the same input and seed must reproduce byte-identical samples.
        second, second_total, _ = create_transaction_samples(
            source, joinpath(scratch, "again", "results.csv"), UInt64(42);
            percentages=(10, 25, 50, 75, 100))
        @test second_total == total
        @test [s.sample_sha256 for s in second] == [s.sample_sha256 for s in samples]
        @test [s.selected_tid_sha256 for s in second] == [s.selected_tid_sha256 for s in samples]
    end

    mktempdir() do scratch
        source = joinpath(scratch, "normalized.txt")
        # Item order is normalized, duplicate items inside a basket are removed,
        # metadata/blank lines are skipped, and duplicate transactions are retained.
        write(source, "@RELATION=normalization\n3 1 3 2\n\n5 4 5\n5 4 5\n2 2 2\n")
        samples, total, _ = create_transaction_samples(
            source, joinpath(scratch, "normalized.csv"), UInt64(42); percentages=(100,))
        @test total == 4
        @test readlines(only(samples).path) == ["1 2 3", "4 5", "4 5", "2"]
    end

    mktempdir() do scratch
        # Golden check for Chess: floor(3196 * 10 / 100) is exactly 319,
        # and the selected-TID hash is fixed by the repository protocol.
        source = joinpath(scratch, "chess-sized.txt")
        write(source, join(1:3196, "\n") * "\n")
        samples, total, _ = create_transaction_samples(
            source, joinpath(scratch, "chess.csv"), UInt64(42); percentages=(10, 100))
        @test total == 3196
        @test [sample.transactions for sample in samples] == [319, 3196]
        @test samples[1].selected_tid_sha256 ==
            "aaa8b4bf695fa5d7008ef34cc4b9a0af55320a7c6435dff1f4a5cad69e2a49f2"
    end

    # Verify the actual checked-in Chess source, not only synthetic rows.
    chess_input = normpath(joinpath(@__DIR__, "..", "data", "benchmarks", "chess.txt"))
    if isfile(chess_input)
        @test sha256_file(chess_input) ==
            "a12ea887df58a396709430af5bf0a9a32d1f6eba8e7c13dd41f28b98572c5db2"
        mktempdir() do scratch
            samples, total, _ = create_transaction_samples(
                chess_input, joinpath(scratch, "chess.csv"), UInt64(42);
                percentages=(10, 100))
            @test total == 3196
            @test [sample.transactions for sample in samples] == [319, 3196]
            @test samples[1].sample_sha256 ==
                "5d8b4aceb1319bf8ce43f8c6791a70387cc495e160fba3fe4076020d90809a6c"
            @test samples[1].selected_tid_sha256 ==
                "aaa8b4bf695fa5d7008ef34cc4b9a0af55320a7c6435dff1f4a5cad69e2a49f2"
            @test samples[2].sample_sha256 ==
                "341d0ff8676e053dd3b417d61f84c732736154f987ce56975a099b07460957f5"
        end
    end

    mktempdir() do scratch
        source = joinpath(scratch, "small.txt")
        write(source, "1\n2\n3\n4\n5\n6\n7\n8\n9\n")
        @test_throws ErrorException create_transaction_samples(
            source, joinpath(scratch, "small.csv"), UInt64(42); percentages=(10,))
    end
end

end # module BenchmarkOptimizedSamplingTests
