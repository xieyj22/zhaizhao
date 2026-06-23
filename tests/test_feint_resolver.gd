extends GutTest

var tu: Tuning
func before_each():
	tu = Tuning.new()

func _mk(id, team, pos, stance) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20
	return u

func _feint(unit, target_pos, apparent, real_dmg, real_stance) -> Technique:
	var t := Technique.new()
	t.type = Technique.Type.FEINT
	t.apparent_stance = apparent
	t.base_damage = real_dmg
	t.resulting_stance = real_stance
	t.speed = 5
	t.opening_dealt = 1
	t.required_range = RangeBand.Id.FAR
	return t

func _strike(unit_stance, target_pos, dmg := 5) -> Technique:
	var t := Technique.new()
	t.type = Technique.Type.STRIKE
	t.base_damage = dmg; t.speed = 5; t.opening_dealt = 1
	t.resulting_stance = unit_stance
	t.required_range = RangeBand.Id.FAR
	return t

func test_perceived_stance_feint_uses_apparent():
	var a := _mk(&"a", 0, Vector2i(0,0), Stance.Id.WATER)
	var b := _mk(&"b", 1, Vector2i(1,0), Stance.Id.METAL)
	var s := BattleState.new(); s.units = [a, b]
	var fe := _feint(a, b.grid_pos, Stance.Id.FIRE, 5, Stance.Id.WATER)
	var act := Resolver.Action.new(a, fe, b.grid_pos)
	assert_eq(Resolver._perceived_stance(a, act), Stance.Id.FIRE, "FEINT 对外=apparent")

func test_perceived_stance_non_feint_is_real():
	var a := _mk(&"a", 0, Vector2i(0,0), Stance.Id.WATER)
	var s := BattleState.new(); s.units = [a]
	var st := _strike(Stance.Id.WATER, Vector2i(1,0))
	var act := Resolver.Action.new(a, st, Vector2i(1,0))
	assert_eq(Resolver._perceived_stance(a, act), Stance.Id.WATER, "非虚招=真实架势")

func test_feint_lures_counter_deals_bonus():
	# A 出 FEINT apparent=FIRE，real=WATER 打击 dmg=5。B=WATER 克 apparent=FIRE（上钩）→ A real × 1.5
	var a := _mk(&"a", 0, Vector2i(0,0), Stance.Id.WATER)
	var b := _mk(&"b", 1, Vector2i(1,0), Stance.Id.WATER)
	var s := BattleState.new(); s.units = [a, b]
	var fe := _feint(a, b.grid_pos, Stance.Id.FIRE, 5, Stance.Id.WATER)
	var bst := _strike(Stance.Id.WATER, a.grid_pos, 3)
	var hp_before := b.hp
	Resolver.resolve([Resolver.Action.new(a, fe, b.grid_pos), Resolver.Action.new(b, bst, a.grid_pos)], s, tu)
	# A real 打 B：base 5 × 1.5 = 7.5 → int(round(7.5)) = 8（A=WATER 不克 B=WATER，无 counter bonus）
	assert_eq(b.hp, hp_before - 8, "B 上钩 → A real ×feint_bonus_mult(1.5)，round(7.5)=8")

func test_feint_unmasked_deals_reduced():
	# A FEINT apparent=FIRE，无对手针对（EARTH 不克 FIRE）→ A real × 0.7
	var a := _mk(&"a", 0, Vector2i(0,0), Stance.Id.WATER)
	var b := _mk(&"b", 1, Vector2i(1,0), Stance.Id.EARTH)
	var s := BattleState.new(); s.units = [a, b]
	var fe := _feint(a, b.grid_pos, Stance.Id.FIRE, 10, Stance.Id.WATER)
	var hp_before := b.hp
	Resolver.resolve([Resolver.Action.new(a, fe, b.grid_pos)], s, tu)
	# base 10 × 0.7 = 7.0 → int(round(7.0)) = 7
	assert_eq(b.hp, hp_before - 7, "B 识破 → A real ×feint_fail_mult(0.7)")

func test_feint_no_apparent_matches_strike():
	# apparent_stance=-1 → FEINT 同 STRIKE（real 原倍，counter 用真实架势）
	var a := _mk(&"a", 0, Vector2i(0,0), Stance.Id.METAL)
	var b := _mk(&"b", 1, Vector2i(1,0), Stance.Id.WOOD)
	var s := BattleState.new(); s.units = [a, b]
	var fe := _feint(a, b.grid_pos, -1, 5, Stance.Id.METAL)
	var hp_before := b.hp
	Resolver.resolve([Resolver.Action.new(a, fe, b.grid_pos)], s, tu)
	# 无 apparent → mult=1.0；A=METAL 克 B=WOOD → base 5 + counter 2 = 7
	assert_eq(b.hp, hp_before - 7, "apparent=-1 同 STRIKE 结算（原倍 + counter）")
