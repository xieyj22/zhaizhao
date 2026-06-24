class_name MapGenerator
extends RefCounted

## seeded DAG 节点图（T4 §1）。同 (seed, chapter) → 同图（纯函数，全 seeded RNG）。
##
## 公约：
##   generate_map(seed, chapter, hazard_delta=0) -> {nodes:{id:{layer,type[,reward_tier]}},
##                                                    edges:[{from,to}], seed, chapter}
##   reachable_next(map, node_id) -> Array[String]
##
## 不变量（每章）：8 层；L0/L7 各 1 节点；L1–L6 各 2–3 节点；
## 节点类型下限 duel≥4 / sparring≥2 / visit≥1 / escort≥1 / hazard≥1 / boss=1；
## 同层类型不重复；L6（首领前层）含 escort；
## 每个非 L0 节点有入边，每个非 L7 节点有出边；L0 出边≥2（分支）。
##
## MG2 扩展：hazard_delta>0 在 baseline 之上额外把可安全转换的节点改为 hazard
## （不破坏类型下限/同层不重复/L6 escort）；险地节点带 reward_tier（"normal"/
## "t3_chance"）；每图至少一条险径（相邻层都有 hazard）。

const LAYERS := 8   # L0 起点 ... L7 首领

# 中间层（L1–L6）可选节点类型；start 仅 L0，boss 仅 L7
const _TYPES := ["duel", "sparring", "visit", "hazard", "escort"]
# T4 §1.3 类型下限（boss 恒 1，由 L7 唯一节点保证）
const _MIN_COUNTS := {"duel": 4, "sparring": 2, "visit": 1, "hazard": 1, "escort": 1}

## 生成一章图。返回 {nodes, edges, seed, chapter}。
##
## hazard_delta: 险地数量增量（默认 0 = M3 行为；>0 在 M3 baseline 之上
## 额外把 hazard_delta 个可转换节点改为 hazard）。边界守护：delta=0 时
## 类型分配与 M3 逐字节一致（仅 hazard 节点多出 additive 的 reward_tier 字段）。
static func generate_map(p_seed: int, chapter: int, hazard_delta: int = 0) -> Dictionary:
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

	# baseline 类型分配：始终用原始 _MIN_COUNTS（hazard 下限 1），
	# 保证 delta=0 与 M3 逐字节一致。
	_assign_types(nodes, layer_ids, rng, _MIN_COUNTS)
	# L6 escort 由 _assign_types 内部保证（作为约束条件，而非事后破坏性覆盖）。

	# delta>0：在 baseline 之上额外把 hazard_delta 个节点改为 hazard
	if hazard_delta > 0:
		_apply_hazard_delta(nodes, layer_ids, rng, hazard_delta)

	# 险地节点赋 reward_tier（additive：仅标注，不改变生成结构）
	for id in nodes:
		if nodes[id]["type"] == "hazard":
			nodes[id]["reward_tier"] = "t3_chance" if (rng.randi() % 3 == 0) else "normal"

	# 险径保证：若无"相邻层都有 hazard"，补一条（delta=0 下 160 代均天然满足，故为 no-op）
	_ensure_peril_path(nodes, layer_ids, rng)

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
static func _assign_types(nodes: Dictionary, layer_ids: Dictionary, rng: RandomNumberGenerator, min_counts: Dictionary) -> void:
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
		var n: int = int(min_counts.get(t, 0))
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


# --- hazard_delta 与险径保证 ----------------------------------------------
#
# 两处共享一个"可安全转为 hazard"的判定：
#   1. 该节点当前非 hazard、非 start、非 boss（中间层天然满足后两条）；
#   2. 该节点所在层目前无 hazard（保同层不重复）；
#   3. 转换后该节点原类型计数仍 ≥ 其下限（保类型下限）；
#   4. 不是 L6 的 escort（保 L6 必含 escort 不变量）。
# reward_tier：baseline + delta-added hazards 在 generate_map 的 hazard 扫描里赋值；
# _ensure_peril_path 在扫描之后运行，故其新加的 hazard 就地赋 reward_tier。

