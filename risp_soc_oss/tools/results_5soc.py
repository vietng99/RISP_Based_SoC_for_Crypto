#!/usr/bin/env python3
"""AES / SHA3 / RSA results of several SoCs from their Verilator summaries.

Usage: results_5soc.py NAME=logs/summary-x.txt [NAME=...]   (first NAME is the reference)
Prints Markdown tables: verdict and checks, accelerator core cycles, PURE cycles,
END-TO-END cycles, and PURE relative to the reference SoC.
Testbench names: RISSP-style tb_<test>; RV32I/Ibex use tb_rv32i_<x>/tb_ibex_<x> with
ecb/cbc/cfb/ctr for the AES tests (same firmware, see mk/rv32i.mk, mk/ibex.mk).
"""
import re
import sys

TESTS = [("aes_ecb", "AES-128 ECB"), ("aes_cbc", "AES-128 CBC"), ("aes_cfb", "AES-128 CFB"),
         ("aes_ctr", "AES-128 CTR"), ("sha3", "SHA3-256 1 block"), ("sha3_4", "SHA3-256 4 block"),
         ("sha3_16", "SHA3-256 16 block"), ("rsa2048", "RSA-2048 CTRL=0x1"),
         ("rsa2048_fast", "RSA-2048 CTRL=0x3")]
AES_SHORT = {"aes_ecb": "ecb", "aes_cbc": "cbc", "aes_cfb": "cfb", "aes_ctr": "ctr"}


def parse(path):
    blocks, cur = {}, None
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"(tb_\w+): ==> \[(PASS|FAIL)\].*?(checks ok \d+/\d+)?\s*$", line)
        if m:
            cur = blocks.setdefault(m.group(1), {"verdict": m.group(2), "checks": m.group(3) or ""})
            continue
        if cur is None:
            continue
        m = re.search(r"\[1\][^:]*:\s*(-?\d+) cyc", line)
        if m:
            cur["core"] = int(m.group(1))
        m = re.search(r"\[2\] PURE[^:]*:\s*(\d+) cyc", line)
        if m:
            cur["pure"] = int(m.group(1))
        m = re.search(r"END-TO-END[^:]*:\s*(\d+) cyc", line)
        if m:
            cur["e2e"] = int(m.group(1))
    return blocks


def find(blocks, key):
    for name in (f"tb_{key}", f"tb_rv32i_{AES_SHORT.get(key, key)}", f"tb_ibex_{AES_SHORT.get(key, key)}"):
        if name in blocks:
            return blocks[name]
    return None


def main():
    socs = [a.split("=", 1) for a in sys.argv[1:]]
    data = {n: parse(p) for n, p in socs}
    names = [n for n, _ in socs]
    ref = names[0]

    def table(title, cell):
        print(f"### {title}\n")
        print("| Test | " + " | ".join(names) + " |")
        print("|---|" + "---:|" * len(names))
        for key, label in TESTS:
            row = [label]
            for n in names:
                b = find(data[n], key)
                row.append(cell(b, key) if b else "-")
            print("| " + " | ".join(row) + " |")
        print()

    table("Verdict (golden checks)", lambda b, k: f"{b['verdict']} {b['checks'].replace('checks ok ', '')}")
    table("Accelerator core cycles", lambda b, k: f"{b.get('core', 0):,}")
    table("PURE cycles (CPU + bus + accelerator, measured on AXI/BRAM)", lambda b, k: f"{b.get('pure', 0):,}")
    table("END-TO-END cycles", lambda b, k: f"{b.get('e2e', 0):,}")

    def rel(b, k):
        r = find(data[ref], k)
        if not r or not r.get("pure") or not b.get("pure"):
            return "-"
        return f"{b['pure'] / r['pure']:.3f}"
    table(f"PURE relative to {ref} (lower is faster)", rel)


if __name__ == "__main__":
    main()
