extends GutTest

var t: Tuning
func before_each():
	t = Tuning.new()

func test_distance_manhattan():
	assert_eq(RangeBand.distance(Vector2i(0,0), Vector2i(3,4)), 7)
	assert_eq(RangeBand.distance(Vector2i(2,2), Vector2i(2,2)), 0)

func test_band_boundaries():
	assert_eq(RangeBand.band(0, t), RangeBand.Id.CLOSE)
	assert_eq(RangeBand.band(1, t), RangeBand.Id.CLOSE)   # ≤1
	assert_eq(RangeBand.band(2, t), RangeBand.Id.MID)
	assert_eq(RangeBand.band(3, t), RangeBand.Id.MID)     # ≤3
	assert_eq(RangeBand.band(4, t), RangeBand.Id.FAR)
	assert_eq(RangeBand.band(12, t), RangeBand.Id.FAR)

func test_in_range_close_only_adjacent():
	# required_range=CLOSE(0)：只能打邻格（距离≤1）
	assert_true(RangeBand.in_range(Vector2i(0,0), Vector2i(1,0), RangeBand.Id.CLOSE, t))
	assert_true(RangeBand.in_range(Vector2i(0,0), Vector2i(0,1), RangeBand.Id.CLOSE, t))
	assert_false(RangeBand.in_range(Vector2i(0,0), Vector2i(2,0), RangeBand.Id.CLOSE, t))

func test_in_range_far_hits_anything():
	# required_range=FAR(2)：近/中/远皆可
	assert_true(RangeBand.in_range(Vector2i(0,0), Vector2i(1,0), RangeBand.Id.FAR, t))
	assert_true(RangeBand.in_range(Vector2i(0,0), Vector2i(3,0), RangeBand.Id.FAR, t))
	assert_true(RangeBand.in_range(Vector2i(0,0), Vector2i(6,6), RangeBand.Id.FAR, t))
