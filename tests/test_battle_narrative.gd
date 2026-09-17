extends GutTest

func after_each():
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}
	MetaSession.reduce_motion = false   # M 键测试的全局态兜底

func test_dialog_lines_for_gates():
	var boss_cfg: Dictionary = {"boss_id": "zongzhenglie", "node_type": "boss"}
	var replay_cfg: Dictionary = {"boss_id": "zongzhenglie", "node_type": "boss", "replay": true}
	var normal_cfg: Dictionary = {"node_type": "duel", "enemies": []}
	var battle := load("res://src/scenes/battle/battle.gd")
	assert_gt(battle._dialog_lines_for(boss_cfg, "pre").size(), 0, "boss 非回放→有战前对白")
	assert_eq(battle._dialog_lines_for(replay_cfg, "pre").size(), 0, "回放→跳过")
	assert_eq(battle._dialog_lines_for(normal_cfg, "pre").size(), 0, "非 boss→跳过")
	assert_eq(battle._dialog_lines_for(boss_cfg, "nope").size(), 0, "key 未命中→跳过")

func test_trait_line_key_detection():
	var battle := load("res://src/scenes/battle/battle.gd")
	var u := UnitState.new()
	u.boss_id = "leiwanjun"; u.frenzied = true; u.hp = 10; u.max_hp = 20
	assert_eq(battle._trait_line_key("leiwanjun", false, 10, u, false), "frenzy_on", "翻转为狂暴")
	assert_eq(battle._trait_line_key("leiwanjun", true, 10, u, false), "", "已狂暴不再触发")
	var drained := UnitState.new()
	drained.boss_id = "yanwujiu"; drained.hp = 30; drained.max_hp = 65
	assert_eq(battle._trait_line_key("yanwujiu", false, 20, drained, false), "drain_on", "hp 上升=吸血")
	var reader := UnitState.new()
	reader.boss_id = "sikongyi"
	assert_eq(battle._trait_line_key("sikongyi", false, 50, reader, true), "read_hit", "读中+心眼")
	assert_eq(battle._trait_line_key("sikongyi", false, 50, reader, false), "", "未读中不触发")
	assert_eq(battle._trait_line_key("", false, 10, u, false), "", "无 boss_id 不触发")

func test_pre_dialog_opens_and_skips():
	var battle_tscn := preload("res://src/scenes/battle/battle.tscn")
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.current_chapter = 3
	run.chapter_progress[3] = {"bosses_defeated": [], "nodes_visited": []}
	run.chapter_maps[3] = MapGenerator.generate_map(7, 3, 0)
	# 定位章3 L7 宗政烈节点
	var boss_node := ""
	for nid: Variant in run.chapter_maps[3]["nodes"]:
		var nd: Dictionary = run.chapter_maps[3]["nodes"][nid]
		if nd.get("boss_id", "") == "zongzhenglie":
			boss_node = String(nid)
	RunFlow.enter_node(run, boss_node)
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"boss_id": "zongzhenglie", "node_type": "boss"}
	var battle := battle_tscn.instantiate()
	add_child(battle)
	assert_true(battle.dialog_open, "战前对白打开")
	# 跳过对白
	for c in battle.get_children():
		if c is DialogBox:
			c.skip()
	assert_false(battle.dialog_open, "跳过后关闭")
	remove_child(battle)
	battle.queue_free()

func test_replay_battle_skips_pre_dialog():
	var battle_tscn := preload("res://src/scenes/battle/battle.tscn")
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.current_chapter = 3
	run.chapter_progress[3] = {"bosses_defeated": ["zongzhenglie"], "nodes_visited": []}
	run.chapter_maps[3] = MapGenerator.generate_map(7, 3, 0)
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"boss_id": "zongzhenglie", "node_type": "boss", "replay": true}
	var battle := battle_tscn.instantiate()
	add_child(battle)
	assert_false(battle.dialog_open, "回放战不弹战前对白")
	remove_child(battle)
	battle.queue_free()

# ---- 终审修（Important#1）：node_cfg.interlude_line → 战前对白前 prepend 空 s 旁白行 ----
# map 战斗切换路径带出的本章 close/mid 过场段；boss 有 pre_lines 则旁白行 prepend 其前，
# 无 pre_lines（非 boss）则单独弹；回放一律不弹；缺键路径逐字节不变。

