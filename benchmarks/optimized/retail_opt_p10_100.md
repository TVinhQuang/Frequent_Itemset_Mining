# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\data\benchmarks\retail.txt`
- **Input SHA-256:** `732c26de19888cb570d3fbb97e47206a9b1c0ce064f85dc1403314ba38f04eaa`
- **Số giao tác gốc:** 88162
- **Tỷ lệ lấy mẫu:** 10%, 25%, 50%, 75%, 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.05 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\output\retail_opt_p10_100.csv.samples\manifest.csv`

## Tập con 10%

- **Số giao tác:** 8816
- **min_count áp dụng:** 441
- **Sample SHA-256:** `584514aad3fa23bdce3084a7c6fa4df4c15539b5b46bae1966f1db9aecdc7e2c`
- **Selected TID SHA-256:** `5693329e671559193afe6f8226c336f0e661b15a41f3f6e13fdeeccbfcc2f3b8`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 25.738 | 305.95 | 1.0× | 0.0 | PASS |
| bitset | 28.513 | 298.13 | 0.9× | 2.55 | PASS |
| streaming | 44.033 | 302.03 | 0.58× | 1.28 | PASS |

- **bitset**: chậm hơn baseline 10.78%; giảm peak RAM 2.55%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 71.08%; giảm peak RAM 1.28%. Fingerprint: PASS.

## Tập con 25%

- **Số giao tác:** 22040
- **min_count áp dụng:** 1102
- **Sample SHA-256:** `a9a3006f0364407720d569efa16c2be783a765e53e60d2f1b89c9708cf73d916`
- **Selected TID SHA-256:** `13a2012ed7b23b03fd50f29b3b7d9501e6a4383e878573af86957ec81182c727`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 45.434 | 312.97 | 1.0× | 0.0 | PASS |
| bitset | 53.845 | 294.62 | 0.84× | 5.86 | PASS |
| streaming | 90.162 | 301.75 | 0.5× | 3.59 | PASS |

- **bitset**: chậm hơn baseline 18.51%; giảm peak RAM 5.86%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 98.45%; giảm peak RAM 3.59%. Fingerprint: PASS.

## Tập con 50%

- **Số giao tác:** 44081
- **min_count áp dụng:** 2205
- **Sample SHA-256:** `ca41804f89994fae8250b8d2d214e3658d7d0b08b96e1e1cfe4a519338bfed45`
- **Selected TID SHA-256:** `57fb424dad2ed377e1169cfc3ca0b670b2da08618681aeec60f877297ae528f0`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 106.768 | 305.57 | 1.0× | 0.0 | PASS |
| bitset | 205.892 | 298.21 | 0.52× | 2.41 | PASS |
| streaming | 322.568 | 300.69 | 0.33× | 1.6 | PASS |

- **bitset**: chậm hơn baseline 92.84%; giảm peak RAM 2.41%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 202.12%; giảm peak RAM 1.6%. Fingerprint: PASS.

## Tập con 75%

- **Số giao tác:** 66121
- **min_count áp dụng:** 3307
- **Sample SHA-256:** `9e58da628d4778b9adaadd680771b4ea6beb7286bd91d63bb7f73e20384bc0e4`
- **Selected TID SHA-256:** `31af33f90a6889ddf9e24b30fbf86734a59bda321b7d96a3c37524c0a86b9653`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 218.982 | 316.23 | 1.0× | 0.0 | PASS |
| bitset | 319.194 | 300.74 | 0.69× | 4.9 | PASS |
| streaming | 520.474 | 301.48 | 0.42× | 4.66 | PASS |

- **bitset**: chậm hơn baseline 45.76%; giảm peak RAM 4.9%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 137.68%; giảm peak RAM 4.66%. Fingerprint: PASS.

## Tập con 100%

- **Số giao tác:** 88162
- **min_count áp dụng:** 4409
- **Sample SHA-256:** `417563fb5feb3711d4f761230ca78b76d100fe2ee0d3178fcc4fbb000d8d1c36`
- **Selected TID SHA-256:** `8233451f80b123a0c6676ead7eac10be951162d051742a9891e89feb4cf9089d`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 297.263 | 315.9 | 1.0× | 0.0 | PASS |
| bitset | 440.196 | 292.88 | 0.68× | 7.29 | PASS |
| streaming | 366.794 | 305.32 | 0.81× | 3.35 | PASS |

- **bitset**: chậm hơn baseline 48.08%; giảm peak RAM 7.29%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 23.39%; giảm peak RAM 3.35%. Fingerprint: PASS.

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
