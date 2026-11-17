abstract type AbstractAprioriTrace end
struct NoTrace <: AbstractAprioriTrace end

"""Stream real Apriori events, limiting detail lines without limiting mining.

    ExplainTrace(io=stderr; limit=5000)

Create a fresh trace for each mine() call. The final summary is always printed,
even when the detail limit was reached. No event history is kept in memory.
"""
mutable struct ExplainTrace{T<:IO} <: AbstractAprioriTrace
    io::T
    limit::Int
    emitted::Int
    truncated::Bool
end

function ExplainTrace(io::IO=stderr; limit=5000)
    if limit isa Bool || !(limit isa Integer) || !(1 <= limit <= typemax(Int))
        throw(ArgumentError("explain limit must be a positive integer fitting Int"))
    end
    return ExplainTrace(io, Int(limit), 0, false)
end

item_text(items) = "{" * join(items, ',') * "}"
record!(::NoTrace, event, args...) = nothing

function record!(trace::ExplainTrace, event::Symbol, args...)
    if trace.emitted >= trace.limit
        if !trace.truncated
            println(trace.io, "[Log đã đạt giới hạn ", trace.limit,
                    " dòng chi tiết; thuật toán vẫn tiếp tục tính đầy đủ.]")
            trace.truncated = true
        end
        return nothing
    end
    text = if event === :begin
        n, threshold, mode = args
        "BẮT ĐẦU Apriori: N=$n; min_count=$threshold; counter=$mode"
    elseif event === :threshold
        ratio, n, threshold = args
        "Ngưỡng support: ceil($ratio × $n) = $threshold"
    elseif event === :input
        tid, row = args
        "Dữ liệu chuẩn hóa: T$tid = $(item_text(row))"
    elseif event === :level
        "MỨC k=$(args[1])"
    elseif event === :transaction
        k, tid, row = args
        "Quét T$tid = $(item_text(row)) (k=$k)"
    elseif event === :increment
        tid, candidate, count = args
        "  T$tid chứa $(item_text(candidate)): count $(count-1) -> $count"
    elseif event === :join
        left, right, candidate = args
        "JOIN $(item_text(left)) + $(item_text(right)) -> $(item_text(candidate))"
    elseif event === :prune
        candidate, subset, k = args
        "PRUNE $(item_text(candidate)): thiếu tập con $(item_text(subset)) trong L_$k -> loại"
    elseif event === :accepted
        "Ứng viên $(item_text(args[1])): qua prune (mọi tập con đều frequent)"
    elseif event === :candidates
        "C_$(args[1]) sau prune: $(args[2]) ứng viên"
    elseif event === :decision
        candidate, count, threshold = args
        count >= threshold ? "GIỮ $(item_text(candidate)): support=$count >= $threshold" :
                             "LOẠI $(item_text(candidate)): support=$count < $threshold"
    elseif event === :frequent
        "L_$(args[1]): $(args[2]) tập phổ biến"
    elseif event === :frequent_item
        "  $(item_text(args[1])) #SUP: $(args[2])"
    elseif event === :stop
        "DỪNG: $(args[1])"
    else
        throw(ArgumentError("unknown Apriori trace event: $event"))
    end
    println(trace.io, text)
    trace.emitted += 1
    return nothing
end

explain_input!(::NoTrace, database, ratio, threshold) = nothing
function explain_input!(trace::ExplainTrace, database, ratio, threshold)
    !isnothing(ratio) && record!(trace, :threshold, ratio, length(database), threshold)
    for (tid, row) in enumerate(database)
        record!(trace, :input, tid, row)
    end
end

explain_singletons!(::NoTrace, counts, threshold) = nothing
function explain_singletons!(trace::ExplainTrace, counts, threshold)
    for item in sort!(collect(keys(counts)))
        record!(trace, :decision, (item,), counts[item], threshold)
    end
end

explain_frequent!(::NoTrace, k, candidates, counts) = nothing
function explain_frequent!(trace::ExplainTrace, k, candidates, counts)
    record!(trace, :frequent, k, length(candidates))
    for (candidate, count) in zip(candidates, counts)
        record!(trace, :frequent_item, candidate, count)
    end
end

ordered_matches!(::NoTrace, ids) = ids
ordered_matches!(::ExplainTrace, ids) = sort!(ids)

finish_explanation!(::NoTrace, total) = nothing
function finish_explanation!(trace::ExplainTrace, total)
    println(trace.io, "KẾT THÚC: ", total,
            " frequent itemsets; support là số giao dịch chứa itemset.")
end
