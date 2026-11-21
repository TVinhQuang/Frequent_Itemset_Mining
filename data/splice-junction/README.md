# UCI Splice-junction Gene Sequences

[splice.data](splice.data) là bản gốc của *Molecular Biology (Splice-junction Gene Sequences)* (1991), UCI Machine Learning Repository, giấy phép [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). [Trang dữ liệu và trích dẫn](https://doi.org/10.24432/C5M888) · [Tải tệp từ UCI](https://archive.ics.uci.edu/ml/machine-learning-databases/molecular-biology/splice-junction-gene-sequences/splice.data)

Mỗi dòng gồm nhãn, tên bản ghi và đoạn DNA dài 60 nucleotide. Bộ dữ liệu có 767 đoạn EI (exon → intron), 768 đoạn IE (intron → exon) và 1.655 đoạn N (đối chứng). SHA-256 của tệp gốc là `ebbae10c85d3c285e2a2489a37e42bc2ee8d91d15005e391a9962fa3389a114f`.

Chương trình dùng cột nucleotide 27–34 (đếm từ 1), tương ứng vị trí −4, −3, −2, −1, +1, +2, +3, +4 quanh tâm. Trong mỗi đoạn, mã hóa từng cặp vị trí–nucleotide A/C/G/T thành một item. Ví dụ, A ở −4 và A ở +1 là hai item khác nhau. Bỏ qua vị trí có ký hiệu mơ hồ D/R/S/N, giữ nguyên đoạn và nhãn khi tính mẫu số. Trong cửa sổ đã chọn, hai đoạn EI và một đoạn đối chứng có ít nhất một vị trí mơ hồ. Ký hiệu nucleotide N và nhãn đối chứng N nằm ở hai trường riêng.
