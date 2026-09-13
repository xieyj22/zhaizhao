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
var _codex_layer: CanvasLayer = null   # Wave2 江湖志：面板层（layer 40；null=关）

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
	# —— Wave2: 江湖志（codex 面板入口，三 tab 人物志/山河志/武道志）——
	var btn_codex := Button.new()
	btn_codex.text = "江湖志"
	btn_codex.pressed.connect(_on_open_codex)
	root.add_child(btn_codex)

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
	# —— Wave2：codex 新解锁反馈（一次性）——
	var hint: String = _codex_new_hint(MetaSession.meta_state, MetaSession.codex_seen_count)
	if hint != "":
		_set_feedback(hint)
	MetaSession.codex_seen_count = CodexUnlock.unlocked_ids(MetaSession.meta_state).size() + _personae_count(MetaSession.meta_state)

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

## Wave2：新解锁反馈文案（纯函数可测）。人物志动态条目计入 unlocked 数。
static func _codex_new_hint(meta: MetaState, seen: int) -> String:
	var n: int = CodexUnlock.unlocked_ids(meta).size() + _personae_count(meta)
	if seen < 0 or n <= seen:
		return ""
	return "江湖志新增 %d 条" % (n - seen)

## 人物志动态条目（BOSS_NARRATIVE 在表 boss ↔ 人物志条目；locked=未击败）。
static func _personae_entries(meta: MetaState) -> Array:
	var out: Array = []
	for bid: Variant in NarrativeBoss.BOSS_NARRATIVE:
		var cfg: Dictionary = BossConfig.get_boss(String(bid))
		out.append({
			"id": String(bid),
			"category": "人物志",
			"title": "%s·%s" % [cfg.get("title", ""), cfg.get("name", String(bid))],
			"body": String(NarrativeBoss.entry(String(bid)).get("bio", "")),
			"locked": not meta.bosses_defeated_all.has(bid),
			"unlock": {"type": "boss_defeated", "key": String(bid)},
		})
	return out

static func _personae_count(meta: MetaState) -> int:
	return _personae_entries(meta).filter(func(e): return not e["locked"]).size()

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

# —— Wave2: 江湖志面板（人物志/山河志/武道志 三 tab）——

func _on_open_codex() -> void:
	if _codex_layer != null:
		return
	_codex_layer = CanvasLayer.new()
	_codex_layer.layer = 40
	add_child(_codex_layer)
	_build_codex_panel("人物志")

func _build_codex_panel(tab: String) -> void:
	for c in _codex_layer.get_children():
		c.queue_free()
	var meta := MetaSession.meta_state
	var root := VBoxContainer.new()
	root.position = Vector2(120, 40)
	root.custom_minimum_size = Vector2(1040, 660)
	_codex_layer.add_child(root)
	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	for t: String in ["人物志", "山河志", "武道志"]:
		var tb := Button.new()
		tb.text = t
		tb.disabled = (t == tab)
		tb.pressed.connect(_build_codex_panel.bind(t))
		tabs.add_child(tb)
	var close := Button.new()
	close.text = "关闭（Esc）"
	close.pressed.connect(_on_close_codex)
	tabs.add_child(close)
	var body := HBoxContainer.new()
	root.add_child(body)
	var list := ScrollContainer.new()
	list.custom_minimum_size = Vector2(300, 560)
	body.add_child(list)
	var list_v := VBoxContainer.new()
	list.add_child(list_v)
	var detail := ScrollContainer.new()
	detail.custom_minimum_size = Vector2(720, 560)
	body.add_child(detail)
	var detail_lbl := Label.new()
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.custom_minimum_size = Vector2(700, 0)
	detail.add_child(detail_lbl)
	var entries: Array = _personae_entries(meta) if tab == "人物志" else _codex_static_entries(tab, meta)
	for e: Variant in entries:
		var d: Dictionary = e
		var btn := Button.new()
		var locked: bool = d.get("locked", false)
		btn.text = "？？？ " if locked else String(d.get("title", ""))
		if locked:
			btn.text += CodexUnlock.hint_for(d) if d.has("unlock") else ""
			btn.disabled = d.get("body", "") == "" and not (tab == "山河志")
		btn.pressed.connect(func() -> void:
			detail_lbl.text = ("【未解锁】" + CodexUnlock.hint_for(d)) if locked else _codex_body_of(d)
		)
		list_v.add_child(btn)

func _codex_static_entries(tab: String, meta: MetaState) -> Array:
	var out: Array = []
	for e: Variant in NarrativeCodex.CODEX_ENTRIES:
		var d: Dictionary = e
		if String(d.get("category", "")) != tab:
			continue
		var c: Dictionary = d.duplicate(true)
		c["locked"] = not CodexUnlock.is_unlocked(d, meta)
		out.append(c)
	return out

func _codex_body_of(d: Dictionary) -> String:
	if d.has("region_id") and String(d["region_id"]) != "":
		return NarrativeRegion.prose(String(d["region_id"]))
	return String(d.get("body", ""))

func _on_close_codex() -> void:
	if _codex_layer != null:
		_codex_layer.queue_free()
		_codex_layer = null

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and _codex_layer != null:
		_on_close_codex()
