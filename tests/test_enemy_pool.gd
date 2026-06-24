extends GutTest

func test_get_deterministic():
	var a: Dictionary = EnemyPool.pick("duel", 0, 7)
	var b: Dictionary = EnemyPool.pick("duel", 0, 7)
	assert_eq(JSON.stringify(a), JSON.stringify(b), "同输入同组合")

func test_get_filters_by_node_affinity():
	var cfg: Dictionary = EnemyPool.pick("duel", 0, 7)
	assert_true((cfg["affinity"] as Array).has("duel"), "duel 节点给 duel 倾向组合")

func test_boss_fixed():
	var cfg: Dictionary = EnemyPool.pick("boss", 0, 7)
	assert_eq(cfg["id"], "hailianzheng", "boss 固定赫连铮")

func test_pool_has_seven():
	assert_eq(EnemyPool.get_pool().size(), 7, "章 1 敌人池 7 组合")

func test_get_returns_enemies_array():
	var cfg: Dictionary = EnemyPool.pick("duel", 0, 7)
	assert_true((cfg["enemies"] as Array).size() >= 1, "组合含 ≥1 敌人单位")
	var e: Dictionary = cfg["enemies"][0]
	assert_true(e.has("faction") and e.has("kit") and e.has("grid_pos"))
