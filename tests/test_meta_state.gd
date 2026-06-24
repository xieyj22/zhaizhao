extends GutTest

## Task MS: MetaState 跨 run meta（唯一落盘类）。

func test_defaults_first_play():
	var m := MetaState.new_first_play()
	assert_true(m.meta_unlocked_pool.has("tongshi_jinda"))
	assert_eq(m.meta_faction_relations["F4"], 40)
	assert_eq(m.meta_faction_relations["F8"], -100)
	assert_false(m.meta_inheritance_unlocked)
	assert_eq(m.meta_runs_completed, 0)

func test_round_trip():
	var m := MetaState.new_first_play()
	m.meta_runs_completed = 2
	m.meta_unlocked_pool.append("chifeng_lianci")
	var d := m.to_dict()
	var m2 := MetaState.from_dict(d)
	assert_eq(JSON.stringify(d), JSON.stringify(m2.to_dict()))

func test_commit_merges_pool_and_relations():
	var meta := MetaState.new_first_play()
	var run := RunState.new()
	run.unlocked_techniques = ["chifeng_lianci","chifeng_yajin"]
	run.faction_relations = {"F2":50,"F4":40,"F8":-100}
	var m2 := MetaState.commit_run_to_meta(meta, run, true)
	assert_true(m2.meta_unlocked_pool.has("chifeng_lianci"), "新解锁招并入池")
	assert_eq(m2.meta_faction_relations["F2"], 50, "关系取 max")
	assert_eq(m2.meta_runs_completed, 1, "通关 +1")
	assert_true(m2.meta_inheritance_unlocked, "首次通关解锁传承")
	assert_eq(m2.meta_faction_relations["F8"], -100)

func test_save_load_round_trip():
	var path := "user://test_meta_tmp.sav"
	var m := MetaState.new_first_play()
	m.meta_runs_completed = 3
	MetaState.save_to(m, path)
	assert_true(FileAccess.file_exists(path))
	var m2 := MetaState.load_from(path)
	assert_eq(m2.meta_runs_completed, 3)
	DirAccess.remove_absolute(path)   # 清理

## Point 2 守卫：commit_run_to_meta 必须深拷贝，不得污染输入 meta。
func test_commit_does_not_mutate_input():
	var meta := MetaState.new_first_play()
	var pool_before: Array = meta.meta_unlocked_pool.duplicate()
	var rel_before_f2: int = int(meta.meta_faction_relations.get("F2", 0))
	var rel_before_f8: int = int(meta.meta_faction_relations["F8"])
	var runs_before := meta.meta_runs_completed
	var inher_before := meta.meta_inheritance_unlocked
	var run := RunState.new()
	run.unlocked_techniques = ["chifeng_lianci"]
	run.faction_relations = {"F2":50,"F8":-100}
	var _ignored := MetaState.commit_run_to_meta(meta, run, true)
	# 输入 meta 的池不得被 append
	assert_eq(meta.meta_unlocked_pool, pool_before, "输入池未被污染")
	assert_false(meta.meta_unlocked_pool.has("chifeng_lianci"), "输入池未并入新招")
	# 输入 meta 的关系/计数/传承不得被改
	assert_eq(meta.meta_faction_relations.get("F2", 0), rel_before_f2, "输入关系未被改")
	assert_eq(meta.meta_faction_relations["F8"], rel_before_f8, "输入 F8 未被改")
	assert_eq(meta.meta_runs_completed, runs_before, "输入通关数未被改")
	assert_eq(meta.meta_inheritance_unlocked, inher_before, "输入传承未被改")
