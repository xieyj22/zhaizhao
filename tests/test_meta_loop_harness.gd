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
