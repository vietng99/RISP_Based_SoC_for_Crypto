# RISSP v2: the RISSP CPU cut down for the crypto firmware

Date: 2026-10-15. Steps: (t-019 baseline, t-020 design, t-021 build, t-022 verify).
RTL: `rtl/cores/rissp_v2/rissp_top_v2.v` (module `rissp_top`, same ports as
`RISP/ip_repo/cpu_rissp/src/rissp_top.v`). The SoC (`rtl/soc/design_1.sv`), the
accelerators, the bus, the testbenches and the firmware hex files are unchanged.
`RISP/ip_repo` is not modified.

## 1. What the firmware needs

Disassembly of the 10 firmware images in `RISP/hardware/firmware` (t-019):

- 9 distinct machine instructions: `sw` 579, `addi` 508, `lui` 503, `lw` 179,
  `xor` 149, `jal` 10, `beq` 10, `andi` 10, `blt` 2.
- Every `jal` has rd = x0 (the `j` pseudo-instruction). No instruction writes x0.
- Registers used: x0-x13 and x18-x31.

The original RISSP core decodes 35 instructions (`start.S:2`) and spends most of
its time in the bus master: about 6 cycles per `sw` and 5 per `lw`
(`logs/summary.txt`, tb_aes_ecb KEY=25 to PT=57 for four lui+addi+sw groups).

## 2. Design

| Part | cpu_rissp (original) | rissp_v2 |
|---|---|---|
| Instructions | 35 (RV32I subset) | 9: LUI ADDI ANDI XOR LW SW BEQ BLT JAL; any other opcode is undefined |
| Decode | full opcode/funct3 compare per type block | only the bits that separate the 9: insn[6,5,4,2], funct3 bit 12 (ADDI/ANDI) and bit 14 (BEQ/BLT) |
| ALU | adder/subtractor, barrel shifter, signed and unsigned comparators, separate store-address adder | one 32-bit adder: LUI = 0 + imm_u, ADDI/LW = a + imm_i, SW = a + imm_s, BEQ/BLT = a + ~b + 1; BLT from the adder's sign with the overflow rule; BEQ from ~|(a ^ b), shared with XOR |
| Register file | 32x32 LUTRAM, read ports muxed to 0 for x0 | 32x32 LUTRAM, writes to x0 dropped, array starts at 0 (FPGA init), no x0 read mux |
| PC | 32 bits | 13 bits of word address (`PC_W`, the 8192-word ROM; design_1 uses imem_addr[14:2]) |
| JAL | writes pc+4 | `JAL_LINK=0` (default): rd ignored, the firmware only has jal x0; `JAL_LINK=1` restores the link (+15 LUT, +4 CARRY4) |
| Bus master | FSM IDLE -> WRITE/READ -> DONE with registered AW/W/AR, address, data and read data | AW/W/AR valid come straight from the decoded instruction in the decode cycle; 4 flags (aw_done, w_done, ar_done, b_pend); BREADY=RREADY=1 |
| Store | CPU waits for B | retires when AW and W are accepted; the next load/store waits for the B response (ordering kept) |
| Load | registered read data, then DONE cycle | RDATA goes to the register file in the cycle RVALID arrives |

AXI4-Lite rules kept: a VALID never depends on the READY of its own channel;
once raised it stays high with stable address/data until the handshake (the
CPU is held, the ROM re-reads the same PC and the register file is not written
while held); AW and W are tracked separately; all VALIDs are low in reset.

## 3. Results

### Area (Yosys 0.69 `synth_xilinx -family xc7 -flatten`, CPU block only)

| CPU block | LUT | LUTRAM (RAM32M) | FF | CARRY4 | MUXF7/8 | Longest path (cells) | Source |
|---|---:|---:|---:|---:|---:|---:|---|
| RISSP original (`cpu_rissp`) | 1,074 | 12 | 173 | 65 | 0 | 411 | `logs/synth-rissp_orig-stat.txt` |
| **RISSP v2** (`JAL_LINK=0`) | **204** | **12** | **17** | **13** | 2 | 194 | `logs/synth-rissp_v2-stat.txt` |
| RISSP v2 (`JAL_LINK=1`) | 219 | 12 | 17 | 17 | 2 | - | variant run, t-021 |
| RV32I (`rv32i_ultra`, core + AXI master) | 2,347 | 0 | 1,665 | 51 | 64 | - | `logs/synth-rv32i-stat.txt` |

v2 against the original: LUT -81%, FF -90%, CARRY4 -80%, longest path -53%.
The 12 RAM32M (register file) are the same in both.

Ibex, Rocket and CVA6 could not be sized here: the Yosys SystemVerilog
frontend stops on `ibex_axi_top_combined.sv:342` and
`rocket/gen/TLToAXI4.sv:113` (`logs/synth-ibex.log`, `logs/synth-rocket.log`),
and there is no Vivado on this host.

