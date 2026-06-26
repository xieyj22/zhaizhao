extends Node2D
## 单一 meta hub = 镜照山·旧址（T4 §3）。M3 占位 UI。
var _layer: CanvasLayer
var _status: Label
var _modifier_line: Label   # M3.5: 当局天象简述行
var _btn_recruit: Button         # 招募同袍主按钮（刷新 disabled 用）
var _btn_rest: Button             # 镖局休整（T10c：满血×rest_cap/章，免费）
var _btn_continue: Button         # 继续闯荡（无进行中 run 时 disabled——防 permadeath 后静默 no-op）
var _feedback: Label              # 操作反馈（休整/招募结果）
var _recruit_panel: VBoxContainer # 派系子按钮列表（展开/收起）

func _ready() -> void:
	# 用 autoload 已加载的 meta_state（battle.gd commit/通关后即时更新内存态）；
	# 仅在未加载时读盘——避免覆盖刚 commit 的 meta（如通关计数）。
	if MetaSession.meta_state == null:
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
	# —— T10 验收：操作反馈行（休整/招募结果等，否则点了没感觉）——
	_feedback = Label.new()
	_feedback.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	root.add_child(_feedback)
	_refresh_status()
	var btn_new := Button.new(); btn_new.text = "开始新一局"
	btn_new.pressed.connect(_on_new_run)
	root.add_child(btn_new)
	_btn_continue = Button.new()
	_btn_continue.text = "继续闯荡（节点图）"
	_btn_continue.disabled = MetaSession.current_run == null   # permadeath/未开局 → disabled（非静默 no-op）
	_btn_continue.pressed.connect(_on_open_map)
	root.add_child(_btn_continue)
	# —— 招募同袍：点开展开派系按钮列表（实装，替代 M3 占位）——
	_btn_recruit = Button.new()
	_btn_recruit.text = "招募同袍"
	_btn_recruit.disabled = not _can_recruit()
	_btn_recruit.pressed.connect(_on_recruit_placeholder)
	root.add_child(_btn_recruit)
	_recruit_panel = VBoxContainer.new()
	_recruit_panel.visible = false
	root.add_child(_recruit_panel)
	# —— T10c: 镖局休整（每章满血×rest_cap，免费）——
	_btn_rest = Button.new()
	_btn_rest.text = _rest_button_text()
	_btn_rest.disabled = not _can_rest()
	_btn_rest.pressed.connect(_on_rest)
	root.add_child(_btn_rest)

func _refresh_status() -> void:
	var m := MetaSession.meta_state
	_status.text = "镜照山·旧址 | 通关 %d 次 | 解锁招 %d 招" % [m.meta_runs_completed, m.meta_unlocked_pool.size()]
	if MetaSession.current_run != null:
		_status.text += " | 当前章 %d | 信用 %d" % [MetaSession.current_run.current_chapter, MetaSession.current_run.jianghu_credit]
	# —— M3.5: 天象行 ——
	if MetaSession.current_run != null and MetaSession.current_run.modifier_state.size() > 0:
		_modifier_line.text = "天象：" + _modifier_brief(MetaSession.current_run.modifier_state)
	else:
		_modifier_line.text = ""
	# 招募按钮 disabled 跟随状态（从 map/battle 返 hub 时刷新）
	if _btn_recruit != null:
		_btn_recruit.disabled = not _can_recruit()
	# T10c: 休整按钮 text/disabled 跟随 rest_used + roster 损伤
	if _btn_rest != null:
		_btn_rest.text = _rest_button_text()
		_btn_rest.disabled = not _can_rest()
	# 继续闯荡按钮 disabled 当无进行中 run（permadeath 后 / 未开局）
	if _btn_continue != null:
		_btn_continue.disabled = MetaSession.current_run == null

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

## 招募 gate：roster_cap 未满 + 信用够（材料）+ 至少一个派系关系达阈值（can_recruit，F8 不可招）。
func _can_recruit() -> bool:
	var run := MetaSession.current_run
	if run == null:
		return false
	var cap := 3
	if run.modifier_state.has("roster_cap"):
		cap = int(run.modifier_state["roster_cap"])
	if run.player_roster.size() >= cap:
		return false
	# T10 招募材料：需信用（访问节点挣）
	if run.jianghu_credit < Tuning.new().recruit_credit_cost:
		return false
	# 至少一个派系可招，否则按钮亮着点开全灰
	for fid in FactionData.recruit_factions():
		if FactionRelations.can_recruit(run.faction_relations, fid):
			return true
	return false

