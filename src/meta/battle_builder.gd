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
	for ed in node_cfg.get("enemies", []):
		units.append(_unit_from_enemy(ed))
	s.units = units
	s.hazard_modifiers = node_cfg.get("hazard", {})
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
	u.hp = 20; u.max_hp = 20
	u.kit = _build_kit(ed.get("kit",[]), RunState.new())   # 敌方无 variant（run 空）
	return u

## kit_ids -> Technique[]（查表 find + variant 覆盖）。未知 id 跳过（find 返回 null）。
static func _build_kit(kit_ids: Array, run: RunState) -> Array:
	var kit: Array = []
	for tid in kit_ids:
		var t: Technique = TechniqueDB.find(StringName(tid))
		if t == null:
			continue   # 未知 id 跳过（不崩）
		if run.technique_variants.has(tid):
			t = Technique.apply_variant(t, StringName(run.technique_variants[tid]))
		kit.append(t)
	return kit