### Cycles (Verilator, SoC clock cycles, PURE = CPU + bus + accelerator)

All 9 usable testbenches PASS on v2 (AES 4/4 checks, SHA3 9/9, RSA 9/9);
`tb_rsa` (old 32-bit RSA map) times out on every CPU as before.
Full tables: `logs/results-6soc.md`; v2 summary: `logs/summary-rissp_v2.txt`.

| Test | RISSP | **RISSP v2** | RV32I | Ibex | Rocket | CVA6 | v2 / RISSP |
|---|---:|---:|---:|---:|---:|---:|---:|
| AES-128 ECB | 75 | **49** | 73 | 70 | 134 | 109 | 0.653 |
| AES-128 CBC/CFB/CTR | 107 | **65** | 105 | 102 | 166 | 144 | 0.607 |
| SHA3-256 1 block | 427 | **230** | 431 | 426 | 756 | 517 | 0.539 |
| SHA3-256 4 block | 1,553 | **861** | 1,689 | 1,684 | 2,176 | 1,741 | 0.554 |
| SHA3-256 16 block | 6,041 | **3,309** | 6,585 | 6,580 | 8,296 | 6,637 | 0.548 |
| RSA-2048 CTRL=0x1 | 320,714 | **320,328** | 320,779 | 320,720 | 321,615 | 321,228 | 0.999 |
| RSA-2048 CTRL=0x3 | 156,515 | **156,128** | 156,579 | 156,515 | 157,407 | 157,023 | 0.998 |

v2 is the fastest of the six CPUs on every test. Accelerator core cycles are
unchanged (AES 17, SHA3 29, RSA 319,814 / 155,611).

### Where the remaining cycles go

Trace of tb_aes_ecb (`logs/rissp_v2-dbg-aes.log`, built with
`+define+RISSP_V2_TRACE`):

- `sw`: 2 cycles. AW is accepted in the decode cycle; the pulp `axi_lite_xbar`
  accepts W one cycle after AW (the W route follows the AW decision).
- `lw`: 3 cycles. AR is accepted in the decode cycle; the accelerator slaves
  raise RVALID two cycles later.
- Two stores to the same slave are at least 4 cycles apart: the slave takes a
  new AW only after its B handshake, which comes two cycles after W.

These limits sit in the slaves and the interconnect, which are the same for
every CPU. A W buffer in the CPU (retire a store on AW alone) would not shorten
back-to-back stores for that reason, so it was left out.

## 4. Limits

- Domain-specific: v2 runs only code built from the 9 instructions, and JAL
  with rd != x0 needs `JAL_LINK=1`. Any other opcode does something undefined.
- x0 relies on the FPGA register-file init (the `initial` block becomes the
  LUTRAM INIT). An ASIC build would need the x0 read mux back.
- The AXI request is combinational from the instruction ROM output and the
  register file, and the slave READY feeds the PC hold. With the Vivado
  `axi_interconnect` this path is different; fmax and power must come from a
  Vivado implementation run. The testbenches print Mbps/W with their fixed
  `POWER_W = 0.407`, which is the old RISSP SoC figure.
- Area numbers are Yosys mappings, a proxy for Vivado; both cores were mapped
  by the same flow.

## 5. Reproduce

```
cd risp_soc_oss
export PATH=<chipyard>/.conda-env/bin:$PATH
make -f mk/core.mk CORE=rissp_v2 -j3 tbs
make -f mk/core.mk CORE=rissp_v2 run-all          # logs/summary-rissp_v2.txt
.tools/yosys-env/bin/yosys -q synth/rissp_core_v2.ys    # logs/synth-rissp_v2-stat.txt
.tools/yosys-env/bin/yosys -q synth/rissp_core_orig.ys  # logs/synth-rissp_orig-stat.txt
```

## 6. RISSP v2b: the same core as one block per instruction type (t-027, t-028)

Date: 2026-10-15. RTL: `rtl/cores/rissp_v2b/` (12 files, module `rissp_top`, same
ports as v2 and as `RISP/ip_repo/cpu_rissp/src/rissp_top.v`). File list:
`flist/rissp_v2b_soc.f`. v2 (`rtl/cores/rissp_v2/rissp_top_v2.v`) is kept as the
flat reference.

v2b follows the structure of the paper's Fig. 1 and of `cpu_rissp`: a fetch stage, a
register file, one hardware instruction block per type, and `modular_ex`, which
routes each opcode to its block and muxes the results.

