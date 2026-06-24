extends GutTest

func test_can_recruit_threshold():
	var r: Dictionary = {"F4":40,"F2":20,"F8":-100}
	assert_true(FactionRelations.can_recruit(r, "F4"), "F4=40≥30 可招")
	assert_false(FactionRelations.can_recruit(r, "F2"), "F2=20<30 不可招")
	assert_false(FactionRelations.can_recruit(r, "F8"), "血衣不可招")

func test_clamp_range():
	assert_eq(FactionRelations.clamp(150), 100)
	assert_eq(FactionRelations.clamp(-150), -100)
	assert_eq(FactionRelations.clamp(30), 30)

func test_defection_only_grey_area_negative():
	var r: Dictionary = {"F6":-50,"F2":-50}
	assert_gt(FactionRelations.defection_chance(r, "F6"), 0.0, "灰区派 F6<0 有倒戈概率")
	assert_eq(FactionRelations.defection_chance(r, "F2"), 0.0, "非灰区派 F2 即使<0 不倒戈")
	assert_eq(FactionRelations.defection_chance({"F6":30}, "F6"), 0.0, "灰区派 F6≥0 不倒戈")
