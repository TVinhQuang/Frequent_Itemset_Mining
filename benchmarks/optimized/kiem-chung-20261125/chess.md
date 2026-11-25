# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `data/benchmarks/chess.txt`
- **Input SHA-256:** `a12ea887df58a396709430af5bf0a9a32d1f6eba8e7c13dd41f28b98572c5db2`
- **Số giao tác gốc:** 3196
- **Tỷ lệ lấy mẫu:** 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.75 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `benchmarks/optimized/kiem-chung-20261125/chess.csv.samples/manifest.csv`

## Tập con 100%

- **Số giao tác:** 3196
- **min_count áp dụng:** 2397
- **Sample SHA-256:** `341d0ff8676e053dd3b417d61f84c732736154f987ce56975a099b07460957f5`
- **Selected TID SHA-256:** `9839ab3742fa5c949f6dacaeb5b8930277a6cf0410b68cf9be1392dd1eb8e43f`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 2354.467 | 303.75 | 1.0× | 0.0 | PASS |
| bitset | 269.894 | 294.89 | 8.72× | 2.92 | PASS |
| streaming | 2621.628 | 306.44 | 0.9× | -0.88 | PASS |

- **bitset**: nhanh hơn baseline 88.54%; giảm peak RAM 2.92%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 11.35%; tăng peak RAM 0.88%. Fingerprint: PASS.

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
