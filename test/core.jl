const PAPER_ROWS = [[1, 3, 4], [2, 3, 5], [1, 2, 3, 5], [2, 5]]
const PAPER_ANSWER = Dict{Tuple{Vararg{Int}},Int}(
    (1,) => 2, (2,) => 3, (3,) => 3, (5,) => 3,
    (1, 3) => 2, (2, 3) => 2, (2, 5) => 3, (3, 5) => 2,
    (2, 3, 5) => 2,
)

"""Independent oracle enumerates every subset; no production helpers."""
function exhaustive(rows, threshold)
    sets = Set{Int}[Set(row) for row in rows]
    universe = sort!(collect(union(Set{Int}(), sets...)))
    answer = Dict{Tuple{Vararg{Int}},Int}()
    for mask in 1:((1 << length(universe)) - 1)
        candidate = Tuple(universe[i] for i in eachindex(universe) if !iszero(mask & (1 << (i - 1))))
        count = sum(all(item in row for item in candidate) for row in sets; init=0)
        count >= threshold && (answer[candidate] = count)
    end
    return answer
end

@testset "Figure 3: all 9 itemsets and support" begin
    for counter in (:scan, :hash_tree)
        result = mine(PAPER_ROWS; min_count=2, counter=counter)
        @test result.itemsets == PAPER_ANSWER
        @test result.transaction_count == 4
        @test result.min_support_count == 2
        @test [(s.size, s.candidates, s.frequent) for s in result.levels] ==
              [(1, 5, 4), (2, 6, 4), (3, 1, 1)]
    end
end

@testset "Paper join/prune" begin
    previous = [(1, 2, 3), (1, 2, 4), (1, 3, 4), (1, 3, 5), (2, 3, 4)]
    @test apriori_gen(previous) == [(1, 2, 3, 4)]
    @test apriori_gen([(1, 2), (2, 3)]) == NTuple{3,Int}[]
    @test apriori_gen(NTuple{2,Int}[]) == NTuple{3,Int}[]
    @test eltype(apriori_gen([(1,), (2,), (3,)])) == NTuple{2,Int}
end

@testset "Five databases vs independent oracle" begin
    databases = [PAPER_ROWS,
        [[3, 1, 1], [1, 3], [2], Int[]],
        [[1], [2], [3], [4]],
        [[0, 1, 2], [0, 1, 2], [0, 1], [1, 2]],
        [[0, 10^12], [10^12], [0, 9], [9, 10^12]],
    ]
    for rows in databases, threshold in (1, 2, length(rows), length(rows) + 1)
        expected = exhaustive(rows, threshold)
        for counter in (:scan, :hash_tree)
            @test mine(rows; min_count=threshold, counter=counter).itemsets == expected
        end
    end
end

@testset "One-shot generators, duplicates and empty rows" begin
    rows = ((item for item in row) for row in [[3, 1, 1], [1, 3], Int[]])
    result = mine(rows; min_support="0.5")
    @test result.transaction_count == 3
    @test result.itemsets == Dict((1,) => 2, (3,) => 2, (1, 3) => 2)
    @test isempty(mine(Vector{Int}[]; min_count=1).itemsets)
    @test mine(Vector{Int}[]; min_support="0.5").min_support_count == 0
    @test isempty(mine([Int[]]; min_count=1).itemsets)
    @test isempty(mine([[1]]; min_count=2).itemsets)
end

@testset "Exact thresholds and inclusive support" begin
    rows = vcat(fill([1], 7), fill([2], 93))
    for value in ("0.07", "7e-2", 0.07, 7 // 100)
        result = mine(rows; min_support=value)
        @test result.min_support_count == 7
        @test result.itemsets == Dict((1,) => 7, (2,) => 93)
    end
    for value in ("0.34", 0.34, 34 // 100)
        result = mine([[1], [1], [2]]; min_support=value)
        @test result.min_support_count == 2
        @test result.itemsets == Dict((1,) => 2)
    end
end

@testset "Invalid values are not silently coerced" begin
    invalid = [NamedTuple(), (; min_count=true), (; min_count=0), (; min_count=-1),
        (; min_count=1.5), (; min_count="2"), (; min_support=true),
        (; min_support=0), (; min_support=-0.1), (; min_support=1.1),
        (; min_support="NaN"), (; min_support=Inf), (; min_support="abc"),
        (; min_support=""), (; min_support="0.5", min_count=1),
        (; min_count=big(typemax(Int)) + 1)]
    for kwargs in invalid
        @test_throws ArgumentError mine(Vector{Int}[]; kwargs...)
    end
    for row in ([true], [-1], [1.5], ["1"], [big(typemax(Int)) + 1])
        @test_throws ArgumentError mine([row]; min_count=1)
    end
    @test_throws ArgumentError mine(Vector{Int}[]; min_count=1, counter=:unknown)
end

@testset "Seeded randomized databases" begin
    rng = MersenneTwister(20261116)
    for trial in 1:30
        rows = [[i for i in 0:6 if rand(rng) < 0.6] for _ in 1:8]
        threshold = rand(rng, 1:8)
        expected = exhaustive(rows, threshold)
        for counter in (:scan, :hash_tree)
            @test mine(rows; min_count=threshold, counter=counter).itemsets == expected
        end
    end
end
