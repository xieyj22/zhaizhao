class_name AIController
extends RefCounted

## L1 效用 AI（spec §5.1/§6）。纯逻辑，seeded 确定可复现。
## 每回合为每个 AI 单位：枚举合法行动 → 四维加权评分 + 致命加成 → top-N seeded 抽签。

class Candidate:
	extends RefCounted
	var action: Resolver.Action
	var score: float = 0.0
	func _init(a: Resolver.Action) -> void:
		action = a

## 为 ai_team 所有存活单位产出行动。kits: unit.id(String) -> Array[Technique]
static func choose_actions(state: BattleState, ai_team: int, tuning: Tuning, kits: Dictionary, rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var chosen: Array = []
	var lethal_targets: Dictionary = {}   # 已被友军致命锁定的目标 id -> true（防过杀）
	for u in state.units:
		if u.team != ai_team or not u.alive:
			continue
		var kit: Array = kits.get(String(u.id), TechniqueKit.default_kit())
		var cands := _enumerate(u, state, tuning, kit)
		for c in cands:
			c.score = _score(c.action, u, state, tuning, lethal_targets)
		if cands.is_empty():
			chosen.append(Resolver.Action.new(u, TechniqueKit.switch_to(u.stance), u.grid_pos))
			continue
		cands.sort_custom(func(x, y): return x.score > y.score)
		# 记致命目标（防后续单位过杀）
		var top_target := state.unit_at(cands[0].action.target_pos)
		if top_target != null and _is_lethal(cands[0].action, u, state, tuning):
			lethal_targets[String(top_target.id)] = true
		var n := mini(tuning.ai_top_n, cands.size())
		var pick: Candidate = cands[rng.randi_range(0, n - 1)]
		chosen.append(pick.action)
	return chosen

## 枚举合法行动：STRIKE(范围内敌方) + MOVE + STANCE_SWITCH(非当前)
static func _enumerate(u: UnitState, state: BattleState, tuning: Tuning, kit: Array) -> Array:
	var out: Array = []
	for tech in kit:
		match tech.type:
			Technique.Type.STRIKE:
				for e in state.units:
					if e.team != u.team and e.alive and RangeBand.in_range(u.grid_pos, e.grid_pos, tech.required_range, tuning):
						out.append(Candidate.new(Resolver.Action.new(u, tech, e.grid_pos)))
			Technique.Type.MOVE:
				# 退化为 no-op 的移动（被网格 clamp 回原位）不是合法/有用的候选，过滤掉。
				var dest := state.clamp_to_grid(u.grid_pos + tech.move_delta)
				if dest != u.grid_pos:
					out.append(Candidate.new(Resolver.Action.new(u, tech, u.grid_pos)))
			Technique.Type.STANCE_SWITCH:
				if tech.resulting_stance != u.stance:
					out.append(Candidate.new(Resolver.Action.new(u, tech, u.grid_pos)))
	return out

## 四维加权 + 致命加成（spec §6）
static func _score(a: Resolver.Action, u: UnitState, state: BattleState, tuning: Tuning, lethal_targets: Dictionary) -> float:
	var tech: Technique = a.technique
	var opening_value := 0.0
	var risk := 0.0
	var position_value := 0.0
	var morale_agg := 0.0
	var morale_active := Morale.phase(state.turn, tuning) != Morale.Phase.NORMAL
	var target: UnitState = state.unit_at(a.target_pos) if tech.type == Technique.Type.STRIKE else null

	if tech.type == Technique.Type.STRIKE and target != null:
		var counter := Stance.counters(u.stance, target.stance)
		var base := tech.base_damage + (tuning.counter_bonus_damage if counter else 0)
		opening_value = float(base) + floor(target.opening * tuning.opening_damage_mult)
		position_value += 1.0
		if morale_active:
			morale_agg += opening_value
		if lethal_targets.has(String(target.id)):
			opening_value *= 0.3   # 防过杀降权
	elif tech.type == Technique.Type.MOVE:
		var before := _nearest_enemy_dist(u.grid_pos, u.team, state)
		var after_pos := state.clamp_to_grid(u.grid_pos + tech.move_delta)
		var after := _nearest_enemy_dist(after_pos, u.team, state)
		position_value += float(before - after)   # 靠近=正
		if morale_active:
			morale_agg += float(before - after)
	elif tech.type == Technique.Type.STANCE_SWITCH:
		if morale_active and tech.resulting_stance >= 0 and Stance.role(tech.resulting_stance) == Stance.Role.DEFENSIVE:
			morale_agg -= 2.0   # 战意高时别龟

	# 风险：行动后自身破绽估计（攻势自叠）
	risk = float(u.opening)
	if tech.resulting_stance >= 0 and Stance.role(tech.resulting_stance) == Stance.Role.OFFENSIVE:
		risk += float(tuning.offensive_self_opening)

	var s := tuning.ai_w_opening * opening_value \
		+ tuning.ai_w_risk * (-risk) \
		+ tuning.ai_w_position * position_value \
		+ tuning.ai_w_morale * morale_agg
	if tech.type == Technique.Type.STRIKE and target != null and _is_lethal(a, u, state, tuning) and not lethal_targets.has(String(target.id)):
		s += tuning.ai_kill_bonus
	return s

static func _is_lethal(a: Resolver.Action, u: UnitState, state: BattleState, tuning: Tuning) -> bool:
	if a.technique.type != Technique.Type.STRIKE:
		return false
	var target := state.unit_at(a.target_pos)
	if target == null:
		return false
	var counter := Stance.counters(u.stance, target.stance)
	var base := a.technique.base_damage + (tuning.counter_bonus_damage if counter else 0)
	var dmg := Opening.compute_damage(base, target.opening, tuning.opening_damage_mult, target.guard_broken)
	return dmg >= target.hp

## Step 3b 版：own_team 作显式参数（而非读 state.units[0].team）。
## 锁住"units[0] 可能是玩家方"的潜在 bug —— 由第 6 个测试守护。
static func _nearest_enemy_dist(from_pos: Vector2i, own_team: int, state: BattleState) -> int:
	var best := 1 << 30
	for e in state.units:
		if e.team != own_team and e.alive:
			best = mini(best, RangeBand.distance(from_pos, e.grid_pos))
	return best
