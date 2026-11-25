"""A directed rule, with exact scores for threshold checks and ranking."""
struct BasketRule
    lhs::Tuple{Vararg{Int}}
    rhs::Tuple{Vararg{Int}}
    count::Int
    support::Rational{Int}
    confidence::Rational{Int}
    lift::Rational{Int128}
end

rank_key(r::BasketRule) = (-r.lift, -r.confidence, -r.count, r.lhs, r.rhs)

function confidence_ratio(min_confidence)
    cutoff = try
        FIM.support_ratio(min_confidence)
    catch exc
        exc isa ArgumentError || rethrow()
        throw(ArgumentError("--minconf cần là số thập phân từ 0 đến 1"))
    end
    0 <= cutoff <= 1 || throw(ArgumentError("--minconf phải nằm trong [0, 1]"))
    return cutoff
end

"""Count all qualifying rules and keep the ten highest-ranked ones."""
function rank_rules(result::FIM.MiningResult, cutoff::Rational)
    0 <= cutoff <= 1 || throw(ArgumentError("--minconf phải nằm trong [0, 1]"))
    best = BasketRule[]
    total = 0
    counts, n = result.itemsets, result.transaction_count
    for (items, together) in counts
        length(items) < 2 && continue
        consequents = [(item,) for item in items]
        while !isempty(consequents)
            passed = empty(consequents)
            for rhs in consequents
                lhs = Tuple(item for item in items if !(item in rhs))
                confidence = together // counts[lhs]
                confidence < cutoff && continue
                push!(passed, rhs)
                total += 1
                lift = (Int128(together) * n) // (Int128(counts[lhs]) * counts[rhs])
                rule = BasketRule(lhs, rhs, together, together // n, confidence, lift)
                position = searchsortedfirst(best, rule; by=rank_key)
                if position <= 10
                    insert!(best, position, rule)
                    length(best) > 10 && pop!(best)
                end
            end
            # Growing the consequent can only decrease confidence for this union.
            # Join only consequents that passed, leaving at least one item on the left.
            (length(passed) < 2 || length(first(passed)) + 1 == length(items)) && break
            consequents = FIM.apriori_gen(passed)
        end
    end
    return (; total, rules=best)
end
