extends GutTest

func _make_1v1() -> BattleState:
	var s := BattleState.new()
	var a := UnitState.new(); a.id=&"a"; a.team=0; a.grid_pos=Vector2i(1,3)
	var b := UnitState.new(); b.id=&"b"; b.team=1; b.grid_pos=Vector2i(5,3)
	s.units = [a, b]
	return s

func test_unit_at_finds_alive_unit():
	var s := _make_1v1()
	assert_eq(s.unit_at(Vector2i(1,3)).id, &"a")
	assert_null(s.unit_at(Vector2i(0,0)))

func test_unit_at_ignores_dead():
	var s := _make_1v1()
	s.units[0].alive = false
	assert_null(s.unit_at(Vector2i(1,3)))

func test_clamp_to_grid():
	var s := _make_1v1()  # grid 7x7
	assert_eq(s.clamp_to_grid(Vector2i(-1, 9)), Vector2i(0, 6))
	assert_eq(s.clamp_to_grid(Vector2i(3, 3)), Vector2i(3, 3))

func test_is_over_when_one_team_left():
	var s := _make_1v1()
	assert_false(s.is_over())
	s.units[1].alive = false
	assert_true(s.is_over())

func test_roundtrip():
	var s := _make_1v1()
	s.turn = 4
	var s2 := BattleState.from_dict(s.to_dict())
	assert_eq(s2.turn, 4)
	assert_eq(s2.units.size(), 2)
	assert_eq(s2.units[0].id, &"a")
	assert_eq(s2.units[1].grid_pos, Vector2i(5,3))
