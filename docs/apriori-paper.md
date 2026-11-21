# Apriori: đọc bài báo và diễn giải từng bước

Tài liệu nền: Rakesh Agrawal và Ramakrishnan Srikant, [*Fast Algorithms for Mining Association Rules*](apriori_longer.pdf). Phần trọng tâm là §2.1, Figure 1 và §2.1.1–2.1.2, trang 5–8 của PDF. Nội dung dưới đây diễn giải thuật toán; chưa phải bằng chứng một cài đặt đã được kiểm chứng với SPMF.

## 1. Apriori giải bài toán nào?

Cho một cơ sở dữ liệu D gồm N giao dịch. Mỗi giao dịch là một tập item. Với một itemset X, support count là số giao dịch chứa toàn bộ X:

\[
\operatorname{count}(X) = |\{t \in D : X \subseteq t\}|.
\]

Nếu dùng support dạng tỷ lệ, khi N > 0:

\[
\operatorname{support}(X) = \frac{\operatorname{count}(X)}{N}.
\]

Apriori tìm **tất cả itemset không rỗng** có support đạt ngưỡng. Trong bài báo, chúng được gọi là *large itemsets*; thuật ngữ thường dùng hiện nay là *frequent itemsets*.

Một giao dịch `{1, 1, 3}` được hiểu là `{1, 3}`. Item 1 chỉ được đếm một lần trong giao dịch đó. Tuy nhiên, hai dòng giao dịch giống nhau vẫn là hai quan sát riêng và cùng đóng góp vào support.

§1.1 tách khai thác luật kết hợp thành hai bài toán: tìm frequent itemsets trước, rồi sinh luật từ các itemsets đó. Bước hiện tại tập trung vào bài toán thứ nhất. Confidence và lift thuộc bước làm ứng dụng giỏ hàng sau này.

## 2. Vì sao có thể loại ứng viên sớm?

Nếu Y là tập con của X thì mọi giao dịch chứa X đều chứa Y. Vì vậy:

\[
Y \subseteq X \Rightarrow \operatorname{count}(Y) \geq \operatorname{count}(X).
\]

Suy ra:

- Nếu X frequent thì mọi tập con không rỗng của X đều frequent.
- Nếu một tập con của X không frequent thì X không thể frequent.

Đây là cơ sở của bước prune. Nó cho phép loại một ứng viên trước khi tốn công quét dữ liệu để đếm ứng viên đó. Các item trong transaction/itemset được sắp tăng dần để join có quy tắc và tránh tạo trùng; việc sắp này không mang ý nghĩa thứ tự sinh học hay thời gian.

## 3. Các ký hiệu trong Figure 1

| Ký hiệu | Ý nghĩa |
|---|---|
| k-itemset | Itemset gồm k item khác nhau |
| L_k | Các frequent k-itemsets, kèm support count |
| C_k | Các candidate k-itemsets, kèm count đang được tích lũy |
| C_t | Các ứng viên trong C_k được chứa trong transaction t |
| apriori-gen | Sinh C_k từ L_(k-1) bằng join và prune |
| subset(C_k, t) | Tìm các ứng viên thuộc C_k được chứa trong t |

C_k chỉ chứa các tập **có khả năng** frequent; phải đếm và lọc mới có L_k. Cấu trúc C có dấu gạch phía trên trong phần AprioriTid là cấu trúc khác, không dùng trong vòng lặp plain Apriori đang xét.

## 4. Luồng chính của Apriori

1. Quét D, đếm từng item và giữ những item đủ ngưỡng để tạo L_1.
2. Đặt k = 2. Dùng L_(k-1) để sinh toàn bộ C_k trước khi quét dữ liệu ở mức này.
3. Đặt count của mỗi ứng viên bằng 0.
4. Với từng giao dịch t, tìm C_t = subset(C_k, t). Mỗi ứng viên trong C_t được tăng count đúng một lần.
5. Giữ các ứng viên có count >= ngưỡng để tạo L_k.
6. Chuyển sang mức k + 1. Dừng khi L_k rỗng hoặc không thể sinh ứng viên tiếp theo.
7. Trả về hợp của tất cả L_1, L_2, ... cùng support count.

