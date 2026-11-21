using Test
include(joinpath(@__DIR__, "..", "apps", "splice-junction", "main.jl"))

@testset "Splice junctions: coordinates, unknown bases and group support" begin
    sequence(window) = "A"^26 * window * "T"^26
    @test SpliceJunction.item_label.(SpliceJunction.encode(sequence("ACGTACGT"))) ==
          ["-4:A","-3:C","-2:G","-1:T","+1:A","+2:C","+3:G","+4:T"]
    @test isempty(SpliceJunction.encode(sequence("RSDNNSDR")))
    @test_throws ArgumentError SpliceJunction.encode("ACGT")
    @test_throws ArgumentError SpliceJunction.encode(sequence("AXGTACGT"))
    mktempdir() do dir
        path = joinpath(dir, "splice.data")
        open(path, "w") do f
            for (group, windows) in [("EI", ["NNNACNNN","NNNACNNN"]),
                                     ("IE", ["NNNACNNN","NNNNNNNN","NNNNCNNN"]),
                                     ("N", ["NNNATNNN"])]
                for (i, window) in enumerate(windows)
                    println(f, group, ", sample", i, ", ", sequence(window))
                end
            end
        end
        root = joinpath(dir, "runs")
        @test SpliceJunction.main(["--input", path, "--minsup", "0.75"];
                                  output_root=root, out=devnull, err=devnull) == 0
        run = only(readdir(root; join=true))
        rows = readlines(joinpath(run, "patterns.csv"))
        fields = split(first(rows), ',')
        parsed = [Dict(zip(fields, split(row, ','))) for row in rows[2:end]]
        pair = only(filter(row -> row["pattern"] == "-1:A +1:C", parsed))
        @test [parse(Int,pair["count_" * g]) for g in ("EI","IE","N")] == [2,1,0]
        @test [parse(Float64,pair["support_" * g]) for g in ("EI","IE","N")] ≈ [1,1/3,0]
        @test occursin("IE=3", read(joinpath(run,"report.txt"),String))
        @test SpliceJunction.main(["--input",path,"--minsup","0"]; output_root=root,
                                  out=devnull, err=devnull) == 2
        write(path, "EI, id, " * sequence("ACGTACGT"))
        @test SpliceJunction.main(["--input",path]; output_root=root,out=devnull,err=devnull) == 2
        @test length(readdir(root)) == 1
    end
end
