"""Read SPMF integer transactions; skip metadata and blank lines."""
function read_spmf(source::IO)
    database = Vector{Int}[]
    for (line_number, line) in enumerate(eachline(source))
            if line_number == 1 && startswith(line, '\ufeff')
                line = chop(line; head=1, tail=0)
            end
            text = strip(line)
            (isempty(text) || startswith(text, ('#', '%', '@'))) && continue
            items = Int[]
            for token in split(text)
                item = tryparse(Int, token)
                (isnothing(item) || item < 0) &&
                    throw(ArgumentError("line $line_number: expected nonnegative integer items"))
                push!(items, item)
            end
            push!(database, unique!(sort!(items)))
    end
    return database
end

read_spmf(path::AbstractString)=open(read_spmf,path,"r")

"""Write all itemsets in deterministic size/lexicographic order."""
function write_spmf(itemsets::AbstractDict, path::AbstractString)
    ordered = sort!(collect(keys(itemsets)); by=items -> (length(items), items))
    open(path, "w") do target
        for itemset in ordered
            println(target, join(itemset, ' '), " #SUP: ", itemsets[itemset])
        end
    end
    return nothing
end
