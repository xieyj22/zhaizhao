class_name RunFlow
extends RefCounted

## run 状态机（T4 §7.4 不变量 114–115）。
## 节点按 DAG 边前进；章节间需 bosses_defeated 含当章通关 boss（M4 T5）。纯函数，无副作用外溢。

## 最终章序号（T10e Bug C 集中"最终章"概念）。掌门 yanwujiu 在此章；胜=通关，不再 advance。
## battle.gd:_on_back_after_battle 与 meta_loop_harness._progress_after_boss 共用，消除硬编码 4 的重复。
const MAX_CHAPTER := 4

## 判定能否从当前节点前进到 target（T4 §7.4 不变量 114：仅沿 DAG 边）。
static func can_advance_node(run: RunState, target_node_id: String) -> bool:
	if not run.chapter_maps.has(run.current_chapter):
		return false
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	return MapGenerator.reachable_next(m, run.current_node_id).has(target_node_id)

## 进入节点：移动 current_node_id，记录已访问，追加 run_log（T4 §7.4）。
## 已访问节点可回放（map 标 ✓ 可点）——nodes_visited 去重，防回放重复记录。
static func enter_node(run: RunState, target_node_id: String) -> void:
	run.current_node_id = target_node_id
	var cp: Dictionary = run.chapter_progress.get(
		run.current_chapter, {"bosses_defeated": [], "nodes_visited": []}
	)
	var visited: Array = cp.get("nodes_visited", [])
	if not visited.has(target_node_id):
		visited.append(target_node_id)
	cp["nodes_visited"] = visited
	run.chapter_progress[run.current_chapter] = cp
	var ty: String = run.chapter_maps[run.current_chapter]["nodes"][target_node_id]["type"]
	(run.run_log as Array).append(
		{"node_id": target_node_id, "node_type": ty, "outcome": "visited"}
	)

## 节点是否已访问过（本章）。供 map 标记"已通关可回放"。
static func is_visited(run: RunState, node_id: String) -> bool:
	var cp: Dictionary = run.chapter_progress.get(run.current_chapter, {"nodes_visited": []})
	return (cp.get("nodes_visited", []) as Array).has(node_id)

## 判定能否进入下一章（T4 §7.4 不变量 115：当前章 boss 必须已败）。
## M4 T5：章1-3 任一 L7 boss 败即可；章4 必须掌门 yanwujiu（L6 mini-boss 不算）。
static func can_advance_chapter(run: RunState) -> bool:
	var cp: Dictionary = run.chapter_progress.get(
		run.current_chapter, {"bosses_defeated": [], "nodes_visited": []}
	)
	var defeated: Array = cp.get("bosses_defeated", [])
	var required: Array = _required_boss_ids(run.current_chapter)
	for bid in required:
		if defeated.has(bid):
			return true
	return false   # required 空（不应发生）或均未败 → false

## 当章通关所需 boss id 列表。章1-3 = BossConfig.boss_ids_for(ch, 7)；
## 章4 仅 yanwujiu（L6 mini-boss sikongyi/leiwanjun 不算通关）。
static func _required_boss_ids(chapter: int) -> Array:
	if chapter == 4:
		return ["yanwujiu"]
	return BossConfig.boss_ids_for(chapter, 7)

## 标记当前章某 boss 已败，记入 bosses_defeated（去重）。
## boss_id 可省略：旧调用者（battle.gd / playtest harness）不传时，
## 从当前章图的 boss 节点 boss_id 字段推导（章1 无 boss_id 字段→取 BossConfig L7 列表首项）。
static func on_boss_defeated(run: RunState, boss_id: String = "") -> void:
	var bid: String = boss_id
	if bid == "":
		bid = _infer_boss_id(run)
	var cp: Dictionary = run.chapter_progress.get(
		run.current_chapter, {"bosses_defeated": [], "nodes_visited": []}
	)
	var arr: Array = cp.get("bosses_defeated", [])
	if not arr.has(bid):
		(arr as Array).append(bid)
	cp["bosses_defeated"] = arr
	run.chapter_progress[run.current_chapter] = cp

## 从当前章图 current_node_id 的 boss 节点推导 boss_id（旧调用者回退路径）。
## 章1 boss 节点无 boss_id 字段（M3 语义）→ 取 BossConfig L7 列表首项（hailianzheng）。
static func _infer_boss_id(run: RunState) -> String:
	if not run.chapter_maps.has(run.current_chapter):
		return ""
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	var node_id: String = run.current_node_id
	if node_id != "" and m["nodes"].has(node_id):
		var nd: Dictionary = m["nodes"][node_id]
		if String(nd.get("type", "")) == "boss":
			var bid: String = String(nd.get("boss_id", ""))
			if bid != "":
				return bid
	# 当前节点非 boss 或无 boss_id（章1）→ 取该章 L7 首项
	var l7: Array = BossConfig.boss_ids_for(run.current_chapter, 7)
	if not l7.is_empty():
		return String(l7[0])
	return ""

