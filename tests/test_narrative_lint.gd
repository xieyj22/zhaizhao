extends GutTest

## 入库红线 lint（Wave2 plan Task 13 Step 2）。
## 与 tools/narrative_lint.py 同词表：py 管草稿 md，本测管入库文本（spec §4 裁决的双轨）。

const RED := ["不禁", "竟然", "仿佛", "宛如", "一丝", "瞳孔", "嘴角勾起", "空气凝固", "深邃", "幽幽"]

func _all_text() -> String:
	var parts := PackedStringArray()
	for bid: Variant in NarrativeBoss.BOSS_NARRATIVE:
		var b: Dictionary = NarrativeBoss.entry(String(bid))
		parts.append(String(b["bio"]))
		for key in ["pre", "post_win", "post_loss"]:
			for ln: Variant in b[key]:
				parts.append(String((ln as Dictionary)["line"]))
		var tl: Dictionary = b.get("trait_lines", {})
		for k: Variant in tl:
			parts.append(String(tl[k]))
	for rid: Variant in NarrativeRegion.REGION_PROSE:
		parts.append(String(NarrativeRegion.REGION_PROSE[rid]))
	for ch: Variant in NarrativeRegion.CHAPTER_INTERLUDES:
		var segs: Dictionary = NarrativeRegion.CHAPTER_INTERLUDES[ch]
		for seg: Variant in segs:
			parts.append(String(segs[seg]))
	for e: Variant in NarrativeCodex.CODEX_ENTRIES:
		var d: Dictionary = e
		parts.append(String(d.get("body", "")))
	return "\n".join(parts)

func _han_count(t: String) -> int:
	var n := 0
	for i in t.length():
		var u := t.unicode_at(i)
		if u >= 0x4E00 and u <= 0x9FFF:
			n += 1
	return n

func test_no_redline_words():
	var t := _all_text()
	for w in RED:
		assert_eq(t.count(w), 0, "红线词[%s]" % w)

func test_dash_density():
	# Ruling: plan 文本写 ≤15/千字，py 真源口径 >10 报警——从严取 10（Task 13 记账）
	var t := _all_text()
	var per_k: float = float(t.count("——")) / max(_han_count(t), 1) * 1000.0
	assert_lte(per_k, 10.0, "破折号密度 %.1f/千字（上限 10）" % per_k)
