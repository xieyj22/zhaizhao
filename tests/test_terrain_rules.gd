extends GutTest

## Task A1: 地形数据层（TerrainRules 纯函数 + UnitState.faction + BattleState.terrain 序列化）。

func test_rules_empty_terrain_all_bypass():
	var t: Dictionary = {}
	assert_false(TerrainRules.blocks_move(t, Vector2i(3, 3)))
	assert_false(TerrainRules.is_water(t, Vector2i(3, 3)))
	assert_false(TerrainRules.is_highland(t, Vector2i(3, 3)))
	assert_false(TerrainRules.is_hazard(t, Vector2i(3, 3)))
	assert_eq(TerrainRules.speed_delta(t, Vector2i(3, 3)), 0)

func test_rules_each_type():
	var t := {"3,3": TerrainRules.OBSTACLE, "2,2": TerrainRules.WATER, "1,1": TerrainRules.HIGHLAND, "0,0": TerrainRules.HAZARD}
	assert_true(TerrainRules.blocks_move(t, Vector2i(3, 3)))
	assert_false(TerrainRules.blocks_move(t, Vector2i(2, 2)), "只有障碍阻挡移动")
	assert_true(TerrainRules.is_water(t, Vector2i(2, 2)))
	assert_eq(TerrainRules.speed_delta(t, Vector2i(2, 2)), -1)
	assert_true(TerrainRules.is_highland(t, Vector2i(1, 1)))
	assert_eq(TerrainRules.speed_delta(t, Vector2i(1, 1)), 0)
	assert_true(TerrainRules.is_hazard(t, Vector2i(0, 0)))

func test_rules_key():
	assert_eq(TerrainRules.key(4, 2), "4,2")

func test_unit_state_faction():
	var u := UnitState.new()
	assert_eq(u.faction, "", "默认空")
	assert_false(u.to_dict().has("faction"), "faction 不入 to_dict")
	var u2 := UnitState.from_dict({"id": "x", "team": 0, "hp": 5, "max_hp": 5, "opening": 0,
		"max_opening": 6, "stance": 0, "grid_pos": [1, 1], "facing": 0, "faction": "F8"})
	assert_eq(u2.faction, "F8", "from_dict 容错读 faction")

func test_battle_state_terrain_roundtrip():
	var s := BattleState.new()
	s.units = []
	s.terrain = {"3,3": TerrainRules.WATER}
	var s2 := BattleState.from_dict(s.to_dict())
	assert_eq(JSON.stringify(s2.terrain), JSON.stringify({"3,3": "water"}))

func test_battle_state_terrain_old_save_compat():
	var s := BattleState.new()
	s.units = []
	var d := s.to_dict()
	d.erase("terrain")
	var s2 := BattleState.from_dict(d)
	assert_eq(s2.terrain.size(), 0, "旧档无 terrain 键 → 默认空")

func test_builder_fills_faction():
	var r := RunState.new()
	r.unlocked_techniques = ["jingzhao_chuzhao"]
	r.player_roster = [{"id":"protagonist","team":0,"hp":20,"max_hp":20,"opening":0,"max_opening":6,
		"stance":0,"grid_pos":[1,3],"facing":0,"guard_broken":false,"alive":true,
		"display_name":"遗照","faction_id":"F1","personality_id":"brain",
		"kit_ids":["jingzhao_chuzhao"],"is_protagonist":true}]
	var s := BattleBuilder.build(r, {"enemies":[{"id":"e1","faction":"F2","personality":"brute",
		"grid_pos":[5,3],"stance":1,"kit":["chifeng_lianci"]}]})
	var p: UnitState = s.units[0]
	var e: UnitState = s.units[1]
	assert_eq(p.faction, "F1", "roster faction_id → faction")
	assert_eq(e.faction, "F2", "enemy faction → faction")
