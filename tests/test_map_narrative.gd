extends GutTest

func _run() -> RunState:
	var r := RunFactory.init_run(MetaState.new_first_play(), 7)
	r.current_chapter = 3
	r.chapter_progress[3] = {"bosses_defeated": [], "nodes_visited": []}
	return r

func test_seg_for_layer_and_marking():
	var map := load("res://src/scenes/map/map.gd")
	var r := _run()
	assert_eq(map._seg_for_layer(r, 4), "mid", "L4→mid")
	assert_eq(map._seg_for_layer(r, 7), "close", "L7→close")
	assert_eq(map._seg_for_layer(r, 2), "", "其他层无")
	r.interlude_shown["3:mid"] = true
	assert_eq(map._seg_for_layer(r, 4), "", "已看过不重弹")
	assert_eq(map._seg_for_layer(null, 4), "", "无 run 安全")

func test_seg_open():
	var map := load("res://src/scenes/map/map.gd")
	var r := _run()
	assert_eq(map._seg_open(r), "open", "未看过章 open")
	r.interlude_shown["3:open"] = true
	assert_eq(map._seg_open(r), "", "看过不重弹")

# ---- 终审修（Important#1）：战斗节点 close/mid 过场段经 node_cfg 带给 battle ----
# 根因：L7 恒 boss→切战斗，_prose_hint 设在将销毁的场景上玩家永读不到，
# 且 interlude_shown 标记已烧（撤退回图也不再显示）；mid 仅 L4 恰为 visit/escort 才可见。
# 修法：战斗路径把段文本经 MetaSession.current_node_cfg.interlude_line 带给 battle
# 作战前旁白行；仅实际带出（将显示）才烧标记；空段不烧（与 open 路径一致）。
# 测试子类覆写 map.gd 两个 seam：_interlude_text 注入段文本（CHAPTER_INTERLUDES 是
# const，运行时只读不可 patch）、_enter_battle_scene 拦截真实切场景。
# （不用 GUT partial_double：doubler 9.6 对 map.gd 带类型返回值的方法生成失败。）

func after_each():
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}

class StubInterludeMap extends "res://src/scenes/map/map.gd":
	var stub_text := ""   # 覆写 _interlude_text 的注入值（""=真实空段语义）
	func _interlude_text(seg: String) -> String:
		return stub_text
	func _enter_battle_scene() -> void:
		pass   # 测试内拦截真实 change_scene_to_file

func _stub_map(r: RunState, stub_text: String) -> StubInterludeMap:
	MetaSession.current_run = r
	var map := StubInterludeMap.new()
	map.stub_text = stub_text
	add_child(map)
	return map

func _run_ch3() -> RunState:
	var r := _run()
	r.chapter_maps[3] = MapGenerator.generate_map(7, 3, 0)
	r.interlude_shown["3:open"] = true   # 预烧 open，跳过入章过场侧噪
	return r

func _zzl_boss_node(r: RunState) -> String:
	for nid: Variant in r.chapter_maps[3]["nodes"]:
		if r.chapter_maps[3]["nodes"][nid].get("boss_id", "") == "zongzhenglie":
			return String(nid)
	return ""

func test_enter_battle_node_carries_close_interlude_to_battle():
	var r := _run_ch3()
	var boss_node := _zzl_boss_node(r)
	assert_ne(boss_node, "", "ch3 图有宗政烈 L7 boss 节点")
	var map := _stub_map(r, "谷底最后一层，锈得最深的那批剑都埋在这里。")
	map._on_enter_node(boss_node)
	assert_true(MetaSession.current_node_cfg.has("interlude_line"),
		"战斗节点：close 段文本经 node_cfg 带给 battle（非 _prose_hint）")
	assert_eq(String(MetaSession.current_node_cfg.get("interlude_line", "")),
		"谷底最后一层，锈得最深的那批剑都埋在这里。", "interlude_line=close 段文本")
	assert_true(r.interlude_shown.has("3:close"), "实际带出（将显示）才烧 interlude_shown")
	remove_child(map)
	map.queue_free()

func test_enter_battle_node_replay_no_carry_no_burn():
	var r := _run_ch3()
	var boss_node := _zzl_boss_node(r)
	(r.chapter_progress[3]["nodes_visited"] as Array).append(boss_node)   # 预标已通关 → 回放
	var map := _stub_map(r, "回放不该再带的段文本")
	map._on_enter_node(boss_node)
	assert_false(MetaSession.current_node_cfg.has("interlude_line"), "回放进同节点不带段文本")
	assert_true(bool(MetaSession.current_node_cfg.get("replay", false)), "回放标记仍在")
	assert_false(r.interlude_shown.has("3:close"), "回放不烧标记")
	remove_child(map)
	map.queue_free()

func test_enter_battle_node_empty_interlude_not_burned():
	# 非空门（Finding 3）：真实数据 ch3 close/mid=""（批D 未灌）→ 空段不带不烧标记
	var r := _run_ch3()
	var boss_node := _zzl_boss_node(r)
	var map := _stub_map(r, "")
	map._on_enter_node(boss_node)
	assert_false(MetaSession.current_node_cfg.has("interlude_line"), "空段不带")
	assert_false(r.interlude_shown.has("3:close"), "空段不烧标记（与 open 路径非空门一致）")
	remove_child(map)
	map.queue_free()
