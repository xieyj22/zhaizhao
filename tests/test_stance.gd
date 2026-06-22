extends GutTest

func test_ring_has_five_stances():
	assert_eq(Stance.ALL.size(), 5, "5 势成环")

func test_counter_cycle_covers_all():
	for s in Stance.ALL:
		var c: int = Stance.counter_of(s)
		assert_true(c in Stance.ALL, "%d 的克制目标在环内" % s)

func test_no_self_counter():
	for s in Stance.ALL:
		assert_false(Stance.counters(s, s), "无人克自己")

func test_known_edges():
	# 五行相克：金克木、木克土、土克水、水克火、火克金
	assert_true(Stance.counters(Stance.Id.METAL, Stance.Id.WOOD))
	assert_true(Stance.counters(Stance.Id.FIRE, Stance.Id.METAL))
	assert_false(Stance.counters(Stance.Id.WOOD, Stance.Id.METAL), "木不克金")

func test_role_mapping_complete():
	# 每个架势都有归属，且 2 攻 / 2 守 / 1 中
	var off := 0; var def := 0; var neu := 0
	for s in Stance.ALL:
		match Stance.role(s):
			Stance.Role.OFFENSIVE: off += 1
			Stance.Role.DEFENSIVE: def += 1
			Stance.Role.NEUTRAL: neu += 1
	assert_eq(off, 2)
	assert_eq(def, 2)
	assert_eq(neu, 1)

func test_role_known_assignments():
	assert_eq(Stance.role(Stance.Id.METAL), Stance.Role.OFFENSIVE)
	assert_eq(Stance.role(Stance.Id.FIRE), Stance.Role.OFFENSIVE)
	assert_eq(Stance.role(Stance.Id.WOOD), Stance.Role.DEFENSIVE)
	assert_eq(Stance.role(Stance.Id.WATER), Stance.Role.DEFENSIVE)
	assert_eq(Stance.role(Stance.Id.EARTH), Stance.Role.NEUTRAL)
