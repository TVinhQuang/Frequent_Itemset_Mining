@testset "Hash-tree candidate IDs" begin
    @testset "terminal collisions require complete candidate checks" begin
        candidates = [(0, 2), (0, 4), (2, 4), (2, 6)]
        tree = HashTree(candidates; bucket_count=1, leaf_capacity=1)
        @test sort(matching_ids(tree, [0, 2, 6])) == [1, 4]
        @test sort(matching_ids(tree, [0, 2, 4, 6])) == [1, 2, 3, 4]
        @test isempty(matching_ids(tree, [0]))
        @test isempty(matching_ids(tree, Int[]))
    end

    @testset "internal nodes may be revisited for different prefixes" begin
        candidates = [(0, 1, 2), (0, 1, 4), (0, 2, 3), (1, 3, 5),
                      (2, 3, 4), (2, 4, 6), (3, 5, 7)]
        tree = HashTree(candidates; bucket_count=2, leaf_capacity=1)
        @test sort(matching_ids(tree, [0, 1, 2, 3, 4, 5, 6, 7])) == collect(1:7)
        @test sort(matching_ids(tree, [0, 2, 3, 4, 6])) == [3, 5, 6]
        @test sort(matching_ids(tree, [1, 3, 5, 7])) == [4, 7]
    end

    @testset "workspace reset and independent convenience results" begin
        tree = HashTree([(0, 2), (0, 4), (2, 4)]; leaf_capacity=1)
        workspace = HashQueryWorkspace(tree)
        first_result = matching_ids!(workspace, tree, [0, 2, 4])
        @test sort(first_result) == [1, 2, 3]
        second_result = matching_ids!(workspace, tree, [0, 4])
        @test second_result === first_result
        @test second_result == [2]
        @test isempty(matching_ids!(workspace, tree, [2]))
        @test matching_ids!(workspace, tree, [2, 4]) == [3]
        owned_result = matching_ids(tree, [0, 2])
        @test owned_result == [1]
        @test matching_ids(tree, [0, 4]) == [2]
        @test owned_result == [1]
        @test matching_ids!(workspace, tree, [0, 2]) == [1]
    end

    @testset "sparse IDs use bounded membership storage" begin
        huge = typemax(Int)
        tree = HashTree([(0, huge - 2), (huge - 2, huge)]; bucket_count=2,
                        leaf_capacity=1)
        workspace = HashQueryWorkspace(tree)
        @test matching_ids!(workspace, tree, [0, huge - 2]) == [1]
        @test matching_ids!(workspace, tree, [huge - 2, huge]) == [2]
        @test isempty(matching_ids!(workspace, tree, [0, huge - 1, huge]))
        @test Base.summarysize(workspace) < 100_000
    end

    @testset "empty typed candidate collections" begin
        tree = HashTree(NTuple{3,Int}[]; bucket_count=1, leaf_capacity=1)
        workspace = HashQueryWorkspace(tree)
        @test isempty(matching_ids(tree, [0, 1, 2]))
        @test isempty(matching_ids!(workspace, tree, Int[]))
    end

    @testset "constructor validates candidates and configuration" begin
        for invalid in (0, -1, true, 1.5, big(typemax(Int)) + 1)
            @test_throws ArgumentError HashTree([(0, 1)]; bucket_count=invalid)
            @test_throws ArgumentError HashTree([(0, 1)]; leaf_capacity=invalid)
        end
        @test_throws ArgumentError HashTree([(-1, 2)])
        @test_throws ArgumentError HashTree([(2, 1)])
        @test_throws ArgumentError HashTree([(1, 1)])
        @test_throws ArgumentError HashTree([()])
        @test_throws ArgumentError HashTree([(true, 2)])
        @test_throws ArgumentError HashTree([(0, 1), (0, 1, 2)])
        @test_throws ArgumentError HashTree([(0, big(typemax(Int)) + 1)])
    end

    @testset "subset oracle across collisions and leaf sizes" begin
        candidates = NTuple{3,Int}[(a, b, c) for a in 0:3 for b in a+1:4 for c in b+1:5]
        for bucket_count in (1, 2, 17), leaf_capacity in (1, 3, 100)
            tree = HashTree(candidates; bucket_count, leaf_capacity)
            workspace = HashQueryWorkspace(tree)
            for mask in 0:127
                transaction = Int[item for item in 0:6 if !iszero(mask & (1 << item))]
                expected = Int[id for (id, candidate) in enumerate(candidates)
                               if all(item in transaction for item in candidate)]
                actual = matching_ids!(workspace, tree, transaction)
                @test sort(actual) == expected
                @test length(actual) == length(unique(actual))
            end
        end
    end
end
