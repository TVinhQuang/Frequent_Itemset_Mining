# Ứng dụng của nhóm

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
