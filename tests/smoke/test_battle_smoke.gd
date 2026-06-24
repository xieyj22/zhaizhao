extends GutTest

const MAX_TURNS := 30   # 远超 morale_cap_turn=12，给宽裕余量防死循环

func _mk_2v2() -> BattleState:
	var s := BattleState.new()
	s.units = [
		_mk(&"p0", 0, Vector2i(1,2), Stance.Id.METAL),
		_mk(&"p1", 0, Vector2i(1,4), Stance.Id.WOOD),
		_mk(&"e0", 1, Vector2i(5,2), Stance.Id.WOOD),
		_mk(&"e1", 1, Vector2i(5,4), Stance.Id.METAL),
	]
	return s

func _mk(id, team, pos, stance) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20
	return u

func _player_actions(s: BattleState, t: Tuning, rng: RandomNumberGenerator) -> Array:
	# 玩家方每存活单位：用远打(FAR 必命中)打血最少的敌方，或随机移动
	var actions: Array = []
	for u in s.units:
		if u.team != 0 or not u.alive:
			continue
		var enemies := s.units.filter(func(e): return e.team != 0 and e.alive)
		if enemies.is_empty():
			continue
		enemies.sort_custom(func(a, b): return a.hp < b.hp)   # 集火最残
		var target: UnitState = enemies[0]
		actions.append(Resolver.Action.new(u, TechniqueKit.strike_far(), target.grid_pos))
	return actions

func test_2v2_multi_seed_terminates_with_legal_outcome():
	var outcomes: Dictionary = {}   # outcome -> count
	for sd in [1, 42, 777, 2026, 99999]:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		var s := _mk_2v2()
		var tuning := Tuning.new()
		var pm := PlayerModel.new()
		var pers := AIPersonality.brain()
		var orch := TurnOrchestrator.new(s, tuning, pm, 1)
		var kits := {}
		for u in s.units:
			if u.team == 1:
				kits[String(u.id)] = TechniqueKit.default_kit()
		var turns := 0
		while s.outcome(tuning) == BattleState.Outcome.ONGOING and turns < MAX_TURNS:
			var player := _player_actions(s, tuning, rng)
			var ai_out := AIController.choose_actions(s, 1, tuning, kits, sd * 1000 + turns, pm, pers)
			orch.reveal_and_resolve(player + ai_out.actions)
			orch.end_turn()
			turns += 1
		var oc := s.outcome(tuning)
		assert_ne(oc, BattleState.Outcome.ONGOING, "seed=%d 在 %d 回合内分胜负" % [sd, MAX_TURNS])
		assert_lt(turns, MAX_TURNS, "seed=%d 未触顶" % sd)
		assert_true(oc in [BattleState.Outcome.TEAM0_WIN, BattleState.Outcome.TEAM1_WIN, BattleState.Outcome.DRAW], "seed=%d outcome 合法" % sd)
		outcomes[oc] = outcomes.get(oc, 0) + 1
	assert_gt(outcomes.size(), 0, "至少有一个 outcome 出现")


# --- M3 端到端 meta 循环冒烟（IT 集成任务）-----------------------------
# 纯逻辑链：init_run → 走 DAG 到 boss → boss 击败 → 掉 T3 招 → commit_run_to_meta → meta 沉淀。
# 不实例化场景（hub/map/battle 场景链需运行时手动验证，headless 不可测）。

func test_chapter1_full_run_meta_persists():
	# 端到端 meta 循环：开一局 → 走到 boss → 击败 → meta 沉淀
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	# 找 boss 节点
	var m: Dictionary = run.chapter_maps[1]
	var boss_id := ""
	for id in m["nodes"]:
		if m["nodes"][id]["type"] == "boss":
			boss_id = id
			break
	assert_ne(boss_id, "", "章 1 图含 boss 节点")
	# 沿边走到 boss 前一层（L6），再进 boss
	var cur := _walk_to_boss(m)
	RunFlow.enter_node(run, cur)
	RunFlow.enter_node(run, boss_id)
	RunFlow.on_boss_defeated(run)
	# boss 掉 T3 招（章 1 赫连铮 → 血衣·血祭）
	var drop: Variant = UnlockRules.roll_unlock_reward(
		meta.meta_unlocked_pool, "boss", {"boss_id": "hailianzheng"}, run.rng_seed
	)
	assert_eq(drop, "xueyi_xuedao", "章 1 boss 掉血衣·血祭")
	if not run.unlocked_techniques.has(drop):
		run.unlocked_techniques.append(drop)
	# meta 沉淀
	var meta2 := MetaState.commit_run_to_meta(meta, run, true)
	assert_true(meta2.meta_unlocked_pool.has("xueyi_xuedao"), "boss 掉落并入 meta 池")
	assert_eq(meta2.meta_runs_completed, 1, "通关 +1")
	assert_true(meta2.meta_inheritance_unlocked, "首次通关解锁传承")
	# 原 meta 不被污染（commit 是纯函数深拷贝）
	assert_eq(meta.meta_runs_completed, 0, "原 meta 不变（commit 深拷贝）")

func _walk_to_boss(m: Dictionary) -> String:
	# 沿 reachable_next[0] 从 L0 走 6 步到 L6（boss 前层）任一节点
	var start := ""
	for id in m["nodes"]:
		if m["nodes"][id]["layer"] == 0:
			start = id
			break
	var cur := start
	for _l in range(6):
		var nxt: Array = MapGenerator.reachable_next(m, cur)
		if nxt.is_empty():
			break
		cur = nxt[0]
	return cur
