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

# —— 招募同袍：多队友进 build（team0 多单位，不叠格）——

func test_build_two_player_units_no_grid_overlap():
	# roster=[主角[1,3], 队友[1,4]] → build 后 team0 两单位 grid_pos 不同
	var run := _run()
	run.player_roster.append(RunFactory._ally("F4", 1))
	var s := BattleBuilder.build(run, {"enemies":[]})
	var p: Array = s.units.filter(func(u): return u.team == 0)
	assert_eq(p.size(), 2, "team0 两单位（主角+队友）")
	assert_ne(p[0].grid_pos, p[1].grid_pos, "主角队友不叠格")

func test_build_ally_kit_resolved():
	# 队友 kit_ids=派系招牌 → 查表成功（kit.size>0，确认招牌 id 在 TechniqueDB）
	var run := _run()
	run.player_roster.append(RunFactory._ally("F1", 1))   # 镜照招牌
	var s := BattleBuilder.build(run, {"enemies":[]})
	var ally: UnitState = s.units.filter(func(u): return u.team == 0)[1]
	assert_eq(ally.kit.size(), 2, "队友 kit 含 2 招招牌（查表成功）")

# —— M4 T4: boss 单位 hp 按章缩放 + boss_traits 注入 ——

func _boss_run(chapter: int) -> RunState:
	var r := RunState.new()
	r.current_chapter = chapter
	r.player_roster = [{
		"id":"protagonist", "team":0, "hp":20, "max_hp":20, "opening":0, "max_opening":6,
		"stance":0, "grid_pos":[1,3], "facing":0, "guard_broken":false, "alive":true,
		"kit_ids":["tongshi_jinda"], "is_protagonist":true,
	}]
	return r

func test_boss_hp_scaled_by_chapter_difficulty():
	# 章3 难度曲线 ×1.3 + boss 强化 ×1.3 = hp_base × 1.69
	# zongzhenglie hp_base=45, 章3: 45×1.3(曲线)×1.3(强化)=76.05≈76
	var run := _boss_run(3)
	var s := BattleBuilder.build(run, {"boss_id":"zongzhenglie","node_type":"boss"})
	var boss: UnitState = s.units.filter(func(u): return u.team == 1)[0]
	assert_eq(boss.max_hp, 76, "章3 boss hp 难度曲线+强化 (45×1.3×1.3)")
	assert_eq(boss.hp, 76, "boss hp=max_hp（满血开场）")

func test_boss_hp_yanwujiu_ch4():
	# yanwujiu 章4: 65×1.45(曲线)×1.6(强化)=150.8≈151
	var run := _boss_run(4)
	var s := BattleBuilder.build(run, {"boss_id":"yanwujiu","node_type":"boss"})
	var boss: UnitState = s.units.filter(func(u): return u.team == 1)[0]
	assert_eq(boss.max_hp, 151, "章4 掌门 hp (65×1.45×1.6)")

func test_boss_hp_no_scale_ch1():
	# 章1 hailianzheng: 40×1.0(曲线)×1.0(强化)=40（章1/2 无 boss 强化）
	var run := _boss_run(1)
	var s := BattleBuilder.build(run, {"boss_id":"hailianzheng","node_type":"boss"})
	var boss: UnitState = s.units.filter(func(u): return u.team == 1)[0]
	assert_eq(boss.max_hp, 40, "章1 boss hp 无缩放")

func test_boss_traits_injected():
	var run := _boss_run(3)
	var s := BattleBuilder.build(run, {"boss_id":"zongzhenglie","node_type":"boss"})
	assert_eq(s.boss_traits.get("zongzhenglie", ""), "iron_body", "boss_traits 注入")

func test_boss_unit_boss_id_set():
	# boss 敌方单位 boss_id 标注（BossTrait._trait_of 读它）
	var run := _boss_run(4)
	var s := BattleBuilder.build(run, {"boss_id":"leiwanjun","node_type":"boss"})
	var boss: UnitState = s.units.filter(func(u): return u.team == 1)[0]
	assert_eq(boss.boss_id, "leiwanjun", "boss 单位 boss_id 标注")
	assert_eq(s.boss_traits.get("leiwanjun", ""), "frenzy", "leiwanjun trait=frenzy")

func test_boss_kit_resolved_from_config():
	# boss kit 来自 BossConfig（zongzhenglie: chifeng_lianci + chifeng_yajin）
	var run := _boss_run(3)
	var s := BattleBuilder.build(run, {"boss_id":"zongzhenglie","node_type":"boss"})
	var boss: UnitState = s.units.filter(func(u): return u.team == 1)[0]
	assert_eq(boss.kit.size(), 2, "boss kit 来自 BOSS_CONFIG (2 招)")

func test_boss_stance_personality_from_config():
	var run := _boss_run(3)
	var s := BattleBuilder.build(run, {"boss_id":"zongzhenglie","node_type":"boss"})
	var boss: UnitState = s.units.filter(func(u): return u.team == 1)[0]
	assert_eq(boss.stance, Stance.Id.METAL, "boss stance 来自 BOSS_CONFIG")

func test_no_boss_id_fallback_no_trait():
	# 边界守护：node_cfg 无 boss_id → 不触发 boss 逻辑，boss_traits 空（与 M0-M3 一致）
	var s := BattleBuilder.build(_boss_run(1), {"enemies":[]})
	assert_eq(s.boss_traits, {}, "无 boss_id → boss_traits 空")