| File | Role |
|---|---|
| `rissp_top.v` | top; `hold = ~rst_n \| bus stall \| illegal` |
| `fetch_stage.v` | PC (PC_W word bits) and the one PC adder: +1 word, or + the block's offset on a jump |
| `register_file.v` | 32x32 LUTRAM, writes to x0 dropped, zero init |
| `u_type_block.v` | LUI |
| `i_type_block.v` | ADDI, ANDI, LW |
| `r_type_block.v` | XOR |
| `s_type_block.v` | SW |
| `b_type_block.v` | BEQ, BLT |
| `j_type_block.v` | JAL (link adder only with `JAL_LINK=1`) |
| `alu_adder.v` | the shared 32-bit adder (I, S and B blocks), as `cpu_rissp` shares `alu_adder` |
| `modular_ex.v` | routing on opcode bits, legality check, block instances, result mux |
| `axi_rissp_master.v` | the v2 AXI4-Lite master, unchanged logic |

New in v2b: the `ILLEGAL_HALT` option (default 0, owner choice 2026-10-15, t-028). With 1, any instruction other than the nine
(opcode, funct3, and funct7 for XOR all checked; with `JAL_LINK=0` also JAL with
rd != x0) holds the core: no register write, no bus request, PC stays, until reset.
With 0 (as in v2) such an instruction runs through whatever datapath its routing bits select
(for example `add`, `sub` and `or` execute as `xor`).

### Results

| Check | v2 | v2b | Source |
|---|---:|---:|---|
| Testbenches PASS (AES 4, SHA3 3, RSA-2048 2) | 9/9 | 9/9 | `logs/summary-rissp_v2b.txt` |
| Cycles, every column of every test | - | identical to v2 | `diff logs/snap-1015/summary-rissp_v2.txt logs/summary-rissp_v2b.txt` prints nothing |
| LUT (Yosys xc7, CPU only) | 204 | **202** (`ILLEGAL_HALT=0`, default), 214 (`ILLEGAL_HALT=1`) | `logs/synth-rissp_v2b-stat.txt`, `logs/synth-rissp_v2b-illegal1-stat.txt` |
| FF / CARRY4 / RAM32M / MUXF7 | 17 / 13 / 12 / 2 | 17 / 13 / 12 / 2 | same |
| Illegal `add x2,x1,x1` after `addi x1,x0,5` (`ILLEGAL_HALT=1`) | runs as xor | halts at word 1, x2 not written, no AW | `tb/tb_rissp_v2b_illegal.sv`, `logs/rissp_v2b-illegal-run.log` |
| Legal `xor x2,x1,x1` in the same place | - | runs, x2 = 0, `sw` issues one AW, reaches word 3 | same |

With the default the block structure is 2 LUTs smaller than v2 (202 vs 204); the
illegal-instruction check costs 12. The LUT count depends on ABC's mapping of
equivalent RTL: with the result mux written `is_lui ? u_rd : is_op ? r_rd : ...` the
same logic maps to 212 LUT; the order `is_op ? r_rd : is_lui ? u_rd : ...` gives 202
and is the one in `modular_ex.v`. Read differences of a few LUTs as mapping noise. `tb_rsa` (old 32-bit RSA map) times out as on every CPU.
Verilator reports the same UNOPTFLAT on the bus master `go` signal for v2 and
v2b (a signal-level path through `axi_lite_xbar`); the tests pass.

### Reproduce

```
cd risp_soc_oss
export PATH=<chipyard>/.conda-env/bin:$PATH
make -f mk/core.mk CORE=rissp_v2b -j4 tbs run-all       # logs/summary-rissp_v2b.txt
diff logs/snap-1015/summary-rissp_v2.txt logs/summary-rissp_v2b.txt
.tools/yosys-env/bin/yosys -q synth/rissp_core_v2b.ys            # logs/synth-rissp_v2b-stat.txt
.tools/yosys-env/bin/yosys -q synth/rissp_core_v2b_illegal1.ys   # logs/synth-rissp_v2b-illegal1-stat.txt
verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style --top-module tb_rissp_v2b_illegal \
  +define+SECOND="32'h00108133" tb/tb_rissp_v2b_illegal.sv rtl/cores/rissp_v2b/*.v -Mdir build/ill -o sim && build/ill/sim
```

### Area per block (hierarchy kept)

`synth/rissp_core_v2b_hier.ys` runs the same Yosys flow without `-flatten`
(`logs/synth-rissp_v2b-hier-stat.txt`). Local LUTs per module: modular_ex 148
(routing, legality, result and operand muxes), alu_adder 32 (+9 CARRY4), i_type_block 32,
r_type_block 32, fetch_stage 26 (+13 FF, 4 CARRY4), b_type_block 24, axi_rissp_master 12
(+4 FF), rissp_top 2, register_file 1 (+12 RAM32M); u_type_block, s_type_block and
j_type_block are 0 (wiring only: imm_u, imm_s, imm_j). Total 309 LUT with the module
boundaries kept, against 202 flattened: the synthesizer merges the block results into
the same LUTs as the result mux only when it may optimize across modules. Report the
flattened number as the core's area; the per-block table only explains where it goes.
In Vivado the default `-flatten_hierarchy rebuilt` dissolves the wiring-only and
mux-merged blocks the same way, so the implemented netlist shows mex and adder only.
