const EXPECTED_SPMF = "1 #SUP: 2\n2 #SUP: 3\n3 #SUP: 3\n5 #SUP: 3\n" *
    "1 3 #SUP: 2\n2 3 #SUP: 2\n2 5 #SUP: 3\n3 5 #SUP: 2\n2 3 5 #SUP: 2\n"

function invoke_cli(input, output, options...)
    out, err = IOBuffer(), IOBuffer()
    status = main(["--input", input, "--output", output, options..., "--quiet"]; out=out, err=err)
    return status, String(take!(out)), String(take!(err))
end

@testset "SPMF I/O and CLI" begin
    mktempdir() do scratch
        input, output = joinpath(scratch, "input.txt"), joinpath(scratch, "output.txt")
        write(input, "\ufeff# comment\n% metadata\n@ITEM=1=a\n\n3 1 1\n0 7\n")
        @test read_spmf(input) == [[1, 3], [0, 7]]
        # A BOM is permitted only at the start of the file. Embedded BOMs
        # must not silently turn two numeric fragments into another item ID.
        write(input, "1\ufeff2 3\n")
        @test_throws ArgumentError read_spmf(input)
        for token in ("bad", "-1", "1.5")
            write(input, "# comment\n1 2\n2 $token\n")
            error = try read_spmf(input); nothing catch exc; exc end
            @test error isa ArgumentError
            @test occursin("line 3", sprint(showerror, error))
        end
        write_spmf(Dict((2, 3) => 4, (3,) => 5, (1,) => 6), output)
        @test read(output, String) == "1 #SUP: 6\n3 #SUP: 5\n2 3 #SUP: 4\n"

        write(input, "1 3 4\n2 3 5\n1 2 3 5\n2 5\n")
        for counter in ("scan", "hash-tree")
            status, out, err = invoke_cli(input, output, "--minsup", "0.5", "--counter", counter, "--trace")
            @test status == 0
            @test isempty(out)
            @test occursin("k=3 candidates=1 frequent=1", err)
            @test read(output, String) == EXPECTED_SPMF
        end
        status, out, err = invoke_cli(input, output, "--min-count", "2")
        @test status == 0
        @test isempty(err)
        @test read(output, String) == EXPECTED_SPMF

        original = read(input, String)
        for alias in (input, joinpath(scratch, "unused", "..", "input.txt"))
            status, _, err = invoke_cli(input, alias, "--min-count", "2")
            @test status != 0
            @test occursin("same file", err)
            @test read(input, String) == original
        end
        link = joinpath(scratch, "hardlink.txt")
        hardlink(input, link)
        status, _, err = invoke_cli(input, link, "--min-count", "2")
        @test status != 0
        @test occursin("same file", err)
        @test read(input, String) == original

        write(output, "keep output")
        write(input, "1 2\nbad\n")
        status, _, err = invoke_cli(input, output, "--min-count", "2")
        @test status != 0
        @test occursin("line 2", err)
        @test read(output, String) == "keep output"
        # Valid input isolates option/threshold validation from parser errors.
        write(input, original)
        for options in (("--minsup", "NaN"), ("--minsup", "0"), ("--min-count", "0"),
                        ("--minsup", "0.5", "--min-count", "2"), (), ("--other", "1"))
            status, _, err = invoke_cli(input, output, options...)
            @test status != 0
            @test !occursin("line 2", err)
            @test read(output, String) == "keep output"
        end
    end
    out, err = IOBuffer(), IOBuffer()
    @test main(["--help"]; out=out, err=err) == 0
    @test occursin("--minsup", String(take!(out)))
    @test isempty(String(take!(err)))
end
