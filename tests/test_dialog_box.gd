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
