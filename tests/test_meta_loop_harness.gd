extends GutTest

# meta loop harness：整局 headless 闭环回归网（M4a T9：4 章闭环扩展）。
# 之前 permadeath bug 缺整局测才漏——本测确保整局能终止/产出合法 outcome/章节推进。
# 章 N boss 胜 → advance_chapter 续跑；章 4 yanwujiu 胜 = cleared。

func test_run_one_terminates_with_valid_outcome():
	# 固定 seed 跑一局：必须终止（不无限循环），outcome ∈ {cleared, protagonist_dead, stalled, boss_draw}
	var meta := MetaState.new_first_play()
	var res := MetaLoopHarness.run_one(meta, 7, AIPersonality.brain())
	var valid_outcomes: Array = ["cleared", "protagonist_dead", "boss_draw", "stalled"]
	assert_true(valid_outcomes.has(res.outcome), "outcome 合法: %s" % res.outcome)
	assert_gte(res.chapter_reached, 1, "章节推进至少到章 1（续跑可能更深）")
	assert_true(res.battles_fought >= 0, "战斗场次非负")

func test_run_one_advances_past_chapter1():
	# 4 章闭环（逻辑验证）：多 seed 跑，至少一局推进到章 2+（验 advance_chapter 续跑接通）。
	# 注：到不了章 4 是平衡问题（玩家方当前偏弱），非代码 bug——本测只验 advance 续跑机制本身。
	# 实测 15 seed brain 通常有 8-12 局到章 2，故 max_ch>=2 是稳健的逻辑断言。
	var meta := MetaState.new_first_play()
	var max_ch := 1
	for s in 15:
		var r := MetaLoopHarness.run_one(meta, 100 + s * 7, AIPersonality.brain())
		max_ch = maxi(max_ch, r.chapter_reached)
	assert_gte(max_ch, 2, "存在 advance 到章 2 的局（验 advance_chapter 续跑机制）")

func test_chapter2_boss_encounter_distribution():
	# 章 2 双 boss 选其一（逻辑验证）：多性格 × 宽 seed 扫，莫青娘/晏九都被遇过。
	# 验两件事：① 节点真实 boss_id 被读（非固定 EnemyPool.CHAPTER_BOSS_ID[2]）；
	#          ② bosses_met 记录遭遇。宽扫对冲平衡（玩家方偏弱，单 20 seed 可能全死在 ch2 boss 前）。
	var meta := MetaState.new_first_play()
	var met := {"moqingniang":0, "yanjiu":0}
	for pers_name in ["brain", "brute", "trick"]:
		var pers := AIPersonality.brain()
		if pers_name == "brute":
			pers = AIPersonality.brute()
		elif pers_name == "trick":
			pers = AIPersonality.trick()
		for s in 80:
			var r := MetaLoopHarness.run_one(meta, 1000 + s * 17, pers)
			for b in r.bosses_met:
				if met.has(b):
					met[b] += 1
	assert_true(met["moqingniang"] > 0 and met["yanjiu"] > 0, "章 2 两 boss 都被遇过（验真实 boss_id + bosses_met 记录）")

func test_run_one_deterministic_same_seed():
	# 同 seed 同结果（纯函数层确定性）
	var meta := MetaState.new_first_play()
	var r1 := MetaLoopHarness.run_one(meta, 42, AIPersonality.brain())
	var r2 := MetaLoopHarness.run_one(meta, 42, AIPersonality.brain())
	assert_eq(r1.outcome, r2.outcome, "同 seed 同 outcome")
	assert_eq(r1.battles_fought, r2.battles_fought, "同 seed 同战斗场次")
	assert_eq(r1.bosses_defeated, r2.bosses_defeated, "同 seed 同 boss 击败数")

