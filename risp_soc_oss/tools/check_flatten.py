#!/usr/bin/env python3
"""[t-034] Check that the flattened Ibex/CVA6 sources of a core_soc_bd package are the
same design as the originals: `verilator -E -P` (preprocess only, no line markers, comments
dropped) of the original file list with its +incdir dirs and of the flattened list with no
include dir must give the same text, blank lines and trailing spaces ignored. Run for each
define set Vivado can see (none, SYNTHESIS, SYNTHESIS + CORE_SOC_ULTRASCALE).

Usage: python3 tools/check_flatten.py <pkg_dir>   (pkg_dir = <out>/core_soc_bd)
"""
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pack_vivado as pv  # noqa: E402
import pack_vivado_bd as bd  # noqa: E402

VERILATOR = os.environ.get("VERILATOR", "verilator")
# `__FILE__ and `__LINE__ inside assertion messages name the flattened file and its lines
FILE_LINE = re.compile(r'"[^"]*\.(?:sv|svh|v|vh)", \d+')
DEFSETS = [[], ["SYNTHESIS"], ["SYNTHESIS", "CORE_SOC_ULTRASCALE"]]


def pre(pkg, files, incs, defs):
    cmd = [VERILATOR, "-E", "-P", *[f"+incdir+{pkg / d}" for d in incs],
           *[f"+define+{d}" for d in defs], *[str(pkg / f) for f in files]]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"verilator -E failed:\n{' '.join(cmd)[:400]}\n{r.stderr[-2000:]}")
    return [l.rstrip() for l in r.stdout.splitlines() if l.strip()]


def main(pkg):
    pkg = Path(pkg)
    bad = 0
    for core in bd.FLATTEN:
        srcs, incs = bd.bd_sources(core)
        flat = [l.strip() for l in (pkg / f"filelists/{core}_soc.f").read_text().splitlines()
                if l.strip() and not l.startswith("+")]
        orig = [str(Path("src") / Path(*Path(f).parts[2:])) if f.startswith("src_flat/") else f for f in flat]
        assert orig == [pv.rel(f).as_posix() for f in srcs], core
        assert not any(l.startswith("+incdir+") for l in (pkg / f"filelists/{core}_soc.f").read_text().splitlines()), core
        for defs in DEFSETS:
            d = defs + pv.DEFINES.get(core, [])
            a = pre(pkg, orig, [pv.rel(i) for i in incs], d)
            b = pre(pkg, flat, [], d)
            same = a == b
            n = sum(x != y for x, y in zip(a, b)) if len(a) == len(b) else -1
            masked = n > 0 and [FILE_LINE.sub('"F", 0', x) for x in a] == [FILE_LINE.sub('"F", 0', x) for x in b]
            verdict = "SAME" if same else (f"SAME except file/line in {n} message lines" if masked else "DIFFERENT")
            bad += not (same or masked)
            print(f"{core} defines={d or '-'}: original {len(a)} lines, flattened {len(b)} lines,"
                  f" flattened files {sum(f.startswith('src_flat/') for f in flat)}: {verdict}")
            if masked:
                print(f"  e.g. orig: {next(x for x, y in zip(a, b) if x != y).strip()[:160]}")
                same = True
            if not same:
                i = next(k for k in range(min(len(a), len(b)) + 1) if k >= min(len(a), len(b)) or a[k] != b[k])
                print(f"  first difference at line {i}:\n  orig: {a[i:i+2]}\n  flat: {b[i:i+2]}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main(sys.argv[1])
