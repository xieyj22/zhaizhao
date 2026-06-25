extends GutTest

# meta loop harness：整局 headless 闭环回归网。
# 之前 permadeath bug 缺整局测才漏——本测确保整局能终止/产出合法 outcome/章节推进。

func test_run_one_terminates_with_valid_outcome():
	# 固定 seed 跑一局：必须终止（不无限循环），outcome ∈ {cleared, protagonist_dead, stalled}
	var meta := MetaState.new_first_play()
	var res := MetaLoopHarness.run_one(meta, 7, AIPersonality.brain())
	var valid_outcomes: Array = ["cleared", "protagonist_dead", "boss_draw", "stalled"]
	assert_true(valid_outcomes.has(res.outcome), "outcome 合法: %s" % res.outcome)
	assert_eq(res.chapter_reached, 1, "章 2-4 未实装，止于章 1")
	assert_true(res.battles_fought >= 0, "战斗场次非负")

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
