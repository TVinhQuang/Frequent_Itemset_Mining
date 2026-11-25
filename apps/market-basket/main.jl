module MarketBasket

import FrequentItemsetMining as FIM
using DelimitedFiles: readdlm
using Printf: @sprintf

include("rules.jl")

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(ROOT, "src", "AssociationRules.jl"))
const HELP = """
Phân tích giỏ hàng Retail của SPMF bằng Apriori
    julia --project=. apps/market-basket/main.jl [--minsup 0.02] [--minconf 0.50]

    --minsup    Tỷ lệ giỏ tối thiểu chứa cả hai vế, trong (0, 1].
    --minconf   Tỷ lệ tối thiểu giỏ có vế phải trong các giỏ có vế trái, trong [0, 1].
    --help      Hiển thị hướng dẫn.

Mỗi lần chạy tạo retail-rules.csv, top10-rules.csv và report.txt trong output/market-basket/retail-N/.
"""

function options(args)
    values = Dict{String,String}()
    for i in 1:2:length(args)
        flag = args[i]
        flag in ("--minsup", "--minconf") || throw(ArgumentError("tham số lạ $flag"))
        haskey(values, flag) && throw(ArgumentError("tham số lặp $flag"))
        i < length(args) || throw(ArgumentError("thiếu giá trị cho $flag"))
        values[flag] = args[i+1]
    end
    return get(values, "--minsup", "0.02"), get(values, "--minconf", "0.50")
end

function product_names(path)
    data, header = readdlm(path, ',', String; header=true)
    vec(header) == ["item_id", "StockCode", "Description"] ||
        throw(ArgumentError("products.csv cần các cột item_id,StockCode,Description"))
    names = Dict{Int,String}()
    for row in eachrow(data)
        id = tryparse(Int, row[1])
        (isnothing(id) || id < 0 || haskey(names, id) || isempty(strip(row[3]))) &&
            throw(ArgumentError("ID hoặc tên sản phẩm không hợp lệ ở dòng có item_id=$(row[1])"))
        names[id] = row[3]
    end
    return names
end

function csv_cell(text)
    occursin(r"""[,"\r\n]""", text) || return text
    return "\"" * replace(text, "\"" => "\"\"") * "\""
end

score(x) = @sprintf("%.8f", Float64(x))
percent(x) = @sprintf("%.2f%%", 100 * Float64(x))

rule_sides(r::BasketRule) = (r.lhs, r.rhs)
rule_sides(r::AssociationRules.Rule) = (r.antecedent, r.consequent)
side_label(items, ::Nothing) = join(items, ' ')
side_label(items, names) = join((names[id] for id in items), " + ")

function write_results(csv, report, result, ranked, names, minsup, minconf)
    println(csv, "rank,antecedent,consequent,basket_count,support,confidence,lift")
    println(report, isnothing(names) ? "Phân tích giỏ hàng Retail (SPMF)" : "Phân tích giỏ hàng UCI Online Retail")
    println(report, "Số giỏ: ", result.transaction_count)
    println(report, "Minsup: $minsup (ít nhất $(result.min_support_count) giỏ) | Minconf: $minconf")
    println(report, "Tập mục phổ biến: ", length(result.itemsets), " | Luật đạt ngưỡng: ", ranked.total)
    println(report, "Số luật hiển thị: ", length(ranked.rules))
    isempty(ranked.rules) && println(report, "\nKhông có luật đạt hai ngưỡng đã chọn.")
    for (rank, rule) in enumerate(ranked.rules)
        left, right = rule_sides(rule)
        lhs = side_label(left, names)
        rhs = side_label(right, names)
        println(csv, join((rank, csv_cell(lhs), csv_cell(rhs), rule.count,
                           score(rule.support), score(rule.confidence), score(rule.lift)), ','))
        println(report, "\n$rank. $lhs → $rhs")
        println(report, "   Có $(rule.count) giỏ chứa tất cả các món trên (support $(percent(rule.support))).")
        println(report, "   Trong các giỏ có đủ món ở vế trái, $(percent(rule.confidence)) cũng có đủ món ở vế phải.")
        lift_text = @sprintf("%.2f", Float64(rule.lift))
        println(report, "   Tỷ lệ này bằng $lift_text lần tỷ lệ gặp vế phải trong toàn bộ giỏ (lift).")
        if rule.lift > 1
            println(report, "   Có thể thử gợi ý $rhs khi giỏ đã có $lhs.")
        else
            println(report, "   Tỷ lệ mua kèm bằng hoặc thấp hơn mức chung. Ưu tiên thử gợi ý khác.")
        end
    end
end

function main(args=ARGS; data_dir=nothing,
              output_root=joinpath(ROOT, "output", "market-basket"), out=stdout, err=stderr)
    if args == ["--help"]
        print(out, HELP)
        return 0
    end
    try
        minsup, minconf = options(args)
        cutoff = confidence_ratio(minconf)
        input = isnothing(data_dir) ? joinpath(ROOT, "data", "benchmarks", "retail.txt") : joinpath(data_dir, "baskets.txt")
        baskets = FIM.read_spmf(input)
        result = FIM.mine(baskets; min_support=minsup, counter=:hash_tree)
        if isnothing(data_dir)
            counts = Dict{Vector{Int},Int}(collect(items) => n for (items, n) in result.itemsets)
            all_rules = AssociationRules.generate_rules(counts, result.transaction_count; minconf=Float64(cutoff))
            ranked = (total=length(all_rules), rules=first(all_rules, 10))
            names = nothing
            stem = "retail"
        else
            # Explicitly supplied baskets and product catalog use the historical named-product format.
            names = product_names(joinpath(data_dir, "products.csv"))
            for basket in baskets, id in basket
                haskey(names, id) || throw(ArgumentError("products.csv thiếu tên cho item_id=$id"))
            end
            all_rules = nothing
            ranked = rank_rules(result, cutoff)
            stem = "online-retail"
        end
        csv, report = IOBuffer(), IOBuffer()
        write_results(csv, report, result, ranked, names, minsup, minconf)
        dir = FIM.numbered_run_directory(output_root, stem)
        csv_path, report_path = joinpath(dir, "top10-rules.csv"), joinpath(dir, "report.txt")
        rules_path = joinpath(dir, "retail-rules.csv")
        try
            write(csv_path, take!(csv))
            write(report_path, take!(report))
            isnothing(all_rules) || AssociationRules.write_rules_csv(rules_path, all_rules)
        catch
            rm(csv_path; force=true)
            rm(report_path; force=true)
            isnothing(all_rules) || rm(rules_path; force=true)
            isempty(readdir(dir)) && rm(dir)
            rethrow()
        end
        println(out, result.transaction_count, " giỏ | ", length(result.itemsets),
                " tập mục phổ biến | ", ranked.total, " luật đạt ngưỡng.")
        println(out, "Top ", length(ranked.rules), ": ", csv_path)
        isnothing(all_rules) || println(out, "Toàn bộ luật: ", rules_path)
        println(out, "Báo cáo: ", report_path)
        return 0
    catch exc
        if exc isa ArgumentError || exc isa SystemError || exc isa Base.IOError
            println(err, "market-basket: ", sprint(showerror, exc))
            return 2
        end
        rethrow()
    end
end

end # module MarketBasket

if abspath(PROGRAM_FILE) == @__FILE__
    exit(MarketBasket.main())
end
