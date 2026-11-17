"""Statistics for a level actually counted (Figure 1 of the paper)."""
struct LevelStats
    size::Int
    candidates::Int
    frequent::Int
end

"""Measured monotonic duration for one mining phase; level totals are nested."""
struct PhaseTiming
    phase::Symbol
    size::Int
    elapsed_ns::UInt64
    candidates::Int
    frequent::Int
end

"""All frequent itemsets and integer transaction support counts."""
struct MiningResult
    # Variable-length keys occur only at the result boundary. Counting uses
    # concrete NTuple{K,Int} vectors and Int counters inside each level.
    itemsets::Dict{Tuple{Vararg{Int}},Int}
    transaction_count::Int
    min_support_count::Int
    levels::Vector{LevelStats}
    timings::Vector{PhaseTiming}
    mining_ns::UInt64
end

MiningResult(itemsets, transaction_count, min_support_count, levels) =
    MiningResult(itemsets, transaction_count, min_support_count, levels, PhaseTiming[], UInt64(0))

record_phase!(::Nothing, phase, size, elapsed_ns, candidates, frequent) = nothing
function record_phase!(timings::Vector{PhaseTiming}, phase, size, elapsed_ns, candidates, frequent)
    push!(timings, PhaseTiming(phase, size, elapsed_ns, candidates, frequent))
    return nothing
end

function normalize_transactions(transactions)
    database = Vector{Int}[]
    for (row_number, row) in enumerate(transactions)
        items = Int[]
        for item in row
            if item isa Bool || !(item isa Integer) || item < 0 || item > typemax(Int)
                throw(ArgumentError("transaction $row_number: items must be nonnegative Int values"))
            end
            push!(items, Int(item))
        end
        sort!(items)
        unique!(items)
        push!(database, items)
    end
    return database
end

"""Parse decimal/scientific notation without an intermediate binary float."""
function decimal_ratio(text::AbstractString)
    parsed = match(r"^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$", strip(text))
    parsed === nothing && throw(ArgumentError("min_support must be a finite decimal ratio"))
    sign, whole, fraction, exponent = parsed.captures
    fraction = isnothing(fraction) ? "" : fraction
    isempty(whole) && isempty(fraction) && throw(ArgumentError("min_support has no digits"))
    power = isnothing(exponent) ? 0 : tryparse(Int, exponent)
    (isnothing(power) || abs(big(power)) > 10000) &&
        throw(ArgumentError("min_support exponent is outside the supported range"))
    numerator = parse(BigInt, (isempty(whole) ? "0" : whole) * fraction)
    sign == "-" && (numerator = -numerator)
    scale = length(fraction) - power
    return scale >= 0 ? numerator // big(10)^scale : (numerator * big(10)^(-scale)) // big(1)
end

function support_ratio(value::Rational)
    return big(numerator(value)) // big(denominator(value))
end
support_ratio(value::AbstractString) = decimal_ratio(value)
support_ratio(value::Integer) = big(value) // big(1)
function support_ratio(value::AbstractFloat)
    isfinite(value) || throw(ArgumentError("min_support must be finite"))
    return decimal_ratio(string(value))
end
support_ratio(value) = throw(ArgumentError("min_support must be a decimal string, Integer, Rational or AbstractFloat"))

function support_threshold(n::Int, min_support, min_count)
    isnothing(min_support) == isnothing(min_count) &&
        throw(ArgumentError("provide exactly one of min_support or min_count"))
    if !isnothing(min_count)
        if min_count isa Bool || !(min_count isa Integer) || !(1 <= min_count <= typemax(Int))
            throw(ArgumentError("min_count must be an integer in 1:typemax(Int)"))
        end
        return Int(min_count)
    end
    min_support isa Bool && throw(ArgumentError("min_support cannot be Bool"))
    ratio = support_ratio(min_support)
    0 < ratio <= 1 || throw(ArgumentError("min_support must be in (0, 1]"))
    return Int(cld(numerator(ratio) * n, denominator(ratio)))
end

