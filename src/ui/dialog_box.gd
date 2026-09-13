class_name DialogBox
extends CanvasLayer
## 通用对白/过场框（Wave2）。程序化 UI：焦墨暗底+赭石名条+正文+"▸继续"+跳过。
## 接口：open(lines, name_label, on_finished)；_advance()/skip() 推进；回调恰好一次。
## reduce_motion=MetaSession.reduce_motion 时淡入淡出瞬切。

var _lines: Array = []
var _idx: int = 0
var _cb: Callable = Callable()
var _finished: bool = false
var _name_lbl: Label
var _body_lbl: Label
var _hint_lbl: Label
var _skip_btn: Button
var _panel: PanelContainer
var _box_name: String = ""

func _ready() -> void:
	layer = 50
	var panel := PanelContainer.new()
	_panel = panel
	# 父节点是 CanvasLayer（非 Control），锚点按视口解析：CENTER_BOTTOM 会把 position 当成
	# 锚点(640,800)的相对偏移 → 全局(760,1280) 出屏。锚点全 0 时 position 即绝对坐标。
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(120, 480)
	panel.custom_minimum_size = Vector2(1040, 220)
	panel.self_modulate = Color(0.06, 0.05, 0.04, 0.92)   # 焦墨
	add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	_name_lbl = Label.new()
	_name_lbl.add_theme_color_override("font_color", Color(0.78, 0.55, 0.32))   # 赭石
	vb.add_child(_name_lbl)
	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.custom_minimum_size = Vector2(1000, 110)
	vb.add_child(_body_lbl)
	_hint_lbl = Label.new()
	_hint_lbl.text = "▸ 继续（点击/空格）"
	_hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vb.add_child(_hint_lbl)
	_skip_btn = Button.new()
	_skip_btn.text = "跳过 »"
	_skip_btn.position = Vector2(1080, 490)
	_skip_btn.pressed.connect(skip)
	add_child(_skip_btn)
	panel.gui_input.connect(_on_panel_input)
	visible = false

func _on_panel_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_advance()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or _finished:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER):
		_advance()
		get_viewport().set_input_as_handled()

func open(lines: Array, name_label: String, on_finished: Callable) -> void:
	_lines = lines
	_cb = on_finished
	_idx = 0
	_finished = false
	_box_name = name_label
	visible = true
	if lines.is_empty():
		_finish()
		return
	_show_idx()
	if not MetaSession.reduce_motion:
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	else:
		_panel.modulate.a = 1.0   # 兜底：淡入中 skip 后 reduce_motion 切换，防止半透明面板

func _show_idx() -> void:
	var d: Dictionary = _lines[_idx]
	var s_name := String(d.get("s", ""))
	_name_lbl.text = s_name if s_name != "" else _name_for_box()
	_body_lbl.text = String(d.get("line", ""))
	_hint_lbl.text = "▸ 继续（%d/%d）" % [_idx + 1, _lines.size()]

func _name_for_box() -> String:
	return _box_name

func _advance() -> void:
	if _finished:
		return
	_idx += 1
	if _idx >= _lines.size():
		_finish()
	else:
		_show_idx()

func skip() -> void:
	if not _finished:
		_finish()

func _finish() -> void:
	_finished = true
	visible = false
	if _cb.is_valid():
		_cb.call()

# —— 测试探针 ——
func current_index() -> int: return _idx
func current_name() -> String: return _name_lbl.text
func current_text() -> String: return _body_lbl.text
