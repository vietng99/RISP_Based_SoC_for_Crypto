# Ghi chú hiệu năng RISSP SoC: Verilator (risp_soc_oss) so với Vivado

Ngày: 2026-10-14. Clock SoC 40 MHz (`clk_wiz_0` CLKOUT1_REQUESTED_OUT_FREQ = 40.000,
testbench `always #12.5 soc_clk_drv`).

## 1. Nguồn số liệu

- Verilator: `risp_soc_oss/logs/summary.txt` (`make run-all`, Verilator 5.022).
- Vivado: trong repo không có log mô phỏng Vivado (`simulate.log`). Số Vivado duy nhất có
  ghi lại nằm ở:
  - `RISP/README.md:118`: RISSP_SoC SHA3-256 = 492 cycle, RV32I_SoC RSA-2048 = 321,039,
    Ibex_SoC RSA-2048 = 320,974.
  - `hardware/testbench/rv32i/tb_rv32i_sha3.v:149`: mốc RISSP SHA3 "loi=28 PURE=492 E2E=549 ck".
  - `hardware/testbench/ibex/tb_ibex_rsa2048.v:138`: mốc RISSP RSA-2048 PURE = 320972 ck.

## 2. So sánh

| Testbench | Chỉ số | Vivado | Verilator | Chênh lệch |
|---|---|---|---|---|
| tb_sha3 | lõi (iLast -> oReady) | 28 | 29 (1 padding + 28 perm) | khớp, Verilator tính cả 1 ck padding |
| tb_sha3 | PURE (absorb1 -> DIGEST) | 492 | 427 | -65 (-13.2%) |
| tb_sha3 | E2E (absorb1 -> BRAM) | 549 | 466 | -83 (-15.1%) |
| tb_rsa2048 | PURE (M -> RESULT) | 320,972 | 320,714 | -258 (-0.08%) |
| tb_aes_ecb/cbc/cfb/ctr | tất cả | chưa có | xem summary.txt | chưa so được |
| tb_sha3_4, tb_sha3_16 | tất cả | chưa có | xem summary.txt | chưa so được |

Kết quả đúng/sai: cả 8 testbench dùng được đều PASS trong Verilator. Testbench là bản gốc của
Vivado (chỉ sửa cách force clock, `logs/tb-adapt.diff`), nên giá trị kỳ vọng (NIST/known
answer) giống hệt. `tb_rsa` FAIL vì firmware `rsa.hex` dùng register map RSA 32-bit cũ
(CTRL 0x14), còn IP trong block design là RSA-2048 (CTRL 0x308). Lỗi này có từ firmware,
không do bản dựng lại.

## 3. Giải thích chênh lệch

- Số cycle lõi tính khớp (SHA3 28 ck). Phần chênh nằm ở đường bus.
- Bản Verilator dùng `axi_lite_xbar` của pulp-platform với `NO_LATENCY` (định tuyến tổ hợp).
  Bản Vivado dùng `axi_interconnect_0` của Xilinx, có thêm thanh ghi trên đường đi.
- SHA3 PURE có khoảng 60 giao dịch AXI (17 word x 3 SW + polling + 8 LW digest).
  -65 ck tương ứng khoảng 1 ck/giao dịch. Đây là ước lượng, chưa đo theo từng giao dịch.
- RSA-2048 chênh -258 ck trên 320k (0.08%). Lõi chiếm 99.7% thời gian nên bus gần như
  không ảnh hưởng.
- Hệ quả cho bài báo: số AXI-level (PURE, E2E) phụ thuộc interconnect. Muốn so CPU với nhau
  thì nên báo cáo số lõi và số Vivado; số Verilator chỉ dùng làm cận dưới khi bus không có
  độ trễ.

## 4. Phân bổ thời gian (Verilator)

| Workload | Cycle lõi | Tổng (PURE) | Lõi chiếm |
|---|---|---|---|
| AES ECB | 17 | 75 | ~23% |
| AES CBC | 17 | 107 | ~16% |
| SHA3 16 block | ~24 x 16 | 6041 | ~6% |
| RSA-2048 | 319,814 | 320,714 | 99.7% |

AES và SHA3 bị nghẽn ở bus và firmware. RSA bị nghẽn ở lõi. CPU host (RISSP, RV32I hay Ibex)
gần như không đổi kết quả RSA (320,972 / 321,039 / 320,974).

## 5. Hướng cải thiện (chưa làm, chưa mô phỏng)

1. RSA `RSA_CONST_TIME = 1` (`acc_rsa/hdl/RSA_mark03_slave_lite_v1_0_S00_AXI.v:39`): 37
   MonMul. Verify dùng số mũ công khai e = 65537 nên không cần constant-time. Đặt 0: 22
   MonMul, khoảng 189k cycle (-41%). Khởi tạo `res = M_bar` để bỏ bước conv R: khoảng 20
   MonMul, 172k cycle. Ước lượng theo công thức 2*S^2 + 6*S + 8 = 8584 ck/MonMul (S = 64)
   trong header `RSA_core.v`.
