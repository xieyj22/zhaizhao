class_name MetaLoopHarness
extends RefCounted

## 整局 meta loop headless 闭环（M3 工程化收尾）。
## 绕过 scene 层（7 处 change_scene + map.gd/hub.gd/battle.gd 的 UI 逻辑），
## 用纯函数层（RunFactory/RunFlow/MapGenerator/BattleBuilder/EnemyPool/TurnOrchestrator/AIController）
## 拼 in-memory 状态机，跑出整局通关/死亡数据。
##
## 与 playtest_harness 的区别：那个跑单场 AI vs AI；这个跑整局（hub→map 多节点→battle 多场→章末 boss）。
##
## 用途：① 整局回归网（之前 permadeath bug 缺整局测才漏）；② 整局平衡数据（通关率/主角死亡率/modifier 影响）。
## 不进 GUT 断言套件（统计用）——由调用方打印；test_meta_loop_harness.gd 断言"能终止/合法 outcome/章节推进"。

class RunResult:
	extends RefCounted
	var seed_used: int = 0
	var outcome: String = ""        # "cleared"(章末 boss 胜) / "protagonist_dead"(permadeath) / "stalled"(超 MAX_NODES 未结束)
	var chapter_reached: int = 1    # 到达的最深章（章 2-4 未实装，上限 1）
	var battles_fought: int = 0
	var bosses_defeated: int = 0
	var total_battle_turns: int = 0
	var modifier_ids: Array = []    # 本局 roll 的 modifier（诊断用）

## 跑一整局（章 1 完整 loop：hub→map 节点链→章末 boss）。
## player_personality = team0（玩家方）AI 性格；敌方性格按 node_cfg。
## 章 2-4 未实装，章 1 boss 胜即"cleared"。
static func run_one(meta: MetaState, seed: int, player_personality: AIPersonality) -> RunResult:
	var res := RunResult.new()
	res.seed_used = seed
	var run := RunFactory.init_run(meta, seed)
	res.modifier_ids = RunModifier.roll(seed)
	RunFlow.place_at_chapter_start(run)

	var tuning := _tuning_for(run)
	# player_roster 预建 PlayerModel（按单位 id）；敌方每场临时建模玩家方
	var pm_player := PlayerModel.new()   # 玩家方建模敌方？反向——这里 pm 观察敌方供玩家 AI 决策
	# TurnOrchestrator(player_model, ai_team)：ai_team=1 → orch 观察 team0 进 player_model
	# 玩家方(team0)由 AI 驱动，决策时需读 team1 模型 → 用第二个 PlayerModel，手动 observe team1

	const MAX_NODES := 64   # 防 DAG 异常无限走（章 1 约 8 层，64 足够兜底）
	var steps := 0
	while steps < MAX_NODES:
		steps += 1
		# permadeath：主角死 → 局结束
		if RunFlow.is_run_over(run):
			res.outcome = "protagonist_dead"
			res.chapter_reached = run.current_chapter
			return res
		# 章末 boss 已败 → 通关（章 2-4 未实装，到此为止）
		if RunFlow.can_advance_chapter(run):
			res.outcome = "cleared"
			res.chapter_reached = run.current_chapter
			return res
		# 取下一可达节点（DAG 邻接）；无邻接且未通关 → stalled
		var m: Dictionary = run.chapter_maps[run.current_chapter]
		var nxt: Array = MapGenerator.reachable_next(m, run.current_node_id)
		if nxt.is_empty():
			res.outcome = "stalled"
			res.chapter_reached = run.current_chapter
			return res
		# 选下一节点：优先 boss（boss_defeated 未达时走 boss 完成章）；否则取第一个可达
		var target := _pick_next_node(m, nxt)
		RunFlow.enter_node(run, target)
		var ty: String = String(m["nodes"][target].get("type", "start"))
		match ty:
			"boss","duel","sparring","hazard":
				_fight_battle(run, ty, target, tuning, player_personality, pm_player, res)
			"visit","escort":
				_grant_unlock(run, ty, target)
			"start","_":
				pass   # 起点节点无事件
	# 超步兜底
	res.outcome = "stalled"
	res.chapter_reached = run.current_chapter
	return res

## 选下一节点：boss 在可达中且本章未通关 → 走 boss；否则首个可达。
static func _pick_next_node(m: Dictionary, reachable: Array) -> String:
	for id in reachable:
		if String(m["nodes"][id].get("type", "")) == "boss":
			return String(id)
	return String(reachable[0])

## 构造 tuning + modifier override（复刻 battle.gd._ready 的 override 逻辑）。
static func _tuning_for(run: RunState) -> Tuning:
	var t := Tuning.new()
	var ms: Dictionary = run.modifier_state
	if ms.has("ai_confidence_cap_delta"):
		t.l2_confidence_cap = clampf(t.l2_confidence_cap + float(ms["ai_confidence_cap_delta"]), 0.0, 1.0)
	if ms.has("morale_cap_delta"):
		t.morale_cap_turn = maxi(1, t.morale_cap_turn + int(ms["morale_cap_delta"]))
	return t

