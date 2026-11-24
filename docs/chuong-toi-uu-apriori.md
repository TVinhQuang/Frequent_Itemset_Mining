# Chương: Phân tích điểm nghẽn và tối ưu hiệu năng Apriori

## 1. Mục tiêu và phạm vi

Chương này mô tả hai biến thể được xây dựng từ cài đặt Apriori hiện tại của dự án. Cả hai giữ nguyên quy tắc Apriori: sinh ứng viên bằng join/prune, support là số transaction chứa toàn bộ itemset, ngưỡng tỷ lệ được đổi thành `ceil(min_support × N)`, và kết quả phải khớp tuyệt đối theo cặp `itemset → support_count`.

Hai mục tiêu tối ưu được tách riêng:

- **Tối ưu thời gian đếm support:** thay việc duyệt cấu trúc hash-tree theo từng transaction bằng giao các bitmap TID theo từng từ máy.
- **Tối ưu peak RAM:** không nạp toàn bộ database vào RAM; đọc tuần tự file SPMF ở từng lượt khai phá.

Hai hướng này có đặc tính khác nhau. Bitmap thường giảm chi phí CPU khi có đủ RAM cho ma trận bit; streaming giảm phần RAM dành cho database nhưng phải đọc file nhiều lượt.

## 2. Phiên bản hiện tại và các điểm nghẽn

### 2.1. Chuẩn hóa và lưu database trong RAM

Trong `src/apriori.jl`, `mine()` gọi `normalize_transactions()` và tạo `Vector{Vector{Int}}` mới. Mỗi transaction được sort và loại item trùng. Điều này đúng về ngữ nghĩa, nhưng toàn bộ transaction vẫn được giữ trong RAM trong suốt quá trình khai phá.

Ở luồng CLI, `read_spmf()` đã parse file thành một database trong RAM trước khi gọi `mine()`. Sau đó `mine()` lại chuẩn hóa sang một cấu trúc khác. Trong thời điểm chuẩn hóa, dữ liệu parse ban đầu và database đã chuẩn hóa có thể cùng tồn tại, làm tăng peak RAM. Bản streaming tránh giữ hai bản database này.

### 2.2. Đếm support bằng hash-tree vẫn phải quét toàn bộ transaction

Bộ đếm mặc định `:hash_tree` trong `count_candidates()` dựng `HashTree` và `HashQueryWorkspace` cho từng mức k, sau đó duyệt từng transaction để tìm candidate ID phù hợp. Cách này tốt hơn việc kiểm tra mọi candidate trong mọi transaction, nhưng vẫn có chi phí:

- Mỗi transaction phải cập nhật membership bitmap và truy vấn cây.
- Hash-tree giữ candidate, compressed candidate, node và workspace.
- Khi chuyển mức, cây của mức trước không còn cần thiết; mỗi mức lại có chi phí dựng cấu trúc.

Bộ đếm `:scan` còn tốn hơn trên dữ liệu có nhiều candidate: với mỗi transaction, nó tạo `Set(transaction)` rồi duyệt tất cả candidate và kiểm tra từng item.

### 2.3. Candidate generation và số lượng kết quả

`apriori_gen()` đã dùng join theo tiền tố, hash set để prune và `NTuple{K,Int}` để tránh khóa động trong vòng đếm. Đây là phần đã được tối ưu tương đối tốt. Tuy nhiên, Apriori vẫn có thể tạo ra rất nhiều candidate khi minsup thấp hoặc dữ liệu dày. Không có cấu trúc đếm nào loại bỏ được sự tăng trưởng tổ hợp đó; hai phiên bản mới vẫn giữ nguyên bước join/prune và vẫn phải lưu các frequent itemset trong kết quả.

## 3. Phiên bản tối ưu 1: Vertical TID Bitmap Apriori

### 3.1. Ý tưởng

Thay vì chỉ lưu transaction theo hàng (horizontal), chuyển các singleton frequent sang biểu diễn dọc (vertical): với mỗi item i, lưu bitmap cho biết transaction nào chứa i.

Ví dụ có 10 transaction, item 4 xuất hiện ở TID 1, 3, 6 và 9. Bitmap của item 4 sẽ có bit bật tại các vị trí đó. Bitmap được đóng gói thành `UInt64`, nên một từ 64 bit biểu diễn tối đa 64 transaction.

