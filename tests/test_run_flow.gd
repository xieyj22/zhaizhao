extends GutTest

func _run() -> RunState:
	var r := RunFactory.init_run(MetaState.new_first_play(), 7)
	# 把 current_node_id 设到 L0 起点
	var m: Dictionary = r.chapter_maps[1]
	for id in m["nodes"]:
		if m["nodes"][id]["layer"] == 0:
			r.current_node_id = id
			break
	return r

func test_can_advance_node_only_along_edges():
	var run := _run()
	var m: Dictionary = run.chapter_maps[1]
	var nxt: Array = MapGenerator.reachable_next(m, run.current_node_id)
	assert_true(RunFlow.can_advance_node(run, nxt[0]), "沿边可前进")
	assert_false(RunFlow.can_advance_node(run, "n9_9"), "非邻接不可走")

func test_cannot_advance_chapter_before_boss():
	# M4 迁移：boss_defeated:bool → bosses_defeated:Array（空 = 未败）
	var run := _run()
	run.chapter_progress[1]["bosses_defeated"] = []
	assert_false(RunFlow.can_advance_chapter(run), "boss 未败不可进下章")

func test_can_advance_chapter_after_boss():
	# M4 迁移：on_boss_defeated(run, boss_id) append boss id
	var run := _run()
	RunFlow.on_boss_defeated(run, "hailianzheng")
	assert_true(RunFlow.can_advance_chapter(run), "boss 败后可进下章")
	assert_eq(run.chapter_progress[1]["bosses_defeated"], ["hailianzheng"], "记录 boss id")

# —— M4 T5: bosses_defeated 记录 boss_id ——
func test_bosses_defeated_records_boss_id():
	var run := _run()
	run.chapter_progress[1]["bosses_defeated"] = []
	RunFlow.on_boss_defeated(run, "hailianzheng")
	assert_eq(run.chapter_progress[1]["bosses_defeated"], ["hailianzheng"])

func test_bosses_defeated_dedup():
	# 同 boss id 多次记录只留一份（去重）
	var run := _run()
	run.chapter_progress[1]["bosses_defeated"] = []
	RunFlow.on_boss_defeated(run, "hailianzheng")
	RunFlow.on_boss_defeated(run, "hailianzheng")
	assert_eq(run.chapter_progress[1]["bosses_defeated"], ["hailianzheng"], "重复 boss id 去重")

func test_can_advance_chapter_any_l7_boss():
	# 章2：打通莫青娘或晏九任一即可
	var run := _run()
	run.current_chapter = 2
	run.chapter_maps[2] = MapGenerator.generate_map(7, 2, 0)
	run.chapter_progress[2] = {"bosses_defeated": []}
	assert_false(RunFlow.can_advance_chapter(run), "章2 boss 均未败不可推进")
	RunFlow.on_boss_defeated(run, "moqingniang")
	assert_true(RunFlow.can_advance_chapter(run), "章2 任一 boss 胜→可推进")

func test_can_advance_chapter_chapter4_requires_yanwujiu():
	# 章4：L6 mini-boss（sikongyi/leiwanjun）不算，必须 L7 掌门 yanwujiu
	var run := _run()
	run.current_chapter = 4
	run.chapter_maps[4] = MapGenerator.generate_map(7, 4, 0)
	run.chapter_progress[4] = {"bosses_defeated": []}
	assert_false(RunFlow.can_advance_chapter(run), "章4 掌门未败不可推进")
	RunFlow.on_boss_defeated(run, "sikongyi")   # L6 mini-boss
	assert_false(RunFlow.can_advance_chapter(run), "章4 mini-boss 胜仍不可推进（需掌门）")
	RunFlow.on_boss_defeated(run, "yanwujiu")
	assert_true(RunFlow.can_advance_chapter(run), "章4 掌门颜无咎胜→可推进")

func test_advance_chapter_generates_next_map():
	var run := _run()
	run.current_chapter = 1
	run.chapter_progress[1]["bosses_defeated"] = ["hailianzheng"]
	RunFlow.advance_chapter(run)
	assert_eq(run.current_chapter, 2, "current_chapter+1")
	assert_true(run.chapter_maps.has(2), "章2 图已生成")
	assert_eq(run.chapter_progress[2]["bosses_defeated"], [], "章2 progress 初始化空")
	assert_eq(run.current_node_id, "", "进新章回 hub 定位（空 = hub）")