## 跑一场战斗（双 AI：team0=玩家性格，team1=节点敌人性格）。
## 复刻 battle.gd 的 BattleBuilder 构造 + playtest_harness 的回合循环 + battle.gd 的回写。
static func _fight_battle(run: RunState, node_type: String, node_id: String,
		tuning: Tuning, player_personality: AIPersonality,
		pm_player: PlayerModel, res: RunResult) -> void:
	var node_cfg: Dictionary = _node_cfg_for(node_type, node_id, run.rng_seed)
	var s := BattleBuilder.build(run, node_cfg)
	# 敌方性格（boss→brute；否则 node_cfg.personality 或 brain）
	var enemy_personality := _enemy_personality_for(node_cfg)
	# TurnOrchestrator(player_model, ai_team=1)：观察 team0（玩家）进 pm_enemy 供敌方决策
	var pm_enemy := PlayerModel.new()
	var orch := TurnOrchestrator.new(s, tuning, pm_enemy, 1)
	# 玩家方决策需建模敌方 → 手动 observe team1 进 pm_player（每回合后）

	# kit lookup（AIController.choose_actions 需要 kits dict）
	var kits: Dictionary = {}
	for u in s.units:
		kits[String(u.id)] = u.kit

	const MAX_TURNS := 30
	var turns := 0
	while s.outcome(tuning) == BattleState.Outcome.ONGOING and turns < MAX_TURNS:
		var rng_seed := run.rng_seed * 7919 + turns * 13 + 1
		# pre-resolve 特征（observe 用 pre-state，复刻 playtest_harness）
		var pre_keys_t1: Dictionary = {}
		for u in s.units:
			if u.team == 1:
				pre_keys_t1[String(u.id)] = pm_player.featurize(u, s, tuning)
		var ai0 := AIController.choose_actions(s, 0, tuning, kits, rng_seed, pm_player, player_personality)
		var ai1 := AIController.choose_actions(s, 1, tuning, kits, rng_seed, pm_enemy, enemy_personality)
		orch.reveal_and_resolve(ai0.actions + ai1.actions)
		# observe team1 进 pm_player（用 pre-resolve 特征）
		for a in ai1.actions:
			if a.unit != null and a.unit.team == 1 and pre_keys_t1.has(String(a.unit.id)):
				pm_player.observe(pre_keys_t1[String(a.unit.id)], a.technique.type, String(a.unit.id))
		orch.end_turn()
		turns += 1

	# 回写 roster 生死/hp（复刻 battle.gd._write_back_result，按 id 匹配）
	for i in range(run.player_roster.size()):
		var pd: Dictionary = run.player_roster[i]
		var u: UnitState = _find_unit(s, String(pd["id"]))
		if u != null:
			pd["hp"] = u.hp
			pd["alive"] = u.alive
			pd["opening"] = u.opening
			pd["guard_broken"] = u.guard_broken
			run.player_roster[i] = pd

	res.battles_fought += 1
	res.total_battle_turns += turns
	# boss 胜 → 标记本章 boss 已败（章末通关条件）
	var oc := s.outcome(tuning)
	if node_type == "boss" and oc == BattleState.Outcome.TEAM0_WIN:
		RunFlow.on_boss_defeated(run)
		res.bosses_defeated += 1

## node_cfg 构造（复刻 map.gd._node_cfg_for；boss 固定 hailianzheng，其余靠 EnemyPool）。
static func _node_cfg_for(node_type: String, node_id: String, rng_seed: int) -> Dictionary:
	if node_type == "boss":
		return {"boss_id":"hailianzheng","node_type":"boss"}
	# 非 boss：BattleBuilder 在 enemies 空 + 有 node_type 时自动从 EnemyPool.pick 抽
	return {"node_type":node_type, "risk":1 if node_type == "hazard" else 0}

## 敌方性格（复刻 battle.gd._personality_for）。
static func _enemy_personality_for(node_cfg: Dictionary) -> AIPersonality:
	if node_cfg.has("boss_id"):
		return AIPersonality.brute()
	# 非 boss：BattleBuilder 已用 EnemyPool 抽了 enemies，但性格在 enemy dict 里；
	# harness 这里简化用 brain（EnemyPool 各组合 personality 在 build 时进 UnitState？否——
	# UnitState 无 personality 字段；敌方 AI 性格此处统一取 brain，M4 可按 enemy_pool 组合细化）
	return AIPersonality.brain()

## visit/escort 节点：roll 解锁招加进 unlocked（复刻 map.gd:62-64）。
static func _grant_unlock(run: RunState, node_type: String, node_id: String) -> void:
	var meta_pool := []   # harness 无 meta_state 上下文，传空池（roll 仍能给奖励）
	var reward: Variant = UnlockRules.roll_unlock_reward(meta_pool, node_type,
		_node_cfg_for(node_type, node_id, run.rng_seed), run.rng_seed)
	if reward != null and not run.unlocked_techniques.has(reward):
		run.unlocked_techniques.append(reward)

static func _find_unit(s: BattleState, id_str: String) -> UnitState:
	for u in s.units:
		if String(u.id) == id_str:
			return u
	return null

## 跑 N 局汇总（统计用）。
class SeriesStats:
	extends RefCounted
	var runs: int = 0
	var cleared: int = 0
	var protagonist_dead: int = 0
	var stalled: int = 0
	var total_battles: int = 0
	func clear_rate() -> float:
		return float(cleared) / float(maxi(1, runs))
	func death_rate() -> float:
		return float(protagonist_dead) / float(maxi(1, runs))

static func run_series(meta: MetaState, n_runs: int, player_personality: AIPersonality, seed_base := 1) -> SeriesStats:
	var st := SeriesStats.new()
	for i in n_runs:
		var r := run_one(meta, seed_base + i * 101, player_personality)
		st.runs += 1
		st.total_battles += r.battles_fought
		match r.outcome:
			"cleared": st.cleared += 1
			"protagonist_dead": st.protagonist_dead += 1
			_: st.stalled += 1
	return st
