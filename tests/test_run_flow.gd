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
