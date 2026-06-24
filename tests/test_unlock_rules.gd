extends GutTest

var pool: Array = ["tongshi_jinda","chifeng_lianci","chifeng_yajin","xueyi_xuedao","tingchao_yuanchao"]

func test_duel_returns_tier2():
	var r: Variant = UnlockRules.roll_unlock_reward(pool, "duel", {}, 7)
	assert_not_null(r)
	assert_eq(TechniqueData.tier_of(StringName(r)), 2, "决斗奖励是 T2")

func test_sparring_returns_faction_signature():
	var r: Variant = UnlockRules.roll_unlock_reward(pool, "sparring", {"faction":"F2"}, 7)
	assert_true(r == "chifeng_lianci" or r == "chifeng_yajin", "切磋给本派招牌招：%s" % str(r))

func test_visit_fixed_tech():
	var r: Variant = UnlockRules.roll_unlock_reward(pool, "visit", {"fixed_tech":"tingchao_yuanchao"}, 7)
	assert_eq(r, "tingchao_yuanchao", "拜访传招固定给")

func test_boss_returns_tier3():
	# 章 1 赫连铮 → 血衣·血祭（T3 固定掉落）
	var r: Variant = UnlockRules.roll_unlock_reward(pool, "boss", {"boss_id":"hailianzheng"}, 7)
	assert_eq(r, "xueyi_xuedao", "章 1 boss 掉血衣·血祭")
	assert_eq(TechniqueData.tier_of(StringName(r)), 3)

func test_empty_pool_returns_null():
	var r: Variant = UnlockRules.roll_unlock_reward([], "duel", {}, 7)
	assert_null(r, "池空给 null")
