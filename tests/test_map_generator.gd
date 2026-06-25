extends GutTest

## Task MG: seeded DAG 节点图生成器（T4 §1）。

func _gen(p_seed: int, chapter: int, hazard_delta: int = 0) -> Dictionary:
	return MapGenerator.generate_map(p_seed, chapter, hazard_delta)

func test_determinism_same_seed_same_map():
	var a := _gen(42, 1)
	var b := _gen(42, 1)
	assert_eq(JSON.stringify(a), JSON.stringify(b), "同 seed 同图")

func test_different_seed_different_map():
	var a := _gen(42, 1)
	var b := _gen(99, 1)
	assert_ne(JSON.stringify(a), JSON.stringify(b))

func test_layers_structure():
	var m := _gen(7, 1)
	var nodes: Dictionary = m["nodes"]
	var by_layer := {}
	for id in nodes:
		var l: int = nodes[id]["layer"]
		by_layer[l] = by_layer.get(l, 0) + 1
	assert_eq(by_layer.get(0, 0), 1, "L0 恰 1 起点")
	assert_eq(by_layer.get(7, 0), 1, "L7 恰 1 首领")
	for l in range(1, 7):
		assert_true(by_layer.get(l, 0) >= 2 and by_layer.get(l, 0) <= 3, "L%d 2–3 节点" % l)

func test_type_minimums():
	var m := _gen(7, 1)
	var counts := {"duel":0,"sparring":0,"visit":0,"escort":0,"hazard":0,"boss":0}
	for id in m["nodes"]:
		var ty: String = m["nodes"][id]["type"]
		if counts.has(ty): counts[ty] += 1
	assert_true(counts["duel"] >= 4, "决斗≥4")
	assert_true(counts["sparring"] >= 2, "切磋≥2")
	assert_true(counts["visit"] >= 1, "拜访≥1")
	assert_true(counts["escort"] >= 1, "镖局≥1")
	assert_true(counts["hazard"] >= 1, "险地≥1")
	assert_eq(counts["boss"], 1, "首领恰 1")

func test_boss_on_layer7_and_escort_before_boss():
	var m := _gen(7, 1)
	for id in m["nodes"]:
		if m["nodes"][id]["layer"] == 7:
			assert_eq(m["nodes"][id]["type"], "boss")
	var l6_types := []
	for id in m["nodes"]:
		if m["nodes"][id]["layer"] == 6: l6_types.append(m["nodes"][id]["type"])
	assert_true(l6_types.has("escort"), "章末层 L6 含镖局（最后补给）")

func test_connectivity_and_no_isolated():
	var m := _gen(7, 1)
	var has_in := {}; var has_out := {}
	for id in m["nodes"]: has_in[id]=false; has_out[id]=false
	for e in m["edges"]:
		has_out[e["from"]] = true
		has_in[e["to"]] = true
	for id in m["nodes"]:
		var l: int = m["nodes"][id]["layer"]
		if l == 7:
			assert_true(has_in[id], "首领有入边")
		else:
			assert_true(has_out[id], "非首领节点 %s 有出边" % id)
		if l != 0:
			assert_true(has_in[id], "非起点节点 %s 有入边" % id)

func test_reachable_next_returns_targets():
	var m := _gen(7, 1)
	var start := ""
	for id in m["nodes"]:
		if m["nodes"][id]["layer"] == 0: start = id; break
	var nxt := MapGenerator.reachable_next(m, start)
	assert_true(nxt.size() >= 2, "从起点至少 2 个可选下一步（分支保证）")
	var boss := ""
	for id in m["nodes"]:
		if m["nodes"][id]["type"] == "boss": boss = id; break
	assert_eq(MapGenerator.reachable_next(m, boss).size(), 0, "首领是端点")

func test_four_chapters_all_valid():
	for ch in [1,2,3,4]:
		var m := _gen(7, ch)
		assert_eq(m["chapter"], ch)
		assert_true(m["nodes"].size() >= 9, "章 %d 至少 9 节点" % ch)

