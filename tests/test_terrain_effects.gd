extends GutTest

## Task A3/A4/A5: 地形效果接入（resolver 三钩子 + end_turn 险地格 + AI 地形项）。

func _tech(p_speed: int, p_dmg: int = 5) -> Technique:
	var t := Technique.new()
	t.id = &"t_strike"
	t.type = Technique.Type.STRIKE
	t.speed = p_speed
	t.base_damage = p_dmg
	t.opening_dealt = 1
	t.required_range = RangeBand.Id.CLOSE
	return t

func _move(delta_x: int, delta_y: int) -> Technique:
	var t := Technique.new()
	t.id = &"t_move"
	t.type = Technique.Type.MOVE
	t.speed = 6
	t.move_delta = Vector2i(delta_x, delta_y)
	t.required_range = RangeBand.Id.FAR
	return t

func _state(p_terrain: Dictionary = {}) -> BattleState:
	var s := BattleState.new()
	s.terrain = p_terrain
	var a := UnitState.new()
	a.id = &"p1"; a.team = 0; a.stance = Stance.Id.METAL
	a.grid_pos = Vector2i(1, 3); a.hp = 30; a.max_hp = 30
	var b := UnitState.new()
	b.id = &"e1"; b.team = 1; b.stance = Stance.Id.WATER
	b.grid_pos = Vector2i(5, 3); b.hp = 30; b.max_hp = 30
	s.units = [a, b]
	return s

func test_water_sort_sink():
	var s := _state({"1,3": TerrainRules.WATER})
	var actions := [
		Resolver.Action.new(s.units[0], _tech(5), s.units[1].grid_pos),
		Resolver.Action.new(s.units[1], _tech(5), s.units[0].grid_pos),
	]
	var r := Resolver.resolve(actions, s, Tuning.new())
	assert_true(String(r.log[0]).begins_with("e1"), "同速水域者后手（e1 先出手）")

func test_no_terrain_order_unchanged():
	var s := _state()
	var actions := [
		Resolver.Action.new(s.units[0], _tech(5), s.units[1].grid_pos),
		Resolver.Action.new(s.units[1], _tech(5), s.units[0].grid_pos),
	]
	var r := Resolver.resolve(actions, s, Tuning.new())
	assert_true(String(r.log[0]).begins_with("p1"), "空 terrain：同速 team0 先（M0-M2 语义不变）")

func test_highland_damage_plus_one():
	var plain := _state()
	var high := _state({"1,3": TerrainRules.HIGHLAND})
	for st in [plain, high]:
		Resolver.resolve([Resolver.Action.new(st.units[0], _tech(5), st.units[1].grid_pos)], st, Tuning.new())
	assert_eq(high.units[1].hp, plain.units[1].hp - 1, "高地攻方伤害 +1")

func test_obstacle_blocks_move():
	var s := _state({"3,3": TerrainRules.OBSTACLE})
	var p0: Vector2i = s.units[0].grid_pos
	Resolver.resolve([Resolver.Action.new(s.units[0], _move(2, 0), p0)], s, Tuning.new())
	assert_eq(s.units[0].grid_pos, p0, "障碍格不可落，留原地")
	var s2 := _state()
	Resolver.resolve([Resolver.Action.new(s2.units[0], _move(2, 0), s2.units[0].grid_pos)], s2, Tuning.new())
	assert_eq(s2.units[0].grid_pos, Vector2i(3, 3), "对照：无障碍移动成功")
