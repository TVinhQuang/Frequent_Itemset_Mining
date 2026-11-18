# Hướng dẫn agent chạy benchmark Apriori của nhóm

Làm phần của **một dataset được giao** trong `Retail/`, `Chess/`, `Mushrooms/` hoặc `Pumsb/`. Mỗi đợt hoàn tất có một bảng chung ở `<Dataset>/run-N/results.csv`. Giữ các đợt cũ để đối chiếu trước và sau tối ưu. Thư mục chưa có kết quả chỉ chứa tệp rỗng `.gitkeep` để Git mang thư mục sang máy khác.

## Chuẩn bị

- Dùng bản transaction trong mục **Frequent Itemset mining / Datasets in SPMF format**. Mỗi dòng là một giao dịch. Lưu file gốc và ghi nhận SHA256. [Danh mục dataset chính thức](https://www.philippe-fournier-viger.com/spmf/datasets.php)
- Dùng Julia của project và Java chạy được SPMF. Đợt Retail dùng Julia 1.13.4, Java 27 và **SPMF 2.68**, SHA256 JAR `2cc2d89e39909230ea0455da4a1c79b389dc98ca04b0670befb63e679b5e2ea0`. Để so trực tiếp, dùng cùng JAR và ghi phiên bản thực tế. Thuật toán tham chiếu trên CLI có tên chính xác là `Apriori`. [Tải SPMF](https://www.philippe-fournier-viger.com/spmf/index.php?link=download.php) · [Cú pháp Apriori](https://www.philippe-fournier-viger.com/spmf/Apriori.php)
- Mở terminal ở thư mục chứa `Project.toml`. Runner hỗ trợ Windows và Linux có GNU `/usr/bin/time`. Đặt `java` trong PATH. Chạy lần lượt trên cùng máy, cùng chế độ nguồn, hạn chế tải nền. Ghi rõ khi số liệu thuộc các máy khác nhau.

## Chọn cấu hình

Chọn **5–7 mức minsup giảm dần** trên mẫu 100% và một ngưỡng ở giữa dãy để dùng cho mọi cỡ mẫu. Đơn vị trong lệnh là **điểm cơ bản** (bp), 100 bp = 1%. Retail dùng `1000,750,500,300,200` tức 10%, 7,5%, 5%, 3%, 2%. Ngưỡng giữa là 500 bp. Với Chess, Mushrooms hoặc Pumsb, thử ngưỡng cao trên mẫu nhỏ để chọn dãy khả thi cho dữ liệu dày. Chốt dãy trước đợt đo chính thức và giữ nguyên qua các phiên bản tối ưu. Ghi lại timeout hoặc thiếu RAM nếu có và giữ log của lần đó.

Ví dụ tái lập **Retail** trên PowerShell, sửa đường dẫn đến Julia và JAR cho phù hợp máy. Đối với dataset được giao, thay tên dataset, file nguồn, dãy bp và ngưỡng giữa.

```powershell
$julia = 'D:/Tools/Julia-1.13.4-apriori/julia-1.13.4/bin/julia.exe'
$env:JULIA_DEPOT_PATH = 'D:/Tools/JuliaDepot-apriori'
$jar = 'D:/Tools/spmf-apriori/spmf.jar'
& $julia --startup-file=no --threads=1 --project=. bin/benchmark.jl Retail data/dataset_train/retail.txt $jar 1000,750,500,300,200 500
```

## Cách lấy cùng một mẫu

1. Đọc giao dịch theo thứ tự nguồn, bỏ dòng trống và metadata SPMF, sắp mã item trong từng giỏ và bỏ item trùng trong giỏ. Giữ các giao dịch trùng nội dung. Đánh số các giao dịch hợp lệ từ 1 đến N.
2. Với giao dịch có chỉ số `i`, tính SHA256 của chuỗi UTF-8 `apriori-v1|42|i` (thay `i` bằng số thập phân, không có ký tự xuống dòng). Sắp chỉ số theo digest hex tăng dần, giữ thứ tự chỉ số nếu hòa. Seed là **42**.
3. Với p = 10, 25, 50, 75, 100 lấy đúng **floor(N × p/100)** chỉ số đầu tiên của cùng thứ hạng. Sắp lại các chỉ số đã chọn theo thứ tự nguồn, ghi mỗi giỏ một dòng, khoảng trắng đơn và LF. Mẫu nhỏ luôn nằm trong mẫu lớn. Mẫu 100% chứa toàn bộ giao dịch hợp lệ theo thứ tự ban đầu.
4. Dùng cùng **file mẫu vật lý**, cùng minsup và cùng số giao dịch cho cả ba bản. Ngưỡng đếm Julia là `ceil(N_mẫu × bp / 10000)`. SPMF nhận phần trăm, ví dụ `5%`. Kiểm tra `sample_sha256` và `selected_tid_sha256` khi chạy lại. Hash thứ hai tính trên các chỉ số đã chọn theo thứ tự nguồn, mỗi chỉ số một dòng LF kể cả dòng cuối.

## Các phép đo

- Chạy toàn bộ dãy ngưỡng trên mẫu 100%. Chạy thêm 10%, 25%, 50%, 75% ở ngưỡng giữa. Dùng lại điểm 100% của ngưỡng giữa cho đường scalability. Dãy 5 ngưỡng tạo **9 cấu hình, 27 dòng CSV, 81 tiến trình đo**.
- Mỗi cấu hình có **3 lần lặp**. Mỗi lần chạy riêng Julia `scan` (bản cơ bản), Julia `hash-tree` (bản dùng cây băm để đếm) và Java SPMF `Apriori`. Runner luân phiên thứ tự để mỗi bản đứng đầu, giữa và cuối đúng một lần. Mỗi lượt dùng tiến trình mới, không warmup trong tiến trình, không bật diễn giải. Worker Julia gọi trực tiếp `read_spmf`, `mine` và `write_spmf`.
- **Thời gian so sánh giữa các bản** là `*_wall_ms`, từ khởi động tiến trình tới khi kết thúc, gồm nạp runtime/JIT, đọc dữ liệu, khai phá và ghi itemsets. Dùng trung vị của 3 lần. `*_native_ms` dùng để phân tích nội bộ. Julia đo `mine()`, SPMF tự in “Total time”; phạm vi hai đồng hồ khác nhau.
- **RAM so sánh** là `*_peak_mib` (1 MiB = 1.048.576 byte) của toàn tiến trình, gồm runtime, dữ liệu và kết quả. Windows đọc giá trị đỉnh working set do hệ điều hành tích lũy, thăm dò khoảng 10 ms và đọc thêm khi kết thúc. Linux dùng GNU time `%M` đổi từ KiB. Báo cáo trung vị của 3 đỉnh, và có thể ghi thêm đỉnh lớn nhất quan sát được. Dùng cùng hệ điều hành và cách đo cho các bản cần so tốc độ/RAM.

## Dữ liệu phải có trong results.csv

Một dòng biểu diễn một bộ **dataset, cỡ mẫu, minsup, lần lặp** và chứa kết quả của cả ba bản. Dùng header do runner sinh. Đơn vị và định nghĩa của cột giống nhau giữa các dataset.

| Nhóm | Các trường và cách dùng |
|---|---|
| Nhận dạng | `protocol`, `dataset`, `run`, `started_utc`, `seed`, `raw_sha256`, `source_sha256`, `harness_sha256`, `spmf_version`, `jar_sha256`. Hash nguồn Julia giúp ghép đúng bản trước/sau tối ưu. |
| Môi trường | `julia_version`, `java_version`, `os`, `arch`, `cpu`, `host_ram_bytes`, `os_threads`, `julia_threads`, `java_active_processors`. |
| Cấu hình | `sample_pct`, `transactions`, `distinct_items`, `mean_width`, `sample_sha256`, `selected_tid_sha256`, `minsup_bp`, `min_count`, `rep`, `engine_order`. |
| Kết quả mỗi bản | Tiền tố `scan_`, `hash_tree_`, `spmf_`. Sau tiền tố có `itemsets`, `output_sha256`, `wall_ms`, `peak_mib`, `native_ms`, `missing`, `extra`, `wrong_support`, `match_pct`. |
| Kiểm tra và truy vết | `status` là PASS khi cả hai bản Julia khớp từng tập và từng support với SPMF. `evidence` dẫn tới thư mục dữ liệu gốc của lần đo trong workspace. |

So toàn bộ ánh xạ **itemset → support count** bằng khóa gồm các mã số được sắp tăng. Bỏ các dòng metadata `@` của SPMF. Tỷ lệ khớp = 100 × số itemset chung có cùng support / số itemset trong hợp của hai đầu ra. Nếu cả hai rỗng thì đạt 100%. Hash đầu ra dùng các khóa chuẩn sắp theo thứ tự từ điển của chuỗi, mỗi dòng dạng `1 2 #SUP: 15` và kết thúc bằng LF. Bảng giữ hash của cả ba bản. Tệp `spmf.txt` là đối chứng để tra support từng itemset.

## Bàn giao và đọc kết quả

1. Kiểm tra đủ tổ hợp và lần lặp, mọi thời gian và RAM dương, số frequent itemsets và hash kết quả ổn định qua các lần lặp. Giữ và điều tra dòng `MISMATCH` bằng hai file itemsets. Một đợt gián đoạn chỉ có `progress.csv` trong phần dữ liệu gốc. Bảng hoàn chỉnh là `benchmarks/<Dataset>/run-N/results.csv`.
2. Toàn bộ mẫu, file support và log từng tiến trình ở `output/benchmarks/<Dataset>/run-N/`. Trong `p<P>-bp<B>/rep-<R>/` có `scan.txt`, `hash-tree.txt`, `spmf.txt` và ba log. Log Julia có thời gian và số ứng viên mỗi mức k. `output/` đang được Git bỏ qua. Khi cần người khác kiểm toán từng support, gửi thêm thư mục bằng chứng hoặc chia sẻ đường dẫn kho dữ liệu của nhóm.
3. Với mẫu 100%, vẽ trung vị thời gian và số frequent itemsets theo minsup. Ở ngưỡng giữa, vẽ trung vị thời gian theo số giao dịch. So RAM của hai bản Julia ở mẫu 100% và ngưỡng giữa. Khi mọi output khớp, cùng một đường số lượng có thể biểu diễn cả ba bản.
4. Để đánh giá thay đổi mã nguồn, ghép dòng theo dataset, hash mẫu, ngưỡng đếm, bản đếm, môi trường và giao thức. Tính hệ số tăng tốc = trung vị thời gian trước / sau; mức giảm RAM (%) = 100 × (RAM trước − sau) / RAM trước. Giữ riêng mốc Julia cơ bản, bản cây băm và SPMF. Khi một tỉ số dưới 1 hoặc RAM tăng, báo cáo kết quả thực đo.

### Gửi một file cho cả nhóm

Trên Windows, có thể tạo một hình bốn biểu đồ và gói toàn bộ kết quả thành **một file ZIP**. Gói chứa bảng CSV, mọi file itemsets/support, mọi log của cả ba bản và hình nếu có. Nhóm có thể mở trực tiếp bằng File Explorer. Bảng CSV nằm riêng bên cạnh để tiện ghép kết quả giữa các dataset. Các file mẫu tái tạo được từ nguồn, seed và hash trong CSV.

```powershell
$csv = 'benchmarks/Retail/run-3/results.csv'   # Đổi theo dòng CSV mà runner vừa in
$first = Import-Csv -LiteralPath $csv | Select-Object -First 1
$png = "output/benchmarks/$($first.dataset)/$($first.run)/figures.png"
./bin/plot-benchmark.ps1 -Csv $csv -Png $png
./bin/package-benchmark.ps1 -Csv $csv
```
