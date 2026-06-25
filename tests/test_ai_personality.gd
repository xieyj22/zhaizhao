extends GutTest

func test_brain_uses_l2():
	var p := AIPersonality.brain()
	assert_gt(p.w_predict_mul, 1.0, "智将放大 L2")
	assert_lte(p.feint_rate, 0.2, "智将少主动虚招")
	assert_gt(p.display_name.length(), 0)

func test_brute_ignores_l2():
	var p := AIPersonality.brute()
	assert_lte(p.w_predict_mul, 0.1, "莽将基本忽略 L2")
	assert_gt(p.aggression, 1.0, "莽将高侵略")
	assert_gt(p.top_n_mul, 1.0, "莽将更随机(冒险)")

func test_trick_feints():
	var p := AIPersonality.trick()
	assert_gt(p.feint_rate, 0.5, "诡将高虚招率")
	assert_gt(p.w_predict_mul, 0.0)

func test_brain_trick_hybrid_weights():
	var p := AIPersonality.brain_trick_hybrid()
	assert_eq(p.display_name, "智诡合一")
	assert_eq(p.w_predict_mul, 2.0, "brain 的读招")
	assert_eq(p.feint_rate, 0.7, "trick 的虚招")
	assert_eq(p.aggression, 1.2)
	assert_eq(p.caution, 1.0)
	assert_eq(p.top_n_mul, 1.1)

func test_defaults_present():
	var p := AIPersonality.new()
	assert_eq(p.w_predict_mul, 1.0)
	assert_eq(p.feint_rate, 0.0)
	assert_eq(p.aggression, 1.0)
	assert_eq(p.caution, 1.0)
	assert_eq(p.top_n_mul, 1.0)

# —— T6 review fix: boss 性格查 BOSS_CONFIG（端到端：battle.gd::_personality_for）——
# battle.gd 是 scene 脚本无 class_name，用 load(...).static 调。
# 覆盖 8 boss：颜无咎→hybrid, 莫青娘→trick, 晏九→brain, 裴渊→trick, 司空弈→brain,
# 赫连铮/宗政烈/雷万钧→brute。
func test_personality_for_boss_from_config():
	var BattleScene = load("res://src/scenes/battle/battle.gd")
	# 颜无咎（掌门）→ hybrid
	var yw: AIPersonality = BattleScene._personality_for({"boss_id":"yanwujiu"})
	assert_eq(yw.display_name, "智诡合一", "颜无咎 hybrid")
	assert_eq(yw.feint_rate, 0.7, "颜无咎 hybrid feint_rate")
	assert_eq(yw.w_predict_mul, 2.0, "颜无咎 hybrid w_predict")
	# 莫青娘 → trick（feint_rate 0.7，w_predict 1.2）
	var mq: AIPersonality = BattleScene._personality_for({"boss_id":"moqingniang"})
	assert_eq(mq.display_name, "诡将", "莫青娘 trick")
	assert_eq(mq.feint_rate, 0.7, "莫青娘 trick feint_rate")
	assert_eq(mq.w_predict_mul, 1.2, "莫青娘 trick w_predict")
	# 裴渊 → trick
	var py: AIPersonality = BattleScene._personality_for({"boss_id":"peiyuan"})
	assert_eq(py.display_name, "诡将", "裴渊 trick")
	# 晏九 → brain（w_predict 2.0，feint 0.1）
	var yj: AIPersonality = BattleScene._personality_for({"boss_id":"yanjiu"})
	assert_eq(yj.display_name, "智将", "晏九 brain")
	assert_eq(yj.w_predict_mul, 2.0, "晏九 brain w_predict")
	assert_eq(yj.feint_rate, 0.1, "晏九 brain feint_rate")
	# 司空弈 → brain
	var sy: AIPersonality = BattleScene._personality_for({"boss_id":"sikongyi"})
	assert_eq(sy.display_name, "智将", "司空弈 brain")
	# 赫连铮 → brute（w_predict 0，aggression 1.8）
	var hl: AIPersonality = BattleScene._personality_for({"boss_id":"hailianzheng"})
	assert_eq(hl.display_name, "莽将", "赫连铮 brute")
	assert_eq(hl.w_predict_mul, 0.0, "赫连铮 brute w_predict")
	assert_eq(hl.aggression, 1.8, "赫连铮 brute aggression")
	# 宗政烈 → brute
	var zz: AIPersonality = BattleScene._personality_for({"boss_id":"zongzhenglie"})
	assert_eq(zz.display_name, "莽将", "宗政烈 brute")
	# 雷万钧 → brute
	var lw: AIPersonality = BattleScene._personality_for({"boss_id":"leiwanjun"})
	assert_eq(lw.display_name, "莽将", "雷万钧 brute")

func test_personality_for_non_boss_uses_personality_field():
	# 非 boss：按 node_cfg.personality 字段（默认 brain）
	var BattleScene = load("res://src/scenes/battle/battle.gd")
	assert_eq(BattleScene._personality_for({}).display_name, "智将", "无 personality 默认 brain")
	assert_eq(BattleScene._personality_for({"personality":"trick"}).display_name, "诡将", "node_cfg trick")
	assert_eq(BattleScene._personality_for({"personality":"brute"}).display_name, "莽将", "node_cfg brute")
	assert_eq(BattleScene._personality_for({"personality":"brain_trick_hybrid"}).display_name, "智诡合一", "node_cfg hybrid")
