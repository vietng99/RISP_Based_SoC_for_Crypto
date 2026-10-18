#!/usr/bin/env python3
"""Make rsa2048_fast.s from rsa2048.s: RSA-2048 verify on the PA1-R RSA IP
using the public-exponent flow (CTRL = 0x3: start + fast_pub).

Only the header comments, the register-map comment and the CTRL value change.
Key, message, PURE window, result checks and BRAM marker stay identical, so
tb_rsa2048 / tb_rv32i_rsa2048 / tb_ibex_rsa2048 check it unchanged and the
PURE numbers compare one to one with rsa2048.s (CTRL = 0x1).

Usage: gen_rsa2048_fast_s.py <rsa2048.s> <rsa2048_fast.s>
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()


def rep(a, b):
    global s
    assert s.count(a) == 1, a
    s = s.replace(a, b)


rep("# rsa2048.s - RSA-2048 verify tren SE-RISSP_AES_ULTRA\n"
    "# Sinh tu dong boi gen_all.py - KHONG sua tay (sua gen_all.py roi chay lai).\n",
    "# rsa2048_fast.s - RSA-2048 verify, luong so mu cong khai (PA1-R, CTRL = 0x3)\n"
    "# Sinh boi risp_soc_oss/tools/gen_rsa2048_fast_s.py tu rsa2048.s - KHONG sua tay.\n"
    "# Khac rsa2048.s DUY NHAT o CTRL = 0x3 (start + fast_pub) va phan chu thich.\n"
    "# Luong nhanh KHONG chay thoi gian hang: chi dung khi E la so mu CONG KHAI\n"
    "# (verify chu ky). Ky/giai ma voi so mu bi mat phai dung rsa2048.s (0x1).\n"
    "# Can IP RSA ban PA1-R (ip_repo/acc_rsa, 2026-10-14). Voi IP cu, bit1 bi\n"
    "# bo qua va firmware nay chay nhu rsa2048.s.\n")
rep("#   0x200-0x2FC  W  R2[0..63]      0x308  W  CTRL   (bit0 = start)\n"
    "#   0x400-0x4FC  R  RESULT[0..63]  0x30C  R  STATUS (bit0 = done)\n",
    "#   0x200-0x2FC  W  R2[0..63]      0x308  W  CTRL   (bit0 = start, bit1 = fast_pub)\n"
    "#   0x400-0x4FC  R  RESULT[0..63]  0x30C  R  STATUS (bit0 = done, bit1 = busy)\n"
    "#   STATUS.done bi xoa ngay khi ghi CTRL start, nen poll bit0 la du.\n")
rep("    li   x6, 0x1\n    sw   x6, 0x308(x13)    # CTRL: start=1\n",
    "    li   x6, 0x3\n    sw   x6, 0x308(x13)    # CTRL: start=1, fast_pub=1 (E cong khai)\n")
open(dst, "w", encoding="utf-8", newline="\n").write(s)
