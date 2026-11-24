# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\data\benchmarks\pumsb.txt`
- **Input SHA-256:** `441b9df08e4be4f5369ada7fd2a53de5d98e617f17be87cceb29d3802ee8d65a`
- **Số giao tác gốc:** 49046
- **Tỷ lệ lấy mẫu:** 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.88 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\output\pumsb_opt_m88.csv.samples\manifest.csv`

## Tập con 100%

- **Số giao tác:** 49046
- **min_count áp dụng:** 43161
- **Sample SHA-256:** `f7e73ff6e80ad94592f51a0e69cc4bd00ca0279f458378890d91c6f4833e6039`
- **Selected TID SHA-256:** `67029e1910c3a13288cbb868f5e847894b8e7413aee1202809b7044059559d4f`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 105913.69 | 345.92 | 1.0× | 0.0 | PASS |
| bitset | 780.651 | 298.93 | 135.67× | 13.58 | PASS |
| streaming | 106187.78 | 317.69 | 1.0× | 8.16 | PASS |

- **bitset**: nhanh hơn baseline 99.26%; giảm peak RAM 13.58%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 0.26%; giảm peak RAM 8.16%. Fingerprint: PASS.

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
