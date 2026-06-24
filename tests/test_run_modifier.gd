extends GutTest

func test_roll_deterministic_and_two_unique():
	var a: Array = RunModifier.roll(42)
	var b: Array = RunModifier.roll(42)
	assert_eq(a, b, "同 seed 同 2 id")
	assert_eq(a.size(), 2, "roll 2 个")
	assert_ne(a[0], a[1], "去重")

func test_roll_different_seed_different():
	assert_ne(RunModifier.roll(42), RunModifier.roll(99))

func test_apply_numeric_sum_and_dict_merge():
	var state: Dictionary = RunModifier.apply(["ruijin_dangling", "hougu_zhenxie"])
	assert_eq(state.get("kit_stance_damage_bonus", {}).get("METAL", 0), 1)
	assert_eq(state.get("kit_stance_speed_bonus", {}).get("EARTH", 0), 1)

func test_apply_same_hook_dict():
	var state: Dictionary = RunModifier.apply(["ruijin_dangling"])
	assert_eq(state["kit_stance_damage_bonus"]["METAL"], 1)

func test_apply_float_hook():
	var state: Dictionary = RunModifier.apply(["duxin_po"])
	assert_eq(state.get("ai_confidence_cap_delta", 0.0), 0.15)

func test_apply_empty_is_empty():
	assert_eq(RunModifier.apply([]), {}, "无 modifier = 空 state")

func test_pool_has_ten():
	assert_eq(RunModifier.get_pool().size(), 10, "初始 10 条 modifier")

func test_by_id_returns_entry():
	var m: Dictionary = RunModifier._by_id("duxing")
	assert_eq(m["name"], "独行")
	assert_true((m["effect"] as Dictionary).has("roster_cap"))
