extends GutTest

func after_each():
	# 兜底：每个测试后重置 MetaSession，防全局态泄漏（RunState 测试的 current_run
	# 绝不能漏进 2v2 fallback 测试——后者依赖 current_run == null）
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}

func test_2v2_pick_reveal_ai_drive_ends_with_outcome():
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	# _ready 后：2 玩家单位(team0)、2 敌方(team1)。给玩家方每单位下一个打击指令（自动找范围内目标）
	var struck := false
	for u in battle.state.units:
		if u.team == 0 and u.alive:
			# 找一个范围内敌方打
			for e in battle.state.units:
				if e.team != 0 and e.alive and RangeBand.in_range(u.grid_pos, e.grid_pos, RangeBand.Id.FAR, battle.tuning):
					battle._on_pick_target(u, TechniqueKit.strike_far(), e.grid_pos)
					struck = true
					break
	assert_true(struck, "至少给一个玩家单位下了打击指令")
	battle._on_reveal()
	# 一回合后，敌方应被 AI 打过血（玩家用远打 FAR 必命中）+ 我方也可能掉血
	var oc: int = battle.state.outcome(battle.tuning)
	assert_eq(oc, BattleState.Outcome.ONGOING, "一回合不足分胜负")
	assert_gt(battle.state.turn, 0, "回合推进了")
	remove_child(battle)
	battle.queue_free()

func test_2v2_runs_to_termination():
	# 重复 pick+reveal 直到 outcome != ONGOING，断言在 cap 内终止（headless 代理）
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	var guard := 0
	while battle.state.outcome(battle.tuning) == BattleState.Outcome.ONGOING and guard < 30:
		# 玩家方每存活单位都打最近的敌方（FAR 必中）
		for u in battle.state.units:
			if u.team == 0 and u.alive:
				var best = null
				var best_d := 1 << 30
				for e in battle.state.units:
					if e.team != 0 and e.alive:
						var d := RangeBand.distance(u.grid_pos, e.grid_pos)
						if d < best_d:
							best_d = d; best = e
				if best != null:
					battle._on_pick_target(u, TechniqueKit.strike_far(), best.grid_pos)
		battle._on_reveal()
		guard += 1
	assert_ne(battle.state.outcome(battle.tuning), BattleState.Outcome.ONGOING, "2v2 在 30 回合内分胜负")
	remove_child(battle)
	battle.queue_free()

func test_2v2_with_brain_personality_runs_to_outcome():
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	# battle._ready 已建 player_model + personality=brain
	var guard := 0
	while battle.state.outcome(battle.tuning) == BattleState.Outcome.ONGOING and guard < 30:
		for u in battle.state.units:
			if u.team == 0 and u.alive:
				var best = null; var best_d := 1 << 30
				for e in battle.state.units:
					if e.team != 0 and e.alive:
						var d := RangeBand.distance(u.grid_pos, e.grid_pos)
						if d < best_d: best_d = d; best = e
				if best != null:
					battle._on_pick_target(u, TechniqueKit.strike_far(), best.grid_pos)
		battle._on_reveal()
		guard += 1
	assert_ne(battle.state.outcome(battle.tuning), BattleState.Outcome.ONGOING, "带 brain 性格的 2v2 在 30 回合内分胜负")
	assert_gt(battle.player_model.total, 0)
	remove_child(battle); battle.queue_free()

func test_game_over_locks_further_reveals():
	# 回归：验收 bug「玩家死后回合一直继续」——_on_reveal 在 game_over 后必须 no-op
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle.game_over = true   # 模拟战斗已结束
	var turn_before: int = battle.state.turn
	battle._on_reveal()       # 应被 game_over guard 挡住，什么都不做
	assert_eq(battle.state.turn, turn_before, "game_over 后揭晓不推进回合")
	assert_true(battle.game_over)
	remove_child(battle); battle.queue_free()

func test_battle_constructs_from_run_state():
	# 设 MetaSession.current_run → battle.gd 应据此构造（玩家=roster 主角，敌方=node_cfg）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	var node_cfg: Dictionary = {"enemies":[
		{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,3],"stance":Stance.Id.WOOD,"kit":["chifeng_lianci","chifeng_yajin"]}
	]}
	MetaSession.current_run = run
	MetaSession.current_node_cfg = node_cfg
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	var p: Array = battle.state.units.filter(func(u): return u.team == 0)
	var e: Array = battle.state.units.filter(func(u): return u.team == 1)
	assert_eq(p.size(), 1, "玩家方=roster（主角）")
	assert_eq(e.size(), 1, "敌方=node_cfg")
	assert_eq(String(e[0].id), "e1")
	remove_child(battle)
	battle.queue_free()
	# 清理全局态，不污染后续测试
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}
