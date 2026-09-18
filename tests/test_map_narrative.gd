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
	# 非空门（Finding 3）：stub 注入空段 → 空段不带不烧标记
	var r := _run_ch3()
	var boss_node := _zzl_boss_node(r)
	var map := _stub_map(r, "")
	map._on_enter_node(boss_node)
	assert_false(MetaSession.current_node_cfg.has("interlude_line"), "空段不带")
	assert_false(r.interlude_shown.has("3:close"), "空段不烧标记（与 open 路径非空门一致）")
	remove_child(map)
	map.queue_free()

# ---- 终审转账项：visit/escort/start 非战斗节点的 mid 散文行（幽灵描写行） ----
# 根因：_on_enter_node 非战斗路径先 _show_interlude_prose 设 _prose_hint.text，再
# _refresh_scene()——后者 free _layer 全部子节点（含 _prose_hint）并在 _build_ui 里
# 重建为空 → 文本至多存活一帧且 interlude_shown 已烧，玩家永远读不到。
# 修法：_show_interlude_prose 先存实例字段 _prose_text，_build_ui 重建 _prose_hint
# 后从字段重挂文本。

func _visit_node(r: RunState) -> String:
	for nid: Variant in r.chapter_maps[3]["nodes"]:
		if r.chapter_maps[3]["nodes"][nid]["type"] == "visit":
			return String(nid)
	return ""

func test_enter_visit_node_mid_prose_survives_refresh():
	var r := _run_ch3()
	var visit_node := _visit_node(r)
	assert_ne(visit_node, "", "ch3 图有 visit 节点（类型下限 visit>=1）")
	r.chapter_maps[3]["nodes"][visit_node]["layer"] = 4   # mid 段触发层
	var map := _stub_map(r, "雾从谷底漫上来，一寸一寸漫过锈剑。")
	map._on_enter_node(visit_node)
	await get_tree().process_frame   # 等 _refresh_scene 的重建落地
	assert_true(r.interlude_shown.has("3:mid"), "进 L4 visit：mid 标记已烧")
	assert_eq(map._prose_hint.text, "雾从谷底漫上来，一寸一寸漫过锈剑。",
		"_refresh_scene 重建后 _prose_hint 仍持有 mid 段文本（非幽灵行）")
	remove_child(map)
	map.queue_free()

func test_enter_visit_node_empty_interlude_not_burned_hint_empty():
	var r := _run_ch3()
	var visit_node := _visit_node(r)
	r.chapter_maps[3]["nodes"][visit_node]["layer"] = 4
	var map := _stub_map(r, "")
	map._on_enter_node(visit_node)
	await get_tree().process_frame
	assert_false(r.interlude_shown.has("3:mid"), "空段不烧标记（非空门不回退）")
	assert_eq(map._prose_hint.text, "", "空段：hint 空")
	remove_child(map)
	map.queue_free()
