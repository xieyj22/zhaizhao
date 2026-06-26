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
	# —— M3.5: roll modifier + apply ——
	r.modifier_state = RunModifier.apply(RunModifier.roll(seed))
	# unlocked = meta 池中 T1 阶（tier_of 默认 T1，通用招落 T1；招牌/隐藏按表筛）
	r.unlocked_techniques = TechniqueDB.tier_ids(meta.meta_unlocked_pool, 1)
	# 关系深拷贝自 meta（run 内改关系不污染 meta）
	r.faction_relations = meta.meta_faction_relations.duplicate(true)
	# roster 仅主角（镜照门 F1，brain 性格；M3 五势圆融，无 deck 限制）
	r.player_roster = [_protagonist(r.unlocked_techniques)]
	# 章 1 起点图（传 hazard_delta，init 期消费；险地数在 generate_map 调用时定型，事后不可改）
	var hazard_delta: int = int(r.modifier_state.get("hazard_node_count_delta", 0))
	r.chapter_maps = {1: MapGenerator.generate_map(seed, 1, hazard_delta)}
	r.chapter_progress = {1: {"bosses_defeated": [], "nodes_visited": []}}
	# —— M3.5: 消费 init 期 hook（relation/hp）——
	apply_init_hooks(r, meta)
	# jianghu_credit / inheritance_slot / technique_variants / hazard_modifiers / run_log
	# 均 RunState 默认（0 / {} / {} / {} / []）；rest_used/upgrade_used 内存态默认 0
	return r

## M3.5: 消费 init 期 modifier hook（relation_start_delta / max_hp_mult）。纯函数，改 run。
## hazard_node_count_delta 不在此（在 init_run 调 generate_map 前读）。
## kit/hazard_baseline/ai/morale/roster/credit 等 downstream hook 由 BB2/battle.gd/HUB 运行时读。
static func apply_init_hooks(run: RunState, meta: MetaState) -> void:
	var ms: Dictionary = run.modifier_state
	# relation_start_delta：所有非 F8 派系关系 += delta（F8 = 隐世派锁死 -100）
	if ms.has("relation_start_delta"):
		var delta: int = int(ms["relation_start_delta"])
		for fid in run.faction_relations:
			if fid != "F8":
				run.faction_relations[fid] = maxi(-100, int(run.faction_relations[fid]) + delta)
	# max_hp_mult：主角（roster 全员）max_hp/hp × mult
	if ms.has("max_hp_mult"):
		var mult: float = float(ms["max_hp_mult"])
		for i in range(run.player_roster.size()):
			var pd: Dictionary = run.player_roster[i]
			var mhp: int = int(round(int(pd["max_hp"]) * mult))
			pd["max_hp"] = mhp
			pd["hp"] = mhp
			run.player_roster[i] = pd

## 主角 unit_persist_dict（T4 §6.2）。kit_ids = 全部 T1 解锁招（五势圆融）。
static func _protagonist(t1_ids: Array) -> Dictionary:
	return {
		"id": "protagonist", "team": 0, "hp": 34, "max_hp": 34,
		"opening": 0, "max_opening": 6,
		"stance": Stance.Id.METAL, "grid_pos": [1, 3], "facing": 0,
		"guard_broken": false, "alive": true,
		"display_name": "遗照", "faction_id": "F1", "personality_id": "brain",
		"kit_ids": t1_ids.duplicate(), "is_protagonist": true,
	}

## 招募队友 unit_persist_dict（与 _protagonist 对称，纯函数 JSON-safe）。
## roster_index = 招募时 roster 大小（决定 id 后缀 + grid_pos 槽，hub 传入不在此 roll）。
## hp=18 略低于主角 20（"主角是天命"叙事）；kit=派系招牌 2 招全带；is_protagonist:false（死不结束局）。
static func _ally(faction_id: String, roster_index: int) -> Dictionary:
	return {
		"id": "ally_%s_%d" % [faction_id, roster_index],
		"team": 0, "hp": 26, "max_hp": 26,
		"opening": 0, "max_opening": 6,
		"stance": FactionData.stance_for(faction_id),
		"grid_pos": (FactionData.PLAYER_SLOTS[roster_index] as Array).duplicate(),
		"facing": 0, "guard_broken": false, "alive": true,
		"display_name": _ally_display_name(faction_id),
		"faction_id": faction_id,
		"personality_id": FactionData.tendency(faction_id),
		"kit_ids": (FactionData.SIGNATURE_KITS.get(faction_id, []) as Array).duplicate(),
		"is_protagonist": false,
	}

## 队友名（派系 → ALLY_GIVEN_NAMES 查表，兜底"同袍"）。
static func _ally_display_name(faction_id: String) -> String:
	return String(FactionData.ALLY_GIVEN_NAMES.get(faction_id, "同袍"))
