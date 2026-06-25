class_name AIController
extends RefCounted

## L1+L2+L3 AI（design §5）。纯逻辑，seeded 确定可复现。
## 每回合为每个 AI 单位：枚举合法行动(+feint 注入) → L1 四维 + L2 predict + 致命加成 → top-N seeded。
## 预测只来自 PlayerModel 历史统计（L4 反全知），不读玩家本回合 action。

class Candidate:
	extends RefCounted
	var action: Resolver.Action
	var score: float = 0.0
	func _init(a: Resolver.Action) -> void:
		action = a

## 返回 {actions: Array, predictions: Dictionary(被预测方 id -> 预测招大类)}
static func choose_actions(state: BattleState, ai_team: int, tuning: Tuning, kits: Dictionary, rng_seed: int, player_model: PlayerModel, personality: AIPersonality) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var chosen: Array = []
	var predictions: Dictionary = {}
	var lethal_targets: Dictionary = {}
	for u in state.units:
		if u.team != ai_team or not u.alive:
			continue
		var nearest := _nearest_enemy(u, state)
		if nearest != null:
			var key := player_model.featurize(nearest, state, tuning)
			# —— M4: BossTrait.predict_confidence（mind_eye → 1.0；空 trait 等价原 confidence）——
			var conf := BossTrait.predict_confidence(state, u, player_model.confidence(key, tuning))
			if conf > 0.0:
				predictions[String(nearest.id)] = player_model.argmax_type(key)
		var kit: Array = kits.get(String(u.id), TechniqueKit.default_kit())
		var cands := _enumerate(u, state, tuning, kit)
		if personality != null and rng.randf() < personality.feint_rate and nearest != null:
			cands.append(Candidate.new(_make_feint(u, nearest, tuning)))
		for c in cands:
			c.score = _score(c.action, u, state, tuning, lethal_targets, player_model, personality, nearest)
		if cands.is_empty():
			chosen.append(Resolver.Action.new(u, TechniqueKit.switch_to(u.stance), u.grid_pos))
			continue
		cands.sort_custom(func(x, y): return x.score > y.score)
		var top_target := state.unit_at(cands[0].action.target_pos)
		if top_target != null and _is_lethal(cands[0].action, u, state, tuning):
			lethal_targets[String(top_target.id)] = true
		var n := maxi(1, mini(int(round(tuning.ai_top_n * (personality.top_n_mul if personality != null else 1.0))), cands.size()))
		var pick: Candidate = cands[rng.randi_range(0, n - 1)]
		chosen.append(pick.action)
	return {"actions": chosen, "predictions": predictions}

static func _enumerate(u: UnitState, state: BattleState, tuning: Tuning, kit: Array) -> Array:
	var out: Array = []
	for tech in kit:
		# —— M3: ban_close 险地（距离禁制）禁用 CLOSE 打击/虚招 ——
		if state.hazard_modifiers.get("ban_close", false) and (tech.type == Technique.Type.STRIKE or tech.type == Technique.Type.FEINT) and tech.required_range == RangeBand.Id.CLOSE:
			continue
		match tech.type:
			Technique.Type.STRIKE, Technique.Type.FEINT:
				for e in state.units:
					if e.team != u.team and e.alive and RangeBand.in_range(u.grid_pos, e.grid_pos, tech.required_range, tuning):
						out.append(Candidate.new(Resolver.Action.new(u, tech, e.grid_pos)))
			Technique.Type.MOVE:
				var dest := state.clamp_to_grid(u.grid_pos + tech.move_delta)
				if dest != u.grid_pos:
					out.append(Candidate.new(Resolver.Action.new(u, tech, u.grid_pos)))
			Technique.Type.STANCE_SWITCH:
				if tech.resulting_stance != u.stance:
					out.append(Candidate.new(Resolver.Action.new(u, tech, u.grid_pos)))
	return out

static func _make_feint(u: UnitState, target: UnitState, tuning: Tuning) -> Resolver.Action:
	var t := Technique.new()
	t.id = &"feint_strike"; t.display_name = "虚招·诱打"
	t.type = Technique.Type.FEINT
	t.required_range = RangeBand.Id.FAR
	t.base_damage = 4; t.speed = 5; t.opening_dealt = 1
	t.resulting_stance = u.stance
	t.apparent_stance = Stance.counter_of(target.stance)
	return Resolver.Action.new(u, t, target.grid_pos)

