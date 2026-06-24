extends GutTest

var tu: Tuning

func before_each():
	tu = Tuning.new()

func _mk(id, team, pos, stance) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20
	return u

func _strike(dmg, speed, stance) -> Technique:
	var t := Technique.new()
	t.type = Technique.Type.STRIKE
	t.base_damage = dmg; t.speed = speed; t.resulting_stance = stance
	t.opening_dealt = 1
	return t

func test_faster_strike_lands_first_and_can_kill_before_slow():
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.WOOD)
	var s := BattleState.new(); s.units = [a, b]

	var fast := _strike(20, 9, Stance.Id.METAL)   # a 一击杀
	var slow := _strike(5, 1, Stance.Id.WOOD)      # b 慢一拍
	var ra := Resolver.Action.new(a, fast, b.grid_pos)
	var rb := Resolver.Action.new(b, slow, a.grid_pos)

	Resolver.resolve([ra, rb], s, tu)
	assert_false(b.alive, "b 被 a 秒了")
	assert_true(a.alive, "b 死后其行动被跳过，a 没掉血")

func test_stance_counter_gives_bonus_damage():
	# a=METAL 克 b=WOOD（金克木），同速
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.WOOD)
	var s := BattleState.new(); s.units = [a, b]

	var hit := _strike(5, 5, Stance.Id.METAL)
	Resolver.resolve([Resolver.Action.new(a, hit, b.grid_pos)], s, tu)
	# base 5 + 克制 2 + floor(opening 0 * 1) = 7
	assert_eq(b.hp, 20 - 7)

func test_opening_amplifies_subsequent_hit():
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.EARTH)  # 不被克
	var s := BattleState.new(); s.units = [a, b]
	b.opening = 4

	var hit := _strike(3, 5, Stance.Id.METAL)
	Resolver.resolve([Resolver.Action.new(a, hit, b.grid_pos)], s, tu)
	# 3 + floor(4*1) = 7
	assert_eq(b.hp, 20 - 7)

func test_guard_break_doubles_next_hit():
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.EARTH)
	var s := BattleState.new(); s.units = [a, b]
	b.guard_broken = true
	b.opening = 2

	var hit := _strike(4, 5, Stance.Id.METAL)
	Resolver.resolve([Resolver.Action.new(a, hit, b.grid_pos)], s, tu)
	# (4 + floor(2*1)) *2 = 12
	assert_eq(b.hp, 20 - 12)

func test_strike_into_empty_tile_is_miss():
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(5,5), Stance.Id.WOOD)
	var s := BattleState.new(); s.units = [a, b]
	var before := b.hp

	var hit := _strike(10, 5, Stance.Id.METAL)
	Resolver.resolve([Resolver.Action.new(a, hit, Vector2i(3,3))], s, tu)
	assert_eq(b.hp, before, "打空地，没人掉血")

func test_move_changes_position_and_clamps():
	var a := _mk(&"a", 0, Vector2i(0,0), Stance.Id.METAL)
	var s := BattleState.new(); s.units = [a]
	var mv := Technique.new()
	mv.type = Technique.Type.MOVE
	mv.speed = 5
	mv.move_delta = Vector2i(-3, -3)   # 会越界
	mv.resulting_stance = Stance.Id.METAL
	Resolver.resolve([Resolver.Action.new(a, mv, Vector2i.ZERO)], s, tu)
	assert_eq(a.grid_pos, Vector2i(0,0), "越界被 clamp 回 (0,0)")

func test_result_carries_log():
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.WOOD)
	var s := BattleState.new(); s.units = [a, b]
	var res := Resolver.resolve([Resolver.Action.new(a, _strike(5,5,Stance.Id.METAL), b.grid_pos)], s, tu)
	assert_gt(res.log.size(), 0)

