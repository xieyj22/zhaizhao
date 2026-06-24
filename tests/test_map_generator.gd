extends GutTest

## Task MG: seeded DAG 节点图生成器（T4 §1）。

func _gen(seed: int, chapter := 1) -> Dictionary:
	return MapGenerator.generate_map(seed, chapter)

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
			assert_eq(by_layer.get(0,0), 1); assert_eq(by_layer.get(7,0), 1)
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
			assert_eq(counts["boss"], 1)
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
