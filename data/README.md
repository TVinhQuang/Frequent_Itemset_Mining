# Dữ liệu Apriori

| Thư mục | Dùng khi nào |
| --- | --- |
| [toy/](toy/) | Chạy ví dụ Figure 3 của bài báo với [paper.txt](toy/paper.txt), hoặc thử các trường hợp giao dịch trùng, rời nhau, dày và thưa. |
| [test-kit/](test-kit/README.md) | Kiểm tra chức năng trên 8 CSDL. [Manifest](test-kit/manifest.json) ghép mỗi file với ngưỡng và [đáp án](test-kit/expected/) tương ứng. |
| [benchmarks/](benchmarks/) | Đo runtime, RAM đỉnh và số ứng viên trên Retail, Mushrooms, Chess và Pumsb. |

Mỗi dòng dữ liệu là một giao dịch gồm các mã item nguyên cách nhau bằng khoảng trắng. Bốn file benchmark được lấy từ mục **Datasets for Frequent Itemset mining → Datasets in SPMF format**. Cột `raw_sha256` trong CSV của mỗi đợt đo dùng để kiểm tra bản dữ liệu. [Danh mục SPMF](https://www.philippe-fournier-viger.com/spmf/datasets.php) · [Kết quả theo dataset](../README.md#kết-quả-benchmark)
