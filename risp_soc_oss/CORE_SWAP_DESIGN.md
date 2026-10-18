# Core swap: Rocket and CVA6 in the RISSP SoC

Goal (owner, 2026-10-15): put the Rocket and CVA6 cores into the RISSP SoC,
with RISSP as the reference configuration, so that the SoCs differ only in the
CPU. Then run the RISSP firmware and testbenches and compare.

## 1. What stays equal

- `rtl/soc/design_1.sv` is used as is (byte-identical). It instantiates a
  module called `rissp_top` with instance name `rissp_top_0`. Each new core
  ships a wrapper module that is also named `rissp_top` and has exactly the
  RISSP CPU ports:
  `clk, rst_n, imem_addr[31:0], imem_rdata[31:0], m_axi_*` (AXI4-Lite, 32-bit
  address and data). The filelist picks the wrapper instead of
  `ip_repo/cpu_rissp`. Nothing else in the SoC changes: same `rom_sync`
  instruction ROM (8192 words, read latency 1) on the imem port, same
  `axil_xbar_flat` with the same address map, same AES / SHA3 / RSA PA1-R,
  same BRAM controller and UART, same clock/reset blocks.
- Testbenches: the 9 RISSP testbenches in `RISP/hardware/testbench/rissp`,
  through the same `tools/adapt_tb.py` copy as RISSP. They only probe the
  AXI slaves, the BRAM port and the clock (no CPU signal), so they run
  unchanged.
- Firmware: the same `RISP/hardware/firmware/*.hex` (RV32I only, linked at
  0x0, stack at the top of BRAM 0xC0002000, all data through AXI). This is
  the "fair comparison" contract written in every `.s` header.

## 2. What differs, and why it cannot be equal

Rocket and CVA6 are cached cores: they fetch instructions through an
instruction cache that refills a whole line over a bus, and RISSP fetches one
word per cycle straight from the ROM port. The wrapper therefore contains a
small read-only bridge that turns the core's cache-refill bursts into
`imem_addr` / `imem_rdata` reads of the same ROM, one word per cycle. This
refill path is part of "the core" in the comparison and is reported as such.

All data accesses (accelerator registers and BRAM) are marked uncached /
non-idempotent in both cores, so every load and store reaches the AXI-Lite
port as one transaction, as on RISSP. The data cache is present in the core
but holds nothing in these tests.

Address map seen by the cores:

| region | range | Rocket | CVA6 |
| --- | --- | --- | --- |
| ROM (firmware) | 0x0000_0000 - 0x0000_7FFF | AXI4 mem port, cacheable, executable | cached + executable region |
| peripherals + BRAM | 0x4000_0000 - 0xCFFF_FFFF | AXI4 MMIO port, uncached | non-idempotent, uncached |

Reset vector 0x0 for both (RISSP starts at 0x0).

## 3. Rocket

- Source: chipyard 1.14.0 `generators/rocket-chip` (55bcad0f5).
- Core: `WithNSmallCores(1)` + `WithRV32`: RV32IMAC, no FPU, no VM, no BTB,
  4 KiB direct-mapped I$ and D$, 64-byte lines.
- System: a minimal rocket-chip subsystem (one tile, no boot ROM, no debug
  module, no PLIC, no bus error device on the ROM range). The CLINT stays if
  the tile needs it for `mtime`; firmware does not touch it. Reset vector is a
  top-level input tied to 0. Memory port (ROM) and MMIO port are AXI4 with
  32-bit data.
- Elaboration: a small Scala generator inside chipyard (sbt, CIRCT) writes
  SystemVerilog into `risp_soc_oss/rtl/cores/rocket/gen/`.
- Wrapper `rtl/cores/rocket/rissp_top_rocket.sv`: AXI4 mem port to ROM
  bridge; AXI4 MMIO port through pulp `axi_to_axi_lite` to `m_axi_*`.

## 4. CVA6

- The chipyard-pinned CVA6 (6000e32b, April 2021) is 64-bit only
  (`include/riscv_pkg.sv:31`, `localparam XLEN = 64`); the RV32I firmware
  cannot run on a 64-bit core (`lui` sign-extends 0xC0000000). So the core
  comes from upstream CVA6 v5.3.0 (2ef1c1b, 2025-02-03), the release with
  maintained RV32 configs, cloned to `risp_soc_oss/third_party/cva6`.
- Core: `cv32a6_imac_sv0` (RV32IMAC, no FPU) with the region rules of
  section 2. Default caches (16 KiB I$, 32 KiB D$, write-through).
- Wrapper `rtl/cores/cva6/rissp_top_cva6.sv`: the single AXI4 port (64-bit
  data) goes to a 64-to-32 data-width converter, then an address demux: ROM
  range to the ROM bridge, everything else to `axi_to_axi_lite`.

## 5. Results and how they are compared

Same metrics as RISSP / RV32I / Ibex (`RESULTS_3SOC.md`): verdict and golden
checks per test, accelerator core cycles (must be equal on every CPU), and
the PURE / FULL / END-TO-END windows measured on the AXI and BRAM signals.
Output: `RESULTS_5SOC.md`.

## 6. Risks

- Cold-start I$ misses add cycles inside the PURE windows; the firmware runs
  once per test, so the cached cores are measured cold. Reported as is.
- A sim-only `$display` at reset is the only addition; no NOP padding or
  firmware change.
- CVA6 issues loads to non-idempotent memory only at commit; that is its real
  behaviour on MMIO and stays in the numbers.