# 在 baseline 之上额外把 hazard_delta 个可安全转换的节点改为 hazard。
# seeded 遍历所有中间层节点（1..6），筛出候选，shuffle 后取前 hazard_delta 个转换。
static func _apply_hazard_delta(nodes: Dictionary, layer_ids: Dictionary, rng: RandomNumberGenerator, hazard_delta: int) -> void:
	# 当前每类型计数（用于下限判定）
	var type_counts := {}
	for id in nodes:
		var ty: String = nodes[id]["type"]
		type_counts[ty] = int(type_counts.get(ty, 0)) + 1
	# 每层是否已有 hazard
	var hazard_in_layer := {}
	for id in nodes:
		if nodes[id]["type"] == "hazard":
			hazard_in_layer[int(nodes[id]["layer"])] = true

	# 收集所有可安全转换的候选节点（中间层 1..6）
	var candidates: Array = []
	for l in range(1, 7):
		for id in layer_ids[l]:
			var ty: String = nodes[id]["type"]
			if ty == "hazard":
				continue
			if l == 6 and ty == "escort":
				continue   # L6 escort 唯一性保护
			var floor: int = int(_MIN_COUNTS.get(ty, 0))
			var cur: int = int(type_counts.get(ty, 0))
			if cur - 1 < floor:
				continue   # 转换会让原类型跌破下限
			# 同层已有 hazard → 转换会破坏同层不重复
			if hazard_in_layer.has(l):
				continue
			candidates.append([l, id])
	if candidates.is_empty():
		return
	_seed_shuffle(candidates, rng)
	var to_add: int = mini(hazard_delta, candidates.size())
	for i in range(to_add):
		var l: int = int(candidates[i][0])
		var id: String = candidates[i][1]
		var old_ty: String = nodes[id]["type"]
		type_counts[old_ty] = int(type_counts.get(old_ty, 0)) - 1
		type_counts["hazard"] = int(type_counts.get("hazard", 0)) + 1
		hazard_in_layer[l] = true
		nodes[id]["type"] = "hazard"


# 若图中无"相邻两层都有 hazard"的险径，把某 hazard 相邻层中一个可安全转换的
# 非起/首节点改为 hazard（同层此前无 hazard，故不破坏同层不重复）。
# delta=0 下 160 代均天然已有险径，故此函数对 delta=0 为 no-op（border guard）。
static func _ensure_peril_path(nodes: Dictionary, layer_ids: Dictionary, rng: RandomNumberGenerator) -> void:
	# 当前 hazard 层集合
	var hazard_layers := {}
	for id in nodes:
		if nodes[id]["type"] == "hazard":
			hazard_layers[int(nodes[id]["layer"])] = true
	if hazard_layers.is_empty():
		return   # 无 hazard（不应发生：min hazard≥1），不强行造

	# 已有相邻 hazard → 险径存在
	var sorted_layers: Array = hazard_layers.keys()
	sorted_layers.sort()
	for i in range(sorted_layers.size() - 1):
		if int(sorted_layers[i + 1]) - int(sorted_layers[i]) == 1:
			return

	# 计算每类型当前计数，用于"不破坏下限"判定（转换后原类型 -1）
	var type_counts := {}
	for id in nodes:
		var ty: String = nodes[id]["type"]
		type_counts[ty] = int(type_counts.get(ty, 0)) + 1

	# 逐 hazard 层尝试在相邻层（L±1，限 1..6 中间层）找候选
	for hl in sorted_layers:
		var h: int = int(hl)
		for delta in [1, -1]:
			var cand_layer: int = h + delta
			if cand_layer < 1 or cand_layer > 6:
				continue
			if hazard_layers.has(cand_layer):
				continue   # 该层已有 hazard
			var candidates: Array = []
			for id in layer_ids[cand_layer]:
				var ty: String = nodes[id]["type"]
				if ty == "hazard":
					continue
				if cand_layer == 6 and ty == "escort":
					continue
				var floor: int = int(_MIN_COUNTS.get(ty, 0))
				var cur: int = int(type_counts.get(ty, 0))
				if cur - 1 < floor:
					continue
				candidates.append(id)
			if candidates.is_empty():
				continue
			# seeded 选一个，转 hazard（reward_tier 由 generate_map 末尾扫描补，
			# 但此处已在 reward_tier 扫描之后执行，故就地补字段）
			var pick_id: String = candidates[rng.randi() % candidates.size()]
			nodes[pick_id]["type"] = "hazard"
			nodes[pick_id]["reward_tier"] = "t3_chance" if (rng.randi() % 3 == 0) else "normal"
			return   # 已补一条险径，足够



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
