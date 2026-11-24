# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\data\benchmarks\pumsb.txt`
- **Input SHA-256:** `441b9df08e4be4f5369ada7fd2a53de5d98e617f17be87cceb29d3802ee8d65a`
- **Số giao tác gốc:** 49046
- **Tỷ lệ lấy mẫu:** 10%, 25%, 50%, 75%, 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.92 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\output\pumsb_opt_p10_100.csv.samples\manifest.csv`

## Tập con 10%

- **Số giao tác:** 4904
- **min_count áp dụng:** 4512
- **Sample SHA-256:** `bcea8c20f86454e18f7929414c80451ac3e82590bce1acdddc5487d05112e418`
- **Selected TID SHA-256:** `f71456f906cd6b8730ecd3da765bdfce743111a9758ad2512f2de4fd4d10afc7`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 1256.682 | 311.98 | 1.0× | 0.0 | PASS |
| bitset | 116.0 | 294.32 | 10.83× | 5.66 | PASS |
| streaming | 1484.133 | 310.2 | 0.85× | 0.57 | PASS |

- **bitset**: nhanh hơn baseline 90.77%; giảm peak RAM 5.66%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 18.1%; giảm peak RAM 0.57%. Fingerprint: PASS.

## Tập con 25%

- **Số giao tác:** 12261
- **min_count áp dụng:** 11281
- **Sample SHA-256:** `f4c878863b3f32ab52df3d70f2d3e794cf28468d709761dd0a41fbbd5c7ba6ce`
- **Selected TID SHA-256:** `61b3022ad7b8b7a75f7df0eb28b783831abda901906f5217f973b201ed8caf10`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 3308.562 | 309.66 | 1.0× | 0.0 | PASS |
| bitset | 215.012 | 296.18 | 15.39× | 4.35 | PASS |
| streaming | 3884.658 | 309.45 | 0.85× | 0.07 | PASS |

- **bitset**: nhanh hơn baseline 93.5%; giảm peak RAM 4.35%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 17.41%; giảm peak RAM 0.07%. Fingerprint: PASS.

## Tập con 50%

- **Số giao tác:** 24523
- **min_count áp dụng:** 22562
- **Sample SHA-256:** `1cabb4af339e0070acf84b7d398b37dced024995195ddcd38834f3617084b3b3`
- **Selected TID SHA-256:** `9318759d5cb7c15cae4ced2d75d9cb6f348ec85fb1ce2fb76dfbd655e126cbd8`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 7051.534 | 308.86 | 1.0× | 0.0 | PASS |
| bitset | 380.675 | 296.75 | 18.52× | 3.92 | PASS |
| streaming | 7950.88 | 320.41 | 0.89× | -3.74 | PASS |

- **bitset**: nhanh hơn baseline 94.6%; giảm peak RAM 3.92%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 12.75%; tăng peak RAM 3.74%. Fingerprint: PASS.

## Tập con 75%

- **Số giao tác:** 36784
- **min_count áp dụng:** 33842
- **Sample SHA-256:** `8cfd86a0b5e809fb05b3609f7e8a2f9025ac4cc6a6bac3d4a32be69914a01286`
- **Selected TID SHA-256:** `b4587fd08cb8b64e520b4eb00b29771acff85643f83b6b1bb459eaa6ec4c86bc`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 10863.165 | 323.21 | 1.0× | 0.0 | PASS |
| bitset | 528.228 | 296.85 | 20.57× | 8.15 | PASS |
| streaming | 12063.615 | 323.53 | 0.9× | -0.1 | PASS |

- **bitset**: nhanh hơn baseline 95.14%; giảm peak RAM 8.15%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 11.05%; tăng peak RAM 0.1%. Fingerprint: PASS.

## Tập con 100%

- **Số giao tác:** 49046
- **min_count áp dụng:** 45123
- **Sample SHA-256:** `f7e73ff6e80ad94592f51a0e69cc4bd00ca0279f458378890d91c6f4833e6039`
- **Selected TID SHA-256:** `67029e1910c3a13288cbb868f5e847894b8e7413aee1202809b7044059559d4f`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 14094.146 | 336.12 | 1.0× | 0.0 | PASS |
| bitset | 631.186 | 298.93 | 22.33× | 11.06 | PASS |
| streaming | 16058.373 | 318.99 | 0.88× | 5.1 | PASS |

- **bitset**: nhanh hơn baseline 95.52%; giảm peak RAM 11.06%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 13.94%; giảm peak RAM 5.1%. Fingerprint: PASS.

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
