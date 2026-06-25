extends GutTest

## BossTrait 5 机制 + 边界守护（M0-M2 noop）测试。

func _state_with_trait(boss_id: String, trait_name: String) -> BattleState:
	var s := BattleState.new()
	s.boss_traits = {boss_id: trait_name} if trait_name != "" else {}
	return s

func _boss(boss_id: String) -> UnitState:
	var u := UnitState.new()
	u.id = StringName(boss_id)
	u.boss_id = boss_id
	return u

# ====== opening_delta ======

func test_opening_delta_iron_body():
	var s := _state_with_trait("zongzhenglie", "iron_body")
	assert_eq(BossTrait.opening_delta(s, _boss("zongzhenglie"), 3), 2, "iron_body 受破绽 -1")
	assert_eq(BossTrait.opening_delta(s, _boss("zongzhenglie"), 0), 0, "min 0")
	assert_eq(BossTrait.opening_delta(s, _boss("zongzhenglie"), 1), 0, "1→0")

func test_opening_delta_noop_without_trait():
	var s := _state_with_trait("", "")   # 空 boss_traits
	assert_eq(BossTrait.opening_delta(s, _boss("x"), 3), 3, "无 trait 原值")
	assert_eq(BossTrait.opening_delta(s, _boss("x"), 0), 0, "0 不变")

func test_opening_delta_other_trait_passthrough():
	# 非 iron_body 的 trait 也透传（opening_delta 只对 iron_body 生效）
	var s := _state_with_trait("p", "frenzy")
	assert_eq(BossTrait.opening_delta(s, _boss("p"), 4), 4, "frenzy 不改 opening_delta")

func test_opening_delta_null_unit_noop():
	var s := _state_with_trait("p", "iron_body")
	assert_eq(BossTrait.opening_delta(s, null, 3), 3, "null unit → noop")

func test_opening_delta_unit_no_boss_id_noop():
	# unit.boss_id == ""（非 boss 单位）→ boss_traits 不命中
	var s := _state_with_trait("zzl", "iron_body")
	var u := _boss("zzl")
	u.boss_id = ""   # 普通敌兵
	assert_eq(BossTrait.opening_delta(s, u, 3), 3, "无 boss_id → 原值")

# ====== feint_mult ======

func test_feint_mult_chain_feint():
	var s := _state_with_trait("peiyuan", "chain_feint")
	# chain_feint：落空→1.0（不受 0.7 fail）；上钩→bonus+0.5
	assert_eq(BossTrait.feint_mult(s, _boss("peiyuan"), false, 0.7, 1.5), 1.0, "落空→1.0")
	assert_eq(BossTrait.feint_mult(s, _boss("peiyuan"), true, 0.7, 1.5), 2.0, "上钩→bonus+0.5")

func test_feint_mult_default_no_trait():
	var s := _state_with_trait("", "")
	# 无 trait = 原行为：上钩 bonus_mult / 落空 fail_mult
	assert_eq(BossTrait.feint_mult(s, _boss("x"), true, 0.7, 1.5), 1.5, "无 trait 上钩=bonus")
	assert_eq(BossTrait.feint_mult(s, _boss("x"), false, 0.7, 1.5), 0.7, "无 trait 落空=fail")

func test_feint_mult_other_trait_passthrough():
	var s := _state_with_trait("p", "mind_eye")
	assert_eq(BossTrait.feint_mult(s, _boss("p"), true, 0.7, 1.5), 1.5, "非 chain_feint 上钩=bonus")
	assert_eq(BossTrait.feint_mult(s, _boss("p"), false, 0.7, 1.5), 0.7, "非 chain_feint 落空=fail")

# ====== predict_confidence ======

func test_predict_confidence_mind_eye():
	var s := _state_with_trait("sikongyi", "mind_eye")
	assert_eq(BossTrait.predict_confidence(s, _boss("sikongyi"), 0.3), 1.0, "mind_eye cap=1.0")
	assert_eq(BossTrait.predict_confidence(s, _boss("sikongyi"), 0.0), 1.0, "mind_eye 即便 base=0 也 1.0")

func test_predict_confidence_no_trait():
	var s := _state_with_trait("", "")
	assert_eq(BossTrait.predict_confidence(s, _boss("x"), 0.3), 0.3, "无 trait 原 base")
	assert_eq(BossTrait.predict_confidence(s, _boss("x"), 0.0), 0.0, "无 trait base=0 透传")

func test_predict_confidence_other_trait_passthrough():
	var s := _state_with_trait("p", "frenzy")
	assert_eq(BossTrait.predict_confidence(s, _boss("p"), 0.4), 0.4, "非 mind_eye 透传 base")

# ====== on_end_turn ======

func _battle_with_frenzy_boss() -> BattleState:
	# hp<50% → 触发 frenzied
	var s := _state_with_trait("b", "frenzy")
	var u := _boss("b")
	u.hp = 3
	u.max_hp = 10
	u.alive = true
	s.units = [u]
	return s

