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

func test_feint_explicit_fields_defaults():
	var t := Technique.new()
	t.type = Technique.Type.FEINT
	assert_eq(t.apparent_stance, -1, "默认非伪装/不伪装")
	assert_eq(t.feint_bonus_mult, 1.5, "上钩惩罚倍率")
	assert_eq(t.feint_fail_mult, 0.7, "识破落空倍率")

func test_feint_apparent_settable():
	var t := Technique.new()
	t.type = Technique.Type.FEINT
	t.apparent_stance = Stance.Id.WATER
	t.base_damage = 6
	assert_eq(t.apparent_stance, Stance.Id.WATER)
	# real 效果复用既有 base_damage / resulting_stance（v1 伪装打击）
	assert_eq(t.base_damage, 6)

func test_variant_default_empty():
	var t := Technique.new()
	assert_eq(t.variant, &"", "默认普通版（variant 空串）")

func test_apply_variant_strong_boosts_damage_and_opening():
	var base := Technique.new()
	base.base_damage = 5
	base.opening_dealt = 2
	var strong := Technique.apply_variant(base, &"strong")
	assert_eq(strong.variant, &"strong", "标记为强化版")
	assert_eq(strong.base_damage, 6, "base_damage +1")
	assert_eq(strong.opening_dealt, 1, "opening_dealt -1")
	# 原招不变（副本）
	assert_eq(base.base_damage, 5)
	assert_eq(base.variant, &"")

func test_apply_variant_empty_is_noop():
	var base := Technique.new()
	base.base_damage = 5
	var v := Technique.apply_variant(base, &"")
	assert_eq(v.base_damage, 5)
	assert_eq(v.variant, &"")
