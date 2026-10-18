# Kết quả 3 SoC (RISSP, RV32I, Ibex) với RSA PA1-R, mô phỏng bằng tool của chipyard

Ngày: 2026-10-14 (t-014). Clock SoC 40 MHz cho cả 3 hệ.

## Môi trường

- Tool lấy từ `chipyard/.conda-env`: Verilator 5.022, `riscv64-unknown-elf-{as,ld,objcopy}`
  (gcc 13.2.0). Phiên bản ghi ở `logs/t014/tools.txt`.
- SoC là bản dựng lại từ block design Vivado của từng hệ (`rtl/soc/design_1.sv`,
  `design_1_rv32i.sv`, `design_1_ibex.sv`): cùng ngoại vi, cùng address map, CPU lấy RTL từ
  `ip_repo`. Không dùng generator Chipyard, không có TileLink system bus, CLINT hay PLIC.
  Interconnect là `axi_lite_xbar` (pulp-platform) thay cho `axi_interconnect_0` của Xilinx.
- RSA: bản PA1-R trong `RISP/ip_repo/acc_rsa` (t-012). Bản cũ sao lưu ở
  `backup/acc_rsa-orig-2026-10-14/`.
- Firmware: build lại toàn bộ `.s` trong `RISP/hardware/firmware` bằng gcc của chipyard
  (`make fw-check`, `tools/build_fw.py`). Mọi `.hex` và `.coe` trùng từng byte với file có sẵn
  (`logs/t014/fw-check.log`).
- Firmware RSA mới: `RISP/hardware/firmware/rsa2048_fast.s` (+ `.hex`, `.coe`), sinh bởi
  `tools/gen_rsa2048_fast_s.py`. Chỉ khác `rsa2048.s` ở CTRL = 0x3 (start + fast_pub) và
  phần chú thích. Khóa, thông điệp, cửa sổ đo PURE và giá trị kiểm tra giữ nguyên, nên cùng
  testbench `tb_*_rsa2048` kiểm tra được. Chỉ dùng khi E là số mũ công khai (verify).
- Testbench: bản gốc của Vivado, chỉ sửa cách force clock cho Verilator (`logs/tb-adapt.diff`,
  `logs/rv32i-tb-adapt.diff`, `logs/ibex-tb-adapt.diff`).

## Bảng kết quả

Lõi = số cycle của accelerator (AES: CTRL -> done, SHA3: iLast -> oReady, RSA: start -> done).
PURE = cửa sổ đo trên bus, định nghĩa trong header từng firmware.

| Test | RISSP ket qua | RISSP loi | RISSP PURE | RV32I ket qua | RV32I loi | RV32I PURE | Ibex ket qua | Ibex loi | Ibex PURE |
|---|---|---|---|---|---|---|---|---|---|
| AES-128 ECB | PASS 4/4 | 17 | 75 (68.27 Mbps) | PASS 4/4 | 17 | 73 (70.14 Mbps) | PASS 4/4 | 17 | 70 (73.14 Mbps) |
| AES-128 CBC | PASS 4/4 | 17 | 107 (47.85 Mbps) | PASS 4/4 | 17 | 105 (48.76 Mbps) | PASS 4/4 | 17 | 102 (50.20 Mbps) |
| AES-128 CFB | PASS 4/4 | 17 | 107 (47.85 Mbps) | PASS 4/4 | 17 | 105 (48.76 Mbps) | PASS 4/4 | 17 | 102 (50.20 Mbps) |
| AES-128 CTR | PASS 4/4 | 17 | 107 (47.85 Mbps) | PASS 4/4 | 17 | 105 (48.76 Mbps) | PASS 4/4 | 17 | 102 (50.20 Mbps) |
| SHA3-256 1 block | PASS 9/9 | 29 | 427 (95.93 Mbps) | PASS 9/9 | 29 | 431 (95.03 Mbps) | PASS 9/9 | 29 | 426 (96.15 Mbps) |
| SHA3-256 4 block | PASS 9/9 | 29 | 1,553 (110.44 Mbps) | PASS 9/9 | 29 | 1,689 (101.55 Mbps) | PASS 9/9 | 29 | 1,684 (101.85 Mbps) |
| SHA3-256 16 block | PASS 9/9 | 29 | 6,041 (114.84 Mbps) | PASS 9/9 | 29 | 6,585 (105.35 Mbps) | PASS 9/9 | 29 | 6,580 (105.43 Mbps) |
| RSA-2048 verify, CTRL=0x1 (goc) | PASS 9/9 | 319,814 | 320,714 (8017.85 us) | PASS 9/9 | 319,814 | 320,779 (8019.48 us) | PASS 9/9 | 319,814 | 320,720 (8018.00 us) |
| RSA-2048 verify, CTRL=0x3 (nhanh) | PASS 9/9 | 155,611 | 156,515 (3912.88 us) | PASS 9/9 | 155,611 | 156,579 (3914.47 us) | PASS 9/9 | 155,611 | 156,515 (3912.88 us) |

