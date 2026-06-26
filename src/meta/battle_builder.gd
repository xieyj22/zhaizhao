class_name BattleBuilder
extends RefCounted

## RunState + 节点配置 -> BattleState（T4 §2.7 不变量 38，纯函数）。
## 玩家方 unit_persist_dict + run.technique_variants -> UnitState(+kit)；敌方 node_cfg.enemies -> UnitState(+kit)。
static func build(run: RunState, node_cfg: Dictionary) -> BattleState:
	var s := BattleState.new()
	s.grid_size = Vector2i(7, 7)
	var units: Array = []
	for pd in run.player_roster:
		units.append(_unit_from_roster(pd, run))
	# 敌方：node_cfg.boss_id 优先（boss 节点，BOSS_CONFIG 构造 + 难度曲线）；
	#       否则 node_cfg.enemies（兼容旧测试），再否则从 enemy_pool.pick 抽。
	if node_cfg.has("boss_id"):
		var boss_id: String = String(node_cfg["boss_id"])
		var bu: UnitState = _unit_from_boss(boss_id, run)
		units.append(bu)
		# trait 注入 BattleState.boss_traits（BossTrait._trait_of 读 key=boss_id）
		var cfg: Dictionary = BossConfig.get_boss(boss_id)
		var trait_name: String = String(cfg.get("trait", ""))
		if trait_name != "":
			s.boss_traits[boss_id] = trait_name
	else:
		var enemies: Array = node_cfg.get("enemies", [])
		if enemies.is_empty() and node_cfg.has("node_type"):
			var ec: Dictionary = EnemyPool.pick(run.current_chapter, String(node_cfg["node_type"]), int(node_cfg.get("risk", 0)), run.rng_seed)
			enemies = ec["enemies"]
		for ed in enemies:
			units.append(_unit_from_enemy(ed))
	s.units = units
	# hazard：node_cfg.hazard ∪ modifier hazard_baseline（深合并）
	var hz: Dictionary = node_cfg.get("hazard", {})
	var baseline: Dictionary = run.modifier_state.get("hazard_baseline", {})
	for k in baseline:
		hz[k] = baseline[k]
	s.hazard_modifiers = hz
	return s

static func _unit_from_roster(pd: Dictionary, run: RunState) -> UnitState:
	var u := UnitState.from_dict(pd)   # 填 11 个战斗字段
	u.id = StringName(pd.get("id","u"))
	u.kit = _build_kit(pd.get("kit_ids",[]), run)
	return u

static func _unit_from_enemy(ed: Dictionary) -> UnitState:
	var u := UnitState.new()
	u.id = StringName(ed.get("id","e"))
	u.team = 1
	var gp: Array = ed.get("grid_pos",[5,3])
	u.grid_pos = Vector2i(gp[0], gp[1])
	u.stance = ed.get("stance", Stance.Id.METAL)
	# 读 pool 敌人 hp（T10b：修固定 20 bug——pool 敌人有 hp 字段 16-34/40/48/50/65，此前被压平成 20）
	var hp := int(ed.get("hp", 20))
	u.hp = hp
	u.max_hp = hp
	u.kit = _build_kit(ed.get("kit",[]), RunState.new())   # 敌方无 variant（run 空）
	u.display_name = String(ed.get("display_name", "敌方"))   # 普通敌人兜底"敌方"（不显示裸 id）
	return u

## boss 敌方单位：查 BOSS_CONFIG 取 personality/stance/kit/hp_base。
## hp 按章难度曲线缩放：hp_base × (1+0.15(chapter-1)) × boss 强化倍率（章3×1.3/章4×1.6/他×1.0）。
## product §4.6 曲线 + §5.5 boss 强化。boss_id 标注（BossTrait._trait_of 读）。
static func _unit_from_boss(boss_id: String, run: RunState) -> UnitState:
	var cfg: Dictionary = BossConfig.get_boss(boss_id)
	var u := UnitState.new()
	u.id = StringName(boss_id)
	u.team = 1
	u.boss_id = boss_id
	u.grid_pos = Vector2i(5, 3)
	u.stance = int(cfg.get("stance", Stance.Id.METAL))
	var hp := _scaled_boss_hp(int(cfg.get("hp_base", 20)), run.current_chapter)
	u.hp = hp
	u.max_hp = hp
	u.display_name = String(cfg.get("name", String(u.id)))   # 显示"颜无咎"而非"yanwujiu"
	u.kit = _build_kit(cfg.get("kit", []), run)
	return u

