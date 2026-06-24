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
