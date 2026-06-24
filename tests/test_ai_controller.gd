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
	var s := BattleState.new(); s.units = units; return s

func _kits(units: Array) -> Dictionary:
	var d := {}
	for u in units: d[String(u.id)] = TechniqueKit.default_kit()
	return d

func _choose(s, team, pm, pers, seed := 42) -> Array:
	return AIController.choose_actions(s, team, tu, _kits(s.units), seed, pm, pers).actions

func test_picks_lethal_strike_empty_model():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD, 1)
	var s := _state([a, b])
	var actions := _choose(s, 1, PlayerModel.new(), AIPersonality.new())
	assert_eq(actions.size(), 1)
	assert_eq(actions[0].technique.type, Technique.Type.STRIKE)
	assert_eq(actions[0].target_pos, b.grid_pos)

func test_respects_range_close_only():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(3,0), Stance.Id.WOOD)
	var s := _state([a, b])
	var kits := { String(a.id): ([TechniqueKit.strike_close()] + TechniqueKit.default_kit().filter(func(t): return t.type != Technique.Type.STRIKE)) }
	var actions: Array = AIController.choose_actions(s, 1, tu, kits, 42, PlayerModel.new(), AIPersonality.new()).actions
	assert_ne(actions[0].technique.type, Technique.Type.STRIKE, "超距不打击")

func test_seeded_reproducible():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD, 5)
	var s := _state([a, b])
	var pm := PlayerModel.new(); var pers := AIPersonality.new()
	var r1: Array = AIController.choose_actions(s, 1, tu, _kits(s.units), 999, pm, pers).actions
	var r2: Array = AIController.choose_actions(s, 1, tu, _kits(s.units), 999, pm, pers).actions
	assert_eq(r1.size(), r2.size())
	for i in r1.size():
		assert_eq(r1[i].technique.id, r2[i].technique.id)

func test_model_predicts_strike_ai_defends():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD)
	var s := _state([a, b])
	var pm := PlayerModel.new()
	for i in 6:
		pm.observe(pm.featurize(b, s, tu), Technique.Type.STRIKE, String(b.id))
	var saw_defensive := false
	for sd in [1, 2, 3, 4, 5]:
		var actions := _choose(s, 1, pm, AIPersonality.brain(), sd)
		if actions[0].technique.type == Technique.Type.STANCE_SWITCH and Stance.role(actions[0].technique.resulting_stance) == Stance.Role.DEFENSIVE:
			saw_defensive = true
	assert_true(saw_defensive, "brain 在对方偏 STRIKE 下，多 seed 至少一次切守势")

func test_brute_ignores_l2():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD)
	var s := _state([a, b])
	var pm := PlayerModel.new()
	for i in 6: pm.observe(pm.featurize(b, s, tu), Technique.Type.STRIKE, String(b.id))
	var actions := _choose(s, 1, pm, AIPersonality.brute())
	assert_eq(actions.size(), 1)

func test_trick_injects_feint():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD)
	var s := _state([a, b])
	var saw_feint := false
	for sd in [1, 2, 3, 4, 5, 6, 7, 8]:
		var actions := _choose(s, 1, PlayerModel.new(), AIPersonality.trick(), sd)
		for act in actions:
			if act.technique.type == Technique.Type.FEINT:
				saw_feint = true
	assert_true(saw_feint, "trick 多 seed 至少出一次虚招")

func test_predictions_returned_for_read_events():
	var a := _unit(&"a", 1, Vector2i(0,0), Stance.Id.METAL)
	var b := _unit(&"b", 0, Vector2i(1,0), Stance.Id.WOOD)
	var s := _state([a, b])
	var pm := PlayerModel.new()
	for i in 6: pm.observe(pm.featurize(b, s, tu), Technique.Type.STRIKE, String(b.id))
	var out := AIController.choose_actions(s, 1, tu, _kits(s.units), 42, pm, AIPersonality.brain())
	assert_true(out.has("predictions"), "返回预测快照供 read_events")
	if out.predictions.has(String(b.id)):
		assert_eq(out.predictions[String(b.id)], Technique.Type.STRIKE, "预测 = 频率最高者")

func test_no_omniscience_signature():
	var inst := AIController.new()
	assert_true(inst.has_method("choose_actions"))
	assert_true(inst.has_method("_score"))

# —— M3 Task TO: ban_close 险地（距离禁制）——
func test_ban_close_filters_close_strikes():
	# AI 单位与玩家单位相邻(CLOSE)，kit 只给 close+far 两招 STRIKE。
	# ban_close=true：AI 的 STRIKE 候选不含 CLOSE 档 → 只剩 far(超距不可达) → 不应选 CLOSE 打击。
	var a := _unit(&"ai", 1, Vector2i(2,2), Stance.Id.METAL)
	var b := _unit(&"p",  0, Vector2i(2,3), Stance.Id.WOOD)   # 距离 1 = CLOSE
	var s := _state([a, b])
	s.hazard_modifiers = {"ban_close": true}
	var kits := { String(a.id): [TechniqueKit.strike_close(), TechniqueKit.strike_far()] }
	var out := AIController.choose_actions(s, 1, tu, kits, 1, PlayerModel.new(), AIPersonality.brute())
	assert_not_null(out)
	for act in out.actions:
		if act.technique.type == Technique.Type.STRIKE:
			assert_ne(act.technique.required_range, RangeBand.Id.CLOSE, "ban_close 下 AI 不选 CLOSE 打击")

func test_ban_close_default_is_noop():
	# hazard_modifiers={} 时 AI 仍可选 CLOSE 打击（border guard）
	var a := _unit(&"ai", 1, Vector2i(2,2), Stance.Id.METAL)
	var b := _unit(&"p",  0, Vector2i(2,3), Stance.Id.WOOD)
	var s := _state([a, b])
	s.hazard_modifiers = {}
	var kits := { String(a.id): [TechniqueKit.strike_close()] }   # 只有 close
	var out := AIController.choose_actions(s, 1, tu, kits, 1, PlayerModel.new(), AIPersonality.brute())
	var saw_close := false
	for act in out.actions:
		if act.technique.type == Technique.Type.STRIKE and act.technique.required_range == RangeBand.Id.CLOSE:
			saw_close = true
	assert_true(saw_close, "无 ban_close：AI 仍可选 CLOSE 打击")
