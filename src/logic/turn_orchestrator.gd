class_name TurnOrchestrator
extends RefCounted

## 同时回合四相编排（M0 + M1 战意/角色 + M2 玩家建模/读招反馈）。
## - 谋：本类不管输入（UI/AI 负责，各自把 Action 喂进来）
## - 揭：reveal_and_resolve()（揭晓前 featurize、揭晓后 observe 玩家出招）
## - 变：end_turn()
var state: BattleState
var tuning: Tuning
var player_model: PlayerModel
var ai_team: int

func _init(s: BattleState, t: Tuning, pm: PlayerModel = null, p_ai_team: int = 1) -> void:
	state = s
	tuning = t
	player_model = pm if pm != null else PlayerModel.new()
	ai_team = p_ai_team

## 揭：双方行动同时揭晓 → 确定性结算；揭晓前 featurize、揭晓后 observe 玩家出招。
func reveal_and_resolve(actions: Array) -> Resolver.Result:
	# resolve 前算特征 key（用揭晓前 state）——玩家方（team != ai_team）
	var pre_keys: Dictionary = {}
	if player_model != null:
		for a in actions:
			if a.unit != null and a.unit.team != ai_team:
				pre_keys[a.unit] = player_model.featurize(a.unit, state, tuning)
	var r := Resolver.resolve(actions, state, tuning)
	# resolve 后用 pre_keys + 实际招 observe
	if player_model != null:
		for a in actions:
			if a.unit != null and a.unit.team != ai_team and pre_keys.has(a.unit):
				player_model.observe(pre_keys[a.unit], a.technique.type, String(a.unit.id))
	return r

## 读招反馈：AI 预测 vs 玩家实际。predictions: 被预测方 id -> 预测招大类；actions 含实际招。
static func compute_read_events(predictions: Dictionary, actions: Array) -> Array:
	var actual_by_unit: Dictionary = {}
	for a in actions:
		if a.unit != null:
			actual_by_unit[String(a.unit.id)] = a.technique.type
	var events: Array = []
	for unit_id in predictions:
		var predicted: int = predictions[unit_id]
		var actual: int = actual_by_unit.get(unit_id, -1)
		events.append({
			"target_id": unit_id,
			"predicted": predicted,
			"actual": actual,
			"hit": predicted == actual,
		})
	return events

## 变：回合末结算 —— 架势角色(自叠) → 战意累积 → 回落(战意削减+守势奖励) → 崩溃恢复 → turn++。
func end_turn() -> void:
	for u in state.units:
		if not u.alive:
			continue
		var add := 0
		if Stance.role(u.stance) == Stance.Role.OFFENSIVE:
			add += tuning.offensive_self_opening
		add += Morale.accumulation(state.turn, tuning)
		var decay := maxi(0, tuning.opening_decay_per_turn - Morale.decay_modifier(state.turn, tuning))
		if Stance.role(u.stance) == Stance.Role.DEFENSIVE:
			decay += tuning.defensive_decay_bonus
		u.opening = clampi(u.opening + add - decay, 0, u.max_opening)
		if u.opening < u.max_opening:
			u.guard_broken = false
	state.turn += 1