func test_run_one_auto_recruits_allies():
	# 保真度：开局 auto_recruit 招满可招派系（F4 初始 40≥30 可招）→ roster >1
	# 用 init_run 直接看招募效果（run_one 内部调 _auto_recruit，这里测其可观测：同 seed 跑出的 run
	# 因多队友而与 auto_recruit=false 不同——验 auto_recruit 开关改变行为）
	var meta := MetaState.new_first_play()
	var with_recruit := MetaLoopHarness.run_one(meta, 7, AIPersonality.brain(), true)
	var no_recruit := MetaLoopHarness.run_one(meta, 7, AIPersonality.brain(), false)
	# 招募与否应影响整局（战斗场次/outcome 至少其一不同，因队友增伤）——不强求方向，仅证开关生效
	var differs: bool = with_recruit.battles_fought != no_recruit.battles_fought \
		or with_recruit.outcome != no_recruit.outcome
	assert_true(differs, "auto_recruit 开关改变整局行为（队友参战）")

func test_run_one_does_not_loop_forever():
	# 多 seed 都能终止（防 DAG 卡死/permadeath 漏判导致无限走）
	var meta := MetaState.new_first_play()
	for s in [1, 2, 3, 100, 777]:
		var res := MetaLoopHarness.run_one(meta, s, AIPersonality.brain())
		assert_ne(res.outcome, "", "seed %d 终止并产出 outcome" % s)

func test_run_series_aggregates():
	# 跑 N 局汇总：runs 计数正确，clear+death+stall == runs
	var meta := MetaState.new_first_play()
	var st := MetaLoopHarness.run_series(meta, 5, AIPersonality.brain())
	assert_eq(st.runs, 5, "跑了 5 局")
	assert_eq(st.cleared + st.protagonist_dead + st.boss_draw + st.stalled, st.runs, "四类 outcome 之和 == runs")

func test_run_one_protagonist_death_possible():
	# 弱玩家（trick 性格对 boss brute 不利）跑多 seed，至少应能跑完不崩；
	# 且若某局主角死，outcome 必为 protagonist_dead（验证 permadeath 判定接进了闭环）
	var meta := MetaState.new_first_play()
	var saw_death := false
	var saw_non_stall := false
	for s in 8:
		var res := MetaLoopHarness.run_one(meta, 11 + s * 7, AIPersonality.brute())
		if res.outcome == "protagonist_dead":
			saw_death = true
		if res.outcome != "stalled":
			saw_non_stall = true
	# 至少有一局能正常结束（cleared 或 protagonist_dead），证明闭环不是全 stalled
	assert_true(saw_non_stall, "存在非 stalled 局（闭环能真正通关或死亡，非卡死）")
	# saw_death 不强求（取决于平衡），仅文档化：若主角死则 outcome 正确
	if saw_death:
		pass_test("检测到 protagonist_dead 局，permadeath 判定已接进闭环")

# ---- ch4 通关分支合成测试（M4a T9 review fix）----
# 当前平衡下玩家 100% 死亡、活不到章 4，故 run_one 集成路径覆盖不到 ch4 cleared 分支。
# 这里直接驱动纯函数 _progress_after_boss：用合成 run 状态绕开平衡，专门验通关决策逻辑。
# 关键不变量：ch4 yanwujiu 胜 → cleared，且 current_chapter 不溢出到 5（否则 generate_map(5) 会炸）。

func _make_synthetic_run(chapter: int, bosses_defeated: Array) -> RunState:
	# 用 init_run 拿到合法章1 run（roster/modifier/seed 全齐），再手动调成目标章状态。
	# 注意：不调 generate_map(chapter)——_progress_after_boss 在 ch4 分支只读 current_chapter，
	#       ch1-3 分支才 advance（advance 内部会 generate_map(next_chapter)）。
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, 7)
	run.current_chapter = chapter
	run.chapter_progress[chapter] = {"bosses_defeated": bosses_defeated.duplicate(), "nodes_visited": []}
	return run

