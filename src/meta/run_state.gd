class_name RunState
extends RefCounted

## 单局闯荡状态（T4 §4，15 字段）。纯数据 JSON-safe；rest_used/upgrade_used 内存态不序列化。
var run_id: String = ""
var rng_seed: int = 0
var current_chapter: int = 1
var current_node_id: String = ""           # 空 = 在 hub
var chapter_maps: Dictionary = {}          # {chapter_int: map_dict}
var player_roster: Array = []              # Array[unit_persist_dict]
var unlocked_techniques: Array = []        # Array[String] 招 id
var technique_variants: Dictionary = {}    # {tech_id: "strong"}
var hazard_modifiers: Dictionary = {}      # 当前险地修饰符（空=无）
var faction_relations: Dictionary = {}     # {faction_id: int}
var jianghu_credit: int = 0
var inheritance_slot: Dictionary = {}      # {}=无；{type,id}
var chapter_progress: Dictionary = {}      # {chapter_int:{boss_defeated,nodes_visited}}
var run_log: Array = []
## —— M3.5: 局 modifier 解析后的 effect（按 hook 分组）；空 = 无 modifier ——
var modifier_state: Dictionary = {}
# —— 内存态（不序列化，T2）——
var rest_used: int = 0
var upgrade_used: int = 0

func to_dict() -> Dictionary:
	return {
		"run_id": run_id, "rng_seed": rng_seed, "current_chapter": current_chapter,
		"current_node_id": current_node_id, "chapter_maps": chapter_maps,
		"player_roster": player_roster, "unlocked_techniques": unlocked_techniques,
		"technique_variants": technique_variants, "hazard_modifiers": hazard_modifiers,
		"faction_relations": faction_relations, "jianghu_credit": jianghu_credit,
		"inheritance_slot": inheritance_slot, "chapter_progress": chapter_progress,
		"run_log": run_log, "modifier_state": modifier_state,
	}   # 注：rest_used/upgrade_used 不进 to_dict（T2）

static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	r.run_id = d.get("run_id", "")
	r.rng_seed = d.get("rng_seed", 0)
	r.current_chapter = d.get("current_chapter", 1)
	r.current_node_id = d.get("current_node_id", "")
	r.chapter_maps = d.get("chapter_maps", {})
	r.player_roster = d.get("player_roster", [])
	r.unlocked_techniques = d.get("unlocked_techniques", [])
	r.technique_variants = d.get("technique_variants", {})
	r.hazard_modifiers = d.get("hazard_modifiers", {})
	r.faction_relations = d.get("faction_relations", {})
	r.jianghu_credit = d.get("jianghu_credit", 0)
	r.inheritance_slot = d.get("inheritance_slot", {})
	r.chapter_progress = d.get("chapter_progress", {})
	r.run_log = d.get("run_log", [])
	r.modifier_state = d.get("modifier_state", {})
	r.rest_used = 0   # 内存态重置
	r.upgrade_used = 0
	return r
