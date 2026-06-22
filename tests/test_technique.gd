extends GutTest

func test_default_technique_is_strike():
	var t := Technique.new()
	assert_eq(t.type, Technique.Type.STRIKE)

func test_tuning_defaults_present():
	var tu := Tuning.new()
	assert_gt(tu.opening_damage_mult, 0.0)
	assert_gt(tu.counter_bonus_damage, 0)

func test_feint_has_two_part_scaffold():
	var feint := Technique.new()
	feint.type = Technique.Type.FEINT
	var apparent := Technique.new()
	var real_eff := Technique.new()
	feint.apparent = apparent
	feint.real_effect = real_eff
	assert_eq(feint.apparent, apparent)
	assert_eq(feint.real_effect, real_eff)
