#!/usr/bin/env python3
"""[t-029] Package the six RTL SoCs as Vivado 2024.2 projects.

Output: <out>/core_soc_vivado/ with
  src/...                    every RTL file of the six SoCs (paths mirror this repo)
  firmware/<test>.mem/.coe   one firmware image per test case
  tb/<tb>.v                  testbenches, each with its firmware preset (IMEM_INIT)
  constrs/core_soc.xdc       40 MHz clock on clk_in1_0
  <core>_soc/create_project.tcl, open_<core>_soc.bat, open_<core>_soc.sh
  filelists/<core>_soc.f     the same sources as a plain file list (used by the check)

Usage: python3 tools/pack_vivado.py <out_dir>
"""
import re
import shutil
import sys
from pathlib import Path

OSS = Path(__file__).resolve().parents[1]                  # risp_soc_oss
PAPER = OSS.parent                                         # paper root
RISP_IP = PAPER / "RISP_SoC_6projects/RISP/ip_repo"
FW_SRC = PAPER / "RISP_SoC_6projects/RISP/hardware/firmware"
PART = "xczu9eg-ffvb1156-2-e"   # ZCU102 (Zynq UltraScale+); override with core_soc_part
BOARD = "zcu102"

CORES = ["rissp_v2b", "rissp", "rv32i", "ibex", "rocket", "cva6"]
TESTS = [  # (testbench module, firmware image)
    ("tb_aes_ecb", "aes_ecb"), ("tb_aes_cbc", "aes_cbc"), ("tb_aes_cfb", "aes_cfb"),
    ("tb_aes_ctr", "aes_ctr"), ("tb_sha3", "sha3"), ("tb_sha3_4", "sha3_4"),
    ("tb_sha3_16", "sha3_16"), ("tb_rsa2048", "rsa2048"), ("tb_rsa2048_fast", "rsa2048_fast"),
    ("tb_rsa", "rsa"),
]
# Verilator-only files and their Vivado equivalents (None = drop, Vivado has the primitive).
SWAP = {
    OSS / "rtl/patched/RSA_core.v": RISP_IP / "acc_rsa/src/RSA_core.v",
    OSS / "rtl/patched_ibex/xilinx_clkbuf_models.v": None,
}
DEFINES = {"rocket": ["PRINTF_COND=0"]}


def expand(path, srcs, incs):
    for raw in Path(path).read_text().splitlines():
        line = raw.split("//")[0].strip()
        if not line:
            continue
        line = line.replace("${RISP_OSS}", str(OSS)).replace("${RISP_IP}", str(RISP_IP))
        if line.startswith("-f"):
            expand(line[2:].strip(), srcs, incs)
        elif line.startswith("+incdir+"):
            d = Path(line[len("+incdir+"):])
            if d not in incs:
                incs.append(d)
        elif line.startswith(("+", "-")):
            raise SystemExit(f"unhandled flist option: {line} in {path}")
        else:
            f = Path(line)
            f = SWAP.get(f, f)
            if f is not None and f not in srcs:
                srcs.append(f)


def patch_ibex(path):
    """BUFGCE SIM_DEVICE must name the device family: 7SERIES or ULTRASCALE_PLUS."""
    text = path.read_text()
    old = '      BUFGCE #(\n        .SIM_DEVICE("7SERIES")\n      ) u_bufgce ('
    new = ('      BUFGCE #(\n'
           '`ifdef CORE_SOC_ULTRASCALE  // [core_soc package] set by create_project.tcl from the part\n'
           '        .SIM_DEVICE("ULTRASCALE_PLUS")\n'
           '`else\n'
           '        .SIM_DEVICE("7SERIES")\n'
           '`endif\n'
           '      ) u_bufgce (')
    assert text.count(old) == 1, path
    path.write_text(text.replace(old, new))


def rel(p):
    return Path("src") / Path(p).resolve().relative_to(PAPER)


def tcl_list(items):
    # one item per line; inside [list ...] every line but the last needs the continuation backslash
    return " \\\n".join(f'    [file join $root {{{i.as_posix()}}}]' for i in items)


