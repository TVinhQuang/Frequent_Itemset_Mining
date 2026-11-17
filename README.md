# Apriori từ bài báo — Julia

Cài đặt Apriori bằng Julia từ mô tả trong *Fast Algorithms for Mining Association Rules* của Rakesh Agrawal và Ramakrishnan Srikant. Mã nguồn được tự viết từ bài báo, không dùng mã SPMF hoặc thư viện khai phá tập phổ biến (FIM). Xem [giải thích thuật toán và liên hệ mã nguồn](docs/apriori-paper.md).

Phạm vi hiện tại là tìm **toàn bộ frequent itemsets không rỗng cùng support count**. Chương trình giữ các bước join, prune và quét CSDL theo từng mức của Apriori; dữ liệu được nạp vào RAM.

## Clone và chuẩn bị

Cần Git và Julia **1.9 trở lên**; đặt lệnh `julia` trong PATH. Dự án chỉ dùng thư viện chuẩn, không cần cài dependency bên ngoài. Clone kho nhóm rồi chạy mọi lệnh bên dưới từ thư mục gốc:

```sh
git clone https://github.com/TVinhQuang/Frequent_Itemset_Mining.git
cd Frequent_Itemset_Mining
julia --project=. test/runtests.jl
```

CLI và bộ kiểm thử Julia dùng được trên Windows, macOS và Linux. Script chạy đủ 8 CSDL bên dưới cần PowerShell. Nếu Julia chưa nằm trong PATH, có thể truyền `-Julia "C:/path/to/julia.exe"` cho script trên Windows; thay đường dẫn mẫu bằng vị trí cài Julia của bạn.

Mỗi lần chạy CLI thành công **tự lưu kết quả và thời gian thực đo vào một thư mục mới**. Để chạy đủ 8 CSDL × 2 bộ đếm, có diễn giải từng bước, dùng ngay lệnh PowerShell sau tại thư mục gốc:

```powershell
./bin/test-kit.ps1 -Explain
```

Terminal in đường dẫn batch mới `output/test-kit/runs/<batch-id>/`. Mở `<counter>/<dataset>/report.txt` trong batch để xem **toàn bộ itemsets, support count, support tương đối và bảng thời gian từng giai đoạn**. `trace.txt` giải thích các bước thực thi; `results.csv` ở gốc batch tổng hợp PASS/FAIL, `MiningMs`, `CliMs`, `ProcessWallMs` và `ReportPath`. Các file này được tạo lại từ lần chạy thực tế hiện tại; chạy lại sẽ giữ thêm một batch, không ghi đè lịch sử.

## Yêu cầu và chạy nhanh

Dùng Julia **1.9 trở lên**, chỉ cần thư viện chuẩn, không có dependency bên ngoài. Chạy các lệnh từ thư mục gốc dự án với `--project=.` để nạp package `FrequentItemsetMining`:

```sh
mkdir output
julia --project=. bin/apriori.jl --input data/toy/paper.txt --output output/paper.txt --minsup 0.5 --counter hash-tree --trace
```

Với CSDL riêng, thay đường dẫn input và chọn ngưỡng phù hợp với dữ liệu. `0.01` dưới đây chỉ là ví dụ cú pháp, không phải ngưỡng đề xuất cho mọi CSDL:

```sh
julia --project=. bin/apriori.jl --input /path/to/dataset.txt --output output/dataset.txt --minsup 0.01 --counter hash-tree --warmup 1
```

Thư mục cha của `--output` phải có sẵn; ví dụ này dùng `output` đã tạo ở trên. Đặt đường dẫn trong dấu nháy nếu có khoảng trắng.

Nếu thư mục `output` đã tồn tại, bỏ qua lệnh `mkdir`. `--trace` ghi số ứng viên C_k và tập phổ biến L_k theo từng mức lên stderr; file kết quả chỉ chứa các dòng SPMF. Có thể thay `--minsup 0.5` bằng `--min-count 2` để đặt support count tối thiểu trực tiếp. Chỉ chọn một trong hai ngưỡng.

Để chạy cùng dữ liệu bằng bộ đếm trực tiếp:

