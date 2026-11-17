@testset "Measured mining phases preserve results and counted levels" begin
    @test isdefined(FrequentItemsetMining, :PhaseTiming)
    result = mine(PAPER_ROWS; min_count=2, counter=:scan)
    @test hasproperty(result, :timings)
    @test hasproperty(result, :mining_ns)
    if hasproperty(result, :timings) && hasproperty(result, :mining_ns)
        expected = [(0, :normalize, 0, 0), (0, :threshold, 0, 0),
                    (1, :singleton_count, 5, 0), (1, :filter, 5, 4), (1, :level_total, 5, 4),
                    (2, :generate_candidates, 6, 0), (2, :build_counter, 6, 0),
                    (2, :count_support, 6, 0), (2, :filter, 6, 4), (2, :level_total, 6, 4),
                    (3, :generate_candidates, 1, 0), (3, :build_counter, 1, 0),
                    (3, :count_support, 1, 0), (3, :filter, 1, 1), (3, :level_total, 1, 1),
                    (4, :generate_candidates, 0, 0), (4, :level_total, 0, 0)]
        for counter in (:scan, :hash_tree)
            actual = mine(PAPER_ROWS; min_support="0.5", counter)
            @test actual.itemsets == PAPER_ANSWER
            @test [(s.size, s.candidates, s.frequent) for s in actual.levels] ==
                  [(1, 5, 4), (2, 6, 4), (3, 1, 1)]
            @test [(t.size, t.phase, t.candidates, t.frequent) for t in actual.timings] == expected
            @test actual.timings isa Vector{FrequentItemsetMining.PhaseTiming}
            @test actual.mining_ns isa UInt64
            @test all(t.elapsed_ns isa UInt64 && t.elapsed_ns <= actual.mining_ns for t in actual.timings)
            for size in 1:4
                rows = filter(t -> t.size == size, actual.timings)
                total = only(filter(t -> t.phase == :level_total, rows)).elapsed_ns
                @test all(t.elapsed_ns <= total for t in rows)
            end
            builds = filter(t -> t.phase == :build_counter, actual.timings)
            if counter == :scan
                @test all(iszero(t.elapsed_ns) for t in builds)
            else
                # A measured tree/workspace build may round to zero on coarse clocks.
                @test all(t.elapsed_ns >= 0 for t in builds)
            end
        end
    end
end

@testset "Timing edge cases and compatibility" begin
    result = mine(Vector{Int}[]; min_count=1)
    @test hasproperty(result, :timings)
    if hasproperty(result, :timings)
        @test [(t.size, t.phase) for t in result.timings] == [(0, :normalize), (0, :threshold)]
        @test isempty(result.levels)
        @test all(t.elapsed_ns <= result.mining_ns for t in result.timings)
        for rows in ([Int[]], [[1]])
            no_frequent = mine(rows; min_count=2)
            @test [(t.size, t.phase) for t in no_frequent.timings] ==
                  [(0, :normalize), (0, :threshold), (1, :singleton_count), (1, :filter), (1, :level_total)]
            @test length(no_frequent.levels) == 1
        end
        # A counted but entirely rejected L2 remains a LevelStats entry.
        rejected = mine([[1], [2]]; min_count=1)
        @test [(s.size, s.candidates, s.frequent) for s in rejected.levels] == [(1, 2, 2), (2, 1, 0)]
        @test [(t.size, t.phase) for t in rejected.timings if t.phase == :level_total] ==
              [(1, :level_total), (2, :level_total)]
        old = MiningResult(copy(PAPER_ANSWER), 4, 2, LevelStats[])
        @test old.itemsets == PAPER_ANSWER
        @test isempty(old.timings)
        @test old.mining_ns === UInt64(0)
        independent = mine([[1]]; min_count=1)
        empty!(independent.timings)
        @test !isempty(mine([[1]]; min_count=1).timings)
    end
    candidates = [(1, 3), (2, 5)]
    for mode in (Val(:scan), Val(:hash_tree))
        @test (@inferred FrequentItemsetMining.count_candidates(candidates, PAPER_ROWS, mode)) == [2, 3]
    end
end
