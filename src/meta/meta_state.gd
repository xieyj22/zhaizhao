class_name MetaState
extends RefCounted

## 跨 run meta（T4 §6.1）。M3 唯一落盘类（user://meta.sav）。
var meta_unlocked_pool: Array = []          # 已解锁招 id
var meta_faction_relations: Dictionary = {} # 跨 run 关系
var meta_inheritance_unlocked: bool = false
var meta_runs_completed: int = 0
var meta_codex_entries: Array = []          # M3 占位

const DEFAULT_SAVE_PATH := "user://meta.sav"

## 首玩默认：解锁池 = T1 阶全部通用招；关系 = FactionData.initial_relations()。
static func new_first_play() -> MetaState:
	var m := MetaState.new()
	m.meta_faction_relations = FactionData.initial_relations()
	# 解锁池 = T1 阶全部（通用招；technique_data tier_of 默认 1）
	for t in TechniqueData.all_techniques():
		if TechniqueData.tier_of(StringName(t.id)) == 1:
			m.meta_unlocked_pool.append(String(t.id))
	return m

func to_dict() -> Dictionary:
	return {
		"meta_unlocked_pool": meta_unlocked_pool,
		"meta_faction_relations": meta_faction_relations,
		"meta_inheritance_unlocked": meta_inheritance_unlocked,
		"meta_runs_completed": meta_runs_completed,
		"meta_codex_entries": meta_codex_entries,
	}

## 注意：深拷贝 nested 容器——to_dict() 返回的 Array/Dict 与本对象字段同引用，
## 直接赋值会共享引用（commit_run_to_meta 改返回值会污染输入）。故 .duplicate(true)。
static func from_dict(d: Dictionary) -> MetaState:
	var m := MetaState.new()
	m.meta_unlocked_pool = (d.get("meta_unlocked_pool", []) as Array).duplicate(true)
	m.meta_faction_relations = (d.get("meta_faction_relations", {}) as Dictionary).duplicate(true)
	m.meta_inheritance_unlocked = d.get("meta_inheritance_unlocked", false)
	m.meta_runs_completed = d.get("meta_runs_completed", 0)
	m.meta_codex_entries = (d.get("meta_codex_entries", []) as Array).duplicate(true)
	return m

## run 结束沉淀（纯函数，深拷贝；不落盘）。run_won=是否通关（章末 boss 胜）。
static func commit_run_to_meta(meta: MetaState, run: RunState, run_won: bool) -> MetaState:
	# from_dict 已 .duplicate(true) → 全新实例，nested 容器独立
	var m := MetaState.from_dict(meta.to_dict())
	for tid in run.unlocked_techniques:
		if not m.meta_unlocked_pool.has(tid):
			m.meta_unlocked_pool.append(tid)
	for fid in run.faction_relations:
		if fid != "F8":   # 血衣教恒 -100 锁死
			m.meta_faction_relations[fid] = maxi(int(m.meta_faction_relations.get(fid, 0)), int(run.faction_relations[fid]))
	if run_won:
		m.meta_runs_completed += 1
		m.meta_inheritance_unlocked = true
	return m

static func load_from(path: String = DEFAULT_SAVE_PATH) -> MetaState:
	if not FileAccess.file_exists(path):
		return new_first_play()
	var f := FileAccess.open(path, FileAccess.READ)
	var m := from_dict(JSON.parse_string(f.get_as_text()))
	f.close()
	return m

static func save_to(meta: MetaState, path: String = DEFAULT_SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(meta.to_dict()))
	f.close()
