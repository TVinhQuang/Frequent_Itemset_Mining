# Hai biến thể Apriori tối ưu được thiết kế dựa trên mine() hiện tại.
# 1) mine_bitset: lưu vertical TID bitmap và đếm support bằng AND + popcount.
# 2) mine_streaming: không giữ toàn bộ database trong RAM; đọc file theo từng lượt.

"""Duyệt file SPMF theo từng transaction, không materialize toàn bộ database.

Callback nhận `(tid, transaction)`. Quy tắc bỏ qua dòng trắng/metadata, xử lý BOM,
parse Int, sort và loại item trùng được giữ giống `read_spmf`.
"""
function foreach_spmf_transaction(callback::F, path::AbstractString) where {F}
    transaction_count = 0
    open(path, "r") do source
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
            unique!(sort!(items))
            transaction_count += 1
            callback(transaction_count, items)
        end
    end
    return transaction_count
end

"""First file pass: count N and singleton support without retaining transactions."""
function file_singleton_counts(path::AbstractString)
    singletons = Dict{Int,Int}()
    transaction_count = foreach_spmf_transaction(path) do _, transaction
        for item in transaction
            singletons[item] = get(singletons, item, 0) + 1
        end
    end
    return transaction_count, singletons
end

"""Create L1 and fill the common MiningResult containers."""
function initial_frequent_level!(answer, levels, singletons, threshold)
    previous = NTuple{1,Int}[(item,) for (item, count) in singletons if count >= threshold]
    sort!(previous)
    for itemset in previous
        answer[itemset] = singletons[itemset[1]]
    end
    push!(levels, LevelStats(1, length(singletons), length(previous)))
    return previous
end

"""Count an itemset by intersecting its singleton TID bitmaps.

`bitmaps` has one UInt64 column per frequent singleton and one row per 64 TIDs.
The candidate is mapped to bitmap columns once, outside the word loop.
"""
@inline function bitset_support(bitmaps::Matrix{UInt64}, columns::Dict{Int,Int},
                                candidate::NTuple{K,Int}) where {K}
    candidate_columns = ntuple(index -> columns[candidate[index]], Val(K))
    support = 0
    @inbounds for word_index in axes(bitmaps, 1)
        intersection = bitmaps[word_index, candidate_columns[1]]
        for position in 2:K
            intersection &= bitmaps[word_index, candidate_columns[position]]
            iszero(intersection) && break
        end
        support += count_ones(intersection)
    end
    return support
end

"""Build a UInt64 vertical bitmap matrix for items in L1."""
function build_singleton_bitmaps(path::AbstractString, transaction_count::Int,
                                 previous::Vector{NTuple{1,Int}})
    columns = Dict{Int,Int}()
    for (column, itemset) in enumerate(previous)
        columns[itemset[1]] = column
    end

    word_count = cld(transaction_count, 64)
    bitmaps = zeros(UInt64, word_count, length(previous))
    observed = foreach_spmf_transaction(path) do tid, transaction
        word_index = ((tid - 1) >>> 6) + 1
        bit_index = (tid - 1) & 63
        bit = one(UInt64) << bit_index
        for item in transaction
            column = get(columns, item, 0)
            if column != 0
                bitmaps[word_index, column] |= bit
            end
        end
    end
    observed == transaction_count ||
        throw(ArgumentError("input file changed between Apriori passes (transaction count differs)"))
    return bitmaps, columns
end

