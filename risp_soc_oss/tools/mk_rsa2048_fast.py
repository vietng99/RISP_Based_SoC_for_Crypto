#!/usr/bin/env python3
"""Make firmware/rsa2048_fast.hex from RISP firmware rsa2048.hex (PA1).

Changes exactly one word: `li x6, 0x1` (00100313) right before
`sw x6, 0x308(x13)` (3066a423, the RSA CTRL write) becomes `li x6, 0x3`
(00300313), so CTRL = start | fast_pub. Fails if the pattern is not found
exactly once or if any other word would change.
"""
import sys

LI_1, LI_3, SW_CTRL = "00100313", "00300313", "3066a423"

src, dst = sys.argv[1], sys.argv[2]
words = [w.strip().lower() for w in open(src).read().split()]
hits = [i for i in range(len(words) - 1) if words[i] == LI_1 and words[i + 1] == SW_CTRL]
if len(hits) != 1:
    sys.exit(f"expected one '{LI_1}' followed by '{SW_CTRL}', found {len(hits)}")
out = list(words)
out[hits[0]] = LI_3
diff = [i for i, (a, b) in enumerate(zip(words, out)) if a != b]
assert len(out) == len(words) and diff == hits, diff
open(dst, "w").write("\n".join(out) + "\n")
print(f"{dst}: word {hits[0]} (line {hits[0] + 1}) {LI_1} -> {LI_3}, {len(words)} words, 1 changed")
