#!/usr/bin/env julia
# Sinh luật kết hợp từ file frequent itemsets (đầu ra của bin/apriori.jl).
#
#   julia --project=. bin/rules.jl --itemsets output/retail.txt \
#         --data data/benchmarks/retail.txt --minconf 0.5 --top 10 \
#         --out output/retail-rules.csv

include(joinpath(@__DIR__, "..", "src", "AssociationRules.jl"))
using .AssociationRules

const USAGE = """
Cách dùng: julia --project=. bin/rules.jl --itemsets FILE (--data FILE | --ntrans N) [tùy chọn]

  --itemsets FILE   file itemsets SPMF do apriori.jl tạo ra (dòng "1 2 #SUP: 7")
  --data FILE       file transaction gốc, dùng để đếm tổng số transaction N
  --ntrans N        cho trực tiếp N thay cho --data
  --minconf X       ngưỡng confidence trong [0,1] (mặc định 0.5)
  --minlift X       ngưỡng lift tối thiểu (mặc định 0)
  --top K           in K luật đầu theo lift (mặc định 10)
  --out FILE        ghi toàn bộ luật ra CSV
"""

function parse_options(args::Vector{String})
    opts = Dict{String,String}()
    i = 1
    while i <= length(args)
        a = args[i]
        if a in ("-h", "--help")
            print(USAGE)
            exit(0)
        end
        startswith(a, "--") || error("tham số không hợp lệ: $a")
        i < length(args) || error("thiếu giá trị cho $a")
        opts[a] = args[i + 1]
        i += 2
    end
    return opts
end

fmt(v::Vector{Int}) = "{" * join(v, ", ") * "}"

function main(args::Vector{String})
    opts = parse_options(args)
    haskey(opts, "--itemsets") || error("cần --itemsets FILE\n\n" * USAGE)
    n = if haskey(opts, "--ntrans")
        parse(Int, opts["--ntrans"])
    elseif haskey(opts, "--data")
        count_transactions(opts["--data"])
    else
        error("cần --data FILE hoặc --ntrans N\n\n" * USAGE)
    end
    minconf = parse(Float64, get(opts, "--minconf", "0.5"))
    minlift = parse(Float64, get(opts, "--minlift", "0"))
    top = parse(Int, get(opts, "--top", "10"))

    counts = read_itemsets(opts["--itemsets"])
    rules = generate_rules(counts, n; minconf=minconf, minlift=minlift)

    println("Transaction N = $n | itemsets = $(length(counts)) | " *
            "luật (minconf=$minconf, minlift=$minlift) = $(length(rules))")
    for (i, r) in enumerate(first(rules, top))
        println(lpad(i, 3), ". ", fmt(r.antecedent), " => ", fmt(r.consequent),
                " | count=", r.count,
                " sup=", round(r.support; digits=4),
                " conf=", round(r.confidence; digits=4),
                " lift=", round(r.lift; digits=3))
    end
    if haskey(opts, "--out")
        write_rules_csv(opts["--out"], rules)
        println("Đã ghi ", length(rules), " luật vào ", opts["--out"])
    end
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
