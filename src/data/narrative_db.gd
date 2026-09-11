class_name NarrativeDB
extends RefCounted

## 叙事数据门面（scene 层只 import 本类）。全部未命中返回空值。
static func boss_dialogue(boss_id: String, key: String) -> Array:
	return NarrativeBoss.dialogue(boss_id, key)

static func boss_line(boss_id: String, trigger: String) -> String:
	return NarrativeBoss.line(boss_id, trigger)

static func interlude(chapter: int, seg: String) -> String:
	return NarrativeRegion.interlude(chapter, seg)

static func prose(region_id: String) -> String:
	return NarrativeRegion.prose(region_id)
