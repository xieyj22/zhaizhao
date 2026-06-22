class_name TurnOrchestrator
extends RefCounted

## 同时回合四相编排（spec §1）。
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

## 变：回合末结算 —— 破绽回落、崩溃恢复、turn 推进。
## 战意槽（§2.7 防龟缩）属 M1，这里不碰。
func end_turn() -> void:
	for u in state.units:
		if not u.alive:
			continue
		u.opening = Opening.decay(u.opening, tuning.opening_decay_per_turn)
		if u.guard_broken and u.opening < u.max_opening:
			u.guard_broken = false
	state.turn += 1
