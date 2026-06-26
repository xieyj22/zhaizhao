extends SceneTree

## T10f 调平专用快速扫描器：只跑 brain 性格，2 seed 范围各 30。
## 比 balance_probe.gd（4×3×30=360 局）快 6 倍，够看趋势。
## 用法：
##   "$GODOT" --path "$PROJ" --headless -s res://src/playtest/tune_scan.gd

const SEEDS_PER_RANGE := 30
const SEED_SPACING := 13
const SEED_BASES := [100, 1000]
const PERSONALITIES := ["brain"]   # 调平聚焦 brain（目标 15-40%）

func _init() -> void:
	var meta := MetaState.new_first_play()
	print("\n=== T10f 调平快速扫描（brain, 2 range × 30）===")
	var rows := []
	for base in SEED_BASES:
		for pname in PERSONALITIES:
			var pers := _personality(pname)
			var cell := _run_cell(meta, base, pers)
			cell["range"] = str(base)
			cell["persona"] = pname
			rows.append(cell)
			print("[r=%s p=%s] clear%%=%.0f%% dead%%=%.0f%% draw%%=%.0f%% stall%%=%.0f%% | ch:1=%d 2=%d 3=%d 4=%d" %
				[base, pname, cell.clear_pct, cell.death_pct, cell.draw_pct, cell.stall_pct,
				 cell.ch_hist[1], cell.ch_hist[2], cell.ch_hist[3], cell.ch_hist[4]])
	# 汇总 brain 平均
	var total_clear := 0
	var total_dead := 0
	var total_n := 0
	for r in rows:
		total_clear += r.cleared
		total_dead += r.dead
		total_n += SEEDS_PER_RANGE
	print(">>> brain 合计 clear%%=%.0f%% dead%%=%.0f%% (n=%d)" %
		[100.0*total_clear/total_n, 100.0*total_dead/total_n, total_n])
	quit()

func _run_cell(meta: MetaState, base: int, pers: AIPersonality) -> Dictionary:
	var cleared := 0
	var dead := 0
	var draw := 0
	var stalled := 0
	var ch_hist := {1:0, 2:0, 3:0, 4:0}
	for i in SEEDS_PER_RANGE:
		var seed := base + i * SEED_SPACING
		var r := MetaLoopHarness.run_one(meta, seed, pers)
		match r.outcome:
			"cleared": cleared += 1
			"protagonist_dead": dead += 1
			"boss_draw": draw += 1
			_: stalled += 1
		var ch := clampi(r.chapter_reached, 1, 4)
		ch_hist[ch] = ch_hist[ch] + 1
	var n := SEEDS_PER_RANGE
	return {
		"cleared": cleared, "dead": dead, "draw": draw, "stalled": stalled, "ch_hist": ch_hist,
		"clear_pct": 100.0 * cleared / n, "death_pct": 100.0 * dead / n,
		"draw_pct": 100.0 * draw / n, "stall_pct": 100.0 * stalled / n,
	}

func _personality(pname: String) -> AIPersonality:
	match pname:
		"brute": return AIPersonality.brute()
		"trick": return AIPersonality.trick()
		_: return AIPersonality.brain()