## 推进到下一章（章 N → N+1）。在 can_advance_chapter 为 true 后由调用方触发。
## 语义：current_chapter+=1；生成下一章图；初始化章 progress；current_node_id 置空（回 hub）。
## 纯函数改 run，不持久化（调用方负责 commit）。
static func advance_chapter(run: RunState) -> void:
	var next_chapter: int = run.current_chapter + 1
	# 章节种子派生与 generate_map 内部一致；hazard_delta 取该 run 的 modifier 态
	var hazard_delta: int = int(run.modifier_state.get("hazard_node_count_delta", 0))
	var next_map: Dictionary = MapGenerator.generate_map(
		run.rng_seed, next_chapter, hazard_delta
	)
	run.chapter_maps[next_chapter] = next_map
	run.chapter_progress[next_chapter] = {"bosses_defeated": [], "nodes_visited": []}
	run.current_chapter = next_chapter
	run.current_node_id = ""   # 进新章回 hub（map 场景 _ready 调 place_at_chapter_start 重定位）
	run.rest_used = 0   # 新章休整配额重置（rest_used 重置的唯一真源；T10c）

## 镖局休整：每章 rest_cap_per_chapter 次满血恢复全员。配额用完或全员满血→不消耗。
## 返回 true=已休整（回血+rest_used++），false=未休整（配额满或无损伤）。
## rest_used 的重置唯一真源在 advance_chapter（进新章配额清零）。纯函数无 rng。
static func rest(run: RunState, tuning: Tuning) -> bool:
	if run.rest_used >= tuning.rest_cap_per_chapter:
		return false
	var need := false
	for pd in run.player_roster:
		if int(pd.get("hp", 0)) < int(pd.get("max_hp", 0)):
			need = true
			break
	if not need:
		return false
	for i in range(run.player_roster.size()):
		var pd: Dictionary = run.player_roster[i]
		pd["hp"] = int(pd.get("max_hp", 0))
		run.player_roster[i] = pd
	run.rest_used += 1
	return true

## permadeath：主角死 = 局结束（T4 §7.1：主角死亡→单 run 结束，meta 保留→回 hub）。
## battle.gd 战斗后据此判定回 hub（commit meta）还是回 map（继续）。
static func is_run_over(run: RunState) -> bool:
	for pd in run.player_roster:
		if bool(pd.get("is_protagonist", false)):
			return not bool(pd.get("alive", true))
	return false   # 无主角（不应发生）→ 不结束

## 剔除死亡的非主角队友（战斗后回写调用）。
## 修 bug：死亡队友若留 roster，_can_recruit 按 size() 计数会被幽灵占满 cap（无法再招），
## 且 _on_recruit_faction 的 idx=roster.size() 会与旧死亡队友 id 冲突致回写错位。
## 主角（无论死活）保留——主角死由 is_run_over/commit_run_to_meta 处理，需 roster 可判定。
static func cull_dead_allies(run: RunState) -> void:
	var alive_roster: Array = []
	for pd in run.player_roster:
		if bool(pd.get("is_protagonist", false)) or bool(pd.get("alive", true)):
			alive_roster.append(pd)
	run.player_roster = alive_roster

## 普通节点败北残息（option B 软失败）：主角复活到 1 血（残息），破绽/崩溃清零，死亡非主角队友剔除。
## 仅用于非 boss 节点败北——boss 败北仍走 permadeath（is_run_over→commit_run_to_meta），boss 是致命威胁。
## 纯函数改 run，不持久化。调用方（battle.gd/harness）在非 boss 败北后调，随后回 hub 休整续闯。
static func survive_loss(run: RunState) -> void:
	for i in range(run.player_roster.size()):
		var pd: Dictionary = run.player_roster[i]
		if bool(pd.get("is_protagonist", false)):
			pd["hp"] = 1
			pd["alive"] = true
			pd["guard_broken"] = false
			pd["opening"] = 0
			run.player_roster[i] = pd
			break
	cull_dead_allies(run)

## 进入章节图：若 current_node_id 为空（在 hub），定位到当前章 L0 起点节点。
## 幂等——已在某节点时（如战斗后返回 map）不动。map 场景 _ready 调用。
## 修 bug：init_run 设 current_node_id="" 进 map 后 can_advance_node 全 false（无边 from=""）→ 节点全 disabled。
static func place_at_chapter_start(run: RunState) -> void:
	if run.current_node_id != "":
		return
	if not run.chapter_maps.has(run.current_chapter):
		return
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	for id in m["nodes"]:
		if int(m["nodes"][id].get("layer", -1)) == 0:
			run.current_node_id = String(id)
			return
