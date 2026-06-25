extends GutTest

# reduce_motion 副作用单测（渲染像素 GUT headless 测不了，剥离可观测副作用测）。
# 验证 spawn_floater/flash_at/HP lerp 在 reduce_motion=true 时降级。

func _view() -> BattleView:
	var v := BattleView.new()
	v.state = BattleState.new()
	v.state.grid_size = Vector2i(7, 7)
	v.state.units = []
	return v

func test_spawn_floater_normal_has_animation():
	var v := _view()
	v.reduce_motion = false
	v.spawn_floater(Vector2i(1, 1), "-5")
	assert_eq(v.floaters.size(), 1)
	assert_false(bool(v.floaters[0].get("static", false)), "正常模式飘字带动画（非 static）")
	assert_eq(float(v.floaters[0]["life"]), 0.8, "正常寿命 0.8")

func test_spawn_floater_reduce_motion_is_static():
	var v := _view()
	v.reduce_motion = true
	v.spawn_floater(Vector2i(1, 1), "-5")
	assert_true(bool(v.floaters[0].get("static", false)), "reduce_motion 飘字标记 static（不上浮不淡出）")
	assert_lt(float(v.floaters[0]["life"]), 0.8, "reduce_motion 寿命压短")

func test_spawn_floater_critical_reduce_motion_no_shake():
	# reduce_motion 时 critical 也不震屏（add_shake gate）
	var v := _view()
	v.reduce_motion = true
	v.spawn_floater(Vector2i(1, 1), "-10", true)
	assert_eq(v.shake, 0.0, "reduce_motion critical 不震屏")

func test_flash_at_normal_records():
	var v := _view()
	v.reduce_motion = false
	v.flash_at(Vector2i(1, 1))
	assert_true(v.flashes.has("1,1"), "正常模式 flash 记录")

func test_flash_at_reduce_motion_skipped():
	var v := _view()
	v.reduce_motion = true
	v.flash_at(Vector2i(1, 1))
	assert_false(v.flashes.has("1,1"), "reduce_motion flash 跳过（不闪白）")

func test_add_shake_reduce_motion_blocked():
	var v := _view()
	v.reduce_motion = true
	v.add_shake(8.0)
	assert_eq(v.shake, 0.0, "reduce_motion add_shake 被拦")

func test_add_shake_normal_accumulates():
	var v := _view()
	v.reduce_motion = false
	v.add_shake(8.0)
	assert_eq(v.shake, 8.0, "正常模式震屏累积")