Với candidate `{a,b,c}`, các transaction chứa đủ cả ba item chính là giao của ba bitmap:

\[
T(a,b,c) = T(a) \;\&\; T(b) \;\&\; T(c)
\]

Support được tính bằng tổng số bit 1 trong bitmap giao:

\[
\operatorname{count}(a,b,c) = \sum_w \operatorname{popcount}(B_a[w] \& B_b[w] \& B_c[w]).
\]

Trong code, `count_ones(UInt64)` thực hiện popcount. Không tạo bitmap trung gian mới cho mỗi candidate; phép AND được tính trong biến cục bộ trên từng word.

### 3.2. Luồng thực thi

1. Đọc file một lượt để đếm N và support của singleton.
2. Tính `min_count` bằng đúng hàm `support_threshold()` của bản gốc; tạo L1.
3. Chỉ cấp bitmap cho các item thuộc L1. Các item không frequent không thể xuất hiện trong candidate hợp lệ nên không cần bitmap.
4. Đọc file lượt thứ hai; mỗi transaction đặt bit TID vào cột bitmap tương ứng.
5. Dùng lại `apriori_gen()` để sinh Ck. Với mỗi candidate, AND các cột bitmap và popcount để có support.
6. Lọc Lk, thêm support vào `MiningResult`, lặp đến khi không còn candidate.

### 3.3. Vì sao hướng này có thể nhanh hơn?

Với N transaction, F singleton frequent và Ck candidate ở mức k, số word bitmap là `ceil(N/64)`. Phần đếm support có chi phí xấp xỉ:

\[
O\left(C_k \times \lceil N/64 \rceil \times k\right).
\]

Các phép AND/popcount hoạt động trên từ máy 64 bit, giảm số vòng lặp so với việc duyệt candidate theo từng transaction. Ma trận bitmap cũng có layout liên tục theo cột, thuận lợi cho truy cập tuần tự.

Lợi ích lớn nhất thường xuất hiện khi database có nhiều transaction, số item frequent vừa phải và các lượt đếm hash-tree tốn đáng kể. Tốc độ thực tế còn phụ thuộc số candidate, độ dài transaction, minsup và CPU.

### 3.4. Đánh đổi và giới hạn

Bộ nhớ ma trận bitmap xấp xỉ:

\[
M_{bitmap} = 8 \times F \times \lceil N/64 \rceil\;\text{bytes}.
\]

Con số này chưa bao gồm dictionary ánh xạ item→cột, candidate, kết quả và Julia runtime. Nếu F hoặc N quá lớn, ma trận bitmap có thể tốn RAM. Vì vậy, đây là phiên bản ưu tiên **thời gian**, không phải lựa chọn tốt nhất trong mọi cấu hình RAM.

## 4. Phiên bản tối ưu 2: Streaming / External-memory Apriori

### 4.1. Ý tưởng

Bản hiện tại giữ toàn bộ database trong `Vector{Vector{Int}}`. Bản streaming thay bằng nguồn dữ liệu là đường dẫn file SPMF, parse từng dòng và chỉ giữ một transaction đã chuẩn hóa trong bộ nhớ tại một thời điểm.

Không cần nạp cả file vào RAM. Đổi lại, Apriori cần quét lại file một lần cho mỗi mức candidate vì support ở mức k phải được đếm trên toàn bộ transaction.

### 4.2. Luồng thực thi

1. Lượt đầu: đọc từng dòng, chuẩn hóa transaction và đếm support singleton; không lưu các transaction.
2. Tạo L1 và giữ support singleton trong kết quả.
3. Sinh C2, dựng hash-tree như phiên bản hiện tại.
4. Mở lại file; với mỗi transaction, tìm candidate ID bằng `matching_ids!()` và tăng counter tương ứng.
5. Lọc L2. Với mỗi mức tiếp theo, sinh candidate, dựng hash-tree và đọc lại file đúng một lượt.
6. Dừng theo cùng điều kiện của bản gốc.

### 4.3. Vì sao peak RAM giảm?

