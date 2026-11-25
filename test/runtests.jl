using Test
using Random

include(joinpath(@__DIR__, "..", "src", "FrequentItemsetMining.jl"))
using .FrequentItemsetMining

@testset "FrequentItemsetMining" begin
    include("core.jl")
    include("hash_tree.jl")
    include("cli.jl")
    include("explain.jl")
    include("timing.jl")
    include("reports.jl")
    include("report_cli.jl")
    include("market_basket.jl")
    include("splice_junction.jl")
end

include("spmf_test_kit.jl")
include("rules_tests.jl")
include("apriori_optimized.jl")
include("benchmark_optimized_sampling.jl")
