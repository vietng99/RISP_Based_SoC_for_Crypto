#!/usr/bin/env python3
"""[t-032] Package the six SoCs as Vivado 2024.2 block-design projects (paper Fig. 6).

Each <core>_soc/create_project.tcl builds design_1.bd the way the owner's SE-RISSP_AES_ULTRA
block design is built: clk_wiz_0, proc_sys_reset_0, axi_interconnect_0 (5 masters),
xlslice_0, blk_mem_gen_0 (instruction ROM, .coe), axi_bram_ctrl_0 + blk_mem_gen_1,
axi_uartlite_0, and the AES / SHA3 / RSA slaves. The CPU block (cpu_core, tools/bd) is the
only cell that differs between the six SoCs. CPU and accelerators enter the block design
as module references, so no packaged IP (and no family restriction) is involved.

Output: <out>/core_soc_bd/ and the same tree as <out>/core_soc_bd.zip is made by the caller.
Usage: python3 tools/pack_vivado_bd.py <out_dir>
"""
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pack_vivado as pv  # noqa: E402  (flist expansion, paths, part, Ibex patch)

OSS, PAPER, RISP_IP, FW_SRC = pv.OSS, pv.PAPER, pv.RISP_IP, pv.FW_SRC
BD_DIR = OSS / "tools/bd"
TB_SRC = PAPER / "RISP_SoC_6projects/RISP/hardware/testbench/rissp"
CORES = pv.CORES
TESTS = [  # set_test name -> (testbench, firmware .coe)
    ("aes_ecb", "tb_aes_ecb"), ("aes_cbc", "tb_aes_cbc"), ("aes_cfb", "tb_aes_cfb"),
    ("aes_ctr", "tb_aes_ctr"), ("sha3", "tb_sha3"), ("sha3_4", "tb_sha3_4"),
    ("sha3_16", "tb_sha3_16"), ("rsa2048", "tb_rsa2048"), ("rsa2048_fast", "tb_rsa2048"),
    ("rsa", "tb_rsa"),
]
# Files of the RTL SoC that the block design replaces with Xilinx IP or does not need.
SOC_ONLY = ("risp_soc_oss/rtl/soc/", "risp_soc_oss/rtl/mem/", "risp_soc_oss/rtl/periph/", "risp_soc_oss/rtl/bus/")
XBAR_ONLY = ("risp_soc_oss/third_party/axi/", "risp_soc_oss/third_party/common_cells/")
# Vivado makes a module reference only when every `include target is a project file
# ([filemgmt 56-591] on prim_util_get_scramble_params.svh, owner's 2025.2 run, t-034). For
# these cores each source that includes a header is shipped flattened (src_flat/<core>/),
# so the project reads no header at all.
FLATTEN = ("ibex", "cva6")
INC_RE = re.compile(r'^\s*`include\s+"([^"]+)"\s*(//.*)?$')
CPU_CELL = {"rissp_v2b": "rissp_v2b_0", "rissp": "rissp_top_0", "rv32i": "rv32i_0",
            "ibex": "ibex_core_0", "rocket": "rocket_0", "cva6": "cva6_0"}


def bd_sources(core):
    srcs, incs = [], []
    pv.expand(OSS / f"flist/{core}_soc.f", srcs, incs)
    keep = []
    for f in srcs:
        r = str(f.resolve().relative_to(PAPER))
        if r.startswith(SOC_ONLY):
            continue
        # the pulp xbar files are only the RTL SoC's interconnect; Rocket and CVA6 use
        # some of them inside their wrappers, so they stay for those two
        if r.startswith(XBAR_ONLY) and core not in ("rocket", "cva6"):
            continue
        keep.append(f)
    keep.append(BD_DIR / f"cpu_core_{core}.v")
    incs = [d for d in incs if core in ("rocket", "cva6") or not str(d.resolve().relative_to(PAPER)).startswith(XBAR_ONLY)]
    return keep, incs


