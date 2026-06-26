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
	var outcome: String = ""        # "cleared"(章4 掌门 yanwujiu 胜) / "protagonist_dead"(permadeath) / "stalled"(超 MAX_NODES 未结束) / "boss_draw"
	var chapter_reached: int = 1    # 到达的最深章（1..4）
	var battles_fought: int = 0
	var bosses_defeated: int = 0
	var total_battle_turns: int = 0
	var modifier_ids: Array = []    # 本局 roll 的 modifier（诊断用）
	var bosses_met: Array = []      # 遭遇过的 boss_id 列表（按遭遇顺序，可重复）

## 跑一整局（4 章闭环：hub→map 节点链→章末 boss→advance→下一章……章 4 掌门 yanwujiu 胜=cleared）。
## player_personality = team0（玩家方）AI 性格；敌方性格按 node_cfg。
## 章 N（N<4）boss 胜 → advance_chapter 续跑章 N+1；章 4 yanwujiu 胜 → cleared。
## auto_recruit=true 时开局限招募可招派系队友（复刻玩家 hub 招募，让整局更真实）。
static func run_one(meta: MetaState, seed: int, player_personality: AIPersonality, auto_recruit := true) -> RunResult:
	var res := RunResult.new()
	res.seed_used = seed
	var run := RunFactory.init_run(meta, seed)
	res.modifier_ids = RunModifier.roll(seed)
	if auto_recruit:
		_auto_recruit(run)   # 开局招满可招派系（roster_cap - 1），模拟玩家在 hub 招募
	RunFlow.place_at_chapter_start(run)

	var tuning := _tuning_for(run)

	const MAX_NODES := 256   # 防 DAG 异常无限走（4 章 × 每章 ~8 层，256 兜底）
	var steps := 0
	while steps < MAX_NODES:
		steps += 1
		# permadeath：主角死 → 局结束
		if RunFlow.is_run_over(run):
			res.outcome = "protagonist_dead"
			res.chapter_reached = run.current_chapter
			return res
		# 章末 boss 已败 → 推进或通关
		if RunFlow.can_advance_chapter(run):
			var ch_before := run.current_chapter
			var prog_outcome: String = _progress_after_boss(run)
			# 章节推进（advance 到新章）→ 重置本章休整配额（每章独立 rest_cap）
			# 不塞进 _progress_after_boss（保持该 helper 纯决策，其 3 个测试不受影响）
			if run.current_chapter != ch_before:
				run.rest_used = 0
			if prog_outcome == "cleared":
				# 章 4 掌门 yanwujiu 胜 = 通关（_progress_after_boss 已判定，未调 advance 防溢出）
				res.outcome = "cleared"
				res.chapter_reached = run.current_chapter
				return res
			# prog_outcome == ""：章 1-3 boss 胜已 advance+place，续跑下一章
			continue   # 回 loop 顶处理新章（is_run_over/can_advance/选节点）
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
				_fight_battle(run, ty, target, tuning, player_personality, meta, res)
				# 战斗间休整：复刻设计意图的恢复循环（roster 有损伤且配额未满→满血）
				_maybe_rest(run, tuning)
			"visit","escort":
				_grant_unlock(run, ty, target, meta.meta_unlocked_pool)
			"start","_":
				pass   # 起点节点无事件
	# 超步兜底
	res.outcome = "stalled"
	res.chapter_reached = run.current_chapter
	return res

## 模拟玩家休整（复刻设计意图：每章 rest_cap_per_chapter 次满血休整）。
## 战斗后若 roster 有损伤且本章休整未用完 → 满血恢复全员，rest_used++。
## rest_used 在章节推进（advance）时由 run_one 重置（每章独立配额）。
## 无 rng，确定性——不破坏 run_one 的 seeded 复现。
static func _maybe_rest(run: RunState, tuning: Tuning) -> void:
	var cap: int = tuning.rest_cap_per_chapter
	if run.rest_used >= cap:
		return
	var need := false
	for pd in run.player_roster:
		if int(pd.get("hp", 0)) < int(pd.get("max_hp", 0)):
			need = true
			break
	if not need:
		return
	for i in range(run.player_roster.size()):
		var pd: Dictionary = run.player_roster[i]
		var mhp: int = int(pd.get("max_hp", 0))
		pd["hp"] = mhp
		run.player_roster[i] = pd
	run.rest_used += 1

