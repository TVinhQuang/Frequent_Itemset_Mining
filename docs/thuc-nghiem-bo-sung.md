# Thực nghiệm bổ sung cho Apriori external

Phép đo độ dài giao dịch trả lời yêu cầu ở dòng 126–128 của [đề gốc](../itemset.md). Ba phép kiểm bổ sung khảo sát vùng minsup còn thiếu, điều kiện Streaming tiết kiệm RAM và độ chính xác của các hàm external thực sự chạy trong benchmark. Bốn ZIP so Scan, Hash-tree và SPMF cùng các phép đo external cũ vẫn là nguồn cho những cấu hình đã có. [Kết quả cũ](../benchmarks/) · [Dữ liệu đợt bổ sung](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/)

## Kết quả kiểm chứng

Một phép đối chiếu kiểm tra toàn bộ tập mục và support count do một engine xuất ở một cấu hình. Cả ba engine dùng đường chạy external của benchmark. Mỗi hàng kết quả ghi riêng số tập thiếu, dư, lặp và sai support. Bốn số này đều bằng 0 trong cả 102 phép đối chiếu dưới đây.

| Dữ liệu và cách xác lập đáp án | Số phép đối chiếu đạt | Bằng chứng |
|---|---:|---|
| Retail, Chess, Mushrooms, Pumsb ở lần lượt 5, 7, 7, 5 ngưỡng. Đọc đáp án SPMF đã lưu trong bốn ZIP, xác minh hash của mẫu và kết quả. | 72/72 | [Từng ngưỡng và từng engine](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/external-correctness.csv) |
| Sáu CSDL tổng hợp theo độ dài. Chạy trực tiếp SPMF 2.68 trên mỗi CSDL. | 18/18 | [Kết quả độ dài](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/width/results.csv) |
| Retail ở các hệ số 1, 2, 5, 10. Đáp án lấy từ support của SPMF trên Retail gốc nhân với số bản sao. | 12/12 | [Kết quả Retail nhân bản](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/size/results.csv) |

Giao thức external sau warm-up có **78 kết quả hiệu năng mới**, mỗi kết quả lấy trung vị ba lượt, tổng cộng **234 lượt đo**. Ở tám cấu hình dữ liệu thật đã có timing (ngưỡng giữa và thấp nhất trên bốn bộ), nhóm dùng lại timing cũ và chạy bước xuất đối chứng. Bộ test Julia đạt 3.482/3.482 ở lệnh chính và 24/24 ở lệnh kiểm tra giao thức riêng. [Lưới thời gian có nguồn từng điểm](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/minsup-grid.csv) · [Log test chính](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/tests.txt) · [Log giao thức](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/protocol-test.txt) · [11 trang biểu đồ](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/figures/apriori.pdf)

## So trực tiếp với bản cơ bản khi cần tệp kết quả đầy đủ

Câu hỏi ở dòng 84–86 của đề là người dùng được lợi bao nhiêu so với bản cơ bản. Mỗi lượt ở bảng dưới khởi động một tiến trình Julia mới, dùng một luồng, đọc toàn bộ mẫu, khai phá và đóng tệp đầu ra SPMF. Bản Scan gọi `mine(read_spmf(...); counter=:scan)` rồi dùng `write_spmf`. Bitset và Streaming gọi hàm external và ghi các tập ngay khi đạt ngưỡng. Đồng hồ phía tiến trình cha dừng khi tiến trình con thoát. Mỗi bộ chạy ba vòng, luân phiên thứ tự engine. Cache hệ điều hành có thể còn giữa các lượt. Peak RAM được đọc trong từng tiến trình sau khi đóng tệp. Cả **36/36** tệp đầu ra khớp từng tập mục và support với đáp án SPMF đã lưu.

