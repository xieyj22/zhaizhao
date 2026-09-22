#!/usr/bin/env python3
"""B3: terrain+sprite 实渲染断言。用法: PYTHONUTF8=1 python tools/snap_terrain_check.py with.png plain.png"""
import sys
from PIL import Image

def colors(img, box):
    return [p[:3] for p in img.crop(box).getdata() if p[3] > 200]

def main():
    a = Image.open(sys.argv[1]).convert("RGBA")
    b = Image.open(sys.argv[2]).convert("RGBA")
    box = (60, 60, a.width - 60, int(a.height * 0.6))   # 棋盘区（避开 HUD）
    ca, cb = set(colors(a, box)), set(colors(b, box))
    # 阈值校准（B3 实拍）：brief 原 1.5× 比率实测仅 1.32（441/334）——两图共享
    # sprite/HUD 色垫高 plain 底数；改断 with 独有新色数（地形 tile + sprite 叠
    # tile 混合色，共享噪声在差集里相消），实测 108，阈值 50 留 >2x 余量。
    new = ca - cb
    assert len(new) >= 50, f"地形/sprite 未生效: new colors {len(new)} (with {len(ca)} vs plain {len(cb)})"
    anchors = [(142, 47, 47), (163, 86, 58), (200, 162, 74)]  # 血衣/赤锋/锐金
    hits = sum(1 for c in ca if any(all(abs(c[i]-an[i]) <= 24 for i in range(3)) for an in anchors))
    assert hits >= 3, f"sprite 锚色命中 {hits} < 3"
    print(f"OK colors {len(cb)} -> {len(ca)}, anchor hits {hits}")

main()
