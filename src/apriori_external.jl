# Disk-backed Apriori path used by the benchmark runner. Itemsets in each level
# are stored as fixed-width Int64 records in lexicographic order.

struct DiskLevel
    path::String
    width::Int
    count::Int
end

struct ExternalMiningSummary
    transaction_count::Int
    min_count::Int
    itemsets::Int
    support_sum::UInt128
    candidate_total::Int
    level_count::Int
    fingerprint_sum::UInt64
    fingerprint_xor::UInt64
end

@inline function external_mix64(value::UInt64)
    value ⊻= value >> 30
    value *= 0xbf58476d1ce4e5b9
    value ⊻= value >> 27
    value *= 0x94d049bb133111eb
    value ⊻= value >> 31
    return value
end

@inline function external_itemset_hash(itemset::NTuple{K,Int}, support::Int) where K
    h = external_mix64(UInt64(K) ⊻ (UInt64(support) << 1))
    for item in itemset
        h = external_mix64(h ⊻ UInt64(item))
    end
    return external_mix64(h ⊻ UInt64(support))
end

@inline function write_itemset(io::IO, itemset::NTuple{K,Int}) where K
    for item in itemset
        write(io, Int64(item))
    end
end

@inline function read_itemset_at(io::IO, level::DiskLevel, index::Int)
    1 <= index <= level.count || throw(BoundsError(1:level.count, index))
    seek(io, (index - 1) * level.width * sizeof(Int64))
    return ntuple(_ -> Int(read(io, Int64)), level.width)
end

@inline function tuple_less(left::Tuple, right::Tuple)
    for i in eachindex(left)
        left[i] == right[i] || return left[i] < right[i]
    end
    return false
end

function disk_level_contains(io::IO, level::DiskLevel, target::NTuple{K,Int}) where K
    low, high = 1, level.count
    while low <= high
        middle = (low + high) >>> 1
        value = read_itemset_at(io, level, middle)
        if value == target
            return true
        elseif tuple_less(value, target)
            low = middle + 1
        else
            high = middle - 1
        end
    end
    return false
end

# Bounded-memory Bloom filter: most absent subsets are rejected without random
# disk seeks. False positives are resolved by the exact binary search above.
struct DiskMembershipBloom
    bits::Vector{UInt64}
    bit_count::UInt64
end

@inline function bloom_hash_pair(itemset::Tuple)
    h = UInt64(0xcbf29ce484222325)
    for item in itemset
        h = (h ⊻ UInt64(item)) * UInt64(0x100000001b3)
    end
    first = external_mix64(h)
    second = external_mix64(first ⊻ UInt64(0x9e3779b97f4a7c15)) | UInt64(1)
    return first, second
end

function build_disk_membership_bloom(level::DiskLevel; max_bytes::Int=32 * 1024^2)
    max_bytes >= 8 || throw(ArgumentError("Bloom filter memory limit must be >= 8 bytes"))
    requested_bits = max(UInt64(64), UInt64(level.count) * UInt64(10))
    maximum_bits = UInt64(max_bytes) * UInt64(8)
    bit_count = min(requested_bits, maximum_bits)
    bit_count = max(UInt64(64), bit_count - (bit_count % UInt64(64)))
    filter = DiskMembershipBloom(zeros(UInt64, Int(bit_count ÷ UInt64(64))), bit_count)
    open(level.path, "r") do source
        for _ in 1:level.count
            itemset = ntuple(_ -> Int(read(source, Int64)), level.width)
            h1, h2 = bloom_hash_pair(itemset)
            index = rem(h1, bit_count)
            step = rem(h2, bit_count)
            for _ in 1:7
                word = Int((index >>> 6) + 1)
                bit = UInt64(1) << (index & UInt64(63))
                filter.bits[word] |= bit
                index += step
                index >= bit_count && (index -= bit_count)
            end
        end
    end
    return filter
end

@inline function bloom_might_contain(filter::DiskMembershipBloom, itemset::Tuple)
    h1, h2 = bloom_hash_pair(itemset)
    index = rem(h1, filter.bit_count)
    step = rem(h2, filter.bit_count)
    for _ in 1:7
        word = Int((index >>> 6) + 1)
        bit = UInt64(1) << (index & UInt64(63))
        (filter.bits[word] & bit) == 0 && return false
        index += step
        index >= filter.bit_count && (index -= filter.bit_count)
    end
    return true
end

