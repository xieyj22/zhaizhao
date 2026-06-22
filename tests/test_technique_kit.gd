extends GutTest

func test_default_kit_contents():
	var kit := TechniqueKit.default_kit()
	# 3 打击 + 4 移动 + 5 切架势 = 12
	assert_eq(kit.size(), 12)
	var strikes := kit.filter(func(t): return t.type == Technique.Type.STRIKE)
	assert_eq(strikes.size(), 3)
	# 打击的 required_range 覆盖 CLOSE/MID/FAR
	var ranges := strikes.map(func(t): return t.required_range)
	assert_true(ranges.has(RangeBand.Id.CLOSE))
	assert_true(ranges.has(RangeBand.Id.MID))
	assert_true(ranges.has(RangeBand.Id.FAR))

func test_step_preserves_stance_sentinel():
	var mv := TechniqueKit.step(1, 0)
	assert_eq(mv.type, Technique.Type.MOVE)
	assert_eq(mv.resulting_stance, -1, "MOVE 用 -1 表示保持当前架势")

func test_resolver_move_preserves_stance():
	# 守卫：MOVE(resulting_stance=-1) 不改架势；STRIKE(resulting_stance=METAL) 改
	var s := BattleState.new()
	var u := UnitState.new()
	u.id = &"u"; u.team = 0; u.grid_pos = Vector2i(0,0); u.stance = Stance.Id.WATER
	u.hp = 20; u.max_hp = 20
	s.units = [u]
	var mv := TechniqueKit.step(1, 0)
	var t := Tuning.new()
	Resolver.resolve([Resolver.Action.new(u, mv, u.grid_pos)], s, t)
	assert_eq(u.grid_pos, Vector2i(1,0), "移动了")
	assert_eq(u.stance, Stance.Id.WATER, "架势保持不变")

func test_resolver_strike_still_sets_stance():
	# 回归：STRIKE 的 resulting_stance(≥0) 仍生效
	var s := BattleState.new()
	var a := UnitState.new(); a.id=&"a"; a.team=0; a.grid_pos=Vector2i(0,0); a.stance=Stance.Id.WATER; a.hp=20; a.max_hp=20
	var b := UnitState.new(); b.id=&"b"; b.team=1; b.grid_pos=Vector2i(1,0); b.stance=Stance.Id.WOOD; b.hp=20; b.max_hp=20
	s.units = [a, b]
	var hit := TechniqueKit.strike_close()   # resulting_stance = METAL
	var t := Tuning.new()
	Resolver.resolve([Resolver.Action.new(a, hit, b.grid_pos)], s, t)
	assert_eq(a.stance, Stance.Id.METAL, "打击后切到 resulting_stance")
