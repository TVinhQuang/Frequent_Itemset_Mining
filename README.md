# Khai phá tập phổ biến bằng Apriori

Nhóm cài đặt Apriori bằng Julia theo bài báo của Rakesh Agrawal và Ramakrishnan Srikant. Hai bộ đếm `scan` và `hash-tree` dùng chung bước sinh ứng viên và trả về từng tập phổ biến cùng support count. [Bài báo gốc (PDF)](docs/apriori_longer.pdf) · [Thuật toán và mã nguồn tương ứng](docs/apriori-paper.md)

## Chạy ví dụ trong bài báo

Cài Julia 1.9 trở lên, mở terminal tại thư mục gốc của repo và chạy:

```sh
julia --project=. bin/apriori.jl --input data/toy/paper.txt --min-count 2 --counter hash-tree --trace
```

Ví dụ Figure 3 có 4 giao dịch. Với support count tối thiểu bằng 2, kết quả có **9 tập phổ biến**, trong đó `2 5 #SUP: 3`. CLI in đường dẫn báo cáo trong `output/runs/`. [Xem đáp án và cách đọc báo cáo](docs/chay-apriori.md#ví-dụ-trong-bài-báo)

## Thư mục của nhóm

| Thư mục | Nội dung |
| --- | --- |
| [data/](data/README.md) | Bốn dataset benchmark, ví dụ Figure 3, các bộ nhỏ và đáp án kiểm thử. |
| [apps/](apps/) | Nơi nhóm đưa mã nguồn của hai ứng dụng. |
| [src/](src/) và [bin/](bin/) | Cài đặt Apriori, CLI và các lệnh benchmark. |
| [test/](test/) | Kiểm thử thuật toán, hai bộ đếm và CLI bằng Julia. |
| [benchmarks/](benchmarks/) | Bảng kết quả từng dataset, gói log và báo cáo so sánh. |
| [docs/](docs/) | PDF bài báo, diễn giải thuật toán và hướng dẫn chạy. |

## Kiểm thử

```sh
julia --project=. test/runtests.jl
julia --project=. test/benchmark_protocol.jl
```

Để chạy cả 8 bộ dữ liệu chức năng qua hai bộ đếm và so với đáp án, dùng PowerShell:

```powershell
./bin/test-kit.ps1
```

[Hướng dẫn CLI và API Julia](docs/chay-apriori.md) · [Chạy dataset riêng](docs/huong-dan-dataset-moi.md)

## Kết quả benchmark

Ở mốc trước tối ưu, cả **120 lần đối chiếu** trên 40 cấu hình đều khớp SPMF 2.68 về từng tập mục và support. Mỗi gói ZIP chứa CSV, biểu đồ, log và đầu ra của ba bộ chạy.

| Dataset | Giao dịch | Đối chiếu đạt | Kết quả |
| --- | ---: | ---: | --- |
| [Retail](data/benchmarks/retail.txt) | 88.162 | 27/27 | [CSV](benchmarks/Retail/run-3/results.csv) · [ZIP](benchmarks/Retail/run-3/Retail-run-3.zip) |
| [Mushrooms](data/benchmarks/mushrooms.txt) | 8.416 | 33/33 | [CSV](benchmarks/Mushrooms/run-2/results.csv) · [ZIP](benchmarks/Mushrooms/run-2/Mushrooms-run-2.zip) |
| [Chess](data/benchmarks/chess.txt) | 3.196 | 33/33 | [CSV](benchmarks/Chess/run-1/results.csv) · [ZIP](benchmarks/Chess/run-1/Chess-run-1.zip) |
| [Pumsb](data/benchmarks/pumsb.txt) | 49.046 | 27/27 | [CSV](benchmarks/Pumsb/run-2/results.csv) · [ZIP](benchmarks/Pumsb/run-2/Pumsb-run-2.zip) |

[Bảng so sánh và chẩn đoán điểm nghẽn (Excel)](benchmarks/summary/Thong-ke-Apriori.xlsx) · [Biểu đồ tổng hợp (PNG)](benchmarks/summary/Bieu-do-Apriori.png) · [Quy trình tái lập benchmark](benchmarks/AGENTS.md)