## 点「招募同袍」：toggle 派系按钮列表展开/收起。
func _on_recruit_placeholder() -> void:
	_refresh_recruit_panel()
	_recruit_panel.visible = not _recruit_panel.visible

## 刷新派系子按钮（F1–F7，各标派名/关系值/可招状态）。
func _refresh_recruit_panel() -> void:
	for c in _recruit_panel.get_children():
		c.queue_free()
	var run := MetaSession.current_run
	if run == null:
		return
	var cost := Tuning.new().recruit_credit_cost
	for fid in FactionData.recruit_factions():
		var rel: int = int(run.faction_relations.get(fid, 0))
		var can: bool = FactionRelations.can_recruit(run.faction_relations, fid)
		var btn := Button.new()
		btn.text = "%s | 关系 %d | 需 %d 信用 | %s" % [FactionData.NAMES[fid], rel, cost, "可招" if can else "不可招"]
		btn.disabled = not can
		btn.pressed.connect(_on_recruit_faction.bind(fid))
		_recruit_panel.add_child(btn)

## 招募某派一名队友：生成 unit_persist_dict → roster.append → 刷新 UI。
func _on_recruit_faction(fid: String) -> void:
	var run := MetaSession.current_run
	if run == null:
		return
	# 二次守护（按钮 disabled 已守，防 panel 未刷新时误点）
	if not FactionRelations.can_recruit(run.faction_relations, fid):
		return
	if not _can_recruit():   # roster_cap 守护
		return
	var idx: int = run.player_roster.size()
	if idx >= FactionData.PLAYER_SLOTS.size():
		return   # 槽位耗尽兜底（roster_cap 应先达）
	var cost := Tuning.new().recruit_credit_cost
	run.jianghu_credit = maxi(0, run.jianghu_credit - cost)
	run.player_roster.append(RunFactory._ally(fid, idx))
	_set_feedback("✓ 招募 %s 同袍入队（耗 %d 信用，剩 %d）" % [FactionData.NAMES.get(fid, fid), cost, run.jianghu_credit])
	_refresh_recruit_panel()
	_refresh_status()   # 含 _btn_recruit.disabled 刷新

## T10c: 镖局休整 gate——配额未满 且 roster 有损伤。
func _can_rest() -> bool:
	var run := MetaSession.current_run
	if run == null:
		return false
	var cap: int = Tuning.new().rest_cap_per_chapter
	if run.rest_used >= cap:
		return false
	for pd in run.player_roster:
		if int(pd.get("hp", 0)) < int(pd.get("max_hp", 0)):
			return true
	return false

## 休整按钮文案：显示剩余次数（cap - rest_used）。
func _rest_button_text() -> String:
	var run := MetaSession.current_run
	if run == null:
		return "休整（无进行中闯荡）"
	var cap: int = Tuning.new().rest_cap_per_chapter
	var left: int = maxi(0, cap - run.rest_used)
	return "镖局休整（剩余 %d/%d）" % [left, cap]

## 点「镖局休整」：调 RunFlow.rest 单一真源，刷新 UI + 反馈（玩家验收：点了要有感觉）。
func _on_rest() -> void:
	var run := MetaSession.current_run
	if run == null:
		return
	var tuning := Tuning.new()
	var healed_total := _roster_damage()
	var ok := RunFlow.rest(run, tuning)
	if ok:
		var left := maxi(0, tuning.rest_cap_per_chapter - run.rest_used)
		_set_feedback("✓ 镖局休整：队伍恢复满血（回血 %d，剩余配额 %d/%d）" % [healed_total, left, tuning.rest_cap_per_chapter])
	elif run.rest_used >= tuning.rest_cap_per_chapter:
		_set_feedback("✗ 本章休整配额已用完（章末 boss 推进后重置）")
	else:
		_set_feedback("（队伍满血，无需休整）")
	_refresh_status()

## roster 当前总损伤量（满血回血量，供反馈显示）。
func _roster_damage() -> int:
	var dmg := 0
	for pd in MetaSession.current_run.player_roster:
		dmg += maxi(0, int(pd.get("max_hp", 0)) - int(pd.get("hp", 0)))
	return dmg

func _set_feedback(text: String) -> void:
	if _feedback != null:
		_feedback.text = text

func _on_new_run() -> void:
	var seed := 7
	MetaSession.current_run = RunFactory.init_run(MetaSession.meta_state, seed)
	_open_map()

func _on_open_map() -> void:
	if MetaSession.current_run == null: return
	_open_map()

func _open_map() -> void:
	get_tree().change_scene_to_file("res://src/scenes/map/map.tscn")
