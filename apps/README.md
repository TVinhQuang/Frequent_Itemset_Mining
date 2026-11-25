# Ứng dụng của nhóm

## Ứng dụng 1 · Phân tích giỏ hàng Retail (SPMF)

Nhóm khai phá 88.162 giỏ hàng của bộ Retail, gồm 16.470 mã mặt hàng ẩn danh. Dữ liệu đã ở dạng giao dịch. Mỗi dòng là một giỏ, mỗi số là một mã mặt hàng. Bộ đọc sắp các mã và loại mã trùng trong cùng một giỏ trước khi đếm support. [Dữ liệu trong repo](../data/benchmarks/retail.txt) · [Notebook của ứng dụng](../notebooks/ung-dung-1-retail.ipynb)

Chạy từ thư mục chứa `Project.toml` với Julia 1.9 trở lên.

```sh
julia --project=. apps/market-basket/main.jl --minsup 0.02 --minconf 0.50
```

Lệnh dùng bộ đếm Hash-tree và bộ sinh luật của notebook. Mỗi lượt tạo thư mục `output/market-basket/retail-N/` chứa toàn bộ luật trong `retail-rules.csv`, mười luật đầu trong `top10-rules.csv` và diễn giải trong `report.txt`. Có thể thay hai ngưỡng. [Bộ sinh luật](../src/AssociationRules.jl) · [CSV kết quả ở ngưỡng mặc định](market-basket/results/retail-rules.csv)

### Kết quả dùng trong báo cáo

Ở minsup 2%, một tập phải xuất hiện trong ít nhất 1.764 giỏ. Apriori tìm được 55 tập phổ biến, gồm 20 tập một mã, 22 tập hai mã, 12 tập ba mã và một tập bốn mã. Ở minconf 50%, có 45 luật đạt ngưỡng. Bảng dưới xếp 10 luật đầu theo lift giảm dần. Cột số giỏ đếm các giao dịch chứa đủ cả hai vế.

| Hạng | Luật theo mã hàng | Số giỏ | Support | Confidence | Lift |
|---:|---|---:|---:|---:|---:|
| 1 | {37} → {39, 40} | 1.945 | 2,21% | 66,25% | 5,646 |
| 2 | {171} → {39, 40} | 2.019 | 2,29% | 65,15% | 5,552 |
| 3 | {40, 171} → {39} | 2.019 | 2,29% | 98,06% | 5,543 |
| 4 | {171} → {39} | 3.031 | 3,44% | 97,81% | 5,529 |
| 5 | {111} → {39} | 2.725 | 3,09% | 97,53% | 5,513 |
| 6 | {37, 40} → {39} | 1.945 | 2,21% | 95,48% | 5,398 |
| 7 | {37} → {39} | 2.790 | 3,16% | 95,03% | 5,372 |
| 8 | {90} → {40, 49} | 2.125 | 2,41% | 55,38% | 1,675 |
| 9 | {40, 90} → {49} | 2.125 | 2,41% | 77,30% | 1,617 |
| 10 | {39, 42} → {40, 49} | 1.991 | 2,26% | 51,09% | 1,546 |

Trong 2.936 giỏ có mã 37, có 1.945 giỏ cũng chứa cả mã 39 và 40, nên confidence bằng 66,25%. Trên toàn bộ dữ liệu, tỷ lệ có đồng thời 39 và 40 là 11,73%. Chia hai tỷ lệ cho nhau cho lift khoảng 5,65. Cửa hàng có thể thử gợi ý cặp 39 và 40 khi khách đã chọn 37. Việc áp dụng cho sản phẩm cụ thể cần bảng đối chiếu mã hàng của cửa hàng. Luật cho thấy hành vi mua chung trong dữ liệu. Tác động của gợi ý đến doanh thu cần được đo riêng.

## Ứng dụng 2 · So sánh các mẫu DNA ở điểm nối exon–intron

Chạy từ thư mục chứa `Project.toml`. CLI đọc trực tiếp 3.190 chuỗi gốc và xuất kết quả cho một lượt chạy riêng ở `output/splice-junction/splice-N/`. Có thể chọn tệp cùng định dạng bằng `--input`. [Dữ liệu và cách mã hóa vị trí](../data/splice-junction/README.md)

```sh
julia --project=. apps/splice-junction/main.jl --minsup 0.20
```

Apriori dùng ngưỡng 20% trong từng nhóm. `patterns.csv` chứa mọi mẫu đạt ngưỡng ở ít nhất một nhóm, chiều dài mẫu, số lần xuất hiện và support ở cả ba nhóm. Ví dụ, `support_IE` có mẫu số 768 đoạn IE. `report.txt` chọn một cặp cho mỗi loại ranh giới theo mức chênh support so với nhóm N và giải thích bằng tiếng Việt.

Mặc định thu được 225 mẫu khác nhau. Hai cặp có chênh lệch lớn nhất so với nhóm N cho thấy vị trí của nucleotide có ý nghĩa khi diễn giải.

| Mẫu vị trí–nucleotide | EI (767 đoạn) | IE (768 đoạn) | N (1.655 đoạn) |
| --- | ---: | ---: | ---: |
| +1:G +2:T | 759 (98,96%) | 108 (14,06%) | 98 (5,92%) |
| −2:A −1:G | 389 (50,72%) | 764 (99,48%) | 127 (7,67%) |

Cặp đầu tập trung ngay sau ranh giới exon → intron, cặp thứ hai tập trung ngay trước ranh giới intron → exon. Một mẫu cũng có thể xuất hiện ở loại ranh giới khác, như cặp thứ hai ở 50,72% đoạn EI. Tỷ lệ trong bộ UCI giúp mô tả khác biệt giữa các nhóm; đánh giá khả năng dự báo trên chuỗi mới cần một phép kiểm chứng riêng.

[Kết quả mẫu với ngưỡng 20% (CSV)](splice-junction/results/patterns.csv) · [Báo cáo của lần chạy](splice-junction/results/report.txt)
