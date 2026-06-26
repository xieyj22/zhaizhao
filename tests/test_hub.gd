extends GutTest

# T10c: hub 场景休整按钮集成测（_on_rest/_can_rest/按钮 text/disabled 跟随）。
# 实例化 hub.tscn，set 一个带损伤 roster 的 current_run，验 _on_rest 回血 + 按钮刷新。
# 用 := 让 GDScript 从 .tscn 根节点（Node2D + hub.gd）推断类型（复刻 test_battle_scene 模式）。

func after_each():
	# 兜底：重置 MetaSession 全局态，防跨测试泄漏
	MetaSession.current_run = null

func _injured_run() -> RunState:
	# 合成带一个损伤主角的 current_run（hp=10 < max_hp=20，rest_used=0）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster = [{
		"id":"protagonist","team":0,"hp":10,"max_hp":20,
		"opening":0,"max_opening":6,"stance":0,"grid_pos":[1,3],
		"facing":0,"guard_broken":false,"alive":true,
		"kit_ids":["tongshi_jinda"],"is_protagonist":true,
	}]
	run.rest_used = 0
	return run

func test_continue_button_disabled_when_no_run():
	# 玩家验收：permadeath 后 current_run=null，"继续闯荡"应 disabled（此前可点但静默 no-op）
	MetaSession.current_run = null
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	assert_true(hub._btn_continue.disabled, "无进行中闯荡 → 继续闯荡 disabled（非静默 no-op）")
	remove_child(hub)
	hub.queue_free()

func test_continue_button_enabled_when_run_active():
	MetaSession.current_run = RunFactory.init_run(MetaState.new_first_play(), 7)
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	assert_false(hub._btn_continue.disabled, "有进行中闯荡 → 继续闯荡 可点")
	remove_child(hub)
	hub.queue_free()

# —— T10 招募材料（信用）门槛 + 休整反馈（玩家验收）——

func test_can_recruit_requires_credit_even_with_relation():
	# F4 默认关系 40>=30，但信用 0 → 不可招（材料门槛）；攒够信用才可招
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.jianghu_credit = 0
	MetaSession.current_run = run
	hub._refresh_status()
	assert_true(int(run.faction_relations.get("F4", 0)) >= 30, "F4 默认关系达阈值（前置）")
	assert_false(hub._can_recruit(), "信用 0 → 不可招（即便 F4 关系达标）")
	run.jianghu_credit = Tuning.new().recruit_credit_cost
	assert_true(hub._can_recruit(), "信用够 + F4 关系达阈值 → 可招")
	remove_child(hub)
	hub.queue_free()

func test_recruit_deducts_credit():
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.jianghu_credit = 100
	MetaSession.current_run = run
	var cost := Tuning.new().recruit_credit_cost
	var size_before := run.player_roster.size()
	hub._on_recruit_faction("F4")
	assert_eq(run.jianghu_credit, 100 - cost, "招募扣信用（材料）")
	assert_eq(run.player_roster.size(), size_before + 1, "roster +1")
	remove_child(hub)
	hub.queue_free()

func test_rest_shows_feedback():
	# 玩家验收：镖局休整应有反馈文案
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	MetaSession.current_run = _injured_run()   # hp 10 < max 20
	hub._on_rest()
	assert_true(hub._feedback.text.find("回血") >= 0 or hub._feedback.text.find("满血") >= 0,
		"休整后 _feedback 有回血/满血文案（非静默）")
	remove_child(hub)
	hub.queue_free()

func test_can_rest_true_when_roster_injured_and_cap_available():
	# 损伤 + 配额可用 → _can_rest true，按钮可点
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	MetaSession.current_run = _injured_run()
	hub._refresh_status()
	assert_true(hub._can_rest(), "损伤+配额可用 → 可休整")
	assert_false(hub._btn_rest.disabled, "按钮可点")
	remove_child(hub)
	hub.queue_free()

func test_on_rest_heals_and_updates_button():
	# _on_rest → 满血 + rest_used+1 + 按钮变 disabled（无损伤后不可再休整）
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	MetaSession.current_run = _injured_run()
	hub._refresh_status()
	assert_false(hub._btn_rest.disabled, "休整前按钮可点")
	hub._on_rest()
	assert_eq(int(MetaSession.current_run.player_roster[0]["hp"]), 20, "休整后满血")
	assert_eq(MetaSession.current_run.rest_used, 1, "rest_used+1")
	# 满血后 _can_rest false → 按钮 disabled
	assert_true(hub._btn_rest.disabled, "满血后按钮 disabled")
	# 按钮文案反映剩余次数（cap=3，已用1 → 剩 2）
	assert_true(hub._btn_rest.text.find("剩余 2/3") >= 0, "按钮文案显示剩余 2/3")
	remove_child(hub)
	hub.queue_free()

func test_can_rest_false_when_no_run():
	# 无 current_run → 不可休整
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	MetaSession.current_run = null
	hub._refresh_status()
	assert_false(hub._can_rest(), "无进行中闯荡 → 不可休整")
	assert_true(hub._btn_rest.disabled, "无 run 时按钮 disabled")
	remove_child(hub)
	hub.queue_free()

func test_can_rest_false_when_cap_used():
	# 配额用满 → 不可休整（即便有损伤）
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	var run := _injured_run()
	run.rest_used = 3   # cap=3 已用满（T10f 调平）
	MetaSession.current_run = run
	hub._refresh_status()
	assert_false(hub._can_rest(), "配额用满 → 不可休整")
	assert_true(hub._btn_rest.disabled, "配额满按钮 disabled")
	remove_child(hub)
	hub.queue_free()
