extends GutTest

var tu: Tuning

func before_each():
	tu = Tuning.new()

func _mk_state() -> BattleState:
	var s := BattleState.new()
	var a := UnitState.new(); a.id=&"a"; a.team=0; a.grid_pos=Vector2i(1,3); a.stance=Stance.Id.EARTH
	var b := UnitState.new(); b.id=&"b"; b.team=1; b.grid_pos=Vector2i(5,3); b.stance=Stance.Id.WOOD
	s.units = [a, b]
	return s

func test_reveal_resolves_and_advances_nothing_yet():
	var s := _mk_state()
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	var hit := Technique.new()
	hit.type = Technique.Type.STRIKE; hit.base_damage=5; hit.speed=5
	hit.resulting_stance = Stance.Id.METAL; hit.opening_dealt = 1
	var res := orch.reveal_and_resolve([Resolver.Action.new(s.units[0], hit, s.units[1].grid_pos)])
	assert_gt(res.log.size(), 0)
	# turn 在 end_turn 才涨
	assert_eq(s.turn, 0)

func test_end_turn_decays_opening():
	var s := _mk_state()
	s.units[0].opening = 3
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	orch.end_turn()
	assert_eq(s.units[0].opening, 2, "回落 1")
	assert_eq(s.turn, 1)

func test_end_turn_clears_guard_break_when_opening_recovers_below_max():
	var s := _mk_state()
	s.units[0].opening = 6
	s.units[0].guard_broken = true
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	orch.end_turn()
	# opening 6→5 < max_opening 6 → 崩溃解除
	assert_false(s.units[0].guard_broken)

func test_state_reports_over_after_kill_via_orchestrator():
	var s := _mk_state()
	s.units[1].hp = 1
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	var hit := Technique.new()
	hit.type = Technique.Type.STRIKE; hit.base_damage=5; hit.speed=5
	hit.resulting_stance = Stance.Id.METAL; hit.opening_dealt = 0
	orch.reveal_and_resolve([Resolver.Action.new(s.units[0], hit, s.units[1].grid_pos)])
	assert_true(s.is_over())

# —— M1 Task 6: end_turn 战意 + 架势角色 ——
func _mk_with(stances: Array) -> BattleState:
	# stances: [unit0_stance, unit1_stance, ...]，全 team 0，便于隔离测 opening 变化
	var s := BattleState.new()
	for i in stances.size():
		var u := UnitState.new()
		u.id = StringName("u%d" % i); u.team = 0
		u.grid_pos = Vector2i(i, 0); u.stance = stances[i]
		u.hp = 20; u.max_hp = 20; u.opening = 0
		s.units.append(u)
	return s

func test_end_turn_neutral_accumulates_under_active_morale():
	# turn=5（ACTIVE），EARTH(中和)：+1 战意累积，decay 被 −1 削到 0 → 净 +1
	var s := _mk_with([Stance.Id.EARTH])
	s.turn = 5
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	orch.end_turn()
	assert_eq(s.units[0].opening, 1)

func test_end_turn_defensive_holds_line_under_active_morale():
	# WOOD(守势)：+1 战意 − (decay 0 + 守势奖励 1) = ±0
	var s := _mk_with([Stance.Id.WOOD])
	s.turn = 5
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	orch.end_turn()
	assert_eq(s.units[0].opening, 0)

func test_end_turn_offensive_self_stacks_fast_under_active_morale():
	# METAL(攻势)：+1 自叠 +1 战意 − 0 decay = +2
	var s := _mk_with([Stance.Id.METAL])
	s.turn = 5
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	orch.end_turn()
	assert_eq(s.units[0].opening, 2)

func test_end_turn_no_morale_before_threshold():
	# turn=4（NORMAL），攻势单位：只 +1 自叠（无战意），decay 正常 1 → 净 0
	var s := _mk_with([Stance.Id.METAL])
	s.turn = 4
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	orch.end_turn()
	assert_eq(s.units[0].opening, 0)

func test_end_turn_clears_guard_break_on_recovery():
	var s := _mk_with([Stance.Id.EARTH])
	s.units[0].opening = s.units[0].max_opening
	s.units[0].guard_broken = true
	s.turn = 4   # NORMAL：decay 1 → opening 回落到 max-1 < max → 解崩溃
	var orch := TurnOrchestrator.new(s, tu, PlayerModel.new(), 1)
	orch.end_turn()
	assert_false(s.units[0].guard_broken)

# —— M2 Task F1: observe + read_events ——
func test_observe_records_player_action_on_reveal():
	var s := _mk_with([Stance.Id.METAL, Stance.Id.WOOD])   # team0 两单位（玩家）
	s.turn = 4
	var pm := PlayerModel.new()
	var orch := TurnOrchestrator.new(s, tu, pm, 1)
	var hit := Technique.new()
	hit.type = Technique.Type.STRIKE; hit.base_damage = 5; hit.speed = 5
	hit.resulting_stance = Stance.Id.METAL; hit.opening_dealt = 0; hit.required_range = RangeBand.Id.FAR
	var p0: UnitState = s.units[0]
	orch.reveal_and_resolve([Resolver.Action.new(p0, hit, p0.grid_pos)])
	assert_gt(pm.total, 0, "玩家出招被记入 PlayerModel")

func test_observe_uses_pre_resolve_features():
	var s := _mk_with([Stance.Id.METAL])
	s.turn = 5
	var pm := PlayerModel.new()
	var orch := TurnOrchestrator.new(s, tu, pm, 1)
	var sw := Technique.new()
	sw.type = Technique.Type.STANCE_SWITCH; sw.speed = 7; sw.resulting_stance = Stance.Id.WATER
	orch.reveal_and_resolve([Resolver.Action.new(s.units[0], sw, s.units[0].grid_pos)])
	# turn 不在 reveal 涨；特征 key 的 phase 段基于 reveal 前 turn=5(ACTIVE)
	assert_gt(pm.total, 0)

func test_read_events_hit_and_miss():
	var s := _mk_with([Stance.Id.METAL])
	var p0: UnitState = s.units[0]
	var hit := Technique.new()
	hit.type = Technique.Type.STRIKE; hit.speed = 5; hit.resulting_stance = Stance.Id.METAL
	var hit_act := Resolver.Action.new(p0, hit, p0.grid_pos)
	var ev_hit := TurnOrchestrator.compute_read_events({String(p0.id): Technique.Type.STRIKE}, [hit_act])
	assert_true(ev_hit.size() >= 1)
	assert_true(ev_hit.any(func(e): return e.hit and e.target_id == String(p0.id)))
	var ev_miss := TurnOrchestrator.compute_read_events({String(p0.id): Technique.Type.MOVE}, [hit_act])
	assert_true(ev_miss.any(func(e): return not e.hit))