Bản streaming không có cấu trúc `database` chứa N transaction. Phần transaction-resident chỉ còn một dòng hiện tại, cộng với bộ đếm singleton trong lượt đầu. Trong các lượt tiếp theo, bộ nhớ chủ yếu phụ thuộc vào candidate của mức hiện tại, hash-tree/workspace, mảng support và kết quả cuối.

Do đó, phần RAM dành cho transaction giảm từ tỷ lệ với tổng số item xuất hiện trong toàn bộ database xuống tỷ lệ với transaction dài nhất. Đây là cải thiện đáng kể khi database lớn nhưng mỗi transaction tương đối ngắn.

### 4.4. Đánh đổi và giới hạn

Nếu thuật toán đi qua K mức candidate khác nhau, bản streaming đọc file xấp xỉ K+1 lượt (một lượt singleton và một lượt cho mỗi mức có candidate). Vì thế tổng I/O tuần tự tăng theo số mức. Nếu file nằm trên ổ đĩa chậm hoặc số mức lớn, thời gian có thể cao hơn bản giữ database trong RAM.

Streaming **không** loại bỏ bộ nhớ dành cho candidate và kết quả frequent itemsets. Dataset dày/minsup rất thấp có thể làm candidate hoặc output tăng mạnh; đây vẫn là giới hạn của Apriori.

## 5. So sánh ba phiên bản

| Tiêu chí | Bản hiện tại (`hash-tree`) | Tối ưu 1 (`bitset`) | Tối ưu 2 (`streaming`) |
|---|---|---|---|
| Biểu diễn transaction | Toàn bộ database dạng vector các vector | Đọc file, sau đó bitmap dọc cho L1 | Đọc file từng dòng, không giữ database |
| Đếm candidate | Hash-tree truy vấn từng transaction | AND bitmap singleton + popcount | Hash-tree truy vấn từng transaction khi stream |
| Số lượt đọc đầu vào | CLI parse một lượt; `mine()` nhận database trong RAM | 2 lượt đọc file (singleton + bitmap) | 1 lượt singleton + 1 lượt cho mỗi mức candidate |
| Mục tiêu chính | Baseline cân bằng | Giảm thời gian đếm support | Giảm peak RAM của database |
| RAM dữ liệu | O(tổng số item xuất hiện) và cấu trúc đếm | O(F × N/64) word bitmap | O(transaction dài nhất) cho phần dữ liệu đầu vào |
| Rủi ro chính | Bản database và bản normalize có thể cùng tồn tại | Bitmap quá lớn khi F×N cao | I/O tăng theo số mức |
| Phù hợp khi | RAM đủ, cần baseline chung | Cần tốc độ và bitmap vừa RAM | RAM giới hạn, file lớn, transaction đọc tuần tự được |

### 5.1. Kỳ vọng theo loại dataset

- **Dữ liệu dày, nhiều candidate:** bitmap có thể giảm đáng kể chi phí đếm nhờ phép AND theo word; tuy nhiên candidate generation vẫn có thể chiếm phần lớn tổng thời gian.
- **Dữ liệu thưa, nhiều item ID nhưng ít singleton frequent:** bitmap chỉ cấp cho L1 nên không bị phụ thuộc vào giá trị lớn nhất của item ID. Nếu F nhỏ, ma trận thường gọn.
- **Dataset có N rất lớn:** streaming có ưu thế về RAM vì không materialize toàn bộ transaction; đổi lại sẽ đọc file nhiều lượt.
- **Minsup thấp:** L1 và Ck có thể tăng mạnh. Bitmap cần nhiều cột hơn; streaming vẫn phải giữ candidate/tree và kết quả. Cần kiểm tra cả hai chỉ số thời gian và RAM thay vì chỉ nhìn một chỉ số.

Đây là kỳ vọng dựa trên cấu trúc dữ liệu và độ phức tạp, không phải số đo thực nghiệm. Kết luận cuối cùng phải dùng CSV do chương trình benchmark sinh trên cùng máy.

## 6. Quy trình đo thực nghiệm

### 6.1. Chạy benchmark

Từ thư mục gốc dự án:

```powershell
julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/chess.txt --minsup 0.10 --repeats 5 --seed 42 --output output/chess-apriori.csv
julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/mushrooms.txt --minsup 0.10 --repeats 5 --seed 42 --output output/mushrooms-apriori.csv
julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/retail.txt --minsup 0.10 --repeats 5 --seed 42 --output output/retail-apriori.csv
julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/pumsb.txt --minsup 0.10 --repeats 5 --seed 42 --output output/pumsb-apriori.csv
```

Ngưỡng `0.10` ở ví dụ chỉ là tham số minh họa. Khi làm báo cáo chính thức, phải dùng cùng minsup/min_count với cấu hình benchmark của nhóm, không tự ý thay ngưỡng giữa các engine. Có thể thay `--minsup` bằng `--min-count N`.

Đổi baseline sang bộ đếm scan để đối chiếu thêm:

```powershell
julia --project=. bin/benchmark-optimized.jl --input data/benchmarks/chess.txt --min-count 100 --baseline scan --repeats 5
```

Mỗi engine được chạy trong một process Julia riêng. Chương trình warm-up mặc định một lượt, sau đó lấy median của các lượt đo; process wrapper ghi peak RSS/working set. `median_ms` bao gồm parse đầu vào và khai phá nhưng không bao gồm ghi itemset ra file. `process_wall_ms` có cả startup, warm-up và shutdown. Peak RAM có cả runtime Julia và warm-up, nên chỉ so sánh các engine chạy trên cùng môi trường.

### 6.2. File kết quả

Chương trình sinh:

- `output/apriori_optimization_results.csv`: dữ liệu số, gồm 15 dòng cho một dataset (5 tỷ lệ × 3 engine), dùng để phân tích hoặc vẽ biểu đồ.
- `output/apriori_optimization_results.md`: bảng so sánh tự động, chia theo từng tỷ lệ 10%, 25%, 50%, 75%, 100%.
- `output/apriori_optimization_results.csv.samples/`: năm file SPMF được lấy mẫu và `manifest.csv` ghi tỷ lệ, số giao tác, seed, đường dẫn file.
- `output/apriori_optimization_results.csv.logs/`: log riêng cho từng process con ở từng tỷ lệ để điều tra nếu engine lỗi.

Các cột quan trọng:

- `median_ms`: median thời gian end-to-end của một lượt đo.
- `peak_ram_mib`: peak resident memory của process.
- `speedup_vs_baseline`: `median_baseline / median_engine`; lớn hơn 1 nghĩa là nhanh hơn baseline.
- `ram_reduction_pct`: `(peak_baseline - peak_engine) / peak_baseline × 100`; dương nghĩa là tiết kiệm RAM.
- `same_as_baseline`: kiểm tra fingerprint kết quả, tổng support và thống kê mức có trùng baseline hay không.

Fingerprint giúp phát hiện sai khác giữa các process trong benchmark nhưng không thay thế so sánh chính xác toàn bộ mapping. Bộ test mới `test/apriori_optimized.jl` đối chiếu trực tiếp `Dict(itemset => support)` với `mine()` trên 8 test-kit và dữ liệu ngẫu nhiên. Báo cáo cuối cùng vẫn nên chạy `julia --project=. test/runtests.jl` và đối chiếu SPMF theo protocol hiện tại của nhóm.

### 6.3. Bảng ghi nhận kết quả

Điền hoặc trích số liệu từ CSV sinh trên máy thực nghiệm; không điền số ước lượng vào báo cáo:

Mỗi dataset sinh 15 dòng kết quả: 5 quy mô × 3 engine. Bảng CSV có thêm `sample_pct`, `transactions`, `sample_input` và `seed` để lọc hoặc vẽ đường tăng trưởng theo quy mô.

| Dataset | Tỷ lệ | Số giao tác | Engine | Median time (ms) | Peak RAM (MiB) | Speedup | RAM giảm (%) | Khớp |
|---|---:|---:|---|---:|---:|---:|---:|---|
| Chess | 10% | — | Baseline hash-tree | — | — | 1.00× | 0.0 | — |
| Chess | 10% | — | Vertical bitset | — | — | — | — | — |
| Chess | 10% | — | Streaming | — | — | — | — | — |
| Chess | 25% | — | ... | — | — | — | — | — |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |
| Chess | 100% | — | Streaming | — | — | — | — | — |

