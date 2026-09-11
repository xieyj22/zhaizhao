extends GutTest

func after_each():
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}

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
