#!/usr/bin/env python3
"""Summarize logs/rv32i-run-<tb>.log files written by `make -f mk/rv32i.mk run-<tb>`.

Same output as tools/summary.py (verdict, golden checks, cycle milestones and
metric lines); only the log name prefix differs.
usage: summary_rv32i.py tb_a tb_b ...
"""
import re
import sys
from pathlib import Path

LOGS = Path(__file__).resolve().parent.parent / "logs"
PREFIX = "rv32i-run-"


def main() -> int:
    rows = []
    for tb in sys.argv[1:]:
        p = LOGS / f"{PREFIX}{tb}.log"
        if not p.exists():
            rows.append(f"{tb}: no log")
            continue
        text = p.read_text(errors="replace")
        verdict = re.search(r"==> \[(PASS|FAIL)\][^\n]*", text)
        timeout = re.search(r"\[TIMEOUT[^\n]*", text)
        ok = len(re.findall(r"=\s+[0-9a-fx]{8}\s+OK\b", text))
        bad = len(re.findall(r"=\s+[0-9a-fx]{8}\s+FAIL\b", text))
        head = verdict.group(0).strip() if verdict else "no verdict"
        if timeout:
            head += f" | {timeout.group(0).strip()}"
        rows.append(f"{tb}: {head} | checks ok {ok}/{ok + bad}")
        for line in text.splitlines():
            s = line.strip()
            if s.startswith("Moc cycle") or re.match(r"\[\d\]", s):
                rows.append(f"    {s}")
    print("\n".join(rows))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
