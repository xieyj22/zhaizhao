class_name MapGenerator
extends RefCounted

## seeded DAG 节点图（T4 §1）。同 (seed, chapter) → 同图（纯函数，全 seeded RNG）。
##
## 公约：
##   generate_map(seed, chapter) -> {nodes:{id:{layer,type}}, edges:[{from,to}], seed, chapter}
##   reachable_next(map, node_id) -> Array[String]
##
## 不变量（每章）：8 层；L0/L7 各 1 节点；L1–L6 各 2–3 节点；
## 节点类型下限 duel≥4 / sparring≥2 / visit≥1 / escort≥1 / hazard≥1 / boss=1；
## 同层类型不重复；L6（首领前层）含 escort；
## 每个非 L0 节点有入边，每个非 L7 节点有出边；L0 出边≥2（分支）。

const LAYERS := 8   # L0 起点 ... L7 首领

# 中间层（L1–L6）可选节点类型；start 仅 L0，boss 仅 L7
const _TYPES := ["duel", "sparring", "visit", "hazard", "escort"]
# T4 §1.3 类型下限（boss 恒 1，由 L7 唯一节点保证）
const _MIN_COUNTS := {"duel": 4, "sparring": 2, "visit": 1, "hazard": 1, "escort": 1}

## 生成一章图。返回 {nodes, edges, seed, chapter}。
static func generate_map(p_seed: int, chapter: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	# 章节种子派生（确定性）：不同 (seed,chapter) → 不同但可复现的 RNG 流
	rng.seed = (p_seed * 31 + chapter * 7) & 0x7FFFFFFF

	var per_layer := {0: 1, 7: 1}
	for l in range(1, 7):
		per_layer[l] = 2 + (rng.randi() % 2)   # 2 或 3

	var nodes := {}
	var layer_ids := {}
	for l in range(LAYERS):
		layer_ids[l] = []
		for i in range(per_layer[l]):
			var id := "n%d_%d" % [l, i + 1]   # 1-based 序号
			nodes[id] = {"layer": l, "type": ""}
			layer_ids[l].append(id)

	nodes[layer_ids[0][0]]["type"] = "start"
	nodes[layer_ids[7][0]]["type"] = "boss"

	_assign_types(nodes, layer_ids, rng)
	# L6 escort 由 _assign_types 内部保证（作为约束条件，而非事后破坏性覆盖）。

	var edges := _build_edges(layer_ids, rng)
	return {"nodes": nodes, "edges": edges, "seed": p_seed, "chapter": chapter}


# --- 类型分配 -------------------------------------------------------------

# 约束驱动的类型分配（保证下限 + 同层不重复 + L6 必含 escort）。
#
# 思路：
#   A. 先处理"优先约束"——L6 必含 escort。把 L6 的一个槽预定为 escort
#      （挑 L6 第一个槽，确定性；若该槽此前已被占则换下一个 L6 槽）。
#   B. 展开剩余需求清单（duel×4/sparring×2/visit×1/hazard×1；escort 已由 A 保证≥1）。
#   C. seeded shuffle 全部中间层空槽。
#   D. 逐需求放置到"该层尚未有此类型"的空槽；第一遍失败则回退任意空槽。
#   E. 剩余空槽自由抽类型，同层不重复。
#
# 关键：escort 放在 L6 槽后，该槽在 D/E 阶段标记已分配，不会被覆盖；
# 因此 hazard/visit/sparring/duel 的下限不会被"强制 escort 覆盖"破坏。
static func _assign_types(nodes: Dictionary, layer_ids: Dictionary, rng: RandomNumberGenerator) -> void:
	# --- A. L6 必含 escort：预定一个 L6 槽 ---
	var l6: Array = layer_ids[6]
	var escort_slot_idx := -1   # 在 slots 数组中的索引（稍后填）
	# 注意：slots 尚未构建，先在 nodes 上直接标记一个 L6 槽为 escort
	var escort_node_id := ""
	for id in l6:
		# L6 此刻全空（_assign_types 入口），取第一个
		escort_node_id = id
		break
	if escort_node_id != "":
		nodes[escort_node_id]["type"] = "escort"

	# --- B. 收集所有中间层空槽 ---
	var slots := []
	for l in range(1, 7):
		for id in layer_ids[l]:
			if nodes[id]["type"] == "":   # 跳过已预定的 L6 escort 槽
				slots.append([l, id])
	_seed_shuffle(slots, rng)

	# --- C. 展开需求清单（不含 escort：已由 A 保证）---
	var needs := []
	# 顺序：先放数量多的（duel×4），再放少的；同层不重复优先满足
	for t in ["duel", "sparring", "hazard", "visit"]:
		var n: int = int(_MIN_COUNTS.get(t, 0))
		for _i in range(n):
			needs.append(t)

	# --- D. 逐需求放置 ---
	var assigned := []
	for _i in range(slots.size()):
		assigned.append(false)

	for t in needs:
		var placed := false
		# 第一遍：未分配 且 该层未占此类型
		for i in range(slots.size()):
			if assigned[i]:
				continue
			var l: int = slots[i][0]
			if not _layer_has_type(nodes, layer_ids, l, t):
				nodes[slots[i][1]]["type"] = t
				assigned[i] = true
				placed = true
				break
		# 第二遍（回退）：任意未分配槽
		if not placed:
			for i in range(slots.size()):
				if not assigned[i]:
					nodes[slots[i][1]]["type"] = t
					assigned[i] = true
					placed = true
					break

	# --- E. 剩余空槽自由抽类型，同层不重复 ---
	for i in range(slots.size()):
		if assigned[i]:
			continue
		var l: int = slots[i][0]
		var used_in_layer := {}
		for id in layer_ids[l]:
			if nodes[id]["type"] != "":
				used_in_layer[nodes[id]["type"]] = true
		var pick := _pick_unused_type(used_in_layer, rng)
		nodes[slots[i][1]]["type"] = pick
		used_in_layer[pick] = true


static func _pick_unused_type(used: Dictionary, rng: RandomNumberGenerator) -> String:
	# 收集该层未占用的类型
	var avail := []
	for t in _TYPES:
		if not used.has(t):
			avail.append(t)
	if avail.is_empty():
		# 5 类型全被同层占满（仅当该层>5 节点，但每层≤3，故不会发生）——回退随机
		return _TYPES[rng.randi() % _TYPES.size()]
	return avail[rng.randi() % avail.size()]


static func _layer_has_type(nodes: Dictionary, layer_ids: Dictionary, layer: int, t: String) -> bool:
	for id in layer_ids[layer]:
		if nodes[id]["type"] == t:
			return true
	return false




# --- 边构造（连通性保证）--------------------------------------------------

# 不变量：
#   L0 → L1 全连（L1 有 2–3 节点，必须每个都收到入边）；
#   每个中间层节点(作为 from) 至少 1 条向下边；
#   每个下一层节点(作为 to) 至少 1 条入边（显式扫描补连）；
#   L6 → L7 全连。
static func _build_edges(layer_ids: Dictionary, rng: RandomNumberGenerator) -> Array:
	var edges := []
	var edge_set := {}   # "from|to" -> true，去重

	var start_id: String = layer_ids[0][0]

	# L0 → L1 全连（保证 L1 每个节点都有入边 + 起点分支≥2）
	for to in layer_ids[1]:
		_add_edge(edges, edge_set, start_id, to)

	# L1 → L2 ... L5 → L6：每个 from 1–2 条；之后扫描保证每个 to 有入边
	for l in range(1, 6):
		var froms: Array = layer_ids[l]
		var tos: Array = layer_ids[l + 1]
		for f in froms:
			var n := 1 + (rng.randi() % 2)   # 1 或 2
			var picked := {}
			for _i in range(n):
				var t = tos[rng.randi() % tos.size()]
				if not picked.has(t):
					_add_edge(edges, edge_set, f, t)
					picked[t] = true
			# 保底：每个 from 至少 1 条出边
			if picked.is_empty():
				_add_edge(edges, edge_set, f, tos[0])
		# 连通补全：扫描 tos，任何缺入边的补一条（从 froms 里 seeded 选）
		for t in tos:
			if not _has_in_edge(edges, t):
				var f = froms[rng.randi() % froms.size()]
				_add_edge(edges, edge_set, f, t)

	# L6 → L7 全连（每个 L6 节点都有出边且都通向首领）
	for f in layer_ids[6]:
		_add_edge(edges, edge_set, f, layer_ids[7][0])

	return edges


static func _add_edge(edges: Array, edge_set: Dictionary, from: String, to: String) -> void:
	var key := "%s|%s" % [from, to]
	if edge_set.has(key):
		return
	edge_set[key] = true
	edges.append({"from": from, "to": to})


static func _has_in_edge(edges: Array, node_id: String) -> bool:
	for e in edges:
		if e["to"] == node_id:
			return true
	return false


# --- 查询 -----------------------------------------------------------------

static func reachable_next(map: Dictionary, node_id: String) -> Array:
	var out := []
	for e in map["edges"]:
		if e["from"] == node_id:
			out.append(e["to"])
	return out


# --- 工具 -----------------------------------------------------------------

# 手动 seeded shuffle（Array.shuffle 不绑 rng，不可用于确定性生成）
static func _seed_shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
