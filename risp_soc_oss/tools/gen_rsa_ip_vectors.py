#!/usr/bin/env python3
"""Vectors for tb/unit/tb_rsa_ip_axi.sv: the RSA IP (RSA_mark03, 2048-bit) tested
alone through its AXI4-Lite port.

First line: number of cases. Then 8 words of WIDTH bits per case:
  KIND_CTRL  bits[3:0] = CTRL value written, bits[11:8] = kind
             kind 0 normal, 1 CTRL without start (no new result),
             2 second start queued while busy (M2 is its message),
             3 E rewritten to E2 (in M2) while busy (must not change result)
  E, NINV, M, N, R2, M2, EXP (expected RESULT after the case)
The IP is instantiated with RSA_E_SCAN = 17 as in the SoC, so the original flow
(CTRL = 0x1) only covers E < 2^17; the fast flow (CTRL = 0x3) covers any E.
"""
import random
import sys

W = 2048
out = sys.argv[1]
rng = random.Random(20261015)
keys = []
for _ in range(2):
    n = rng.getrandbits(W) | (1 << (W - 1)) | 1
    keys.append((n, (-pow(n, -1, 1 << 32)) % (1 << 32), pow(2, 2 * W, n)))

cases = []
def add(kind, ctrl, e, key, m, m2=0, exp=None):
    n, ninv, r2 = key
    if exp is None:
        exp = pow(m, e, n)
    cases.append(((kind << 8) | ctrl, e, ninv, m, n, r2, m2, exp))

k0, k1 = keys
m = rng.randrange(k0[0])
add(0, 0x1, 65537, k0, m)                     # original flow, e = 65537
add(0, 0x3, 65537, k0, m)                     # fast flow, same inputs
add(0, 0x3, 3, k0, rng.randrange(k0[0]))      # fast, e = 3
add(0, 0x1, 3, k0, rng.randrange(k0[0]))      # original, e = 3
add(0, 0x3, 65537, k0, (1 << W) - 1)          # fast, M >= N
add(0, 0x3, 65537, k0, k0[0])                 # fast, M = N -> 0
add(0, 0x3, 1, k0, 0)                         # fast, e = 1, M = 0
add(0, 0x3, 0, k0, rng.randrange(k0[0]))      # fast bit with E = 0 -> original flow -> 1
add(0, 0x3, rng.getrandbits(32) | 0x80000001, k1, rng.randrange(k1[0]))  # fast, 32-bit E
add(0, 0x3, 65537, k1, k1[0] - 1)             # fast, M = N - 1
prev = cases[-1]
add(1, 0x2, 65537, k1, rng.randrange(k1[0]), exp=prev[7])  # CTRL=0x2: no start, RESULT unchanged
ma, mb = rng.randrange(k1[0]), rng.randrange(k1[0])
add(2, 0x3, 65537, k1, ma, m2=mb, exp=pow(mb, 65537, k1[0]))  # queued start
mc = rng.randrange(k0[0])
add(3, 0x3, 65537, k0, mc, m2=3, exp=pow(mc, 65537, k0[0]))   # E rewrite while busy
add(3, 0x1, 65537, k0, mc, m2=5, exp=pow(mc, 65537, k0[0]))   # same, original flow

d = W // 4
with open(out, "w") as f:
    f.write(f"{len(cases):0{d}x}\n")
    for c in cases:
        for v in c:
            f.write(f"{v:0{d}x}\n")
print(f"{out}: {len(cases)} cases")
