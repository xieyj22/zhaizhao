extends GutTest

const MAX_TURNS := 30   # 远超 morale_cap_turn=12，给宽裕余量防死循环

func _mk_2v2() -> BattleState:
	var s := BattleState.new()
	s.units = [
		_mk(&"p0", 0, Vector2i(1,2), Stance.Id.METAL),
		_mk(&"p1", 0, Vector2i(1,4), Stance.Id.WOOD),
		_mk(&"e0", 1, Vector2i(5,2), Stance.Id.WOOD),
		_mk(&"e1", 1, Vector2i(5,4), Stance.Id.METAL),
	]
	return s

func _mk(id, team, pos, stance) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20
	return u

func _player_actions(s: BattleState, t: Tuning, rng: RandomNumberGenerator) -> Array:
	# 玩家方每存活单位：用远打(FAR 必命中)打血最少的敌方，或随机移动
	var actions: Array = []
	for u in s.units:
		if u.team != 0 or not u.alive:
			continue
		var enemies := s.units.filter(func(e): return e.team != 0 and e.alive)
		if enemies.is_empty():
			continue
		enemies.sort_custom(func(a, b): return a.hp < b.hp)   # 集火最残
		var target: UnitState = enemies[0]
		actions.append(Resolver.Action.new(u, TechniqueKit.strike_far(), target.grid_pos))
	return actions

func test_2v2_multi_seed_terminates_with_legal_outcome():
	var outcomes: Dictionary = {}   # outcome -> count
	for sd in [1, 42, 777, 2026, 99999]:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		var s := _mk_2v2()
		var tuning := Tuning.new()
		var pm := PlayerModel.new()
		var pers := AIPersonality.brain()
		var orch := TurnOrchestrator.new(s, tuning, pm, 1)
		var kits := {}
		for u in s.units:
			if u.team == 1:
				kits[String(u.id)] = TechniqueKit.default_kit()
		var turns := 0
		while s.outcome(tuning) == BattleState.Outcome.ONGOING and turns < MAX_TURNS:
			var player := _player_actions(s, tuning, rng)
			var ai_out := AIController.choose_actions(s, 1, tuning, kits, sd * 1000 + turns, pm, pers)
			orch.reveal_and_resolve(player + ai_out.actions)
			orch.end_turn()
			turns += 1
		var oc := s.outcome(tuning)
		assert_ne(oc, BattleState.Outcome.ONGOING, "seed=%d 在 %d 回合内分胜负" % [sd, MAX_TURNS])
		assert_lt(turns, MAX_TURNS, "seed=%d 未触顶" % sd)
		assert_true(oc in [BattleState.Outcome.TEAM0_WIN, BattleState.Outcome.TEAM1_WIN, BattleState.Outcome.DRAW], "seed=%d outcome 合法" % sd)
		outcomes[oc] = outcomes.get(oc, 0) + 1
	assert_gt(outcomes.size(), 0, "至少有一个 outcome 出现")
