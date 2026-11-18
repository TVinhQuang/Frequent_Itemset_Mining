include(joinpath(@__DIR__, "..", "src", "run_directories.jl"))

length(ARGS) == 1 || error("Usage: julia bin/new-batch.jl PARENT")
println(basename(numbered_run_directory(abspath(only(ARGS)), "batch")))
