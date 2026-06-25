class_name BossTrait
extends RefCounted

## boss 独有机制（M4 product §5.2）。纯函数，空 trait 全 noop（M0-M2 边界守护）。
## state.boss_traits = {boss_id: trait_name}；unit.boss_id 标识 boss 单位。
## 接入点：resolver (opening_delta/feint_mult) / ai_controller (predict_confidence) /
##         turn_orchestrator (on_end_turn + mind_eye 反制伤)。

## 取 unit 对应 trait 名（unit 无 boss_id 或 dict 缺 → ""）。
static func _trait_of(state: BattleState, u: UnitState) -> String:
	if u == null:
		return ""
	return String(state.boss_traits.get(u.boss_id, ""))

## 受破绽调整（resolver:116）。iron_body → delta-1（min 0）；否则原值。
static func opening_delta(state: BattleState, target: UnitState, delta: int) -> int:
	if _trait_of(state, target) == "iron_body":
		return maxi(0, delta - 1)
	return delta

## 虚招倍率（resolver:108）。
## chain_feint → 落空1.0（不受 fail_mult）/ 上钩 bonus_mult+0.5；否则原 mult。
static func feint_mult(state: BattleState, attacker: UnitState, is_lured: bool, fail_mult: float, bonus_mult: float) -> float:
	if _trait_of(state, attacker) == "chain_feint":
		return (bonus_mult + 0.5) if is_lured else 1.0
	return bonus_mult if is_lured else fail_mult

## 读招置信（ai_controller:28）。mind_eye → 1.0（始终读中）；否则 base。
static func predict_confidence(state: BattleState, boss: UnitState, base: float) -> float:
	if _trait_of(state, boss) == "mind_eye":
		return 1.0
	return base

## 回合末（turn_orchestrator:54）。
## frenzy：hp<50% 标 frenzied（resolver:114 用 frenzied 把 dmg×1.5）。
## blood_drain：吸「玩家方本回合受损总量」30%（damage_taken_by_player 值求和）。
## damage_taken_by_player: {玩家方 unit id: 本回合受损量}（turn_orchestrator 传入）；空=无人受伤=不吸。
static func on_end_turn(state: BattleState, damage_taken_by_player: Dictionary) -> void:
	# blood_drain 先算总吸血量（所有玩家单位本回合受损之和），再分给每个 blood_drain boss
	var total_player_damage: int = 0
	for _id in damage_taken_by_player:
		total_player_damage += int(damage_taken_by_player[_id])
	for u in state.units:
		var tr := _trait_of(state, u)
		if tr == "frenzy" and u.alive and float(u.hp) < float(u.max_hp) * 0.5:
			u.frenzied = true
		elif tr == "blood_drain" and u.alive:
			var gained: int = int(float(total_player_damage) * 0.3)
			u.hp = mini(u.max_hp, u.hp + gained)

## mind_eye 反制伤（turn_orchestrator reveal_and_resolve 后处理）。
## boss 是 mind_eye 且本回合预测命中玩家实际招 → 玩家额外 -2 hp。
## predictions: {被预测方 unit id: 预测招大类}；actions 含玩家实际招。
static func mind_eye_counter(state: BattleState, predictions: Dictionary, actions: Array) -> void:
	# 收集所有 mind_eye boss 的 id（反制来源）
	var mind_eye_ids: Dictionary = {}
	for u in state.units:
		if u.alive and _trait_of(state, u) == "mind_eye":
			mind_eye_ids[String(u.id)] = true
	if mind_eye_ids.is_empty():
		return
	# 实际招 by unit id
	var actual_by_unit: Dictionary = {}
	for a in actions:
		if a.unit != null:
			actual_by_unit[String(a.unit.id)] = a.technique.type
	# 对每个被预测且命中的单位（玩家方），-2 hp（仅当本局有 mind_eye boss）
	# 注：反制来源是 mind_eye boss，但 predictions 由 ai_controller 对每个 AI 单位的 nearest enemy 生成；
	# 命中即代表 boss 读中了该单位 → 该单位受 -2。
	for unit_id in predictions:
		if not actual_by_unit.has(unit_id):
			continue
		var predicted: int = predictions[unit_id]
		var actual: int = actual_by_unit[unit_id]
		if predicted == actual:
			# 找到该单位扣血（反制来源是任意 mind_eye boss，效果合并 -2 一次）
			var target := _find_unit(state, unit_id)
			if target != null and target.alive:
				target.hp = maxi(0, target.hp - 2)
				if target.hp <= 0:
					target.alive = false

static func _find_unit(state: BattleState, unit_id: String) -> UnitState:
	for u in state.units:
		if String(u.id) == unit_id:
			return u
	return null
