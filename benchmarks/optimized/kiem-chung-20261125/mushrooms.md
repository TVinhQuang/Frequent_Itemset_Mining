# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `data/benchmarks/mushrooms.txt`
- **Input SHA-256:** `3bc1159b06baa231932810d1d58cbb958684be88b6daa8e3672f8d76c5f0eb98`
- **Số giao tác gốc:** 8416
- **Tỷ lệ lấy mẫu:** 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.175 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `benchmarks/optimized/kiem-chung-20261125/mushrooms.csv.samples/manifest.csv`

## Tập con 100%

- **Số giao tác:** 8416
- **min_count áp dụng:** 1473
- **Sample SHA-256:** `37a11571574d74bd1659c830a1e30e120485c6994b79f32e3b6635621a229bf7`
- **Selected TID SHA-256:** `4459a1a5f6d1f97a1c482a8eff56d908107b0e1819e393f54a7ff0f77cabee8c`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 4982.216 | 316.91 | 1.0× | 0.0 | PASS |
| bitset | 735.288 | 305.54 | 6.78× | 3.59 | PASS |
| streaming | 5577.87 | 317.45 | 0.89× | -0.17 | PASS |

- **bitset**: nhanh hơn baseline 85.24%; giảm peak RAM 3.59%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 11.96%; tăng peak RAM 0.17%. Fingerprint: PASS.

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
