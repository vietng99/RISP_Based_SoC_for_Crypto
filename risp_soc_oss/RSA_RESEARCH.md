# Research: tăng tốc IP RSA-2048 (Montgomery) của RISSP SoC

Ngày: 2026-10-14. Task: t-006. Bước 1/4 (chỉ research, chưa sửa RTL).

## 1. Hiện trạng IP

Nguồn: `RISP/ip_repo/acc_rsa/src/RSA_core.v`, `RSA_mark03_slave_lite_v1_0_S00_AXI.v`,
`risp_soc_oss/logs/summary.txt`.

- Thuật toán: CIOS word-serial (Koç 1996), WORD = 32, S = 2048/32 = 64 word.
- Phần cứng nhân: 1 MAC 32x32 dùng chung cho cả vòng a*b (L1) và m*n (L2).
- Chi phí 1 MonMul: 2*S^2 + 6*S + 8 = 8584 cycle (công thức trong header `RSA_core.v`).
  Trong đó 2*S^2 = 8192 cycle là MAC thực sự làm việc, tức MAC bận khoảng 95%.
- Luồng lũy thừa: `RSA_CONST_TIME = 1`, `RSA_E_SCAN = 17`, nên 2*17 + 3 = 37 MonMul.
  37 * 8584 = 317,608 cycle; đo được 319,814 cycle lõi (start -> done), 7.99 ms ở 40 MHz.
- Mỗi MonMul còn có ST_SUB (S cycle), ST_WR (S cycle), ST_CPY (S cycle) = ~3*S = 192 cycle.

Nhận xét: với 1 MAC, IP đã gần giới hạn của chính nó (MAC bận ~95%, Bo et al. 2011 cũng chỉ
đạt >97% với 1 DSP). Muốn nhanh hơn rõ rệt phải (a) giảm số MonMul hoặc (b) thêm/rộng bộ nhân.

## 2. Nguồn tham khảo

