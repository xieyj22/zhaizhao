extends GutTest

func test_trial_boss_entry_complete():
	var b: Dictionary = NarrativeBoss.entry("zongzhenglie")
	for k in ["bio", "pre", "post_win", "post_loss", "trait_lines"]:
		assert_true(b.has(k), "字段 %s" % k)
	assert_gt(String(b["bio"]).length(), 200, "小传 >=200 汉字级长度")
	assert_gte((b["pre"] as Array).size(), 6, "战前 >=6 句")
	assert_gte((b["post_win"] as Array).size(), 4, "胜 >=4 句")
	assert_gte((b["post_loss"] as Array).size(), 3, "败 >=3 句")

func test_every_present_entry_is_complete():
	# 结构有效性：凡在表中的 boss 必四套齐（W2-2 逐批灌入不破坏此不变量；8 boss 全量断言留 Task 13）
	for bid in NarrativeBoss.BOSS_NARRATIVE:
		var b: Dictionary = NarrativeBoss.entry(String(bid))
		assert_false(String(b["bio"]).is_empty(), "%s bio 空" % bid)
		for key in ["pre", "post_win", "post_loss"]:
			var arr: Array = b[key]
			assert_false(arr.is_empty(), "%s %s 空" % [bid, key])
			for ln in arr:
				var d: Dictionary = ln
				assert_false(String(d["line"]).is_empty(), "%s %s 空句" % [bid, key])

func test_dialogue_miss_returns_empty():
	assert_eq(NarrativeBoss.dialogue("nope", "pre").size(), 0)
	assert_eq(NarrativeBoss.dialogue("zongzhenglie", "nope").size(), 0)
	assert_eq(NarrativeBoss.line("nope", "frenzy_on"), "")
	assert_eq(NarrativeBoss.line("zongzhenglie", "frenzy_on"), "")   # 宗政烈无此触发

func test_interlude_and_prose():
	assert_gt(NarrativeRegion.interlude(3, "open").length(), 50, "章3 open（试写含沉剑谷氛围则填章3）")
	assert_eq(NarrativeRegion.interlude(9, "open"), "", "未命中空")
	assert_gt(NarrativeRegion.prose("chenjianggu").length(), 50, "沉剑谷散文")
	assert_eq(NarrativeRegion.prose("nope"), "")

func test_codex_entries_schema():
	for e in NarrativeCodex.CODEX_ENTRIES:
		var d: Dictionary = e
		for k in ["id", "category", "title", "unlock"]:
			assert_true(d.has(k), "codex 字段 %s" % k)
		var u: Dictionary = d["unlock"]
		assert_true(u.has("type"), "unlock.type")
	assert_true(NarrativeCodex.CODEX_ENTRIES.size() >= 1, "至少试写条目在表")

func test_db_facade_forwards():
	assert_eq(NarrativeDB.boss_dialogue("zongzhenglie", "pre"), NarrativeBoss.dialogue("zongzhenglie", "pre"))
	assert_eq(NarrativeDB.boss_line("zongzhenglie", "frenzy_on"), NarrativeBoss.line("zongzhenglie", "frenzy_on"))
	assert_eq(NarrativeDB.prose("chenjianggu"), NarrativeRegion.prose("chenjianggu"))
	assert_eq(NarrativeDB.interlude(9, "open"), "")

func test_wave2_final_completeness():
	assert_eq(NarrativeBoss.BOSS_NARRATIVE.size(), 8, "8 boss 全量")
	for bid in ["hailianzheng", "moqingniang", "yanjiu", "zongzhenglie", "peiyuan", "sikongyi", "leiwanjun", "yanwujiu"]:
		assert_true(NarrativeBoss.BOSS_NARRATIVE.has(bid), "%s 在表" % bid)
	assert_eq(NarrativeRegion.REGION_PROSE.size(), 5, "5 区散文")
	for ch in [1, 2, 3, 4]:
		for seg in ["open", "mid", "close"]:
			assert_gt(NarrativeRegion.interlude(ch, seg).length(), 50, "章%d %s" % [ch, seg])
	var geo := 0; var wu := 0
	for e in NarrativeCodex.CODEX_ENTRIES:
		var d: Dictionary = e
		if d["category"] == "山河志": geo += 1
		if d["category"] == "武道志": wu += 1
	assert_eq(geo, 5, "山河志 5 条")
	assert_eq(wu, 43, "武道志 5+16+14+8=43 条")
	# trait_lines 覆盖：三个触发点各有主
	assert_true(NarrativeBoss.line("leiwanjun", "frenzy_on") != "")
	assert_true(NarrativeBoss.line("yanwujiu", "drain_on") != "")
	assert_true(NarrativeBoss.line("sikongyi", "read_hit") != "")
