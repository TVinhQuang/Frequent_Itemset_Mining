using TOML

function report_cli(input, output, options...)
    out, err = IOBuffer(), IOBuffer()
    status = main(["--input", input, "--output", output, options...]; out, err)
    return status, String(take!(out)), String(take!(err))
end

@testset "CLI run history and timing context" begin
    mktempdir() do scratch
        input, output = joinpath.(scratch, ("input.txt", "current.txt"))
        write(input, "1 2\n1\n")
        status, out, err = report_cli(input, output, "--minsup", "0.5", "--warmup", "1")
        @test status == 0
        @test isempty(err)
        @test occursin("Report:", out)
        @test occursin("MiningMs:", out)
        runs = joinpath(scratch, "runs")
        @test isdir(runs)
        if isdir(runs)
            first_run = only(readdir(runs; join=true))
            @test all(isfile(joinpath(first_run, file)) for file in
                      ("itemsets.txt", "report.txt", "timings.csv", "metadata.toml"))
            @test read(joinpath(first_run, "itemsets.txt"), String) == "1 #SUP: 2\n2 #SUP: 1\n1 2 #SUP: 1\n"
            metadata = TOML.parsefile(joinpath(first_run, "metadata.toml"))
            @test metadata["warmup_runs"] == 1
            @test metadata["explain_enabled"] == false
            @test metadata["minsup_argument"] == "0.5"
            @test metadata["input_hash_scope"] == "exact_bytes_parsed"
            @test metadata["input_sha256"] == bytes2hex(FrequentItemsetMining.SHA.sha256(read(input)))
            @test metadata["input_changed_after_read"] == false
            original = Dict(file => read(joinpath(first_run, file)) for file in readdir(first_run))
            status, out, err = report_cli(input, output, "--min-count", "2", "--quiet")
            @test status == 0
            @test isempty(out) && isempty(err)
            @test length(readdir(runs)) == 2
            @test read(output, String) == "1 #SUP: 2\n"
            @test all(read(joinpath(first_run, file)) == bytes for (file, bytes) in original)
        end
    end
end

@testset "CLI explicit report destination and prevalidation" begin
    mktempdir() do scratch
        input = joinpath(scratch, "input.txt")
        write(input, "1 2\n1\n")
        bundle = joinpath(scratch, "nested", "one-run")
        output, trace = joinpath.(bundle, ("itemsets.txt", "trace.txt"))
        status, out, err = report_cli(input, output, "--min-count", "1",
            "--report-dir", bundle, "--explain-file", trace)
        @test status == 0
        @test isempty(err)
        @test occursin(abspath(bundle), out)
        if isdir(bundle)
            @test occursin("JOIN", read(trace, String))
            metadata = TOML.parsefile(joinpath(bundle, "metadata.toml"))
            @test metadata["explain_enabled"] == true
            @test metadata["minsup_argument"] == ""
            original = Dict(file => read(joinpath(bundle, file)) for file in readdir(bundle))
            status, out, err = report_cli(input, output, "--min-count", "2", "--report-dir", bundle)
            @test status != 0
            @test isempty(out)
            @test occursin("exist", err)
            @test all(read(joinpath(bundle, file)) == bytes for (file, bytes) in original)
        end

        existing_output = joinpath(scratch, "current.txt")
        write(existing_output, "preserve me")
        for options in (("--warmup", "-1"), ("--warmup", "bad"),
                        ("--warmup", "999999999999999999999999999"),
                        ("--counter", "unknown"), ("--explain-limit", "0"))
            target = joinpath(scratch, "invalid-run")
            status, out, err = report_cli(input, existing_output, "--min-count", "1",
                "--report-dir", target, "--quiet", options...)
            @test status != 0
            @test isempty(out) && !isempty(err)
            @test !ispath(target)
            @test read(existing_output, String) == "preserve me"
        end
        for reserved in ("report.txt", "timings.csv", "metadata.toml", "trace.txt")
            target = joinpath(scratch, "reserved-run")
            status, out, err = report_cli(input, joinpath(target, reserved), "--min-count", "1",
                "--report-dir", target)
            @test status != 0
            @test isempty(out) && !isempty(err)
            @test !ispath(target)
        end
        target = joinpath(scratch, "reserved-log")
        status, _, _ = report_cli(input, existing_output, "--min-count", "1",
            "--report-dir", target, "--explain-file", joinpath(target, "itemsets.txt"))
        @test status != 0
        @test !ispath(target)
        @test read(existing_output, String) == "preserve me"

        target = joinpath(scratch, "file-parent-run")
        status, out, err = report_cli(input, joinpath(target, "other.txt"), "--min-count", "1",
            "--report-dir", target, "--explain-file", joinpath(target, "other.txt", "trace.txt"))
        @test status != 0
        @test isempty(out) && !isempty(err)
        @test !ispath(target)

        blocked_output=joinpath(scratch,"future-output")
        kept_log=joinpath(scratch,"kept-log.txt")
        write(kept_log,"keep explanation")
        status, _, _ = report_cli(input,blocked_output,"--min-count","1",
            "--report-dir",joinpath(blocked_output,"run"),"--explain-file",kept_log)
        @test status != 0
        @test !ispath(blocked_output)
        @test read(kept_log,String)=="keep explanation"

        # Symlink creation may require privileges on Windows. If available,
        # verify a dangling destination cannot become a reserved report file.
        link=joinpath(scratch,"dangling-output")
        dangling_run=joinpath(scratch,"dangling-run")
        link_created=false
        try
            symlink(joinpath(dangling_run,"report.txt"),link)
            link_created=true
        catch exc
            exc isa Base.IOError || exc isa SystemError || rethrow()
        end
        if link_created
            try
                write(kept_log,"keep explanation")
                status, _, _ = report_cli(input,link,"--min-count","1",
                    "--report-dir",dangling_run,"--explain-file",kept_log)
                @test status != 0
                @test !ispath(dangling_run)
                @test read(kept_log,String)=="keep explanation"
            finally
                # Remove only the known link itself before temporary cleanup.
                islink(link) && rm(link)
            end
        end

        target = joinpath(scratch, "malformed-run")
        write(input, "invalid\n")
        status, _, _ = report_cli(input, existing_output, "--min-count", "1", "--report-dir", target)
        @test status != 0
        @test !ispath(target)
        @test read(existing_output, String) == "preserve me"
    end
end
