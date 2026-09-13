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

func test_codex_panel_backdrop():
	# spec §3.4「全屏面板」：暗底 ColorRect 恒为 _codex_layer 首子（CanvasLayer 内
	# 先加=绘制于内容 VBox 之下）。断锚点值 0/0→1/1（FULL_RECT），不断窗口相关尺寸。
	var hub := preload("res://src/scenes/hub/hub.tscn").instantiate()
	add_child(hub)
	hub._on_open_codex()
	var first = hub._codex_layer.get_child(0)
	assert_true(first is ColorRect, "首子应为全屏暗底 ColorRect")
	var dim: ColorRect = first
	assert_eq(dim.anchor_left, 0.0, "anchor_left=0")
	assert_eq(dim.anchor_top, 0.0, "anchor_top=0")
	assert_eq(dim.anchor_right, 1.0, "anchor_right=1")
	assert_eq(dim.anchor_bottom, 1.0, "anchor_bottom=1")
	assert_eq(dim.color, Color(0.03, 0.03, 0.025, 0.74), "焦墨暗底色值")
	assert_true(hub._codex_layer.get_child(1) is VBoxContainer, "内容 VBox 后加=绘于暗底之上")
	# tab 切换：_build_codex_panel 清空重建，新暗底须先于新内容加入（同步帧可验）
	hub._build_codex_panel("山河志")
	var n: int = hub._codex_layer.get_child_count()
	assert_true(hub._codex_layer.get_child(n - 2) is ColorRect, "tab 重建：新暗底先于新内容")
	assert_true(hub._codex_layer.get_child(n - 1) is VBoxContainer, "tab 重建：新内容 VBox 最后")
	# queue_free 延迟到帧末结算——待两帧后旧暗底应已释放，不随切换堆叠
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(hub._codex_layer.get_child(0) is ColorRect, "结算后暗底仍为首子")
	var rect_count: int = 0
	for c in hub._codex_layer.get_children():
		if c is ColorRect:
			rect_count += 1
	assert_eq(rect_count, 1, "暗底不随 tab 切换堆叠")
	remove_child(hub)
	hub.queue_free()

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
