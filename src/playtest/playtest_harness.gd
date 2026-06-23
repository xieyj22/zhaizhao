class_name PlaytestHarness
extends RefCounted

## M2 深度打磨：AI vs AI 自动对局 + 数据收集（headless，确定性 seeded）。
## 不进 GUT 测试套件（不是断言，是统计）——由 battle_stats.gd 入口脚本调用打印。
## 数据回答：胜/平率、单局回合数、L2 读招命中率、虚招触发/上钩率、破绽崩溃率、致命占比。

class MatchResult:
	extends RefCounted
	var outcome: int            # BattleState.Outcome
	var turns: int
	var read_hits: int          # AI 预测命中玩家方招的次数
	var read_attempts: int      # AI 做出预测的总次数（confidence>0）
	var feints_thrown: int      # 双方出 FEINT 的总次数
	var feints_lured: int       # FEINT 成功诱骗(上钩×1.5)的次数
	var feints_unmasked: int    # FEINT 被识破(×0.7)的次数
	var feints_plain: int       # FEINT apparent=-1(原倍)的次数
	var guard_breaks: int       # 招架崩溃(破绽满)触发次数
	var lethal_strikes: int     # 致命打击(本击杀死单位)次数

class Stats:
	extends RefCounted
	var matches: int = 0
	var team0_wins: int = 0
	var team1_wins: int = 0
	var draws: int = 0
	var total_turns: int = 0
	var turn_samples: Array = []
	var read_hits: int = 0
	var read_attempts: int = 0
	var feints_thrown: int = 0
	var feints_lured: int = 0
	var feints_unmasked: int = 0
	var feints_plain: int = 0
	var guard_breaks: int = 0
	var lethal_strikes: int = 0

	func absorb(r: MatchResult) -> void:
		matches += 1
		match r.outcome:
			BattleState.Outcome.TEAM0_WIN: team0_wins += 1
			BattleState.Outcome.TEAM1_WIN: team1_wins += 1
			BattleState.Outcome.DRAW: draws += 1
		total_turns += r.turns
		turn_samples.append(r.turns)
		read_hits += r.read_hits
		read_attempts += r.read_attempts
		feints_thrown += r.feints_thrown
		feints_lured += r.feints_lured
		feints_unmasked += r.feints_unmasked
		feints_plain += r.feints_plain
		guard_breaks += r.guard_breaks
		lethal_strikes += r.lethal_strikes

	func mean_turns() -> float:
		return float(total_turns) / float(maxi(1, matches))

	func median_turns() -> int:
		var sorted := turn_samples.duplicate()
		sorted.sort()
		return sorted[sorted.size() / 2]

	func read_hit_rate() -> float:
		return float(read_hits) / float(maxi(1, read_attempts))

	func feint_lure_rate() -> float:
		# 上钩率 = 上钩 / (上钩+识破)，plain(apparent=-1)不计入博弈
		var n := feints_lured + feints_unmasked
		return float(feints_lured) / float(maxi(1, n))

## 跑一场 2v2（team0=pers0 性格 vs team1=pers1 性格），返回 MatchResult
## 玩家方(team0)与敌方(team1)都由 AI 驱动（脚本化：都集火最残敌方，FAR 必中）
static func run_match(pers0: AIPersonality, pers1: AIPersonality, tuning: Tuning, seed: int) -> MatchResult:
	var res := MatchResult.new()
	var s := _mk_2v2_state()
	var pm0 := PlayerModel.new()
	var pm1 := PlayerModel.new()
	var orch := TurnOrchestrator.new(s, tuning, pm1, 1)   # ai_team=1 observe team0
	# team0 也需要被建模 team1：用第二个 orchestrator? 不——observe 逻辑在 reveal_and_resolve。
	# 这里只用一个 orch（observe team0 进 pm1）。pm0 用于 team0 AI 决策时读 team1。
	# 简化：两个 PlayerModel，但只 orch(pm1,ai_team=1) observe team0。team0 AI 决策用 pm0（observe team1）。
	# 为对称 observe，另建一个 observe-team1 的 hook：手动在每回合后 observe team1 进 pm0。
	var kits := {}
	for u in s.units:
		kits[String(u.id)] = TechniqueKit.default_kit()
	const MAX_TURNS := 30
	var turns := 0
	# 记录每单位初始架势 + 出招史（统计用）
	while s.outcome(tuning) == BattleState.Outcome.ONGOING and turns < MAX_TURNS:
		# team0 决策（pers0，建模 team1）
		# team0/team1 用同一 seed（对称 RNG 序列；决策因 state/PlayerModel 不同而异，但 RNG 公平）
		# 之前 +1/+2 offset 制造了系统性 team 偏差（已诊断）
		var rng_seed := seed * 7919 + turns * 13 + 1
		var ai0 := AIController.choose_actions(s, 0, tuning, kits, rng_seed, pm0, pers0)
		var ai1 := AIController.choose_actions(s, 1, tuning, kits, rng_seed, pm1, pers1)
		# 读招统计：team1 对 team0 的预测 vs team0 实际
		_count_reads(res, ai1.predictions, ai0.actions)
		_count_reads(res, ai0.predictions, ai1.actions)   # 双向都计（read_attempts 翻倍，但命中率有代表性）
		# reveal 前：featurize team1（pre-resolve 特征供 observe）+ 记致命/崩溃快照
		# 用 Dictionary 值拷贝（Godot duplicate(true) 对 RefCounted 仍浅，引用共享导致 pre==post）
		var pre_keys_t1: Dictionary = {}
		for a in ai1.actions:
			if a.unit != null and a.unit.team == 1:
				pre_keys_t1[String(a.unit.id)] = pm0.featurize(a.unit, s, tuning)
		var pre_state: Dictionary = {}
		for u in s.units:
			pre_state[String(u.id)] = {"alive": u.alive, "guard_broken": u.guard_broken}
		orch.reveal_and_resolve(ai0.actions + ai1.actions)
		# observe team1（用 pre-resolve key；team0 已由 orch 内部 observe）
		for a in ai1.actions:
			if a.unit != null and a.unit.team == 1 and pre_keys_t1.has(String(a.unit.id)):
				pm0.observe(pre_keys_t1[String(a.unit.id)], a.technique.type, String(a.unit.id))
		_count_feints(res, ai0.actions + ai1.actions, pre_state, s)
		orch.end_turn()   # 推进回合 + 战意/角色结算（之前漏了导致 outcome 永远 ONGOING）
		turns += 1
	res.outcome = s.outcome(tuning)
	res.turns = turns
	return res

