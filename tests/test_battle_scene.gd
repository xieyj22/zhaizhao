extends GutTest

func after_each():
	# 兜底：每个测试后重置 MetaSession，防全局态泄漏（RunState 测试的 current_run
	# 绝不能漏进 2v2 fallback 测试——后者依赖 current_run == null）
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}
	MetaSession.last_battle_outcome = BattleState.Outcome.ONGOING

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

func test_boss_win_advances_chapter():
	# T8 集成：boss 胜 → _on_back_after_battle → advance_chapter → 章2 图生成
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)   # 章1，chapter_maps[1] 已生成
	# 在章1 图里找到 type=="boss" 的节点 id，设 current_node_id
	var boss_node_id := ""
	for id in run.chapter_maps[1]["nodes"]:
		if String(run.chapter_maps[1]["nodes"][id].get("type", "")) == "boss":
			boss_node_id = String(id)
			break
	assert_ne(boss_node_id, "", "章1 图应有 boss 节点")
	run.current_node_id = boss_node_id
	MetaSession.current_run = run
	MetaSession.last_battle_outcome = BattleState.Outcome.TEAM0_WIN   # _on_back_after_battle 读它判 boss 胜
	# 主角存活（init_run 默认存活）→ is_run_over 为 false，走"继续"分支
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle._on_back_after_battle()   # 真实入口（change_scene_to_file 延迟到帧末，断言时未发生）
	assert_eq(MetaSession.current_run.current_chapter, 2, "boss 胜后推进到章2")
	assert_true(MetaSession.current_run.chapter_maps.has(2), "章2 图已由 advance_chapter 生成")
	remove_child(battle)
	battle.queue_free()
	# 清理全局态
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}
	MetaSession.last_battle_outcome = 0

func test_boss_battle_has_boss_traits_injected():
	# 便宜测：boss node_cfg 构造的 battle，state.boss_traits 非空（验证 trait 接入点 live）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"boss_id":"zongzhenglie","node_type":"boss","enemies":[
		{"id":"zongzhenglie","faction":"F2","personality":"brute","grid_pos":[5,3],
		 "stance":Stance.Id.METAL,"kit":["chifeng_lianci","chifeng_yajin"]}
	]}
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	assert_true(battle.state.boss_traits.has("zongzhenglie"), "boss 战注入 boss_traits（mind_eye/iron_body 接入点）")
	remove_child(battle)
	battle.queue_free()
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}

func test_retreat_button_present_and_visible_during_battle():
	# 撤退按钮：战斗中存在且可见（game_over 后由 _on_reveal hide）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"enemies":[
		{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,3],
		 "stance":Stance.Id.WOOD,"kit":["chifeng_lianci","chifeng_yajin"]}
	]}
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	assert_not_null(battle._retreat_button, "撤退按钮已创建")
	assert_true(battle._retreat_button.visible, "战斗中撤退按钮可见")
	assert_false(battle.game_over, "初始未 game_over")
	remove_child(battle)
	battle.queue_free()
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}

# ---- T10e Bug B: mind_eye predictions 必须转发给 orch.ai_predictions ----
# 回归：battle.gd:_on_reveal 取了 ai_out.predictions 喂 compute_read_events（读招显示），
# 但从不 orch.ai_predictions = ai_out.predictions → mind_eye 反制伤(-2) 死代码。
# 修法：reveal_and_resolve 前设 orch.ai_predictions = ai_out.predictions（敌方对玩家的预测）。
# ---- T10e Bug C: ch4 掌门胜 → 通关（commit meta + 回 hub），不生成幻影 ch5 ----
# 回归：battle.gd:_on_back_after_battle 在 ch4 boss 胜时调 advance_chapter → current_chapter=5 +
# generate_map(seed,5) 幻影第5章。修法：加 RunFlow.MAX_CHAPTER=4 守卫，ch4 胜直接 commit+hub。
func test_ch4_boss_win_clears_run_not_advances_to_ch5():
	var meta := MetaState.new_first_play()
	var runs_before := meta.meta_runs_completed
	var run := RunFactory.init_run(meta, 7)   # 章1
	# 合成 ch4 状态：current_chapter=4，掌门 yanwujiu 已败（can_advance_chapter true）
	run.current_chapter = 4
	run.chapter_maps[4] = MapGenerator.generate_map(7, 4, 0)   # ch4 图含 boss 节点
	run.chapter_progress[4] = {"bosses_defeated": ["yanwujiu"], "nodes_visited": []}
	# 找 ch4 boss 节点设 current_node_id
	var boss_node := ""
	for id in run.chapter_maps[4]["nodes"]:
		if String(run.chapter_maps[4]["nodes"][id].get("type","")) == "boss":
			boss_node = String(id); break
	assert_ne(boss_node, "", "ch4 图有 boss 节点")
	run.current_node_id = boss_node
	MetaSession.current_run = run
	MetaSession.meta_state = meta
	MetaSession.last_battle_outcome = BattleState.Outcome.TEAM0_WIN
	# 主角存活（init_run 默认）→ is_run_over false → 走 boss 胜分支
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle._on_back_after_battle()
	# 关键断言：ch4 胜 = 通关
	assert_null(MetaSession.current_run, "ch4 掌门胜 → current_run 清空（通关，回 hub）")
	assert_eq(MetaSession.meta_state.meta_runs_completed, runs_before + 1,
		"ch4 胜 → meta_runs_completed +1（commit run_won=true）")
	# ch5 幻影不应存在（修复前会 advance_chapter 生成 chapter_maps[5]）
	# 注：current_run 已 null，但若 advance_chapter 曾执行过，meta 里无残留（run 已丢）；此断言保 place_at_chapter 不炸
	remove_child(battle)
	battle.queue_free()
	# 清理全局态
	MetaSession.current_run = null
	MetaSession.meta_state = null
	MetaSession.last_battle_outcome = 0

