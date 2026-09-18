extends GutTest

## Task A2: TerrainGen 确定性/密度/连通/stress（沿 test_map_generator 模式）。

func test_determinism():
	var a := TerrainGen.generate(42, "n1", "duel", 1, ["1,3"])
	var b := TerrainGen.generate(42, "n1", "duel", 1, ["1,3"])
	assert_eq(JSON.stringify(a), JSON.stringify(b))

func test_node_identity_changes_board():
	var a := TerrainGen.generate(42, "n1", "duel", 1, ["1,3"])
	var b := TerrainGen.generate(42, "n2", "duel", 1, ["1,3"])
	assert_ne(JSON.stringify(a), JSON.stringify(b))

func test_spawn_cells_never_used():
	for i in 30:
		var t := TerrainGen.generate(i, "n%d" % i, "duel", 1, ["1,3", "5,3", "5,5"])
		for k in ["1,3", "5,3", "5,5"]:
			assert_false(t.has(k), "出生格 %s 不可有地形（seed %d）" % [k, i])

func test_counts_by_node_type():
	for i in 5:
		assert_eq(TerrainGen.generate(i, "n", "duel", 1, ["1,3"]).size(), 6, "普通节点 6 格")
		assert_eq(TerrainGen.generate(i, "n", "hazard", 1, ["1,3"]).size(), 12, "险地节点 12 格")
		assert_eq(TerrainGen.generate(i, "n", "boss", 1, ["1,3", "5,3"]).size(), 6, "boss 板 6 格")

func test_boss_board_mirrored():
	var b := TerrainGen.generate(3, "n", "boss", 1, ["1,3", "5,3"])
	for k in b:
		var parts := String(k).split(",")
		var mk := TerrainRules.key(6 - int(parts[0]), int(parts[1]))
		assert_eq(String(b.get(mk, "")), String(b[k]), "boss 板左右镜像 %s" % k)

func test_hazard_node_hazard_cells():
	var t := TerrainGen.generate(7, "n", "hazard", 1, ["1,3"])
	var kinds := {}
	for k in t:
		kinds[t[k]] = true
	assert_true(kinds.has(TerrainRules.HAZARD), "险地节点必有险地格")

func test_connectivity_flood_fill():
	# 障碍不得把棋盘切成孤岛：非障碍格从任一自由格 flood-fill 全达
	for i in 40:
		var t := TerrainGen.generate(i, "n%d" % i, "duel", 1, ["1,3"])
		var blocked := {}
		for k in t:
			if t[k] == TerrainRules.OBSTACLE:
				blocked[k] = true
		var start := ""
		for y in 7:
			for x in 7:
				if not blocked.has(TerrainRules.key(x, y)):
					start = TerrainRules.key(x, y)
					break
			if start != "":
				break
		var seen := {start: true}
		var frontier: Array = [start]
		while not frontier.is_empty():
			var cur: String = frontier.pop_back()
			var parts := cur.split(",")
			for d in [[1,0],[-1,0],[0,1],[0,-1]]:
				var nx: int = int(parts[0]) + int(d[0])
				var ny: int = int(parts[1]) + int(d[1])
				if nx < 0 or ny < 0 or nx > 6 or ny > 6:
					continue
				var nk := TerrainRules.key(nx, ny)
				if not blocked.has(nk) and not seen.has(nk):
					seen[nk] = true
					frontier.append(nk)
		assert_eq(seen.size(), 49 - blocked.size(), "seed %d 非障碍格全连通" % i)

func test_stress_160_generations():
	var types := ["duel", "sparring", "hazard", "boss"]
	for i in 160:
		var nt: String = types[i % types.size()]
		var t := TerrainGen.generate(i, "n%d" % i, nt, 1 + (i % 4), ["1,3"])
		assert_true(t.size() > 0, "seed %d %s 必产地形" % [i, nt])
		var kinds := {}
		for k in t:
			kinds[t[k]] = true
		if nt == "hazard":
			assert_true(kinds.has(TerrainRules.HAZARD))
		else:
			assert_true(kinds.has(TerrainRules.OBSTACLE) and kinds.has(TerrainRules.WATER) and kinds.has(TerrainRules.HIGHLAND), "seed %d 三类齐" % i)
