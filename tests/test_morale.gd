extends GutTest

var t: Tuning
func before_each():
	t = Tuning.new()

func test_accumulation_steps():
	assert_eq(Morale.accumulation(0, t), 0)
	assert_eq(Morale.accumulation(4, t), 0)
	assert_eq(Morale.accumulation(5, t), 1)   # ACTIVE
	assert_eq(Morale.accumulation(7, t), 1)
	assert_eq(Morale.accumulation(8, t), 2)   # ESCALATED
	assert_eq(Morale.accumulation(12, t), 2)

func test_decay_modifier():
	assert_eq(Morale.decay_modifier(4, t), 0)
	assert_eq(Morale.decay_modifier(5, t), 1)
	assert_eq(Morale.decay_modifier(8, t), 1)

func test_phase():
	assert_eq(Morale.phase(4, t), Morale.Phase.NORMAL)
	assert_eq(Morale.phase(5, t), Morale.Phase.ACTIVE)
	assert_eq(Morale.phase(8, t), Morale.Phase.ESCALATED)
