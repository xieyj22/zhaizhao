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

func test_init_run_has_modifier_state():
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 42)
	assert_true(run.modifier_state.size() > 0, "init_run roll 出 modifier，state 非空")
	var run2 := RunFactory.init_run(meta, 42)
	assert_eq(run.modifier_state, run2.modifier_state, "同 seed 同 modifier_state（确定性）")

func test_apply_init_hooks_relation_delta():
	# 直接测纯消费函数：注入 modifier_state，验证 relation 消费
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.modifier_state = {"relation_start_delta":-20}
	RunFactory.apply_init_hooks(run, meta)   # 纯消费：relation -= 20（F8 锁死除外）
	assert_eq(run.faction_relations["F4"], 20, "F4 40-20=20")
	assert_eq(run.faction_relations["F8"], -100, "F8 锁死不变")

func test_apply_init_hooks_max_hp_mult():
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.modifier_state = {"max_hp_mult":1.5}
	RunFactory.apply_init_hooks(run, meta)
	assert_eq(run.player_roster[0]["max_hp"], 51, "34*1.5=51（T10f 调平：主角 hp 20→34）")
	assert_eq(run.player_roster[0]["hp"], 51)

func test_apply_init_hooks_empty_is_noop():
	# 边界守护：空 modifier_state → 不改 relation/hp
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	var f4_before: int = int(run.faction_relations["F4"])
	var hp_before: int = int(run.player_roster[0]["max_hp"])
	run.modifier_state = {}
	RunFactory.apply_init_hooks(run, meta)
	assert_eq(run.faction_relations["F4"], f4_before)
	assert_eq(run.player_roster[0]["max_hp"], hp_before)

# —— 招募同袍（_ally）——

func test_ally_dict_fields_complete():
	var a: Dictionary = RunFactory._ally("F4", 1)
	# 15 字段全在（与 _protagonist 对称 schema）
	for key in ["id","team","hp","max_hp","opening","max_opening","stance","grid_pos",
				"facing","guard_broken","alive","display_name","faction_id",
				"personality_id","kit_ids","is_protagonist"]:
		assert_true(a.has(key), "队友字段 %s 存在" % key)

func test_ally_id_unique_not_protagonist():
	# id = ally_<fid>_<idx>，唯一非 "protagonist"
	var a1: Dictionary = RunFactory._ally("F4", 1)
	var a2: Dictionary = RunFactory._ally("F4", 2)
	assert_eq(a1["id"], "ally_F4_1")
	assert_ne(a1["id"], "protagonist")
	assert_ne(a1["id"], a2["id"], "不同 idx → 不同 id（回写不错位）")
	assert_false(a1["is_protagonist"], "队友死不结束局")

func test_ally_grid_pos_advances_with_index():
	# grid_pos 按 roster index 取槽，与主角 [1,3] 错开且互不重叠
	assert_eq(RunFactory._ally("F2", 1)["grid_pos"], [1,4], "idx1 → slot1")
	assert_eq(RunFactory._ally("F3", 2)["grid_pos"], [2,3], "idx2 → slot2")
	assert_ne(RunFactory._ally("F2", 1)["grid_pos"], [1,3], "不与主角同格")

func test_ally_kit_from_signature():
	# kit = 派系招牌 2 招全带
	assert_eq(RunFactory._ally("F1", 1)["kit_ids"], ["jingzhao_chuzhao","jingzhao_yingzhao"])
	assert_eq(RunFactory._ally("F2", 1)["kit_ids"], ["chifeng_lianci","chifeng_yajin"])

func test_ally_personality_from_tendency():
	assert_eq(RunFactory._ally("F2", 1)["personality_id"], "brute")
	assert_eq(RunFactory._ally("F4", 1)["personality_id"], "brain")
	assert_eq(RunFactory._ally("F6", 1)["personality_id"], "trick")

func test_ally_stance_from_faction():
	assert_eq(RunFactory._ally("F2", 1)["stance"], Stance.Id.FIRE, "赤锋烈火")
	assert_eq(RunFactory._ally("F4", 1)["stance"], Stance.Id.WATER, "听潮柔水")
	assert_eq(RunFactory._ally("F1", 1)["stance"], Stance.Id.METAL)

func test_ally_hp_below_protagonist():
	# 叙事守护：队友略脆（< 主角）
	assert_lt(int(RunFactory._ally("F4", 1)["max_hp"]), int(RunFactory._protagonist([])["max_hp"]), "队友 max_hp < 主角")
	assert_eq(int(RunFactory._ally("F4", 1)["hp"]), int(RunFactory._ally("F4", 1)["max_hp"]), "满血招募")

func test_ally_json_safe_roundtrip():
	# roster 含队友 → to_dict → JSON → from_dict 字段无丢失（尤其 grid_pos/kit_ids Array）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.player_roster.append(RunFactory._ally("F4", 1))
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	assert_eq(restored.player_roster.size(), 2)
	var ally: Dictionary = restored.player_roster[1]
	assert_eq(ally["id"], "ally_F4_1")
	# 注：Godot 4.7 JSON.parse_string 把数字转 float（坑②），逐元素 int 验坐标非整体 assert_eq
	var gp: Array = ally["grid_pos"]
	assert_eq(int(gp[0]), 1, "grid_pos x round-trip")
	assert_eq(int(gp[1]), 4, "grid_pos y round-trip")
	assert_eq(ally["kit_ids"], ["tingchao_yuanchao","tingchao_xieli"], "kit_ids Array round-trip")
	assert_false(ally["is_protagonist"])

func test_apply_init_hooks_max_hp_mult_affects_allies():
	# 固化行为：max_hp_mult 遍历全 roster（含招募的队友）。
	# 注：招募发生在 hub 运行时（init_run 之后），init hook 已消费完，新队友不受影响——
	# 本测验证的是"若 roster 含队友时重跑 hook 会乘全员"，文档化此遍历语义。
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.player_roster.append(RunFactory._ally("F4", 1))
	var ally_hp_before: int = int(run.player_roster[1]["max_hp"])   # 26（T10f 调平）
	run.modifier_state = {"max_hp_mult":1.5}
	RunFactory.apply_init_hooks(run, meta)
	assert_eq(int(run.player_roster[1]["max_hp"]), 39, "队友 26*1.5=39（遍历全 roster）")
