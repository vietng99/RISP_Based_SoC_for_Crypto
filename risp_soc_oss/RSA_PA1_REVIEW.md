# Rà soát PA1 trước khi thay RSA cũ trong SoC (t-011)

Ngày: 2026-10-14. RTL rà soát: `rtl/patched/RSA_core.v` (sửa lần cuối 17:10:26) và
`rtl/patched/RSA_mark03_slave_lite_v1_0_S00_AXI.v` (17:13:25). Bản sửa sau rà soát gắn
nhãn `[PA1-R]` trong code. Diff so với IP gốc trong `ip_repo/acc_rsa`:
`patches/RSA_core.v.diff`, `patches/RSA_mark03_slave_lite_v1_0_S00_AXI.v.diff` (tạo lại
bằng `diff -u --strip-trailing-cr`, vì file gốc dùng CRLF).

## 1. Danh sách rủi ro

| # | Rủi ro | Xử lý | Kiểm chứng |
|---|---|---|---|
| R1 | Lõi đọc `E` trực tiếp từ thanh ghi wrapper trong lúc chạy (ST_MSB và các lệnh `ebit <= E[...]`). Firmware ghi E khi lõi đang chạy thì kết quả sai. | Sửa: lõi chốt `e_r <= E` lúc start, mọi chỗ đọc bit E dùng `e_r`. | `tb_rsa_ip_axi` kind 3 (ghi E mới khi đang chạy, kết quả phải không đổi): case 12 (CTRL=0x3), case 13 (CTRL=0x1) PASS. |
| R2 | Ghi start khi lõi đang chạy: bản gốc xóa `done_latch` bằng `core_start`, sau đó `done` của phép tính cũ bật lại `done_latch`. Firmware đọc được done=1 cùng kết quả của phép tính cũ. | Sửa: start khi đang bận được xếp hàng (sâu 1, `start_pending`) và chạy khi lõi rảnh; toán hạng lấy lúc thực sự start. `done_latch` xóa ở lần ghi CTRL start, bỏ qua `done` khi còn `start_pending`. | kind 2 (start thứ hai khi đang bận, M2 là thông điệp mới): case 11 PASS, số lần poll 71,748, khoảng 2 lần một phép tính, khớp với việc chạy nối tiếp. |
| R3 | STATUS chỉ có bit done, firmware không phân biệt được "chưa start" và "đang chạy". Có 1 cycle (`core_done`) mà done_latch chưa bật. | Sửa: thêm STATUS bit1 = busy, gồm cả cycle `core_done`, nên không bao giờ đọc được done=0, busy=0 giữa phép tính. Bit0 giữ nguyên nghĩa; khi xong STATUS = 0x1 như bản gốc. | 9 test SoC dùng firmware cũ vẫn ra cùng kết quả (mục 2). Testbench IP kiểm tra STATUS ở mọi case. |
| R4 | Ghi CTRL không có bit start (chỉ đổi bit1 fast_pub) có thể tạo kết quả mới hoặc xóa done. | Không cần sửa: chỉ start=1 mới chạy và xóa done. | kind 1: case 10 (CTRL=0x2) PASS, RESULT giữ nguyên. |
| R5 | Luồng nhanh (CTRL=0x3) không chạy thời gian hằng: số cycle phụ thuộc bit cao nhất và số bit 1 của E. Dùng với số mũ bí mật thì lộ E qua thời gian. | Giữ nguyên, có chủ ý: luồng này chỉ dành cho verify với E công khai (65537). Mặc định sau reset `core_fast = 0`, CTRL=0x1 chạy đúng luồng gốc. Firmware ký/giải mã không được ghi CTRL=0x3. | Đường gốc: `logs/run-tb_rsa2048.log` giống hệt bản trước PA1 (t-009). |
| R6 | E = 0 ở luồng nhanh: vòng ST_MSB dò bit cao nhất sẽ không dừng. | Đã chặn từ PA1: `fast_r = fast_pub && E != 0`, E = 0 quay về luồng gốc. | case 7 (CTRL=0x3, E=0) PASS, 73,798 poll, bằng luồng gốc. |

Rủi ro có từ trước PA1, không sửa trong t-011:

