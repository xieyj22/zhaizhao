class_name Resolver
extends RefCounted

## 确定性揭晓结算（spec §2.5）。纯逻辑，就地修改 BattleState。

class Action:
	extends RefCounted
	var unit: UnitState
	var technique: Technique
	var target_pos: Vector2i
	func _init(u: UnitState = null, t: Technique = null, p: Vector2i = Vector2i.ZERO) -> void:
		unit = u; technique = t; target_pos = p

class Result:
	extends RefCounted
	var log: Array = []     # 文字日志（调试/回放）

## 主入口：给定双方行动 + 状态 + 调参，确定性结算（就地改 state）
static func resolve(actions: Array, state: BattleState, tuning: Tuning) -> Result:
	var result := Result.new()
	var order := _sort_actions(actions)
	for a in order:
		if a.unit == null or not a.unit.alive:
			continue
		_apply_one(a, state, tuning, result)
	return result

## 优先级：速度降序 → 架势克制（克制方先）→ team 升序 → 原索引升序
static func _sort_actions(actions: Array) -> Array:
	var keyed: Array = []
	for i in actions.size():
		keyed.append([actions[i], i])
	keyed.sort_custom(_compare)
	return keyed.map(func(e): return e[0])

static func _compare(a: Array, b: Array) -> bool:
	var act_a: Action = a[0]
	var act_b: Action = b[0]
	# 1) 速度降序
	if act_a.technique.speed != act_b.technique.speed:
		return act_a.technique.speed > act_b.technique.speed
	# 2) 架势克制（互克在 5 环里不可能，故异或安全）
	var a_cb := Stance.counters(act_a.unit.stance, act_b.unit.stance)
	var b_ca := Stance.counters(act_b.unit.stance, act_a.unit.stance)
	if a_cb != b_ca:
		return a_cb
	# 3) team 升序
	if act_a.unit.team != act_b.unit.team:
		return act_a.unit.team < act_b.unit.team
	# 4) 原索引升序
	return a[1] < b[1]

static func _apply_one(a: Action, state: BattleState, tuning: Tuning, result: Result) -> void:
	var u: UnitState = a.unit
	var t: Technique = a.technique
	match t.type:
		Technique.Type.MOVE:
			u.grid_pos = state.clamp_to_grid(u.grid_pos + t.move_delta)
			result.log.append("%s 移动到 %s" % [String(u.id), u.grid_pos])
		Technique.Type.STANCE_SWITCH:
			# 仅切架势，不造成效果
			result.log.append("%s 切换架势" % String(u.id))
		Technique.Type.STRIKE:
			var target := state.unit_at(a.target_pos)
			if target == null or not target.alive:
				result.log.append("%s 打空" % String(u.id))
			else:
				var counters := Stance.counters(u.stance, target.stance)
				var bonus_dmg: int = tuning.counter_bonus_damage if counters else 0
				var bonus_op: int = tuning.counter_bonus_opening if counters else 0
				var base: int = t.base_damage + bonus_dmg
				var dmg: int = Opening.compute_damage(base, target.opening, tuning.opening_damage_mult, target.guard_broken)
				target.hp -= dmg
				target.opening += t.opening_dealt + bonus_op
				if target.opening >= target.max_opening:
					target.guard_broken = true
				if target.hp <= 0:
					target.hp = 0
					target.alive = false
				result.log.append("%s 命中 %s：-%d HP" % [String(u.id), String(target.id), dmg])
		Technique.Type.FEINT, Technique.Type.SPECIAL:
			# M0 占位：虚招/特技完整语义留 M2（spec §2.3）
			result.log.append("%s 使出 %s（M0 占位）" % [String(u.id), String(t.id)])
	# 出招后统一进入 resulting_stance（MOVE 时调用方设为原架势）
	u.stance = t.resulting_stance