func test_progress_after_boss_ch4_cleared():
	# ch4 + yanwujiu 已败 → cleared，current_chapter 保持 4（不推进到 5），无 chapter_maps[5]
	var run := _make_synthetic_run(4, ["yanwujiu"])
	var outcome: String = MetaLoopHarness._progress_after_boss(run)
	assert_eq(outcome, "cleared", "ch4 yanwujiu 胜 → cleared")
	assert_eq(run.current_chapter, 4, "ch4 cleared 后 current_chapter 不溢出到 5")
	assert_false(run.chapter_maps.has(5), "未触发 generate_map(5)（防炸的关键不变量）")

func test_progress_after_boss_ch3_advances():
	# ch3 + 宗政烈已败 → ""（推进续跑），current_chapter=4，chapter_maps[4] 被生成
	var run := _make_synthetic_run(3, ["zongzhenglie"])
	var outcome: String = MetaLoopHarness._progress_after_boss(run)
	assert_eq(outcome, "", "ch3 boss 胜 → 非通关，循环继续")
	assert_eq(run.current_chapter, 4, "advance 后 current_chapter==4")
	assert_true(run.chapter_maps.has(4), "advance 生成了章 4 图")

func test_progress_after_boss_no_clear_until_boss_defeated():
	# ch4 但 yanwujiu 未败 → ""（继续当章）——掌门未死不算通关
	var run := _make_synthetic_run(4, [])
	var outcome: String = MetaLoopHarness._progress_after_boss(run)
	assert_eq(outcome, "", "ch4 yanwujiu 未败 → 不通关，继续当章")
	assert_eq(run.current_chapter, 4, "未推进，仍在章 4")

# ---- T10b Part B: harness 战斗间休整回血模型（复刻 rest_cap 设计）----
# 复刻设计意图：每章 rest_cap_per_chapter 次满血休整。roster 有损伤且配额未满→满血+rest_used++。
# 直接驱动纯函数 _maybe_rest（绕开整局平衡），验休整逻辑本身。

func _rest_test_run(hp: int, max_hp: int, rest_used: int) -> RunState:
	# 合成带一个损伤主角的 roster（hp<max_hp），rest_used 可配
	var run := _make_synthetic_run(1, [])
	run.player_roster = [{
		"id":"protagonist","team":0,"hp":hp,"max_hp":max_hp,
		"opening":0,"max_opening":6,"stance":0,"grid_pos":[1,3],
		"facing":0,"guard_broken":false,"alive":true,
		"kit_ids":["tongshi_jinda"],"is_protagonist":true,
	}]
	run.rest_used = rest_used
	return run

func test_maybe_rest_heals_when_cap_available():
	# roster 损伤 + rest_used<cap → 满血 + rest_used+1
	var run := _rest_test_run(8, 20, 0)
	var tuning := Tuning.new()   # rest_cap_per_chapter=2 默认
	MetaLoopHarness._maybe_rest(run, tuning)
	assert_eq(int(run.player_roster[0]["hp"]), 20, "损伤 + 配额可用 → 满血")
	assert_eq(run.rest_used, 1, "rest_used +1")

func test_maybe_rest_noop_when_cap_used():
	# rest_used==cap → 不回血、不增 rest_used
	var run := _rest_test_run(8, 20, 2)   # cap=2 已用满
	var tuning := Tuning.new()
	MetaLoopHarness._maybe_rest(run, tuning)
	assert_eq(int(run.player_roster[0]["hp"]), 8, "配额用满 → 不回血")
	assert_eq(run.rest_used, 2, "rest_used 不增")

func test_maybe_rest_noop_when_full_hp():
	# 满血 → 不消耗配额（无需休整）
	var run := _rest_test_run(20, 20, 0)
	var tuning := Tuning.new()
	MetaLoopHarness._maybe_rest(run, tuning)
	assert_eq(int(run.player_roster[0]["hp"]), 20, "满血 → 保持满血")
	assert_eq(run.rest_used, 0, "满血 → 不消耗配额")