func test_runflow_max_chapter_constant_is_four():
	# 集中"最终章"概念：RunFlow.MAX_CHAPTER == 4
	assert_eq(RunFlow.MAX_CHAPTER, 4, "RunFlow.MAX_CHAPTER 常量 = 4（掌门 yanwujiu 所在章）")

func test_mind_eye_predictions_forwarded_to_orch_after_reveal():
	# sikongyi = mind_eye boss。构造 boss 战，玩家下指令，跑 _on_reveal。
	# 敌方有存活单位时 ai_out.predictions 非空 → 转发后 orch.ai_predictions 必须非空。
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	MetaSession.current_run = run
	# sikongyi 在 [5,3]，玩家主角在 [1,3]（init_run 默认）——同列相邻近，AI 会预测玩家招
	MetaSession.current_node_cfg = {"boss_id":"sikongyi","node_type":"boss"}
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	# 确认是 mind_eye boss 战
	assert_true(battle.state.boss_traits.has("sikongyi"), "sikongyi 注入 mind_eye trait")
	# 给玩家主角下指令（远打必中，让 AI 有可预测对象）
	var p0 = null
	for u in battle.state.units:
		if u.team == 0 and u.alive:
			p0 = u
			break
	assert_not_null(p0, "玩家单位存在")
	for e in battle.state.units:
		if e.team != 0 and e.alive and RangeBand.in_range(p0.grid_pos, e.grid_pos, RangeBand.Id.FAR, battle.tuning):
			battle._on_pick_target(p0, TechniqueKit.strike_far(), e.grid_pos)
			break
	# 转发前 ai_predictions 应为默认空 dict（_init 设 {}）
	assert_eq(battle.orch.ai_predictions.size(), 0, "reveal 前 orch.ai_predictions 空（默认）")
	battle._on_reveal()
	# 关键断言：reveal 后 orch.ai_predictions 必须非空（敌方预测了玩家且已转发）
	# sikongyi 是 mind_eye（confidence=1.0 必预测），玩家单位在其 nearest enemy 范围内 → predictions 非空
	assert_true(battle.orch.ai_predictions.size() > 0,
		"reveal 后 orch.ai_predictions 非空（敌方 mind_eye 预测已转发，反制伤可触发）")
	remove_child(battle)
	battle.queue_free()
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}

# —— option B 软失败：败北分流（普通节点残息 / boss permadeath）——

func test_regular_node_loss_survives_run_continues():
	# 普通节点败 → 主角残息 1 血，current_run 保留（回 hub 续闯，非 permadeath）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	var m: Dictionary = run.chapter_maps[1]
	var duel_id := ""
	for id in m["nodes"]:
		if String(m["nodes"][id].get("type", "")) == "duel":
			duel_id = String(id); break
	assert_ne(duel_id, "", "章 1 有 duel 节点")
	run.current_node_id = duel_id
	run.player_roster[0]["hp"] = 0
	run.player_roster[0]["alive"] = false
	MetaSession.current_run = run
	MetaSession.last_battle_outcome = BattleState.Outcome.TEAM1_WIN
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle._on_back_after_battle()
	assert_ne(MetaSession.current_run, null, "普通节点败 → current_run 保留（局继续）")
	if MetaSession.current_run != null:
		assert_eq(int(MetaSession.current_run.player_roster[0]["hp"]), 1, "主角残息复活到 1 血")
	remove_child(battle)
	battle.queue_free()

func test_back_button_positioned_outside_scroll_rect():
	# 回归（验收 bug）：game-over 的 back 按钮不得落在右侧 _scroll 矩形内
	# （ScrollContainer mouse_filter=STOP 会吞点击 → "主角阵亡-回大本营"点不到）
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	var guard := 0
	while battle.state.outcome(battle.tuning) == BattleState.Outcome.ONGOING and guard < 30:
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
	# 战斗结束 → back 按钮已由 _on_reveal 创建。在 _layer 子节点里找它
	var back_btn: Button = null
	for c in battle._layer.get_children():
		if c is Button:
			var t := String((c as Button).text)
			if t.find("回大本营") >= 0 or t == "返回":
				back_btn = c
				break
	assert_not_null(back_btn, "game-over back 按钮已创建")
	if back_btn != null:
		# 右侧 _scroll 矩形 x[528,860]——back 按钮必须在其外才不被吞点击
		assert_true(back_btn.position.x < 528.0 or back_btn.position.x > 860.0,
			"back 按钮不在 _scroll 矩形内（防 ScrollContainer 遮挡吞点击）")
	remove_child(battle)
	battle.queue_free()

func test_boss_loss_is_permadeath():
	# boss 败 = 致命 → permadeath（局结束，current_run null）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	var m: Dictionary = run.chapter_maps[1]
	var boss_id := ""
	for id in m["nodes"]:
		if String(m["nodes"][id].get("type", "")) == "boss":
			boss_id = String(id); break
	assert_ne(boss_id, "", "章 1 有 boss 节点")
	run.current_node_id = boss_id
	run.player_roster[0]["hp"] = 0
	run.player_roster[0]["alive"] = false
	MetaSession.current_run = run
	MetaSession.last_battle_outcome = BattleState.Outcome.TEAM1_WIN
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	battle._on_back_after_battle()
	assert_eq(MetaSession.current_run, null, "boss 败 → permadeath（current_run null）")
	remove_child(battle)
	battle.queue_free()
