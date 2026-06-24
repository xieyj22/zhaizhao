extends Node2D
## 单一 meta hub = 镜照山·旧址（T4 §3）。M3 占位 UI。
var _layer: CanvasLayer
var _status: Label
var _modifier_line: Label   # M3.5: 当局天象简述行

func _ready() -> void:
	MetaSession.meta_state = MetaState.load_from()
	_build_ui()

func _build_ui() -> void:
	_layer = CanvasLayer.new(); add_child(_layer)
	var root := VBoxContainer.new()
	root.position = Vector2(40, 40); root.custom_minimum_size = Vector2(400, 0)
	_layer.add_child(root)
	_status = Label.new()
	root.add_child(_status)
	# —— M3.5: 当局天象（modifier）简述行 ——
	_modifier_line = Label.new()
	root.add_child(_modifier_line)
	_refresh_status()
	var btn_new := Button.new(); btn_new.text = "开始新一局"
	btn_new.pressed.connect(_on_new_run)
	root.add_child(btn_new)
	var btn_cont := Button.new(); btn_cont.text = "继续闯荡（节点图）"
	btn_cont.pressed.connect(_on_open_map)
	root.add_child(btn_cont)
	# —— M3.5: 招募占位（M3 仅文案；roster_cap gate 在 _can_recruit 内守，留 M4 完整招募实装接）——
	var btn_recruit := Button.new(); btn_recruit.text = "招募同袍（占位）"
	btn_recruit.disabled = not _can_recruit()
	btn_recruit.pressed.connect(_on_recruit_placeholder)
	root.add_child(btn_recruit)
	for f in ["F1 镜照","F2 赤锋","F4 听潮"]:
		var lbl := Label.new(); lbl.text = "【%s 代表】（招募/关系/技谱）" % f
		root.add_child(lbl)

func _refresh_status() -> void:
	var m := MetaSession.meta_state
	_status.text = "镜照山·旧址 | 通关 %d 次 | 解锁招 %d 招" % [m.meta_runs_completed, m.meta_unlocked_pool.size()]
	if MetaSession.current_run != null:
		_status.text += " | 当前章 %d" % MetaSession.current_run.current_chapter
	# —— M3.5: 天象行 ——
	if MetaSession.current_run != null and MetaSession.current_run.modifier_state.size() > 0:
		_modifier_line.text = "天象：" + _modifier_brief(MetaSession.current_run.modifier_state)
	else:
		_modifier_line.text = ""

## M3.5: modifier_state → 中文简述（hook 反推；M4 可换 modifier_ids 反查 POOL 取 name/desc）。
## 用 hook 键而非 id（meta UI 展示的是「效果」而非「名字」，避免 meta 改 POOL 文案时此处失同步）。
func _modifier_brief(ms: Dictionary) -> String:
	var parts: Array = []
	if ms.has("kit_stance_damage_bonus"): parts.append("锐金势强")
	if ms.has("hazard_baseline"): parts.append("煞气弥漫")
	if ms.has("ai_confidence_cap_delta"):
		parts.append("读心破" if float(ms["ai_confidence_cap_delta"]) > 0 else "测不准")
	if ms.has("roster_cap"): parts.append("独行")
	if ms.has("morale_cap_delta"): parts.append("慎思")
	if ms.has("credit_mult"): parts.append("众叛亲离")
	if ms.has("kit_feint_bonus_delta"): parts.append("网开一面")
	if ms.has("hazard_node_count_delta"): parts.append("险地频仍")
	if ms.has("kit_stance_speed_bonus"): parts.append("厚土镇煞")
	return ", ".join(parts) if not parts.is_empty() else "风平浪静"

## M3.5: roster_cap modifier 招募 gate。无 modifier 时无上限（cap=99 兜底）。
func _can_recruit() -> bool:
	var run := MetaSession.current_run
	if run == null:
		return false
	var cap := 99
	if run.modifier_state.has("roster_cap"):
		cap = int(run.modifier_state["roster_cap"])
	return run.player_roster.size() < cap

## M3.5: 招募占位回调（M3 hub 招募未实装；gate 已守，留 M4 接 FactionRelations.can_recruit + roster.append）。
func _on_recruit_placeholder() -> void:
	pass

func _on_new_run() -> void:
	var seed := 7
	MetaSession.current_run = RunFactory.init_run(MetaSession.meta_state, seed)
	_open_map()

func _on_open_map() -> void:
	if MetaSession.current_run == null: return
	_open_map()

func _open_map() -> void:
	get_tree().change_scene_to_file("res://src/scenes/map/map.tscn")
