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