| Dữ liệu, minsup | Scan (giây / MiB) | Bitset external (giây / MiB) | Streaming external (giây / MiB) | Tốc độ Bitset so với Scan |
|---|---:|---:|---:|---:|
| Retail, 5% | 2,872 / 341,2 | 2,924 / 294,4 | 3,549 / 295,8 | 0,98× |
| Chess, 75% | 7,211 / 342,7 | 5,752 / 326,5 | 11,189 / 332,8 | 1,25× |
| Mushrooms, 17,5% | 12,824 / 340,6 | 7,607 / 346,6 | 16,043 / 351,7 | 1,69× |
| Pumsb, 92% | 6,123 / 413,4 | 4,647 / 323,6 | 22,445 / 345,5 | 1,32× |

Mỗi ô ghi trung vị thời gian toàn tiến trình và trung vị của ba đỉnh RAM. Bitset nhanh hơn Scan ở ba bộ. Trên Retail, khoảng min–max của Scan (2,826–2,896 giây) và Bitset (2,884–2,960 giây) giao nhau. Streaming chậm hơn Scan trên cả bốn bộ. Trên Mushrooms, cả hai biến thể có peak RAM trung vị cao hơn Scan. Pumsb minh họa tầm quan trọng của mốc so sánh. Tại cùng ngưỡng 92%, Bitset đạt 1,32× so với Scan khi xuất đủ tệp và 22,10× so với Hash-tree external trong phép đo sau warm-up. [CSV trung vị và khoảng min–max](../benchmarks/optimized/scan-xuat-day-du-20261125/output/results.csv) · [36 phép đo và đối chứng](../benchmarks/optimized/scan-xuat-day-du-20261125/output/raw.csv) · [Biểu đồ](../benchmarks/optimized/scan-xuat-day-du-20261125/figures/scan-output.pdf) · [Thông tin môi trường](../benchmarks/optimized/scan-xuat-day-du-20261125/metadata.json)

## Độ dài giao dịch

Mỗi CSDL có 10.000 giao dịch và 100 mã item. Với seed 42, một nửa giao dịch chứa cùng cặp item 1 và 2. Các vị trí còn lại lấy từ một hoán vị không lặp của 98 item khác. Cùng TID sử dụng cùng hoán vị ở mọi độ dài. Nhờ vậy giỏ dài chứa toàn bộ giỏ ngắn của cùng TID. Cặp được cài vào dữ liệu giúp cả giỏ ngắn cũng có mẫu dài hai item để kiểm tra.