2. RSA chỉ có 1 MAC 32x32. Thêm MAC thứ hai để chạy song song vòng L1/L2 (kiểu FIOS) giảm
   khoảng 2 lần nữa, đổi lại thêm DSP.
3. Mỗi SW/LW qua AXI tốn 5-6 ck: `axi_rissp_master.v` đi IDLE -> WRITE -> DONE, slave chờ
   thêm 1 ck mới bật BVALID/RVALID. Bật valid sớm hơn và bỏ trạng thái DONE còn khoảng 3 ck.
4. Firmware SHA3 dùng 3 SW cho mỗi word 64-bit (`sha3_4.s`: data_hi, data_lo, CTRL), khoảng
   22 ck/word, tức ~374 ck để nạp 1 block, trong khi permutation chỉ cần 24 ck. Cho lõi tự
   absorb khi ghi data_lo sẽ bớt 1 SW/word.
5. Chưa có timing report (Vivado hoặc OpenROAD STA), nên chưa biết 40 MHz đã là giới hạn
   của CPU single-cycle hay còn slack.

Rủi ro: firmware SHA3 không đọc `buffer_full`. Hiện chạy đúng vì CPU nạp chậm hơn
permutation. Nếu làm bus nhanh hơn thì phải kiểm tra lại.

## 6. Còn thiếu cho t-005

- Log mô phỏng Vivado của 4 testbench AES và tb_sha3_4, tb_sha3_16 (các mốc cycle và
  ciphertext/digest in ra).
- Số cycle lõi RSA (start -> done) phía Vivado, để xác nhận lõi khớp đúng từng cycle.

## 7. Kết quả PA1 (đo trong Verilator, 2026-10-14)

PA1 = luồng số mũ công khai trong `rtl/patched/RSA_core.v` (thiết kế: `RSA_PA1_DESIGN.md`),
chọn bằng CTRL bit1. Firmware `firmware/rsa2048_fast.hex` ghi CTRL = 0x3.

| Chỉ số (tb_rsa2048) | Gốc (CTRL = 0x1) | PA1 (CTRL = 0x3) | Thay đổi |
|---|---|---|---|
| Lõi (start -> done) | 319,814 cyc (7995.35 us) | 155,611 cyc (3890.28 us) | -51.3% (2.06x) |
| PURE (M -> RESULT) | 320,714 | 156,515 | -51.2% |
| E2E (M -> BRAM) | 320,759 | 156,560 | -51.2% |
| Kết quả | PASS 9/9 | PASS 9/9 | |

- Đường gốc sau khi sửa: log `logs/run-tb_rsa2048.log` trùng từng byte với log trước PA1
  (`logs/run-tb_rsa2048.before-pa1.log`).
- Unit test `make test-rsa-pa1` (WIDTH = 256, 180 case x 2 đường, so với Python `pow()`):
  360/360 đúng; số MonMul đếm đúng công thức, e = 65537 dùng 18 MonMul (đường gốc 67 với
  E_SCAN = 32). Log: `logs/test-rsa-pa1.log`.
- Ước lượng trước đó 18 x 8584 = 154,512; đo được 155,611 (chênh 1,099 cycle do các trạng
  thái điều khiển giữa các MonMul và 16 cycle dò bit cao nhất của E).
- Số này chưa có trong Vivado: muốn dùng cho bài báo phải đưa bản sửa về `ip_repo` và chạy lại.

## 8. Tài nguyên FPGA của IP RSA (bản PA1), đo bằng Yosys, 2026-10-14

Lệnh: `.tools/yosys-env/bin/yosys -l logs/synth-rsa-baseline.log synth/rsa_baseline.ys`
(Yosys 0.69, `synth_xilinx -family xc7 -flatten`, top = wrapper AXI + lõi `rsa`, RSA_WIDTH = 2048).
Kết quả: `logs/synth-rsa-baseline.stat`.

| Tài nguyên | Số lượng | % của xc7z020 |
|---|---|---|
| LUT logic (LUT2-6 + INV) | 11,803 | |
| LUT làm RAM (86 RAM64M x 4) | 344 | |
| Tổng LUT | ~12,147 | ~22.8% (53,200) |
| FF (FDRE) | 20,862 | ~19.6% (106,400) |
| DSP48E1 | 4 | 1.8% (220) |
| CARRY4 | 53 | |

- So với CPU RISSP (1,126 LUT, 175 FF theo README), IP RSA lớn hơn khoảng 10 lần về LUT.
- 4 DSP là bộ MAC 32x32 duy nhất. Phần lớn LUT/FF nằm ở các mảng toán hạng giữ bằng thanh
  ghi (8 mảng trong lõi, 3 mảng trong wrapper, thanh ghi C 2048-bit) và bộ mux đọc của chúng.
- Đây là số của Yosys, chưa phải Vivado. Vivado thường cho số LUT khác (thường thấp hơn);
  nên đo lại bằng Vivado trước khi đưa vào bài báo.
- `synth/RSA_core_synth.v` là bản sao `rtl/patched/RSA_core.v`, chỉ thay dòng xóa mảng `t`
  bằng vòng for gốc vì Yosys không đọc được `'{default: ...}`.