def flatten(src, incs, missing):
    """Text of src with each `include "x" line replaced by the text of x, recursively. x is
    looked up in src's directory, then in incs in order. A header found nowhere stays as a
    comment and is reported in missing (it sits under an `ifdef the build does not set)."""
    out = []
    for line in Path(src).read_text().splitlines(keepends=True):
        m = INC_RE.match(line)
        if not m:
            out.append(line)
            continue
        name = m.group(1)
        hit = next((d / name for d in [Path(src).parent, *incs] if (d / name).is_file()), None)
        if hit is None:
            missing.add(name)
            out.append(f"// [core_soc flatten] not found, left out: {line.strip()}\n")
            continue
        body = flatten(hit, incs, missing)
        out.append(f"// [core_soc flatten] begin {name}\n{body}")
        out.append(("" if body.endswith("\n") else "\n") + f"// [core_soc flatten] end {name}\n")
    return "".join(out)


def has_include(f):
    return any(INC_RE.match(l) for l in Path(f).read_text().splitlines())


TCL = r'''# [core_soc block design] Creates (first run) or opens the @NAME@ Vivado project.
# design_1.bd follows the owner's SE-RISSP_AES_ULTRA block design (paper Fig. 6); only
# the CPU block (@CELL@, module cpu_core) differs between the six SoCs.
# Run in the Vivado Tcl console:  source <path>/@NAME@/create_project.tcl
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here ..]]
set ::core_soc_root $root
source [file join $root scripts set_test.tcl]
set xpr  [file join $here @NAME@.xpr]
set done [file join $here @NAME@.ready]
# One project per Vivado session: close whatever is open (another SoC, or this one).
if {[llength [get_projects -quiet]] > 0} { close_project }
if {[file exists $xpr] && [file exists $done]} {
    open_project $xpr
    puts "@NAME@: opened. Switch test with: set_test <name>  (list: set_test help)"
    return
}
if {[file exists $xpr] && ![info exists ::core_soc_rebuild]} {
    # The project exists but this script did not finish it (it stopped half way, or an
    # older package made it). Open it unchanged; rebuilding deletes its runs and edits.
    open_project $xpr
    puts "@NAME@: opened an existing project that has no @NAME@.ready marker."
    puts "If its block design is incomplete, rebuild it:  set core_soc_rebuild 1; source [info script]"
    return
}
# Rebuild requested (or first run): remove generated project files, keep the scripts.
foreach f [glob -nocomplain [file join $here @NAME@.*]] { file delete -force $f }
unset -nocomplain ::core_soc_rebuild

# ---------------- part ----------------
# Default @PART@ (ZCU102). Another installed part: set core_soc_part <part> before sourcing.
if {![info exists ::core_soc_part]} { set ::core_soc_part @PART@ }
if {[llength [get_parts -quiet $::core_soc_part]] == 0} {
    puts "ERROR: part $::core_soc_part is not installed in this Vivado."
    puts "Fix: Help > Add Design Tools or Devices, or: set core_soc_part <installed part>"
    return
}
create_project -force @NAME@ $here -part $::core_soc_part
set board [lindex [lsort [get_board_parts -quiet *@BOARD@*]] end]
if {$board ne "" && $::core_soc_part eq "@PART@"} { set_property board_part $board [current_project] }
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
# Module references write into <project>.gen/sources_1; create it up front.
file mkdir [file join $here @NAME@.gen sources_1]
set arch [get_property ARCHITECTURE [get_parts $::core_soc_part]]
set defs [list @DEFS@]
if {[lsearch -exact {zynq artix7 kintex7 virtex7 spartan7 azynq aartix7 akintex7 qzynq qartix7 qkintex7 qvirtex7} $arch] < 0} {
    lappend defs CORE_SOC_ULTRASCALE
}

# ---------------- RTL: CPU, accelerators, cpu_core wrapper ----------------
add_files -norecurse -fileset sources_1 [list \
@SOURCES@ \
]
set incs [list \
@INCS@ \
]
if {[llength $incs] > 0} {
    set_property include_dirs $incs [get_filesets sources_1]
    set_property include_dirs $incs [get_filesets sim_1]
}
set_property verilog_define $defs [get_filesets sources_1]
set_property verilog_define $defs [get_filesets sim_1]
add_files -norecurse -fileset constrs_1 [file join $root constrs core_soc_bd.xdc]
update_compile_order -fileset sources_1

# ---------------- block design design_1 ----------------
create_bd_design design_1

create_bd_port -dir I -type clk -freq_hz 100000000 clk_in1_0
create_bd_port -dir I -type rst reset_0
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports reset_0]
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:uart_rtl:1.0 UART_0

create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {40.000}] [get_bd_cells clk_wiz_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {5}] [get_bd_cells axi_interconnect_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0
set_property -dict [list CONFIG.DIN_WIDTH {32} CONFIG.DIN_FROM {14} CONFIG.DIN_TO {2}] [get_bd_cells xlslice_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0
set_property -dict [list \
    CONFIG.use_bram_block {Stand_Alone} \
    CONFIG.Memory_Type {Single_Port_ROM} \
    CONFIG.Enable_32bit_Address {false} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Read_Width_A {32} \
    CONFIG.Write_Depth_A {8192} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Load_Init_File {true} \
    CONFIG.Coe_File [file join $root firmware aes_ecb.coe] \
    CONFIG.Fill_Remaining_Memory_Locations {true} \
] [get_bd_cells blk_mem_gen_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property -dict [list CONFIG.SINGLE_PORT_BRAM {1} CONFIG.SUPPORTS_NARROW_BURST {0}] [get_bd_cells axi_bram_ctrl_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_1
set_property -dict [list CONFIG.Enable_32bit_Address {true}] [get_bd_cells blk_mem_gen_1]
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0

create_bd_cell -type module -reference cpu_core @CELL@
create_bd_cell -type module -reference aes_axi_slave aes_axi_slave_0
create_bd_cell -type module -reference SHA3_hardware_new SHA3_hardware_new_0
create_bd_cell -type module -reference RSA_mark03 RSA_mark03_0

# interface pin by name, case-insensitive (module references name inferred interfaces
# after the port prefix, e.g. s01_axi)
proc core_soc_ipin {cell name} {
    foreach q [get_bd_intf_pins -quiet -of_objects [get_bd_cells $cell]] {
        if {[string equal -nocase [get_property NAME $q] $name]} { return $q }
    }
    error "core_soc: interface pin $name not found on $cell"
}

connect_bd_intf_net [core_soc_ipin @CELL@ m_axi]                  [get_bd_intf_pins axi_interconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [core_soc_ipin aes_axi_slave_0 S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] [core_soc_ipin SHA3_hardware_new_0 S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M02_AXI] [core_soc_ipin RSA_mark03_0 S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M03_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M04_AXI] [get_bd_intf_pins axi_uartlite_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_1/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_ports UART_0] [get_bd_intf_pins axi_uartlite_0/UART]

connect_bd_net [get_bd_ports clk_in1_0] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_ports reset_0] [get_bd_pins clk_wiz_0/reset] [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] \
    [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
    [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] \
    [get_bd_pins axi_interconnect_0/M02_ACLK] [get_bd_pins axi_interconnect_0/M03_ACLK] \
    [get_bd_pins axi_interconnect_0/M04_ACLK] \
    [get_bd_pins @CELL@/clk] [get_bd_pins blk_mem_gen_0/clka] \
    [get_bd_pins aes_axi_slave_0/S_AXI_ACLK] [get_bd_pins SHA3_hardware_new_0/s01_axi_aclk] \
    [get_bd_pins RSA_mark03_0/s00_axi_aclk] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] \
    [get_bd_pins axi_uartlite_0/s_axi_aclk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] \
    [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/M01_ARESETN] \
    [get_bd_pins axi_interconnect_0/M02_ARESETN] [get_bd_pins axi_interconnect_0/M03_ARESETN] \
    [get_bd_pins axi_interconnect_0/M04_ARESETN] \
    [get_bd_pins @CELL@/rst_n] \
    [get_bd_pins aes_axi_slave_0/S_AXI_ARESETN] [get_bd_pins SHA3_hardware_new_0/s01_axi_aresetn] \
    [get_bd_pins RSA_mark03_0/s00_axi_aresetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] \
    [get_bd_pins axi_uartlite_0/s_axi_aresetn]
connect_bd_net [get_bd_pins @CELL@/imem_addr] [get_bd_pins xlslice_0/Din]
connect_bd_net [get_bd_pins xlslice_0/Dout] [get_bd_pins blk_mem_gen_0/addra]
connect_bd_net [get_bd_pins blk_mem_gen_0/douta] [get_bd_pins @CELL@/imem_rdata]

# ---------------- address map (as in SE-RISSP_AES_ULTRA) ----------------
set space [get_bd_addr_spaces -of_objects [get_bd_cells @CELL@]]
foreach {pin offset range} [list \
    [core_soc_ipin aes_axi_slave_0 S_AXI]         0x40000000 16K \
    [core_soc_ipin SHA3_hardware_new_0 S01_AXI]   0x44000000 64K \
    [core_soc_ipin RSA_mark03_0 S00_AXI]          0x48000000 64K \
    [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]      0xC0000000 8K  \
    [get_bd_intf_pins axi_uartlite_0/S_AXI]       0x40600000 64K ] {
    set seg [lindex [get_bd_addr_segs -of_objects $pin] 0]
    if {[catch {assign_bd_address -offset $offset -range $range -target_address_space $space $seg -force} msg]} {
        puts "WARNING: core_soc: $seg with range $range failed ($msg); using its own range"
        assign_bd_address -offset $offset -target_address_space $space $seg -force
    }
}

validate_bd_design
save_bd_design
set bd_file [get_files design_1.bd]
# Global synthesis: the CPU and accelerators synthesize with the top, under the project
# defines (CORE_SOC_ULTRASCALE, PRINTF_COND).
set_property synth_checkpoint_mode None $bd_file
generate_target all $bd_file
add_files -norecurse -fileset sources_1 [make_wrapper -files $bd_file -top]
set_property top design_1_wrapper [get_filesets sources_1]

# ---------------- simulation: the owner's testbenches ----------------
add_files -norecurse -fileset sim_1 [list \
@TBS@ \
]
set_property top tb_aes_ecb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
open_bd_design $bd_file
close [open $done w]
puts "@NAME@: project ready ($xpr). Test loaded: aes_ecb. Switch test with: set_test <name>"
'''

