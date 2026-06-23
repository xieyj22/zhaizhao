extends GutTest

## 诊断 harness：确认单局/小 series 能快速完成（非平衡断言，是性能/逻辑诊断）。
func test_run_one_match_completes():
	var tuning := Tuning.new()
	var r := PlaytestHarness.run_match(AIPersonality.brain(), AIPersonality.brute(), tuning, 42)
	assert_true(r.turns > 0 and r.turns <= 30, "单局在 30 回合内结束")
	assert_ne(r.outcome, BattleState.Outcome.ONGOING, "单局有合法 outcome")
	gut.p("1局: turns=%d outcome=%d reads=%d/%d feints=%d lured=%d" % [r.turns, r.outcome, r.read_hits, r.read_attempts, r.feints_thrown, r.feints_lured])

func test_run_series_small():
	var tuning := Tuning.new()
	var stats := PlaytestHarness.run_series(AIPersonality.brain(), AIPersonality.trick(), tuning, 3)
	assert_eq(stats.matches, 3)
	gut.p("brain vs trick(3局): team0=%d team1=%d draw=%d read%%=%.0f feints=%d" % [stats.team0_wins, stats.team1_wins, stats.draws, 100.0 * stats.read_hit_rate(), stats.feints_thrown])