Nguồn: `logs/summary-rissp.txt`, `logs/summary-rv32i.txt`, `logs/summary-ibex.txt`. Lint 0
`%Error` trên cả 3 hệ (`logs/t014/rissp-lint.log`, `logs/rv32i-lint.log`, `logs/ibex-lint.log`).

## Nhận xét

- Cả 3 hệ PASS mọi test AES (4 mode), SHA3 (1, 4, 16 block) và RSA-2048 (2 luồng).
- Số cycle lõi giống nhau trên cả 3 CPU (AES 17, SHA3 29, RSA 319,814 / 155,611): accelerator
  không phụ thuộc CPU. Phần chênh giữa các CPU nằm ở firmware và bus.
- RSA luồng nhanh giảm lõi 51.3% và PURE 51.2% trên cả 3 hệ.
- So với Vivado (`RISP/README.md:118`, RSA-2048: RISSP 320,972, RV32I 321,039, Ibex 320,974):
  PURE luồng gốc của Verilator thấp hơn 254-260 cycle (-0.08%). Lý do: bus Verilator không có
  độ trễ (`PERF_NOTES.md` mục 3). README không ghi rõ chỉ số; giả định là PURE.
- `tb_rsa` (RISSP) không có trong bảng: firmware `rsa.s` dùng register map RSA 32-bit cũ
  (CTRL 0x14), IP hiện tại là 2048-bit (CTRL 0x308), nên FAIL do timeout như trước PA1.

## Giới hạn

- Chưa có số Vivado cho AES và SHA3 của RV32I và Ibex, nên chưa so được 2 cột đó.
- Ibex: mô hình BUFGCE cho clock đi thẳng qua (`rtl/patched_ibex/xilinx_clkbuf_models.v`).
  Trong mọi lần chạy, CE luôn bằng 1 sau khi CPU chạy, nên giống phần cứng. Firmware có WFI
  sẽ không được mô phỏng đúng.
- 3 project Vivado vẫn dùng RSA cũ (bản chép trong `ipshared/f662`) cho tới khi Upgrade IP.

## Chạy lại

```
cd risp_soc_oss
export PATH=<chipyard>/.conda-env/bin:$PATH
make fw-check
make -j3 soc-tbs && make run-all && make run-tb_rsa2048_fast
make -j3 -f mk/rv32i.mk tbs && make -f mk/rv32i.mk run-all
make -j3 -f mk/ibex.mk tbs && make -f mk/ibex.mk run-all
python3 tools/summary.py tb_aes_ecb tb_aes_cbc tb_aes_cfb tb_aes_ctr tb_sha3 tb_sha3_4 tb_sha3_16 tb_rsa tb_rsa2048 tb_rsa2048_fast > logs/summary-rissp.txt
python3 tools/results_3soc.py logs/summary-rissp.txt logs/summary-rv32i.txt logs/summary-ibex.txt
```