# Exact compact membership index for item IDs that fit in a 64- or 128-bit
# packed key. This avoids one disk binary search for every positive Bloom query.
struct PackedDiskMembership{T<:Unsigned}
    keys::Set{T}
    bits_per_item::Int
end

@inline function packed_itemset_key(itemset::Tuple, bits::Int, ::Type{T}) where {T<:Unsigned}
    key = zero(T)
    for item in itemset
        key = (key << bits) | T(item)
    end
    return key
end

@inline function disk_membership_contains(index::PackedDiskMembership{T},
                                          itemset::Tuple) where {T<:Unsigned}
    return packed_itemset_key(itemset, index.bits_per_item, T) in index.keys
end

function build_packed_disk_membership(previous::DiskLevel;
                                      max_bytes::Int=128 * 1024^2)
    previous.count == 0 && return nothing
    max_bytes >= 0 || throw(ArgumentError("packed membership memory limit must be nonnegative"))

    maximum_item = UInt64(0)
    open(previous.path, "r") do source
        for _ in 1:previous.count, _ in 1:previous.width
            value = read(source, Int64)
            value >= 0 || throw(ArgumentError("disk level contains a negative item"))
            maximum_item = max(maximum_item, UInt64(value))
        end
    end
    bits = max(1, 64 - leading_zeros(maximum_item))
    total_bits = previous.width * bits
    key_type, estimated_bytes_per_key = if total_bits <= 64
        (UInt64, 32)
    elseif total_bits <= 128
        (UInt128, 40)
    else
        return nothing
    end
    Int128(previous.count) * estimated_bytes_per_key <= max_bytes || return nothing

    keys = Set{key_type}()
    sizehint!(keys, previous.count)
    open(previous.path, "r") do source
        for _ in 1:previous.count
            itemset = ntuple(_ -> Int(read(source, Int64)), previous.width)
            push!(keys, packed_itemset_key(itemset, bits, key_type))
        end
    end
    return PackedDiskMembership(keys, bits)
end

"""Generate sorted candidates from a disk-backed sorted L_k, with bounded RAM."""
function foreach_disk_candidate_batch(callback::F, previous::DiskLevel,
                                      batch_size::Int; progress::Bool=false,
                                      level::Int=previous.width + 1) where F
    batch_size >= 1 || throw(ArgumentError("candidate_batch_size must be >= 1"))
    K = previous.width
    K >= 1 || throw(ArgumentError("invalid disk level width"))
    batch = NTuple{K+1,Int}[]
    total = 0
    generation_started = time_ns()

    # Small levels use a tuple Set. Larger levels try an exact packed-key Set
    # (capped at 128 MiB); only levels that cannot be packed/fitted use Bloom +
    # exact on-disk binary search.
    cache_limit = 64 * 1024^2
    estimated_cache_bytes = previous.count * (previous.width * sizeof(Int) + 24)
    known = nothing
    packed_known = nothing
    if estimated_cache_bytes <= cache_limit
        cached = Set{NTuple{K,Int}}()
        sizehint!(cached, previous.count)
        open(previous.path, "r") do source
            for _ in 1:previous.count
                push!(cached, ntuple(_ -> Int(read(source, Int64)), K))
            end
        end
        known = cached
    else
        packed_known = build_packed_disk_membership(previous)
    end
    bloom = isnothing(known) && isnothing(packed_known) ?
            build_disk_membership_bloom(previous) : nothing

    progress_step = max(1, cld(previous.count, 20))
    open(previous.path, "r") do sequential_source
        open(previous.path, "r") do membership_source
            for i in 1:previous.count
                left = read_itemset_at(sequential_source, previous, i)
                seek(sequential_source, i * previous.width * sizeof(Int64))
                for j in (i + 1):previous.count
                    right = ntuple(_ -> Int(read(sequential_source, Int64)), K)
                    all(left[p] == right[p] for p in 1:(K - 1)) || break
                    candidate = (left..., right[K])

                    # The two subsets already known from the join are obtained
                    # by removing positions K and K+1. Check every other K-subset.
                    # In particular, removing position 1 must be checked too;
                    # skipping it admits candidates that Apriori should prune.
                    valid = true
                    for removed in 1:(K - 1)
                        subset = ntuple(p -> candidate[p + (p >= removed)], Val(K))
                        present = if !isnothing(known)
                            subset in known
                        elseif !isnothing(packed_known)
                            disk_membership_contains(packed_known, subset)
                        elseif bloom_might_contain(bloom, subset)
                            disk_level_contains(membership_source, previous, subset)
                        else
                            false
                        end
                        if !present
                            valid = false
                            break
                        end
                    end
                    if valid
                        push!(batch, candidate)
                        total += 1
                        if length(batch) == batch_size
                            callback(batch)
                            empty!(batch)
                        end
                    end
                end
                if progress && (i % progress_step == 0 || i == previous.count)
                    pct = round(100 * i / previous.count; digits=1)
                    println(stderr, "[external] L$level join scan: $i/$(previous.count) ($pct%) | candidates=$total")
                    flush(stderr)
                end
            end
        end
    end
    isempty(batch) || callback(batch)
    return (; total, generation_ns=UInt64(time_ns() - generation_started))
