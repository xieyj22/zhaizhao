extends GutTest

func test_eight_bosses_present():
	# product §5.1：8 boss（赫连铮/莫青娘/晏九/宗政烈/裴渊/司空弈/雷万钧/颜无咎）
	var ids := BossConfig.BOSS_CONFIG.keys()
	assert_eq(ids.size(), 8)
	for bid in ["hailianzheng","moqingniang","yanjiu","zongzhenglie","peiyuan","sikongyi","leiwanjun","yanwujiu"]:
		assert_true(BossConfig.BOSS_CONFIG.has(bid), "%s 在表" % bid)

func test_boss_fields_complete():
	var b: Dictionary = BossConfig.BOSS_CONFIG["zongzhenglie"]
	for k in ["name","title","chapter","layer","personality","stance","hp_base","kit","trait"]:
		assert_true(b.has(k), "字段 %s" % k)
	assert_eq(b["chapter"], 3)
	assert_eq(b["layer"], 7)
	assert_eq(b["personality"], "brute")
	assert_eq(b["trait"], "iron_body")

func test_chapter_layer_layout_matches_design():
	# product §4.4 CHAPTER_BOSS_LAYOUT：章1[赫连铮@L7]/章2[莫青娘,晏九@L7]/章3[宗政烈,裴渊@L7]/章4[司空弈,雷万钧@L6,颜无咎@L7]
	assert_eq(BossConfig.boss_ids_for(2, 7).size(), 2)   # 莫青娘+晏九
	assert_eq(BossConfig.boss_ids_for(4, 6).size(), 2)   # 司空弈+雷万钧
	assert_eq(BossConfig.boss_ids_for(4, 7), ["yanwujiu"])  # 掌门固定
	assert_eq(BossConfig.boss_ids_for(1, 7), ["hailianzheng"])

func test_yanwujiu_hybrid():
	var b: Dictionary = BossConfig.BOSS_CONFIG["yanwujiu"]
	assert_eq(b["personality"], "brain_trick_hybrid")
	assert_eq(b["trait"], "blood_drain")
