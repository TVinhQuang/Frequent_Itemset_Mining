module SpliceJunction

import FrequentItemsetMining as FIM
using Printf: @printf

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const GROUPS = ("EI", "IE", "N")
const BASES = "ACGT"
const POSITIONS = (-4, -3, -2, -1, 1, 2, 3, 4)
const HELP = """
    julia --project=. apps/splice-junction/main.jl [--minsup 0.20] [--input splice.data]
Apriori xét 4 nucleotide mỗi bên tâm đoạn. Minsup thuộc (0, 1] và áp dụng riêng cho EI, IE, N.
Kết quả mỗi lần chạy được lưu vào thư mục mới bên trong output/splice-junction/.
"""

function encode(sequence)
    (ncodeunits(sequence) == 60 && all(c -> c in "ACGTDRSN", sequence)) ||
        throw(ArgumentError("cần đúng 60 nucleotide theo bảng ký hiệu của bộ UCI"))
    items = Int[]
    # The boundary is between columns 30 and 31. No position is numbered zero.
    for (slot, base) in enumerate(sequence[27:34])
        index = findfirst(==(base), BASES)
        isnothing(index) || push!(items, 4 * (slot - 1) + index)
    end
    return items
end

function item_label(id)
    slot, base = divrem(id - 1, 4)
    pos = POSITIONS[slot + 1]
    return string(pos > 0 ? "+" : "", pos, ":", BASES[base + 1])
end

function read_groups(path)
    groups = Dict(g => Vector{Int}[] for g in GROUPS)
    open(path) do io
        for (line_num, line) in enumerate(eachline(io))
            isempty(strip(line)) && continue
            fields = strip.(split(line, ','))
            (length(fields) == 3 && fields[1] in GROUPS && !isempty(fields[2])) ||
                throw(ArgumentError("dòng $line_num cần có nhãn EI/IE/N, tên và chuỗi DNA"))
            push!(groups[fields[1]], encode(uppercase(fields[3])))
        end
    end
    all(g -> !isempty(groups[g]), GROUPS) || throw(ArgumentError("dữ liệu cần có đủ ba nhóm EI, IE, N"))
    return groups
end

"""The 32 position/base items fit in one mask. Used only to recount across groups."""
function item_mask(items)
    mask = zero(UInt32)
    for id in items
        mask |= UInt32(1) << (id - 1)
    end
    return mask
end

function compare_groups(groups, minsup)
    results = [FIM.mine(groups[g]; min_support=minsup) for g in GROUPS]
    patterns = union((keys(r.itemsets) for r in results)...)
    masks = [item_mask.(groups[g]) for g in GROUPS]
    ordered = sort!(collect(patterns); by=p -> (length(p), p))
    return map(ordered) do pattern
        wanted = item_mask(pattern)
        counts = ntuple(3) do i
            # Missing from a group's frequent sets means below cutoff, possibly nonzero.
            get(results[i].itemsets, pattern) do
                count(mask -> (mask & wanted) == wanted, masks[i])
            end
        end
        support = ntuple(i -> counts[i] // results[i].transaction_count, 3)
        (; pattern, counts, support)
    end
end

pattern_label(p) = join(item_label.(p), " ")

function write_patterns(path, rows)
    open(path, "w") do io
        println(io, "pattern,size,count_EI,count_IE,count_N,support_EI,support_IE,support_N")
        for row in rows
            print(io, pattern_label(row.pattern), ',', length(row.pattern), ',', join(row.counts, ','))
            for value in row.support
                @printf(io, ",%.8f", value)
            end
            println(io)
        end
    end
end

function write_report(path, groups, minsup, rows)
    cutoff = FIM.support_ratio(minsup)
    open(path, "w") do io
        println(io, "Các mẫu nucleotide quanh điểm nối exon – intron")
        println(io, "Số đoạn: ", join(("$g=$(length(groups[g]))" for g in GROUPS), ", "))
        println(io, "Vị trí: -4..-1, +1..+4. Minsup mỗi nhóm: $minsup. Tổng số mẫu khác nhau: ", length(rows))
        for (i, boundary) in enumerate(("exon → intron", "intron → exon"))
            group = GROUPS[i]
            pairs = filter(r -> length(r.pattern) == 2 && r.support[i] >= cutoff &&
                                r.support[i] > r.support[3], rows)
            println(io, "\n$group ($boundary)")
            if isempty(pairs)
                println(io, "Không có cặp đạt ngưỡng trong $group và phổ biến hơn ở nhóm N.")
                continue
            end
            # The CSV contains all patterns. Choose one pair per boundary for interpretation.
            row = first(sort!(pairs; by=r -> (r.support[3] - r.support[i], -r.support[i], r.pattern)))
            println(io, "Cặp có chênh lệch support lớn nhất so với N: ", pattern_label(row.pattern))
            for (j, g) in enumerate(GROUPS)
                @printf(io, "  %s: %d/%d (%.2f%%)\n", g, row.counts[j], length(groups[g]), 100 * row.support[j])
            end
            println(io, "Trong bộ UCI, hai nucleotide ở đúng hai vị trí này thường đi cùng nhau gần ranh giới $boundary hơn ở tâm các đoạn đối chứng.")
        end
        println(io, "\nCác tỷ lệ mô tả tập dữ liệu đã gán nhãn. Đánh giá khả năng dự đoán điểm nối cần dữ liệu kiểm chứng độc lập.")
    end
end

function main(args=ARGS; output_root=joinpath(ROOT,"output","splice-junction"), out=stdout, err=stderr)
    if args == ["--help"]
        print(out, HELP)
        return 0
    end
    try
        flags = Dict{String,String}()
        for i in 1:2:length(args)
            key = args[i]
            (key in ("--minsup", "--input") && !haskey(flags, key) && i < length(args)) ||
                throw(ArgumentError("tham số không hợp lệ: $key. Xem --help"))
            flags[key] = args[i+1]
        end
        minsup = get(flags, "--minsup", "0.20")
        FIM.support_threshold(1, minsup, nothing)
        path = get(flags, "--input", joinpath(ROOT,"data","splice-junction","splice.data"))
        groups = read_groups(path)
        rows = compare_groups(groups, minsup)
        dir = FIM.numbered_run_directory(output_root, "splice")
        csv, report = joinpath(dir, "patterns.csv"), joinpath(dir, "report.txt")
        try
            write_patterns(csv, rows)
            write_report(report, groups, minsup, rows)
        catch
            rm(csv; force=true)
            rm(report; force=true)
            isempty(readdir(dir)) && rm(dir)
            rethrow()
        end
        println(out, join(("$g=$(length(groups[g]))" for g in GROUPS), ", "), "; mẫu: ", length(rows))
        println(out, "CSV: ", csv)
        println(out, "Báo cáo: ", report)
        return 0
    catch exc
        if exc isa ArgumentError || exc isa SystemError || exc isa Base.IOError
            println(err, "splice-junction: ", sprint(showerror, exc))
            return 2
        end
        rethrow()
    end
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    exit(SpliceJunction.main())
end