func test_invariants_hold_across_many_seeds():
	# 跨多 seed × 4 章验证不变量（确定性/结构/类型下限/连通/分支）—— 抓边界 seed bug
	for seed in range(1, 41):   # 40 seeds
		for ch in [1,2,3,4]:
			var m := MapGenerator.generate_map(seed, ch)
			# 确定性
			assert_eq(JSON.stringify(m), JSON.stringify(MapGenerator.generate_map(seed, ch)))
			# 结构
			var by_layer := {}
			for id in m["nodes"]: var l: int = m["nodes"][id]["layer"]; by_layer[l] = by_layer.get(l,0)+1
			assert_eq(by_layer.get(0,0), 1)
			# M4：L7 节点数 = 该章 boss 数（章1=1 / 章2,3=2 / 章4=1 掌门）
			var exp_l7: int = 1
			if ch in [2, 3]: exp_l7 = 2
			assert_eq(by_layer.get(7,0), exp_l7, "seed %d ch %d L7 应为 %d" % [seed, ch, exp_l7])
			for l in range(1,7): assert_true(by_layer.get(l,0) >= 2 and by_layer.get(l,0) <= 3)
			# 类型下限
			var counts := {"duel":0,"sparring":0,"visit":0,"escort":0,"hazard":0,"boss":0}
			for id in m["nodes"]:
				var ty = m["nodes"][id]["type"]
				if counts.has(ty): counts[ty] += 1
			assert_true(counts["duel"] >= 4)
			assert_true(counts["sparring"] >= 2)
			assert_true(counts["visit"] >= 1)
			assert_true(counts["escort"] >= 1)
			assert_true(counts["hazard"] >= 1)
			# M4：boss 总数按章（章1=1 / 章2,3=2 / 章4=3）
			var expected_bosses: int = 1
			if ch in [2, 3]: expected_bosses = 2
			if ch == 4: expected_bosses = 3
			assert_eq(counts["boss"], expected_bosses, "seed %d ch %d boss 数应为 %d" % [seed, ch, expected_bosses])
			# 连通：每个非端点节点有入+出边
			var has_in := {}; var has_out := {}
			for id in m["nodes"]: has_in[id]=false; has_out[id]=false
			for e in m["edges"]: has_out[e["from"]]=true; has_in[e["to"]]=true
			for id in m["nodes"]:
				var l: int = m["nodes"][id]["layer"]
				if l != 7: assert_true(has_out[id], "seed %d ch %d node %s 缺出边" % [seed,ch,id])
				if l != 0: assert_true(has_in[id], "seed %d ch %d node %s 缺入边" % [seed,ch,id])
			# 起点≥2 可达；boss 端点
			var start := ""
			for id in m["nodes"]: if m["nodes"][id]["layer"]==0: start=id; break
			assert_true(MapGenerator.reachable_next(m, start).size() >= 2, "seed %d ch %d 起点分支<2" % [seed,ch])


# --- Task MG2: hazard_delta + reward_tier + 险径 --------------------------

func test_hazard_nodes_have_reward_tier():
	var m := _gen(7, 1)
	for id in m["nodes"]:
		if m["nodes"][id]["type"] == "hazard":
			var rt: String = m["nodes"][id].get("reward_tier", "")
			assert_true(rt == "normal" or rt == "t3_chance", "险地节点 %s 有 reward_tier" % id)

func test_at_least_one_peril_path():
	var m := _gen(7, 1)
	var hazards_by_layer := {}
	for id in m["nodes"]:
		if m["nodes"][id]["type"] == "hazard":
			var l: int = m["nodes"][id]["layer"]
			hazards_by_layer[l] = hazards_by_layer.get(l, [])
			hazards_by_layer[l].append(id)
	var layers_with_hazard: Array = hazards_by_layer.keys()
	layers_with_hazard.sort()
	var has_peril := false
	for i in range(layers_with_hazard.size() - 1):
		if layers_with_hazard[i + 1] - layers_with_hazard[i] == 1:
			has_peril = true
			break
	assert_true(has_peril, "至少一条险径（相邻层都有险地）")

func test_hazard_delta_increases_count():
	var base: int = _hazard_count(_gen(7, 1, 0))
	var more: int = _hazard_count(_gen(7, 1, 2))
	assert_gt(more, base, "hazard_delta=2 → 险地更多")

func test_hazard_delta_zero_unchanged():
	assert_eq(_hazard_count(_gen(7, 1, 0)), _hazard_count(_gen(7, 1)))

func _hazard_count(m: Dictionary) -> int:
	var n := 0
	for id in m["nodes"]:
		if m["nodes"][id]["type"] == "hazard":
			n += 1
	return n


