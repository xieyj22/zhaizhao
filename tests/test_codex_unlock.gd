extends GutTest

## Task 3（M4 Wave2）: MetaState codex 累积字段 + 局末收割 + CodexUnlock 纯函数求值。

func _meta() -> MetaState:
	var m := MetaState.new_first_play()
	m.bosses_defeated_all = []
	m.chapters_reached = [1]
	return m

func test_new_fields_roundtrip_and_olddict_compat():
	var m := _meta()
	m.bosses_defeated_all = ["hailianzheng", "zongzhenglie"]
	m.chapters_reached = [1, 2, 3]
	var r: MetaState = MetaState.from_dict(m.to_dict())
	assert_eq(r.bosses_defeated_all, ["hailianzheng", "zongzhenglie"])
	assert_eq(r.chapters_reached, [1, 2, 3])
	# 旧档（无新字段）
	var old := {"meta_unlocked_pool": [], "meta_faction_relations": {}, "meta_runs_completed": 2}
	var m2: MetaState = MetaState.from_dict(old)
	assert_eq(m2.bosses_defeated_all.size(), 0)
	assert_eq(m2.chapters_reached.size(), 0)
	assert_eq(m2.meta_runs_completed, 2)

func test_commit_harvests_bosses_and_chapters():
	var run := RunFactory.init_run(_meta(), 7)
	run.current_chapter = 3
	run.chapter_progress[1] = {"bosses_defeated": ["hailianzheng"], "nodes_visited": []}
	run.chapter_progress[2] = {"bosses_defeated": ["moqingniang"], "nodes_visited": []}
	run.chapter_progress[3] = {"bosses_defeated": [], "nodes_visited": []}
	var meta := MetaState.commit_run_to_meta(_meta(), run, false)
	assert_has(meta.bosses_defeated_all, "hailianzheng")
	assert_has(meta.bosses_defeated_all, "moqingniang")
	assert_has(meta.chapters_reached, 3)
	# 二次收割去重
	var meta2 := MetaState.commit_run_to_meta(meta, run, false)
	assert_eq(meta2.bosses_defeated_all.size(), 2, "去重")

func test_unlock_types():
	var m := _meta()
	var e_always: Dictionary = {"unlock": {"type": "always", "key": ""}}
	var e_boss: Dictionary = {"unlock": {"type": "boss_defeated", "key": "yanjiu"}}
	var e_ch: Dictionary = {"unlock": {"type": "chapter_reached", "key": 4}}
	var e_tech: Dictionary = {"unlock": {"type": "technique_owned", "key": "xueyi_xuedao"}}
	var e_runs: Dictionary = {"unlock": {"type": "runs_completed_ge", "key": 1}}
	assert_true(CodexUnlock.is_unlocked(e_always, m))
	assert_false(CodexUnlock.is_unlocked(e_boss, m))
	m.bosses_defeated_all = ["yanjiu"]
	assert_true(CodexUnlock.is_unlocked(e_boss, m))
	assert_false(CodexUnlock.is_unlocked(e_ch, m))
	m.chapters_reached = [1, 4]
	assert_true(CodexUnlock.is_unlocked(e_ch, m))
	assert_false(CodexUnlock.is_unlocked(e_tech, m))
	m.meta_unlocked_pool.append("xueyi_xuedao")
	assert_true(CodexUnlock.is_unlocked(e_tech, m))
	m.meta_runs_completed = 1
	assert_true(CodexUnlock.is_unlocked(e_runs, m))

func test_codex_count_ge_two_pass_no_recursion_trap():
	# codex_count_ge 以「非 count 型已解锁条目数」计数（两遍求值，防递归自含）。
	# _base_count 遍历真表 CODEX_ENTRIES——brief 的合成 e1/e2 不入表，
	# 故阈值边界按真表基数动态校准（防真表后续增长漂移）：key=基数 恰解锁 / key=基数+1 不解锁。
	var m := _meta()
	var base0: int = CodexUnlock._base_count(m)
	assert_true(base0 >= 1, "真表至少 1 条 always 已解锁（基数非零起点）")
	assert_false(
		CodexUnlock.is_unlocked({"unlock": {"type": "codex_count_ge", "key": base0 + 1}}, m),
		"key=基数+1 未达，不解锁")
	assert_true(
		CodexUnlock.is_unlocked({"unlock": {"type": "codex_count_ge", "key": base0}}, m),
		"key=基数 恰达，解锁")
	# 非 count 解锁数增长 → 基数随之增长（到章 3 后 geo_chenjianggu 计入）
	var ids0: Array = CodexUnlock.unlocked_ids(m)   # chapters=[1]
	assert_has(ids0, "lore_daotong_1")
	assert_false(ids0.has("geo_chenjianggu"), "未抵章 3 不解锁")
	m.chapters_reached = [1, 3]
	assert_gt(CodexUnlock._base_count(m), base0, "到章3后基数增长")
	# unlocked_ids 覆盖两遍逻辑（遍历真表 CODEX_ENTRIES：brief 合成 a/b/c 不在真表，
	# 按语义改为真表断言——always 条目恒入、chapter_reached 条目按到章入；断言用 has 防表增长漂移）
	var ids: Array = CodexUnlock.unlocked_ids(m)
	assert_has(ids, "lore_daotong_1")
	assert_has(ids, "geo_chenjianggu")

func test_hint_for_templates():
	assert_eq(CodexUnlock.hint_for({"unlock": {"type": "boss_defeated", "key": "yanjiu"}}), "击败该首领后解锁")
	assert_eq(CodexUnlock.hint_for({"unlock": {"type": "chapter_reached", "key": 4}}), "抵达该章后解锁")
	assert_eq(CodexUnlock.hint_for({"unlock": {"type": "technique_owned", "key": "x"}}), "习得对应招式后解锁")
	assert_eq(CodexUnlock.hint_for({"unlock": {"type": "runs_completed_ge", "key": 1}}), "通关后解锁")
	assert_eq(CodexUnlock.hint_for({"unlock": {"type": "codex_count_ge", "key": 2}}), "江湖志收集更多条目后解锁")
	assert_eq(CodexUnlock.hint_for({"unlock": {"type": "always", "key": ""}}), "")