static func _count_reads(res: MatchResult, predictions: Dictionary, actions: Array) -> void:
	var actual_by_unit: Dictionary = {}
	for a in actions:
		if a.unit != null:
			actual_by_unit[String(a.unit.id)] = a.technique.type
	for uid in predictions:
		res.read_attempts += 1
		if actual_by_unit.has(uid) and actual_by_unit[uid] == predictions[uid]:
			res.read_hits += 1

## 手动 observe：team1 的实际招进 pm0（用 pre-resolve 特征）
static func _observe_team(s: BattleState, pre_units: Array, pm: PlayerModel, team: int, tuning: Tuning, actions: Array) -> void:
	# pre_units 是结算前快照，用它算特征
	for a in actions:
		if a.unit != null and a.unit.team == team:
			var pre_u := _find_unit(pre_units, a.unit.id)
			if pre_u != null:
				pm.observe(pm.featurize(pre_u, s, tuning), a.technique.type, String(a.unit.id))

static func _find_unit(units: Array, id) -> UnitState:
	for u in units:
		if u.id == id:
			return u
	return null

## 统计虚招（按 action.technique 类型）+ 上钩/识破（用 resolver 逻辑重判）+ 崩溃/致命（前后对比）
static func _count_feints(res: MatchResult, actions: Array, pre_state: Dictionary, s: BattleState) -> void:
	for a in actions:
		var t: Technique = a.technique
		if t.type == Technique.Type.FEINT:
			res.feints_thrown += 1
			if t.apparent_stance < 0:
				res.feints_plain += 1
			else:
				# 重判上钩：对手是否存在 perceived 克 apparent（同 Resolver._compute_lured 逻辑）
				var hooked := false
				for b in actions:
					if b == a or b.unit == null:
						continue
					if b.unit.team != a.unit.team and b.unit.alive:
						var b_perceived: int = b.unit.stance
						if b.technique != null and b.technique.type == Technique.Type.FEINT and b.technique.apparent_stance >= 0:
							b_perceived = b.technique.apparent_stance
						if Stance.counters(b_perceived, t.apparent_stance):
							hooked = true
							break
				if hooked:
					res.feints_lured += 1
				else:
					res.feints_unmasked += 1
	# 致命/崩溃：用 pre_state 快照（Dictionary 值拷贝，避免 RefCounted 引用共享导致 pre==post）
	for u in s.units:
		var pre: Dictionary = pre_state.get(String(u.id), {})
		if pre.has("alive"):
			if pre["alive"] and not u.alive:
				res.lethal_strikes += 1
			if not pre["guard_broken"] and u.guard_broken:
				res.guard_breaks += 1

static func _mk_2v2_state() -> BattleState:
	var s := BattleState.new()
	s.units = [
		_mk(&"p0", 0, Vector2i(1,2), Stance.Id.METAL),
		_mk(&"p1", 0, Vector2i(1,4), Stance.Id.WOOD),
		_mk(&"e0", 1, Vector2i(5,2), Stance.Id.WOOD),
		_mk(&"e1", 1, Vector2i(5,4), Stance.Id.METAL),
	]
	return s

static func _mk(id, team, pos, stance) -> UnitState:
	var u := UnitState.new()
	u.id = id; u.team = team; u.grid_pos = pos; u.stance = stance
	u.hp = 20; u.max_hp = 20
	return u

## 跑一组对战（pers0 × pers1 × N seed），返回 Stats
static func run_series(pers0: AIPersonality, pers1: AIPersonality, tuning: Tuning, n_seeds: int, seed_base := 1) -> Stats:
	var stats := Stats.new()
	for i in n_seeds:
		var r := run_match(pers0, pers1, tuning, seed_base + i * 101)
		stats.absorb(r)
	return stats