## boss 胜后的章节推进决策（run_one 内 can_advance_chapter 为 true 时调）。
## 返回 "cleared"（ch4 掌门 yanwujiu 胜=通关，调用方设 RunResult 并 return）或 ""（推进到下一章或仍在当章，循环继续）。
## ch4 不调 advance_chapter（防 current_chapter 溢出到 5 致 generate_map(5) 炸）。
## 抽成纯函数：让合成 run 状态可直接驱动该决策（绕开平衡做 ch4 cleared 路径的单测覆盖）。
static func _progress_after_boss(run: RunState) -> String:
	if not RunFlow.can_advance_chapter(run):
		return ""
	if run.current_chapter >= 4:   # 章 4 掌门 yanwujiu 胜 = 通关
		return "cleared"
	# 章 1-3 boss 胜 → 推进下一章
	RunFlow.advance_chapter(run)
	RunFlow.place_at_chapter_start(run)   # advance 置 current_node_id=""，需重定位 L0
	return ""

## 开局限招募：模拟玩家在 hub 招满可招派系（受 roster_cap 限），让整局含多队友。
static func _auto_recruit(run: RunState) -> void:
	# roster_cap 复刻 hub._can_recruit（默认 3，「独行」modifier 覆盖）
	var cap := 3
	if run.modifier_state.has("roster_cap"):
		cap = int(run.modifier_state["roster_cap"])
	while run.player_roster.size() < cap:
		var recruited := false
		for fid in FactionData.recruit_factions():
			if FactionRelations.can_recruit(run.faction_relations, fid):
				var idx: int = run.player_roster.size()
				if idx < FactionData.PLAYER_SLOTS.size():
					run.player_roster.append(RunFactory._ally(fid, idx))
					recruited = true
					break   # 每轮招一个，重判 cap/槽位
		if not recruited:
			break   # 无可招派系则停

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
## pm_player 每场重建（复刻 battle.gd:50 每场 new PlayerModel——防跨战斗观察污染）。
static func _fight_battle(run: RunState, node_type: String, node_id: String,
		tuning: Tuning, player_personality: AIPersonality,
		meta: MetaState, res: RunResult) -> void:
	# 查节点真实 boss_id（章1 boss 节点无 boss_id 字段→回退 EnemyPool.CHAPTER_BOSS_ID）
	var node_real_boss_id := ""
	if node_type == "boss" and run.chapter_maps.has(run.current_chapter):
		var m: Dictionary = run.chapter_maps[run.current_chapter]
		if m["nodes"].has(node_id):
			node_real_boss_id = String(m["nodes"][node_id].get("boss_id", ""))
	var node_cfg: Dictionary = _node_cfg_for(run.current_chapter, node_type, node_id, run.rng_seed, node_real_boss_id)
	# 遭遇 boss 即记 bosses_met（按遭遇顺序，可重复）
	if node_type == "boss" and node_cfg.has("boss_id"):
		res.bosses_met.append(String(node_cfg["boss_id"]))
	var s := BattleBuilder.build(run, node_cfg)
	# 敌方性格（boss→brute；否则读 node_cfg.personality——由 EnemyPool 组合带出）
	var enemy_personality := _enemy_personality_for(node_cfg)
	# 每场重建 player_model（复刻 battle.gd；旧实现跨战斗累积污染预测）
	var pm_player := PlayerModel.new()
	var pm_enemy := PlayerModel.new()
	var orch := TurnOrchestrator.new(s, tuning, pm_enemy, 1)

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
	# 剔除死亡队友（复刻 battle.gd：调 RunFlow.cull_dead_allies，保 roster 紧凑）
	RunFlow.cull_dead_allies(run)

	res.battles_fought += 1
	res.total_battle_turns += turns
	# boss 结果：TEAM0_WIN→通关推进；DRAW→单独 outcome（旧实现误并入 stalled）
	var oc := s.outcome(tuning)
	if node_type == "boss":
		match oc:
			BattleState.Outcome.TEAM0_WIN:
				RunFlow.on_boss_defeated(run)
				res.bosses_defeated += 1
			BattleState.Outcome.DRAW:
				res.outcome = "boss_draw"   # boss 平局：未通关未死，暴露为独立 outcome
				res.chapter_reached = run.current_chapter
			# TEAM1_WIN：主角若死由下轮 is_run_over 捕获；主角活则 stalled（boss 邻接为空）

