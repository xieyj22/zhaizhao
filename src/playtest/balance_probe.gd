extends SceneTree

## M4a Wave1 数值稳定性探针（T10 Step3 复核）。
## 跨 4 个 seed 范围（100/500/1000/2000 + s*13）× 3 性格（brain/brute/trick）× 每范围 30 seed，
## 跑 MetaLoopHarness.run_one 整局闭环，每格打印：
##   - outcome 分布 {cleared, protagonist_dead, boss_draw, stalled}
##   - chapter_reached 直方图（1..4）
##   - clear% / death% / draw% / stall%
## 末尾跑确定性自检（同 seed 两次 run_one 逐字段比对）。
##
## 用法（headless 纯数据，无渲染）：
##   export GODOT="E:/claude/Godot_v4.7-stable_win64.exe"
##   export PROJ="E:/claude/zhaizhao"
##   "$GODOT" --path "$PROJ" --headless -s res://src/playtest/balance_probe.gd
##
## 设计：
##   - extends SceneTree（参照 battle_stats.gd / snap_bosses.gd），非 GUT。
##   - MetaLoopHarness / AIPersonality / MetaState 是 class_name 全局类，
##     -s SceneTree 期全局标识符在编译期已注册（这三者不依赖 autoload），
##     故直接用 MetaLoopHarness.run_one(...) 即可（与 battle_stats.gd 同款）。
##   - 4 范围 seed_base：100 / 500 / 1000 / 2000；seed = base + i*13（i=0..29）。
##     s*13 间隔保证相邻 seed 差分大，避免 RNG 序列相关。
##   - 性格：AIPersonality.brain() / brute() / trick()。
##   - meta 用 MetaState.new_first_play()（首玩默认，每范围一致）。

const SEEDS_PER_RANGE := 30
const SEED_SPACING := 13
const SEED_BASES := [100, 500, 1000, 2000]
const PERSONALITIES := ["brain", "brute", "trick"]

func _init() -> void:
	# 先确定性自检（同 seed 两次 run_one 应逐字同），早暴露 RNG 泄漏
	var det := _determinism_check(7, "brain")
	print("\n=== 确定性自检（seed=7, brain, 两次 run_one）===")
	print("  identical: %s" % str(det.identical))
	if not det.identical:
		print("  !!! 不一致：")
		print("    run1: outcome=%s ch=%d battles=%d bosses=%d turns=%d" %
			[det.r1.outcome, det.r1.chapter_reached, det.r1.battles_fought, det.r1.bosses_defeated, det.r1.total_battle_turns])
		print("    run2: outcome=%s ch=%d battles=%d bosses=%d turns=%d" %
			[det.r2.outcome, det.r2.chapter_reached, det.r2.battles_fought, det.r2.bosses_defeated, det.r2.total_battle_turns])

	var meta := MetaState.new_first_play()
	# 表头
	print("\n=== M4a Wave1 多范围平衡探针 ===")
	print("配置：4 seed 范围 × 3 性格 × %d seed/范围 = %d 局" %
		[SEEDS_PER_RANGE, SEED_BASES.size() * PERSONALITIES.size() * SEEDS_PER_RANGE])
	print("seed 公式：base + i*%d（i=0..%d），base ∈ %s" %
		[SEED_SPACING, SEEDS_PER_RANGE - 1, str(SEED_BASES)])

	# 收集所有单元格，最后打印总表
	var rows := []   # [{range, persona, cleared, dead, draw, stalled, ch_hist, clear_pct}]
	for base in SEED_BASES:
		for pname in PERSONALITIES:
			var pers := _personality(pname)
			var cell := _run_cell(meta, base, pers)
			cell["range"] = str(base)
			cell["persona"] = pname
			rows.append(cell)
			print("\n[range=%s persona=%s]" % [base, pname])
			print("  outcome: cleared=%d dead=%d draw=%d stalled=%d  (n=%d)" %
				[cell.cleared, cell.dead, cell.draw, cell.stalled, SEEDS_PER_RANGE])
			print("  chapter_reached 直方图: ch1=%d ch2=%d ch3=%d ch4=%d" %
				[cell.ch_hist[1], cell.ch_hist[2], cell.ch_hist[3], cell.ch_hist[4]])
			print("  clear%%=%.0f%%  death%%=%.0f%%  draw%%=%.0f%%  stall%%=%.0f%%" %
				[cell.clear_pct, cell.death_pct, cell.draw_pct, cell.stall_pct])

	# 汇总表（紧凑）
	_print_summary_table(rows)

	# 稳定性判定
	_print_stability_verdict(rows, det.identical)

	quit()

## 单格：跑 SEEDS_PER_RANGE seed，汇总 outcome + chapter 直方图。
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
		"cleared": cleared,
		"dead": dead,
		"draw": draw,
		"stalled": stalled,
		"ch_hist": ch_hist,
		"clear_pct": 100.0 * cleared / n,
		"death_pct": 100.0 * dead / n,
		"draw_pct": 100.0 * draw / n,
		"stall_pct": 100.0 * stalled / n,
	}

