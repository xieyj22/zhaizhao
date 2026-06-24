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
