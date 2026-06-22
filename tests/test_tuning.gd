extends GutTest

func test_morale_defaults():
	var t := Tuning.new()
	assert_eq(t.morale_turn1, 5)
	assert_eq(t.morale_accum1, 1)
	assert_eq(t.morale_decay_reduction, 1)
	assert_eq(t.morale_turn2, 8)
	assert_eq(t.morale_accum2, 2)
	assert_eq(t.morale_cap_turn, 12)

func test_stance_role_defaults():
	var t := Tuning.new()
	assert_eq(t.defensive_decay_bonus, 1)
	assert_eq(t.offensive_self_opening, 1)

func test_range_defaults():
	var t := Tuning.new()
	assert_eq(t.range_close_max, 1)
	assert_eq(t.range_mid_max, 3)

func test_ai_weight_defaults():
	var t := Tuning.new()
	assert_eq(t.ai_w_opening, 1.0)
	assert_eq(t.ai_w_risk, 0.5)
	assert_eq(t.ai_w_position, 0.3)
	assert_eq(t.ai_w_morale, 0.8)
	assert_eq(t.ai_kill_bonus, 10.0)
	assert_eq(t.ai_top_n, 3)