```sh
julia --project=. bin/apriori.jl --input data/toy/paper.txt --output output/paper-scan.txt --min-count 2 --counter scan --trace
julia --project=. bin/apriori.jl --help
```

Hai bộ đếm dùng chung vòng lặp Apriori:

- `scan`: thử từng ứng viên có nằm trong transaction hay không, thuận tiện để đọc và đối chiếu.
- `hash-tree` (mặc định): lưu ứng viên trong hash-tree theo §2.1.2 của bài báo, duyệt các nhánh phù hợp rồi kiểm tra đầy đủ tại lá; mỗi ứng viên chỉ được đếm một lần trong mỗi transaction, kể cả khi hash collision xảy ra.

Chưa có kết quả benchmark để khẳng định hash-tree nhanh hơn scan.

## Xem từng bước Apriori

`--explain` ghi diễn giải tiếng Việt lên stderr: transaction sau chuẩn hóa, ngưỡng count, từng mức k, cặp join, ứng viên qua prune hoặc bị loại kèm tập con thiếu, số ứng viên C_k sau prune, support tăng trong từng transaction, quyết định giữ/loại và L_k cùng support, rồi lý do dừng. Các dòng này được phát ngay từ lần chạy khai phá thực tế, không chạy lại thuật toán để dựng log. File `--output` vẫn chỉ chứa kết quả SPMF.

Chạy riêng bộ 01 và giữ mọi file trong cùng một thư mục mới bằng PowerShell:

```powershell
$run = "output/runs/" + (Get-Date -Format "yyyyMMddTHHmmssfff") + "_" + [Guid]::NewGuid().ToString()
julia --project=. bin/apriori.jl --input Apriori_Test_Kit_8_Datasets/datasets/01_spmf_example.txt --report-dir $run --output "$run/itemsets.txt" --minsup 0.40 --counter hash-tree --explain-file "$run/trace.txt"
Get-Content -LiteralPath "$run/report.txt" -Encoding UTF8
```

`--report-dir PATH` phải là thư mục **chưa tồn tại**; CLI tự tạo nó và các thư mục cha cần thiết. Không tạo sẵn `$run`. Nếu không đặt tùy chọn này, bundle tự nằm trong `<output-parent>/runs/<UTC-timestamp_uuid>/`; thư mục cha của output/log bên ngoài bundle phải có sẵn. `--quiet` chỉ ẩn thông báo thành công, vẫn ghi báo cáo.

`--explain-file PATH` tự bật diễn giải; không cần thêm `--explain`. Dùng `--explain` thay cho `--explain-file` nếu muốn xem diễn giải trên stderr; khi đó không có bản lưu `trace.txt` trong bundle. Ba đường dẫn input, output và diễn giải phải khác nhau, kể cả khi cùng trỏ tới một file qua alias hoặc hardlink. `--explain-limit N` nhận số nguyên dương, mặc định **5.000 dòng chi tiết**. Khi đạt giới hạn, chương trình báo cắt log, vẫn khai phá đầy đủ và luôn ghi tổng kết cuối; giới hạn này không giới hạn số itemsets. `--trace` vẫn dùng được để xem thống kê ngắn theo mức.

