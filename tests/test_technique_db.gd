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
