class_name TerrainGen
extends RefCounted

## 格级地形生成（m4c spec §2.4）。seeded 确定性；出生格不落；障碍不破连通。
## 密度：hazard 节点→险地×12；普通→障碍2/水2/高地2；boss→左右镜像三对。
## chapter 仅透传（Follow-ups 按章递进预留，本期不用）。
const GRID := Vector2i(7, 7)

static func generate(rng_seed: int, node_id: String, node_type: String, chapter: int, spawn_cells: Array) -> Dictionary:
	for attempt in 8:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|%s|%d" % [rng_seed, node_id, attempt])
		var terrain := _place(rng, node_type, spawn_cells)
		if _valid(terrain, spawn_cells, node_type):
			return terrain
	return {}   # 8 摇全败（该密度下近乎不可能）→ 无地形，保底可玩

static func _place(rng: RandomNumberGenerator, node_type: String, spawn_cells: Array) -> Dictionary:
	var terrain := {}
	if node_type == "boss":
		# 镜像三对：x 取 0-2，格 (x,y) 与 (6-x,y) 成对同型
		for t in [TerrainRules.OBSTACLE, TerrainRules.WATER, TerrainRules.HIGHLAND]:
			var c := _free_cell(rng, terrain, spawn_cells, true)
			if c != Vector2i(-1, -1):
				terrain[TerrainRules.key(c.x, c.y)] = t
				terrain[TerrainRules.key(GRID.x - 1 - c.x, c.y)] = t
	else:
		var counts: Dictionary = {TerrainRules.HAZARD: 12} if node_type == "hazard" \
			else {TerrainRules.OBSTACLE: 2, TerrainRules.WATER: 2, TerrainRules.HIGHLAND: 2}
		for t in counts:
			for i in int(counts[t]):
				var c := _free_cell(rng, terrain, spawn_cells, false)
				if c != Vector2i(-1, -1):
					terrain[TerrainRules.key(c.x, c.y)] = t
	return terrain

## 取一个空格。mirror=true 时同时检查镜像格（boss 板成对摆放）。
static func _free_cell(rng: RandomNumberGenerator, terrain: Dictionary, spawn_cells: Array, mirror: bool) -> Vector2i:
	for try_i in 40:
		var x: int = rng.randi_range(0, 2 if mirror else GRID.x - 1)
		var y: int = rng.randi_range(0, GRID.y - 1)
		var k := TerrainRules.key(x, y)
		var mk := TerrainRules.key(GRID.x - 1 - x, y)
		if terrain.has(k) or terrain.has(mk) or spawn_cells.has(k):
			continue
		if mirror and (spawn_cells.has(mk) or mk == k):
			continue
		return Vector2i(x, y)
	return Vector2i(-1, -1)

static func _valid(terrain: Dictionary, spawn_cells: Array, node_type: String) -> bool:
	for k in terrain:
		if spawn_cells.has(k):
			return false
	var blocked := {}
	for k in terrain:
		if terrain[k] == TerrainRules.OBSTACLE:
			blocked[k] = true
	# flood-fill：非障碍格全连通
	var start := ""
	for y in GRID.y:
		for x in GRID.x:
			var k := TerrainRules.key(x, y)
			if not blocked.has(k):
				start = k
				break
		if start != "":
			break
	if start == "":
		return false
	var seen := {start: true}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var cur: String = frontier.pop_back()
		var parts := cur.split(",")
		for d in [[1,0],[-1,0],[0,1],[0,-1]]:
			var nx: int = int(parts[0]) + int(d[0])
			var ny: int = int(parts[1]) + int(d[1])
			if nx < 0 or ny < 0 or nx >= GRID.x or ny >= GRID.y:
				continue
			var nk := TerrainRules.key(nx, ny)
			if not blocked.has(nk) and not seen.has(nk):
				seen[nk] = true
				frontier.append(nk)
	if seen.size() != GRID.x * GRID.y - blocked.size():
		return false
	# 类型下限（boss 与普通同：三类各 ≥1；hazard 节点：险地 ≥1）
	if node_type == "hazard":
		return _count(terrain, TerrainRules.HAZARD) >= 1
	return _count(terrain, TerrainRules.OBSTACLE) >= 1 \
		and _count(terrain, TerrainRules.WATER) >= 1 \
		and _count(terrain, TerrainRules.HIGHLAND) >= 1

static func _count(terrain: Dictionary, t: String) -> int:
	var n := 0
	for k in terrain:
		if terrain[k] == t:
			n += 1
	return n
