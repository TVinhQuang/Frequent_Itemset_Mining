using FrequentItemsetMining

function write_result(input, target, min_count, engine)
    if engine == "scan"
        result = mine(read_spmf(input); min_count, counter=:scan)
        write_spmf(result.itemsets, target)
    elseif engine == "bitset" || engine == "streaming"
        miner = engine == "bitset" ? mine_bitset_external : mine_streaming_external
        open(target, "w") do io
            miner(input; min_count, candidate_batch_size=10_000, itemset_io=io)
        end
    else
        error("Expected scan, bitset or streaming")
    end
end

input, target, count, engine = ARGS
write_result(input, target, parse(Int, count), engine)
println("PEAK_BYTES|", Sys.maxrss())