end

function create_level_file(directory::String, width::Int, name::String)
    path = joinpath(directory, name * ".bin")
    return path
end

function build_external_summary(transaction_count, threshold, levels, itemsets,
                                support_sum, fingerprint_sum, fingerprint_xor)
    candidate_total = sum(level.candidates for level in levels; init=0)
    return ExternalMiningSummary(transaction_count, threshold, itemsets, support_sum,
        candidate_total, length(levels), fingerprint_sum, fingerprint_xor)
end

"""Shared disk-output loop. `count_batch` returns supports aligned with candidates."""
function external_mine_levels!(directory::String, transaction_count::Int, threshold::Int,
                               singleton_counts::Dict{Int,Int}, count_batch::F,
                               candidate_batch_size::Int; progress::Bool=false) where F
    levels = LevelStats[]
    transaction_count == 0 && return build_external_summary(transaction_count, threshold,
        levels, 0, UInt128(0), UInt64(0), UInt64(0))
    singleton_total = length(singleton_counts)
    l1_path = create_level_file(directory, 1, "level-1")
    l1_count = 0
    itemset_count = 0
    support_sum = UInt128(0)
    fingerprint_sum = UInt64(0)
    fingerprint_xor = UInt64(0)

    open(l1_path, "w") do output
        for item in sort!(collect(keys(singleton_counts)))
            support = singleton_counts[item]
            if support >= threshold
                itemset = (item,)
                write_itemset(output, itemset)
                l1_count += 1
                itemset_count += 1
                support_sum += UInt128(support)
                h = external_itemset_hash(itemset, support)
                fingerprint_sum += h
                fingerprint_xor ⊻= h
            end
        end
    end
    push!(levels, LevelStats(1, singleton_total, l1_count))
    empty!(singleton_counts)
    previous = DiskLevel(l1_path, 1, l1_count)
    itemset_size = 2

    while previous.count > 0
        current_path = create_level_file(directory, itemset_size, "level-$itemset_size")
        current_count = Ref(0)
        progress && println(stderr, "[external] Starting L$itemset_size from $(previous.count) itemsets")
        progress && flush(stderr)
        batch_number = Ref(0)
        counted_candidates = Ref(0)
        generation_phase = open(current_path, "w") do output
            foreach_disk_candidate_batch(previous, candidate_batch_size;
                                         progress, level=itemset_size) do candidates
                batch_number[] += 1
                counted_candidates[] += length(candidates)
                supports = count_batch(candidates, itemset_size)
                if progress && (batch_number[] == 1 || batch_number[] % 10 == 0)
                    println(stderr, "[external] L$itemset_size support-count batch $(batch_number[]) | candidates=$(counted_candidates[]) | frequent=$(current_count[])")
                    flush(stderr)
                end
                length(supports) == length(candidates) || error("counter returned wrong support count")
                for id in eachindex(candidates)
                    support = supports[id]
                    if support >= threshold
                        itemset = candidates[id]
                        write_itemset(output, itemset)
                        current_count[] += 1
                        itemset_count += 1
                        support_sum += UInt128(support)
                        h = external_itemset_hash(itemset, support)
                        fingerprint_sum += h
                        fingerprint_xor ⊻= h
                    end
                end
            end
        end
        if generation_phase.total == 0
            rm(current_path; force=true)
            break
        end
        push!(levels, LevelStats(itemset_size, generation_phase.total, current_count[]))
        progress && println(stderr, "[external] Finished L$itemset_size | candidates=$(generation_phase.total) | frequent=$(current_count[]) | elapsed=$(round(generation_phase.generation_ns / 1e9; digits=2))s")
        progress && flush(stderr)
        old_level_path = previous.path
        previous = DiskLevel(current_path, itemset_size, current_count[])
        rm(old_level_path; force=true)
        itemset_size += 1
    end
    return build_external_summary(transaction_count, threshold, levels, itemset_count,
                                  support_sum, fingerprint_sum, fingerprint_xor)