static func _score(a: Resolver.Action, u: UnitState, state: BattleState, tuning: Tuning, lethal_targets: Dictionary, player_model: PlayerModel, personality: AIPersonality, nearest: UnitState) -> float:
	var tech: Technique = a.technique
	var w_opening := tuning.ai_w_opening * (personality.aggression if personality != null else 1.0)
	var w_risk := tuning.ai_w_risk * (personality.caution if personality != null else 1.0)
	var w_position := tuning.ai_w_position
	var w_morale := tuning.ai_w_morale * (personality.aggression if personality != null else 1.0)
	var w_predict := tuning.ai_w_predict * (personality.w_predict_mul if personality != null else 1.0)

	var opening_value := 0.0
	var risk := 0.0
	var position_value := 0.0
	var morale_agg := 0.0
	var predict_value := 0.0
	var morale_active := Morale.phase(state.turn, tuning) != Morale.Phase.NORMAL
	var target: UnitState = state.unit_at(a.target_pos) if (tech.type == Technique.Type.STRIKE or tech.type == Technique.Type.FEINT) else null

	if nearest != null:
		var key := player_model.featurize(nearest, state, tuning)
		if player_model.confidence(key, tuning) > 0.0:
			var pred := player_model.argmax_type(key)
			match pred:
				Technique.Type.STRIKE:
					# 预测对方打击 → 切守势反制（design §2.2 spec 值 +2.0）
					# 维度权重靠 Tuning.ai_w_predict × AIPersonality.w_predict_mul 缩放
					if tech.type == Technique.Type.STANCE_SWITCH and tech.resulting_stance >= 0 and Stance.role(tech.resulting_stance) == Stance.Role.DEFENSIVE:
						predict_value += 2.0
					# 快打击抢先手压制对方的打击（spec +0.8）
					elif tech.type == Technique.Type.STRIKE and tech.speed >= 5:
						predict_value += 0.8
				Technique.Type.STANCE_SWITCH:
					# 预测对方龟 → 打击破龟（spec +1.5）
					if tech.type == Technique.Type.STRIKE:
						predict_value += 1.5
				Technique.Type.MOVE:
					# 预测对方走位 → 打击抓位移（spec +0.5）
					if tech.type == Technique.Type.STRIKE:
						predict_value += 0.5
				Technique.Type.FEINT:
					predict_value -= 1.0

	if tech.type == Technique.Type.STRIKE and target != null:
		var counter := Stance.counters(u.stance, target.stance)
		var base := tech.base_damage + (tuning.counter_bonus_damage if counter else 0)
		opening_value = float(base) + floor(target.opening * tuning.opening_damage_mult)
		position_value += 1.0
		if morale_active:
			morale_agg += opening_value
		if lethal_targets.has(String(target.id)):
			opening_value *= 0.3
	elif tech.type == Technique.Type.FEINT and target != null:
		opening_value = float(tech.base_damage) * 0.8
		position_value += 0.5
		if morale_active:
			morale_agg += opening_value * 0.5
	elif tech.type == Technique.Type.MOVE:
		var before := _nearest_enemy_dist(u.grid_pos, u.team, state)
		var after_pos := state.clamp_to_grid(u.grid_pos + tech.move_delta)
		var after := _nearest_enemy_dist(after_pos, u.team, state)
		position_value += float(before - after)
		if morale_active:
			morale_agg += float(before - after)
	elif tech.type == Technique.Type.STANCE_SWITCH:
		if morale_active and tech.resulting_stance >= 0 and Stance.role(tech.resulting_stance) == Stance.Role.DEFENSIVE:
			morale_agg -= 2.0

	risk = float(u.opening)
	if tech.resulting_stance >= 0 and Stance.role(tech.resulting_stance) == Stance.Role.OFFENSIVE:
		risk += float(tuning.offensive_self_opening)

	var s := w_opening * opening_value \
		+ w_risk * (-risk) \
		+ w_position * position_value \
		+ w_morale * morale_agg \
		+ w_predict * predict_value
	if (tech.type == Technique.Type.STRIKE) and target != null and _is_lethal(a, u, state, tuning) and not lethal_targets.has(String(target.id)):
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

static func _nearest_enemy(u: UnitState, state: BattleState) -> UnitState:
	var best: UnitState = null
	var best_d := 1 << 30
	for e in state.units:
		if e.team != u.team and e.alive:
			var d := RangeBand.distance(u.grid_pos, e.grid_pos)
			if d < best_d:
				best_d = d; best = e
	return best

## own_team 作显式参数（而非读 state.units[0].team）。
static func _nearest_enemy_dist(from_pos: Vector2i, own_team: int, state: BattleState) -> int:
	var best := 1 << 30
	for e in state.units:
		if e.team != own_team and e.alive:
			best = mini(best, RangeBand.distance(from_pos, e.grid_pos))
	return best
