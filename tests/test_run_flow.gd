extends GutTest

func _run() -> RunState:
	var r := RunFactory.init_run(MetaState.new_first_play(), 7)
	# 把 current_node_id 设到 L0 起点
	var m: Dictionary = r.chapter_maps[1]
	for id in m["nodes"]:
		if m["nodes"][id]["layer"] == 0:
			r.current_node_id = id
			break
	return r

func test_can_advance_node_only_along_edges():
	var run := _run()
	var m: Dictionary = run.chapter_maps[1]
	var nxt: Array = MapGenerator.reachable_next(m, run.current_node_id)
	assert_true(RunFlow.can_advance_node(run, nxt[0]), "沿边可前进")
	assert_false(RunFlow.can_advance_node(run, "n9_9"), "非邻接不可走")

func test_cannot_advance_chapter_before_boss():
	var run := _run()
	run.chapter_progress[1]["boss_defeated"] = false
	assert_false(RunFlow.can_advance_chapter(run), "boss 未败不可进下章")

func test_can_advance_chapter_after_boss():
	var run := _run()
	RunFlow.on_boss_defeated(run)
	assert_true(RunFlow.can_advance_chapter(run), "boss 败后可进下章")

func test_enter_node_updates_current_and_log():
	var run := _run()
	var m: Dictionary = run.chapter_maps[1]
	var nxt: Array = MapGenerator.reachable_next(m, run.current_node_id)
	RunFlow.enter_node(run, nxt[0])
	assert_eq(run.current_node_id, nxt[0])
	assert_true(run.chapter_progress[1]["nodes_visited"].has(nxt[0]), "记录已访问")

# —— 回归（bug: init_run 后 current_node_id="" 进 map 无节点可点）——
func _first_node_of_layer(run: RunState, layer: int) -> String:
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	for id in m["nodes"]:
		if int(m["nodes"][id]["layer"]) == layer:
			return id
	return ""

func test_place_at_chapter_start_fixes_unreachable_bug():
	# 复现：fresh init_run 的 current_node_id="" → 进图前 L1 节点不可 advance（bug 症状）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	assert_eq(run.current_node_id, "", "fresh run current_node_id 空（在 hub）")
	var l1 := _first_node_of_layer(run, 1)
	assert_false(RunFlow.can_advance_node(run, l1), "未定位起点时 L1 节点不可 advance（bug）")
	# 修复：place_at_chapter_start 定位到 L0 起点
	RunFlow.place_at_chapter_start(run)
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	assert_eq(int(m["nodes"][run.current_node_id]["layer"]), 0, "定位到 L0 起点")
	assert_true(RunFlow.can_advance_node(run, l1), "定位后 L1 节点可 advance（修复）")

func test_place_at_chapter_start_idempotent():
	# 已在某节点时（如战斗后返回 map）→ 幂等不动
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	RunFlow.place_at_chapter_start(run)
	var first: String = run.current_node_id
	assert_ne(first, "")
	RunFlow.place_at_chapter_start(run)
	assert_eq(run.current_node_id, first, "已在节点时幂等不改")

func test_is_run_over_when_protagonist_dead():
	# permadeath：主角死 = 局结束（回 hub，meta 沉淀）。主角存活 = 继续。
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	assert_false(RunFlow.is_run_over(run), "主角存活 → 局未结束")
	run.player_roster[0]["alive"] = false
	assert_true(RunFlow.is_run_over(run), "主角死 → 局结束")

func test_is_run_over_ally_dead_protagonist_alive():
	# 队友死、主角活 → 局不结束（permadeath 只认主角）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster.append(RunFactory._ally("F4", 1))
	run.player_roster[1]["alive"] = false   # 队友死
	assert_false(RunFlow.is_run_over(run), "队友死主角活 → 局未结束")

func test_is_run_over_protagonist_dead_ally_alive():
	# 主角死、队友活 → 局结束（即便有存活队友）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster.append(RunFactory._ally("F4", 1))
	run.player_roster[0]["alive"] = false   # 主角死
	run.player_roster[1]["alive"] = true    # 队友活
	assert_true(RunFlow.is_run_over(run), "主角死 → 局结束（无视队友存活）")