func _battle_run_ch3() -> RunState:
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.current_chapter = 3
	run.chapter_progress[3] = {"bosses_defeated": [], "nodes_visited": []}
	run.chapter_maps[3] = MapGenerator.generate_map(7, 3, 0)
	return run

func _find_dialog(battle) -> DialogBox:
	for c in battle.get_children():
		if c is DialogBox:
			return c
	return null

func test_interlude_line_prepended_as_narration_before_boss_pre():
	var run := _battle_run_ch3()
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"boss_id": "zongzhenglie", "node_type": "boss",
		"interlude_line": "雾在最深处合拢，千百年前的剑鸣停了。"}
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	assert_true(battle.dialog_open, "带段 → 战前对白打开")
	var box: DialogBox = _find_dialog(battle)
	assert_not_null(box, "对白框存在")
	if box != null:
		assert_eq(box.current_text(), "雾在最深处合拢，千百年前的剑鸣停了。",
			"首条=过场旁白行（prepend 于 boss pre_lines 前）")
		assert_eq(box.current_name(), "", "旁白行空名条（与 map 过场同观感）")
		box.skip()
	assert_false(battle.dialog_open, "跳过后关闭")
	remove_child(battle)
	battle.queue_free()

func test_interlude_line_alone_opens_dialog_nonboss():
	# L4 duel/sparring/hazard 带段（无 pre_lines）→ 旁白行单独弹
	var run := _battle_run_ch3()
	MetaSession.current_run = run
	var combo: Dictionary = EnemyPool.pick(3, "duel", 0, 0)
	MetaSession.current_node_cfg = {
		"node_type": "duel", "risk": 0,
		"personality": String(combo.get("personality", "brain")),
		"enemies": combo.get("enemies", []),
		"interlude_line": "行至半程，雾换了脾气。",
	}
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	assert_true(battle.dialog_open, "非 boss 无 pre_lines → 旁白行单独弹")
	var box: DialogBox = _find_dialog(battle)
	assert_not_null(box, "对白框存在")
	if box != null:
		assert_eq(box.current_text(), "行至半程，雾换了脾气。", "首条=过场旁白行")
		assert_eq(box.current_name(), "", "旁白行空名条")
		box.skip()
	remove_child(battle)
	battle.queue_free()

func test_replay_interlude_line_suppressed():
	# 回放一律不弹（map 侧不带 + battle 侧 replay 门双保险）
	var run := _battle_run_ch3()
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"boss_id": "zongzhenglie", "node_type": "boss",
		"replay": true, "interlude_line": "回放不该出现的旁白"}
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	assert_false(battle.dialog_open, "回放不弹旁白")
	assert_null(_find_dialog(battle), "回放无对白框")
	remove_child(battle)
	battle.queue_free()

func test_no_interlude_key_first_line_is_boss_pre():
	# 老路径回归：node_cfg 无 interlude_line 键 → 首条=boss pre_lines 第一句（与修前一致）
	var run := _battle_run_ch3()
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"boss_id": "zongzhenglie", "node_type": "boss"}
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	var box: DialogBox = _find_dialog(battle)
	assert_not_null(box, "对白框存在")
	if box != null:
		assert_eq(box.current_name(), "宗政烈", "首条名条=boss")
		assert_eq(box.current_text(), "镜照门的种，倒敢往沉剑谷里走。", "首条=pre 第一句")
		box.skip()
	remove_child(battle)
	battle.queue_free()

# ---- 终审修（Minor#2）：M 键须过对白门 ----

func test_m_key_ignored_while_pre_dialog_open():
	var run := _battle_run_ch3()
	MetaSession.current_run = run
	MetaSession.current_node_cfg = {"boss_id": "zongzhenglie", "node_type": "boss"}
	MetaSession.reduce_motion = false
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	assert_true(battle.dialog_open, "战前对白打开")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_M
	battle._unhandled_input(ev)
	assert_false(MetaSession.reduce_motion, "对白打开时按 M 不切 reduce_motion")
	var box: DialogBox = _find_dialog(battle)
	if box != null:
		box.skip()
	assert_false(battle.dialog_open, "对白已关")
	battle._unhandled_input(ev)
	assert_true(MetaSession.reduce_motion, "对白关闭后 M 恢复切换")
	remove_child(battle)
	battle.queue_free()
