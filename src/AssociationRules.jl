"""
    AssociationRules

Sinh luật kết hợp `X => Y` từ các frequent itemset đã khai phá bằng Apriori.

Đầu vào là file itemsets theo định dạng SPMF (`1 3 5 #SUP: 42`) và tổng số
transaction `N`. Với mỗi itemset phổ biến `Z` và mỗi cách tách `Z = X ∪ Y`
(X, Y khác rỗng, rời nhau):

    support(X ⇒ Y)    = sup(Z) / N
    confidence(X ⇒ Y) = sup(Z) / sup(X)
    lift(X ⇒ Y)       = confidence / (sup(Y) / N) = sup(Z)·N / (sup(X)·sup(Y))

Do tính chất Apriori, mọi tập con của `Z` đều phổ biến nên `sup(X)` và `sup(Y)`
luôn có sẵn trong file itemsets; không cần quét lại dữ liệu.

Module chỉ dùng thư viện chuẩn của Julia và không có trạng thái toàn cục.
Kết quả được sắp theo thứ tự toàn phần (lift ↓, confidence ↓, count ↓, rồi
antecedent/consequent tăng dần) nên chạy lại luôn cho cùng một đầu ra.
"""
module AssociationRules

export Rule, read_itemsets, count_transactions, generate_rules, write_rules_csv

"Số item tối đa của một itemset được tách luật (2^k phép tách)."
const MAX_ITEMSET_SIZE = 24
const SUP_MARK = "#SUP:"
const EPS = 1e-12

"Một luật kết hợp `antecedent ⇒ consequent` cùng các chỉ số đo."
struct Rule
    antecedent::Vector{Int}
    consequent::Vector{Int}
    count::Int          # sup(X ∪ Y), số transaction chứa cả hai vế
    support::Float64
    confidence::Float64
    lift::Float64
end

"""
    read_itemsets(path) -> Dict{Vector{Int},Int}

Đọc file itemsets SPMF. Khóa là vector item đã sắp tăng, giá trị là support count.
Bỏ qua dòng trống và dòng metadata bắt đầu bằng `@`, `%` hoặc `#`.
"""
function read_itemsets(path::AbstractString)
    counts = Dict{Vector{Int},Int}()
    for (ln, line) in enumerate(eachline(path))
        s = strip(line)
        (isempty(s) || s[1] in ('@', '%', '#')) && continue
        pos = findfirst(SUP_MARK, s)
        pos === nothing && throw(ArgumentError("$path:$ln: thiếu '$SUP_MARK'"))
        left = strip(s[1:prevind(s, first(pos))])
        right = strip(s[(last(pos) + 1):end])
        items = try
            sort!(parse.(Int, split(left)))
        catch
            throw(ArgumentError("$path:$ln: item không phải số nguyên"))
        end
        isempty(items) && continue
        counts[items] = try
            parse(Int, right)
        catch
            throw(ArgumentError("$path:$ln: support count không hợp lệ"))
        end
    end
    return counts
end

"""
    count_transactions(path) -> Int

Đếm số transaction hợp lệ của file dữ liệu SPMF (bỏ dòng trống và metadata).
"""
function count_transactions(path::AbstractString)
    n = 0
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || s[1] in ('#', '%', '@')) && continue
        n += 1
    end
    return n
end

function _rule_isless(a::Rule, b::Rule)
    a.lift != b.lift && return a.lift > b.lift
    a.confidence != b.confidence && return a.confidence > b.confidence
    a.count != b.count && return a.count > b.count
    a.antecedent != b.antecedent && return a.antecedent < b.antecedent
    return a.consequent < b.consequent
end

function _rules_from_itemset!(rules::Vector{Rule}, counts::Dict{Vector{Int},Int},
                              items::Vector{Int}, supxy::Int, ntrans::Int,
                              minconf::Float64, minlift::Float64)
    k = length(items)
    full = (1 << k) - 1
    @inbounds for mask in 1:(full - 1)      # mọi tập con khác rỗng và khác toàn bộ
        ant = Int[]
        con = Int[]
        for j in 1:k
            if (mask >> (j - 1)) & 1 == 1
                push!(ant, items[j])
            else
                push!(con, items[j])
            end
        end
        supx = get(counts, ant, 0)
        supy = get(counts, con, 0)
        if supx == 0 || supy == 0
            throw(ArgumentError("thiếu support của tập con $(supx == 0 ? ant : con) " *
                                "trong file itemsets (file không đầy đủ?)"))
        end
        conf = supxy / supx
        conf + EPS < minconf && continue
        lift = Float64(supxy * ntrans) / Float64(supx * supy)
        lift + EPS < minlift && continue
        push!(rules, Rule(ant, con, supxy, supxy / ntrans, conf, lift))
    end
    return rules
end

"""
    generate_rules(counts, ntrans; minconf=0.5, minlift=0.0) -> Vector{Rule}

Sinh mọi luật có confidence ≥ `minconf` và lift ≥ `minlift`, đã sắp xếp
(lift giảm dần, hòa thì confidence, count, rồi thứ tự từ điển).
"""
function generate_rules(counts::Dict{Vector{Int},Int}, ntrans::Integer;
                        minconf::Real=0.5, minlift::Real=0.0)
    ntrans > 0 || throw(ArgumentError("ntrans phải > 0"))
    0 <= minconf <= 1 || throw(ArgumentError("minconf phải nằm trong [0, 1]"))
    minlift >= 0 || throw(ArgumentError("minlift phải >= 0"))
    rules = Rule[]
    for (items, supxy) in counts
        length(items) < 2 && continue
        if length(items) > MAX_ITEMSET_SIZE
            throw(ArgumentError("itemset có $(length(items)) item, vượt giới hạn " *
                                "$MAX_ITEMSET_SIZE; hãy tăng minsup"))
        end
        _rules_from_itemset!(rules, counts, items, supxy, Int(ntrans),
                             Float64(minconf), Float64(minlift))
    end
    sort!(rules; lt=_rule_isless)
    return rules
end

"Ghi luật ra CSV: antecedent, consequent (item cách nhau bằng khoảng trắng), count, support, confidence, lift."
function write_rules_csv(path::AbstractString, rules::Vector{Rule})
    dir = dirname(path)
    isempty(dir) || mkpath(dir)
    open(path, "w") do io
        println(io, "antecedent,consequent,count,support,confidence,lift")
        for r in rules
            println(io, join(r.antecedent, ' '), ',', join(r.consequent, ' '), ',',
                    r.count, ',', r.support, ',', r.confidence, ',', r.lift)
        end
    end
    return path
end

end # module
