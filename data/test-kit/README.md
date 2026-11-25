# Bộ kiểm thử nhỏ cho dự án Apriori (SPMF transaction format)

Bộ này chứa **8 cơ sở dữ liệu nhỏ**, mỗi file `.txt` là một CSDL giao tác khác nhau, và kết quả FIM tương ứng tại minsup chỉ định. Đây là dữ liệu để kiểm tra đúng/sai; **không thay cho 4 benchmark lớn** mà đề bài yêu cầu.

## Nguồn gốc

- `01_spmf_example`: ví dụ chính thức trên trang giải thích Apriori của SPMF: https://www.philippe-fournier-viger.com/spmf/Apriori.php
- `02_hcmus_fim_slide`: dữ liệu ví dụ 6 giao tác trong bài giảng Khai thác tập phổ biến HCMUS. Ánh xạ A=1, C=2, D=3, T=4, W=5.
- `03` đến `08`: dữ liệu giả lập do người biên soạn bộ test tạo để bắt các lỗi biên.

Thư mục [expected/](expected/) chứa đáp án tính bằng vét cạn độc lập. Ngày 25/11/2026, nhóm cũng chạy lệnh `Apriori` của **SPMF 2.68** bằng Java 27 trên đúng 8 tệp và ngưỡng trong [manifest.json](manifest.json). Nhóm lưu đầu ra của từng lần chạy, ngưỡng, SHA-256 của đầu vào và của JAR trong [spmf-2.68.toml](spmf-2.68.toml). Hai nguồn đáp án khớp trên cả 8 CSDL.

## Tỷ lệ đúng so với SPMF

Một CSDL đạt khi đầu ra Julia có đúng mọi tập mục SPMF tìm thấy, support count của từng tập bằng nhau và không có tập dư hay trùng. Thứ tự dòng và thứ tự item trong một tập không ảnh hưởng phép so. Bảng ghi số cặp *(tập mục, support count)* khớp trên tổng số cặp SPMF của từng CSDL.

| CSDL | Minsup | Support count tối thiểu | Scan so với SPMF | Hash-tree so với SPMF |
| --- | ---: | ---: | ---: | ---: |
| 01 · Ví dụ SPMF | 40% | 2 | 15/15 | 15/15 |
| 02 · Bài giảng HCMUS | 80% | 5 | 3/3 | 3/3 |
| 03 · Support đúng ngưỡng | 50% | 2 | 6/6 | 6/6 |
| 04 · Giao dịch dày | 100% | 4 | 15/15 | 15/15 |
| 05 · Không có tập đạt ngưỡng | 40% | 2 | Cùng rỗng | Cùng rỗng |
| 06 · Giỏ hàng lặp | 60% | 3 | 7/7 | 7/7 |
| 07 · Làm tròn ngưỡng | 43% | 4 | 1/1 | 1/1 |
| 08 · Mã item không liên tiếp | 50% | 2 | 6/6 | 6/6 |

**Scan đạt 8/8 CSDL (100%) và Hash-tree đạt 8/8 CSDL (100%).** Mỗi bộ đếm khớp 53/53 cặp trên toàn bộ test-kit. Ca 05 đạt vì cả hai đầu ra có 0 tập mục. Ca này đóng góp một CSDL vào tỷ lệ 8/8 và 0 cặp vào tổng 53.

Lệnh `julia --project=. test/runtests.jl` chạy đối chiếu này mặc định bằng đầu ra SPMF đã lưu. Để chạy lại chính JAR trên cả 8 CSDL, đặt `SPMF_JAR` trỏ tới JAR có SHA-256 trong tệp bằng chứng, cài `java` trong PATH và chạy từ thư mục gốc. Ví dụ với PowerShell trên Windows:

```powershell
$env:SPMF_JAR = 'D:\Tools\spmf-apriori\spmf.jar'
julia --project=. test/spmf_test_kit.jl
```

Chế độ này kiểm thêm số tập SPMF báo sau mỗi lần chạy và so từng cặp trong tệp vừa xuất với bản lưu. [Mã kiểm thử](../../test/spmf_test_kit.jl)

## Format

- Mỗi dòng là một transaction, số nguyên dương cách nhau bởi khoảng trắng.
- Bên trong mỗi transaction, các item không lặp lại và được sắp tăng dần.
- Một transaction giống hệt transaction khác vẫn là **hai giao tác riêng**.
- Đầu ra dự kiến là `1 2 #SUP: 3`; support là **số giao tác**, không phải tỉ lệ %.
- Output trong `expected/` đã được sắp theo số item trong itemset, rồi theo thứ tự từ điển. Khi so sánh, không yêu cầu thứ tự dòng của chương trình phải giống hệt.
- `05_sparse_no_frequent` có kết quả mong đợi **rỗng** — đó là hành vi đúng.

## Chạy thử

Đọc `manifest.json` để biết mức `minsup_relative` ứng với từng file. Từ thư mục gốc repository, PowerShell có thể chạy và đối chiếu cả 8 CSDL bằng Julia:

```powershell
.\bin\test-kit.ps1 -Warmup 1
```

Thêm `-Explain` để lưu luồng thuật toán. Nếu Julia chưa có trong PATH, truyền `-Julia` kèm đường dẫn `julia.exe` của máy. Script tự lấy đúng minsup, chạy cả hai bộ đếm và so sánh itemsets/support, không phụ thuộc thứ tự dòng.

Chạy riêng một bộ bằng CLI Julia (mọi hệ điều hành có Julia):

```sh
mkdir output
julia --project=. bin/apriori.jl --input data/test-kit/datasets/01_spmf_example.txt --output output/example.txt --minsup 0.40 --counter hash-tree --warmup 1
```

Bỏ qua `mkdir output` nếu thư mục đã có. Mỗi lần chạy lưu báo cáo itemsets/support, thời gian và metadata trong bundle mới; script cả bộ lưu ở `output/test-kit/runs/`. Xem [README chính](../../docs/chay-apriori.md) để biết các file và phạm vi đo thời gian.

## Kiểm thử đề xuất

1. `01`: kiểm tra ví dụ chính thức (15 frequent itemsets ở mức 40%).
2. `02`: kiểm tra dữ liệu trong bài giảng (minsup 80%, cần `C`, `W`, và `C W`).
3. `03`: trường hợp support **bằng đúng** minsup phải được giữ.
4. `04`: dữ liệu dense có toàn bộ 15 tập con khác rỗng của 4 items.
5. `05`: không xuất itemset nào.
6. `06`: nhiều transaction giống nhau vẫn được đếm riêng.
7. `07`: làm tròn **lên** ngưỡng 43% của 7 transaction thành 4.
8. `08`: không giả định item IDs phải liên tiếp từ 1.

## Dữ liệu để đo hiệu năng

Bốn bộ Retail, Mushrooms, Chess và Pumsb nằm trong [data/benchmarks](../benchmarks/). Bản Mushrooms nhóm dùng có 8.416 giao dịch. [Các đợt đo và kết quả đối chiếu](../../README.md#kết-quả-benchmark)