- R7: luồng gốc với `RSA_E_SCAN = 17` cho kết quả sai mà không báo lỗi khi E >= 2^17
  (đã ghi trong header wrapper gốc). Luồng nhanh quét đủ 32 bit E: case 8
  (CTRL=0x3, E=0xe341f133) PASS.
- R8: `tb_rsa` FAIL vì firmware `rsa.hex` dùng register map RSA 32-bit cũ (CTRL 0x14),
  trong khi IP là bản 2048-bit (CTRL 0x308). Kết quả này giống trước PA1.

## 2. Kết quả test

| Test | Lệnh | Kết quả | Log |
|---|---|---|---|
| Unit test lõi, W=64 và W=256, 252 case x 2 luồng, so với Python `pow()` | `make test-rsa-pa1` | 504/504 mỗi W | `logs/test-rsa-pa1.log` (17:11:28) |
| IP riêng qua AXI4-Lite, RSA_WIDTH=2048, 14 case x 6 seed thời gian AXI ngẫu nhiên | `make test-rsa-ip RSA_IP_SEEDS="1 2 3 4 5 6"` | PASS cả 6 seed | `logs/test-rsa-ip.log` (17:13:57) |
| 9 test SoC | `make run-all` | `logs/summary.txt` giống hệt `logs/summary.before-pa1.txt` (`diff` rỗng): 8 PASS, `tb_rsa` FAIL như cũ (R8) | `logs/run-all-pa1r.log` (17:16:45) |
| Firmware nhanh `rsa2048_fast.hex` | trong `make run-all` | PASS, lõi 155,611 cyc, PURE 156,515 | `logs/run-tb_rsa2048_fast.log` |
| Lint SoC | `make lint-soc` | 0 `%Error` | `logs/lint-soc-pa1r.log` |

Mọi log trên được tạo sau lần sửa RTL cuối (17:13:25).

Một lần chạy thử đã cài 4 lỗi có chủ ý vào RTL để thử testbench IP; cả 4 đều bị bắt. Chi tiết
từng lỗi không được ghi ra file, chỉ có trong nhật ký làm việc của tác giả.

## 3. Tài nguyên so với IP gốc (Yosys 0.69, `synth_xilinx -family xc7 -flatten`, RSA_WIDTH=2048)

| Tài nguyên | Gốc (`ip_repo`) | PA1 (t-010) | PA1-R (hiện tại) | PA1-R so với gốc |
|---|---|---|---|---|
| LUT logic (LUT1-6 + INV) | 11,098 | 11,803 | 12,290 | +1,192 |
| LUT làm RAM (RAM64M x 4) | 176 (44) | 344 (86) | 344 (86) | +168 |
| Tổng LUT | 11,274 | 12,147 | 12,634 | +1,360 (+12.1%), 23.7% xc7z020 |
| FF | 20,858 | 20,862 | 20,883 | +25 (+0.1%) |
| DSP48E1 | 4 | 4 | 4 | 0 |
| CARRY4 | 53 | 53 | 53 | 0 |

- Script: `synth/rsa_original.ys`, `synth/rsa_pa1r.ys` (bản sao của `rsa_baseline.ys`).
  Kết quả: `logs/synth-rsa-original.stat`, `logs/synth-rsa-pa1r.stat`.
- `synth/RSA_core_synth.v` đã chép lại từ `rtl/patched/RSA_core.v` hiện tại; chỉ khác 1 dòng
  xóa mảng `t` (Yosys không đọc được `'{default: ...}`).
- Đổi lấy +12.1% LUT là lõi nhanh gấp 2.06 lần (319,814 xuống 155,611 cyc).
- Đây là số Yosys. Muốn đưa vào bài báo phải đo lại bằng Vivado sau khi đưa bản sửa vào
  `ip_repo`.

## 4. Còn mở

- Bản PA1-R mới nằm ở `risp_soc_oss/rtl/patched/`, chưa đưa vào `ip_repo` và chưa chạy
  trong Vivado. Việc này cần chủ dự án quyết định.
- Firmware cũ không đọc STATUS.busy. Firmware mới nên poll `STATUS == 0x1` hoặc chờ
  busy = 0 rồi mới đọc RESULT.