def main(out):
    pkg = Path(out) / "core_soc_vivado"
    if pkg.exists():
        shutil.rmtree(pkg)
    for d in ("firmware", "tb", "constrs", "filelists"):
        (pkg / d).mkdir(parents=True)

    # firmware: .mem for $readmemh (Vivado copies .mem into the xsim run directory), .coe kept for blk_mem_gen
    for _, fw in TESTS:
        shutil.copy(FW_SRC / f"{fw}.hex", pkg / f"firmware/{fw}.mem")
        shutil.copy(FW_SRC / f"{fw}.coe", pkg / f"firmware/{fw}.coe")

    # testbenches: the RISSP testbenches as adapted for this repo (build/tb), firmware preset per test
    for tb, fw in TESTS:
        base = "tb_rsa2048" if tb == "tb_rsa2048_fast" else tb
        text = (OSS / f"build/tb/{base}.v").read_text()
        if tb != base:
            text, n = re.subn(rf"\bmodule {base};", f"module {tb};", text)
            assert n == 1, tb
        text, n = re.subn(r"design_1_wrapper dut \(",
                          f'design_1_wrapper #(.IMEM_INIT("{fw}.mem")) dut (', text)
        assert n == 1, tb
        header = (f"// [core_soc package] firmware preset: {fw}.mem (firmware/{fw}.coe is the same image for blk_mem_gen).\n")
        (pkg / f"tb/{tb}.v").write_text(header + text)

    (pkg / "constrs/core_soc.xdc").write_text(
        "# 40 MHz SoC clock, as clk_wiz_0 clk_out1 in the board design (the RTL SoC has no MMCM).\n"
        "# For fmax: lower the period, re-run implementation, read WNS.\n"
        "create_clock -period 25.000 -name soc_clk [get_ports clk_in1_0]\n"
        "set_false_path -from [get_ports reset_0]\n"
        "set_false_path -from [get_ports UART_0_rxd]\n"
        "set_false_path -to [get_ports UART_0_txd]\n")

    copied = set()
    for core in CORES:
        srcs, incs = [], []
        expand(OSS / f"flist/{core}_soc.f", srcs, incs)
        for f in srcs:
            if f not in copied:
                dst = pkg / rel(f)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(f, dst)
                copied.add(f)
                if f.name == "ibex_axi_top_combined.sv":
                    patch_ibex(dst)
        for d in incs:
            for f in d.rglob("*"):
                if f.is_file() and f.suffix in (".svh", ".vh", ".sv", ".v", ".h") and f not in copied:
                    dst = pkg / rel(f)
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy(f, dst)
                    copied.add(f)

        name = f"{core}_soc"
        defs = DEFINES.get(core, [])
        (pkg / f"filelists/{name}.f").write_text(
            "".join(f"+incdir+{rel(d).as_posix()}\n" for d in incs)
            + "".join(f"+define+{d}\n" for d in defs)
            + "".join(f"{rel(f).as_posix()}\n" for f in srcs))

        pdir = pkg / name
        pdir.mkdir()
        tbs = [Path("tb") / f"{tb}.v" for tb, _ in TESTS]
        mems = [Path("firmware") / f"{fw}.mem" for _, fw in TESTS]
        (pdir / "create_project.tcl").write_text(f"""# [core_soc package] Creates (first run) or opens the {name} Vivado project.
# Vivado 2024.2, part {PART}. Run: open_{name}.bat (Windows), open_{name}.sh (Linux),
# or in the Vivado Tcl console:  source <path>/{name}/create_project.tcl
set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here ..]]
set xpr  [file join $here {name}.xpr]
if {{[file exists $xpr]}} {{
    open_project $xpr
    return
}}
# Part: {PART} by default (ZCU102 board). To use another installed part, run
#   set core_soc_part <part>
# in the Tcl console before sourcing this script.
if {{![info exists ::core_soc_part]}} {{ set ::core_soc_part {PART} }}
if {{[llength [get_parts -quiet $::core_soc_part]] == 0}} {{
    puts "ERROR: part $::core_soc_part is not installed in this Vivado."
    puts "Zynq-7000 parts found: [llength [get_parts -quiet xc7z*]]; 7-series parts found: [llength [get_parts -quiet xc7*]]"
    puts "Fix: Help > Add Design Tools or Devices > Devices > SoCs > Zynq-7000, or: set core_soc_part <installed part>"
    return
}}
create_project -force {name} $here -part $::core_soc_part
set board [lindex [lsort [get_board_parts -quiet *{BOARD}*]] end]
if {{$board ne "" && $::core_soc_part eq "{PART}"}} {{ set_property board_part $board [current_project] }}
# 7-series parts keep the Ibex BUFGCE SIM_DEVICE 7SERIES; other families get ULTRASCALE_PLUS.
set arch [get_property ARCHITECTURE [get_parts $::core_soc_part]]
set defs [list {' '.join(defs)}]
if {{[lsearch -exact {{zynq artix7 kintex7 virtex7 spartan7 azynq aartix7 akintex7 qzynq qartix7 qkintex7 qvirtex7}} $arch] < 0}} {{
    lappend defs CORE_SOC_ULTRASCALE
}}
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -norecurse -fileset sources_1 [list \\
{tcl_list([rel(f) for f in srcs])} \\
]
# The RTL uses SystemVerilog throughout (Verilator reads every file as SV).
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sources_1] -filter {{FILE_TYPE == Verilog}}]
set incs [list \\
{tcl_list([rel(d) for d in incs]) if incs else ''} \\
]
set_property include_dirs $incs [get_filesets sources_1]
set_property include_dirs $incs [get_filesets sim_1]
set_property verilog_define $defs [get_filesets sources_1]
set_property verilog_define $defs [get_filesets sim_1]
set_property top design_1_wrapper [get_filesets sources_1]
# Firmware images. In sources_1 they reach synthesis ($readmemh by file name) and are
# copied to the xsim run directory. Synthesis needs a real image in the ROM: with an
# empty ROM every instruction reads 0 and Vivado trims the CPU, so area and fmax would
# be wrong. Each testbench picks its own image with IMEM_INIT.
add_files -norecurse -fileset sources_1 [list \\
{tcl_list(mems)} \\
]
set_property generic {{IMEM_INIT="aes_ecb.mem"}} [get_filesets sources_1]

add_files -norecurse -fileset constrs_1 [file join $root constrs core_soc.xdc]

add_files -norecurse -fileset sim_1 [list \\
{tcl_list(tbs)} \\
]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] -filter {{FILE_TYPE == Verilog}}]
set_property top tb_aes_ecb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {{xsim.simulate.runtime}} -value {{all}} -objects [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "{name}: project ready ($xpr)"
""")
        (pdir / f"open_{name}.bat").write_text(
            "@echo off\r\n"
            f"rem [core_soc package] Double-click: creates {name}.xpr on the first run, then opens it.\r\n"
            "set VIV=vivado\r\n"
            "if exist \"C:\\AMDDesignTools\\2024.2\\Vivado\\bin\\vivado.bat\" set VIV=\"C:\\AMDDesignTools\\2024.2\\Vivado\\bin\\vivado.bat\"\r\n"
            "if exist \"C:\\Xilinx\\Vivado\\2024.2\\bin\\vivado.bat\" set VIV=\"C:\\Xilinx\\Vivado\\2024.2\\bin\\vivado.bat\"\r\n"
            "cd /d \"%~dp0\"\r\n"
            "call %VIV% -mode gui -source create_project.tcl -nojournal -log vivado_open.log\r\n")
        (pdir / f"open_{name}.sh").write_text(
            "#!/bin/sh\n"
            f"# [core_soc package] Creates {name}.xpr on the first run, then opens it.\n"
            "cd \"$(dirname \"$0\")\" && exec vivado -mode gui -source create_project.tcl -nojournal -log vivado_open.log\n")
        (pdir / f"open_{name}.sh").chmod(0o755)
        print(f"{name}: {len(srcs)} sources, {len(incs)} include dirs")
    shutil.copy(Path(__file__).with_name("core_soc_README_VI.md"), pkg / "README_VI.md")
    print(f"files copied: {len(copied)}")


if __name__ == "__main__":
    main(sys.argv[1])
