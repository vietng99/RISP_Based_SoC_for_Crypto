#!/usr/bin/env python3
"""Copy a Vivado RISSP testbench and make it run under Verilator 5.022.

One change only. The Vivado testbench does, inside an initial block,

    force dut.design_1_i.clk_wiz_0_clk_out1 = soc_clk_drv;

Verilator 5.022 evaluates the right-hand side once, so the SoC clock stays at
0. The copy drops that statement and re-applies the same force on every change
of soc_clk_drv from a module-level always block, which gives the same 40 MHz
clock on the same net. Everything else (stimulus, probes, golden values,
reports) is byte-for-byte the original.

usage: adapt_tb.py <vivado_tb.v> <out.v>
"""
import re
import sys

# [^\r\n]* keeps the line ending (the Vivado files are CRLF) out of the match.
FORCE = re.compile(r"^([ \t]*)force\s+dut\.design_1_i\.clk_wiz_0_clk_out1\s*=\s*soc_clk_drv\s*;[^\r\n]*", re.M)
DRV = re.compile(r"^[^\r\n]*always\s+#[\d.]+\s+soc_clk_drv\s*=\s*~soc_clk_drv\s*;[^\r\n]*(\r?\n)", re.M)


def main() -> int:
    src_path, out_path = sys.argv[1], sys.argv[2]
    src = open(src_path, encoding="utf-8", errors="surrogateescape", newline="").read()
    if len(FORCE.findall(src)) != 1 or len(DRV.findall(src)) != 1:
        sys.exit(f"{src_path}: expected exactly one clk_out1 force and one soc_clk_drv generator")
    out = FORCE.sub(lambda m: f"{m.group(1)}// [adapt_tb] clk_out1 force moved next to soc_clk_drv (Verilator)", src)
    out = DRV.sub(lambda m: m.group(0) + "always @(soc_clk_drv) force dut.design_1_i.clk_wiz_0_clk_out1 = soc_clk_drv;  // [adapt_tb]" + m.group(1), out)
    open(out_path, "w", encoding="utf-8", errors="surrogateescape", newline="").write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
