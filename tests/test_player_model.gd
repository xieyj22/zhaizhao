extends GutTest

var t: Tuning
func before_each():
	t = Tuning.new()

func _unit(id, team, pos, stance, opening := 0) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20; u.opening = opening
	return u

func _state(units: Array, turn := 0) -> BattleState:
	var s := BattleState.new()
	s.units = units; s.turn = turn
	return s

func test_predict_cold_start_uniform():
	var pm := PlayerModel.new()
	var p := pm.predict("0|0|0|-1|0")
	assert_eq(p.size(), 4)
	for v in p.values():
		assert_between(v, 0.249, 0.251)

func test_observe_accumulates_and_skews():
	var pm := PlayerModel.new()
	var key := "0|0|0|-1|0"
	pm.observe(key, Technique.Type.STRIKE, "p0")
	pm.observe(key, Technique.Type.STRIKE, "p0")
	pm.observe(key, Technique.Type.STRIKE, "p1")
	var p := pm.predict(key)
	var best := 0.0
	for v in p.values(): best = max(best, v)
	assert_eq(best, p[Technique.Type.STRIKE])
	assert_gt(p[Technique.Type.STRIKE], p[Technique.Type.MOVE])

func test_confidence_cold_start_zero_below_min_samples():
	var pm := PlayerModel.new()
	var key := "0|0|0|-1|0"
	assert_eq(pm.confidence(key, t), 0.0, "空表 → 0")
	pm.observe(key, Technique.Type.STRIKE, "p0")
	assert_eq(pm.confidence(key, t), 0.0)

func test_confidence_capped():
	var pm := PlayerModel.new()
	var key := "0|0|0|-1|0"
	for i in 20:
		pm.observe(key, Technique.Type.STRIKE, "p0")
	var c := pm.confidence(key, t)
	assert_lte(c, t.l2_confidence_cap, "置信度封顶")
	assert_gt(c, 0.0)

func test_argmax_type_returns_predicted():
	var pm := PlayerModel.new()
	var key := "0|0|0|-1|0"
	for i in 5: pm.observe(key, Technique.Type.STRIKE, "p0")
	assert_eq(pm.argmax_type(key), Technique.Type.STRIKE)

func test_featurize_encodes_five_segments():
	var pm := PlayerModel.new()
	var e := _unit(&"e", 1, Vector2i(2,2), Stance.Id.EARTH, 0)
	var foe := _unit(&"f", 0, Vector2i(3,2), Stance.Id.METAL)
	var s := _state([e, foe], 6)
	var key := pm.featurize(e, s, t)
	# role=NEUTRAL=2 | band=CLOSE=0 | phase=ACTIVE=1 | last=-1 | opening=LOW=0
	assert_eq(key, "2|0|1|-1|0")

func test_featurize_tracks_last_type():
	var pm := PlayerModel.new()
	var e := _unit(&"e", 1, Vector2i(2,2), Stance.Id.EARTH, 0)
	var foe := _unit(&"f", 0, Vector2i(3,2), Stance.Id.METAL)
	var s := _state([e, foe], 6)
	var k1 := pm.featurize(e, s, t)
	pm.observe(k1, Technique.Type.MOVE, String(e.id))
	var k2 := pm.featurize(e, s, t)
	assert_ne(k1, k2)
	assert_true(k2.ends_with("|%d|0" % Technique.Type.MOVE))

func test_roundtrip_json_safe():
	var pm := PlayerModel.new()
	pm.observe("0|0|0|-1|0", Technique.Type.STRIKE, "p0")
	pm.observe("1|1|0|-1|0", Technique.Type.MOVE, "p1")
	var d := pm.to_dict()
	var s := JSON.stringify(d)
	var pm2 := PlayerModel.from_dict(JSON.parse_string(s))
	assert_eq(pm2.total, pm.total)
	var k := "0|0|0|-1|0"
	assert_eq(pm2.predict(k)[Technique.Type.STRIKE], pm.predict(k)[Technique.Type.STRIKE])