SET_TEST = r'''# [core_soc block design] set_test <name>: load firmware/<name>.coe into blk_mem_gen_0,
# regenerate the block design outputs and make the matching testbench the simulation top.
# Usage in the Tcl console of an open core_soc project:
#   source <package>/scripts/set_test.tcl      (create_project.tcl already does this)
#   set_test sha3_16
if {![info exists ::core_soc_root]} {
    set ::core_soc_root [file normalize [file join [file dirname [info script]] ..]]
}
array set ::core_soc_tests {
@MAP@
}
proc set_test {{name help}} {
    if {![info exists ::core_soc_tests($name)]} {
        puts "set_test <name>, name one of: [lsort [array names ::core_soc_tests]]"
        return
    }
    set tb  $::core_soc_tests($name)
    set coe [file join $::core_soc_root firmware $name.coe]
    set bd  [get_files design_1.bd]
    open_bd_design $bd
    set_property CONFIG.Coe_File $coe [get_bd_cells blk_mem_gen_0]
    save_bd_design
    reset_target all $bd
    generate_target all $bd
    set_property top $tb [get_filesets sim_1]
    update_compile_order -fileset sim_1
    puts "core_soc: firmware $name.coe in blk_mem_gen_0, simulation top $tb. Run Simulation > Run Behavioral Simulation."
}
'''


