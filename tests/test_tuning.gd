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

func test_l2_defaults():
	var t := Tuning.new()
	assert_eq(t.l2_confidence_cap, 0.65, "预测置信度封顶 0.65（留虚招出口）")
	assert_eq(t.l2_min_samples, 3, "样本不足 3 纯走 L1")
	assert_eq(t.ai_w_predict, 3.0)

func test_m35_replay_constants():
	var t := Tuning.new()
	assert_eq(t.rest_cap_per_chapter, 2, "镖局休整限 2/章")
	assert_eq(t.credit_service_cost, 8, "镖局服务单价 ~8")
	assert_eq(t.credit_income_chapter1, 25, "章 1 信用产出 ~25")