Điểm cần giữ đúng: mỗi mức quét lại các giao dịch gốc. Không thay vòng quét này bằng giao tidset rồi coi đó là cấu trúc Apriori trong §2.1.

## 5. apriori-gen gồm join rồi prune

### Join

Hai itemset p và q trong L_(k-1) được ghép khi:

- k - 2 item đầu giống nhau;
- item cuối của p nhỏ hơn item cuối của q.

Ứng viên được tạo từ toàn bộ p rồi thêm item cuối của q. Ví dụ `{2,3}` và `{2,5}` sinh `{2,3,5}`. Hai tập `{1,2}` và `{2,3}` không có cùng tiền tố nên không được join trực tiếp theo quy tắc này.

### Prune

Với ứng viên c có k item, kiểm tra mọi tập con dài k - 1. Nếu có một tập con không thuộc L_(k-1), loại c. Tra cứu bằng hash set/hash table giúp bước membership này nhanh hơn tìm tuần tự.

Ví dụ ở trang 6:

```text
L3 = {123, 124, 134, 135, 234}
Sau join:  C4 = {1234, 1345}
Sau prune: C4 = {1234}
```

Ở đây `1234` viết gọn cho `{1,2,3,4}`. Ứng viên `1345` bị loại vì tập con `145` không thuộc L3; `345` cũng không thuộc L3. Các tập con `123`, `124`, `134`, `234` của `1234` đều thuộc L3.

**Lỗi trong bài báo:** câu so sánh ở cuối ví dụ trang 6 ghi Apriori chỉ đếm `{1,3,4,5}`, trái với chính kết quả join/prune ngay phía trên. Kết quả đúng theo quy tắc và ví dụ là `{1,2,3,4}`. Không dùng câu ghi nhầm đó làm đáp án kiểm thử.

## 6. subset và hash-tree trong §2.1.2

Một cách đơn giản để hiện thực subset là duyệt từng ứng viên trong C_k và kiểm tra xem nó có nằm trong transaction hay không. Cách này giữ đúng kết quả Figure 1 và thuận tiện để học, nhưng có thể kiểm tra rất nhiều ứng viên không liên quan.

Bài báo tổ chức C_k bằng **hash-tree**:

- Lá giữ danh sách ứng viên.
- Node trong giữ các bucket trỏ tới node con.
- Node ở độ sâu d phân nhánh theo hash của item thứ d trong ứng viên; bài dùng gốc ở độ sâu 1.
- Khi lá chứa quá nhiều ứng viên, tách lá thành node trong và phân phối lại. Không tách quá vị trí item cuối của ứng viên.

Khi truy vấn một transaction, duyệt các item theo vị trí tăng dần để đi qua những bucket có thể chứa ứng viên phù hợp. Khi đến lá, vẫn phải kiểm tra toàn bộ ứng viên có nằm trong transaction hay không: hai item khác nhau có thể cùng bucket do hash collision.

**Hai điều kiện đúng đắn dễ bị bỏ sót:**

1. Collision không được khiến ứng viên thiếu item vẫn được tính là có mặt.
2. Một transaction có thể đi đến cùng lá qua nhiều đường collision. Mỗi ứng viên phù hợp vẫn chỉ được tăng count một lần cho transaction đó. Có thể dùng tập ID kết quả hoặc dấu đánh dấu theo transaction; không đánh dấu bỏ qua node trong toàn cục vì các lần đến node có thể có phần đuôi transaction khác nhau.

