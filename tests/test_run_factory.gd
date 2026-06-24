extends GutTest

func test_init_run_protagonist_only():
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 42)
	assert_eq(run.player_roster.size(), 1, "仅主角")
	assert_true(run.player_roster[0]["is_protagonist"])
	assert_eq(run.current_chapter, 1)
	assert_eq(run.current_node_id, "", "起始在 hub（空 node）")
	assert_eq(run.jianghu_credit, 0)

func test_init_run_unlocked_is_tier1():
	var meta := MetaState.new_first_play()
	meta.meta_unlocked_pool.append("chifeng_lianci")   # 加一个 T2 招到 meta 池
	var run := RunFactory.init_run(meta, 42)
	for tid in run.unlocked_techniques:
		assert_eq(TechniqueData.tier_of(StringName(tid)), 1, "%s 应是 T1" % tid)
	assert_false(run.unlocked_techniques.has("chifeng_lianci"), "T2 不在开局 kit")

func test_init_run_relations_copied_from_meta():
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 42)
	assert_eq(run.faction_relations["F4"], 40, "关系拷贝自 meta")
	assert_eq(run.faction_relations["F8"], -100)
	# 改 run 关系不影响 meta（深拷贝）
	run.faction_relations["F4"] = 99
	assert_eq(meta.meta_faction_relations["F4"], 40, "meta 不被 run 污染")

func test_init_run_chapter_map_generated():
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 42)
	assert_true(run.chapter_maps.has(1), "章 1 图已生成")
	assert_eq(run.chapter_maps[1]["chapter"], 1)
	assert_true(run.chapter_maps[1]["nodes"].size() >= 9)
