extends GutTest

# T10e Bug A：map.gd:_node_cfg_for 硬编码 boss=hailianzheng / 敌人=chifeng，真实游戏里
# ch2/3/4 所有 boss 战都变赫连铮、所有普通战都同一个 chifeng 敌人。
# 修法：boss 分支读节点真实 boss_id（ch1 无字段→回退 hailianzheng），
#       非 boss 分支用 EnemyPool.pick 取组合。

func after_each():
	MetaSession.current_run = null
	MetaSession.current_node_cfg = {}

func _instantiate_map(run: RunState) -> Node2D:
	MetaSession.current_run = run
	var map := preload("res://src/scenes/map/map.tscn").instantiate()
	add_child(map)
	return map

func _find_boss_node_id(chapter: int) -> String:
	# 在任意 ch 图里找首个 type=="boss" 节点 id
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	if chapter != 1:
		# 合成目标章图（init_run 只生成章1）
		run.chapter_maps[chapter] = MapGenerator.generate_map(7, chapter, 0)
	for id in run.chapter_maps[chapter]["nodes"]:
		if String(run.chapter_maps[chapter]["nodes"][id].get("type","")) == "boss":
			return String(id)
	return ""

# ---- boss 分支：读节点真实 boss_id（非硬编码 hailianzheng）----

func test_node_cfg_for_boss_reads_real_boss_id_ch2():
	# ch2 boss 节点带 boss_id（moqingniang/yanjiu）；_node_cfg_for 必须返回真实 boss_id
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.chapter_maps[2] = MapGenerator.generate_map(7, 2, 0)
	run.current_chapter = 2
	var map := _instantiate_map(run)
	var boss_node := _find_first_boss_in_map(run.chapter_maps[2])
	assert_ne(boss_node, "", "ch2 图有 boss 节点")
	var cfg: Dictionary = map._node_cfg_for("boss", boss_node)
	var bid: String = String(cfg.get("boss_id", ""))
	# ch2 boss ∈ {moqingniang, yanjiu}，不应是 hailianzheng（章1 boss）
	assert_true(bid == "moqingniang" or bid == "yanjiu",
		"ch2 boss_id 读节点真实值（%s），非硬编码 hailianzheng" % bid)
	remove_child(map); map.queue_free()

func test_node_cfg_for_boss_reads_real_boss_id_ch3():
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.chapter_maps[3] = MapGenerator.generate_map(7, 3, 0)
	run.current_chapter = 3
	var map := _instantiate_map(run)
	var boss_node := _find_first_boss_in_map(run.chapter_maps[3])
	var cfg: Dictionary = map._node_cfg_for("boss", boss_node)
	var bid: String = String(cfg.get("boss_id", ""))
	# ch3 boss ∈ {zongzhenglie, peiyuan}，trait 注入由 BattleBuilder 负责（_unit_from_boss）
	assert_true(bid == "zongzhenglie" or bid == "peiyuan",
		"ch3 boss_id 读节点真实值（%s）" % bid)
	remove_child(map); map.queue_free()

func test_node_cfg_for_boss_ch1_falls_back_to_hailianzheng():
	# 边界守护：ch1 boss 节点无 boss_id 字段（M3 语义）→ 回退 hailianzheng（章1逐字节不变）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)   # ch1
	var map := _instantiate_map(run)
	var boss_node := _find_first_boss_in_map(run.chapter_maps[1])
	var cfg: Dictionary = map._node_cfg_for("boss", boss_node)
	assert_eq(String(cfg.get("boss_id", "")), "hailianzheng",
		"ch1 boss 无 boss_id 字段 → 回退 hailianzheng（M3 语义不变）")
	remove_child(map); map.queue_free()