func test_chapter1_boss_flow_still_works():
	# 章1 兼容：on_boss_defeated(hailianzheng) → can_advance
	var run := _run()
	run.chapter_progress[1]["bosses_defeated"] = []
	assert_false(RunFlow.can_advance_chapter(run))
	RunFlow.on_boss_defeated(run, "hailianzheng")
	assert_true(RunFlow.can_advance_chapter(run), "章1 赫连铮胜→可推进")

func test_enter_node_updates_current_and_log():
	var run := _run()
	var m: Dictionary = run.chapter_maps[1]
	var nxt: Array = MapGenerator.reachable_next(m, run.current_node_id)
	RunFlow.enter_node(run, nxt[0])
	assert_eq(run.current_node_id, nxt[0])
	assert_true(run.chapter_progress[1]["nodes_visited"].has(nxt[0]), "记录已访问")

# —— 回归（bug: init_run 后 current_node_id="" 进 map 无节点可点）——
func _first_node_of_layer(run: RunState, layer: int) -> String:
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	for id in m["nodes"]:
		if int(m["nodes"][id]["layer"]) == layer:
			return id
	return ""

func test_place_at_chapter_start_fixes_unreachable_bug():
	# 复现：fresh init_run 的 current_node_id="" → 进图前 L1 节点不可 advance（bug 症状）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	assert_eq(run.current_node_id, "", "fresh run current_node_id 空（在 hub）")
	var l1 := _first_node_of_layer(run, 1)
	assert_false(RunFlow.can_advance_node(run, l1), "未定位起点时 L1 节点不可 advance（bug）")
	# 修复：place_at_chapter_start 定位到 L0 起点
	RunFlow.place_at_chapter_start(run)
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	assert_eq(int(m["nodes"][run.current_node_id]["layer"]), 0, "定位到 L0 起点")
	assert_true(RunFlow.can_advance_node(run, l1), "定位后 L1 节点可 advance（修复）")

func test_place_at_chapter_start_idempotent():
	# 已在某节点时（如战斗后返回 map）→ 幂等不动
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	RunFlow.place_at_chapter_start(run)
	var first: String = run.current_node_id
	assert_ne(first, "")
	RunFlow.place_at_chapter_start(run)
	assert_eq(run.current_node_id, first, "已在节点时幂等不改")

func test_is_run_over_when_protagonist_dead():
	# permadeath：主角死 = 局结束（回 hub，meta 沉淀）。主角存活 = 继续。
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	assert_false(RunFlow.is_run_over(run), "主角存活 → 局未结束")
	run.player_roster[0]["alive"] = false
	assert_true(RunFlow.is_run_over(run), "主角死 → 局结束")

func test_is_run_over_ally_dead_protagonist_alive():
	# 队友死、主角活 → 局不结束（permadeath 只认主角）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster.append(RunFactory._ally("F4", 1))
	run.player_roster[1]["alive"] = false   # 队友死
	assert_false(RunFlow.is_run_over(run), "队友死主角活 → 局未结束")

func test_is_run_over_protagonist_dead_ally_alive():
	# 主角死、队友活 → 局结束（即便有存活队友）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster.append(RunFactory._ally("F4", 1))
	run.player_roster[0]["alive"] = false   # 主角死
	run.player_roster[1]["alive"] = true    # 队友活
	assert_true(RunFlow.is_run_over(run), "主角死 → 局结束（无视队友存活）")

# —— 死亡队友剔除（修 bug：死亡队友永久占 roster 致 cap 被幽灵偷）——

func test_cull_dead_allies_removes_dead_keeps_protagonist_and_alive():
	# 死亡非主角队友剔除；主角（无论死活，主角死由 is_run_over/commit 处理）与存活队友保留
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster.append(RunFactory._ally("F4", 1))   # 存活队友
	run.player_roster.append(RunFactory._ally("F2", 2))   # 将死的队友
	run.player_roster[2]["alive"] = false
	RunFlow.cull_dead_allies(run)
	assert_eq(run.player_roster.size(), 2, "死亡队友被剔除")
	assert_eq(run.player_roster[0]["id"], "protagonist", "主角保留")
	assert_eq(run.player_roster[1]["id"], "ally_F4_1", "存活队友保留")

