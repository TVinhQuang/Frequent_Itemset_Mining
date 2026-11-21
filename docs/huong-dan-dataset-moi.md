# Chạy Apriori trên dataset mới

Apriori khai phá các nhóm item thường xuất hiện cùng nhau trong một giao dịch. Mỗi lần chạy tạo danh sách nhóm item, số giao dịch chứa từng nhóm (support count) và thời gian khai phá. Bạn có thể dùng toàn bộ dataset cho một lần đo, không cần nhãn hay chia train/test.

## 1. Chuẩn bị file giao dịch

Mở PowerShell tại thư mục gốc của project (thư mục chứa `Project.toml`). Tạo thư mục để chứa các bộ dữ liệu của bạn.

```powershell
New-Item -ItemType Directory -Force -Path data/benchmarks | Out-Null
```

Mỗi dataset là **một file TXT UTF-8**, mỗi dòng là **một giao dịch**, mỗi item là **một số nguyên không âm**, cách nhau bằng khoảng trắng. Ví dụ, file `data/benchmarks/gio_hang.txt` có thể chứa ba đơn hàng sau.

```text
10 20
10 30
10 20 30
```

Nếu dữ liệu gốc là CSV/Excel có các cột `MaDon, SanPham`, hãy gom các dòng cùng mã đơn thành một giỏ. Nếu sản phẩm là tên, gán mỗi tên một ID cố định và lưu bảng tra để đọc lại kết quả. Ví dụ, gán sữa = 10, bánh mì = 20 và trứng = 30. Chỉ ghi ID sản phẩm vào file TXT. Giữ nguyên các đơn hàng khác nhau dù mua cùng một giỏ. Một sản phẩm lặp trong cùng đơn chỉ đóng góp một lần vào support. Lưu bảng tra ở ngoài thư mục quét dataset.

## 2. Chạy một dataset

Chọn Julia trong phiên PowerShell hiện tại. Đoạn này dùng Julia trong PATH nếu có, hoặc dùng bản portable ở vị trí đã cài trên máy của nhóm.

```powershell
$cmdJulia = Get-Command julia -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cmdJulia) {
    $julia = $cmdJulia.Source
} else {
    $julia = 'D:/Tools/Julia-1.13.4-apriori/julia-1.13.4/bin/julia.exe'
    $env:JULIA_DEPOT_PATH = 'D:/Tools/JuliaDepot-apriori'
}
```

Dùng lệnh dưới đây sau khi lưu `gio_hang.txt`. Bạn cũng có thể đổi `$file` thành `'data/toy/paper.txt'` để thử ngay với dữ liệu sẵn có.

```powershell
$file = 'data/benchmarks/gio_hang.txt'
& $julia --project=. bin/apriori.jl --input $file --minsup 0.50 --counter hash-tree --warmup 1
if ($LASTEXITCODE -ne 0) { throw 'Apriori chạy lỗi. Xem thông báo phía trên.' }
```

Với ví dụ ba giỏ ở trên, `--minsup 0.50` giữ các nhóm xuất hiện trong ít nhất `ceil(3 × 0.50) = 2` giao dịch. Dòng `10 20 #SUP: 2` có nghĩa là 2 trong 3 đơn mua cả sữa và bánh mì. Với dữ liệu khác, bạn có thể đổi `0.50` hoặc thay `--minsup 0.50` bằng `--min-count 2` nếu muốn đặt số giao dịch tối thiểu trực tiếp. Với dataset lớn hoặc giỏ dài, thử ngưỡng cao trước, rồi hạ dần vì số nhóm cần xét có thể tăng rất nhanh.

Terminal in đường dẫn thư mục vừa tạo ở dòng `Report:`. Mỗi dataset có dãy số riêng trong `output/runs/`, bắt đầu từ 1. Mở `report.txt` trong đó để xem tổng quan, `timings.csv` để xem thời gian theo từng mức và `metadata.toml` để tra ngưỡng, phiên bản Julia, hash dữ liệu và mã nguồn.

### Chạy bộ Retail của SPMF