def main(out):
    pkg = Path(out) / "core_soc_bd"
    if pkg.exists():
        shutil.rmtree(pkg)
    for d in ("firmware", "tb", "constrs", "scripts"):
        (pkg / d).mkdir(parents=True)

    for name, _ in TESTS:
        shutil.copy(FW_SRC / f"{name}.coe", pkg / f"firmware/{name}.coe")
    tbs = sorted({tb for _, tb in TESTS})
    for tb in tbs:
        shutil.copy(TB_SRC / f"{tb}.v", pkg / f"tb/{tb}.v")
    (pkg / "constrs/core_soc_bd.xdc").write_text(
        "# clk_wiz_0 constrains its own 100 MHz input and derives clk_out1 (40 MHz).\n"
        "# For fmax: change clk_wiz_0 CLKOUT1_REQUESTED_OUT_FREQ, re-run implementation, read WNS.\n"
        "set_false_path -from [get_ports reset_0]\n"
        "set_false_path -from [get_ports UART_0_rxd]\n"
        "set_false_path -to [get_ports UART_0_txd]\n")
    (pkg / "scripts/set_test.tcl").write_text(SET_TEST.replace(
        "@MAP@", "\n".join(f"    {n} {tb}" for n, tb in TESTS)))
    shutil.copy(Path(__file__).with_name("core_soc_bd_README_VI.md"), pkg / "README_VI.md")

    copied = set()
    for core in CORES:
        srcs, incs = bd_sources(core)
        for f in srcs:
            if f in copied:
                continue
            dst = pkg / pv.rel(f)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(f, dst)
            copied.add(f)
            if f.name == "ibex_axi_top_combined.sv":
                pv.patch_ibex(dst)
        for d in incs:
            for f in d.rglob("*"):
                if f.is_file() and f.suffix in (".svh", ".vh", ".sv", ".v", ".h") and f not in copied:
                    dst = pkg / pv.rel(f)
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy(f, dst)
                    copied.add(f)
        names = [pv.rel(f) for f in srcs]
        if core in FLATTEN:
            missing = set()
            for i, f in enumerate(srcs):
                if has_include(pkg / names[i]):
                    flat = Path("src_flat") / core / names[i].relative_to("src")
                    (pkg / flat).parent.mkdir(parents=True, exist_ok=True)
                    # flatten the package copy, so the Ibex BUFGCE patch is kept
                    (pkg / flat).write_text(flatten(pkg / names[i], [pkg / pv.rel(d) for d in incs], missing))
                    names[i] = flat
            print(f"{core}: flattened {sum(n.parts[0] == 'src_flat' for n in names)} sources;"
                  f" headers not found (left out): {sorted(missing)}")
            incs = []
        name = f"{core}_soc"
        (pkg / name).mkdir()
        tcl = (TCL.replace("@NAME@", name).replace("@CELL@", CPU_CELL[core])
               .replace("@PART@", pv.PART).replace("@BOARD@", pv.BOARD)
               .replace("@DEFS@", " ".join(pv.DEFINES.get(core, [])))
               .replace("@SOURCES@", pv.tcl_list(names))
               .replace("@INCS@", pv.tcl_list([pv.rel(d) for d in incs]))
               .replace("@TBS@", pv.tcl_list([Path("tb") / f"{tb}.v" for tb in tbs])))
        (pkg / name / "create_project.tcl").write_text(tcl)
        (pkg / f"filelists").mkdir(exist_ok=True)
        (pkg / f"filelists/{name}.f").write_text(
            "".join(f"+incdir+{pv.rel(d).as_posix()}\n" for d in incs)
            + "".join(f"+define+{d}\n" for d in pv.DEFINES.get(core, []))
            + "".join(f"{n.as_posix()}\n" for n in names))
        print(f"{name}: {len(srcs)} sources, {len(incs)} include dirs, CPU cell {CPU_CELL[core]}")
    print(f"files copied: {len(copied)}")


if __name__ == "__main__":
    main(sys.argv[1])
