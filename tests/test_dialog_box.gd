extends GutTest

const LINES := [
	{"s": "宗政烈", "line": "第一句"},
	{"s": "遗照", "line": "第二句"},
	{"s": "宗政烈", "line": "第三句"},
]

func _make_box() -> DialogBox:
	var box := DialogBox.new()
	add_child(box)
	return box

func test_open_shows_first_line_and_name():
	var box := _make_box()
	box.open(LINES, "test", func(): pass)
	assert_eq(box.current_index(), 0)
	assert_eq(box.current_name(), "宗政烈")
	assert_eq(box.current_text(), "第一句")

func test_advance_walks_lines_then_finishes_once():
	# 坑：GDScript lambda 按值捕获局部变量，int 计数器在回调里改不动外层；
	# 用 dict（引用捕获）做计数。
	var finished := {"n": 0}
	var box := _make_box()
	box.open(LINES, "test", func(): finished.n += 1)
	box._advance()
	box._advance()
	assert_eq(finished.n, 0, "最后一句 advance 前不结束")
	box._advance()
	assert_eq(finished.n, 1, "恰好回调一次")
	box._advance()
	assert_eq(finished.n, 1, "结束后再 advance 不重复回调")

func test_skip_finishes_immediately():
	var finished := {"n": 0}
	var box := _make_box()
	box.open(LINES, "test", func(): finished.n += 1)
	box.skip()
	assert_eq(finished.n, 1)

func test_open_empty_lines_calls_back_immediately():
	var finished := {"n": 0}
	var box := _make_box()
	box.open([], "test", func(): finished.n += 1)
	assert_eq(finished.n, 1, "空文本=防御性立即回调，调用方流程不断")

func test_interlude_mode_no_name():
	var box := _make_box()
	box.open([{"s": "", "line": "过场散文一句"}], "", func(): pass)
	assert_eq(box.current_name(), "")

func test_fallback_name_used_when_s_empty():
	var box := _make_box()
	box.open([{"s": "", "line": "旁白一句"}], "旁白", func(): pass)
	assert_eq(box.current_name(), "旁白", "条目 s 为空时回退 open 的 name_label 默认名条")

func test_panel_anchors_zero_position_absolute():
	# 回归（T7 真机验收）：CanvasLayer 的子 Control 锚点按视口解析，CENTER_BOTTOM 会把
	# position(120,480) 当成锚点(640,800)的相对偏移 → 全局(760,1280) 出屏不可见。
	# 锚点全 0（TOP_LEFT）时 position 即绝对坐标，不随视口尺寸漂移。
	var box := _make_box()
	await get_tree().process_frame
	var panel: PanelContainer = box._panel
	assert_eq(panel.anchor_left, 0.0, "左锚点为 0")
	assert_eq(panel.anchor_right, 0.0, "右锚点为 0")
	assert_eq(panel.anchor_top, 0.0, "上锚点为 0")
	assert_eq(panel.anchor_bottom, 0.0, "下锚点为 0")
	assert_eq(panel.position, Vector2(120, 480), "面板绝对坐标 (120,480)")

func test_unhandled_input_space_advances_echo_ignored():
	var box := _make_box()
	box.open(LINES, "test", func(): pass)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SPACE
	box._unhandled_input(ev)
	assert_eq(box.current_index(), 1, "空格推进一句")
	var echo_ev := InputEventKey.new()
	echo_ev.pressed = true
	echo_ev.echo = true
	echo_ev.keycode = KEY_SPACE
	box._unhandled_input(echo_ev)
	assert_eq(box.current_index(), 1, "按住空格的系统 echo 重复键不推进")
