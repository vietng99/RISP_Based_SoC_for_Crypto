# Thiết kế PA1: luồng lũy thừa nhanh cho số mũ công khai (RSA core)

Ngày: 2026-10-14. Task: t-007. Bước 2/4: chỉ là thiết kế, chưa sửa RTL.
Nguồn gốc: `risp_soc_oss/RSA_RESEARCH.md` mục 3 (PA1) và tham chiếu R2 (OpenTitan `mod_exp_ibex.c`).

## 1. Mục tiêu

- Giảm số lần nhân Montgomery (MonMul) khi verify RSA-2048 với e = 65537 từ 37 xuống 18.
- Cycle lõi ước lượng: 18 * 8584 = 154,512 (hiện đo được 319,814), giảm khoảng 51%.
- Không thêm DSP, không thêm mảng nhớ 2048-bit, không đổi giao thức AXI.
- Giữ nguyên đường constant-time cũ để dùng khi số mũ là bí mật.

## 2. Thuật toán

Ký hiệu: `MonMul(a, b) = a * b * R^-1 mod N`, với R = 2^2048. `R2 = R^2 mod N` đã được tính sẵn
ngoài chip, giống hiện tại.

Luồng mới (left-to-right square-and-multiply, áp dụng cho mọi e lẻ):

```
L  = vị trí bit 1 cao nhất của E           (65537 -> L = 16)
A  = MonMul(M, R2)        = M * R mod N     (vào miền Montgomery, lưu ở mbar)
res = A
for i = L-1 downto 1:
    res = MonMul(res, res)                  (bình phương)
    if E[i] == 1: res = MonMul(res, mbar)   (nhân trong miền Montgomery)
res = MonMul(res, res)                      (bình phương cho bit 0)
if E[0] == 1: C = MonMul(res, M)            (nhân với M thường: hệ số R tự triệt tiêu)
else:         C = MonMul(res, 1)            (thoát miền Montgomery)
```

Kiểm tra cho e = 65537 = 2^16 + 1: 1 (vào miền) + 16 (bình phương) + 0 (bit giữa đều 0)
+ 1 (nhân với M) = 18 MonMul. Kết quả trùng với code OpenTitan.

Vì sao bước cuối đúng: `res = M^(2^16) * R`, nên `MonMul(res, M) = M^(2^16) * R * M * R^-1 =
M^65537 mod N`. Mỗi MonMul trong IP đã có bước trừ N ở cuối, nên kết quả nằm trong [0, N).

Trường hợp biên:
- e = 1 (L = 0): bỏ qua vòng lặp và bước bình phương bit 0, tính `C = MonMul(A, 1) = M mod N`.
- e = 0: không phải số mũ RSA hợp lệ. Luồng nhanh trả STATUS.done với C = 1 mod N, hoặc chuyển
  sang đường cũ (mục 6, câu hỏi Q2).
- e chẵn: vẫn đúng, đi nhánh `MonMul(res, 1)`.

## 3. Thay đổi RTL

Chỉ sửa bản sao trong `risp_soc_oss`, không đụng `RISP/ip_repo`.

### 3.1 `risp_soc_oss/rtl/patched/RSA_core.v` (module `rsa`)

- Thêm cổng `input wire fast_pub` (chọn luồng, chốt lúc start).
- Thêm trạng thái `ST_MSB`: dò bit 1 cao nhất của E, mỗi cycle 1 bit, tối đa 32 cycle. Dùng lại
  thanh ghi `ebit_idx` sẵn có.
- Đổi `ST_EXP_A` / `ST_EXP_B` khi `fast_pub = 1`:
  - Sau phase 0 (vào miền): chép kết quả vào cả `mbar` và `res`, bỏ phase 1 (conv R).
  - Vòng lặp: bình phương; chỉ nhân với `mbar` khi bit = 1 (không chạy MonMul giả như CT).
  - Bit 0: chọn `sel_b = 3'd4` (`m_in`, M thường) nếu E[0] = 1, ngược lại `sel_b = 3'd3` (hằng 1).
- Không đụng vòng CIOS (ST_CLR đến ST_CPY), nên chi phí mỗi MonMul giữ nguyên 8584 cycle.
- Khi `fast_pub = 0`: chạy y hệt code cũ, từng cycle.

### 3.2 Wrapper AXI (bản sao `RSA_mark03_slave_lite_v1_0_S00_AXI.v` trong `risp_soc_oss/rtl/patched/`)

- CTRL (0x308): bit0 = start (như cũ), **bit1 = fast_pub (mới)**. Ghi 0x1 chạy đường cũ, ghi 0x3
  chạy đường nhanh.
- Các địa chỉ khác giữ nguyên. Firmware cũ ghi 0x1 nên vẫn chạy đúng đường cũ.
- Cập nhật `flist/rissp_soc.f` trỏ sang bản sao wrapper.

### 3.3 Firmware

