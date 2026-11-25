# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `data/benchmarks/pumsb.txt`
- **Input SHA-256:** `441b9df08e4be4f5369ada7fd2a53de5d98e617f17be87cceb29d3802ee8d65a`
- **Số giao tác gốc:** 49046
- **Tỷ lệ lấy mẫu:** 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.92 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `benchmarks/optimized/kiem-chung-20261125/pumsb.csv.samples/manifest.csv`

## Tập con 100%

- **Số giao tác:** 49046
- **min_count áp dụng:** 45123
- **Sample SHA-256:** `f7e73ff6e80ad94592f51a0e69cc4bd00ca0279f458378890d91c6f4833e6039`
- **Selected TID SHA-256:** `67029e1910c3a13288cbb868f5e847894b8e7413aee1202809b7044059559d4f`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 15740.302 | 334.18 | 1.0× | 0.0 | PASS |
| bitset | 712.275 | 296.46 | 22.1× | 11.28 | PASS |
| streaming | 16874.718 | 317.57 | 0.93× | 4.97 | PASS |

- **bitset**: nhanh hơn baseline 95.47%; giảm peak RAM 11.28%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 7.21%; giảm peak RAM 4.97%. Fingerprint: PASS.

## Quy trình lấy mẫu và giới hạn đo
Giao thức APRIORI-V1: parse SPMF theo thứ tự nguồn; bỏ dòng trống và metadata;
sắp item và bỏ item trùng trong mỗi giao tác, nhưng giữ giao tác trùng nội dung.
Xếp hạng TID theo SHA-256 của chuỗi `apriori-v1|seed|tid` tăng dần, tie-break bằng TID;
chọn đúng `floor(N*p/100)` TID đầu, rồi ghi lại theo thứ tự nguồn.
Mẫu 100% giữ toàn bộ giao tác theo thứ tự nguồn sau chuẩn hóa.
Mỗi engine ở cùng tỷ lệ nhận cùng một file mẫu. Việc tạo file mẫu nằm ngoài thời gian
và peak RAM của process engine. `median_ms` gồm đọc/parse file mẫu và khai phá.
`peak_ram_mib` là peak RSS/working set của process con, gồm Julia runtime và warm-up.
Với `--minsup`, support count được tính lại theo số transaction của từng tập con;
với `--min-count`, ngưỡng đếm tuyệt đối được giữ nguyên ở cả năm quy mô.
Manifest lưu SHA-256 của input, sample và danh sách TID được chọn để kiểm toán.
Fingerprint là kiểm tra nhất quán giữa các engine; test oracle nên đối chiếu
mapping itemset → support đầy đủ.