| # | Nguồn | Nội dung dùng được | Link |
|---|---|---|---|
| R1 | Koç, Acar, Kaliski, "Analyzing and Comparing Montgomery Multiplication Algorithms", IEEE Micro 16(3), 1996 | So sánh SOS/CIOS/FIOS/FIPS/CIHS; CIOS hiệu quả nhất trên bộ xử lý tuần tự. IP hiện tại dùng CIOS. | [Microsoft Research](https://www.microsoft.com/en-us/research/?p=158376) |
| R2 | OpenTitan `mod_exp_ibex.c` (sigverify, e = 65537) | Code tham chiếu: 1 MonMul vào miền Montgomery (sig * R^2), 16 bình phương, 1 MonMul với sig thường (hệ số R tự triệt tiêu). Tổng 18 MonMul, không cần MonMul thoát miền Montgomery. | [mod_exp_ibex.c](https://opentitan.org/gen/doxy/mod__exp__ibex_8c_source.html) |
| R3 | OpenTitan OTBN benchmark | RSA-2048 modexp e = 65537: 132,028 cycle; RSA-2048 decrypt (constant time): 18,889,021 cycle. OTBN dùng thanh ghi 256-bit. Trang ghi chú số chỉ là ước lượng từ 1 lần chạy. | [OTBN intro](https://opentitan.org/book/hw/ip/otbn/doc/otbn_intro.html) |
| R4 | Bo, Kawakami, Nakano, Ito, "An RSA Encryption Hardware Algorithm using a Single DSP Block and a Single Block RAM on the FPGA", IJNC 1(2), 2011 | 1 DSP48E1 + 1 BRAM, Virtex-6, RSA-2048 encrypt/decrypt 277.26 ms; DSP bận >97%. Tác giả kết luận với 1 bộ nhân không cải thiện thêm được. | [J-STAGE](https://www.jstage.jst.go.jp/article/ijnc/1/2/1_277/_article) |
| R5 | Noyez, El Mrabet, Potin, Véron, "Montgomery Multiplication Scalable Systolic Designs Optimized for DSP48E2", ACM TRETS 17(1), 2024 | Systolic kiểu FIOS trên DSP48E2: 1 MonMul 2048-bit trong 1.550 us với 41 DSP. Abstract không ghi tần số và device. | [Crossref 10.1145/3624571](https://api.crossref.org/works/10.1145%2F3624571) |
| R6 | Tenca, Koç, "A Scalable Architecture for Montgomery Multiplication", CHES 1999, LNCS 1717 | MWR2MM: chuỗi processing element, quét X theo bit, Y theo word; số PE chọn tùy diện tích. | [patent US8433736 tóm tắt](https://patents.google.com/patent/US8433736) |
| R7 | Suzuki, "How to Maximize the Potential of FPGA Resources for Modular Exponentiation", CHES 2007, LNCS 4727 | Kiến trúc Montgomery dùng DSP của Virtex-4; 512-bit modexp 0.26 ms; cùng mạch chạy 1024 đến 2048-bit. | [IACR PDF](https://www.iacr.org/archive/ches2007/47270272/47270272.pdf) |
| R8 | Walter, "Montgomery exponentiation needs no final subtractions", Electronics Letters 35(21), 1999; Hachez, Quisquater, CHES 2000 | Bỏ bước trừ cuối của mỗi MonMul nếu tăng độ rộng R thêm vài bit. Tôi chưa đọc bản gốc; điều kiện chính xác cần kiểm tra lại. | [IACR CryptoDB](https://iacr.org/cryptodb/data/paper.php?pubkey=614) |
| R9 | Cryptech modexp (Verilog 2001, 32-bit iterative, tới 8192-bit) | RTL mở để đối chiếu. README 2015 ghi core chưa chạy; trạng thái hiện tại chưa kiểm tra. | [git.cryptech.is](https://git.cryptech.is/core/math/modexp/about) |

## 3. Các phương án áp vào IP hiện tại

Ước lượng theo công thức của `RSA_core.v` (S = 64), chưa mô phỏng. "Lõi" = start -> done.

| PA | Thay đổi | MonMul | Cycle/MonMul | Cycle lõi (ước lượng) | So với hiện tại | Thêm phần cứng | Công sức |
|---|---|---|---|---|---|---|---|
| 0 | Hiện tại (CT=1) | 37 | 8,584 | 317,608 (đo 319,814) | - | - | - |
| 0b | Chỉ đặt `RSA_CONST_TIME = 0` | 22 | 8,584 | 188,848 | -41% | không | 1 dòng |
| 1 | Luồng e = 65537 kiểu OpenTitan (R2) | 18 | 8,584 | 154,512 | -51% | không (đổi FSM) | ~1 ngày |
| 2 | PA1 + 2 MAC song song (a*b và m*n, kiểu FIOS) | 18 | ~4,500 | ~81,000 | -75% | +1 MAC 32x32 (~4 DSP48E1) | 3-5 ngày |
| 3 | PA1 + MAC 64x64 (S = 32) | 18 | ~2,250 | ~40,500 | -87% | MAC 64x64 (~16 DSP48E1), rủi ro Fmax | 3-5 ngày |
| 4 | Systolic nhiều PE (R5) | 18 | ~1.55 us/MonMul ở tần số của R5 | ~28 us | rất lớn | ~41 DSP | vài tuần |

Ghi chú từng phương án:

- **PA0b**: chỉ đổi tham số. Thời gian chạy phụ thuộc số mũ, nhưng verify dùng khóa công khai
  nên không lộ bí mật. Nếu IP còn dùng cho khóa bí mật (decrypt/sign) thì phải giữ CT = 1 cho
  đường đó.
- **PA1** (đề xuất số 1): theo R2. Với e = 65537 = 2^16 + 1:
  `A = MonMul(M, R2) = M*R`; 16 lần `A = MonMul(A, A)`; `C = MonMul(A, M)` = M^65537 mod N.
  Bỏ được bước "conv R" và MonMul(res, 1) cuối. IP đã có sẵn nguồn toán hạng `m_in` (sel = 4),
  nên chỉ đổi FSM ở ST_EXP_A/ST_EXP_B. Giữ đường tổng quát cũ cho số mũ khác.
- **PA2**: vòng L1 (a*b_i) và L2 (m*n) của CIOS hiện chạy nối tiếp trên cùng 1 MAC. Hai MAC
  chạy lệch pha (kiểu FIOS, R1, R5) đưa chi phí về khoảng S^2 + O(S). Cần xử lý phụ thuộc:
  m của hàng i cần t[0] sau MAC đầu tiên của hàng đó.
- **PA3**: giảm S còn 32 nên 2*S^2 giảm 4 lần. Bộ nhân 64x64 tổ hợp có đường găng dài; cần
  STA mới biết có giữ được 40 MHz không (hiện chưa có timing report nào trong repo).
- **PA4**: nhanh nhất nhưng tốn ~41 DSP, đi ngược hướng "SoC tối giản" của bài báo.
- **Bỏ bước trừ cuối (R8)**: ở IP này lợi ít. Tiết kiệm ~3*S = 192 cycle/MonMul (~2%), nhưng
  phải thêm 1 word cho R (S+1 word) làm mỗi MonMul dài thêm ~4*S cycle. Không đề xuất.
- **Bình phương chuyên dụng**: 16/18 MonMul của PA1 là bình phương; nhân a*a đối xứng giảm
  phần L1 còn khoảng S^2/2. Ghép với CIOS khó; để sau.

Đối chiếu: OTBN (R3) chạy RSA-2048 e = 65537 trong 132,028 cycle. PA1 (154,512) gần bằng
OTBN mà không thêm phần cứng; PA2 (~81,000) đã nhanh hơn OTBN.

## 4. Xếp hạng đề xuất

1. **PA1** (luồng e = 65537, 18 MonMul): -51%, không thêm DSP, sửa nhỏ, có code tham chiếu (R2).
2. **PA1 + PA2** (thêm 1 MAC): khoảng -75%, thêm ~4 DSP48E1, vẫn hợp với SoC tối giản.
3. **PA1 + PA3** (MAC 64-bit): khoảng -87%, cần kiểm tra Fmax trước.

## 5. Giới hạn của bản research này

- Số cycle của các PA là ước lượng theo công thức, chưa mô phỏng.
- R5, R7, R8: chỉ đọc abstract hoặc tóm tắt, chưa đọc toàn văn.
- Chưa có số DSP/LUT/Fmax thật của IP hiện tại (chưa có báo cáo synthesis trong repo).
