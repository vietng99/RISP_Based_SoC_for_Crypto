# Vivado notes

The `create_project.tcl` scripts contain a few settings that are not obvious from the RTL.
Most of them fix an error seen when the projects were first built in Vivado 2025.2.

## All SoCs

**Module references and `` `include ``.** Vivado creates a module-reference cell only if
every file reached through `` `include `` is part of the project; otherwise
`create_bd_cell -reference cpu_core` fails with
`[filemgmt 56-591] Given include File '...' needs to be added to the project`.
The scripts add the included headers (Ibex, Rocket, CVA6) with file type
`Verilog Header`, so Vivado resolves them and does not compile them as separate units.

**One project per Vivado session.** Sourcing a `create_project.tcl` closes the open
project first. Sourcing it again opens the existing project instead of rebuilding it,
unless `core_soc_rebuild` is set.

## CVA6

**`instr_tracer` (simulation).** In `cva6.sv` the instruction tracer instance sits inside
a `// pragma translate_off` region. Vivado skips such regions when it builds the module
hierarchy, so `instr_tracer.sv` is left out of the compile order and xsim elaboration
fails with `Module <instr_tracer> not found`. The guard was changed from
`` `ifndef VERILATOR `` to `` `ifdef CVA6_INSTR_TRACER ``: the tracer is off by default
(as it already was in Verilator). It only writes a trace log and has no effect on the
results. Define `CVA6_INSTR_TRACER` on `sim_1` and add `instr_tracer.sv` to `sim_1` by
hand if you want the trace.

**`XSIM` on `sim_1` (CVA6 and Rocket).** xsim does not support `default disable iff`
(`[XSIM 43-3980]`). The pulp-platform axi sources already skip those assertions under
`` `ifndef XSIM ``, so the scripts define `XSIM` for simulation only.

**SRAM for synthesis.** `tc_sram_wrapper.sv` is a simulation model: its body is inside
`// synthesis translate_off`, so synthesis sees an empty module and implementation stops
with `[DRC INBB-3] Black Box Instances`. Synthesis uses the CVA6 FPGA wrapper instead
(`tc_sram_fpga_wrapper.sv` with `SyncSpRamBeNx64.sv`, inferred block RAM, macro
`FPGA_TARGET_XILINX`). The scripts mark the FPGA files `used_in_simulation false` and the
model `used_in_synthesis false`, so simulation keeps the model.

**`TARGET_VIVADO` for synthesis.** `common_cells/src/unread.sv` has a body only when
`TARGET_VIVADO` is defined; an empty module is again a black box. The define is passed to
synthesis only (`STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS`), because in simulation that body
would drive X onto the instance input.

**Critical warnings `[HDL 9-1206]` / `[HDL 9-3952]`.** About 370 of them appear when the
CVA6 project is created, in the fpnew, axi and common_cells sources (for example
`use of undefined macro 'FF'`). They come from the quick parser Vivado runs to display the
source hierarchy. Synthesis and xsim compile those files without errors.

## Cycle counts

The testbenches count cycles on the AXI4-Lite ports of the accelerators, so the bus
(`axi_interconnect_0`) is part of every figure, including the "core" figure of AES, which
starts when the CTRL write address reaches the slave. Measured with another interconnect
(for example a combinational crossbar in an RTL simulator), the same core can show one
cycle more or less.
