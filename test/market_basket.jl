using Test
using DelimitedFiles: readdlm
include(joinpath(@__DIR__, "..", "apps", "market-basket", "main.jl"))

@testset "Default Retail application matches the notebook" begin
    mktempdir() do dir
        out = IOBuffer()
        @test MarketBasket.main(String[]; output_root=dir, out=out) == 0
        @test occursin("88162 giỏ | 55 tập mục phổ biến | 45 luật", String(take!(out)))
        run = only(readdir(dir; join=true))
        @test basename(run) == "retail-1"
        reference = joinpath(@__DIR__, "..", "apps", "market-basket", "results", "retail-rules.csv")
        all_rules = joinpath(run, "retail-rules.csv")
        @test isfile(all_rules)
        if isfile(all_rules)
            @test readlines(all_rules) == readlines(reference)
        end
        expected, _ = readdlm(reference, ',', String; header=true)
        top, _ = readdlm(joinpath(run, "top10-rules.csv"), ',', String; header=true)
        @test size(top, 1) == 10
        @test top[:, 2:4] == expected[1:10, 1:3]
        @test all(isapprox.(parse.(Float64, top[:, 5:7]), parse.(Float64, expected[1:10, 4:6]); atol=5e-9))
    end
end

@testset "Market basket rules" begin
    mined = MarketBasket.FIM.mine([[1,2],[1,2],[1],[1],[3]]; min_count=1)
    ranked = MarketBasket.rank_rules(mined, 1//2)
    @test ranked.total == 2
    @test [(r.lhs, r.rhs) for r in ranked.rules] == [((2,), (1,)), ((1,), (2,))]
    @test [(r.count, r.support, r.confidence, r.lift) for r in ranked.rules] ==
          [(2, 2//5, 1, 5//4), (2, 2//5, 1//2, 5//4)]
    @test MarketBasket.rank_rules(mined, MarketBasket.confidence_ratio("0.50000000000000001")).total == 1

    triple = MarketBasket.FIM.mine([[1,2,3],[1,2,3],[4]]; min_count=2)
    tied = MarketBasket.rank_rules(triple, 1//1)
    @test tied.total == 12
    @test length(tied.rules) == 10
    @test (tied.rules[2].lhs, tied.rules[2].rhs) == ((1,), (2,3))
    @test issorted([(r.lhs, r.rhs) for r in tied.rules])

    four = MarketBasket.FIM.mine([[1,2,3,4],[1,2,3,4],[5]]; min_count=2)
    larger = MarketBasket.rank_rules(four, 1//1)
    @test larger.total == 50
    @test any(r -> r.lhs == (1,) && r.rhs == (2,3,4), larger.rules)
end

@testset "Market basket application" begin
    mktempdir() do dir
        write(joinpath(dir, "baskets.txt"), "1 2\n1 2\n1\n1\n3\n")
        catalog = joinpath(dir, "products.csv")
        write(catalog, "item_id,StockCode,Description\r\n1,A,\"Cốc, to\"\r\n2,B,\"Tách \"\"A\"\"\"\r\n3,C,Khay\r\n")
        output = joinpath(dir, "runs")
        invoke(args) = MarketBasket.main(args; data_dir=dir, output_root=output,
                                         out=IOBuffer(), err=IOBuffer())
        @test invoke(["--minconf", "1.1"]) == 2
        @test invoke(["--minconf"]) == 2
        @test invoke(["--minsup", "0"]) == 2
        err = IOBuffer()
        @test MarketBasket.main(["--minconf", "nope"]; data_dir=joinpath(dir, "missing"),
                                output_root=output, err=err) == 2
        @test occursin("--minconf", String(take!(err)))
        @test !ispath(output)
        @test invoke(["--minsup", "0.4", "--minconf", "0.5"]) == 0
        first_run = only(readdir(output; join=true))
        path = joinpath(first_run, "top10-rules.csv")
        table, header = readdlm(path, ',', String; header=true)
        @test vec(header) == ["rank","antecedent","consequent","basket_count","support","confidence","lift"]
        @test table[1,2:3] == ["Tách \"A\"", "Cốc, to"]
        @test parse.(Float64, table[1,4:7]) == [2,0.4,1,1.25]
        @test table[2,2:3] == reverse(table[1,2:3])
        @test occursin("Tách \"A\"", read(joinpath(first_run, "report.txt"), String))
        original = read(path)
        @test invoke(["--minsup", "1"]) == 0
        @test read(path) == original
        empty_run = only(setdiff(readdir(output; join=true), [first_run]))
        @test length(readlines(joinpath(empty_run, "top10-rules.csv"))) == 1
        @test occursin("0", read(joinpath(empty_run, "report.txt"), String))
        write(catalog, "item_id,StockCode,Description\n1,A,Cup\n")
        @test invoke(String[]) == 2
        @test length(readdir(output)) == 2
    end
end