func test_cull_dead_allies_frees_slot_for_re_recruit():
	# 修 bug 核心场景：队友死后回 hub，roster_cap 不被幽灵占，可再招
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster.append(RunFactory._ally("F4", 1))
	run.player_roster[1]["alive"] = false   # 队友死
	RunFlow.cull_dead_allies(run)
	assert_eq(run.player_roster.size(), 1, "死亡队友剔除后 roster 回到 1（主角）")
	# 再招：idx 应=1（首个空槽），不与旧死亡队友的 ally_F4_1 id 冲突
	var idx: int = run.player_roster.size()
	run.player_roster.append(RunFactory._ally("F2", idx))
	assert_eq(run.player_roster[1]["id"], "ally_F2_1", "新队友 id 不与旧死亡队友冲突")

func test_cull_dead_allies_keeps_dead_protagonist():
	# 主角死不剔除（permadeath 由 commit_run_to_meta/is_run_over 处理，roster 保留供判定）
	var run := RunFactory.init_run(MetaState.new_first_play(), 7)
	run.player_roster[0]["alive"] = false   # 主角死
	RunFlow.cull_dead_allies(run)
	assert_eq(run.player_roster.size(), 1, "主角（死）保留——供 is_run_over 判定")
	assert_true(RunFlow.is_run_over(run), "主角死 → 局结束（cull 后仍可判）")

# —— T10c: 镖局休整（RunFlow.rest 单一真源）——
# rest 语义：每章 rest_cap_per_chapter 次满血休整。配额满或全员满血→不消耗。

func _rest_run(hp: int, max_hp: int, rest_used: int) -> RunState:
	# 合成带一个主角的 roster（hp/max_hp/rest_used 可配）
	var run := _run()
	run.player_roster = [{
		"id":"protagonist","team":0,"hp":hp,"max_hp":max_hp,
		"opening":0,"max_opening":6,"stance":0,"grid_pos":[1,3],
		"facing":0,"guard_broken":false,"alive":true,
		"kit_ids":["tongshi_jinda"],"is_protagonist":true,
	}]
	run.rest_used = rest_used
	return run

func test_rest_heals_roster_and_increments_used():
	# roster 损伤 + rest_used<cap → 满血 + rest_used+1，返回 true
	var run := _rest_run(10, 20, 0)
	var healed: bool = RunFlow.rest(run, Tuning.new())
	assert_true(healed, "损伤+配额可用 → 已休整（true）")
	assert_eq(int(run.player_roster[0]["hp"]), 20, "主角满血")
	assert_eq(run.rest_used, 1, "rest_used +1")

func test_rest_noop_when_cap_reached():
	# rest_used==cap → 返回 false、hp 不变、rest_used 仍 cap
	var run := _rest_run(10, 20, 3)   # cap=3 已用满（T10f 调平）
	var healed: bool = RunFlow.rest(run, Tuning.new())
	assert_false(healed, "配额用满 → 未休整（false）")
	assert_eq(int(run.player_roster[0]["hp"]), 10, "配额满不回血")
	assert_eq(run.rest_used, 3, "rest_used 不增")

func test_rest_noop_when_full_hp():
	# 满血 → 不消耗配额（无需休整），返回 false
	var run := _rest_run(20, 20, 0)
	var healed: bool = RunFlow.rest(run, Tuning.new())
	assert_false(healed, "满血 → 未休整（false）")
	assert_eq(int(run.player_roster[0]["hp"]), 20, "满血保持")
	assert_eq(run.rest_used, 0, "满血不消耗配额")

func test_advance_chapter_resets_rest_used():
	# advance_chapter 末尾重置 rest_used=0（rest_used 重置的唯一真源）
	var run := _run()
	run.rest_used = 2   # 当章已用满
	run.chapter_progress[1]["bosses_defeated"] = ["hailianzheng"]
	RunFlow.advance_chapter(run)
	assert_eq(run.rest_used, 0, "进新章 rest_used 重置 0（唯一真源）")