"""Apriori using vertical TID bitmaps; optimized for fast support counting.

The input is a path to an SPMF transaction file. Only items frequent at level 1
receive bitmaps. Candidate support is computed by word-wise intersections and
`count_ones`, avoiding a transaction-by-candidate hash-tree traversal.
"""
function mine_bitset(path::AbstractString; min_support=nothing, min_count=nothing,
                      candidate_batch_size::Int=10_000)
    candidate_batch_size >= 1 ||
        throw(ArgumentError("candidate_batch_size must be >= 1"))
    mining_started = time_ns()
    timings = PhaseTiming[]

    started = time_ns()
    transaction_count, singletons = file_singleton_counts(path)
    record_phase!(timings, :singleton_count, 1, time_ns() - started, length(singletons), 0)

    started = time_ns()
    threshold = support_threshold(transaction_count, min_support, min_count)
    record_phase!(timings, :threshold, 0, time_ns() - started, 0, 0)

    answer = Dict{Tuple{Vararg{Int}},Int}()
    levels = LevelStats[]
    if iszero(transaction_count)
        return MiningResult(answer, transaction_count, threshold, levels,
                            timings, time_ns() - mining_started)
    end
    previous = initial_frequent_level!(answer, levels, singletons, threshold)
    isempty(previous) && return MiningResult(answer, transaction_count, threshold, levels,
                                               timings, time_ns() - mining_started)

    # L1's support counts are now copied to the result; release the temporary map.
    singletons = nothing  # let the singleton dictionary become collectible
    # With one frequent singleton, C2 is empty; retain the original phase record
    # but skip the unnecessary second file pass that would build a one-column bitmap.
    if length(previous) < 2
        level_started = time_ns()
        started = time_ns()
        apriori_gen(previous)
        record_phase!(timings, :generate_candidates, 2, time_ns() - started, 0, 0)
        record_phase!(timings, :level_total, 2, time_ns() - level_started, 0, 0)
        return MiningResult(answer, transaction_count, threshold, levels,
                            timings, time_ns() - mining_started)
    end

    started = time_ns()
    bitmaps, columns = build_singleton_bitmaps(path, transaction_count, previous)
    record_phase!(timings, :build_counter, 1, time_ns() - started,
                  length(previous), 0)

    itemset_size = 2
    while !isempty(previous)
        level_started = time_ns()
        candidate_type = typeof((first(previous)..., 0))
        current = candidate_type[]
        generation_phase_index = Ref(0)
        candidate_stats = foreach_candidate_batch(previous, candidate_batch_size, NoTrace()) do candidates
            if iszero(generation_phase_index[])
                push!(timings, PhaseTiming(:generate_candidates, itemset_size, UInt64(0), 0, 0))
                generation_phase_index[] = length(timings)
            end
            count_started = time_ns()
            counts = Vector{Int}(undef, length(candidates))
            for candidate_id in eachindex(candidates)
                counts[candidate_id] = bitset_support(bitmaps, columns, candidates[candidate_id])
            end
            record_phase!(timings, :count_support, itemset_size,
                          time_ns() - count_started, length(candidates), 0)
            filter_started = time_ns()
            frequent_in_batch = 0
            for candidate_id in eachindex(candidates)
                support = counts[candidate_id]
                if support >= threshold
                    candidate = candidates[candidate_id]
                    push!(current, candidate)
                    answer[candidate] = support
                    frequent_in_batch += 1
                end
            end
            record_phase!(timings, :filter, itemset_size, time_ns() - filter_started,
                          length(candidates), frequent_in_batch)
        end
        candidate_total = candidate_stats.total
        if iszero(generation_phase_index[])
            record_phase!(timings, :generate_candidates, itemset_size,
                          candidate_stats.generation_ns, candidate_total, 0)
        else
            timings[generation_phase_index[]] =
                PhaseTiming(:generate_candidates, itemset_size, candidate_stats.generation_ns,
                            candidate_total, 0)
        end
        if iszero(candidate_total)
            record_phase!(timings, :level_total, itemset_size,
                          time_ns() - level_started, 0, 0)
            break
        end
        push!(levels, LevelStats(itemset_size, candidate_total, length(current)))
        record_phase!(timings, :level_total, itemset_size, time_ns() - level_started,
                      candidate_total, length(current))
        previous = current
        itemset_size += 1
    end

    return MiningResult(answer, transaction_count, threshold, levels, timings,
                        time_ns() - mining_started)
end

