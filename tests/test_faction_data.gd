extends GutTest

func test_eight_factions():
	assert_eq(FactionData.FACTIONS.size(), 8)
	assert_true(FactionData.FACTIONS.has("F1"))

func test_initial_relations():
	var r := FactionData.initial_relations()
	assert_eq(r["F1"], 0, "镜照起点中性")
	assert_eq(r["F4"], 40, "听潮暗盟 +40（主角=F1 视角）")
	assert_eq(r["F8"], -100, "血衣死敌 -100 锁死")
	assert_eq(r["F6"], 0, "灰区派幻踪起点 0")

func test_bloodfrost_locked():
	assert_false(FactionData.recruit_factions().has("F8"))
	assert_true(FactionData.recruit_factions().has("F1"))

func test_faction_personality_tendency():
	assert_eq(FactionData.tendency("F2"), "brute", "赤锋军门 brute")
	assert_eq(FactionData.tendency("F4"), "brain", "听潮书院 brain")
	assert_eq(FactionData.tendency("F6"), "trick", "幻踪门 trick")

func test_all_tendencies_match_design_doc():
	# docs/design/02-factions.md §性格映射 self-check (lines 258-262)
	assert_eq(FactionData.tendency("F1"), "brain")
	assert_eq(FactionData.tendency("F2"), "brute")
	assert_eq(FactionData.tendency("F3"), "brain")
	assert_eq(FactionData.tendency("F4"), "brain")
	assert_eq(FactionData.tendency("F5"), "brute")
	assert_eq(FactionData.tendency("F6"), "trick")
	assert_eq(FactionData.tendency("F7"), "trick", "夜枭镖局 = trick（老油条诡，非 brain）")
	# F8 血衣教 = 混合（M3+ 扩展）；tendency() 简化为 brute（七高手 brute/brain/trick 分脑，M3 取主战 brute）
	assert_eq(FactionData.tendency("F8"), "brute")
