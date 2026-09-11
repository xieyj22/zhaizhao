class_name CodexUnlock
extends RefCounted

## codex 进度解锁求值（Wave2 spec §3.5）。纯函数。codex_count_ge 两遍求值防递归自含。

static func is_unlocked(entry: Dictionary, meta: MetaState) -> bool:
	var u: Dictionary = entry.get("unlock", {"type": "always", "key": ""})
	match String(u.get("type", "always")):
		"always": return true
		"boss_defeated": return meta.bosses_defeated_all.has(String(u.get("key", "")))
		"chapter_reached": return meta.chapters_reached.has(int(u.get("key", 1)))
		"technique_owned": return meta.meta_unlocked_pool.has(String(u.get("key", "")))
		"runs_completed_ge": return meta.meta_runs_completed >= int(u.get("key", 1))
		"codex_count_ge": return _base_count(meta) >= int(u.get("key", 1))
		_: return false

static func unlocked_ids(meta: MetaState) -> Array:
	var out: Array = []
	var count_entries: Array = []
	for e: Variant in NarrativeCodex.CODEX_ENTRIES:
		var d: Dictionary = e
		if String(d.get("unlock", {}).get("type", "always")) == "codex_count_ge":
			count_entries.append(d)
		elif is_unlocked(d, meta):
			out.append(String(d.get("id", "")))
	# 第二遍：count 型以非 count 已解锁数为基数
	var base: int = _base_count(meta)
	for d: Dictionary in count_entries:
		if base >= int(d["unlock"].get("key", 1)):
			out.append(String(d.get("id", "")))
	return out

static func _base_count(meta: MetaState) -> int:
	var n := 0
	for e: Variant in NarrativeCodex.CODEX_ENTRIES:
		var d: Dictionary = e
		if String(d.get("unlock", {}).get("type", "always")) != "codex_count_ge" and is_unlocked(d, meta):
			n += 1
	return n

static func hint_for(entry: Dictionary) -> String:
	match String(entry.get("unlock", {}).get("type", "always")):
		"boss_defeated": return "击败该首领后解锁"
		"chapter_reached": return "抵达该章后解锁"
		"technique_owned": return "习得对应招式后解锁"
		"runs_completed_ge": return "通关后解锁"
		"codex_count_ge": return "江湖志收集更多条目后解锁"
		_: return ""
