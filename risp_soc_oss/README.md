# risp_soc_oss: RISSP SoC without Vivado IP

Open-source rebuild of the Vivado block design
`RISP/hardware/projects/RISSP_SoC/.../bd/design_1` (SE-RISSP_AES_ULTRA).
The CPU and the three accelerators are the original RTL from `RISP/ip_repo`;
every Xilinx IP is replaced (see the table at the top of `rtl/soc/design_1.sv`).
Instance and net names match the Vivado-generated `design_1.v`, so the
original testbenches in `RISP/hardware/testbench/rissp` run here.

## Run

```
export PATH=<chipyard>/.conda-env/bin:$PATH   # Verilator 5.022
make lint-soc          # Verilator -Wall lint of design_1_wrapper
make -j3 soc-tbs       # build one simulator per testbench
make run-all           # run all firmwares, write logs/run-<tb>.log and logs/summary.txt
make run-tb_sha3       # one testbench; tb_<name> loads firmware/<name>.hex
```

## RISSP v2 CPU

`rtl/cores/rissp_v2/rissp_top_v2.v` is the RISSP CPU cut down to the nine
instructions the firmware uses, with a bus master that issues AXI requests in
the decode cycle. Same SoC, testbenches and firmware. Design and results:
`RISSP_V2_DESIGN.md`.

```
make -f mk/core.mk CORE=rissp_v2 -j3 tbs
make -f mk/core.mk CORE=rissp_v2 run-all     # logs/summary-rissp_v2.txt
```

## Differences from the Vivado flow

- Testbenches: `tools/adapt_tb.py` copies each Vivado testbench into
  `build/tb/` with one change. Verilator 5.022 evaluates the right-hand side of
  `force ...clk_wiz_0_clk_out1 = soc_clk_drv` once, so the copy re-applies the
  force on every edge of `soc_clk_drv`. Diffs: `logs/tb-adapt.diff`.
- `rtl/patched/RSA_core.v`: one line changed (whole-array clear instead of a
  for-loop of non-blocking assignments, which Verilator 5.022 rejects).
  Diff: `patches/RSA_core.v.diff`.
- PA1 (RSA public-exponent flow, design in `RSA_PA1_DESIGN.md`):
  `rtl/patched/RSA_core.v` adds a `fast_pub` input (18 MonMul for e = 65537,
  not constant time), and `rtl/patched/RSA_mark03_slave_lite_v1_0_S00_AXI.v`
  maps it to CTRL bit1. CTRL = 0x1 runs the original flow cycle for cycle;
  CTRL = 0x3 runs the fast flow. The wrapper copy has LF line endings (the
  original is CRLF). Diffs: `patches/RSA_core.v.diff`,
  `patches/RSA_mark03_slave_lite_v1_0_S00_AXI.v.diff`.
  `make run-tb_rsa2048_fast` runs `tb_rsa2048` with `firmware/rsa2048_fast.hex`,
  made by `tools/mk_rsa2048_fast.py` (one word changed: `li x6, 0x1` to `0x3`).
- Instruction ROM loads firmware from `+FIRMWARE=<hex>` instead of a .coe file.
- Interconnect is pulp-platform `axi_lite_xbar` (no latency), BRAM controller
  and UART are small local modules. Bus timing differs from the Xilinx
  interconnect, so AXI-level cycle counts can differ from Vivado; accelerator
  core counts should not.
- `tb_rsa` / `rsa.hex` targets the old 32-bit RSA register map and cannot work
  with the 2048-bit RSA IP in this block design (CTRL moved from 0x14 to 0x308).
