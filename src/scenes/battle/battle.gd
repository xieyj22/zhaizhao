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

var _layer: CanvasLayer
var _scroll: ScrollContainer
var _panel: VBoxContainer
var _target_panel: VBoxContainer
var _hud: Label

func _ready() -> void:
	tuning = Tuning.new()
	state = BattleState.new()
	state.grid_size = GRID
	# 2v2：玩家 team0 左列，敌方 team1 右列
	state.units = [
		_mk(&"玩家甲", 0, Vector2i(1, 2), Stance.Id.METAL),
		_mk(&"玩家乙", 0, Vector2i(1, 4), Stance.Id.WOOD),
		_mk(&"敌甲", 1, Vector2i(5, 2), Stance.Id.WOOD),
		_mk(&"敌乙", 1, Vector2i(5, 4), Stance.Id.METAL),
	]
	player_model = PlayerModel.new()
	if personality == null:
		personality = AIPersonality.brain()   # 默认智将（最显 L2 效果）
	orch = TurnOrchestrator.new(state, tuning, player_model, 1)

	view = BattleView.new()
	view.cell = CELL; view.grid_size = GRID; view.state = state
	add_child(view)

	_build_ui()
	_refresh()

func _mk(id, team, pos, stance) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20
	return u

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

	var reveal := Button.new()
	reveal.text = "揭晓结算"
	reveal.pressed.connect(_on_reveal)
	root.add_child(reveal)

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

	# 玩家方每个存活单位一个招式 picker
	for u in state.units:
		if u.team != 0 or not u.alive:
			continue
		var title := Label.new()
		var role_name: String = ["攻", "守", "中"][Stance.role(u.stance)]
		title.text = "【%s】HP %d/%d 破绽 %d/%d%s 架势%d(%s) %s" % [
			String(u.id), u.hp, u.max_hp, u.opening, u.max_opening,
			" 崩溃!" if u.guard_broken else "", u.stance, role_name,
			"✓已指令" if pending.has(String(u.id)) else "待指令"
		]
		_panel.add_child(title)
		for tech in TechniqueKit.default_kit():
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
			lbl.text = "→ %s 选目标：" % String(u.id)
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

func _player_can_pick(u: UnitState, tech: Technique) -> bool:
	if tech.type == Technique.Type.STRIKE:
		# 至少有一个范围内敌方才允许选招（否则按钮灰）
		for e in state.units:
			if e.team != 0 and e.alive and RangeBand.in_range(u.grid_pos, e.grid_pos, tech.required_range, tuning):
				return true
		return false
	if tech.type == Technique.Type.STANCE_SWITCH and tech.resulting_stance == u.stance:
		return false
	return true

func _on_pick_tech(u: UnitState, tech: Technique) -> void:
	if tech.type == Technique.Type.STRIKE:
		awaiting_target[String(u.id)] = tech
		pending.erase(String(u.id))
	else:
		pending[String(u.id)] = Resolver.Action.new(u, tech, u.grid_pos)
		awaiting_target.erase(String(u.id))
	_refresh()

func _on_pick_target(u: UnitState, tech: Technique, target_pos: Vector2i) -> void:
	pending[String(u.id)] = Resolver.Action.new(u, tech, target_pos)
	awaiting_target.erase(String(u.id))
	_refresh()

func _on_reveal() -> void:
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
	orch.reveal_and_resolve(all_actions)
	last_read_events = TurnOrchestrator.compute_read_events(ai_out.predictions, all_actions)
	orch.end_turn()
	_refresh()
	var oc := state.outcome(tuning)
	if oc != BattleState.Outcome.ONGOING:
		var msg: String = ["", "玩家胜！", "玩家败...", "平局"][oc]
		_hud.text = "战斗结束：%s（回合 %d）" % [msg, state.turn]