Trang 8 mô tả bitmap tạm để kiểm tra một ứng viên trong O(k). Khi item ID thưa và lớn, có thể ánh xạ ID sang chỉ số liên tục trước khi dựng bitmap; đây là quyết định hiện thực, không thay đổi itemset hay support. Hash-tree hỗ trợ đếm, còn join/prune vẫn quyết định tập ứng viên.

## 7. Chạy tay trên dữ liệu trong bài báo

Dùng cơ sở dữ liệu ở Figure 3, trang 10. Figure này minh họa AprioriTid, nhưng D và các L_k cũng là kết quả cần thu được khi chạy plain Apriori trên cùng D và cùng ngưỡng.

| TID | Items |
|---|---|
| 100 | 1, 3, 4 |
| 200 | 2, 3, 5 |
| 300 | 1, 2, 3, 5 |
| 400 | 2, 5 |

N = 4, chọn minsup = 0.5, tương đương min_count = 2.

### Mức 1

| Itemset | Count | Giữ? |
|---|---:|---|
| {1} | 2 | Có |
| {2} | 3 | Có |
| {3} | 3 | Có |
| {4} | 1 | Không |
| {5} | 3 | Có |

Vậy L1 có 4 itemsets: `{1}`, `{2}`, `{3}`, `{5}`.

### Mức 2

| Ứng viên C2 | Count | Giữ trong L2? |
|---|---:|---|
| {1,2} | 1 | Không |
| {1,3} | 2 | Có |
| {1,5} | 1 | Không |
| {2,3} | 2 | Có |
| {2,5} | 3 | Có |
| {3,5} | 2 | Có |

### Mức 3 và dừng

Từ L2, `{2,3}` và `{2,5}` join thành `{2,3,5}`. Ba tập con `{2,3}`, `{2,5}`, `{3,5}` đều frequent nên ứng viên qua prune.

`{2,3,5}` có trong TID 200 và 300, count = 2, nên thuộc L3. L3 chỉ còn một itemset nên không sinh được ứng viên dài 4. Thuật toán dừng.

Kết quả cuối cùng có **9 frequent itemsets**: 4 singleton, 4 cặp và 1 bộ ba. Kết quả phải chứa cả 9 tập cùng support của chúng, không chỉ bộ ba cuối cùng.

## 8. Chuyển minsup tỷ lệ sang ngưỡng đếm

Với tỷ lệ s, dùng:

\[
\operatorname{min\_count} = \lceil sN \rceil.
\]

Ví dụ `s = 0.34`, `N = 3` thì ngưỡng bằng 2. Với chuỗi thập phân `0.07` và N = 100, ngưỡng đúng bằng 7; cần tránh để sai số số thực đẩy thành 8.

API/CLI phân biệt rõ ngưỡng tỷ lệ và ngưỡng count. Support đúng bằng ngưỡng vẫn được giữ. Đây là quy ước kết nối giao diện với phép so count trong Figure 1.

## 9. Những điều cần kiểm chứng khi cài

- Chín itemsets và support trong ví dụ Figure 3 phải khớp hoàn toàn.
- Ví dụ trang 6 phải sinh và prune đúng ứng viên.
- Đối chiếu scan, hash-tree và một oracle vét cạn độc lập trên ít nhất 5 CSDL nhỏ.
- Ép mọi item vào cùng bucket để kiểm tra collision, kết quả không được đếm lặp hoặc nhận nhầm ứng viên.
- Kiểm tra item/transaction trùng, đầu vào chưa sắp thứ tự, item ID thưa, empty database và ngưỡng sát biên.
- Kiểm tra đọc/xuất SPMF và lỗi đầu vào.
- Sau khi có SPMF thật, tiếp tục so sánh toàn bộ mapping itemset -> support. Vét cạn đúng trên dữ liệu nhỏ chưa thay thế phép đối chiếu SPMF mà đề yêu cầu.

