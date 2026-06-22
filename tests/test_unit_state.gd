extends GutTest

func test_defaults_alive_and_full_hp():
	var u := UnitState.new()
	assert_true(u.alive)
	assert_eq(u.hp, u.max_hp)
	assert_eq(u.opening, 0)

func test_roundtrip_preserves_all_fields():
	var u := UnitState.new()
	u.id = &"mu"
	u.team = 1
	u.hp = 7
	u.max_hp = 12
	u.opening = 3
	u.max_opening = 8
	u.stance = Stance.Id.WATER
	u.grid_pos = Vector2i(3, 4)
	u.facing = 2
	u.guard_broken = true
	u.alive = false

	var d := u.to_dict()
	var u2 := UnitState.from_dict(d)

	assert_eq(u2.id, &"mu")
	assert_eq(u2.team, 1)
	assert_eq(u2.hp, 7)
	assert_eq(u2.max_hp, 12)
	assert_eq(u2.opening, 3)
	assert_eq(u2.max_opening, 8)
	assert_eq(u2.stance, Stance.Id.WATER)
	assert_eq(u2.grid_pos, Vector2i(3, 4))
	assert_eq(u2.facing, 2)
	assert_eq(u2.guard_broken, true)
	assert_eq(u2.alive, false)

func test_dict_is_json_serializable():
	# JSON-safe：所有值都是基本类型/Array/Dictionary，能过 JSON.stringify 往返
	# 注意 Godot 4.7 的 JSON.parse_string 把所有数字还原为 float（引擎行为），
	# 故 [2,5] 经 stringify→parse_string 后变成 [2.0, 5.0]。
	# 这里验证：(1) 能 stringify；(2) 解析回来仍是 Array；(3) 坐标值数值相等；(4) 能重建等价 Vector2i。
	var u := UnitState.new()
	u.grid_pos = Vector2i(2, 5)
	var s := JSON.stringify(u.to_dict())
	assert_not_null(s)
	var parsed = JSON.parse_string(s)
	assert_not_null(parsed)
	assert_eq(typeof(parsed.grid_pos), TYPE_ARRAY, "grid_pos 序列化为 Array")
	assert_eq(parsed.grid_pos.size(), 2)
	assert_eq(int(parsed.grid_pos[0]), 2)
	assert_eq(int(parsed.grid_pos[1]), 5)
	# 真正的 round-trip：from_dict 能从 JSON-safe dict 重建等价 Vector2i
	var u2 := UnitState.from_dict(parsed)
	assert_eq(u2.grid_pos, Vector2i(2, 5))
