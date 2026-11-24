# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\data\benchmarks\mushrooms.txt`
- **Input SHA-256:** `3bc1159b06baa231932810d1d58cbb958684be88b6daa8e3672f8d76c5f0eb98`
- **Số giao tác gốc:** 8416
- **Tỷ lệ lấy mẫu:** 10%, 25%, 50%, 75%, 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.175 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\output\mushrooms_opt_p10_100.csv.samples\manifest.csv`

## Tập con 10%

- **Số giao tác:** 841
- **min_count áp dụng:** 148
- **Sample SHA-256:** `8c6b73f6cbf270175d2fd88f80cc9b2ff098e85cf535de3f2e52a94bb74b9c02`
- **Selected TID SHA-256:** `479698750f081c4e25f9538ab16a4229e965515f5343491504b9f75f19eebaf6`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 3143.354 | 325.09 | 1.0× | 0.0 | PASS |
| bitset | 2056.393 | 312.55 | 1.53× | 3.85 | PASS |
| streaming | 3305.402 | 330.82 | 0.95× | -1.76 | PASS |

- **bitset**: nhanh hơn baseline 34.58%; giảm peak RAM 3.85%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 5.16%; tăng peak RAM 1.76%. Fingerprint: PASS.

## Tập con 25%

- **Số giao tác:** 2104
- **min_count áp dụng:** 369
- **Sample SHA-256:** `8c3d889e26c2c206ee93a239cce7fd37a3d483f8c58727315c21fabbae5af2a4`
- **Selected TID SHA-256:** `d4544e92137aae115d69b18469f24ed54880c8b3ac750a10724e004b5767e353`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 2114.66 | 315.6 | 1.0× | 0.0 | PASS |
| bitset | 1069.666 | 308.77 | 1.98× | 2.17 | PASS |
| streaming | 2189.426 | 323.02 | 0.97× | -2.35 | PASS |

- **bitset**: nhanh hơn baseline 49.42%; giảm peak RAM 2.17%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 3.54%; tăng peak RAM 2.35%. Fingerprint: PASS.

## Tập con 50%

- **Số giao tác:** 4208
- **min_count áp dụng:** 737
- **Sample SHA-256:** `c37dc4d0d10d36258654c527e71c3676325a013acef30fb702bcf9aaa4d98534`
- **Selected TID SHA-256:** `4754305bbdc88a47abc06532b78d174e231764f27af76d6590490d5169d50eb8`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 3045.118 | 324.77 | 1.0× | 0.0 | PASS |
| bitset | 1091.06 | 311.45 | 2.79× | 4.1 | PASS |
| streaming | 3199.799 | 318.99 | 0.95× | 1.78 | PASS |

- **bitset**: nhanh hơn baseline 64.17%; giảm peak RAM 4.1%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 5.08%; giảm peak RAM 1.78%. Fingerprint: PASS.

## Tập con 75%

- **Số giao tác:** 6312
- **min_count áp dụng:** 1105
- **Sample SHA-256:** `271ac27e8fc17f747c8b8ee8ec4fe73cf9d766409e27c0e44f75ef89c31f13c9`
- **Selected TID SHA-256:** `329d362c7c1d4e6468430eb6a2c9941ce982d499bb6b5b154b727b9259522966`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 3912.398 | 326.86 | 1.0× | 0.0 | PASS |
| bitset | 1059.986 | 314.35 | 3.69× | 3.83 | PASS |
| streaming | 4176.143 | 322.4 | 0.94× | 1.36 | PASS |

- **bitset**: nhanh hơn baseline 72.91%; giảm peak RAM 3.83%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 6.74%; giảm peak RAM 1.36%. Fingerprint: PASS.

## Tập con 100%

- **Số giao tác:** 8416
- **min_count áp dụng:** 1473
- **Sample SHA-256:** `37a11571574d74bd1659c830a1e30e120485c6994b79f32e3b6635621a229bf7`
- **Selected TID SHA-256:** `4459a1a5f6d1f97a1c482a8eff56d908107b0e1819e393f54a7ff0f77cabee8c`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 4898.466 | 323.77 | 1.0× | 0.0 | PASS |
| bitset | 1109.414 | 309.92 | 4.42× | 4.28 | PASS |
| streaming | 5225.883 | 325.29 | 0.94× | -0.47 | PASS |

- **bitset**: nhanh hơn baseline 77.35%; giảm peak RAM 4.28%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 6.68%; tăng peak RAM 0.47%. Fingerprint: PASS.

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