"""Apriori with a disk-backed transaction source and bounded transaction memory.

The file is scanned once to count singletons and once per candidate batch for
support counting. At most one normalized transaction is resident while support
is counted. This exchanges additional sequential disk reads for a much smaller
database-memory footprint. Candidate processing is bounded by
`candidate_batch_size`: each batch gets its own hash-tree and counters, then is
discarded. The previous frequent level and final output still reside in RAM.
"""
function mine_streaming(path::AbstractString; min_support=nothing, min_count=nothing,
                         candidate_batch_size::Int=10_000)
    candidate_batch_size >= 1 ||
        throw(ArgumentError("candidate_batch_size must be >= 1"))
    mining_started = time_ns()
    timings = PhaseTiming[]

    started = time_ns()
    transaction_count, singletons = file_singleton_counts(path)
    record_phase!(timings, :singleton_count, 1, time_ns() - started, length(singletons), 0)

    started = time_ns()
    threshold = support_threshold(transaction_count, min_support, min_count)
    record_phase!(timings, :threshold, 0, time_ns() - started, 0, 0)

    answer = Dict{Tuple{Vararg{Int}},Int}()
    levels = LevelStats[]
    if iszero(transaction_count)
        return MiningResult(answer, transaction_count, threshold, levels,
                            timings, time_ns() - mining_started)
    end
    previous = initial_frequent_level!(answer, levels, singletons, threshold)
    isempty(previous) && return MiningResult(answer, transaction_count, threshold, levels,
                                               timings, time_ns() - mining_started)
    singletons = nothing  # let the singleton dictionary become collectible

    itemset_size = 2
    while !isempty(previous)
        level_started = time_ns()
        candidate_type = typeof((first(previous)..., 0))
        current = candidate_type[]
        generation_phase_index = Ref(0)
        candidate_stats = foreach_candidate_batch(previous, candidate_batch_size, NoTrace()) do candidates
            if iszero(generation_phase_index[])
                push!(timings, PhaseTiming(:generate_candidates, itemset_size, UInt64(0), 0, 0))
                generation_phase_index[] = length(timings)
            end
            build_started = time_ns()
            tree = HashTree(candidates)
            workspace = HashQueryWorkspace(tree)
            record_phase!(timings, :build_counter, itemset_size,
                          time_ns() - build_started, length(candidates), 0)

            count_started = time_ns()
            counts = zeros(Int, length(candidates))
            observed = foreach_spmf_transaction(path) do _, transaction
                for candidate_id in matching_ids!(workspace, tree, transaction)
                    counts[candidate_id] += 1
                end
            end
            observed == transaction_count ||
                throw(ArgumentError("input file changed between Apriori passes (transaction count differs)"))
            record_phase!(timings, :count_support, itemset_size,
                          time_ns() - count_started, length(candidates), 0)

            filter_started = time_ns()
            frequent_in_batch = 0
            for candidate_id in eachindex(candidates)
                support = counts[candidate_id]
                if support >= threshold
                    candidate = candidates[candidate_id]
                    push!(current, candidate)
                    answer[candidate] = support
                    frequent_in_batch += 1
                end
            end
            record_phase!(timings, :filter, itemset_size, time_ns() - filter_started,
                          length(candidates), frequent_in_batch)
        end
        candidate_total = candidate_stats.total
        if iszero(generation_phase_index[])
            record_phase!(timings, :generate_candidates, itemset_size,
                          candidate_stats.generation_ns, candidate_total, 0)
        else
            timings[generation_phase_index[]] =
                PhaseTiming(:generate_candidates, itemset_size, candidate_stats.generation_ns,
                            candidate_total, 0)
        end
        if iszero(candidate_total)
            record_phase!(timings, :level_total, itemset_size,
                          time_ns() - level_started, 0, 0)
            break
        end
        push!(levels, LevelStats(itemset_size, candidate_total, length(current)))
        record_phase!(timings, :level_total, itemset_size, time_ns() - level_started,
                      candidate_total, length(current))
        previous = current
        itemset_size += 1
    end

    return MiningResult(answer, transaction_count, threshold, levels, timings,
                        time_ns() - mining_started)
end
