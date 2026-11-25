@testset "Optimized Apriori variants" begin
    @testset "External output preserves support across bitmap words and candidate batches" begin
        mktempdir() do scratch
            path = joinpath(scratch, "word-boundaries.txt")
            for n in (63, 64, 65, 127, 128, 129)
                rows = [i in (1, 63, 64, 65, 127, 128, 129) ? [1, 2, 3] : [1, 3] for i in 1:n]
                write(path, join((join(row, ' ') for row in rows), "\n") * "\n")
                expected = mine(rows; min_count=2, counter=:scan).itemsets
                for (algorithm, input) in ((mine_external, rows), (mine_bitset_external, path),
                                           (mine_streaming_external, path))
                    buffer = IOBuffer()
                    summary = algorithm(input; min_count=2, candidate_batch_size=1, itemset_io=buffer)
                    lines = split(chomp(String(take!(buffer))), '\n')
                    reference = [join(key, ' ') * " #SUP: " * string(value) for (key, value) in expected]
                    @test sort(lines) == sort(reference)
                    @test summary.itemsets == length(lines)
                end
            end
        end
    end
    root = normpath(joinpath(@__DIR__, ".."))
    datasets = joinpath(root, "data", "test-kit", "datasets")
    for filename in sort(readdir(datasets))
        endswith(filename, ".txt") || continue
        path = joinpath(datasets, filename)
        transactions = read_spmf(path)
        expected = mine(transactions; min_count=2, counter=:hash_tree)
        bitset = mine_bitset(path; min_count=2)
        streaming = mine_streaming(path; min_count=2)

        @test bitset.itemsets == expected.itemsets
        @test streaming.itemsets == expected.itemsets
        @test bitset.transaction_count == expected.transaction_count
        @test streaming.transaction_count == expected.transaction_count
        @test bitset.min_support_count == expected.min_support_count
        @test streaming.min_support_count == expected.min_support_count
        @test [(x.size, x.candidates, x.frequent) for x in bitset.levels] ==
              [(x.size, x.candidates, x.frequent) for x in expected.levels]
        @test [(x.size, x.candidates, x.frequent) for x in streaming.levels] ==
              [(x.size, x.candidates, x.frequent) for x in expected.levels]
    end

    mktempdir() do scratch
        path = joinpath(scratch, "transactions.txt")
        write(path, "@RELATION=test\n3 1 3 2\n1 2\n2 3\n3 1\n")
        transactions = read_spmf(path)
        for threshold in 1:4
            expected = mine(transactions; min_count=threshold)
            @test mine_bitset(path; min_count=threshold).itemsets == expected.itemsets
            @test mine_streaming(path; min_count=threshold).itemsets == expected.itemsets
        end
        @test mine_bitset(path; min_support="0.5").itemsets ==
              mine(transactions; min_support="0.5").itemsets
        @test mine_streaming(path; min_support="0.5").itemsets ==
              mine(transactions; min_support="0.5").itemsets

        fractional_path = joinpath(scratch, "fractional.txt")
        write(fractional_path, "1\n1\n1\n1\n2\n2\n3\n")
        fractional_rows = read_spmf(fractional_path)
        fractional_expected = mine(fractional_rows; min_support="0.43")
        @test fractional_expected.min_support_count == 4
        @test mine_bitset(fractional_path; min_support="0.43").itemsets ==
              fractional_expected.itemsets
        @test mine_streaming(fractional_path; min_support="0.43").itemsets ==
              fractional_expected.itemsets

        empty_path = joinpath(scratch, "empty.txt")
        write(empty_path, "# empty database\n\n@META=test\n")
        expected_empty = mine(Vector{Int}[]; min_count=1)
        @test mine_bitset(empty_path; min_count=1).itemsets == expected_empty.itemsets
        @test mine_streaming(empty_path; min_count=1).itemsets == expected_empty.itemsets
        @test isempty(mine_bitset(empty_path; min_count=1).levels)
        @test isempty(mine_streaming(empty_path; min_count=1).levels)
    end

    # Bounded candidate batches must preserve exact itemset/support results and
    # per-level candidate/frequent counts for every engine.
    mktempdir() do scratch
        path = joinpath(scratch, "batching.txt")
        transactions = [
            [1, 2, 3, 4], [1, 2, 3], [1, 2, 4], [1, 3, 4],
            [2, 3, 4], [1, 2, 3, 4], [1, 2], [3, 4],
        ]
        open(path, "w") do output
            foreach(row -> println(output, join(row, ' ')), transactions)
        end
        expected = mine(transactions; min_count=2, candidate_batch_size=10_000)
        for batch_size in (1, 2, 3, 5)
            baseline = mine(transactions; min_count=2, candidate_batch_size=batch_size)
            bitset = mine_bitset(path; min_count=2, candidate_batch_size=batch_size)
            streaming = mine_streaming(path; min_count=2, candidate_batch_size=batch_size)
            @test baseline.itemsets == expected.itemsets
            @test bitset.itemsets == expected.itemsets
            @test streaming.itemsets == expected.itemsets
            @test [(x.size, x.candidates, x.frequent) for x in baseline.levels] ==
                  [(x.size, x.candidates, x.frequent) for x in expected.levels]
            @test [(x.size, x.candidates, x.frequent) for x in bitset.levels] ==
                  [(x.size, x.candidates, x.frequent) for x in expected.levels]
            @test [(x.size, x.candidates, x.frequent) for x in streaming.levels] ==
                  [(x.size, x.candidates, x.frequent) for x in expected.levels]
        end
    end


    # Bloom prefilter must never reject an itemset inserted from a disk level.
    mktempdir() do bloom_scratch
        bloom_path = joinpath(bloom_scratch, "bloom-level.bin")
        open(bloom_path, "w") do output
            for item in 1:2_000
                write(output, Int64(item))
                write(output, Int64(item + 10_000))
            end
        end
        bloom_level = FrequentItemsetMining.DiskLevel(bloom_path, 2, 2_000)
        tiny = FrequentItemsetMining.build_disk_membership_bloom(bloom_level; max_bytes=8)
        absent = (10_001, 20_001)
        @test FrequentItemsetMining.bloom_might_contain(tiny, absent)
        open(bloom_path) do io
            @test !FrequentItemsetMining.disk_level_contains(io, bloom_level, absent)
        end
        @test isnothing(FrequentItemsetMining.build_packed_disk_membership(bloom_level; max_bytes=0))
        for (key, keytype) in (((1, 1 << 31), UInt64),
                               ((1, 2, 3, 1 << 31), UInt128),
                               ((1, 2, 1 << 42), nothing))
            boundary_path = joinpath(bloom_scratch, "packed-boundary-$(length(key)).bin")
            open(boundary_path, "w") do io
                foreach(item -> write(io, Int64(item)), key)
            end
            level = FrequentItemsetMining.DiskLevel(boundary_path, length(key), 1)
            index = FrequentItemsetMining.build_packed_disk_membership(level)
            if isnothing(keytype)
                @test isnothing(index)
            else
                @test eltype(index.keys) == keytype
                @test FrequentItemsetMining.disk_membership_contains(index, key)
            end
        end
        bloom = FrequentItemsetMining.build_disk_membership_bloom(bloom_level)
        @test all(FrequentItemsetMining.bloom_might_contain(bloom, (item, item + 10_000))
                  for item in 1:2_000)
        packed = FrequentItemsetMining.build_packed_disk_membership(bloom_level)
        @test packed !== nothing
        @test all(FrequentItemsetMining.disk_membership_contains(
                      packed, (item, item + 10_000)) for item in 1:2_000)
        @test !FrequentItemsetMining.disk_membership_contains(packed, (9_999, 12_001))

        # Exercise the UInt128 packed-key path (3 * 22 bits = 66 bits).
        wide_path = joinpath(bloom_scratch, "wide-level.bin")
        wide_items = [(1, 2_000_000, 4_000_000),
                      (1, 3_000_000, 4_000_000),
                      (2, 3_000_000, 4_000_000)]
        open(wide_path, "w") do output
            for itemset in wide_items, item in itemset
                write(output, Int64(item))
            end
        end
        wide_level = FrequentItemsetMining.DiskLevel(wide_path, 3, length(wide_items))
        wide_packed = FrequentItemsetMining.build_packed_disk_membership(wide_level)
        @test wide_packed !== nothing
        @test all(FrequentItemsetMining.disk_membership_contains(wide_packed, itemset)
                  for itemset in wide_items)
        @test !FrequentItemsetMining.disk_membership_contains(
            wide_packed, (1, 2_500_000, 4_000_000))
    end

    # Disk-backed benchmark APIs must match the regular in-memory API while
    # avoiding a materialized Dict of all frequent itemsets.
    mktempdir() do scratch
        path = joinpath(scratch, "external-memory.txt")
        transactions = [
            [0, 1, 2, 3], [0, 1, 2], [0, 1, 3], [0, 2, 3],
            [1, 2, 3], [0, 1, 2, 3], [0, 1], [2, 3],
        ]
        open(path, "w") do output
            foreach(row -> println(output, join(row, ' ')), transactions)
        end
        expected = mine(transactions; min_count=2)
        expected_hashes = UInt64[]
        mix_for_test = value -> begin
            value = UInt64(value)
            value ⊻= value >> 30
            value *= 0xbf58476d1ce4e5b9
            value ⊻= value >> 27
            value *= 0x94d049bb133111eb
            value ⊻= value >> 31
            value
        end
        for (itemset, support) in expected.itemsets
            h = mix_for_test(UInt64(length(itemset)) ⊻ (UInt64(support) << 1))
            for item in itemset
                h = mix_for_test(h ⊻ UInt64(item))
            end
            push!(expected_hashes, mix_for_test(h ⊻ UInt64(support)))
        end
        expected_fingerprint_sum = foldl(+, expected_hashes; init=UInt64(0))
        expected_fingerprint_xor = foldl(⊻, expected_hashes; init=UInt64(0))
        expected_support_sum = sum(UInt128(value) for value in values(expected.itemsets); init=UInt128(0))
        expected_candidate_total = sum(level.candidates for level in expected.levels; init=0)

        for batch_size in (1, 2, 5, 10_000)
            external_results = (
                mine_external(transactions; min_count=2, candidate_batch_size=batch_size, workdir=scratch),
                mine_external(transactions; min_count=2, counter=:scan, candidate_batch_size=batch_size, workdir=scratch),
                mine_bitset_external(path; min_count=2, candidate_batch_size=batch_size, workdir=scratch),
                mine_streaming_external(path; min_count=2, candidate_batch_size=batch_size, workdir=scratch),
            )
            for result in external_results
                @test result.transaction_count == expected.transaction_count
                @test result.min_count == expected.min_support_count
                @test result.itemsets == length(expected.itemsets)
                @test result.support_sum == expected_support_sum
                @test result.candidate_total == expected_candidate_total
                @test result.level_count == length(expected.levels)
                @test result.fingerprint_sum == expected_fingerprint_sum
                @test result.fingerprint_xor == expected_fingerprint_xor
            end
        end
        @test readdir(scratch) == ["external-memory.txt"]

        # Regression: C3=(1,2,4) must be pruned because its subset (2,4)
        # is absent from L2, even though the two join parents are frequent.
        # The old external loop checked the wrong positions and retained C3.
        prune_transactions = [[1, 2], [1, 4], [1, 2], [1, 4]]
        prune_path = joinpath(scratch, "prune-regression.txt")
        open(prune_path, "w") do output
            foreach(row -> println(output, join(row, ' ')), prune_transactions)
        end
        prune_expected = mine(prune_transactions; min_count=2)
        @test [(level.size, level.candidates) for level in prune_expected.levels] == [(1, 3), (2, 3)]
        @test sum(level.candidates for level in prune_expected.levels; init=0) == 6
        @test length(prune_expected.levels) == 2
        prune_results = (
            mine_external(prune_transactions; min_count=2, candidate_batch_size=2, workdir=scratch),
            mine_bitset_external(prune_path; min_count=2, candidate_batch_size=2, workdir=scratch),
            mine_streaming_external(prune_path; min_count=2, candidate_batch_size=2, workdir=scratch),
        )
        for result in prune_results
            @test result.itemsets == length(prune_expected.itemsets)
            @test result.candidate_total == 6
            @test result.level_count == 2
        end

        empty_path = joinpath(scratch, "empty.txt")
        write(empty_path, "# empty\n\n")
        empty_result = mine_streaming_external(empty_path; min_count=1, workdir=scratch)
        @test empty_result.itemsets == 0
        @test empty_result.level_count == 0
    end

    @test_throws ArgumentError mine([[1, 2]]; min_count=1, candidate_batch_size=0)
    @test_throws ArgumentError mine_bitset(joinpath(root, "data", "toy", "paper.txt");
                                           min_count=1, candidate_batch_size=0)
    @test_throws ArgumentError mine_streaming(joinpath(root, "data", "toy", "paper.txt");
                                              min_count=1, candidate_batch_size=0)

    rng = MersenneTwister(20261121)
    mktempdir() do scratch
        for trial in 1:20
            path = joinpath(scratch, "random-$trial.txt")
            transactions = Vector{Int}[]
            for _ in 1:10
                row = Int[item for item in 0:6 if rand(rng) < 0.55]
                isempty(row) && push!(row, rand(rng, 0:6))
                push!(transactions, row)
            end
            open(path, "w") do output
                for row in transactions
                    println(output, join(row, ' '))
                end
            end
            expected_rows = read_spmf(path)
            threshold = rand(rng, 1:10)
            expected = mine(expected_rows; min_count=threshold, counter=:hash_tree)
            @test mine_bitset(path; min_count=threshold).itemsets == expected.itemsets
            @test mine_streaming(path; min_count=threshold).itemsets == expected.itemsets
        end
    end
end
