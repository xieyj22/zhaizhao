extends GutTest

func test_generic_kit_uses_new_ids():
	assert_eq(TechniqueKit.strike_close().id, &"tongshi_jinda")
	assert_eq(TechniqueKit.strike_mid().id, &"tongshi_zhongda")
	assert_eq(TechniqueKit.strike_far().id, &"tongshi_yuanda")

func test_step_id_by_direction():
	assert_eq(TechniqueKit.step(1, 0).id, &"tongshi_jinbu", "+x 进步")
	assert_eq(TechniqueKit.step(-1, 0).id, &"tongshi_tuibu", "-x 退步")
	assert_eq(TechniqueKit.step(0, 1).id, &"tongshi_cebu_shang", "+y 侧步·上")
	assert_eq(TechniqueKit.step(0, -1).id, &"tongshi_cebu_xia", "-y 侧步·下")

func test_switch_id_by_stance():
	assert_eq(TechniqueKit.switch_to(Stance.Id.METAL).id, &"tongshi_zhuan_ruijin")
	assert_eq(TechniqueKit.switch_to(Stance.Id.WOOD).id, &"tongshi_zhuan_pangen")
	assert_eq(TechniqueKit.switch_to(Stance.Id.EARTH).id, &"tongshi_zhuan_houtu")
	assert_eq(TechniqueKit.switch_to(Stance.Id.WATER).id, &"tongshi_zhuan_liushui")
	assert_eq(TechniqueKit.switch_to(Stance.Id.FIRE).id, &"tongshi_zhuan_liehuo")

func test_feint_presets_new_ids():
	var ps := TechniqueKit.feint_presets()
	assert_eq(ps[0].id, &"tongshi_zhuangjin")
	assert_eq(ps[1].id, &"tongshi_zhuangshui")

func test_db_get_returns_technique():
	var t := TechniqueDB.find(&"chifeng_lianci")
	assert_not_null(t)
	assert_eq(t.display_name, "赤锋·连刺")
	assert_eq(t.type, Technique.Type.STRIKE)

func test_db_tier_filter():
	var pool := [&"tongshi_jinda", &"chifeng_lianci", &"xueyi_xuedao"]
	var t1 := TechniqueDB.tier_ids(pool, 1)
	assert_true(t1.has(&"tongshi_jinda"), "通式近打是 T1")
	var t2 := TechniqueDB.tier_ids(pool, 2)
	assert_true(t2.has(&"chifeng_lianci"), "赤锋连刺是 T2")
	assert_false(t2.has(&"tongshi_jinda"))

func test_data_count():
	# 14 通用 + 16 招牌 + 2 隐藏 = 32 实例
	assert_eq(TechniqueData.all_techniques().size(), 32, "14+16+2=32（通用14含4步法+5切势+3打击+2虚招预设；招牌16；隐藏2）")

func test_signature_numerics_match_spec():
	# T3 §3 authoritative values (guard against data drift)
	var lianci := TechniqueDB.find(&"chifeng_lianci")
	assert_eq(lianci.base_damage, 6); assert_eq(lianci.speed, 5); assert_eq(lianci.opening_dealt, 2)
	var yingzhao := TechniqueDB.find(&"jingzhao_yingzhao")
	assert_eq(yingzhao.speed, 7)
	var lagen := TechniqueDB.find(&"pangen_lagen")
	assert_eq(lagen.speed, 7)
	var liaoyuan := TechniqueDB.find(&"lieyan_liaoyuan")
	assert_eq(liaoyuan.base_damage, 7); assert_eq(liaoyuan.opening_dealt, 2)
	var huoqi := TechniqueDB.find(&"lieyan_huoqi")   # id corrected from lieyan_pokong
	assert_eq(huoqi.display_name, "烈焰·破空"); assert_eq(huoqi.speed, 6); assert_eq(huoqi.required_range, 2)
	var xuedao := TechniqueDB.find(&"xueyi_xuedao")
	assert_eq(xuedao.base_damage, 7); assert_eq(xuedao.speed, 5); assert_eq(xuedao.opening_dealt, 2)

func test_feint_signature_has_separate_apparent():
	var zhuangtu := TechniqueDB.find(&"huazong_zhuangtu")
	assert_eq(zhuangtu.resulting_stance, -1, "feint resulting=-1 保持")
	assert_eq(zhuangtu.apparent_stance, Stance.Id.EARTH, "apparent=厚土诱饵")
	assert_eq(zhuangtu.required_range, 2, "装土是 FAR")
	var zhuanghuo := TechniqueDB.find(&"huazong_zhuanghuo")
	assert_eq(zhuanghuo.base_damage, 5, "装火 real dmg 5")
	assert_eq(zhuanghuo.apparent_stance, Stance.Id.FIRE)
	var xz := TechniqueDB.find(&"xueyi_zhuangjin")
	assert_eq(xz.base_damage, 5); assert_eq(xz.apparent_stance, Stance.Id.METAL)

func test_move_signature_has_delta():
	var yajin := TechniqueDB.find(&"chifeng_yajin")
	assert_eq(yajin.move_delta, Vector2i(1, 0))
	var xieli := TechniqueDB.find(&"tingchao_xieli")
	assert_eq(xieli.move_delta, Vector2i(-1, 0))

func test_lieyan_pokong_gone():
	# 旧错误 id 不应存在
	assert_null(TechniqueDB.find(&"lieyan_pokong"))
