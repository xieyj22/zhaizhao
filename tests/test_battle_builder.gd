extends GutTest

func _run() -> RunState:
	var r := RunState.new()
	r.unlocked_techniques = ["tongshi_jinda","tongshi_zhongda"]
	r.player_roster = [{
		"id":"protagonist", "team":0, "hp":20, "max_hp":20, "opening":0, "max_opening":6,
		"stance":0, "grid_pos":[1,3], "facing":0, "guard_broken":false, "alive":true,
		"display_name":"遗照", "faction_id":"F1", "personality_id":"brain",
		"kit_ids":["tongshi_jinda"], "is_protagonist":true,
	}]
	return r

func test_build_player_units_from_roster():
	var node_cfg: Dictionary = {"enemies":[
		{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,3],"stance":1,"kit":["chifeng_lianci","chifeng_yajin"]}
	]}
	var s := BattleBuilder.build(_run(), node_cfg)
	var p: Array = s.units.filter(func(u): return u.team == 0)
	var e: Array = s.units.filter(func(u): return u.team == 1)
	assert_eq(p.size(), 1, "玩家方=roster（主角）")
	assert_eq(e.size(), 1, "敌方=node_cfg")
	assert_eq(String(e[0].id), "e1")

func test_build_kits_resolved():
	# 主角 kit_ids → 实际 Technique 对象（查表）；kit 字段填充
	var s := BattleBuilder.build(_run(), {"enemies":[]})
	var u: UnitState = s.units[0]
	assert_eq(u.kit.size(), 1, "主角 kit 含 1 招（tongshi_jinda）")
	assert_eq(String(u.kit[0].id), "tongshi_jinda")

func test_build_variant_applied():
	# technique_variants 标记的招被强化（base_damage 比基础多 1）
	var run := _run()
	run.technique_variants = {"tongshi_jinda":"strong"}
	var s := BattleBuilder.build(run, {"enemies":[]})
	var u: UnitState = s.units[0]
	var base_tech = TechniqueDB.find(&"tongshi_jinda")
	assert_eq(u.kit[0].base_damage, base_tech.base_damage + 1, "variant strong → base_damage +1")

func test_build_injects_hazard():
	var node_cfg: Dictionary = {"enemies":[],"hazard":{"chaos":true}}
	var s := BattleBuilder.build(_run(), node_cfg)
	assert_eq(s.hazard_modifiers.get("chaos", false), true, "险地修饰符注入 BattleState")

func test_build_no_hazard_default():
	var s := BattleBuilder.build(_run(), {"enemies":[]})
	assert_eq(s.hazard_modifiers, {}, "非险地节点无修饰符")

# —— M3.5 BB2: modifier 注入 + enemy_pool ——

func test_kit_stance_damage_bonus_applied():
	# 锐金当令：METAL 招 base_damage +1（tongshi_jinda 是 METAL resulting_stance）
	var run := _run()
	run.modifier_state = {"kit_stance_damage_bonus":{"METAL":1}}
	var s := BattleBuilder.build(run, {"enemies":[]})
	var u: UnitState = s.units[0]
	var base = TechniqueDB.find(&"tongshi_jinda")
	var applied: Array = u.kit.filter(func(t): return String(t.id) == "tongshi_jinda")
	assert_true(applied.size() > 0, "主角 kit 含 tongshi_jinda")
	assert_eq(applied[0].base_damage, base.base_damage + 1, "METAL kit base_damage +1")

func test_hazard_baseline_injected():
	var run := _run()
	run.modifier_state = {"hazard_baseline":{"chaos":true}}
	var s := BattleBuilder.build(run, {"enemies":[]})
	assert_eq(s.hazard_modifiers.get("chaos", false), true, "hazard_baseline chaos 注入")

func test_empty_modifier_state_unchanged():
	# 边界守护：空 modifier_state → kit/hazard 与 M3 一致
	var run := _run()   # modifier_state 默认 {}
	var s := BattleBuilder.build(run, {"enemies":[]})
	assert_eq(s.hazard_modifiers, {}, "空 modifier → 无 hazard")
	var u: UnitState = s.units[0]
	for t in u.kit:
		var base = TechniqueDB.find(StringName(t.id))
		assert_eq(t.base_damage, base.base_damage, "%s base_damage 未被改" % String(t.id))

func test_enemy_pool_used_when_no_node_enemies():
	# node_cfg 无 enemies 但有 node_type → battle_builder 从 enemy_pool.pick 抽
	var run := _run()
	var s := BattleBuilder.build(run, {"node_type":"duel","risk":0})
	var e: Array = s.units.filter(func(u): return u.team == 1)
	assert_true(e.size() >= 1, "无 node enemies 时从 enemy_pool 抽")