## 章节难度曲线 + boss 强化倍率（product §4.6 + §5.5）。
## 曲线：hp_base × (1 + 0.15 × (chapter-1))（章1×1.0 ... 章4×1.45）。
## boss 强化（叠加）：章3×1.3 / 章4×1.6 / 章1·2×1.0。
static func _scaled_boss_hp(hp_base: int, chapter: int) -> int:
	var curve_mult: float = 1.0 + 0.15 * float(chapter - 1)
	var boss_mult: float = 1.0
	match chapter:
		3:
			boss_mult = 1.3
		4:
			boss_mult = 1.6
	var hp: float = float(hp_base) * curve_mult * boss_mult
	return int(round(hp))

## kit_ids -> Technique[]（查表 find + variant 覆盖 + modifier 注入）。未知 id 跳过（find 返回 null）。
## M3.5：modifier 按招 resulting_stance 所属势施加（kit 构造期不知单位架势，故按招势）。
static func _build_kit(kit_ids: Array, run: RunState) -> Array:
	var kit: Array = []
	var ms: Dictionary = run.modifier_state
	var dmg_bonus: Dictionary = ms.get("kit_stance_damage_bonus", {})
	var spd_bonus: Dictionary = ms.get("kit_stance_speed_bonus", {})
	var feint_delta: float = float(ms.get("kit_feint_bonus_delta", 0.0))
	for tid in kit_ids:
		var t: Technique = TechniqueDB.find(StringName(tid))
		if t == null:
			continue   # 未知 id 跳过（不崩）
		if run.technique_variants.has(tid):
			t = Technique.apply_variant(t, StringName(run.technique_variants[tid]))
		# —— M3.5: modifier 注入（按招 resulting_stance 所属势）——
		t = _apply_modifier_to_tech(t, dmg_bonus, spd_bonus, feint_delta)
		kit.append(t)
	return kit

## modifier 注入到单招：dmg/spd bonus 按 resulting_stance、feint delta 仅 FEINT。
## 空 modifier（dmg_bonus/spd_bonus 全 {}、feint_delta 0）→ 直接返回原招（边界守护，与 M3 一致）。
static func _apply_modifier_to_tech(t: Technique, dmg_bonus: Dictionary, spd_bonus: Dictionary, feint_delta: float) -> Technique:
	if dmg_bonus.is_empty() and spd_bonus.is_empty() and feint_delta == 0.0:
		return t
	var out: Technique = t.duplicate()
	var stance_name: String = _stance_name(out.resulting_stance)
	if stance_name != "" and dmg_bonus.has(stance_name):
		out.base_damage = out.base_damage + int(dmg_bonus[stance_name])
	if stance_name != "" and spd_bonus.has(stance_name):
		out.speed = out.speed + int(spd_bonus[stance_name])
	if out.type == Technique.Type.FEINT and feint_delta != 0.0:
		out.feint_bonus_mult = out.feint_bonus_mult + feint_delta
	return out

## Stance.Id -> modifier_state 键名（"METAL"/...）；-1（MOVE 保持）无 stance bonus。
static func _stance_name(stance_id: int) -> String:
	match stance_id:
		Stance.Id.METAL: return "METAL"
		Stance.Id.WOOD: return "WOOD"
		Stance.Id.EARTH: return "EARTH"
		Stance.Id.WATER: return "WATER"
		Stance.Id.FIRE: return "FIRE"
		_: return ""   # -1（MOVE/保持）无 stance bonus