- `rsa2048_fast.hex`: bản sao của `rsa2048.hex`, chỉ đổi 1 lệnh `li x6, 0x1` thành
  `li x6, 0x3` ngay trước `sw x6, 0x308(x13)` (`rsa2048.s:471`). Mã máy đổi từ `0x00100313`
  thành `0x00300313` (dòng 585 của `rsa2048.hex`; dòng 586 là `3066a423` = `sw x6, 0x308(x13)`).
  Có toolchain RISC-V trong `chipyard/.conda-env/riscv-tools/bin/riscv64-unknown-elf-as`, nên
  có 2 cách: (a) sửa đúng 1 word trong bản sao hex, kèm script kiểm tra chỉ 1 word đổi; hoặc
  (b) dịch lại bản sao `.s` bằng toolchain đó. Đề xuất (a) vì không đụng tới quá trình build
  firmware gốc.

## 4. Ưu điểm

1. **Nhanh hơn khoảng 2 lần** cho verify với e = 65537: 37 xuống 18 MonMul, ~320k xuống ~155k
   cycle (ước lượng, sẽ đo ở bước 4).
2. **Không tốn thêm phần cứng lớn**: không thêm DSP, không thêm mảng 2048-bit. Chỉ thêm 1 bit
   chế độ, 1 trạng thái FSM và vài nhánh chọn toán hạng.
3. **Tương thích ngược**: register map giữ nguyên, firmware cũ (CTRL = 0x1) chạy đúng như trước,
   số cycle cũ giữ nguyên.
4. **Đúng cho mọi e lẻ**, không chỉ 65537: tự dò độ dài số mũ nên bỏ được rủi ro của
   `RSA_E_SCAN` (hiện nếu e có bit >= 17 thì kết quả sai mà không báo).
5. **Có tham chiếu ngoài**: cùng thuật toán với OpenTitan `mod_exp_ibex.c` (R2), dễ trích dẫn
   trong bài báo.

## 5. Nhược điểm và rủi ro

1. **Thời gian chạy phụ thuộc số mũ** khi `fast_pub = 1`. Với khóa công khai thì không sao. Nếu
   firmware lỡ dùng chế độ nhanh cho số mũ bí mật (decrypt/sign) thì sẽ lộ thông tin qua thời
   gian. Biện pháp: mặc định là đường CT; ghi rõ trong comment và README.
2. **Firmware phải đổi 1 lệnh** mới được tăng tốc. Firmware hiện tại không tự nhanh lên.
3. **Thêm vài cycle dò MSB** (tối đa 32 cycle mỗi lần start), không đáng kể so với 155k.
4. **Lệch so với IP gốc trong Vivado**: số liệu bài báo đang lấy từ IP gốc. Muốn dùng số mới cho
   bài báo thì phải đưa bản sửa về `ip_repo` và chạy lại Vivado. Bước này là việc của bạn.
5. **Chưa giải quyết giới hạn 1 MAC**: mỗi MonMul vẫn 8584 cycle. Muốn nhanh hơn nữa phải làm
   PA2 (thêm MAC) sau.
6. **Rủi ro lỗi FSM** ở các nhánh biên (e = 1, e chẵn, e = 0). Kế hoạch test ở mục 7 phủ các
   trường hợp này.

## 6. Câu hỏi cần bạn quyết định

- **Q1. Cách chọn chế độ:**
  - (A, đề xuất) CTRL bit1, chọn lúc chạy. An toàn nhất vì mặc định là đường CT.
  - (B) Tham số Verilog `RSA_CONST_TIME = 0` cộng với luồng mới. Không cần sửa firmware,
    nhưng IP mất hẳn đường CT.
  - (C) Phần cứng tự nhận khi E = 65537. Không cần sửa firmware, nhưng ẩn ý đồ và vẫn
    chạy đường nhanh nếu khóa bí mật tình cờ bằng 65537.
- **Q2. Với e = 0:** (đề xuất) chạy đường cũ, hay trả C = 1?

## 7. Kế hoạch test (bước 4)

1. Lint: `make lint-soc` (Verilator -Wall) không có cảnh báo mới.
2. Hồi quy: `tb_rsa2048` với `rsa2048.hex` gốc (CTRL = 0x1) phải PASS 9/9 và core vẫn đúng
   319,814 cycle.
3. Đường nhanh: `tb_rsa2048` với `rsa2048_fast.hex` (CTRL = 0x3) phải PASS 9/9 và core khoảng
   154.5k cycle.
4. Unit test lõi `rsa` ở WIDTH = 256 (chạy nhanh) với e trong {1, 2, 3, 17, 65537, 0xFFFFFFFF,
   vài số lẻ ngẫu nhiên}, so với Python `pow(M, e, N)`, cho cả `fast_pub = 0` và `= 1`.
5. Ghi số đo mới vào `PERF_NOTES.md` và proof report của task.

Thời gian ước lượng cho bước 3 (RTL) và bước 4 (test): khoảng 2-3 giờ.
