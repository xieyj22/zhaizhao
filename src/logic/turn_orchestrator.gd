class_name TurnOrchestrator
extends RefCounted

## 同时回合四相编排（M0 + M1 战意/架势角色）。
## - 谋：本类不管输入（UI/AI 负责，各自把 Action 喂进来）
## - 揭：reveal_and_resolve()
## - 变：end_turn()
var state: BattleState
var tuning: Tuning

func _init(s: BattleState, t: Tuning) -> void:
	state = s
	tuning = t

## 揭：双方行动同时揭晓 → 确定性结算（就地改 state）
func reveal_and_resolve(actions: Array) -> Resolver.Result:
	return Resolver.resolve(actions, state, tuning)

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
