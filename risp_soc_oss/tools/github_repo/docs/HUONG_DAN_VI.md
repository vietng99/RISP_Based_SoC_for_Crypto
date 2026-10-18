# Hướng dẫn sử dụng (tiếng Việt)

Repo này có 6 SoC dùng chung một block design trong Vivado. Giữa các SoC chỉ khác khối CPU
(`cpu_core`). Cả 6 SoC chạy cùng firmware, cùng testbench và cùng 3 accelerator AES-128,
SHA3-256, RSA-2048.

| Thư mục | CPU | Khối CPU trong Diagram |
|---|---|---|
| `socs/rissp_soc` | RISSP gốc (35 lệnh) | `rissp_top_0` |
| `socs/rissp_v2b_soc` | RISSP v2b: 9 lệnh, mỗi loại lệnh một khối phần cứng | `rissp_v2b_0` |
| `socs/rv32i_soc` | RV32I pipeline 5 tầng (`rv32i_ultra`) | `rv32i_0` |
| `socs/ibex_soc` | Ibex (tắt RV32M) | `ibex_core_0` |
| `socs/rocket_soc` | Rocket RV32 cấu hình nhỏ, sinh từ Chipyard | `rocket_0` |
| `socs/cva6_soc` | CVA6 `cv32a6_imac_sv0` | `cva6_0` |

## 1. Tạo project

Cần Vivado 2024.2 trở lên, có cài part `xczu9eg-ffvb1156-2-e` (ZCU102).

1. Clone repo:
   ```
   git clone https://github.com/thanhtruong332/SoC-all-core.git
   ```
2. Gõ vào Tcl Console của Vivado (đổi `<repo>` thành đường dẫn tới thư mục vừa clone):
   ```
   source <repo>/socs/rissp_soc/create_project.tcl
   ```
   - Lần đầu, script tạo project `socs/rissp_soc/rissp_soc.xpr` và dựng block design. Xong thì
     Tcl Console in `rissp_soc: project ready`. Mất khoảng 2-5 phút; CVA6 mất khoảng 10-15 phút.
   - Các lần sau, chạy lại đúng lệnh đó: script chỉ mở project đã có.
   - Muốn đổi sang SoC khác, `source` script của SoC đó. Script tự đóng project đang mở.
   - Muốn dựng lại từ đầu: `set core_soc_rebuild 1`, rồi `source` lại. Lệnh này xóa các file
     `<tên>_soc.*` mà Vivado tạo trong thư mục của SoC đó.
   - Muốn dùng part khác, gõ trước lệnh `source`: `set core_soc_part <part>`.

## 2. Chạy mô phỏng

```
set_test aes_ecb
```
Lệnh này nạp `firmware/aes_ecb.coe` vào ROM lệnh (`blk_mem_gen_0`) và đặt `tb_aes_ecb` làm
top mô phỏng. Sau đó bấm Run Simulation > Run Behavioral Simulation. Testbench in `[PASS]` hoặc
`[FAIL]` kèm số cycle.

| `set_test` | Testbench | Firmware |
|---|---|---|
| `aes_ecb` / `aes_cbc` / `aes_cfb` / `aes_ctr` | `tb_aes_*` | AES-128 |
| `sha3` / `sha3_4` / `sha3_16` | `tb_sha3*` | SHA3-256, 1/4/16 block |
| `rsa2048` | `tb_rsa2048` | RSA-2048 |
| `rsa2048_fast` | `tb_rsa2048` | RSA-2048, đường nhanh cho e = 65537 |
| `rsa` | `tb_rsa` | map RSA 32-bit cũ, sẽ TIMEOUT trên các SoC này |

## 3. Synthesis, implementation, fmax

- Chạy Synthesis và Implementation trong Flow Navigator như bình thường.
- Đo fmax: mở Diagram, bấm đúp `clk_wiz_0`, đổi tần số `clk_out1` (mặc định 40 MHz), chạy lại
  implementation rồi đọc WNS. Ước lượng nhanh: fmax = 1000 / (chu kỳ ns - WNS).

## 4. Các điểm cần biết

Các chỉnh sửa riêng cho Vivado (header, `instr_tracer`, `XSIM`, SRAM, `TARGET_VIVADO`) và lý
do của từng chỗ được ghi trong [VIVADO_NOTES.md](VIVADO_NOTES.md).
