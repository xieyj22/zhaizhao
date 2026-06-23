class_name Resolver
extends RefCounted

## 确定性揭晓结算（spec §2.5 + M2 虚招 §2.3）。纯逻辑，就地修改 BattleState。

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

## 感知架势（M2 §2.3）：FEINT 出招者对外 = apparent_stance；否则真实。
## _compare 与 _compute_lured 都用这个，让双方都按「看到的」表象判断。
static func _perceived_stance(unit: UnitState, action: Action) -> int:
	if action.technique != null and action.technique.type == Technique.Type.FEINT and action.technique.apparent_stance >= 0:
		return action.technique.apparent_stance
	return unit.stance

## 主入口：给定双方行动 + 状态 + 调参，确定性结算（就地改 state）
static func resolve(actions: Array, state: BattleState, tuning: Tuning) -> Result:
	var result := Result.new()
	var lured := _compute_lured(actions)   # FEINT action(obj) -> 是否诱骗成功
	var order := _sort_actions(actions)
	for a in order:
		if a.unit == null or not a.unit.alive:
			continue
		_apply_one(a, state, tuning, result, lured)
	return result

## 预计算：哪些 FEINT 招成功诱骗了对手（对手按 apparent 针对了它）
static func _compute_lured(actions: Array) -> Dictionary:
	var lured := {}
	for a in actions:
		if a.technique == null or a.technique.type != Technique.Type.FEINT:
			continue
		if a.technique.apparent_stance < 0:
			continue   # 非伪装 FEINT，不进上钩判定
		var x: int = a.technique.apparent_stance
		var hooked := false
		for b in actions:
			if b == a or b.unit == null:
				continue
			if b.unit.team != a.unit.team and b.unit.alive:
				if Stance.counters(_perceived_stance(b.unit, b), x):
					hooked = true
					break
		lured[a] = hooked
	return lured

## 优先级：速度降序 → 感知架势克制（克制方先）→ team 升序 → 原索引升序
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
	# 2) 感知架势克制（M2：用 perceived；互克在 5 环里不可能，异或安全）
	var a_cb := Stance.counters(_perceived_stance(act_a.unit, act_a), _perceived_stance(act_b.unit, act_b))
	var b_ca := Stance.counters(_perceived_stance(act_b.unit, act_b), _perceived_stance(act_a.unit, act_a))
	if a_cb != b_ca:
		return a_cb
	# 3) team 升序
	if act_a.unit.team != act_b.unit.team:
		return act_a.unit.team < act_b.unit.team
	# 4) 原索引升序
	return a[1] < b[1]

static func _apply_one(a: Action, state: BattleState, tuning: Tuning, result: Result, lured: Dictionary) -> void:
	var u: UnitState = a.unit
	var t: Technique = a.technique
	match t.type:
		Technique.Type.MOVE:
			u.grid_pos = state.clamp_to_grid(u.grid_pos + t.move_delta)
			result.log.append("%s 移动到 %s" % [String(u.id), u.grid_pos])
		Technique.Type.STANCE_SWITCH:
			# 仅切架势，不造成效果
			result.log.append("%s 切换架势" % String(u.id))
		Technique.Type.STRIKE, Technique.Type.FEINT:
			var target := state.unit_at(a.target_pos)
			if target == null or not target.alive:
				result.log.append("%s 打空" % String(u.id))
			else:
				var base: int = t.base_damage
				var mult := 1.0
				var verb := "命中"
				if t.type == Technique.Type.FEINT:
					if t.apparent_stance >= 0:
						# 伪装 FEINT：上钩→奖励倍率；识破→落空倍率
						mult = t.feint_bonus_mult if lured.get(a, false) else t.feint_fail_mult
						verb = "虚招诱中" if lured.get(a, false) else "虚招落空"
					# apparent<0：伪装打击但不诱骗，mult 维持 1.0（同 STRIKE）
				base = int(round(base * mult))
				var counters := Stance.counters(u.stance, target.stance)
				base += tuning.counter_bonus_damage if counters else 0
				var dmg: int = Opening.compute_damage(base, target.opening, tuning.opening_damage_mult, target.guard_broken)
				target.hp -= dmg
				target.opening += t.opening_dealt + (tuning.counter_bonus_opening if counters else 0)
				if target.opening >= target.max_opening:
					target.guard_broken = true
				if target.hp <= 0:
					target.hp = 0
					target.alive = false
				result.log.append("%s %s %s：-%d HP" % [String(u.id), verb, String(target.id), dmg])
		Technique.Type.SPECIAL:
			# M2 仍占位（spec §2.3 特技完整语义留后续）
			result.log.append("%s 使出 %s（占位）" % [String(u.id), String(t.id)])
	# 出招后统一进入 resulting_stance；MOVE 用 -1 表示保持当前架势（不赋值）
	if t.resulting_stance >= 0:
		u.stance = t.resulting_stance
