# Five SoCs, one SoC design: RISSP, RV32I, Ibex, Rocket, CVA6

Date: 2026-10-15. Verilator 5.022 (chipyard conda env), 40 MHz SoC clock as in
the testbenches. All numbers are SoC clock cycles.

## What is compared

Every SoC has the same RISSP block design (`rtl/soc/design_1.sv`): pulp
AXI4-Lite crossbar with the RISSP address map, AES / SHA3 / RSA PA1-R
accelerators, 8 KiB BRAM, UART, and the 32 KiB instruction ROM on the CPU's
imem port. Only the CPU changes. All five run the same firmware hex files
from `RISP/hardware/firmware` (RV32I only, see the "fair comparison" header in
every `.s` file).

| SoC | CPU | Source | How it sits in the SoC |
| --- | --- | --- | --- |
| RISSP | RISSP (RV32I subset, 35 instructions per start.S) | `RISP/ip_repo/cpu_rissp` | native imem + AXI4-Lite |
| RV32I | RV32I core from the RV32I_SoC project | `RISP/ip_repo` | `rtl/soc/design_1_rv32i.sv` (t-013) |
| Ibex | Ibex (RV32M=0, no I-cache) | `RISP/ip_repo` | `rtl/soc/design_1_ibex.sv` (t-013) |
| Rocket | small Rocket: RV32IMAC, no FPU, no VM, 4 KiB I$ and D$ | chipyard 1.14.0 rocket-chip | `rtl/cores/rocket/rissp_top_rocket.sv` |
| CVA6 | cv32a6_imac_sv0: RV32IMAC, 16 KiB I$, 32 KiB WT D$ | CVA6 v5.3.0 | `rtl/cores/cva6/rissp_top_cva6.sv` |

Rocket and CVA6 replace the module behind `rissp_top` and leave `design_1.sv`
unchanged. They run the 9 RISSP testbenches unchanged. Their instruction
caches refill from the same ROM through `rtl/cores/common/axi_rom_bridge.sv`
(one 32-bit word per cycle). Their loads and stores to accelerators and BRAM
are uncached and pass through `rtl/cores/common/axi4_to_axil.sv`, which adds
no cycle. Design: `CORE_SWAP_DESIGN.md`.

## Results

Sources: RISSP, RV32I, Ibex from t-014
(the author's run summaries 06, 07 and 08); Rocket
`logs/summary-rocket.txt`; CVA6 `logs/summary-cva6.txt`. Table made by
`tools/results_5soc.py` (`logs/results-5soc.md`).

### Verdict (golden checks)

All 45 cells PASS: AES 4/4, SHA3 9/9, RSA 9/9 on every CPU. `tb_rsa`
(old 32-bit RSA register map in `rsa.s`) times out on every CPU and is left
out, as in t-004 and t-014.

### Accelerator core cycles

Equal on all five CPUs: AES 17, SHA3 29, RSA-2048 319,814 (CTRL=0x1) and
155,611 (CTRL=0x3).

### PURE cycles (CPU + bus + accelerator, stamped on AXI/BRAM signals)

| Test | RISSP | RV32I | Ibex | Rocket | CVA6 |
|---|---:|---:|---:|---:|---:|
| AES-128 ECB | 75 | 73 | 70 | 134 | 109 |
| AES-128 CBC | 107 | 105 | 102 | 166 | 144 |
| AES-128 CFB | 107 | 105 | 102 | 166 | 144 |
| AES-128 CTR | 107 | 105 | 102 | 166 | 144 |
| SHA3-256 1 block | 427 | 431 | 426 | 756 | 517 |
| SHA3-256 4 block | 1,553 | 1,689 | 1,684 | 2,176 | 1,741 |
| SHA3-256 16 block | 6,041 | 6,585 | 6,580 | 8,296 | 6,637 |
| RSA-2048 CTRL=0x1 | 320,714 | 320,779 | 320,720 | 321,615 | 321,228 |
| RSA-2048 CTRL=0x3 | 156,515 | 156,579 | 156,515 | 157,407 | 157,023 |

### PURE relative to RISSP (lower is faster)

| Test | RV32I | Ibex | Rocket | CVA6 |
|---|---:|---:|---:|---:|
| AES-128 ECB | 0.973 | 0.933 | 1.787 | 1.453 |
| AES-128 CBC/CFB/CTR | 0.981 | 0.953 | 1.551 | 1.346 |
| SHA3-256 1 block | 1.009 | 0.998 | 1.770 | 1.211 |
| SHA3-256 4 block | 1.088 | 1.084 | 1.401 | 1.121 |
| SHA3-256 16 block | 1.090 | 1.089 | 1.373 | 1.099 |
| RSA-2048 CTRL=0x1 | 1.000 | 1.000 | 1.003 | 1.002 |
| RSA-2048 CTRL=0x3 | 1.000 | 1.000 | 1.006 | 1.003 |

END-TO-END cycles follow the same order; see `logs/results-5soc.md`.

## Reading the numbers

- The accelerators do the same work on every CPU, so the differences come from
  the CPU and its path to the AXI4-Lite port.
- Rocket's uncached loads and stores go through the standard rocket-chip
  subsystem: D-cache uncached path, tile crossing buffer, system bus crossbar,
  `TLToAXI4`, AXI4 user/ID/deinterleave stages and an `AXI4Buffer`
  (`rtl/cores/rocket/gen/`). In the commit trace of the first sha3 run, one
  uncached store retires about every 11 cycles. This gives the largest
  overhead on short, register-heavy tests (AES, SHA3 1 block).
- CVA6 sends loads to non-idempotent memory only at commit and stores through
  its write buffer; it is slower than RISSP on short tests and close to RV32I /
  Ibex on SHA3 16 block.
- Both cached cores start cold: instruction cache misses refill from the ROM
  inside the measured windows, once per test.
- On RSA-2048 the accelerator runs for 155k to 320k cycles, so all five CPUs
  are within 0.6% of each other.

## Limits

- CVA6 is upstream v5.3.0. The CVA6 that chipyard 1.14.0 pins (2021) is
  64-bit only and cannot run the RV32I firmware.
- Rocket's subsystem keeps a CLINT and a PLIC (rocket-chip needs them to
  elaborate the tile interrupt crossings). They sit at 0x0200_0000 and
  0x0C00_0000, outside the SoC map, and the firmware never touches them.
- CVA6 uses the SoC's pulp common_cells v1.39.0 / axi v0.39.11 in place of its
  vendored copies (one definition per module in one Verilator build).
- `axi4_to_axil` keeps the address on AW/AR after the handshake until the
  response, as RISSP does; tb_sha3 reads ARADDR at RVALID for its DIGEST stamp.
- Verilator numbers only; no Vivado or FPGA timing, no area for Rocket/CVA6.

## Reproduce

```
cd risp_soc_oss
export PATH=$PWD/../chipyard/.conda-env/bin:$PATH
# Rocket Verilog (chipyard sbt, about 8 min the first time):
#   cd ../chipyard && java -jar scripts/sbt-launch.jar ";project chipyard; runMain chipyard.risp.RispRocketGen $PWD/rtl/cores/rocket/gen"
python3 tools/mk_cva6_flist.py
make -j4 -f mk/core.mk CORE=rocket tbs && make -f mk/core.mk CORE=rocket run-all
make -j4 -f mk/core.mk CORE=cva6 tbs   && make -f mk/core.mk CORE=cva6 run-all
python3 tools/results_5soc.py RISSP=<rissp summary> RV32I=<rv32i summary> Ibex=<ibex summary> \
  Rocket=logs/summary-rocket.txt CVA6=logs/summary-cva6.txt
```