func test_on_end_turn_frenzy_triggers_below_half():
	var s := _battle_with_frenzy_boss()
	BossTrait.on_end_turn(s, {})
	assert_true(s.units[0].frenzied, "hp<50% → frenzied=true")

func test_on_end_turn_frenzy_no_trigger_above_half():
	var s := _state_with_trait("b", "frenzy")
	var u := _boss("b")
	u.hp = 6; u.max_hp = 10; u.alive = true
	s.units = [u]
	BossTrait.on_end_turn(s, {})
	assert_false(s.units[0].frenzied, "hp>=50% → 不触发")

func test_on_end_turn_frenzy_no_trait_stays_false():
	var s := _state_with_trait("", "")
	var u := _boss("b")
	u.hp = 1; u.max_hp = 10; u.alive = true
	s.units = [u]
	BossTrait.on_end_turn(s, {})
	assert_false(s.units[0].frenzied, "无 trait → 不触发")

func test_on_end_turn_blood_drain():
	var s := _state_with_trait("b", "blood_drain")
	var u := _boss("b")
	u.hp = 5; u.max_hp = 20; u.alive = true
	s.units = [u]
	# 玩家方本回合受损 10 → 吸 30% = 3
	BossTrait.on_end_turn(s, {"player1": 10})
	assert_eq(s.units[0].hp, 8, "blood_drain 吸 10*0.3=3")

func test_on_end_turn_blood_drain_capped_at_max():
	var s := _state_with_trait("b", "blood_drain")
	var u := _boss("b")
	u.hp = 18; u.max_hp = 20; u.alive = true
	s.units = [u]
	# 吸 6 但只到 max_hp=20 → +2
	BossTrait.on_end_turn(s, {"player1": 20})
	assert_eq(s.units[0].hp, 20, "blood_drain 封顶 max_hp")

func test_on_end_turn_blood_drain_dead_unit_skip():
	var s := _state_with_trait("b", "blood_drain")
	var u := _boss("b")
	u.hp = 0; u.max_hp = 20; u.alive = false
	s.units = [u]
	BossTrait.on_end_turn(s, {"player1": 20})
	assert_eq(s.units[0].hp, 0, "死亡 unit 不吸血")

func test_on_end_turn_no_trait_no_change():
	var s := _state_with_trait("", "")
	var u := _boss("b")
	u.hp = 5; u.max_hp = 20; u.alive = true
	s.units = [u]
	BossTrait.on_end_turn(s, {"player1": 100})
	assert_eq(s.units[0].hp, 5, "无 trait → hp 不变")

# ====== 边界守护：空 boss_traits 字段扩展不破坏 M0-M2 ======

func test_battle_state_has_boss_traits_default_empty():
	var s := BattleState.new()
	assert_eq(s.boss_traits, {}, "boss_traits 默认空 dict")

func test_unit_state_has_frenzied_boss_id_defaults():
	var u := UnitState.new()
	assert_false(u.frenzied, "frenzied 默认 false")
	assert_eq(u.boss_id, "", "boss_id 默认空串")

func test_unit_state_from_dict_missing_keys_compat():
	# 旧 dict（无 frenzied/boss_id）应能 from_dict 不报错
	var d := {
		"id": "u1", "team": 0, "hp": 10, "max_hp": 10,
		"opening": 0, "max_opening": 6, "stance": 0,
		"grid_pos": [0, 0], "facing": 0, "guard_broken": false, "alive": true,
	}
	var u := UnitState.from_dict(d)
	assert_eq(u.frenzied, false, "from_dict 旧数据 frenzied=false")
	assert_eq(u.boss_id, "", "from_dict 旧数据 boss_id=''")

func test_battle_state_roundtrip_preserves_boss_traits():
	var s := BattleState.new()
	s.boss_traits = {"zzl": "iron_body"}
	var d := s.to_dict()
	var s2 := BattleState.from_dict(d)
	assert_eq(s2.boss_traits, {"zzl": "iron_body"}, "to/from_dict 保 boss_traits")

func test_unit_state_roundtrip_preserves_frenzied_boss_id():
	var u := UnitState.new()
	u.frenzied = true
	u.boss_id = "zzl"
	var d := u.to_dict()
	var u2 := UnitState.from_dict(d)
	assert_true(u2.frenzied, "roundtrip frenzied")
	assert_eq(u2.boss_id, "zzl", "roundtrip boss_id")

# ====== mind_eye 反制伤（resolver 后处理接入验证）======
# 注：mind_eye 反制伤为 -2 hp，由 turn_orchestrator.reveal_and_resolve 后处理触发；
# 集成测见 test_turn_orchestrator（若已加），这里只验 BossTrait 纯函数本身。

# 边界守护（M0-M2 全套逐字节绿）由全量 GUT 覆盖——本文件只验 BossTrait 本身。
