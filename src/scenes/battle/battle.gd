extends Node2D

const GRID := Vector2i(7, 7)
const CELL := 64

var state: BattleState
var orch: TurnOrchestrator
var tuning: Tuning
var view: BattleView
var player_model: PlayerModel
var personality: AIPersonality = null   # 默认 None→用 AIPersonality.new()；可设 brain/trick
var last_read_events: Array = []

var pending: Dictionary = {}            # unit.id(String) -> Resolver.Action（玩家已下指令）
var awaiting_target: Dictionary = {}    # unit.id(String) -> Technique（选招了打击，等点目标）
var game_over: bool = false             # 战斗结束锁：outcome 非 ONGOING 后阻止继续揭晓/选招

var _layer: CanvasLayer
var _scroll: ScrollContainer
var _panel: VBoxContainer
var _target_panel: VBoxContainer
var _hud: Label
var _reveal_button: Button
var _retreat_button: Button   # 撤退（本场不算）——战斗中可见，game_over 隐藏

func _ready() -> void:
	tuning = Tuning.new()
	# —— M3.5: modifier tuning override（ai_cap/morale_cap delta）——
	if MetaSession.current_run != null:
		var ms: Dictionary = MetaSession.current_run.modifier_state
		if ms.has("ai_confidence_cap_delta"):
			tuning.l2_confidence_cap = clampf(tuning.l2_confidence_cap + float(ms["ai_confidence_cap_delta"]), 0.0, 1.0)
		if ms.has("morale_cap_delta"):
			tuning.morale_cap_turn = maxi(1, tuning.morale_cap_turn + int(ms["morale_cap_delta"]))
	if MetaSession.current_run != null:
		# —— M3: 由 RunState + node_cfg 构造 ——
		state = BattleBuilder.build(MetaSession.current_run, MetaSession.current_node_cfg)
		personality = _personality_for(MetaSession.current_node_cfg)
	else:
		# 回退：旧硬编码 2v2（保留给 M0–M2 场景测试）
		state = BattleState.new()
		state.grid_size = GRID
		# 2v2：玩家 team0 左列，敌方 team1 右列
		state.units = [
			_mk(&"玩家甲", 0, Vector2i(1, 2), Stance.Id.METAL),
			_mk(&"玩家乙", 0, Vector2i(1, 4), Stance.Id.WOOD),
			_mk(&"敌甲", 1, Vector2i(5, 2), Stance.Id.WOOD),
			_mk(&"敌乙", 1, Vector2i(5, 4), Stance.Id.METAL),
		]
		personality = AIPersonality.brain()   # 默认智将（最显 L2 效果）
	player_model = PlayerModel.new()
	orch = TurnOrchestrator.new(state, tuning, player_model, 1)

	view = BattleView.new()
	view.cell = CELL; view.grid_size = GRID; view.state = state
	view.reduce_motion = MetaSession.reduce_motion   # 跨战斗持久（a11y）
	add_child(view)

	_build_ui()
	_refresh()

func _mk(id, team, pos, stance) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20
	return u

## node_cfg → 敌方性格（boss 查 BOSS_CONFIG.personality；否则按 node_cfg.personality 字段，默认 brain）。
static func _personality_for(node_cfg: Dictionary) -> AIPersonality:
	var p: String = "brain"
	if node_cfg.has("boss_id"):
		var cfg: Dictionary = BossConfig.get_boss(String(node_cfg["boss_id"]))
		p = String(cfg.get("personality", "brute"))
	else:
		p = String(node_cfg.get("personality", "brain"))
	match p:
		"brute": return AIPersonality.brute()
		"trick": return AIPersonality.trick()
		"brain_trick_hybrid": return AIPersonality.brain_trick_hybrid()
		_: return AIPersonality.brain()

