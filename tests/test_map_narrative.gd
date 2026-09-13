extends GutTest

func _run() -> RunState:
	var r := RunFactory.init_run(MetaState.new_first_play(), 7)
	r.current_chapter = 3
	r.chapter_progress[3] = {"bosses_defeated": [], "nodes_visited": []}
	return r

func test_seg_for_layer_and_marking():
	var map := load("res://src/scenes/map/map.gd")
	var r := _run()
	assert_eq(map._seg_for_layer(r, 4), "mid", "L4→mid")
	assert_eq(map._seg_for_layer(r, 7), "close", "L7→close")
	assert_eq(map._seg_for_layer(r, 2), "", "其他层无")
	r.interlude_shown["3:mid"] = true
	assert_eq(map._seg_for_layer(r, 4), "", "已看过不重弹")
	assert_eq(map._seg_for_layer(null, 4), "", "无 run 安全")

func test_seg_open():
	var map := load("res://src/scenes/map/map.gd")
	var r := _run()
	assert_eq(map._seg_open(r), "open", "未看过章 open")
	r.interlude_shown["3:open"] = true
	assert_eq(map._seg_open(r), "", "看过不重弹")
