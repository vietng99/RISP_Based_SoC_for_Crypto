# core_soc_bd: 6 SoC dạng block design (giống Fig. 6 của paper) cho Vivado 2024.2

Mỗi project tạo ra `design_1.bd` dựng theo đúng block design `SE-RISSP_AES_ULTRA` của bạn: `clk_wiz_0`, `proc_sys_reset_0`, `axi_interconnect_0` (1 master, 5 slave), `xlslice_0`, `blk_mem_gen_0` (ROM lệnh, nạp `.coe`), `axi_bram_ctrl_0` + `blk_mem_gen_1`, `axi_uartlite_0`, `aes_axi_slave_0`, `SHA3_hardware_new_0`, `RSA_mark03_0`. Giữa 6 SoC chỉ khác **khối CPU**:

| Thư mục | Khối CPU trong Diagram | CPU |
|---|---|---|
| `rissp_v2b_soc/` | `rissp_v2b_0` | RISSP v2b: 9 lệnh, mỗi loại lệnh một hardware instruction block |
| `rissp_soc/` | `rissp_top_0` | RISSP gốc (35 lệnh) |
| `rv32i_soc/` | `rv32i_0` | RV32I (`rv32i_ultra`) |
| `ibex_soc/` | `ibex_core_0` | Ibex (RV32M=0) |
| `rocket_soc/` | `rocket_0` | Rocket |
| `cva6_soc/` | `cva6_0` | CVA6 |

Bản đồ địa chỉ: AES `0x4000_0000` (16K), SHA3 `0x4400_0000` (64K), RSA `0x4800_0000` (64K), UART `0x4060_0000` (64K), BRAM debug `0xC000_0000` (8K).

## 1. Mở project (lần đầu khoảng 2-5 phút)

Gõ vào Tcl Console của Vivado 2024.2 (đổi đường dẫn cho đúng chỗ bạn giải nén):
```
source <workspace>/core_soc_bd/rissp_v2b_soc/create_project.tcl
```
- Lần đầu: script tạo `rissp_v2b_soc.xpr`, dựng block design, tạo `design_1_wrapper`, rồi mở Diagram.
- Các lần sau: chạy lại đúng lệnh `source` đó. Script thấy `.xpr` đã có thì chỉ mở, đồng thời nạp lệnh `set_test`.
- Muốn chuyển sang SoC khác: chỉ cần `source` script của SoC đó. Script tự đóng project đang mở.
- Nếu lần tạo trước bị dừng giữa chừng (Diagram có khối nhưng chưa nối dây), dựng lại:
  `set core_soc_rebuild 1` rồi `source` lại script. Lệnh này xóa các file `<tên>_soc.*` do Vivado tạo trong thư mục đó (giữ lại `create_project.tcl`).
- Part mặc định: `xczu9eg-ffvb1156-2-e` (ZCU102). Muốn dùng part khác, gõ trước lệnh `source`: `set core_soc_part xc7z020clg484-1`.

## 2. Chạy test

```
set_test aes_ecb
```
Lệnh này nạp `firmware/aes_ecb.coe` vào `blk_mem_gen_0`, tạo lại output products, rồi đặt `tb_aes_ecb` làm top mô phỏng. Sau đó bấm Run Simulation > Run Behavioral Simulation.

| `set_test` | Testbench | Firmware |
|---|---|---|
| `aes_ecb` / `aes_cbc` / `aes_cfb` / `aes_ctr` | `tb_aes_*` | AES-128 |
| `sha3` / `sha3_4` / `sha3_16` | `tb_sha3*` | SHA3-256 1/4/16 block |
| `rsa2048` | `tb_rsa2048` | RSA-2048 CTRL=0x1 |
| `rsa2048_fast` | `tb_rsa2048` | RSA-2048 CTRL=0x3 (e=65537 nhanh) |
| `rsa` | `tb_rsa` | Map RSA 32-bit cũ, dự kiến TIMEOUT |

Testbench lấy nguyên từ `hardware/testbench/rissp/` của bạn. Testbench không tham chiếu tới CPU nên dùng được cho cả 6 SoC.

## 3. Đo fmax

1. Mở Diagram, bấm đúp `clk_wiz_0`, đổi `clk_out1` (mặc định 40 MHz).
2. Run Implementation, rồi đọc WNS trong Report Timing Summary.
3. Tăng tần số cho tới khi WNS gần 0 mà vẫn dương. Ước lượng nhanh: fmax ≈ 1000 / (chu kỳ ns - WNS).

## 4. Khác với project cũ

- CPU, AES, SHA3, RSA đưa vào block design dạng **module reference** (khối có nhãn RTL). Lý do: IP đóng gói trong `ip_repo` cũ chỉ khai báo họ `zynq`, nên không dùng được trên ZCU102. RTL bên trong giống hệt.
- Ibex và RV32I nằm sau một wrapper `cpu_core` có cùng port với RISSP (`clk`, `rst_n`, `imem_addr`, `imem_rdata`, `m_axi`). Khối `addsub_bootoffset_0` (Ibex) và `xlconstant_0` (RV32I) trong project cũ được đưa vào wrapper (file `src/risp_soc_oss/tools/bd/cpu_core_*.v`). Nhờ vậy cả 6 SoC có cùng một Diagram.
- Synthesis chạy global (`synth_checkpoint_mode None`), tức cả SoC synthesize trong một run.

## 5. Đã kiểm tra / chưa kiểm tra

- Đã kiểm tra: 6 wrapper `cpu_core` chạy trong SoC RTL bằng Verilator, 16/16 test PASS, cycles giống bảng cũ (v2b: AES ECB 49, SHA3 16 block 3,309, RSA nhanh 156,128). Script Tcl đã chạy thử bằng tclsh với lệnh Vivado giả lập, không thiếu file nào.
- Chưa chạy trong Vivado (máy tạo gói không có Vivado). Những chỗ có thể cần sửa lần đầu: tên interface mà Vivado tự suy ra cho module reference, và range địa chỉ của các slave. Nếu có lỗi, gửi dòng `ERROR:` đầu tiên.
- Bus là `axi_interconnect` của Xilinx (giống paper), nên cycles có thể khác số Verilator (Verilator dùng `axi_lite_xbar`).
