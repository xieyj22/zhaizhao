extends Node2D

const GRID := Vector2i(7, 7)
const CELL := 64

var state: BattleState
var orch: TurnOrchestrator
var view: BattleView

# 谁在选、选了什么
var picking_team: int = 0        # 0 选完轮 1，1 选完进揭晓
var pending: Dictionary = {}     # unit.id -> Resolver.Action

# 内置极简招式（M0 占位；M1 起改读 .tres）
func _strike() -> Technique:
	var t := Technique.new()
	t.id = &"strike"; t.display_name = "打击"
	t.type = Technique.Type.STRIKE
	t.base_damage = 5; t.speed = 5; t.opening_dealt = 1
	t.resulting_stance = Stance.Id.METAL
	return t

func _step(dx: int, dy: int) -> Technique:
	var t := Technique.new()
	t.id = &"step"; t.display_name = "进退步"
	t.type = Technique.Type.MOVE
	t.speed = 6; t.move_delta = Vector2i(dx, dy)
	t.resulting_stance = Stance.Id.METAL
	return t

func _to_stance(s: int, name: String) -> Technique:
	var t := Technique.new()
	t.id = StringName(name); t.display_name = name
	t.type = Technique.Type.STANCE_SWITCH
	t.speed = 7; t.resulting_stance = s
	return t

func _ready() -> void:
	# 初始状态：两队各 1 人，对角站位
	state = BattleState.new()
	state.grid_size = GRID
	var a := UnitState.new()
	a.id = &"玩家"; a.team = 0; a.grid_pos = Vector2i(1, 3); a.stance = Stance.Id.METAL
	a.hp = 20; a.max_hp = 20
	var b := UnitState.new()
	b.id = &"对手"; b.team = 1; b.grid_pos = Vector2i(5, 3); b.stance = Stance.Id.WOOD
	b.hp = 20; b.max_hp = 20
	state.units = [a, b]

	orch = TurnOrchestrator.new(state, Tuning.new())

	view = BattleView.new()
	view.cell = CELL
	view.grid_size = GRID
	view.state = state
	add_child(view)

	_build_ui()
	view.queue_redraw()

# ---------- UI（代码生成，避免手搓 .tscn 控件树）----------
var _btns: Array = []        # Button 列表
var _label: Label

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(220, 0)
	layer.add_child(panel)

	_label = Label.new()
	panel.add_child(_label)

	for u in state.units:
		if u.team == 0:
			_add_picker_for(u, panel)

	var reveal := Button.new()
	reveal.text = "揭晓结算"
	reveal.pressed.connect(_on_reveal)
	panel.add_child(reveal)
	_btns.append(reveal)

	_refresh()

func _add_picker_for(u: UnitState, panel: VBoxContainer) -> void:
	var name := Label.new()
	name.text = "【%s】选招" % String(u.id)
	panel.add_child(name)
	for t in [_strike(), _step(1, 0), _to_stance(Stance.Id.WATER, "切·水"), _to_stance(Stance.Id.FIRE, "切·火")]:
		var btn := Button.new()
		btn.text = "%s（速%d）" % [t.display_name, t.speed]
		btn.set_meta("unit", u)
		btn.set_meta("tech", t)
		btn.pressed.connect(_on_pick.bind(u, t))
		panel.add_child(btn)
		_btns.append(btn)

func _on_pick(u: UnitState, t: Technique) -> void:
	# 目标格：打击→敌方位；移动→不命中；切架势→自身位
	var target := u.grid_pos
	if t.type == Technique.Type.STRIKE:
		for e in state.units:
			if e.team != u.team and e.alive:
				target = e.grid_pos
				break
	pending[String(u.id)] = Resolver.Action.new(u, t, target)
	_refresh()

func _on_reveal() -> void:
	# M0 热座：需要双方都选了才揭晓（敌方也由玩家点）
	if pending.size() < 2:
		_label.text = "双方都要选招（热座：请也给对手选一招）"
		return
	var actions := pending.values()
	pending.clear()
	orch.reveal_and_resolve(actions)
	orch.end_turn()
	_refresh()
	if state.is_over():
		var winner := state.alive_teams()
		_label.text = "战斗结束（存活方 team=%s）" % str(winner)

func _refresh() -> void:
	var lines: Array = []
	for u in state.units:
		lines.append("%s [team%d %s] HP %d/%d 破绽 %d/%d%s %s" % [
			String(u.id), u.team, Stance.Id.keys()[u.stance],
			u.hp, u.max_hp, u.opening, u.max_opening,
			" 崩溃!" if u.guard_broken else "",
			"已选" if pending.has(String(u.id)) else "待选"
		])
	_label.text = "\n".join(lines)
	view.queue_redraw()
