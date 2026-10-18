# core_soc_vivado: 6 SoC cho Vivado 2024.2

Gói này chứa 6 SoC giống hệt nhau, chỉ khác CPU. Mỗi SoC có đủ firmware (.coe/.mem) cho từng test và 10 testbench.
Part mặc định: `xczu9eg-ffvb1156-2-e` (board ZCU102, Zynq UltraScale+). Nếu Vivado có board file ZCU102 thì script gán luôn board part.
Muốn dùng part khác (ví dụ `xc7z020clg484-1` của ZedBoard, giống paper), gõ trước khi `source`:
`set core_soc_part xc7z020clg484-1`

Lưu ý: số fmax và area trên ZCU102 (UltraScale+) không so trực tiếp được với Table II của paper (Zynq-7020). Muốn so với paper thì dùng `xc7z020clg484-1`.

| Thư mục | CPU |
|---|---|
| `rissp_v2b_soc/` | RISSP v2b: 9 lệnh, mỗi loại lệnh một hardware instruction block (core mới) |
| `rissp_soc/` | RISSP gốc (35 lệnh) |
| `rv32i_soc/` | RV32I |
| `ibex_soc/` | Ibex |
| `rocket_soc/` | Rocket (chipyard) |
| `cva6_soc/` | CVA6 |

Cả 6 SoC dùng chung: AES-128, SHA3-256, RSA-2048 PA1-R (có đường e=65537 nhanh, CTRL=0x3), bus AXI4-Lite `axi_lite_xbar`, ROM 32 KiB, BRAM debug, UART.

## 1. Mở project (lần đầu khoảng 1 phút)

Windows: vào thư mục SoC, bấm đúp `open_<tên>_soc.bat` (ví dụ `rissp_v2b_soc/open_rissp_v2b_soc.bat`).

- Lần đầu: Vivado chạy `create_project.tcl`, tạo `rissp_v2b_soc.xpr` trong cùng thư mục, rồi mở luôn.
- Các lần sau: bấm lại file `.bat`, hoặc mở trực tiếp `rissp_v2b_soc.xpr` (File > Open Project).
- Nếu `.bat` không tìm thấy Vivado: mở Vivado 2024.2, vào Tcl Console, gõ
  `source <đường dẫn>/rissp_v2b_soc/create_project.tcl`
- Giải nén vào đường dẫn ngắn, không dấu, không khoảng trắng (ví dụ `D:\core_soc_vivado`). Đường dẫn dài trên Windows làm Vivado báo lỗi.

## 2. Chạy test

1. Ở tab Sources, mở Simulation Sources > sim_1.
2. Chuột phải vào testbench muốn chạy, chọn **Set as Top**.
3. Bấm Run Simulation > Run Behavioral Simulation. Mô phỏng tự chạy đến hết (`xsim.simulate.runtime = all`).
4. Kết quả in ở Tcl Console: dòng `==> [PASS] ...` cùng các mốc cycle.

Firmware đã gắn sẵn trong từng testbench (`IMEM_INIT`), không phải sửa gì:

| Testbench | Firmware | Kiểm tra |
|---|---|---|
| `tb_aes_ecb` / `tb_aes_cbc` / `tb_aes_cfb` / `tb_aes_ctr` | `aes_*.mem` | AES-128, 4 check |
| `tb_sha3` / `tb_sha3_4` / `tb_sha3_16` | `sha3*.mem` | SHA3-256 1/4/16 block, 9 check |
| `tb_rsa2048` | `rsa2048.mem` | RSA-2048, CTRL=0x1 (đường chung) |
| `tb_rsa2048_fast` | `rsa2048_fast.mem` | RSA-2048, CTRL=0x3 (e=65537 nhanh) |
| `tb_rsa` | `rsa.mem` | Map RSA 32-bit cũ. Dự kiến TIMEOUT trên mọi CPU, giữ lại để đối chiếu |

Các file `.coe` trong `firmware/` có cùng nội dung với `.mem`. Dùng `.coe` khi nạp vào `blk_mem_gen` trong block design.

### PURE cycles dự kiến (Verilator, 40 MHz)

| Test | rissp_v2b | rissp | rv32i | ibex | rocket | cva6 |
|---|---:|---:|---:|---:|---:|---:|
| AES-128 ECB | 49 | 75 | 73 | 70 | 134 | 109 |
| AES-128 CBC/CFB/CTR | 65 | 107 | 105 | 102 | 166 | 144 |
| SHA3-256 1 block | 230 | 427 | 431 | 426 | 756 | 517 |
| SHA3-256 4 block | 861 | 1,553 | 1,689 | 1,684 | 2,176 | 1,741 |
| SHA3-256 16 block | 3,309 | 6,041 | 6,585 | 6,580 | 8,296 | 6,637 |
| RSA-2048 CTRL=0x1 | 320,328 | 320,714 | 320,779 | 320,720 | 321,615 | 321,228 |
| RSA-2048 CTRL=0x3 | 156,128 | 156,515 | 156,579 | 156,515 | 157,407 | 157,023 |

Nếu xsim cho số khác bảng này, hãy ghi lại cả hai số: đó chính là phần đối chiếu Vivado/Verilator (task t-005).

## 3. Đo fmax

1. Mở `constrs/core_soc.xdc` (dùng chung cho cả 6 SoC). Mặc định là `create_clock -period 25.000` (40 MHz).
2. Bấm Run Implementation, rồi mở Open Implemented Design > Report Timing Summary và đọc WNS.
3. Ước lượng fmax = 1000 / (period - WNS) MHz. Ví dụ period 25 ns, WNS 5 ns cho ra 50 MHz.
4. Muốn có số chính xác: đặt period gần bằng (period - WNS) vừa đo, chạy lại, rồi lặp đến khi WNS gần 0 mà vẫn dương.
5. Ghi lại: WNS, period, `report_utilization -hierarchical` (LUT/FF của CPU và của cả SoC) và `report_power`.

Khi synthesis, ROM được nạp sẵn `aes_ecb.mem` (generic `IMEM_INIT` đặt ở Settings > General > Generics/Parameters). Không được để trống generic này: nếu ROM rỗng, mọi lệnh đọc ra đều bằng 0 và Vivado sẽ cắt bỏ phần lớn logic CPU, khiến area và fmax đo được bị sai.

## 4. Giới hạn đã biết

- Script và testbench được kiểm tra bằng Verilator và tclsh trên máy Linux, chưa chạy thử trong Vivado vì máy đó không có Vivado.
- SoC dựng hoàn toàn từ RTL, không có block design, MMCM hay Zynq PS. Clock đi thẳng từ chân `clk_in1_0`. Bus là `axi_lite_xbar` (pulp), không phải `axi_interconnect` của Xilinx, nên số cycle và fmax có thể khác project block design cũ.
- Ibex dùng `BUFGCE` của Xilinx: xsim lấy từ thư viện `unisims_ver` có sẵn trong Vivado. Script tự đặt `SIM_DEVICE` theo họ chip của part (`7SERIES` hoặc `ULTRASCALE_PLUS`) qua define `CORE_SOC_ULTRASCALE`.
- Rocket và CVA6 lớn: lần đầu biên dịch mô phỏng mất vài phút, synthesis lâu hơn các SoC còn lại.
- Rocket đặt `PRINTF_COND=0` để tắt log từng lệnh khi mô phỏng.
- Cột Mbps/W mà testbench in ra dùng `POWER_W = 0.407` cố định của SoC cũ, không phải power đo được.