File Retail nằm ở `data/benchmarks/retail.txt`. Nếu cần tải lại trên máy khác, mở mục **Datasets for Frequent Itemset mining → Datasets in SPMF format**, nhấp chuột phải vào **retail**, chọn **Save link as…** và lưu với cùng đường dẫn. [Trang danh mục SPMF](https://www.philippe-fournier-viger.com/spmf/datasets.php) · [File retail.txt gốc](https://www.philippe-fournier-viger.com/spmf/publicdatasets/retail.txt)

Từ thư mục gốc, sau khi khai báo `$julia` như ở bước 2, chạy đoạn sau. Ngưỡng 5% tương ứng ít nhất 4.409 trong 88.162 giao dịch. Mỗi lần chạy tạo một thư mục kết quả riêng.

```powershell
& $julia --startup-file=no --project=. bin/apriori.jl --input data/benchmarks/retail.txt --minsup 0.05 --counter hash-tree --warmup 1
if ($LASTEXITCODE -ne 0) { throw 'Apriori chạy lỗi. Xem thông báo phía trên.' }
```

Lượt đầu theo cách đặt tên mới ghi vào `output/runs/retail-1/`. Đổi ngưỡng rồi chạy lại sẽ ghi vào `retail-2/`, tiếp theo là `retail-3/`. Các thư mục mã dài cũ vẫn mở được bằng đường dẫn ban đầu. Để so tốc độ hai bộ đếm trên riêng Retail, dùng khối lệnh ở bước 3 với `$datasets = @(Get-Item -LiteralPath 'data/benchmarks/retail.txt')` và `$minsup = '0.05'`.

## 3. Chạy nhiều dataset và xuất bảng so sánh

Đặt các file giao dịch `.txt` cần đo vào `data/benchmarks/`. Chạy khối PowerShell sau tại thư mục gốc, trong phiên đã khai báo `$julia` ở bước 2. Nếu muốn kiểm tra nhanh trước, thay dòng gán `$datasets` bằng `$datasets = @(Get-Item -LiteralPath 'data/toy/paper.txt')`. Bạn có thể dùng một ngưỡng khác khi chạy lại cả đợt.

```powershell
$datasets = @(Get-ChildItem -LiteralPath 'data/benchmarks' -File -Filter '*.txt' -ErrorAction Stop)
if ($datasets.Count -eq 0) { throw 'Hãy thêm file giao dịch TXT vào data/benchmarks.' }
$minsup = '0.50'
$repeats = 3
$batchName = & $julia --startup-file=no bin/new-batch.jl output/bench
if ($LASTEXITCODE -ne 0) { throw 'Tạo thư mục đợt đo thất bại.' }
$batch = Join-Path 'output/bench' $batchName

$rows = foreach ($dataset in $datasets) {
    $referenceHash = $null
    foreach ($rep in 1..$repeats) {
        foreach ($counter in 'scan', 'hash-tree') {
            $run = "$batch/$($dataset.BaseName)/$counter/$rep"
            & $julia --project=. bin/apriori.jl --input $dataset.FullName --minsup $minsup --counter $counter --warmup 1 --report-dir $run --output "$run/itemsets.txt" --quiet
            if ($LASTEXITCODE -ne 0) { throw "Lỗi khi chạy $($dataset.Name), $counter, lượt $rep" }

            $total = Import-Csv -LiteralPath "$run/timings.csv" | Where-Object phase -eq 'mining_total'
            $hash = (Get-FileHash -LiteralPath "$run/itemsets.txt" -Algorithm SHA256).Hash
            if ($null -eq $referenceHash) { $referenceHash = $hash }
            [pscustomobject]@{
                Dataset = $dataset.Name
                Minsup = $minsup
                Counter = $counter
                Repeat = $rep
                MiningMs = $total.elapsed_ms
                Itemsets = $total.frequent
                SameAsFirst = ($hash -eq $referenceHash)
                ItemsetsSHA256 = $hash
                RunDir = $run
            }
        }
    }
}
$rows | Export-Csv -LiteralPath "$batch/summary.csv" -NoTypeInformation -Encoding UTF8
$rows | Format-Table Dataset, Minsup, Counter, Repeat, MiningMs, Itemsets, SameAsFirst
"Bảng so sánh nằm ở $batch/summary.csv"
```

Mỗi dataset tạo 6 dòng trong bảng (2 bộ đếm × 3 lần đo). `--warmup 1` chạy một lượt làm nóng trước mỗi lượt đo. Mỗi lần thực hiện lại cả khối lệnh sẽ tạo một thư mục đợt đo mới. Dataset mới có thể chạy thẳng qua CLI, không cần đáp án mẫu hay chỉnh manifest của bộ 8 test.

## 4. Dùng kết quả để tối ưu

1. Giữ `summary.csv` cùng các thư mục con của đợt đầu làm **baseline**. Kiểm tra cột `SameAsFirst` đều là `True` cho mỗi dataset. Chương trình ghi itemsets theo thứ tự cố định, nên hash khớp cho biết các tập **và support count** khớp ở các lượt này. Nếu có `False`, đối chiếu hai file `itemsets.txt` trước khi so tốc độ.
2. Với mỗi tổ hợp **dataset + minsup + counter**, lấy **trung vị của 3 giá trị MiningMs** (xếp theo số, lấy giá trị ở giữa). Đây là thời gian khai phá. Để biết phần nào tốn thời gian, lọc `timings.csv` theo mức `k` rồi xem các phase như `generate_candidates`, `build_counter` và `count_support`. Dòng `level_total` đã bao gồm các phase con.
3. Sau khi sửa thuật toán, chạy lại bước 3 trên cùng máy, cùng phiên bản Julia, cùng dữ liệu, ngưỡng và warmup. Giữ chế độ diễn giải tắt ở cả hai đợt. So `input_sha256` trong `metadata.toml` và `ItemsetsSHA256` trong hai bảng để xác nhận dữ liệu đầu vào và kết quả khớp. `implementation_sha256` cho biết phiên bản mã nào đã được đo. Với cùng bộ đếm, **hệ số tăng tốc = trung vị MiningMs trước / trung vị MiningMs sau**. Ví dụ, từ 120 ms xuống 80 ms tương ứng nhanh hơn 1,5 lần.
