"""Claim a fresh stem-N directory, starting after the largest existing suffix."""
function numbered_run_directory(parent, stem; validate=identity)
    prefix = stem * "-"
    Sys.iswindows() && (prefix = lowercase(prefix))
    last_number = big(0)
    if isdir(parent)
        for entry in readdir(parent; sort=false)
            name = Sys.iswindows() ? lowercase(entry) : entry
            startswith(name, prefix) || continue
            suffix = chopprefix(name, prefix)
            occursin(r"^[0-9]+\z", suffix) || continue
            last_number = max(last_number, parse(BigInt, suffix))
        end
    end
    number = last_number + 1
    while true
        directory = joinpath(parent, "$stem-$number")
        validate(directory)
        mkpath(parent)
        try
            return mkdir(directory)
        catch exc
            # Another process may have claimed this number since readdir.
            exc isa Base.IOError && exc.code == Base.UV_EEXIST || rethrow()
            number += 1
        end
    end
end
