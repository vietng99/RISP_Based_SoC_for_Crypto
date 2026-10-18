#!/usr/bin/env python3
"""Test vectors for tb/unit/tb_rsa_core_pa1.sv (PA1 unit test of module `rsa`).

Writes one hex word per line: first the number of cases, then 6 lines per case: M, N, R2 = 2^(2*WIDTH) mod N,
N_INV = -N^-1 mod 2^32, E, expected pow(M, E, N). Fixed seed, so the file is
the same on every run.
"""
import random
import sys

WIDTH = int(sys.argv[2]) if len(sys.argv) > 2 else 256
out = sys.argv[1]
rng = random.Random(20261014)

moduli = []
while len(moduli) < 3:
    n = rng.getrandbits(WIDTH) | (1 << (WIDTH - 1)) | 1     # odd, full width
    moduli.append(n)
exps = [0, 1, 2, 3, 17, 65537, 0x10001 + 2, 0x80000000, 0xFFFFFFFF] + \
       [rng.getrandbits(32) | 1 for _ in range(3)]

digits = WIDTH // 4
lines, n_cases = [], 0
for n in moduli:
    r2 = pow(2, 2 * WIDTH, n)
    ninv = (-pow(n, -1, 1 << 32)) % (1 << 32)
    # M >= N (up to 2^WIDTH - 1) is legal input for the core: both flows bound the
    # Montgomery result below 2N, so one final subtraction still reduces it.
    for m in [0, 1, n - 1, rng.randrange(n), rng.randrange(n),
              n, (1 << WIDTH) - 1]:
        for e in exps:
            for v in (m, n, r2, ninv, e, pow(m, e, n)):
                lines.append(f"{v:0{digits}x}")
            n_cases += 1
open(out, "w").write(f"{n_cases:0{digits}x}\n" + "\n".join(lines) + "\n")
print(f"{out}: {n_cases} cases, WIDTH {WIDTH}")
