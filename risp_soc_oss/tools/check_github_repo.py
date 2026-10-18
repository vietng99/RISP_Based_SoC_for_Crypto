#!/usr/bin/env python3
"""[t-036] Verilator check of the SoC-all-core repository RTL.

For each core, the RTL SoC file list (flist/<core>_soc.f) is expanded and every file the
repository ships is taken from the repository copy instead; only the SoC parts that the
Vivado block design builds from Xilinx IP (rtl/soc, mem, periph, bus, xbar) stay from
risp_soc_oss. The CPU enters through the repository's cpu_core wrapper
(tools/bd/design_1_cpucore.sv). Writes build/repocheck/<core>/soc.f.
Usage: python3 tools/check_github_repo.py <repo>
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pack_vivado as pv  # noqa: E402
import pack_github_repo as gr  # noqa: E402

repo = Path(sys.argv[1]).resolve()
# Keep the Verilator-only stand-ins of the RTL SoC (rtl/patched/RSA_core.v: Verilator cannot
# do delayed array writes in for loops; rtl/patched_ibex/xilinx_clkbuf_models.v: BUFGCE
# model). The repository ships the originals, which Vivado reads.
pv.SWAP = {}
for core in pv.CORES:
    srcs, incs = [], []
    pv.expand(pv.OSS / f"flist/{core}_soc.f", srcs, incs)
    out, swapped = [], 0
    for f in srcs:
        f = Path(f).resolve()
        if f.name.startswith("design_1") and f.parent.name == "soc":
            continue
        try:
            r = repo / gr.dest(f)
        except SystemExit:
            r = None
        if r is not None and r.is_file():
            out.append(r)
            swapped += 1
        else:
            out.append(f)
    out += [repo / f"rtl/cpu/{core}/cpu_core_{core}.v", pv.OSS / "tools/bd/design_1_cpucore.sv"]
    rincs = []
    for d in incs:
        try:
            rd = (repo / gr.dest(Path(d) / "x")).parent
        except SystemExit:
            rd = Path(d)
        rincs.append(rd if rd.is_dir() else Path(d))
    w = pv.OSS / f"build/repocheck/{core}"
    w.mkdir(parents=True, exist_ok=True)
    lines = [f"+incdir+{d}" for d in rincs] + [str(f) for f in out]
    (w / "soc.f").write_text("\n".join(lines) + "\n")
    print(f"{core}: {len(out)} files, {swapped} from the repository")
