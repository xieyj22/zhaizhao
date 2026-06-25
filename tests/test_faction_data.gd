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

# —— 招募同袍（PLAYER_SLOTS / FACTION_STANCE / ALLY_GIVEN_NAMES）——

func test_player_slots_zero_is_protagonist_pos():
	# slot[0] 必须与主角固定 grid_pos [1,3] 对齐（数据自洽守护）
	assert_eq(FactionData.PLAYER_SLOTS[0], [1,3], "slot[0] 对齐主角站位")

func test_player_slots_distinct():
	# 玩家方站位槽两两不重叠（避免招募顺序错位致叠格）
	var seen: Dictionary = {}
	for slot in FactionData.PLAYER_SLOTS:
		var key := "%d,%d" % [slot[0], slot[1]]
		assert_false(seen.has(key), "PLAYER_SLOTS 无重复格 %s" % str(slot))
		seen[key] = true

func test_player_slots_within_left_half():
	# 7×7 棋盘，玩家方占左半区 x∈[0,2]，y∈[0,6]（不越界）
	for slot in FactionData.PLAYER_SLOTS:
		assert_true(slot[0] >= 0 and slot[0] <= 2, "x 在左半区 %s" % str(slot))
		assert_true(slot[1] >= 0 and slot[1] <= 6, "y 在棋盘内 %s" % str(slot))

func test_stance_for_all_factions():
	# 8 派都有架势映射，且值为合法 Stance.Id
	assert_eq(FactionData.stance_for("F1"), Stance.Id.METAL, "镜照锐金攻势")
	assert_eq(FactionData.stance_for("F2"), Stance.Id.FIRE, "赤锋烈火攻势")
	assert_eq(FactionData.stance_for("F4"), Stance.Id.WATER, "听潮柔水守势")
	assert_eq(FactionData.stance_for("F8"), Stance.Id.FIRE, "血衣烈火")
	# 全派映射存在
	for fid in FactionData.FACTIONS:
		assert_true(FactionData.FACTION_STANCE.has(fid), "%s 有架势映射" % fid)
	# 兜底
	assert_eq(FactionData.stance_for("FX"), Stance.Id.METAL, "未知派兜底 METAL")

func test_ally_given_names_all_recruit_factions():
	# 每个可招募派都有队友名（F8 不可招无需）
	for fid in FactionData.recruit_factions():
		assert_true(FactionData.ALLY_GIVEN_NAMES.has(fid), "%s 有队友名" % fid)