Số lượng ứng viên có thể tăng rất lớn ở dữ liệu dày và minsup thấp. Hash-tree không loại bỏ độ khó tổ hợp của bài toán và không đảm bảo luôn nhanh hơn scan. §2.1.3 còn mô tả cách xử lý khi ứng viên không vừa RAM; bản đầu sẽ nêu rõ giới hạn nạp dữ liệu vào RAM, phần quản lý ngoài RAM để bước sau.

## 10. Liên hệ với mã nguồn đã cài

Chương trình dùng Julia >= 1.9. Module [FrequentItemsetMining.jl](../src/FrequentItemsetMining.jl) nạp các thành phần bên dưới; chỉ dùng thư viện chuẩn.

| Nội dung bài báo | Mã nguồn | Cách đọc |
|---|---|---|
| Định nghĩa transaction là tập item | `normalize_transactions` trong [apriori.jl](../src/apriori.jl) | Bỏ item trùng nhưng giữ các dòng transaction trùng và transaction rỗng trong API |
| Ngưỡng count trong Figure 1 | `support_threshold`, `decimal_ratio` trong [apriori.jl](../src/apriori.jl) | Chuyển chuỗi tỷ lệ thành `Rational{BigInt}` và ceiling chính xác |
| Figure 1: vòng lặp Apriori | `mine`, `next_level` trong [apriori.jl](../src/apriori.jl) | L1, sinh Ck, quét dữ liệu, lọc Lk, tích lũy kết quả |
| §2.1.1: join và prune | `apriori_gen` trong [apriori.jl](../src/apriori.jl) | Join cùng tiền tố bằng chỉ số, rồi kiểm tra mọi tập con dài k-1 |
| subset(Ck, t), bản dễ đọc | `count_candidates` với `Val(:scan)` trong [apriori.jl](../src/apriori.jl) | Kiểm tra từng ứng viên đối với transaction |
| §2.1.2: hash-tree | `HashTree`, `HashQueryWorkspace`, `matching_ids!` trong [hash_tree.jl](../src/hash_tree.jl) | Tách lá, truy vấn ID ứng viên và xử lý collision |
| Hợp tất cả Lk | `MiningResult.itemsets` | Mapping từ tuple item tăng dần sang support count |
| Quan sát lần chạy thực tế | `ExplainTrace`, `record!` trong [explain.jl](../src/explain.jl) và các lời gọi trong `mine`, `apriori_gen`, `count_candidates` | Stream diễn giải từ bước đang chạy, giới hạn số dòng chi tiết nhưng luôn ghi tổng kết cuối |
| Thời gian của các bước đang chạy | `PhaseTiming`, `MiningResult.timings`, `MiningResult.mining_ns` trong [apriori.jl](../src/apriori.jl) | `time_ns()` đo các vùng thực thi; join + prune chung một phase, dựng hash-tree riêng với đếm support |
| Lưu kết quả cho đối chiếu sau này | [reports.jl](../src/reports.jl), [cli.jl](../src/cli.jl) | Mỗi lần CLI thành công có bundle mới với itemsets, báo cáo, CSV timing và metadata SHA256 |
| Định dạng dữ liệu và giao diện | [io.jl](../src/io.jl), [cli.jl](../src/cli.jl), [bin/apriori.jl](../bin/apriori.jl) | Đọc/ghi SPMF, kiểm tra tham số và trace |

Ở bước kiểm tra tại lá, bản Julia dùng `BitVector` tái sử dụng trên chỉ số item đã nén tọa độ. Mỗi truy vấn đặt các bit của transaction và xóa các vị trí đã chạm để dùng lại workspace; kiểm tra đầy đủ từng ứng viên trong O(k), tránh cấp bộ nhớ theo item ID lớn nhất. Đánh dấu lá đã kiểm tra theo từng transaction ngăn đếm lặp khi collision dẫn nhiều đường đến cùng lá. Thuật toán vẫn quét dữ liệu gốc theo từng mức Apriori.

