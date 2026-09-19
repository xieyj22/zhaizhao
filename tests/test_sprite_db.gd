extends GutTest

## Task B1: SpriteDB 映射链（纯字符串层；文件存在性走 B3 PIL 验收）。

func _u(p_id: String, p_faction: String, p_team: int, p_boss: String = "") -> UnitState:
	var u := UnitState.new()
	u.id = StringName(p_id); u.faction = p_faction; u.team = p_team; u.boss_id = p_boss
	return u

func test_priority_boss_over_faction():
	assert_eq(SpriteDB.path_for(_u("x", "F2", 1, "hailianzheng")),
		"res://assets/sprites/boss/hailianzheng.png")

func test_priority_hero_over_faction():
	assert_eq(SpriteDB.path_for(_u("protagonist", "F1", 0)),
		"res://assets/sprites/hero/protagonist.png")

func test_enemy_side_by_faction():
	assert_eq(SpriteDB.path_for(_u("e1", "F8", 1)), "res://assets/sprites/enemy/F8.png")

func test_ally_side_by_faction():
	assert_eq(SpriteDB.path_for(_u("ally_F2_0", "F2", 0)), "res://assets/sprites/ally/F2.png")

func test_unknown_returns_empty():
	assert_eq(SpriteDB.path_for(_u("e9", "", 1)), "", "无 faction 无 boss → 空串（渲染回退色块）")

func test_terrain_texture_paths():
	assert_eq(SpriteDB.TERRAIN_PATHS[TerrainRules.WATER], "res://assets/sprites/terrain/water.png")
	assert_eq(SpriteDB.TERRAIN_PATHS.size(), 5)

func test_completeness_tables():
	assert_eq(SpriteDB.BOSS_PATHS.size(), 8)
	for bid in ["hailianzheng","moqingniang","yanjiu","zongzhenglie","peiyuan","sikongyi","leiwanjun","yanwujiu"]:
		assert_true(SpriteDB.BOSS_PATHS.has(bid), "boss %s 缺表项" % bid)
	for f in FactionData.FACTIONS:
		assert_true(SpriteDB.ENEMY_PATHS.has(f) and SpriteDB.ALLY_PATHS.has(f), "%s 缺门派表项" % f)
