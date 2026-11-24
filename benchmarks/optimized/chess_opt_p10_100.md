# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\data\benchmarks\chess.txt`
- **Input SHA-256:** `a12ea887df58a396709430af5bf0a9a32d1f6eba8e7c13dd41f28b98572c5db2`
- **Số giao tác gốc:** 3196
- **Tỷ lệ lấy mẫu:** 10%, 25%, 50%, 75%, 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.75 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\output\chess_opt_p10_100.csv.samples\manifest.csv`

## Tập con 10%

- **Số giao tác:** 319
- **min_count áp dụng:** 240
- **Sample SHA-256:** `5d8b4aceb1319bf8ce43f8c6791a70387cc495e160fba3fe4076020d90809a6c`
- **Selected TID SHA-256:** `aaa8b4bf695fa5d7008ef34cc4b9a0af55320a7c6435dff1f4a5cad69e2a49f2`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 649.94 | 315.61 | 1.0× | 0.0 | PASS |
| bitset | 460.51 | 301.62 | 1.41× | 4.43 | PASS |
| streaming | 679.932 | 320.86 | 0.96× | -1.66 | PASS |

- **bitset**: nhanh hơn baseline 29.15%; giảm peak RAM 4.43%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 4.61%; tăng peak RAM 1.66%. Fingerprint: PASS.

## Tập con 25%

- **Số giao tác:** 799
- **min_count áp dụng:** 600
- **Sample SHA-256:** `4590906d980f42eeabc0fb9a29167ad650ab7384c36430992aea3a8e7c0d5e95`
- **Selected TID SHA-256:** `02b1ef5554d79316669fa2cd767f1572620a01eda32bf3c87b3fe5c5a93721db`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 1010.809 | 312.92 | 1.0× | 0.0 | PASS |
| bitset | 484.351 | 297.43 | 2.09× | 4.95 | PASS |
| streaming | 1051.018 | 310.65 | 0.96× | 0.72 | PASS |

- **bitset**: nhanh hơn baseline 52.08%; giảm peak RAM 4.95%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 3.98%; giảm peak RAM 0.72%. Fingerprint: PASS.

## Tập con 50%

- **Số giao tác:** 1598
- **min_count áp dụng:** 1199
- **Sample SHA-256:** `feeedf0b3eb840e4bae81cdf03d55ba3f999bb2a8244ca4d93e9053c726bffc6`
- **Selected TID SHA-256:** `a22227da2ea32a6f30467a7c001d95b28a6923950e3da6e205fdf831f356c0c4`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 1691.074 | 307.4 | 1.0× | 0.0 | PASS |
| bitset | 601.078 | 294.57 | 2.81× | 4.18 | PASS |
| streaming | 1768.689 | 310.2 | 0.96× | -0.91 | PASS |

- **bitset**: nhanh hơn baseline 64.46%; giảm peak RAM 4.18%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 4.59%; tăng peak RAM 0.91%. Fingerprint: PASS.

## Tập con 75%

- **Số giao tác:** 2397
- **min_count áp dụng:** 1798
- **Sample SHA-256:** `a999155381d982619d407838889d56e31e211e3dc9ce33ebf9d8de253e0425c0`
- **Selected TID SHA-256:** `0579445aaefe7e9019ebf87449e7e0bcb3ab3a8a09dca0fbda492200968618dd`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 2176.267 | 309.9 | 1.0× | 0.0 | PASS |
| bitset | 536.813 | 304.38 | 4.05× | 1.78 | PASS |
| streaming | 2282.591 | 309.26 | 0.95× | 0.21 | PASS |

- **bitset**: nhanh hơn baseline 75.33%; giảm peak RAM 1.78%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 4.89%; giảm peak RAM 0.21%. Fingerprint: PASS.

## Tập con 100%

- **Số giao tác:** 3196
- **min_count áp dụng:** 2397
- **Sample SHA-256:** `341d0ff8676e053dd3b417d61f84c732736154f987ce56975a099b07460957f5`
- **Selected TID SHA-256:** `9839ab3742fa5c949f6dacaeb5b8930277a6cf0410b68cf9be1392dd1eb8e43f`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 2703.06 | 312.05 | 1.0× | 0.0 | PASS |
| bitset | 623.774 | 302.91 | 4.33× | 2.93 | PASS |
| streaming | 2922.71 | 307.81 | 0.92× | 1.36 | PASS |

- **bitset**: nhanh hơn baseline 76.92%; giảm peak RAM 2.93%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 8.13%; giảm peak RAM 1.36%. Fingerprint: PASS.

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
