class_name RunFactory
extends RefCounted

## 从 meta + seed 初始化一局（T4 §6.2 reset 规则）。纯函数。
##
## - roster 仅主角；unlocked 仅 T1 阶；关系深拷贝自 meta
## - credit/rest/upgrade/progress 归 0；章 1 起点图生成
static func init_run(meta: MetaState, seed: int) -> RunState:
	var r := RunState.new()
	r.run_id = "run_%d" % seed
	r.rng_seed = seed
	r.current_chapter = 1
	r.current_node_id = ""   # 空 = hub
	# unlocked = meta 池中 T1 阶（tier_of 默认 T1，通用招落 T1；招牌/隐藏按表筛）
	r.unlocked_techniques = TechniqueDB.tier_ids(meta.meta_unlocked_pool, 1)
	# 关系深拷贝自 meta（run 内改关系不污染 meta）
	r.faction_relations = meta.meta_faction_relations.duplicate(true)
	# roster 仅主角（镜照门 F1，brain 性格；M3 五势圆融，无 deck 限制）
	r.player_roster = [_protagonist(r.unlocked_techniques)]
	# 章 1 起点图
	r.chapter_maps = {1: MapGenerator.generate_map(seed, 1)}
	r.chapter_progress = {1: {"boss_defeated": false, "nodes_visited": []}}
	# jianghu_credit / inheritance_slot / technique_variants / hazard_modifiers / run_log
	# 均 RunState 默认（0 / {} / {} / {} / []）；rest_used/upgrade_used 内存态默认 0
	return r

## 主角 unit_persist_dict（T4 §6.2）。kit_ids = 全部 T1 解锁招（五势圆融）。
static func _protagonist(t1_ids: Array) -> Dictionary:
	return {
		"id": "protagonist", "team": 0, "hp": 20, "max_hp": 20,
		"opening": 0, "max_opening": 6,
		"stance": Stance.Id.METAL, "grid_pos": [1, 3], "facing": 0,
		"guard_broken": false, "alive": true,
		"display_name": "遗照", "faction_id": "F1", "personality_id": "brain",
		"kit_ids": t1_ids.duplicate(), "is_protagonist": true,
	}
