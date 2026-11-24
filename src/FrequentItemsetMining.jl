module FrequentItemsetMining

using Dates
using SHA
using TOML
using UUIDs

export mine, mine_bitset, mine_streaming, apriori_gen, MiningResult, LevelStats, read_spmf, write_spmf, main
export HashTree, HashQueryWorkspace, matching_ids, matching_ids!
export ExplainTrace
export PhaseTiming, ExternalMiningSummary, mine_external, mine_bitset_external, mine_streaming_external

include("explain.jl")
include("hash_tree.jl")
include("apriori.jl")
include("io.jl")
include("apriori_optimized.jl")
include("apriori_external.jl")
include("reports.jl")
include("run_directories.jl")
include("cli.jl")

end