Trước khi đo, pilot dùng 1.000 giỏ dài 50. Quy tắc chọn là lấy ngưỡng đầu tiên trong dãy 25%, 28%, 32%, 36% cho từ 1 đến 100 cặp phổ biến. Số cặp tương ứng là 2.116, 41, 1 và 1. Vì vậy cả sáu điểm đo chính thức dùng **28%, tức 2.800 giao dịch**. Pilot chỉ dùng để chọn ngưỡng. Figure 15 của bài gốc giữ tổng số lượt xuất hiện item gần cố định khi thay đổi độ dài và điều chỉnh số giao dịch. Thí nghiệm ở đây giữ số giao dịch cố định để quan sát tải trên một CSDL có cùng số bản ghi. Hai thiết kế trả lời hai câu hỏi khác nhau. [Pilot](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/width/pilot.csv) · [Bài gốc, mục 4.8 và Figure 15](https://www.philippe-fournier-viger.com/spmf/apriori_longer.pdf)

| Item/giao dịch | Ứng viên, gồm singleton | Tập phổ biến | Hash-tree (ms) | Bitset (ms) | Streaming (ms) | Tốc độ Bitset so với Hash-tree |
|---:|---:|---:|---:|---:|---:|---:|
| 5 | 101 | 3 | 9,2 | 12,1 | 12,5 | 0,76× |
| 10 | 101 | 3 | 12,7 | 19,9 | 23,0 | 0,64× |
| 20 | 101 | 3 | 17,4 | 31,3 | 42,0 | 0,56× |
| 30 | 5.050 | 101 | 248,9 | 42,6 | 270,4 | 5,84× |
| 40 | 5.050 | 101 | 371,8 | 79,2 | 413,9 | 4,69× |
| 50 | 5.050 | 101 | 450,6 | 86,7 | 601,4 | 5,20× |

Ở độ dài 5–20, chỉ hai singleton và cặp được cài sẵn đạt ngưỡng. Hash-tree nhanh nhất ở cả ba điểm. Dù số ứng viên giữ ở 101, thời gian cả ba engine vẫn tăng khi phải đọc và xử lý giỏ dài hơn. Từ 20 lên 30, số singleton phổ biến tăng từ 2 lên 100. Cả 4.950 cặp trở thành ứng viên. Bước nhảy thời gian ở đây bao gồm ảnh hưởng của cả độ dài lẫn số ứng viên. Từ 30 lên 50, số ứng viên lại cố định, thời gian Hash-tree tăng từ 249 lên 451 ms. Trong khoảng này Bitset có thể dùng lại các cột TID cho nhiều ứng viên và nhanh nhất tại cả ba điểm. Đây là thời gian toàn lượt đọc và khai phá sau warm-up. Chưa có đồng hồ tách riêng chi phí parse, dựng cây và giao bit trong bảng này. [CSV chi tiết, khoảng min–max và hash](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/width/results.csv)

[Hình kết quả độ dài giao dịch](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/figures/width.png)

## Khi nào Streaming tiết kiệm RAM?

Tệp Retail chuẩn hóa được nối lần lượt 1, 2, 5 và 10 lần. Khi nhân lên $r$ bản, support count của mọi tập tăng đúng $r$ lần, tỷ lệ giữ nguyên. Tập tham chiếu cho từng cấu hình được dựng bằng phép nhân này từ đầu ra SPMF đã kiểm hash. Ở minsup 5%, cả bốn quy mô đều có 16 tập phổ biến và 16.488 ứng viên kể cả singleton. Bảng ghi **trung vị giây / đỉnh RAM MiB**.

| Số bản Retail | Giao dịch | Hash-tree | Bitset | Streaming | RAM Streaming giảm so với Hash-tree |
|---:|---:|---:|---:|---:|---:|
| 1 | 88.162 | 0,138 / 314,8 | 0,203 / 292,6 | 0,313 / 301,0 | 4,37% |
| 2 | 176.324 | 0,294 / 317,5 | 0,392 / 292,2 | 0,603 / 297,4 | 6,33% |
| 5 | 440.810 | 0,797 / 409,9 | 0,935 / 293,8 | 1,581 / 310,5 | 24,24% |
| 10 | 881.620 | 1,809 / 533,9 | 2,829 / 296,5 | 4,569 / 310,3 | 41,87% |

Ở 10×, Streaming giảm khoảng 224 MiB nhưng mất 2,53 lần thời gian của Hash-tree. **Bitset dùng ít RAM nhất trong cả bốn cấu hình này.** Retail có ít singleton đạt 5%, nên bitmap chỉ cần một số ít cột. Với cùng tập itemset, kích thước payload cực đại của hai tệp mức kề nhau tính từ số tập và độ dài tuple là 184 byte ở cả bốn điểm. Đây là ước tính cấu trúc mức. Cấp phát, peak RAM toàn tiến trình, I/O vật lý và kích thước phân bổ theo block của hệ thống tệp là các đại lượng khác nhau. Không đặt trần RAM hệ điều hành trong phép đo này. Việc nhân bản kiểm soát quy mô nhưng giữ nguyên phân bố và mức đa dạng của Retail. [CSV quy mô lớn](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/size/results.csv)

[Hình kết quả Retail nhân bản](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/figures/size.png)

## Khi thay đổi minsup trên dữ liệu thật

Nhóm đã có số đo external ở ngưỡng giữa và ngưỡng thấp nhất trên mỗi bộ. Đợt bổ sung đo ba engine ở 16 ngưỡng còn trống. Khi đọc hình, điểm rỗng là đợt cũ, điểm đặc là đợt bổ sung. Mỗi hệ số tăng tốc so các engine trong chính đợt của điểm đó. Thay đổi tốc độ giữa hai điểm có thể chịu ảnh hưởng của cả ngưỡng lẫn điều kiện máy tại thời điểm đo. [CSV các ngưỡng bổ sung](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/minsup/results.csv)

Trên Chess, ở ngưỡng 90% có 622 tập phổ biến và Bitset nhanh gấp 2,39 lần Hash-tree. Ở 65%, hai con số là 111.239 tập và 9,62 lần. Trên Retail, ở 10% chỉ có 9 tập, Bitset đạt 0,91×. Ở 3% có 32 tập, hệ số chỉ khoảng 1,04×. Việc dựng bitmap cần thêm lượt đọc và khởi tạo cột. Chi phí này có thể được phân bổ trên nhiều ứng viên khi các mức sinh nhiều tập. Đây là lời giải thích dựa vào cấu trúc bộ đếm. Muốn lượng hóa riêng phần đóng góp của từng bước cần đồng hồ từng pha trong cùng giao thức.

Pumsb cho thấy ngưỡng ảnh hưởng mạnh tới kết luận. Ở 96%, Bitset chỉ đạt 1,03× so với Hash-tree. Ở 90%, ba engine cùng tìm 2.607 tập. Hash-tree mất 55,998 giây, Bitset 0,585 giây và Streaming 42,845 giây. Tại đúng cấu hình này, Bitset đạt 95,67× và Streaming cũng nhanh hơn mốc Hash-tree. Hệ số 22,10× ở ngưỡng 92% thuộc đợt trước. Hai con số đều lấy thời gian Hash-tree external làm mẫu so.

## Khả năng mở rộng trên năm mẫu Retail

Ở phép đo khả năng mở rộng theo yêu cầu của đề, năm mẫu Retail dùng chung minsup 5%. Từ 10% lên 100% giao dịch, thời gian trung vị Hash-tree external tăng từ 25,7 lên 297,3 ms, tương ứng khoảng 11,55 lần. Số tập phổ biến thay đổi từ 15 lên 16. Các mẫu lồng nhau có thể khác về support và số ứng viên. Năm điểm này mô tả xu hướng trong khoảng đã đo. Ở phép nhân bản Retail phía trên, phân bố và số ứng viên được giữ cố định, nên có thể quan sát riêng ảnh hưởng của số giao dịch lên thời gian và peak RAM. [Dữ liệu năm mẫu](../benchmarks/optimized/retail_opt_p10_100.csv) · [Hình khả năng mở rộng trên Retail](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/figures/retail-scale.png)

## Giao thức và cách tái lập

Khi chạy lại, script dựng mẫu 100% từ các tệp trong `data/benchmarks/`, giữ thứ tự giao dịch, sắp các mã hàng phân biệt trong mỗi giỏ và ghi theo quy ước xuống dòng LF. Trước khi so với SPMF, script kiểm SHA-256 của mẫu với CSV của lần đo gốc. Các manifest lưu trong đợt kiểm chứng ghi lại các giá trị để đối chiếu.

Các log có nội dung của các đợt đo tối ưu được đóng gói theo tên đợt, bộ dữ liệu và engine. Giải nén tại `benchmarks/optimized/` để khôi phục cây thư mục log. [Tải log gốc](../benchmarks/optimized/logs.zip)

Đợt bổ sung chạy trên Windows 11 x86-64, CPU Intel Core i7-13620H (10 lõi vật lý, 16 bộ xử lý logic), RAM vật lý khoảng 31,6 GiB, Julia 1.13.4. Mỗi engine dùng một luồng Julia. Phần mềm điều phối dùng Python 3.12.14. [Metadata của phiên](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/metadata.json)

1. Cài Julia 1.9+ (đợt lưu dùng 1.13.4), Python 3.9+ và Java tương thích với JAR SPMF 2.68. Các lệnh bên dưới chạy từ repo root. Python điều phối và phân tích, Julia thực hiện toàn bộ phần khai phá của nhóm. Đặt `julia` và `java` trong PATH hoặc truyền đường dẫn Julia bằng `--julia`.
2. Dùng một thư mục kết quả mới. Mỗi tiến trình Julia chạy một engine, một luồng, lô tối đa 10.000 ứng viên, một lượt warm-up và ba lượt đo. Cùng cấu hình, các engine đọc cùng một tệp. Thứ tự engine xoay theo cấu hình. `median_ms` gồm đọc, chuẩn hóa, xử lý mức trên đĩa và khai phá. `peak_mib` là đỉnh bộ nhớ cư trú của tiến trình, gồm runtime, JIT và warm-up, lấy bằng `Sys.maxrss()` trước bước xuất đối chứng. Ba thời gian dùng chung tiến trình. Mỗi engine chỉ có **một** đỉnh RAM trong cấu hình. Log riêng và `raw.csv` giữ số đo từng lượt.
3. Sau khi chốt đồng hồ và peak RAM, worker chạy lại cùng engine và xuất từng cặp itemset–support. Với các ngưỡng benchmark chuẩn, bộ kiểm đọc tệp SPMF trong ZIP cũ và kiểm SHA-256 của mẫu cùng đầu ra tham chiếu. Với dữ liệu độ dài, bộ kiểm chạy JAR SPMF trên từng tệp. CSV đếm tập thiếu, dư, lặp và sai support. Tệp kết quả lớn phục vụ so trực tiếp được dọn sau khi so. Các tệp nguồn tổng hợp tái sinh từ script và có SHA-256 trong CSV.
4. Giới hạn mặc định là 360 giây mỗi worker, gồm cả bước xuất đối chứng. Trạng thái lỗi có cột riêng. Thời gian ngoài tiến trình `worker_wall_s_including_verification` gồm cả khởi động lẫn xuất kiểm chứng. Đợt cũ so SPMF sử dụng wall time đến khi ghi xong toàn bộ output. Chỉ tính tỷ số giữa các engine trong cùng cấu hình và giao thức.

```sh
python bin/study-apriori.py --julia julia --jar /path/to/spmf.jar --output benchmarks/optimized/run-moi --parts width size minsup exact lowest
python bin/study-apriori.py --julia julia --output benchmarks/optimized/so-scan-moi --parts output
python -m pip install reportlab pypdfium2 pillow
python bin/plot-apriori-study.py benchmarks/optimized/run-moi
python bin/plot-apriori-study.py benchmarks/optimized/so-scan-moi --scan-output
```

Mỗi tên sau `--parts` cũng có thể chạy riêng. Hai phần `exact` và `lowest` xuất đối chứng ở ngưỡng giữa và thấp nhất, dùng lại số đo hiệu năng đã có. Lệnh vẽ đọc ba phần đo, các đối chứng và các CSV lịch sử trong thư mục cha. Nếu đối chứng ngưỡng thấp nằm ở thư mục đợt khác, truyền thêm `--lowest-run <thư-mục-đợt-đó>`. [Script đo](../bin/study-apriori.py) · [Script vẽ](../bin/plot-apriori-study.py) · [Lệnh của đợt đã chạy](../benchmarks/optimized/thuc-nghiem-bo-sung-20261125/commands.txt)

Với thời gian $t_b,t_o$ và peak RAM $m_b,m_o$ của baseline và engine đang xét, speedup là $t_b/t_o$, phần trăm giảm thời gian là $100(1-t_o/t_b)$ và phần trăm giảm RAM là $100(1-m_o/m_b)$. Giá trị giảm âm cho biết engine cần nhiều thời gian hoặc bộ nhớ hơn. Các đồ thị sau warm-up lấy Hash-tree external làm mốc. Phép đo xuất trọn tệp ở bốn ngưỡng giữa lấy Scan làm mốc.

## Giới hạn và hai hướng tối ưu tiếp theo

- **Độ ổn định của phép đo.** Ba lượt sau warm-up phản ánh biến thiên trong một tiến trình. JIT còn lại, GC, lịch CPU, hệ thống tệp và cache có thể ảnh hưởng thời gian. Min–max của ba lượt chỉ mô tả lượt đã chạy. Peak RSS gồm bộ nhớ của Julia, nên các chênh lệch nhỏ cần được xác nhận trên nhiều tiến trình độc lập. Các bộ lịch sử từng được đo trên nhiều cấu hình phần cứng.
- **Phạm vi dữ liệu.** Một seed, một cặp được cài sẵn, sáu độ dài và một bộ Retail nhân bản chỉ cho phép kết luận trong miền thử nghiệm đó. Năm mức quy mô cũ hay bốn hệ số nhân mới chưa xác lập độ phức tạp tiệm cận. Phép so với Scan tính cả ghi đầu ra ở bốn ngưỡng giữa. Số đo đó bao gồm nhiều bước nên chưa xác định riêng thời gian ghi tệp.
- **Chọn bộ đếm theo mức.** Ước lượng số ứng viên, số singleton phổ biến và kích thước bitmap trước khi chọn cách đếm. Tính cả chi phí dựng bitmap khi chuyển engine. So với engine cố định trên cùng mẫu và toàn bộ mapping. Có thể tham khảo tư tưởng chuyển phương thức của AprioriHybrid. AprioriHybrid gốc chuyển giữa Apriori và AprioriTid.
- **Biểu diễn TID thích nghi.** Với item hiếm, thử danh sách TID sắp xếp hoặc bitmap nén. Dùng cột UInt64 cho item đủ dày. So thời gian giao, dung lượng chỉ mục và chi phí chuyển đổi trên Retail lẫn Chess ở cùng ngưỡng, kể cả trường hợp kiểu lai chậm hơn.

## Đối chiếu khi viết hai chương đầu

| Nội dung trong đề | Tài liệu và cách sử dụng |
|---|---|
| Chương 1, dòng 77–89 | Dùng [Apriori và bài báo](apriori-paper.md) cho bước sinh ứng viên, [chứng minh và chi phí](chuong-toi-uu-apriori.md) cho Bitset, Streaming và lưu mức trên đĩa. Phần tái tạo có [tỷ lệ đúng theo từng CSDL so với SPMF 2.68](../data/test-kit/README.md). Scan và Hash-tree mỗi bản đạt 8/8 CSDL. |
| Chương 2, dòng 93–125 | Dùng [các ZIP, CSV và bảng tổng hợp](../benchmarks/) cho so từng tập với SPMF, biểu đồ giảm minsup, RAM ở ngưỡng giữa và quy mô 10–100%. Có 120 lượt trên 40 cấu hình, mọi mapping khớp. SPMF nhanh nhất trên cả 40 cấu hình theo đồng hồ toàn tiến trình. |
| Chương 2, dòng 126–134 | Thí nghiệm độ dài ở đầu tài liệu này bổ sung biến còn thiếu. Retail nhân bản khảo sát giới hạn bộ nhớ. Liên hệ số ứng viên, chi phí bộ đếm và các hướng tối ưu ở trên với từng quan sát. |
| Phạm vi các đề xuất ngoài đề | CLI cơ bản đã đáp ứng I/O của đề. Đợt bổ sung mở đường xuất kết quả ở cả ba engine external, kiểm tra biên word của bitmap và packed key. Các nghiên cứu nhiều seed, áp trần bộ nhớ hệ điều hành, đo I/O vật lý và tách đóng góp của từng tối ưu là các bước mở rộng. Bộ CSV hiện đo một seed và peak toàn tiến trình. |

Khi viết mức cải thiện, ghi tên bản làm mốc ngay cạnh hệ số. Trong phép đo lịch sử từ khởi động đến ghi xong kết quả của bộ Scan/Hash-tree/SPMF, SPMF nhanh nhất ở 40/40 cấu hình và Hash-tree nhanh hơn Scan ở 1/40 cấu hình. Giao thức external sau warm-up trả lời câu hỏi về thay đổi bộ đếm hay cách lưu giao dịch. Phép đo xuất trọn tệp cho biết người dùng mất bao lâu so với Scan khi cần lấy toàn bộ kết quả. Chưa đo đồng thời SPMF với hai biến thể external trong hai giao thức này. [Đối chiếu giao thức và kết quả cơ bản](../benchmarks/summary/Thong-ke-Apriori.xlsx)