Mỗi mức giữ ứng viên dưới dạng `Vector{NTuple{K,Int}}`, support trong `Vector{Int}` và cây `HashTree{K}`. Function barrier giữa các mức cho phép vòng đếm chuyên biệt theo K; mapping tuple nhiều độ dài chỉ xuất hiện tại biên kết quả. Các lựa chọn này chưa chứng minh Julia hoặc hash-tree nhanh hơn nếu chưa đo benchmark.

Thứ tự đọc mã gợi ý: `mine` với `counter=:scan` trước, rồi `apriori_gen`, cuối cùng `HashTree` với `counter=:hash_tree`. Hai bộ đếm có cùng hợp đồng kết quả để đối chiếu. Ví dụ API: `using FrequentItemsetMining; mine(rows; min_support="0.5", counter=:hash_tree)`.

Chạy ví dụ từ thư mục gốc (tạo thư mục `output` nếu chưa có):

```sh
julia --project=. bin/apriori.jl --input data/toy/paper.txt --output output/paper.txt --minsup 0.5 --counter hash-tree --trace
```

Trace mong đợi của ví dụ:

```text
transactions=4 min_count=2 itemsets=9
k=1 candidates=5 frequent=4
k=2 candidates=6 frequent=4
k=3 candidates=1 frequent=1
```

`levels` chỉ ghi các mức đã được đếm; không thêm dòng C4=0 khi không còn ứng viên để quét. Chạy kiểm thử bằng `julia --project=. test/runtests.jl`; xem [README](../README.md) để chạy API và theo dõi trạng thái xác minh. Julia 1.13.4 đã vượt qua 2.813 assertions, gồm timing/report/history; bộ 8 CSDL với diễn giải bật đạt 16/16 PASS. Các kiểm tra trước đó cũng đối chiếu 20 kết quả CLI trên 5 CSDL toy với oracle vét cạn độc lập. Các kiểm tra này chưa thay thế đối chiếu SPMF/Java thật.

## 11. Đọc diễn giải của lần chạy thực tế

