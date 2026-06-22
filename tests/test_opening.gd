extends GutTest

func test_base_damage_with_zero_opening():
	assert_eq(Opening.compute_damage(5, 0, 1.0, false), 5)

func test_opening_amplifies_damage():
	# base + floor(opening * mult)
	assert_eq(Opening.compute_damage(5, 3, 1.0, false), 8)
	assert_eq(Opening.compute_damage(5, 3, 2.0, false), 11)

func test_guard_broken_doubles_damage():
	# 8 * 2 = 16
	assert_eq(Opening.compute_damage(5, 3, 1.0, true), 16)

func test_damage_never_negative():
	assert_eq(Opening.compute_damage(0, 0, 1.0, false), 0)

func test_decay_floors_at_zero():
	assert_eq(Opening.decay(2, 1), 1)
	assert_eq(Opening.decay(0, 1), 0)
	assert_eq(Opening.decay(1, 5), 0)
