extends GutTest

var tu: Tuning

func before_each():
	tu = Tuning.new()

func _mk_state() -> BattleState:
	var s := BattleState.new()
	var a := UnitState.new(); a.id=&"a"; a.team=0; a.grid_pos=Vector2i(1,3); a.stance=Stance.Id.METAL
	var b := UnitState.new(); b.id=&"b"; b.team=1; b.grid_pos=Vector2i(5,3); b.stance=Stance.Id.WOOD
	s.units = [a, b]
	return s

func test_reveal_resolves_and_advances_nothing_yet():
	var s := _mk_state()
	var orch := TurnOrchestrator.new(s, tu)
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
	var orch := TurnOrchestrator.new(s, tu)
	orch.end_turn()
	assert_eq(s.units[0].opening, 2, "回落 1")
	assert_eq(s.turn, 1)

func test_end_turn_clears_guard_break_when_opening_recovers_below_max():
	var s := _mk_state()
	s.units[0].opening = 6
	s.units[0].guard_broken = true
	var orch := TurnOrchestrator.new(s, tu)
	orch.end_turn()
	# opening 6→5 < max_opening 6 → 崩溃解除
	assert_false(s.units[0].guard_broken)

func test_state_reports_over_after_kill_via_orchestrator():
	var s := _mk_state()
	s.units[1].hp = 1
	var orch := TurnOrchestrator.new(s, tu)
	var hit := Technique.new()
	hit.type = Technique.Type.STRIKE; hit.base_damage=5; hit.speed=5
	hit.resulting_stance = Stance.Id.METAL; hit.opening_dealt = 0
	orch.reveal_and_resolve([Resolver.Action.new(s.units[0], hit, s.units[1].grid_pos)])
	assert_true(s.is_over())