Với `hash-tree`, diễn giải cho biết các ứng viên thực sự khớp transaction sau kiểm tra collision và lần tăng count của chúng; không ghi từng bucket hay nút cây. Bộ 01 ở ngưỡng count 2 không có ứng viên bị prune loại; việc không thấy dòng `PRUNE` trong log này là bình thường. Xem [ví dụ tạo prune thực tế](docs/apriori-paper.md#11-đọc-diễn-giải-của-lần-chạy-thực-tế) để quan sát trường hợp đó.

## Đọc báo cáo và so sánh thời gian

| File trong mỗi bundle | Nội dung |
| --- | --- |
| `itemsets.txt` | Toàn bộ frequent itemsets và support count theo dạng SPMF. |
| `report.txt` | Báo cáo tiếng Việt: dữ liệu, tham số, toàn bộ itemsets/count/tỷ lệ và bảng timing theo mức k. |
| `timings.csv` | Số đo gốc `elapsed_ns`, kèm `elapsed_ms`, phase, k, số ứng viên và số frequent. |
| `metadata.toml` | SHA256 input và mã nguồn, thời điểm UTC, Julia/OS/CPU/threads, ngưỡng và cờ warmup/explain để đối chiếu. |
| `trace.txt` | Diễn giải thực thi nếu dùng `--explain-file` hoặc script `-Explain`. |

Timing dùng đồng hồ monotonic `time_ns()`. Các phase gồm chuẩn hóa, tính ngưỡng, đếm singleton, sinh ứng viên **join + prune gộp chung**, dựng bộ đếm, đếm support và lọc. Hash-tree tách thời gian dựng cây/workspace khỏi quét transaction; scan ghi `build_counter = 0`. `level_total` bao gồm các phase con, nên **không cộng mọi dòng timing**. Lần sinh C_k rỗng cuối cùng vẫn có timing dù không thêm mức đã đếm vào `levels`.

`MiningMs` đo `mine()`, không gồm đọc input/ghi output, nhưng có thể chứa JIT, GC và chi phí diễn giải. `CliMs` gồm xử lý CLI, đọc/ghi kết quả và warmup, kết thúc trước đối chiếu hash cuối và ghi bundle; không gồm khởi động Julia. `read_input` gồm đọc một snapshot, SHA256 và parse chính các bytes đó. `ProcessWallMs` do PowerShell đo quanh tiến trình Julia, gồm khởi động, biên dịch và ghi báo cáo. Các phạm vi này khác nhau.

Metadata giữ hash input đã parse và hash mã nguồn trước mining. Nếu các file đổi trong khi chạy, hash cuối và cờ `input_changed_after_read` / `implementation_changed_during_run` ghi rõ sự khác biệt; không gắn kết quả cũ với dữ liệu mới.

Mặc định `--warmup 0`: chỉ một lượt khai phá được đo. Có thể thêm `--warmup 1` vào CLI, hoặc `-Warmup 1` vào script, để chạy một lượt không diễn giải trước lượt đo. Warmup được ghi thời gian riêng và không nằm trong `MiningMs`; nó không bảo đảm loại hết JIT, nhất là khi lượt đo bật explain hoặc dùng kiểu IO khác. Explain làm tăng chi phí định dạng/IO trong các phase. Khi so sánh, giữ cùng input SHA256, ngưỡng, counter, runtime và cờ warmup/explain; kiểm tra SHA256 mã nguồn để biết phiên bản nào đã thay đổi. Đây là số đo của **một lượt thực tế**, chưa phải trung bình benchmark hay bằng chứng hash-tree nhanh hơn scan.

## Ví dụ trong bài báo

`data/toy/paper.txt` chứa đúng bốn transaction của Figure 3:

```text
1 3 4
2 3 5
1 2 3 5
2 5
```

Với `--minsup 0.5` (tương đương `--min-count 2`), kết quả mong đợi là chín itemsets sau, sắp theo độ dài rồi thứ tự từ điển:

```text
1 #SUP: 2
2 #SUP: 3
3 #SUP: 3
5 #SUP: 3
1 3 #SUP: 2
2 3 #SUP: 2
2 5 #SUP: 3
3 5 #SUP: 2
2 3 5 #SUP: 2
```

## Dùng API

```julia
using FrequentItemsetMining

transactions = [[1, 3, 4], [2, 3, 5], [1, 2, 3, 5], [2, 5]]
result = mine(transactions; min_support="0.5", counter=:hash_tree)

println(result.itemsets[(2, 5)])  # 3
println(result.transaction_count)  # 4
println(result.min_support_count)  # 2
for level in result.levels
    println((level.size, level.candidates, level.frequent))
end
```

`result.itemsets` ánh xạ tuple item tăng dần sang support count. Có thể dùng `min_count=2` thay cho `min_support`, hoặc `counter=:scan` để đổi bộ đếm. API nhận mỗi transaction là một iterable các số nguyên không âm nằm trong miền `Int` của máy (không nhận `Bool`) và giữ transaction rỗng trong tổng số transaction.

Để xem diễn giải bằng API, tạo một `ExplainTrace` mới cho mỗi lần gọi:

```julia
rows = [[1, 2], [1, 2], [1, 3], [1, 3]]
result = mine(rows; min_count=2, explain=ExplainTrace(stdout))
# Có thể đặt ExplainTrace(stdout; limit=1000); mặc định không truyền explain là tắt.
```

`result.timings` chứa các `PhaseTiming(phase, size, elapsed_ns, candidates, frequent)`; `result.mining_ns` là tổng thời gian `mine()`. API trả dữ liệu đo trong bộ nhớ; CLI tự lưu bundle qua [reports.jl](src/reports.jl).

Module chính là [src/FrequentItemsetMining.jl](src/FrequentItemsetMining.jl), gồm [explain.jl](src/explain.jl), [apriori.jl](src/apriori.jl), [hash_tree.jl](src/hash_tree.jl), [io.jl](src/io.jl), [reports.jl](src/reports.jl) và [cli.jl](src/cli.jl). Mỗi mức dùng `NTuple{K,Int}` cụ thể trong vòng đếm; hash-tree tái sử dụng `BitVector` trên chỉ số item đã nén tọa độ, không cấp bộ nhớ theo ID lớn nhất. Đây là lựa chọn cấu trúc dữ liệu, chưa phải kết luận benchmark.

## Quy ước dữ liệu

- File đầu vào theo định dạng transaction SPMF: mỗi dòng gồm các item nguyên không âm, cách nhau bằng khoảng trắng. Bỏ qua dòng trắng và dòng chú thích bắt đầu bằng `#`, `%` hoặc `@`.
- Item trong một transaction được sắp tăng và loại trùng. Các dòng transaction giống nhau vẫn được tính riêng; support là số transaction chứa itemset.
- Tỷ lệ support phải thuộc `(0, 1]`; API nhận chuỗi thập phân/khoa học, `Integer`, `Rational` hoặc `AbstractFloat` hữu hạn (không nhận `Bool` hay mọi kiểu `Real` khác). Ngưỡng count là `ceil(tỷ lệ × số transaction)`. CLI xử lý chuỗi thập phân bằng phân số chính xác để tránh sai số làm tròn nhị phân. `min_count` phải là số nguyên ít nhất 1.
- Token lỗi trong file đầu vào được báo kèm số dòng. Không dùng cùng file làm đầu vào và đầu ra.
- File đầu ra dùng dạng `1 2 3 #SUP: 4`. Chương trình chỉ tìm frequent itemsets, chưa sinh luật kết hợp.

## Năm CSDL nhỏ đi kèm

| File trong `data/toy/` | Nội dung và mục đích |
| --- | --- |
| `paper.txt` | 4 transaction đúng ví dụ Figure 3; kiểm tra chín itemsets có support xác định ở trên. |
| `duplicates.txt` | Item lặp, thứ tự tùy ý và transaction lặp; kiểm tra chuẩn hóa item và giữ số dòng transaction. |
| `disjoint.txt` | Các transaction không giao nhau; hỗ trợ kiểm tra trường hợp không có cặp phổ biến. |
| `dense.txt` | Nhiều transaction chia sẻ các tập con; tạo frequent itemsets ở nhiều mức. |
| `sparse.txt` | Ít item mỗi transaction, có item 0 và ID rất lớn; kiểm tra dữ liệu thưa mà không cấp bộ nhớ theo ID lớn nhất. |

## Kiểm thử và trạng thái

### Chạy bộ 8 CSDL bổ sung

Từ terminal PowerShell tại thư mục gốc dự án, chạy:

```powershell
./bin/test-kit.ps1
```

Script mặc định gọi `julia` trong PATH. Script đọc `Apriori_Test_Kit_8_Datasets/manifest.json`, dùng đúng minsup của từng bộ, chạy cả `scan` và `hash-tree`, rồi so sánh toàn bộ itemsets/support với `expected/` mà không phụ thuộc thứ tự dòng. Script trả lỗi nếu Julia chạy thất bại hoặc có kết quả không khớp.

Thêm `-Explain` để lưu diễn giải cho cả 16 lần chạy:

```powershell
./bin/test-kit.ps1 -Explain
```

Mỗi lần gọi script tạo `output/test-kit/runs/<batch-id>/` mới. Mỗi dataset/counter có bundle tại `<counter>/<dataset>/`, ví dụ `hash-tree/01_spmf_example/report.txt` và `trace.txt`. Script in thời gian khai phá/thời gian tiến trình và đường dẫn batch, đồng thời vẫn đối chiếu đầy đủ itemsets/support.

Kết quả được giữ ở:

- `output/test-kit/runs/<batch-id>/scan/<dataset>/`: bundle của bộ đếm trực tiếp.
- `output/test-kit/runs/<batch-id>/hash-tree/<dataset>/`: bundle của bộ đếm hash-tree.
- `output/test-kit/runs/<batch-id>/results.csv`: đối chiếu itemsets/support, PASS/FAIL, `MiningMs`, `CliMs`, `ProcessWallMs`, `ReportPath`, run-id và cờ explain/warmup.

Các output phẳng cũ tại `output/test-kit/scan/`, `hash-tree/` và `results.csv` được giữ nguyên; chúng không phải kết quả của batch mới.

Lượt chạy ngày 2026-11-16 bằng Julia 1.13.4: **16/16 PASS** (8 CSDL × 2 bộ đếm), không thiếu/thừa itemset hay sai support. Số itemsets của các bộ 01–08 lần lượt là **15, 3, 6, 15, 0, 7, 1, 6**. Bộ 05 có output rỗng là đúng; bộ 07 dùng `ceil(0.43 × 7) = 4`.

Để chạy riêng một CSDL và xem trace:

```powershell
julia --project=. bin/apriori.jl --input Apriori_Test_Kit_8_Datasets/datasets/01_spmf_example.txt --output output/test-kit/example.txt --minsup 0.40 --counter hash-tree --trace
```

Thư mục output phải tồn tại trước khi chạy riêng CLI. Chạy script toàn bộ ở trên sẽ tạo sẵn `output/test-kit/`. Đáp án của bộ test là kết quả vét cạn độc lập, chưa phải kết quả chạy SPMF/Java thật; bộ này cũng không thay thế benchmark lớn.

### Kiểm thử nội bộ

Chạy bộ kiểm thử Julia bằng thư viện chuẩn `Test` và `Random`:

```sh
julia --project=. test/runtests.jl
```

Kiểm thử đối chiếu đầy đủ itemsets/support với oracle vét cạn độc lập trên CSDL nhỏ, ví dụ bài báo, join/prune, hai bộ đếm, hash collision và I/O/CLI. Mã kiểm thử nằm trong `test/`, được chạy từ `test/runtests.jl`.

**Lần xác minh Julia gần nhất (2026-11-17):** chạy thực tế bằng Julia 1.13.4, toàn bộ **2.813 assertions** vượt qua, gồm timing, báo cáo, history, hash snapshot và bảo vệ đường dẫn bên cạnh các kiểm tra thuật toán/trace trước đó. Hai batch thật đều đạt **16/16 PASS**: có giải thích/không warmup, và không giải thích/`Warmup=1`. Batch sau được kiểm tra đủ 16 bundle, cùng hash nguồn, đúng hash snapshot và không có cờ file thay đổi. Script cũng đã chạy hai lần trên fixture để xác nhận lịch sử cũ không đổi. Các kiểm tra trước đó đối chiếu 20 kết quả CLI trên 5 CSDL toy với oracle vét cạn độc lập. `@inferred` kiểm tra đạt cho join và cả hai vòng đếm khi tắt diễn giải. Chưa chạy trực tiếp bằng Julia 1.9.

```text
Test Summary:         | Pass  Total
FrequentItemsetMining | 2813   2813
```

Chưa chạy đối chiếu với chương trình SPMF/Java thật; hỗ trợ định dạng SPMF không đồng nghĩa đã xác minh khớp SPMF. Đã có thời gian từng lần chạy; benchmark lặp lại trên dữ liệu lớn và đo bộ nhớ, sinh luật kết hợp cùng hai ứng dụng giỏ hàng/sinh học vẫn là bước sau. Chưa triển khai quản lý bộ đệm ngoài RAM của §2.1.3.