"""§2.1.1: prefix join followed by membership pruning of every K-subset."""
function apriori_gen(previous::Vector{NTuple{K,Int}}, trace::AbstractAprioriTrace=NoTrace()) where K
    K >= 1 || throw(ArgumentError("previous itemsets must not be empty"))
    ordered = sort!(unique(previous))
    known = Set(ordered)
    candidates = NTuple{K+1,Int}[]
    for i in eachindex(ordered)
        left = ordered[i]
        # Index iteration avoids copying every remaining tail of the list.
        for j in (i + 1):length(ordered)
            right = ordered[j]
            all(left[p] == right[p] for p in 1:(K - 1)) || break
            candidate = (left..., right[K])
            record!(trace, :join, left, right, candidate)
            valid = true
            for removed in 1:(K + 1)
                subset = ntuple(p -> candidate[p + (p >= removed)], Val(K))
                if !(subset in known)
                    record!(trace, :prune, candidate, subset, K)
                    valid = false
                    break
                end
            end
            if valid
                push!(candidates, candidate)
                record!(trace, :accepted, candidate)
            end
        end
    end
    return candidates
end

function count_candidates(candidates::Vector{NTuple{K,Int}}, database::Vector{Vector{Int}},
                          ::Val{:scan}, trace::AbstractAprioriTrace=NoTrace(),
                          timings::Union{Nothing,Vector{PhaseTiming}}=nothing) where K
    # Scan has no reusable counter structure to build.
    record_phase!(timings, :build_counter, K, UInt64(0), length(candidates), 0)
    started = time_ns()
    counts = zeros(Int, length(candidates))
    for (tid, transaction) in enumerate(database)
        record!(trace, :transaction, K, tid, transaction)
        present = Set(transaction)
        for id in eachindex(candidates)
            if all(item in present for item in candidates[id])
                counts[id] += 1
                record!(trace, :increment, tid, candidates[id], counts[id])
            end
        end
    end
    record_phase!(timings, :count_support, K, time_ns() - started, length(candidates), 0)
    return counts
end

function count_candidates(candidates::Vector{NTuple{K,Int}}, database::Vector{Vector{Int}},
                          ::Val{:hash_tree}, trace::AbstractAprioriTrace=NoTrace(),
                          timings::Union{Nothing,Vector{PhaseTiming}}=nothing) where K
    started = time_ns()
    tree = HashTree(candidates)
    workspace = HashQueryWorkspace(tree)
    counts = zeros(Int, length(candidates))
    record_phase!(timings, :build_counter, K, time_ns() - started, length(candidates), 0)
    started = time_ns()
    for (tid, transaction) in enumerate(database)
        record!(trace, :transaction, K, tid, transaction)
        for id in ordered_matches!(trace, matching_ids!(workspace, tree, transaction))
            counts[id] += 1
            record!(trace, :increment, tid, candidates[id], counts[id])
        end
    end
    record_phase!(timings, :count_support, K, time_ns() - started, length(candidates), 0)
    return counts
end

function next_level(previous::Vector{NTuple{K,Int}}, database, threshold, mode,
                    trace::AbstractAprioriTrace=NoTrace(),
                    timings::Union{Nothing,Vector{PhaseTiming}}=nothing) where K
    record!(trace, :level, K+1)
    started = time_ns()
    candidates = apriori_gen(previous, trace)
    record_phase!(timings, :generate_candidates, K+1, time_ns() - started, length(candidates), 0)
    record!(trace, :candidates, K+1, length(candidates))
    isempty(candidates) && return candidates, Int[], 0
    counts = count_candidates(candidates, database, mode, trace, timings)
    started = time_ns()
    frequent = NTuple{K+1,Int}[]
    supports = Int[]
    for id in eachindex(candidates)
        record!(trace, :decision, candidates[id], counts[id], threshold)
        if counts[id] >= threshold
            push!(frequent, candidates[id])
            push!(supports, counts[id])
        end
    end
    explain_frequent!(trace, K+1, frequent, supports)
    record_phase!(timings, :filter, K+1, time_ns() - started, length(candidates), length(frequent))
    return frequent, supports, length(candidates)
end

