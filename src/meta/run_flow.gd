class_name RunFlow
extends RefCounted

## run 状态机（T4 §7.4 不变量 114–115）。
## 节点按 DAG 边前进；章节间需 boss_defeated。纯函数，无副作用外溢。

## 判定能否从当前节点前进到 target（T4 §7.4 不变量 114：仅沿 DAG 边）。
static func can_advance_node(run: RunState, target_node_id: String) -> bool:
	if not run.chapter_maps.has(run.current_chapter):
		return false
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	return MapGenerator.reachable_next(m, run.current_node_id).has(target_node_id)

## 进入节点：移动 current_node_id，记录已访问，追加 run_log（T4 §7.4）。
static func enter_node(run: RunState, target_node_id: String) -> void:
	run.current_node_id = target_node_id
	var cp: Dictionary = run.chapter_progress.get(
		run.current_chapter, {"boss_defeated": false, "nodes_visited": []}
	)
	(cp["nodes_visited"] as Array).append(target_node_id)
	run.chapter_progress[run.current_chapter] = cp
	var ty: String = run.chapter_maps[run.current_chapter]["nodes"][target_node_id]["type"]
	(run.run_log as Array).append(
		{"node_id": target_node_id, "node_type": ty, "outcome": "visited"}
	)

## 判定能否进入下一章（T4 §7.4 不变量 115：当前章 boss 必须已败）。
static func can_advance_chapter(run: RunState) -> bool:
	var cp: Dictionary = run.chapter_progress.get(run.current_chapter, {})
	return cp.get("boss_defeated", false)

## 标记当前章 boss 已败。
static func on_boss_defeated(run: RunState) -> void:
	var cp: Dictionary = run.chapter_progress.get(
		run.current_chapter, {"boss_defeated": false, "nodes_visited": []}
	)
	cp["boss_defeated"] = true
	run.chapter_progress[run.current_chapter] = cp

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
