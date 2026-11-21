using Test
using Random
include(joinpath(@__DIR__, "..", "src", "AssociationRules.jl"))
using .AssociationRules

# Ví dụ của bài báo Agrawal & Srikant (min count = 2, N = 4)
const PAPER_COUNTS = Dict{Vector{Int},Int}(
    [1] => 2, [2] => 3, [3] => 3, [5] => 3,
    [1, 3] => 2, [2, 3] => 2, [2, 5] => 3, [3, 5] => 2,
    [2, 3, 5] => 2,
)

key(r::Rule) = (r.antecedent, r.consequent)

@testset "AssociationRules" begin
    @testset "đọc file itemsets và đếm transaction" begin
        mktempdir() do d
            f = joinpath(d, "itemsets.txt")
            write(f, "@CONVERTED_FROM_TEXT\n\n5 2 #SUP: 3\n1 #SUP: 2\n2 3 5 #SUP: 2\n")
            c = read_itemsets(f)
            @test c == Dict([2, 5] => 3, [1] => 2, [2, 3, 5] => 2)

            bad = joinpath(d, "bad.txt")
            write(bad, "1 2 3\n")
            @test_throws ArgumentError read_itemsets(bad)

            g = joinpath(d, "data.txt")
            write(g, "# ghi chú\n1 3 4\n\n2 3 5\n@meta\n1 2 3 5\n2 5\n")
            @test count_transactions(g) == 4
        end
    end

    @testset "ví dụ bài báo" begin
        all_rules = generate_rules(PAPER_COUNTS, 4; minconf=0.0)
        @test length(all_rules) == 14             # 4 cặp × 2 + 1 bộ ba × 6

        r = generate_rules(PAPER_COUNTS, 4; minconf=1.0)
        @test Set(key.(r)) == Set([([1], [3]), ([2], [5]), ([5], [2]),
                                   ([2, 3], [5]), ([3, 5], [2])])
        @test all(x -> x.confidence == 1.0, r)
        @test all(x -> isapprox(x.lift, 4 / 3), r)
        # support cao nhất đứng trước, hòa thì antecedent tăng dần
        @test key(r[1]) == ([2], [5])
        @test key(r[2]) == ([5], [2])
        @test r[1].support == 0.75
        @test r[1].count == 3

        # {5} ⇒ {3}: conf = 2/3, lift = (2/3) / (3/4) = 8/9 < 1
        x = only(filter(y -> key(y) == ([5], [3]), all_rules))
        @test isapprox(x.confidence, 2 / 3)
        @test isapprox(x.lift, 8 / 9)
        @test x.support == 0.5

        # lọc theo lift
        pos = generate_rules(PAPER_COUNTS, 4; minconf=0.0, minlift=1.0)
        @test all(x -> x.lift >= 1.0, pos)
        @test length(pos) < length(all_rules)
    end

    @testset "đối chiếu brute-force trên dữ liệu ngẫu nhiên (seed cố định)" begin
        rng = MersenneTwister(42)
        nitems, ntrans = 8, 60
        trans = [sort!(collect(Iterators.take(randperm(rng, nitems), rand(rng, 2:5))))
                 for _ in 1:ntrans]
        supcount(set) = count(t -> all(in(t), set), trans)

        counts = Dict{Vector{Int},Int}()
        for mask in 1:(1 << nitems) - 1
            set = [i for i in 1:nitems if (mask >> (i - 1)) & 1 == 1]
            c = supcount(set)
            c >= 6 && (counts[set] = c)
        end

        minconf = 0.4
        rules = generate_rules(counts, ntrans; minconf=minconf)

        # đếm luật kỳ vọng bằng cách duyệt mọi cặp (X, Y) rời nhau
        expected = 0
        for (z, cz) in counts, mask in 1:(1 << length(z)) - 2
            x = [z[j] for j in eachindex(z) if (mask >> (j - 1)) & 1 == 1]
            cz / supcount(x) >= minconf - 1e-12 && (expected += 1)
        end
        @test length(rules) == expected
        @test !isempty(rules)

        for r in rules
            z = sort!(vcat(r.antecedent, r.consequent))
            @test isempty(intersect(r.antecedent, r.consequent))
            @test r.count == supcount(z)
            @test r.confidence ≈ supcount(z) / supcount(r.antecedent)
            @test r.lift ≈ (supcount(z) / ntrans) /
                           ((supcount(r.antecedent) / ntrans) * (supcount(r.consequent) / ntrans))
        end
        @test issorted(rules; by=r -> -r.lift)

        # chạy lại cho đúng cùng kết quả (tái lập)
        again = generate_rules(counts, ntrans; minconf=minconf)
        @test key.(again) == key.(rules)
        @test [r.lift for r in again] == [r.lift for r in rules]
    end

    @testset "ghi CSV" begin
        mktempdir() do d
            p = write_rules_csv(joinpath(d, "sub", "rules.csv"),
                                generate_rules(PAPER_COUNTS, 4; minconf=1.0))
            lines = readlines(p)
            @test lines[1] == "antecedent,consequent,count,support,confidence,lift"
            @test length(lines) == 6
            @test startswith(lines[2], "2,5,3,0.75,1.0,")
        end
    end

    @testset "kiểm tra lỗi đầu vào" begin
        @test_throws ArgumentError generate_rules(PAPER_COUNTS, 0)
        @test_throws ArgumentError generate_rules(PAPER_COUNTS, 4; minconf=1.5)
        @test_throws ArgumentError generate_rules(PAPER_COUNTS, 4; minlift=-1)
        thieu = Dict{Vector{Int},Int}([1, 2] => 3, [1] => 3)   # thiếu support của {2}
        @test_throws ArgumentError generate_rules(thieu, 5)
    end
end
