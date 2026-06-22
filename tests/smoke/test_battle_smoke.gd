extends GutTest

const MAX_TURNS := 50   # 远超 spec §2.7 的 ~8~10 回合硬上限（战意 M1 才有，这里给宽裕余量防死循环）

func _mk_state() -> BattleState:
	var s := BattleState.new()
	var a := UnitState.new(); a.id=&"a"; a.team=0; a.grid_pos=Vector2i(1,3); a.stance=Stance.Id.METAL; a.hp=30; a.max_hp=30
	var b := UnitState.new(); b.id=&"b"; b.team=1; b.grid_pos=Vector2i(5,3); b.stance=Stance.Id.WOOD; b.hp=30; b.max_hp=30
	s.units = [a, b]
	return s

func _random_action(u: UnitState, enemy: UnitState) -> Resolver.Action:
	var roll := randi() % 4
	var t := Technique.new()
	t.resulting_stance = u.stance
	match roll:
		0:
			t.type = Technique.Type.STRIKE; t.base_damage=5; t.speed=5; t.opening_dealt=1
			t.resulting_stance = Stance.Id.METAL
			return Resolver.Action.new(u, t, enemy.grid_pos)
		1:
			t.type = Technique.Type.MOVE; t.speed=6; t.move_delta = Vector2i(randi_range(-1,1), 0)
		2:
			t.type = Technique.Type.STANCE_SWITCH; t.speed=7; t.resulting_stance = Stance.Id.WATER
		_:
			t.type = Technique.Type.STANCE_SWITCH; t.speed=7; t.resulting_stance = Stance.Id.FIRE
	return Resolver.Action.new(u, t, u.grid_pos)

func test_random_1v1_terminates_without_infinite_loop():
	seed(12345)
	var s := _mk_state()
	var orch := TurnOrchestrator.new(s, Tuning.new())
	var turns := 0
	while not s.is_over() and turns < MAX_TURNS:
		var a: UnitState = s.units[0]
		var b: UnitState = s.units[1]
		var alive_a := a.alive
		var alive_b := b.alive
		var actions: Array = []
		if alive_a and alive_b:
			actions.append(_random_action(a, b))
			actions.append(_random_action(b, a))
		orch.reveal_and_resolve(actions)
		orch.end_turn()
		turns += 1
	assert_true(s.is_over(), "战斗在 %d 回合内分出胜负" % MAX_TURNS)
	assert_lt(turns, MAX_TURNS, "未触顶防死循环")

func test_multiple_seeds_all_terminate():
	for sd in [1, 42, 777, 2026, 99999]:
		seed(sd)
		var s := _mk_state()
		var orch := TurnOrchestrator.new(s, Tuning.new())
		var turns := 0
		while not s.is_over() and turns < MAX_TURNS:
			var a: UnitState = s.units[0]; var b: UnitState = s.units[1]
			if a.alive and b.alive:
				orch.reveal_and_resolve([_random_action(a,b), _random_action(b,a)])
			orch.end_turn()
			turns += 1
		assert_true(s.is_over(), "seed=%d 终止" % sd)
		assert_lt(turns, MAX_TURNS, "seed=%d 未触顶" % sd)