counter_mode(counter) = counter in (:scan, "scan") ? Val(:scan) :
                        counter in (:hash_tree, "hash-tree") ? Val(:hash_tree) :
                        throw(ArgumentError("counter must be :scan or :hash_tree"))

"""
    mine(transactions; min_support=nothing, min_count=nothing, counter=:hash_tree, explain=nothing)

Plain Apriori (Figure 1): join/prune, scan original transactions, filter L_k.
Pass exactly one support threshold. Empty API rows still contribute to N.
All data is materialized in RAM; §2.1.3 external-memory handling is deferred.
"""
function mine(transactions; min_support=nothing, min_count=nothing, counter=:hash_tree, explain=nothing)
    mining_started = time_ns()
    mode = counter_mode(counter)
    trace = isnothing(explain) ? NoTrace() : explain
    trace isa AbstractAprioriTrace || throw(ArgumentError("explain must be ExplainTrace or nothing"))
    timings = PhaseTiming[]
    started = time_ns()
    database = normalize_transactions(transactions)
    record_phase!(timings, :normalize, 0, time_ns() - started, 0, 0)
    started = time_ns()
    threshold = support_threshold(length(database), min_support, min_count)
    record_phase!(timings, :threshold, 0, time_ns() - started, 0, 0)
    answer = Dict{Tuple{Vararg{Int}},Int}()
    levels = LevelStats[]
    mode_name = mode isa Val{:scan} ? "scan" : "hash-tree"
    record!(trace, :begin, length(database), threshold, mode_name)
    explain_input!(trace, database, min_support, threshold)
    if isempty(database)
        record!(trace, :stop, "CSDL rỗng.")
        finish_explanation!(trace, 0)
        return MiningResult(answer, 0, threshold, levels, timings, time_ns() - mining_started)
    end

    # Figure 1, line 1: count singletons, then select L_1.
    level_started = time_ns()
    started = time_ns()
    singletons = Dict{Int,Int}()
    record!(trace, :level, 1)
    for (tid, transaction) in enumerate(database)
        record!(trace, :transaction, 1, tid, transaction)
        for item in transaction
            singletons[item] = get(singletons, item, 0) + 1
            record!(trace, :increment, tid, (item,), singletons[item])
        end
    end
    record_phase!(timings, :singleton_count, 1, time_ns() - started, length(singletons), 0)
    started = time_ns()
    explain_singletons!(trace, singletons, threshold)
    previous = NTuple{1,Int}[(item,) for (item, count) in singletons if count >= threshold]
    sort!(previous)
    record_phase!(timings, :filter, 1, time_ns() - started, length(singletons), length(previous))
    for itemset in previous
        answer[itemset] = singletons[itemset[1]]
    end
    push!(levels, LevelStats(1, length(singletons), length(previous)))
    # Support values are already in the result; no extra collection when off.
    explain_frequent!(trace, 1, previous, (singletons[itemset[1]] for itemset in previous))
    isempty(previous) && record!(trace, :stop, "L_1 rỗng, không có item frequent.")
    record_phase!(timings, :level_total, 1, time_ns() - level_started, length(singletons), length(previous))

    # next_level is a function barrier: its loops specialize for each K.
    size = 2
    while !isempty(previous)
        level_started = time_ns()
        current, supports, candidate_count = next_level(previous, database, threshold, mode, trace, timings)
        if iszero(candidate_count)
            record!(trace, :stop, "C_$size rỗng, không còn ứng viên để đếm.")
            record_phase!(timings, :level_total, size, time_ns() - level_started, 0, 0)
            break
        end
        push!(levels, LevelStats(size, candidate_count, length(current)))
        for id in eachindex(current)
            answer[current[id]] = supports[id]
        end
        previous = current
        isempty(previous) && record!(trace, :stop, "L_$size rỗng, mọi ứng viên đều dưới ngưỡng.")
        record_phase!(timings, :level_total, size, time_ns() - level_started, candidate_count, length(current))
        size += 1
    end
    finish_explanation!(trace, length(answer))
    return MiningResult(answer, length(database), threshold, levels, timings, time_ns() - mining_started)
end