### 6.4. Thí nghiệm theo năm quy mô giao tác

Mỗi lần chạy benchmark không chỉ đo trên toàn bộ file gốc. Chương trình tự tạo lần lượt năm tập con có kích thước 10%, 25%, 50%, 75% và 100% tổng số giao tác. Mặc định `--seed 42`; người dùng có thể thay bằng `--seed N` để tạo một mẫu khác nhưng vẫn tái lập được.

Cách lấy mẫu tuân thủ giao thức `APRIORI-V1` trong `benchmarks/AGENTS.md`:

1. Đọc giao tác theo thứ tự nguồn bằng `read_spmf()`: bỏ dòng trống và metadata, sắp mã item trong từng giao tác, loại item trùng trong giao tác; vẫn giữ các giao tác trùng nội dung. Đánh số TID hợp lệ từ 1 đến N.
2. Với mỗi TID `i`, tính SHA-256 của chuỗi UTF-8 `apriori-v1|42|i` (không có ký tự xuống dòng). Xếp TID theo digest hex tăng dần; nếu digest hòa thì giữ TID tăng dần. Runner cho phép đổi seed bằng `--seed`, mặc định và seed dùng cho kết quả nhóm là 42.
3. Với mỗi tỷ lệ p trong 10%, 25%, 50%, 75%, 100%, chọn đúng `floor(N × p / 100)` TID đầu trong thứ hạng SHA-256. Không làm tròn lên và không tự ép số lượng tối thiểu thành 1; nếu tỷ lệ tạo mẫu rỗng, runner báo lỗi để tránh âm thầm thay đổi giao thức.
4. Sắp các TID được chọn theo thứ tự nguồn rồi ghi giao tác đã chuẩn hóa, mỗi giao tác một dòng, cách item bằng một dấu cách và kết thúc bằng LF. Như vậy các tập con lồng nhau; mẫu 100% giữ toàn bộ giao tác hợp lệ theo thứ tự ban đầu.
5. Ghi `source_sha256`, `sample_sha256` và `selected_tid_sha256` trong manifest/CSV để kiểm tra input, byte file mẫu và danh sách TID. Chạy baseline, Bitset và Streaming trên cùng file mẫu vật lý; việc tạo mẫu nằm ngoài thời gian và peak RAM của engine.

Với `--minsup RATIO`, mỗi tỷ lệ có ngưỡng đếm riêng: `min_count = ceil(RATIO × số_giao_tác_của_tập_con)`. Đây là cách giữ nguyên ý nghĩa support tương đối khi quy mô dữ liệu thay đổi. Với `--min-count N`, giữ nguyên N ở cả năm tỷ lệ để thực hiện thí nghiệm theo ngưỡng support tuyệt đối; ở các tập con nhỏ, N có thể lớn hơn số giao tác và khi đó kết quả có thể rỗng.

Nên dùng cùng seed khi so sánh nhiều thuật toán hoặc nhiều lần chạy cùng dataset. Nếu muốn kiểm tra độ nhạy với việc chọn mẫu, có thể lặp lại toàn bộ benchmark với một vài seed khác nhau; không nên thay seed giữa ba engine trong cùng một lần so sánh.

## 7. Kết luận

Hai bản tối ưu giải quyết hai điểm nghẽn khác nhau. Vertical TID Bitmap thay đổi cách đếm support để giảm thao tác theo transaction; đổi lại nó cần ma trận bit có kích thước phụ thuộc vào số singleton frequent và số transaction. Streaming giữ cơ chế candidate/hash-tree của dự án nhưng thay database trong RAM bằng các lượt đọc tuần tự; nó phù hợp để giảm peak RAM và chấp nhận tăng thời gian I/O.

Không có một engine thắng trong mọi dataset. Nếu ưu tiên tốc độ và bitmap vừa RAM, chọn bitset sau khi đo. Nếu ưu tiên giới hạn RAM, chọn streaming. Nếu RAM đủ và dữ liệu phù hợp, baseline hash-tree vẫn có thể là lựa chọn cân bằng. Quyết định trong báo cáo phải dựa trên median thời gian, peak RAM và kiểm tra khớp support cùng lúc.
