extends SceneTree

## M2 深度打磨：自动 playtest 入口。跑 AI vs AI 多局，打印平衡数据。
## 用法："$GODOT" --path "$PROJ" --headless -s res://src/playtest/battle_stats.gd
## 非 GUT 测试（不扫 tests/），是统计工具。

func _init() -> void:
	var tuning := Tuning.new()
	var n := 20   # 每组 seed 数
	var combos := [
		["brain vs brain", AIPersonality.brain(), AIPersonality.brain()],
		["brain vs brute", AIPersonality.brain(), AIPersonality.brute()],
		["brain vs trick", AIPersonality.brain(), AIPersonality.trick()],
		["brute vs brute", AIPersonality.brute(), AIPersonality.brute()],
		["brute vs trick", AIPersonality.brute(), AIPersonality.trick()],
		["trick vs trick", AIPersonality.trick(), AIPersonality.trick()],
	]
	print("\n=== M2 Playtest（%d 局/组，6 组合）===" % n)
	for c in combos:
		var cname: String = c[0]
		var p0: AIPersonality = c[1]
		var p1: AIPersonality = c[2]
		var stats := PlaytestHarness.run_series(p0, p1, tuning, n)
		print("\n[%s]" % cname)
		print("  胜率: team0 %.0f%% / team1 %.0f%% / 平 %.0f%%" % [
			100.0 * stats.team0_wins / stats.matches,
			100.0 * stats.team1_wins / stats.matches,
			100.0 * stats.draws / stats.matches])
		print("  回合: 均 %.1f / 中位 %d" % [stats.mean_turns(), stats.median_turns()])
		print("  读招命中率: %.0f%% (%d/%d)" % [100.0 * stats.read_hit_rate(), stats.read_hits, stats.read_attempts])
		print("  虚招: 出 %d | 上钩率 %.0f%% (%d lured/%d unmasked) | plain %d" % [
			stats.feints_thrown, 100.0 * stats.feint_lure_rate(),
			stats.feints_lured, stats.feints_unmasked, stats.feints_plain])
		print("  崩溃 %d / 致命 %d" % [stats.guard_breaks, stats.lethal_strikes])
	print("\n=== 平衡判据 ===")
	print("  平局率 >25%% = 战意没逼升温（调低 morale_cap_turn 或升伤害）")
	print("  读招命中率 >55%% = 开挂感（降 ai_w_predict 或 l2_confidence_cap）")
	print("  读招命中率 <30%% = L2 没用（升 ai_w_predict）")
	print("  虚招上钩率 <20%% = 诱饵太弱（升 feint_bonus_mult 或调 apparent 策略）")
	quit()