## node_cfg 构造：boss 用节点真实 boss_id（caller 从 m["nodes"][node_id].boss_id 查得，章1无字段→回退表）；
## 非 boss 主动 EnemyPool.pick 取组合（带 personality + risk），让 BattleBuilder 用显式 enemies（不二次 pick）+ _enemy_personality_for 读组合性格。
## real_boss_id 由 _fight_battle 从节点 boss_id 字段查得传入——这是 ch4 L6 mini-boss vs L7 yanwujiu 保真的关键。
static func _node_cfg_for(chapter: int, node_type: String, node_id: String, rng_seed: int, real_boss_id: String = "") -> Dictionary:
	if node_type == "boss":
		var boss_id: String = real_boss_id if real_boss_id != "" else String(EnemyPool.CHAPTER_BOSS_ID.get(chapter, "hailianzheng"))
		return {"boss_id":boss_id,"node_type":"boss"}
	# 非 boss：主动抽组合，把 enemies + personality 显式带进 node_cfg
	var risk: int = 1 if node_type == "hazard" else 0
	var combo: Dictionary = EnemyPool.pick(chapter, node_type, risk, rng_seed)
	return {
		"node_type": node_type,
		"risk": risk,
		"personality": String(combo.get("personality", "brain")),
		"enemies": combo.get("enemies", []),
	}

## 敌方性格（boss→brute；否则读 node_cfg.personality——由 EnemyPool 组合带出，复刻 battle.gd._personality_for）。
static func _enemy_personality_for(node_cfg: Dictionary) -> AIPersonality:
	if node_cfg.has("boss_id"):
		return AIPersonality.brute()
	var p: String = String(node_cfg.get("personality", "brain"))
	match p:
		"brute": return AIPersonality.brute()
		"trick": return AIPersonality.trick()
		_: return AIPersonality.brain()

## visit/escort 节点：roll 解锁招加进 unlocked（复刻 map.gd:62-64，传真实 meta_pool）。
static func _grant_unlock(run: RunState, node_type: String, node_id: String, meta_pool: Array) -> void:
	var reward: Variant = UnlockRules.roll_unlock_reward(meta_pool, node_type,
		_node_cfg_for(run.current_chapter, node_type, node_id, run.rng_seed), run.rng_seed)
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
	var boss_draw: int = 0
	var stalled: int = 0
	var total_battles: int = 0
	func clear_rate() -> float:
		return float(cleared) / float(maxi(1, runs))
	func death_rate() -> float:
		return float(protagonist_dead) / float(maxi(1, runs))
	func draw_rate() -> float:
		return float(boss_draw) / float(maxi(1, runs))

static func run_series(meta: MetaState, n_runs: int, player_personality: AIPersonality, seed_base := 1) -> SeriesStats:
	var st := SeriesStats.new()
	for i in n_runs:
		var r := run_one(meta, seed_base + i * 101, player_personality)
		st.runs += 1
		st.total_battles += r.battles_fought
		match r.outcome:
			"cleared": st.cleared += 1
			"protagonist_dead": st.protagonist_dead += 1
			"boss_draw": st.boss_draw += 1
			_: st.stalled += 1
	return st
