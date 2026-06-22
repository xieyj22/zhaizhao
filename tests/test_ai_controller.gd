extends GutTest

var tu: Tuning
func before_each():
	tu = Tuning.new()

func _unit(id, team, pos, stance, hp := 20) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = hp; u.max_hp = 20
	return u

func _state(units: Array) -> BattleState:
	var s := BattleState.new()
	s.units = units
	return s

func _kits(units: Array) -> Dictionary:
	var d := {}
	for u in units:
		d[String(u.id)] = TechniqueKit.default_kit()
	return d

func test_picks_lethal_strike():
	# 敌人 hp=1，近身，AI 应选致命的近打
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD, 1)
	var s := _state([a, b])
	var actions := AIController.choose_actions(s, 1, tu, _kits(s.units), 42)
	assert_eq(actions.size(), 1)
	var act: Resolver.Action = actions[0]
	assert_eq(act.unit.id, &"a")
	assert_eq(act.technique.type, Technique.Type.STRIKE, "能杀就杀——选招是打击")
	assert_eq(act.target_pos, b.grid_pos)

func test_respects_range_when_close_only():
	# 给 AI 单位一个只有近打的 kit；敌人距离 3（MID，超 CLOSE）→ 不能打击，须移动
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(3,0), Stance.Id.WOOD)
	var s := _state([a, b])
	var kits := { String(a.id): [TechniqueKit.strike_close()] }
	# 另补移动+切架势，让 AI 有合法非打击选项
	kits[String(a.id)] += TechniqueKit.default_kit().filter(func(t): return t.type != Technique.Type.STRIKE)
	var actions := AIController.choose_actions(s, 1, tu, kits, 42)
	var act: Resolver.Action = actions[0]
	assert_ne(act.technique.type, Technique.Type.STRIKE, "超距不打击")

func test_seeded_reproducible():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD, 5)
	var s := _state([a, b])
	var r1 := AIController.choose_actions(s, 1, tu, _kits(s.units), 999)
	var r2 := AIController.choose_actions(s, 1, tu, _kits(s.units), 999)
	assert_eq(r1.size(), r2.size())
	for i in r1.size():
		assert_eq(r1[i].technique.id, r2[i].technique.id, "同 seed 同选招")
		assert_eq(r1[i].target_pos, r2[i].target_pos)

func test_score_penalizes_offensive_self_stack():
	# 直接测 _score：相同上下文下，切到攻势(METAL)比切到中和(EARTH)风险高→分低
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.EARTH)
	a.opening = 3   # 已有破绽
	var b := _unit(&"b", 0, Vector2i(5,0), Stance.Id.WOOD)
	var s := _state([a, b])
	var to_off := TechniqueKit.switch_to(Stance.Id.METAL)   # 攻势：自叠 +1 破绽
	var to_neu := TechniqueKit.switch_to(Stance.Id.EARTH)   # 中和：不自叠
	var act_off := Resolver.Action.new(a, to_off, a.grid_pos)
	var act_neu := Resolver.Action.new(a, to_neu, a.grid_pos)
	var sc_off: float = AIController._score(act_off, a, s, tu, {})
	var sc_neu: float = AIController._score(act_neu, a, s, tu, {})
	assert_lt(sc_off, sc_neu, "攻势自叠风险更高→分更低")

func test_score_rewards_aggression_under_morale():
	# 战意 NORMAL(turn4) vs ACTIVE(turn6)：切到守势(WOOD)的评分应更低（龟被罚）
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(5,0), Stance.Id.WOOD)
	var to_def := TechniqueKit.switch_to(Stance.Id.WOOD)
	var act := Resolver.Action.new(a, to_def, a.grid_pos)
	var s := _state([a, b])
	s.turn = 4
	var sc_normal: float = AIController._score(act, a, s, tu, {})
	s.turn = 6
	var sc_active: float = AIController._score(act, a, s, tu, {})
	assert_lt(sc_active, sc_normal, "战意 ACTIVE 时切守势(龟)评分更低")

# —— 第 6 用例（controller 授权追加）：锁住 Step 3b 的 `_nearest_enemy_dist(own_team)` ——
# Step 3 的朴素版读 `state.units[0].team` 当"己方"，当 units[0] 是玩家方时会误把 AI 方当友军、
# 把玩家方当敌人，MOVE 评分算反。本测把玩家放 units[0]、AI 放 units[1+]，断言 AI 仍朝玩家靠近。
func test_nearest_enemy_dist_handles_units0_not_ai():
	# units[0] = 玩家(team 0)；AI 是 team 1。朴素版会把 team 0 当"己方"→ AI 找不到敌人→ before/after 都是大数。
	# 3b 版传 own_team=1，AI 正确识别 team 0 为敌，MOVE 朝 +x（玩家方向）应得正分。
	var p := _unit(&"player", 0, Vector2i(5,0), Stance.Id.WOOD)   # 玩家在右
	var ai := _unit(&"ai", 1, Vector2i(0,0), Stance.Id.METAL)
	var s := _state([p, ai])   # units[0] 是玩家方！
	var step_right := TechniqueKit.step(1, 0)
	var act := Resolver.Action.new(ai, step_right, ai.grid_pos)
	var sc: float = AIController._score(act, ai, s, tu, {})
	# position 分：before=5, after=4 → (before-after)=1 > 0；朴素版会得 0（找不到敌人，before=after=INT_MAX）
	assert_gt(sc, 0.0, "AI(team1) 朝玩家(team0) 靠近应得正分；朴素 units[0].team 版会得 0")