func test_node_cfg_for_boss_returns_boss_type_for_unlockrules():
	# escort/visit 节点也调 _node_cfg_for 传给 UnlockRules——boss 返回必须含 node_type
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.chapter_maps[2] = MapGenerator.generate_map(7, 2, 0)
	run.current_chapter = 2
	var map := _instantiate_map(run)
	var boss_node := _find_first_boss_in_map(run.chapter_maps[2])
	var cfg: Dictionary = map._node_cfg_for("boss", boss_node)
	assert_eq(String(cfg.get("node_type", "")), "boss",
		"boss 分支返回 node_type=boss（UnlockRules 兼容）")
	remove_child(map); map.queue_free()

# ---- 非 boss 分支：用 EnemyPool.pick（非硬编码 chifeng）----

func test_node_cfg_for_nonboss_uses_enemy_pool_not_hardcoded():
	# ch2 duel 节点非 boss：_node_cfg_for 应返回 EnemyPool.pick 组合（多组合，非固定 chifeng）。
	# 关键：enemies 数组来自 pool，组合 personality/faction 多样；硬编码实现总是单一 chifeng(F2/brute)。
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.chapter_maps[2] = MapGenerator.generate_map(7, 2, 0)
	run.current_chapter = 2
	var map := _instantiate_map(run)
	# 找 ch2 第一个 duel 节点
	var duel_node := ""
	for id in run.chapter_maps[2]["nodes"]:
		if String(run.chapter_maps[2]["nodes"][id].get("type","")) == "duel":
			duel_node = String(id); break
	assert_ne(duel_node, "", "ch2 有 duel 节点")
	var cfg: Dictionary = map._node_cfg_for("duel", duel_node)
	# EnemyPool ch2 duel 组合：faction ∈ {F4(brain), F6(trick), F7(trick)} 等，非 F2/brute-only chifeng
	# 硬编码 bug 返回固定 e1@F2 brute。断言敌人 faction/personality 来自 pool（ch2 duel 至少一敌非 F2-brute）
	var enemies: Array = cfg.get("enemies", [])
	assert_false(enemies.is_empty(), "duel 节点 enemies 非空（pool 组合）")
	# 至少有一个敌人 faction != "F2" 或 personality != "brute"（ch2 duel 池含 F4/F6/F7）
	var has_non_chifeng := false
	for e in enemies:
		if String(e.get("faction","")) != "F2" or String(e.get("personality","")) != "brute":
			has_non_chifeng = true
	assert_true(has_non_chifeng,
		"ch2 duel 敌人来自 EnemyPool（含非 chifeng 组合），非硬编码 chifeng")
	# node_type 保留（UnlockRules 用）
	assert_eq(String(cfg.get("node_type","")), "duel", "非 boss 返回 node_type")
	remove_child(map); map.queue_free()

func test_node_cfg_for_nonboss_ch1_pool_unchanged():
	# 边界守护：ch1 非 boss 节点 enemies 来自 EnemyPool ch1 池（与 harness 一致；ch1 池逐字节=M3）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	var map := _instantiate_map(run)
	var duel_node := ""
	for id in run.chapter_maps[1]["nodes"]:
		if String(run.chapter_maps[1]["nodes"][id].get("type","")) == "duel":
			duel_node = String(id); break
	assert_ne(duel_node, "", "ch1 有 duel 节点")
	var cfg: Dictionary = map._node_cfg_for("duel", duel_node)
	var enemies: Array = cfg.get("enemies", [])
	assert_false(enemies.is_empty(), "ch1 duel enemies 非空")
	# 敌人 id 来自 ch1 pool（chifeng_patrol/pangen_elder/huazong_trickster/...）
	var e0: Dictionary = enemies[0] if not enemies.is_empty() else {}
	assert_true(e0.has("kit"), "ch1 duel 敌人带 kit（pool 格式，非硬编码占位）")
	remove_child(map); map.queue_free()

func _find_first_boss_in_map(m: Dictionary) -> String:
	for id in m["nodes"]:
		if String(m["nodes"][id].get("type","")) == "boss":
			return String(id)
	return ""
