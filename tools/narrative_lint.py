#!/usr/bin/env python3
"""Wave2 文案体检（md 草稿层）。用法: python tools/narrative_lint.py <md...>；有违规 exit 1
红线词表与 docs/design/narrative/00-style-bible.md §5 保持同步（改词表须两处同改）。"""
import re, sys, pathlib
sys.stdout.reconfigure(encoding="utf-8")   # Win 控制台 cp936 防乱码
RED = ["不禁", "竟然", "仿佛", "宛如", "一丝", "瞳孔", "嘴角勾起", "空气凝固", "深邃", "幽幽"]

def lint(p: str):
    t = pathlib.Path(p).read_text(encoding="utf-8")
    han = len(re.findall(r"[一-鿿]", t))
    issues = []
    for w in RED:
        if t.count(w):
            issues.append(f"红线词[{w}]x{t.count(w)}")
    per_k = t.count("——") / max(han, 1) * 1000
    if per_k > 10:
        issues.append(f"破折号密度{per_k:.1f}/千字(>10)")
    return issues, han

if __name__ == "__main__":
    bad = 0
    for p in sys.argv[1:]:
        issues, han = lint(p)
        print(f"{p}: {han}汉字", "OK" if not issues else "; ".join(issues))
        bad += len(issues)
    sys.exit(1 if bad else 0)
