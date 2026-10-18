#!/usr/bin/env python3
"""Table of AES / SHA3 / RSA results for the three SoCs from the Verilator summaries.

Usage: results_3soc.py logs/summary.txt logs/summary-rv32i.txt logs/summary-ibex.txt
Prints Markdown: verdict, core cycles, PURE cycles and PURE throughput per test and core.
"""
import re
import sys

CORES = ["RISSP", "RV32I", "Ibex"]
TESTS = [("aes_ecb", "AES-128 ECB"), ("aes_cbc", "AES-128 CBC"), ("aes_cfb", "AES-128 CFB"),
         ("aes_ctr", "AES-128 CTR"), ("sha3", "SHA3-256 1 block"), ("sha3_4", "SHA3-256 4 block"),
         ("sha3_16", "SHA3-256 16 block"), ("rsa2048", "RSA-2048 verify, CTRL=0x1 (goc)"),
         ("rsa2048_fast", "RSA-2048 verify, CTRL=0x3 (nhanh)")]
ALIAS = {"RV32I": {"aes_ecb": "ecb", "aes_cbc": "cbc", "aes_cfb": "cfb", "aes_ctr": "ctr"},
         "Ibex": {"aes_ecb": "ecb", "aes_cbc": "cbc", "aes_cfb": "cfb", "aes_ctr": "ctr"}}
PREFIX = {"RISSP": "tb_", "RV32I": "tb_rv32i_", "Ibex": "tb_ibex_"}


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
        m = re.search(r"\[2\] PURE[^:]*:\s*(\d+) cyc(?: =\s*([\d.]+) us)?(?: ->\s*([\d.]+) Mbps)?", line)
        if m:
            cur["pure"] = int(m.group(1))
            cur["us"] = m.group(2)
            cur["mbps"] = m.group(3)
    return blocks


data = {c: parse(p) for c, p in zip(CORES, sys.argv[1:4])}
print("| Test | " + " | ".join(f"{c} ket qua | {c} loi | {c} PURE" for c in CORES) + " |")
print("|---|" + "---|---|---|" * len(CORES))
for key, label in TESTS:
    row = [label]
    for c in CORES:
        name = PREFIX[c] + ALIAS.get(c, {}).get(key, key)
        b = data[c].get(name)
        if not b:
            row += ["-", "-", "-"]
            continue
        pure = f"{b.get('pure', 0):,}"
        if b.get("mbps"):
            pure += f" ({b['mbps']} Mbps)"
        elif b.get("us"):
            pure += f" ({b['us']} us)"
        row += [f"{b['verdict']} {b['checks'].replace('checks ok ', '')}", f"{b.get('core', 0):,}", pure]
    print("| " + " | ".join(row) + " |")
