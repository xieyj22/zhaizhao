extends GutTest

func _sample() -> RunState:
	var r := RunState.new()
	r.run_id = "run_001"
	r.rng_seed = 12345
	r.current_chapter = 1
	r.current_node_id = "n3"
	r.chapter_maps = {1: {"nodes":{"n0":{"layer":0,"type":"start"}}, "edges":[], "seed":12345, "chapter":1}}
	r.player_roster = [{
		"id":"protagonist", "team":0, "hp":20, "max_hp":20, "opening":0, "max_opening":6,
		"stance":0, "grid_pos":[1,2], "facing":0, "guard_broken":false, "alive":true,
		"display_name":"遗照", "faction_id":"F1", "personality_id":"brain",
		"kit_ids":["tongshi_jinda","tongshi_zhongda"], "is_protagonist":true,
	}]
	r.unlocked_techniques = ["tongshi_jinda","tongshi_zhongda"]
	r.technique_variants = {"tongshi_jinda":"strong"}
	r.hazard_modifiers = {}
	r.faction_relations = {"F1":0,"F4":40,"F8":-100}
	r.jianghu_credit = 25
	r.inheritance_slot = {}
	r.chapter_progress = {1:{"boss_defeated":false,"nodes_visited":["n0","n1"]}}
	r.run_log = [{"node_id":"n1","node_type":"duel","outcome":"win"}]
	return r

func test_round_trip_deep_equal():
	var r := _sample()
	var d := r.to_dict()
	var r2 := RunState.from_dict(d)
	var d2 := r2.to_dict()
	assert_eq(JSON.stringify(d), JSON.stringify(d2), "round-trip 深相等")

func test_no_node_or_resource_refs():
	var r := _sample()
	assert_true(_scan_safe(r.to_dict()), "全字段 JSON-safe（无 Node/Resource/Object）")

func _scan_safe(v) -> bool:
	if v is Dictionary:
		for k in v: if not _scan_safe(v[k]): return false
		return true
	if v is Array:
		for e in v: if not _scan_safe(e): return false
		return true
	return v is int or v is float or v is bool or v is String

func test_rest_upgrade_not_serialized():
	var r := _sample()
	r.rest_used = 2; r.upgrade_used = 1
	assert_false(r.to_dict().has("rest_used"), "rest_used 不序列化")
	assert_false(r.to_dict().has("upgrade_used"), "upgrade_used 不序列化")

func test_from_dict_resets_rest_upgrade():
	var r := _sample()
	r.rest_used = 3
	var r2 := RunState.from_dict(r.to_dict())
	assert_eq(r2.rest_used, 0, "反序列化重置 0")
