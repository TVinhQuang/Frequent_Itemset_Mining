using FrequentItemsetMining

input, target, count, counter = ARGS
rows = read_spmf(input)
result = mine(rows; min_count=parse(Int, count), counter)
write_spmf(result.itemsets, target)
println("mining_ms=", result.mining_ns / 1e6)
println("k,phase,elapsed_ns,candidates,frequent")
for phase in result.timings
    println(join((phase.size, phase.phase, phase.elapsed_ns, phase.candidates, phase.frequent), ','))
end
