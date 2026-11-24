# Rà soát và sửa lỗi bản External-Memory v2

## Phát hiện chính

1. **Sai vị trí kiểm tra Apriori prune** trong `src/apriori_external.jl`.
   Candidate được tạo bằng cách join hai K-itemset có chung K-1 phần tử đầu. Hai subset join-parent đã được biết là tồn tại khi bỏ phần tử ở vị trí K hoặc K+1. Vì vậy phải kiểm tra các subset còn lại bằng `removed = 1:(K-1)`. Bản v2 dùng `2:K`, bỏ sót subset khi xóa phần tử đầu và kiểm tra dư một join-parent. Điều này có thể giữ candidate không hợp lệ, làm tăng số candidate và số lần đếm support; thống kê candidate/level cũng có thể lệch so với `mine()`.

2. **Membership lookup trên đĩa quá đắt khi nhiều subset tồn tại**.
   Bản v2 dùng Bloom filter rồi binary search file cho mọi Bloom-positive. Với level lớn và nhiều candidate hợp lệ, có thể phát sinh rất nhiều seek/read ngẫu nhiên.

## Thay đổi trong bản v3

- Sửa prune thành kiểm tra `1:(K-1)` và cập nhật giải thích trong code.
- Thêm `PackedDiskMembership`: mã hóa chính xác fixed-width itemset sang UInt64 hoặc UInt128 nếu kích thước ID cho phép.
- Chỉ mục packed có giới hạn 128 MiB theo ước lượng; nếu không vừa hoặc không thể pack thì vẫn dùng Bloom filter + binary search chính xác trên file.
- Thêm regression test cho trường hợp C3=(1,2,4) phải bị prune vì subset (2,4) không nằm trong L2.
- Thêm kiểm thử packed membership cho cả UInt64 và UInt128.

## Giới hạn xác minh

Môi trường tạo gói không có Julia executable, nên chưa thể chạy `julia --project=. test/runtests.jl` hoặc benchmark Chess. Các test mới đã được thêm vào source nhưng chưa được thực thi. Không xem bản v3 là đã PASS cho đến khi chạy test trong môi trường Julia.