func test_counter_ordering_decides_same_speed_tie():
	# A=METAL 克 B=WOOD；两人同速 STRIKE。若 A 因克制先手，B 被秒，A 不掉血。
	# 用具体数验算：b.hp=5；A 打击 base 5 + 克制奖励 2 = 7 ≥ 5 → 击杀；
	# B 打击 base 5（WOOD 不克 METAL，无奖励）若落到 A 身上会 -5 HP。
	# 结果只在「A 先手」时成立：B 死、A hp 仍为 20。
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.WOOD)
	b.hp = 5
	var s := BattleState.new(); s.units = [a, b]

	var hit_a := _strike(5, 5, Stance.Id.METAL)   # 同速，METAL 克 WOOD
	var hit_b := _strike(5, 5, Stance.Id.WOOD)    # 同速，WOOD 不克 METAL
	var ra := Resolver.Action.new(a, hit_a, b.grid_pos)
	var rb := Resolver.Action.new(b, hit_b, a.grid_pos)

	Resolver.resolve([ra, rb], s, tu)
	assert_false(b.alive, "B 被先手秒杀")
	assert_eq(a.hp, 20, "A 因克制先手，未受伤")

# —— M3 Task TO: imbalance 险地（五行失衡）——
# imbalance 使指定架势的单位该局速度 -2（影响先后手）。
# resolver.gd _compare 的 speed 降序段是注入点：imbalance 势单位 speed 取 effect_speed = speed - 2。
func test_imbalance_hazard_changes_initiative():
	# A=METAL, B=WOOD, 同 speed=5。
	# 无 imbalance：A 克 B（金克木），A 先手 → B 死、A 不掉血。
	# imbalance=METAL：A 的 effective speed = 5-2 = 3 < B 的 5 → B 先手。
	#   B 先手打 A（WOOD 不克 METAL，无加成），但 A 没死 → A 反击秒 B（METAL 克 WOOD +7≥5）。
	#   所以 B 反而先掉血但 A 也掉血（border: imbalance 翻转了先后手，A 受伤说明 B 先动了）。
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.WOOD)
	b.hp = 5
	var s := BattleState.new(); s.units = [a, b]
	s.hazard_modifiers = {"imbalance": Stance.Id.METAL}

	var hit_a := _strike(5, 5, Stance.Id.METAL)
	var hit_b := _strike(5, 5, Stance.Id.WOOD)
	var ra := Resolver.Action.new(a, hit_a, b.grid_pos)
	var rb := Resolver.Action.new(b, hit_b, a.grid_pos)
	Resolver.resolve([ra, rb], s, tu)
	# imbalance 翻转：B(speed 5) 先于 A(speed 3) 落招 → A 先掉 5 HP（WO不克M，无加成=5）
	assert_eq(a.hp, 20 - 5, "imbalance=METAL 使 A 速度 -2，B 抢先手打中 A")
	# A 随后反击：base 5 + 克制 2 = 7 ≥ 5 → B 仍死
	assert_false(b.alive, "A 反击仍秒杀 B")

func test_imbalance_hazard_default_is_noop():
	# hazard_modifiers={} 时 _compare 行为与 M2 一致（border guard）：
	# 同条件无 imbalance → A 先手秒 B，A 不掉血（与 test_counter_ordering_decides_same_speed_tie 一致）
	var a := _mk(&"a", 0, Vector2i(1,1), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(2,1), Stance.Id.WOOD)
	b.hp = 5
	var s := BattleState.new(); s.units = [a, b]
	s.hazard_modifiers = {}

	var hit_a := _strike(5, 5, Stance.Id.METAL)
	var hit_b := _strike(5, 5, Stance.Id.WOOD)
	var ra := Resolver.Action.new(a, hit_a, b.grid_pos)
	var rb := Resolver.Action.new(b, hit_b, a.grid_pos)
	Resolver.resolve([ra, rb], s, tu)
	assert_false(b.alive, "无 imbalance：A 先手秒 B")
	assert_eq(a.hp, 20, "无 imbalance：A 不掉血")
