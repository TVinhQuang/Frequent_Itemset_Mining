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
end
