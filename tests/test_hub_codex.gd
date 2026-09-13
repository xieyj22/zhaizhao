extends GutTest

# T6: hub 江湖志面板——新解锁反馈 hint + 人物志动态条目（纯函数）+ 面板 UI 冒烟。
# 注：brief 原文以 hailianzheng 验「人物志 +1」，但人物志条目源=BOSS_NARRATIVE，
# 当前在表仅宗政烈（W2-2 批 A/B/C 后为 8），hailianzheng 无条目不计入 → 改用
# zongzhenglie（验证意图不变：击败在表 boss → 人物志动态条目计入新增数）。

func test_codex_new_hint():
	var hub := load("res://src/scenes/hub/hub.gd")
	var m := MetaState.new_first_play()
	m.bosses_defeated_all = []
	m.chapters_reached = [1]
	assert_eq(hub._codex_new_hint(m, -1), "", "首次进 hub（seen=-1）不报")
	assert_eq(hub._codex_new_hint(m, 5), "", "无增量不报")
	var before: int = CodexUnlock.unlocked_ids(m).size()
	m.bosses_defeated_all = ["zongzhenglie"]   # 人物志 +1（hub 动态条目计入）
	assert_eq(hub._codex_new_hint(m, before), "江湖志新增 1 条")

func test_personae_entries_dynamic():
	var hub := load("res://src/scenes/hub/hub.gd")
	var m := MetaState.new_first_play()
	m.bosses_defeated_all = ["zongzhenglie"]
	var entries: Array = hub._personae_entries(m)
	# 当前数据表只有宗政烈（W2-2 批 A/B/C 后为 8）——断言在表 boss 全出现
	assert_gte(entries.size(), 1)
	for e: Variant in entries:
		var d: Dictionary = e
		assert_true(d.has("title") and d.has("body") and d.has("locked"))
	var found := entries.filter(func(e): return e["id"] == "zongzhenglie")
	assert_eq(found.size(), 1)
	assert_false(found[0]["locked"], "已击败→解锁")

func test_codex_panel_smoke():
	# 已知坑兜底：场景脚本的运行期错误（容器漏 .new()/connect 目标不存在等）GUT 纯函数
	# 测不到——实例化 hub.tscn 开面板走三 tab + 关闭，冒烟面板构建路径。
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	hub._on_open_codex()
	assert_not_null(hub._codex_layer, "开面板建层")
	hub._on_open_codex()   # 重复开=幂等
	hub._build_codex_panel("山河志")
	hub._build_codex_panel("武道志")
	hub._on_close_codex()
	assert_null(hub._codex_layer, "关面板清层")
	remove_child(hub)
	hub.queue_free()
