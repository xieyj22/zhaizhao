#!/usr/bin/env python3
"""m4c sprite 资产 PIL 验收（spec §4.6/§5.2）。用法: PYTHONUTF8=1 python tools/sprite_check.py manifest.json ledger.json"""
import sys, hashlib, json
from PIL import Image

SPECS = {"boss": (32, 32), "enemy": (24, 24), "ally": (24, 24), "hero": (24, 24), "terrain": (64, 64)}
TOL = 24

def main():
    manifest = json.load(open(sys.argv[1], encoding="utf-8"))
    ledger, bad = {}, 0
    for item in manifest:
        path, kind = item["path"], item["kind"]
        anchor = item.get("anchor")
        img = Image.open(path).convert("RGBA")
        problems = []
        if img.size != SPECS[kind]:
            problems.append(f"size {img.size} != {SPECS[kind]}")
        px = list(img.getdata())
        opaque = [p[:3] for p in px if p[3] > 200]
        if len(opaque) < len(px) * 0.15:
            problems.append(f"opaque ratio {len(opaque)/len(px):.2f} < 0.15")
        if len(set(opaque)) < 3:
            problems.append(f"colors {len(set(opaque))} < 3")
        if anchor and not any(all(abs(c[i]-anchor[i]) <= TOL for i in range(3)) for c in opaque):
            problems.append(f"anchor {anchor} not found (tol {TOL})")
        h = hashlib.sha256(open(path, "rb").read()).hexdigest()[:16]
        ledger[path] = {"sha256_16": h, "colors": len(set(opaque))}
        tag = "FAIL" if problems else "OK"
        if problems:
            bad += 1
        print(f"{tag:4} {path} colors={len(set(opaque))} hash={h} {'; '.join(problems)}")
    json.dump(ledger, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    sys.exit(1 if bad else 0)

main()