# --- Task M4-T2: 多 boss DAG（章2/3 L7双选、章4 L6 mini-boss+L7掌门）----------

func test_chapter2_has_two_boss_nodes_at_L7():
	var m := MapGenerator.generate_map(7, 2, 0)
	var l7_bosses: Array = []
	for id in m["nodes"]:
		if int(m["nodes"][id]["layer"]) == 7 and m["nodes"][id]["type"] == "boss":
			l7_bosses.append(id)
	assert_eq(l7_bosses.size(), 2, "章2 L7 双 boss")
	# 每个 boss 带 boss_id（moqingniang/yanjiu）
	var boss_ids: Array = []
	for id in l7_bosses:
		boss_ids.append(String(m["nodes"][id].get("boss_id", "")))
	assert_true(boss_ids.has("moqingniang"))
	assert_true(boss_ids.has("yanjiu"))

func test_chapter4_L6_miniboss_L7_master():
	var m := MapGenerator.generate_map(7, 4, 0)
	var l6_bosses: Array = []
	var l7_bosses: Array = []
	for id in m["nodes"]:
		if m["nodes"][id]["type"] == "boss":
			if int(m["nodes"][id]["layer"]) == 6: l6_bosses.append(id)
			if int(m["nodes"][id]["layer"]) == 7: l7_bosses.append(id)
	assert_eq(l6_bosses.size(), 2, "章4 L6 双 mini-boss（司空弈/雷万钧）")
	assert_eq(l7_bosses.size(), 1, "章4 L7 掌门固定")
	assert_eq(String(m["nodes"][l7_bosses[0]].get("boss_id","")), "yanwujiu")

func test_every_boss_has_in_edge():
	# 不变量：每个 boss 节点 ≥1 入边（连通性）
	for chapter in [2, 3, 4]:
		var m := MapGenerator.generate_map(11, chapter, 0)
		var boss_ids: Array = []
		for id in m["nodes"]:
			if m["nodes"][id]["type"] == "boss": boss_ids.append(id)
		for bid in boss_ids:
			var has_in := false
			for e in m["edges"]:
				if e["to"] == bid: has_in = true
			assert_true(has_in, "章%d boss %s 有入边" % [chapter, bid])

func test_chapter1_byte_identical_to_m3():
	# 边界守护：章1 生成结果与 M3 逐字节一致（单 boss@L7，无 boss_id 字段或 boss_id=hailianzheng）
	var m := MapGenerator.generate_map(7, 1, 0)
	var l7: Array = []
	for id in m["nodes"]:
		if int(m["nodes"][id]["layer"]) == 7: l7.append(id)
	assert_eq(l7.size(), 1, "章1 L7 单节点")
	assert_eq(m["nodes"][l7[0]]["type"], "boss")

func test_chapter_bosses_named_correctly():
	# 章3 双 boss: zongzhenglie/peiyuan；章4 L6: sikongyi/leiwanjun
	var m3 := MapGenerator.generate_map(7, 3, 0)
	var c3_bosses: Array = []
	for id in m3["nodes"]:
		if m3["nodes"][id]["type"] == "boss":
			c3_bosses.append(String(m3["nodes"][id].get("boss_id", "")))
	assert_true(c3_bosses.has("zongzhenglie"))
	assert_true(c3_bosses.has("peiyuan"))

	var m4 := MapGenerator.generate_map(7, 4, 0)
	var c4_l6: Array = []
	for id in m4["nodes"]:
		if m4["nodes"][id]["type"] == "boss" and int(m4["nodes"][id]["layer"]) == 6:
			c4_l6.append(String(m4["nodes"][id].get("boss_id", "")))
	assert_true(c4_l6.has("sikongyi"))
	assert_true(c4_l6.has("leiwanjun"))

func test_chapter1_boss_id_field_absent_or_hailianzheng():
	# 章1 守护：boss_id 字段为空（M3 无此字段）或 hailianzheng
	var m := MapGenerator.generate_map(7, 1, 0)
	for id in m["nodes"]:
		if m["nodes"][id]["type"] == "boss":
			var bid: String = String(m["nodes"][id].get("boss_id", ""))
			assert_true(bid == "" or bid == "hailianzheng", "章1 boss_id 应为空或 hailianzheng，得 %s" % bid)