end

function with_external_directory(callback::F, workdir) where F
    directory = isnothing(workdir) ? mktempdir(prefix="fim-apriori-") : mktempdir(workdir; prefix="fim-apriori-")
    try
        return callback(directory)
    finally
        rm(directory; recursive=true, force=true)
    end
end

"""Baseline Apriori benchmark path: input transactions stay in RAM; levels/results stay on disk."""
function mine_external(transactions; min_support=nothing, min_count=nothing,
                       counter=:hash_tree, candidate_batch_size::Int=10_000,
                       workdir=nothing, normalized::Bool=false, progress::Bool=false)
    candidate_batch_size >= 1 || throw(ArgumentError("candidate_batch_size must be >= 1"))
    mode = counter_mode(counter)
    database = if normalized
        transactions isa Vector{Vector{Int}} ||
            throw(ArgumentError("normalized=true requires Vector{Vector{Int}} input"))
        transactions
    else
        normalize_transactions(transactions)
    end
    threshold = support_threshold(length(database), min_support, min_count)
    singleton_counts = Dict{Int,Int}()
    for transaction in database, item in transaction
        singleton_counts[item] = get(singleton_counts, item, 0) + 1
    end
    return with_external_directory(workdir) do directory
        count_batch = (candidates, _) -> count_candidates(candidates, database, mode)
        external_mine_levels!(directory, length(database), threshold, singleton_counts,
                              count_batch, candidate_batch_size; progress)
    end
end

function mine_bitset_external(path::AbstractString; min_support=nothing, min_count=nothing,
                              candidate_batch_size::Int=10_000, workdir=nothing,
                              progress::Bool=false)
    candidate_batch_size >= 1 || throw(ArgumentError("candidate_batch_size must be >= 1"))
    transaction_count, singleton_counts = file_singleton_counts(path)
    threshold = support_threshold(transaction_count, min_support, min_count)
    return with_external_directory(workdir) do directory
        # Build the L1 disk file first, then construct vertical bitmaps from its IDs.
        l1_items = sort!([item for (item, count) in singleton_counts if count >= threshold])
        columns = Dict(item => column for (column, item) in enumerate(l1_items))
        bitmaps = zeros(UInt64, cld(transaction_count, 64), length(l1_items))
        observed = foreach_spmf_transaction(path) do tid, transaction
            word_index = ((tid - 1) >>> 6) + 1
            bit_index = (tid - 1) & 63
            bit = one(UInt64) << bit_index
            for item in transaction
                column = get(columns, item, 0)
                column == 0 || (bitmaps[word_index, column] |= bit)
            end
        end
        observed == transaction_count || throw(ArgumentError("input file changed between passes"))
        count_batch = (candidates, _) -> begin
            counts = Vector{Int}(undef, length(candidates))
            for id in eachindex(candidates)
                counts[id] = bitset_support(bitmaps, columns, candidates[id])
            end
            counts
        end
        external_mine_levels!(directory, transaction_count, threshold, singleton_counts,
                              count_batch, candidate_batch_size; progress)
    end
end

function mine_streaming_external(path::AbstractString; min_support=nothing, min_count=nothing,
                                 candidate_batch_size::Int=10_000, workdir=nothing,
                                 progress::Bool=false)
    candidate_batch_size >= 1 || throw(ArgumentError("candidate_batch_size must be >= 1"))
    transaction_count, singleton_counts = file_singleton_counts(path)
    threshold = support_threshold(transaction_count, min_support, min_count)
    return with_external_directory(workdir) do directory
        count_batch = (candidates, _) -> begin
            tree = HashTree(candidates)
            workspace = HashQueryWorkspace(tree)
            counts = zeros(Int, length(candidates))
            observed = foreach_spmf_transaction(path) do _, transaction
                for id in matching_ids!(workspace, tree, transaction)
                    counts[id] += 1
                end
            end
            observed == transaction_count || throw(ArgumentError("input file changed between passes"))
            counts
        end
        external_mine_levels!(directory, transaction_count, threshold, singleton_counts,
                              count_batch, candidate_batch_size; progress)
    end
end
