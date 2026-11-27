# Khai phá tập phổ biến bằng Apriori

Nhóm cài đặt Apriori bằng Julia theo bài báo của Rakesh Agrawal và Ramakrishnan Srikant. Hai bộ đếm `scan` và `hash-tree` dùng chung bước sinh ứng viên và trả về từng tập phổ biến cùng support count. [Bài báo gốc (PDF)](docs/apriori_longer.pdf) · [Thuật toán và mã nguồn tương ứng](docs/apriori-paper.md)

## Thành viên nhóm

| Họ và tên | MSSV |
| --- | --- |
| Phạm Nguyễn Trường Huy | 24127401 |
| Trần Vinh Quang | 24127523 |
| Phạm Đặng Thiên Quốc | 24127524 |

## Đề bài và phạm vi của nhóm

- [Đề bài gốc của giảng viên](itemset.md) gồm toàn bộ yêu cầu, các hướng ứng dụng được phép chọn và tiêu chí chấm điểm.
- Nhóm chọn Apriori, phân tích giỏ hàng với bộ Retail của SPMF và phân tích dữ liệu sinh học với Splice-junction. [Phạm vi đã chốt của nhóm](Pham_vi_da_chot.txt)

## Hai ứng dụng trên Google Colab

[Mở notebook tổng hợp Retail và Splice-junction trên Google Colab](https://colab.research.google.com/github/TVinhQuang/Frequent_Itemset_Mining/blob/main/notebooks/demo.ipynb)

Chọn **Python 3 (CPU)** rồi **Runtime → Run all**. Phần đầu dùng Apriori để tìm các mặt hàng mua chung trong dữ liệu Retail và xếp hạng 10 luật theo lift. Phần sau so sánh các mẫu DNA quanh điểm nối exon–intron của bộ Splice-junction với nhóm đối chứng.

| Notebook | Nội dung |
| --- | --- |
| [demo.ipynb](notebooks/demo.ipynb) | Bản tổng hợp để chạy cả hai ứng dụng và xem kết quả ngay trong notebook. |
| [ung-dung-1-retail.ipynb](notebooks/ung-dung-1-retail.ipynb) | Bản riêng của Ứng dụng 1, phân tích giỏ hàng Retail. |
| [ung-dung-2-splice-junction.ipynb](notebooks/ung-dung-2-splice-junction.ipynb) | Bản riêng của Ứng dụng 2, phân tích điểm nối exon–intron. |

Cả ba notebook đóng gói mã Julia từ cùng [phiên bản mã nguồn](https://github.com/TVinhQuang/Frequent_Itemset_Mining/tree/e48110f6978f226a80329dbcfeef07e1c519c530). Notebook tổng hợp và bản Retail kèm dữ liệu kiểm thử để chạy bộ kiểm thử của dự án ngay trong phiên Colab.

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
| [apps/](apps/README.md) | Lệnh chạy và cách đọc kết quả của hai ứng dụng Retail (SPMF) và Splice-junction. |
| [src/](src/) và [bin/](bin/) | Cài đặt Apriori, CLI và các lệnh benchmark. |
| [test/](test/) | Kiểm thử thuật toán, hai bộ đếm và CLI bằng Julia. |
| [benchmarks/](benchmarks/) | Bảng kết quả từng dataset, gói log và báo cáo so sánh. |
| [docs/](docs/) | PDF bài báo, diễn giải thuật toán và hướng dẫn chạy. |

## Kiểm thử

```sh
julia --project=. test/runtests.jl
julia --project=. test/benchmark_protocol.jl
```

Kết quả lần chạy ngày 25/11/2026 với Julia 1.13.4, gồm kiểm thử hai ứng dụng, luật kết hợp, các bản tối ưu và hai quy trình benchmark:

```text
Test Summary                                        | Pass  Total
FrequentItemsetMining                               | 2875   2875
Apriori vs SPMF on the small test databases         |   34     34
AssociationRules                                    |  228    228
Optimized Apriori variants                          |  342    342
Optimized benchmark APRIORI-V1 transaction sampling |   45     45
Nested transaction samples and support comparisons  |   24     24
```

Lệnh chính đạt 3.524/3.524, gồm kiểm tra ứng dụng Retail cục bộ với toàn bộ 45 luật đã xuất từ notebook. Kiểm tra giao thức chạy riêng đạt 24/24. [Output lệnh chính](apps/market-basket/results/runtests.txt) · [Output kiểm tra giao thức](benchmarks/optimized/thuc-nghiem-bo-sung-20261125/protocol-test.txt)

Trên bộ test nhỏ của Chương 1, Scan và Hash-tree mỗi bản khớp **8/8 CSDL (100%)** với SPMF 2.68. Mỗi bản khớp đủ 53/53 cặp tập mục–support và cùng trả về 0 tập ở ca rỗng. Unit test mặc định dùng đầu ra SPMF đã lưu. Đặt biến môi trường `SPMF_JAR` để kiểm tra thêm bằng cách chạy lại JAR. [Bảng kết quả, dữ liệu tham chiếu và lệnh tái lập](data/test-kit/README.md)

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

### Kết quả sau tối ưu

Nhóm so sánh Hash-tree, Bitset và Streaming trên cùng các giao dịch. Đợt kiểm chứng ngày 25/11/2026 chạy cả ba phiên bản trên 100% mỗi bộ dữ liệu ở ngưỡng hỗ trợ giữa. Bitset nhanh nhất trên Chess, Mushrooms và Pumsb. Hash-tree nhanh nhất trên Retail ở ngưỡng 5%. [Phân tích và bảng số liệu](docs/chuong-toi-uu-apriori.md#63-kết-quả-kiểm-chứng-ngày-25112026) · [Biểu đồ thời gian và RAM](benchmarks/optimized/kiem-chung-20261125/thoi-gian-va-ram.png) · [CSV và manifest của đợt kiểm chứng](benchmarks/optimized/kiem-chung-20261125/) · [Các đợt đo của nhóm](benchmarks/optimized/) · [Log gốc](benchmarks/optimized/logs.zip)

Để chạy lại Retail ở cùng cấu hình từ thư mục gốc:

```sh
julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/retail.txt --minsup 0.05 --sample-percentages 100 --seed 42 --warmup 1 --repeats 3 --output output/retail-5pct.csv
```

### Độ dài giao dịch, quy mô lớn và kiểm chứng external

Ba engine external khớp từng tập mục và support với đầu ra SPMF lưu trong bốn bộ benchmark ở toàn bộ 24 cấu hình minsup (72/72 phép đối chiếu). Sáu CSDL tổng hợp chạy đối chiếu trực tiếp với SPMF đạt 18/18. Bốn quy mô Retail đạt 12/12 khi đối chiếu với support SPMF của bản gốc nhân theo số bản sao. [CSV kiểm chứng trên dữ liệu thật](benchmarks/optimized/thuc-nghiem-bo-sung-20261125/external-correctness.csv) · [CSV thời gian, RAM và nguồn từng điểm](benchmarks/optimized/thuc-nghiem-bo-sung-20261125/minsup-grid.csv)

Khi tính từ khởi động Julia tới khi xuất đủ tệp ở ngưỡng giữa, Bitset external so với Scan đạt 0,98× trên Retail, 1,25× trên Chess, 1,69× trên Mushrooms và 1,32× trên Pumsb. Streaming external chậm hơn Scan ở cả bốn điểm. Cả 36 tệp kết quả của phép đo này khớp đáp án SPMF. [Bảng và số liệu từng lần chạy](benchmarks/optimized/scan-xuat-day-du-20261125/output/) · [Hình so với Scan](benchmarks/optimized/scan-xuat-day-du-20261125/figures/scan-output.pdf)

Với 10.000 giao dịch, 100 item và minsup 28%, Hash-tree nhanh nhất ở độ dài 5–20. Ở độ dài 30–50, cả ba engine đếm 5.050 ứng viên và Bitset nhanh nhất. Trên Retail nhân bản 10 lần (881.620 giao dịch), Streaming dùng 310,3 MiB so với 533,9 MiB của Hash-tree, đổi lại thời gian tăng từ 1,809 lên 4,569 giây. Các CSV kèm theo giữ cả thời gian từng lượt và kết quả so từng itemset–support. [Thiết kế, kết quả và lệnh tái lập](docs/thuc-nghiem-bo-sung.md) · [CSV và metadata](benchmarks/optimized/thuc-nghiem-bo-sung-20261125/) · [Biểu đồ](benchmarks/optimized/thuc-nghiem-bo-sung-20261125/figures/apriori.pdf)