## 紧凑汇总表（range × persona 的 clear% + outcome 分布）。
func _print_summary_table(rows: Array) -> void:
	print("\n=== 汇总表（clear% / outcome 分布）===")
	print("%-7s %-7s %7s %7s %7s %7s %7s" %
		["range", "persona", "clear%", "dead%", "draw%", "stall%", "ch4%"])
	for r in rows:
		print("%-7s %-7s %6.0f%% %6.0f%% %6.0f%% %6.0f%% %6.0f%%" %
			[r.range, r.persona, r.clear_pct, r.death_pct, r.draw_pct, r.stall_pct,
			 100.0 * r.ch_hist[4] / SEEDS_PER_RANGE])

## 稳定性判定：
##  - clear% 跨 4 范围是否稳定（非某范围突变 0% 或 100%）
##  - 是否所有范围都 non-0% non-100%（Step3 "合理" 标准的硬下限）
##  - 确定性是否成立
func _print_stability_verdict(rows: Array, determinism_ok: bool) -> void:
	print("\n=== 稳定性判定 ===")
	# 按性格分组，看 clear% 跨范围波动
	var by_persona := {}
	for r in rows:
		if not by_persona.has(r.persona):
			by_persona[r.persona] = []
		by_persona[r.persona].append(r)

	var boundary_cells := []   # clear% = 0% 或 100% 的 cell（Step3 硬下限）
	var max_swing := 0.0       # 单性格跨范围最大 clear% 波动
	for pname in PERSONALITIES:
		var rs: Array = by_persona[pname]
		var pcts: Array = []
		for r in rs:
			pcts.append(r.clear_pct)
			if r.clear_pct <= 0.0 or r.clear_pct >= 100.0:
				boundary_cells.append({"range":r.range, "persona":pname, "pct":r.clear_pct})
		var vmin := _min_of(pcts)
		var vmax := _max_of(pcts)
		var swing := vmax - vmin
		if swing > max_swing:
			max_swing = swing
		print("  %s: clear%% 跨范围 = %s | min=%.0f%% max=%.0f%% swing=%.0f%%" %
			[pname, _fmt_pcts(pcts), vmin, vmax, swing])

	# 边界 cell 列表（clear%=0% 或 100% → Step3 不达标）
	if boundary_cells.is_empty():
		print("\n  边界 cell（clear%=0% 或 100%）：无")
	else:
		print("\n  边界 cell（clear%=0% 或 100%）：")
		for bc in boundary_cells:
			print("    - range=%s persona=%s clear%%=%.0f%%" % [bc.range, bc.persona, bc.pct])
	print("  跨范围最大 swing：%.0f%%" % max_swing)
	print("  确定性自检：%s" % ("通过" if determinism_ok else "!!! 不通过"))

	# Step3 "合理" 标准：所有 12 格 clear% non-0% non-100% + 确定性成立
	# 注意：death%=100%（=clear%=0%）同样算边界失败——主角几乎必死，无游玩空间。
	var step3_pass := boundary_cells.is_empty() and determinism_ok
	if step3_pass:
		print("\n  >>> Step3 '合理' 标准（全格 non-0% non-100% + 确定性）：PASS")
	else:
		print("\n  >>> Step3 '合理' 标准（全格 non-0% non-100% + 确定性）：FAIL")
		print("      （边界 cell 存在或确定性失败 → 数值偏置过强，需调参）")

## 确定性自检：同 seed 两次 run_one，逐字段比对。
## 返回 {identical:bool, r1:RunResult, r2:RunResult}。
func _determinism_check(seed: int, pname: String) -> Dictionary:
	var meta := MetaState.new_first_play()
	var pers := _personality(pname)
	var r1 := MetaLoopHarness.run_one(meta, seed, pers)
	var r2 := MetaLoopHarness.run_one(meta, seed, pers)
	var identical := (
		r1.outcome == r2.outcome and
		r1.chapter_reached == r2.chapter_reached and
		r1.battles_fought == r2.battles_fought and
		r1.bosses_defeated == r2.bosses_defeated and
		r1.total_battle_turns == r2.total_battle_turns and
		_arr_eq(r1.bosses_met, r2.bosses_met)
	)
	return {"identical": identical, "r1": r1, "r2": r2}

func _personality(pname: String) -> AIPersonality:
	match pname:
		"brute": return AIPersonality.brute()
		"trick": return AIPersonality.trick()
		_: return AIPersonality.brain()

func _arr_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

func _min_of(a: Array) -> float:
	var m: float = a[0]
	for v in a:
		if float(v) < m:
			m = float(v)
	return m

func _max_of(a: Array) -> float:
	var m: float = a[0]
	for v in a:
		if float(v) > m:
			m = float(v)
	return m

func _fmt_pcts(a: Array) -> String:
	var parts := []
	for v in a:
		parts.append("%.0f%%" % float(v))
	return "[" + ", ".join(parts) + "]"
