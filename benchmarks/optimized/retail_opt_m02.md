# Báo cáo so sánh hiệu năng Apriori theo quy mô tập giao tác

- **Input gốc:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\data\benchmarks\retail.txt`
- **Input SHA-256:** `732c26de19888cb570d3fbb97e47206a9b1c0ce064f85dc1403314ba38f04eaa`
- **Số giao tác gốc:** 88162
- **Tỷ lệ lấy mẫu:** 100%
- **Seed:** 42 (có thể tái lập)
- **Minsup:** 0.02 (quy đổi thành min_count riêng theo từng tập con)
- **Baseline:** `hash-tree`
- **Warm-up / repeats:** 1 / 3
- **Candidate batch size:** 10000
- **Julia / OS / kiến trúc:** 1.13.4 / NT / x86_64
- **Manifest và các file mẫu:** `D:\Thien Quoc\Subjects\KTDL\PJ Frequent itemset mining\Frequent_Itemset_Mining_external_memory_v4 - Copy\Frequent_Itemset_Mining-main\output\retail_opt_m02.csv.samples\manifest.csv`

## Tập con 100%

- **Số giao tác:** 88162
- **min_count áp dụng:** 1764
- **Sample SHA-256:** `417563fb5feb3711d4f761230ca78b76d100fe2ee0d3178fcc4fbb000d8d1c36`
- **Selected TID SHA-256:** `8233451f80b123a0c6676ead7eac10be951162d051742a9891e89feb4cf9089d`

| Engine | Median (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp baseline |
|---|---:|---:|---:|---:|---|
| baseline-hash-tree | 296.113 | 319.69 | 1.0× | 0.0 | PASS |
| bitset | 240.989 | 292.82 | 1.23× | 8.41 | PASS |
| streaming | 775.146 | 313.98 | 0.38× | 1.79 | PASS |

- **bitset**: nhanh hơn baseline 18.62%; giảm peak RAM 8.41%. Fingerprint: PASS.
- **streaming**: chậm hơn baseline 161.77%; giảm peak RAM 1.79%. Fingerprint: PASS.

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
