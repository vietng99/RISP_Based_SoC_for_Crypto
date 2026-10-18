#!/usr/bin/env python3
"""Build RISP firmware (.s -> .hex + .coe) with the chipyard RISC-V toolchain.

Same steps as build() in RISP/hardware/firmware/gen_all.py (as -march=rv32i
-mabi=ilp32, ld -T link.ld, objcopy -O binary, little-endian 32-bit words),
with riscv64-unknown-elf-{as,ld,objcopy} from chipyard/.conda-env/riscv-tools
instead of the Windows xpack riscv-none-elf tools.

Usage: build_fw.py <out_dir> <file.s> [<file.s> ...]
"""
import struct
import subprocess
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[2] / "chipyard/.conda-env/riscv-tools/bin"
AS, LD, OC = (str(TOOLS / f"riscv64-unknown-elf-{t}") for t in ("as", "ld", "objcopy"))


def build(src, out):
    name = src.stem
    o, elf, binf = out / f"{name}.o", out / f"{name}.elf", out / f"{name}.bin"
    for cmd in ([AS, "-march=rv32i", "-mabi=ilp32", "-o", str(o), str(src)],
                [LD, "-m", "elf32lriscv", "-T", str(src.parent / "link.ld"), "-o", str(elf), str(o)],
                [OC, "-O", "binary", str(elf), str(binf)]):
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"build {name} failed:\n{' '.join(cmd)}\n{r.stderr}")
    data = binf.read_bytes()
    w = [struct.unpack("<I", data[i:i + 4])[0] for i in range(0, len(data), 4)]
    L = ["%08X" % x for x in w]
    (out / f"{name}.coe").write_text(
        "memory_initialization_radix=16;\nmemory_initialization_vector=\n"
        + ",\n".join(L[:-1]) + ",\n" + L[-1] + ";\n", newline="\n")
    (out / f"{name}.hex").write_text("".join("%08x\n" % x for x in w), newline="\n")
    for f in (o, elf, binf):
        f.unlink()
    return len(w)


if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for s in sys.argv[2:]:
        print(f"{Path(s).stem:10s} {build(Path(s).resolve(), out):4d} words")