`--trace` ở trên là bảng thống kê ngắn. Để thấy cách thuật toán đi đến kết quả, thêm `--explain` vào lệnh CLI: chương trình ghi diễn giải tiếng Việt lên stderr. Dùng `--explain-file PATH` để tự bật diễn giải và ghi vào file UTF-8 riêng; file kết quả `--output` vẫn theo định dạng SPMF. Xem [lệnh PowerShell chạy bộ 01](chay-apriori.md#xem-từng-bước-apriori) và cách chạy toàn bộ test kit với `-Explain` trong README.

Diễn giải bắt đầu bằng N, ngưỡng count, bộ đếm và từng transaction sau chuẩn hóa. Ở mức 1, mỗi lần một item xuất hiện trong transaction sẽ tăng count đúng một lần; chương trình so count với ngưỡng rồi liệt kê L_1. Ở các mức tiếp theo, đọc theo thứ tự:

1. `JOIN`: hai itemsets cùng tiền tố sinh một ứng viên.
2. `Ứng viên ... qua prune` hoặc `PRUNE ... thiếu tập con ...`: kiểm tra điều kiện mọi tập con thuộc mức frequent trước. Khi gặp tập con thiếu đầu tiên, ứng viên bị loại ngay.
3. `C_k sau prune`: số ứng viên thực sự được đưa vào bước đếm; các dòng join/prune phía trước cho biết chúng được tạo và giữ như thế nào.
4. `Quét T...` và `T... chứa ...: count a -> b`: ứng viên khớp transaction và support vừa được cập nhật. Đây là các lần tăng count trong bộ đếm đang chạy.
5. `GIỮ`/`LOẠI`: so support cuối mức với ngưỡng. `L_k` và các dòng `#SUP` sau đó liệt kê những itemsets được giữ.
6. `DỪNG`: CSDL rỗng, L_k rỗng hoặc không sinh được C_k tiếp theo. `KẾT THÚC` ghi tổng số frequent itemsets thu được.

Các sự kiện phát trực tiếp từ `mine`, `apriori_gen` và hai vòng `count_candidates`; chương trình không chạy một thuật toán mô phỏng riêng để dựng lại log. Với `hash-tree`, các dòng transaction phản ánh những ứng viên thực sự trả về sau kiểm tra đầy đủ và khử đếm lặp do collision. Diễn giải hiện tại quan sát kết quả khớp và cập nhật support, không trình bày từng bucket/nút hoặc lần tách lá. Chẳng hạn bộ 01 có 6 ứng viên C_2, chưa vượt sức chứa lá mặc định 8, nên không có lý do để nói gốc cây đã tách trong ví dụ đó.

### Ví dụ có ứng viên bị prune loại

Bộ `01_spmf_example` với `--minsup 0.40` có ngưỡng count 2 và không có ứng viên bị prune loại. Để thấy một trường hợp loại thực tế, dùng API với bốn transaction sau:

```julia
using FrequentItemsetMining

rows = [[1, 2], [1, 2], [1, 3], [1, 3]]
result = mine(rows; min_count=2, explain=ExplainTrace(stdout))
```

L_1 gồm `{1}`, `{2}`, `{3}`. C_2 gồm ba cặp; `{1,2}` và `{1,3}` đều có support 2, còn `{2,3}` có support 0 nên bị loại khi lọc support. Tại mức 3, hai cặp trong L_2 có cùng tiền tố `{1}`, nên join được `{1,2,3}`. Đoạn log lúc đó là:

```text
MỨC k=3
JOIN {1,2} + {1,3} -> {1,2,3}
PRUNE {1,2,3}: thiếu tập con {2,3} trong L_2 -> loại
C_3 sau prune: 0 ứng viên
DỪNG: C_3 rỗng, không còn ứng viên để đếm.
KẾT THÚC: 5 frequent itemsets; support là số giao dịch chứa itemset.
```

Ứng viên `{1,2,3}` bị loại trước bước đếm, nên không có lần quét transaction cho mức 3. Điều này khác với `{2,3}` ở mức 2: cặp đó đã qua prune, được đếm, rồi mới bị loại vì support dưới ngưỡng.

### Giới hạn log và API

`ExplainTrace(stdout; limit=5000)` hoặc CLI `--explain-limit 5000` giới hạn 5.000 dòng chi tiết theo mặc định; N phải là số nguyên dương. Khi cần cắt log, chương trình ghi thông báo một lần, vẫn tiếp tục khai phá và luôn ghi dòng `KẾT THÚC`. Số dòng thông báo cắt và tổng kết cuối nằm ngoài giới hạn chi tiết, nên tổng số dòng có thể lớn hơn N. Giới hạn không thay đổi itemsets hoặc support.

Không truyền `explain` (hoặc `explain=nothing`) thì tắt diễn giải. Tạo `ExplainTrace` mới cho mỗi lời gọi `mine` vì sink giữ bộ đếm số dòng đã ghi. Các sự kiện được ghi lần lượt ra IO, không lưu toàn bộ lịch sử trong RAM.

## 12. Kết quả và thời gian tự lưu sau mỗi lần chạy

Lệnh quen thuộc sau chạy lại toàn bộ 8 CSDL với cả hai bộ đếm và tự tạo một batch báo cáo mới:

```powershell
.\bin\test-kit.ps1 -Explain
```

Mở `output/test-kit/runs/<batch-id>/<counter>/<dataset>/report.txt` để xem toàn bộ frequent itemsets, support count, tỷ lệ `count/N` và bảng thời gian theo k. Cùng thư mục có `itemsets.txt` dạng SPMF, `timings.csv` giữ `elapsed_ns` gốc và `elapsed_ms`, `metadata.toml` ghi dữ liệu/mã nguồn SHA256 cùng tham số/runtime, và `trace.txt` khi bật `-Explain`. File `results.csv` ở gốc batch tổng hợp đối chiếu, thời gian và đường dẫn từng báo cáo. Mỗi batch giữ riêng lịch sử; các output phẳng cũ được giữ nguyên.

Khi chạy một CSDL riêng, CLI tự đánh số báo cáo trong `output/runs/<dataset>-<số>/`. Nếu đặt `--output FILE`, thư mục `runs` nằm cạnh file đó. `--report-dir PATH` cho phép chọn thư mục báo cáo mới theo tên riêng. `--quiet` ẩn thông báo thành công. [Lệnh chạy riêng bộ 01](chay-apriori.md#xem-từng-bước-apriori).

Log và số đo được sinh từ quá trình thực thi hiện tại. Nội dung giải thích có thể giống nhau giữa hai lần chạy vì input, ngưỡng và thứ tự duyệt giống nhau; đây không phải dấu hiệu dùng lại log tĩnh. Thời điểm UTC, run-id, hash input/mã nguồn và số đo thực tế được lưu cùng kết quả để kiểm tra điều kiện chạy.

| Phase/phạm vi | Ý nghĩa |
| --- | --- |
| `normalize`, `threshold` | Chuẩn hóa transaction và xác định ngưỡng count. |
| `singleton_count`, `filter` | Đếm item đơn, rồi lọc theo ngưỡng; `filter` cũng có ở các mức sau. |
| `generate_candidates` | Toàn bộ join và prune trong `apriori_gen`, gộp chung một số đo. |
| `build_counter` | Dựng hash-tree/workspace; scan ghi 0. |
| `count_support` | Quét transaction để đếm các ứng viên sau prune. |
| `level_total` | Tổng một mức k, chứa các phase con; có cả lần sinh C_k rỗng cuối cùng. |
| `mining_total` / `MiningMs` | Thời gian `mine()`, gồm bookkeeping và diễn giải; không gồm file input/output. |
| `read_input`, `write_output` | Đọc/parse file input và ghi kết quả SPMF, đo riêng ở CLI. |
| `warmup_total` | Các lượt khai phá không diễn giải trước lượt đo chính; mặc định không chạy. |
| `cli_total` / `CliMs` | Xử lý CLI sau parse đến trước đối chiếu hash cuối/serialize báo cáo, gồm đọc/ghi, hash snapshot và warmup; không gồm khởi động Julia. |
| `ProcessWallMs` trong batch CSV | Stopwatch quanh tiến trình Julia, gồm khởi động, biên dịch, xử lý và ghi bundle. |

Các dòng `level_total` và phase con lồng nhau; **không cộng mọi dòng thành tổng**. Lần sinh C_k rỗng có timing nhưng không thêm một `LevelStats` đã đếm giả. Đồng hồ `time_ns()` là monotonic; số đo vẫn có thể gồm GC, dispatch và JIT tại vùng đang đo. File `report.txt` nói rõ ranh giới này.

Mặc định `--warmup 0` chỉ có một lượt khai phá được đo. Thêm `--warmup 1` vào CLI hoặc `-Warmup 1` vào script để yêu cầu một lượt không diễn giải trước lượt đo; nó nằm ngoài `MiningMs` và có thời gian riêng. Warmup không bảo đảm hết JIT, nhất là khi lượt đo dùng explain/kiểu IO khác. Bật explain còn làm tăng thời gian format/IO trong từng phase. Để đối chiếu, dùng cùng input SHA256, ngưỡng, counter, runtime và cờ explain/warmup; kiểm tra `implementation_sha256` để biết phiên bản mã nguồn. Đây là thống kê của một lần chạy thực tế, chưa phải trung bình benchmark hoặc xác minh nhanh hơn scan/SPMF.

Xem [README](../README.md) để chạy với dataset của nhóm và đọc báo cáo thời gian.
