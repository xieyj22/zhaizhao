extends GutTest

func test_brain_uses_l2():
	var p := AIPersonality.brain()
	assert_gt(p.w_predict_mul, 1.0, "智将放大 L2")
	assert_lte(p.feint_rate, 0.2, "智将少主动虚招")
	assert_gt(p.display_name.length(), 0)

func test_brute_ignores_l2():
	var p := AIPersonality.brute()
	assert_lte(p.w_predict_mul, 0.1, "莽将基本忽略 L2")
	assert_gt(p.aggression, 1.0, "莽将高侵略")
	assert_gt(p.top_n_mul, 1.0, "莽将更随机(冒险)")

func test_trick_feints():
	var p := AIPersonality.trick()
	assert_gt(p.feint_rate, 0.5, "诡将高虚招率")
	assert_gt(p.w_predict_mul, 0.0)

func test_brain_trick_hybrid_weights():
	var p := AIPersonality.brain_trick_hybrid()
	assert_eq(p.display_name, "智诡合一")
	assert_eq(p.w_predict_mul, 2.0, "brain 的读招")
	assert_eq(p.feint_rate, 0.7, "trick 的虚招")
	assert_eq(p.aggression, 1.2)
	assert_eq(p.caution, 1.0)
	assert_eq(p.top_n_mul, 1.1)

func test_defaults_present():
	var p := AIPersonality.new()
	assert_eq(p.w_predict_mul, 1.0)
	assert_eq(p.feint_rate, 0.0)
	assert_eq(p.aggression, 1.0)
	assert_eq(p.caution, 1.0)
	assert_eq(p.top_n_mul, 1.0)