# ---------- UI ----------
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	# 右侧面板放进 ScrollContainer：招式(24)+目标+揭晓 总高会超出窗口，需可滚动
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(528, 16)
	_scroll.custom_minimum_size = Vector2(332, 760)
	_scroll.size = Vector2(332, 760)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layer.add_child(_scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(316, 0)
	_scroll.add_child(root)

	_hud = Label.new()
	root.add_child(_hud)

	_panel = VBoxContainer.new()
	root.add_child(_panel)

	_target_panel = VBoxContainer.new()
	root.add_child(_target_panel)

	_reveal_button = Button.new()
	_reveal_button.text = "揭晓结算"
	_reveal_button.pressed.connect(_on_reveal)
	root.add_child(_reveal_button)
	# 撤退：本场不算（不回写 roster，保持进战前状态）回地图重选节点。左下绝对定位避开右侧面板。
	_retreat_button = Button.new()
	_retreat_button.text = "撤退（本场不算）"
	_retreat_button.position = Vector2(40, 700)
	_retreat_button.pressed.connect(_on_retreat)
	_layer.add_child(_retreat_button)

func _refresh() -> void:
	for c in _panel.get_children():
		c.queue_free()
	for c in _target_panel.get_children():
		c.queue_free()

	var phase_name: String = ["NORMAL", "ACTIVE", "ESCALATED"][Morale.phase(state.turn, tuning)]
	_hud.text = "回合 %d | 战意 %s | 双方单位：%d/%d 存活" % [
		state.turn, phase_name,
		state.units.filter(func(u): return u.alive and u.team == 0).size(),
		state.units.filter(func(u): return u.alive and u.team == 1).size(),
	]
	var read_line := ""
	for e in last_read_events:
		if e.hit:
			read_line += "  ▶ %s 读中目标(predict=%s)！" % [personality.display_name if personality != null else "敌方", Technique.Type.keys()[e.predicted]]
	if read_line != "":
		_hud.text += "\n" + read_line
	# reduce_motion 状态提示（M 键切换）
	if view != null and view.reduce_motion:
		_hud.text += "\n[简洁动效已开 · 按 M 切换]"

	# 玩家方每个存活单位一个招式 picker
	for u in state.units:
		if u.team != 0 or not u.alive:
			continue
		var title := Label.new()
		var role_name: String = ["攻", "守", "中"][Stance.role(u.stance)]
		title.text = "【%s】HP %d/%d 破绽 %d/%d%s 架势%d(%s) %s" % [
			u.display_label(), u.hp, u.max_hp, u.opening, u.max_opening,
			" 崩溃!" if u.guard_broken else "", u.stance, role_name,
			"✓已指令" if pending.has(String(u.id)) else "待指令"
		]
		_panel.add_child(title)
		for tech in (TechniqueKit.default_kit() + TechniqueKit.feint_presets()):
			var btn := Button.new()
			btn.text = "%s（速%d）" % [tech.display_name, tech.speed]
			btn.disabled = not _player_can_pick(u, tech)
			btn.pressed.connect(_on_pick_tech.bind(u, tech))
			_panel.add_child(btn)

	# 若有单位在等目标，显示范围内敌方按钮
	for u in state.units:
		if u.team != 0 or not u.alive:
			continue
		if awaiting_target.has(String(u.id)):
			var tech: Technique = awaiting_target[String(u.id)]
			var lbl := Label.new()
			lbl.text = "→ %s 选目标：" % u.display_label()
			_target_panel.add_child(lbl)
			for e in state.units:
				if e.team != 0 and e.alive and RangeBand.in_range(u.grid_pos, e.grid_pos, tech.required_range, tuning):
					var tb := Button.new()
					tb.text = "%s (距%d)" % [String(e.id), RangeBand.distance(u.grid_pos, e.grid_pos)]
					tb.pressed.connect(_on_pick_target.bind(u, tech, e.grid_pos))
					_target_panel.add_child(tb)
	# 点了打击进入"等目标"态时，自动滚到目标选择区，避免目标按钮藏在折叠下方
	if _scroll != null and not awaiting_target.is_empty():
		_scroll.set_deferred("scroll_vertical", 999999)
	view.queue_redraw()

## M 键切换简洁动效（reduce_motion：破绽脉冲/受击闪白/飘字动画/HP lerp 降级或静化）。
## a11y 收尾——动效敏感用户。态存 MetaSession 跨战斗持久（不落盘）。
func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return   # 战斗结束后不重建 UI（防残留 picker）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			MetaSession.reduce_motion = not MetaSession.reduce_motion
			view.reduce_motion = MetaSession.reduce_motion
			_refresh()

func _player_can_pick(u: UnitState, tech: Technique) -> bool:
	# —— M3: ban_close 险地，玩家也不可选 CLOSE 打击/虚招 ——
	if state.hazard_modifiers.get("ban_close", false) and (tech.type == Technique.Type.STRIKE or tech.type == Technique.Type.FEINT) and tech.required_range == RangeBand.Id.CLOSE:
		return false
	if tech.type == Technique.Type.STRIKE or tech.type == Technique.Type.FEINT:
		# 至少有一个范围内敌方才允许选招（否则按钮灰）
		for e in state.units:
			if e.team != 0 and e.alive and RangeBand.in_range(u.grid_pos, e.grid_pos, tech.required_range, tuning):
				return true
		return false
	if tech.type == Technique.Type.STANCE_SWITCH and tech.resulting_stance == u.stance:
		return false
	return true

func _on_pick_tech(u: UnitState, tech: Technique) -> void:
	if game_over:
		return
	if tech.type == Technique.Type.STRIKE or tech.type == Technique.Type.FEINT:
		awaiting_target[String(u.id)] = tech
		pending.erase(String(u.id))
	else:
		pending[String(u.id)] = Resolver.Action.new(u, tech, u.grid_pos)
		awaiting_target.erase(String(u.id))
	_refresh()

func _on_pick_target(u: UnitState, tech: Technique, target_pos: Vector2i) -> void:
	if game_over:
		return
	pending[String(u.id)] = Resolver.Action.new(u, tech, target_pos)
	awaiting_target.erase(String(u.id))
	_refresh()

func _on_reveal() -> void:
	if game_over:
		return   # 战斗已结束，不再推进
	# 玩家方所有存活单位都需已下指令
	var alive_player := state.units.filter(func(u): return u.team == 0 and u.alive)
	if pending.size() < alive_player.size():
		_hud.text = "请先为本方所有存活单位下指令（打击须点目标）"
		return
	# 敌方由 AI 驱动
	var kits := {}
	for u in state.units:
		if u.team == 1:
			kits[String(u.id)] = TechniqueKit.default_kit()
	var ai_out := AIController.choose_actions(state, 1, tuning, kits, 1000 + state.turn, player_model, personality)
	var all_actions: Array = pending.values() + ai_out.actions
	pending.clear()
	awaiting_target.clear()
	# —— T10e Bug B：转发敌方(team1)对玩家的预测给 orch，让 mind_eye 反制伤(-2) 可触发 ——
	# 修复前：ai_out.predictions 只喂 compute_read_events（读招显示），从不转发 → mind_eye 死代码。
	# ai_out 是 team1(boss/敌方) 的 choose_actions，predictions 键=玩家方 unit id，正是 mind_eye_counter 所需。
	orch.ai_predictions = ai_out.predictions
	# 记 pre hp/guard（juice：伤害飘字+震屏用，reveal 前）
	var pre_hp: Dictionary = {}
	var pre_guard: Dictionary = {}
	for u in state.units:
		pre_hp[String(u.id)] = u.hp
		pre_guard[String(u.id)] = u.guard_broken
	orch.reveal_and_resolve(all_actions)
	# juice：命中飘字（pre_guard=true=挨打前已崩溃→翻倍=critical=黄大字+震；致命=大震）
	for u in state.units:
		var dmg: int = int(pre_hp[String(u.id)]) - u.hp
		if dmg > 0:
			view.spawn_floater(u.grid_pos, "-%d" % dmg, bool(pre_guard[String(u.id)]))
			view.flash_at(u.grid_pos)
			if u.hp <= 0:
				view.add_shake(8.0)
	last_read_events = TurnOrchestrator.compute_read_events(ai_out.predictions, all_actions)
	orch.end_turn()
	_refresh()
	var oc := state.outcome(tuning)
	if oc != BattleState.Outcome.ONGOING:
		game_over = true
		_reveal_button.disabled = true
		_reveal_button.text = "战斗结束 — 关闭窗口重玩"
		if _retreat_button != null:
			_retreat_button.hide()   # 战斗结束后由"返回"按钮接管
		var msg: String = ["", "玩家胜！", "玩家败...", "平局"][oc]
		_hud.text = "战斗结束：%s（回合 %d）" % [msg, state.turn]
		_write_back_result(oc)
		var back := Button.new()
		back.text = "主角阵亡 — 回大本营" if oc == BattleState.Outcome.TEAM1_WIN else "返回"
		# 左侧（retreat 已 hide 让位）+ 设最小尺寸——勿放 528+，会被右侧 _scroll 遮挡吞点击（验收 bug）
		back.position = Vector2(40, 700)
		back.custom_minimum_size = Vector2(260, 40)
		back.pressed.connect(_on_back_after_battle)
		_layer.add_child(back)

## 战斗结束回写 RunState（队友生死）。主角死信号由 HUB/IT 接管。
func _write_back_result(outcome: int) -> void:
	if MetaSession.current_run == null:
		return   # fallback 2v2 不回写
	var run := MetaSession.current_run
	for i in range(run.player_roster.size()):
		var pd: Dictionary = run.player_roster[i]
		var u: UnitState = _find_unit(state, String(pd["id"]))
		if u != null:
			pd["hp"] = u.hp
			pd["alive"] = u.alive
			pd["opening"] = u.opening
			pd["guard_broken"] = u.guard_broken
			run.player_roster[i] = pd
	# 剔除死亡非主角队友（修 roster 泄漏：否则幽灵占满 roster_cap 无法再招）
	RunFlow.cull_dead_allies(run)
	MetaSession.last_battle_outcome = outcome

static func _find_unit(s: BattleState, id_str: String) -> UnitState:
	for u in s.units:
		if String(u.id) == id_str:
			return u
	return null

## 撤退：本场不算（不调 _write_back_result → roster 保持进战前状态），回地图。
## 回到进战前的位置（previous_node_id），并把刚进入未通关的节点从 nodes_visited 移除——
## 否则 current_node_id 停在战节点，只能沿其 DAG 后继走，换不了同层兄弟节点（玩家验收）。
func _on_retreat() -> void:
	var run := MetaSession.current_run
	if run != null:
		var retreated: String = run.current_node_id
		run.current_node_id = MetaSession.previous_node_id
		var cp: Dictionary = run.chapter_progress.get(run.current_chapter, {"bosses_defeated": [], "nodes_visited": []})
		var visited: Array = cp.get("nodes_visited", [])
		visited.erase(retreated)   # 未通关不算已访问（不标 ✓）
		cp["nodes_visited"] = visited
		run.chapter_progress[run.current_chapter] = cp
	get_tree().change_scene_to_file("res://src/scenes/map/map.tscn")

func _on_back_after_battle() -> void:
	var run := MetaSession.current_run
	if run == null:
		get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn")
		return
	var oc := MetaSession.last_battle_outcome
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	var ty: String = m["nodes"].get(run.current_node_id, {}).get("type", "")
	# —— option B 软失败：败北分流（须在 is_run_over 前——败北主角已死）——
	# boss 败 = 致命 → permadeath（局结束）；普通节点败 = 残息（主角 1 血复活）回 hub 续闯。
	if oc == BattleState.Outcome.TEAM1_WIN:
		if ty == "boss":
			var meta := MetaState.commit_run_to_meta(MetaSession.meta_state, run, false)
			MetaState.save_to(meta)
			MetaSession.meta_state = meta
			MetaSession.current_run = null
			get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn")
			return
		RunFlow.survive_loss(run)
		get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn")
		return
	# permadeath（T4 §7.1）：主角阵亡 → 局结束（胜/平不应触发，守护）。
	if RunFlow.is_run_over(run):
		var meta := MetaState.commit_run_to_meta(MetaSession.meta_state, run, false)
		MetaState.save_to(meta)
		MetaSession.meta_state = meta
		MetaSession.current_run = null
		get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn")
		return
	# 存活 → 继续：boss 胜则标记，回 map
	if ty == "boss" and oc == BattleState.Outcome.TEAM0_WIN:
		RunFlow.on_boss_defeated(run)
		if RunFlow.can_advance_chapter(run):
			# —— T10e Bug C：ch4 掌门胜 = 通关（不再 advance 到幻影 ch5）——
			if run.current_chapter >= RunFlow.MAX_CHAPTER:
				var meta := MetaState.commit_run_to_meta(MetaSession.meta_state, run, true)
				MetaState.save_to(meta)
				MetaSession.meta_state = meta
				MetaSession.current_run = null
				get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn")
				return
			RunFlow.advance_chapter(run)
	get_tree().change_scene_to_file("res://src/scenes/map/map.tscn")
