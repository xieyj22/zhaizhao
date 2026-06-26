extends Node2D
## 当前章节节点图（T4 §1）。M3 占位渲染（每层一列按钮）。
var _layer: CanvasLayer
var _hint: Label   # 引导/反馈行（玩家验收：点哪个节点不直观）

func _ready() -> void:
	# 修 bug：进图时若在 hub（current_node_id 空），定位到当前章 L0 起点，否则无节点可点。
	if MetaSession.current_run != null:
		RunFlow.place_at_chapter_start(MetaSession.current_run)
	_build_ui()

func _build_ui() -> void:
	_layer = CanvasLayer.new(); add_child(_layer)
	var run := MetaSession.current_run
	if run == null:
		get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn"); return
	var m: Dictionary = run.chapter_maps[run.current_chapter]
	var by_layer := {}
	for id in m["nodes"]:
		var l: int = m["nodes"][id]["layer"]
		by_layer[l] = by_layer.get(l, []); by_layer[l].append(id)
	for l in range(8):
		var x := 40 + l * 110
		var lbl := Label.new(); lbl.position = Vector2(x, 16); lbl.text = "L%d" % l
		_layer.add_child(lbl)
		for id in by_layer.get(l, []):
			var ty: String = m["nodes"][id]["type"]
			var btn := Button.new()
			btn.position = Vector2(x, 40 + (by_layer[l] as Array).find(id) * 50)
			btn.text = "%s\n%s" % [id, _type_label(ty)]
			btn.custom_minimum_size = Vector2(100, 40)
			# —— M3.5: 险地节点高亮 + reward_tier 标注（MG2 在险地打 t3_chance 标）——
			if ty == "hazard":
				btn.modulate = Color(1.0, 0.5, 0.5)   # 红色高亮
				var rt: String = m["nodes"][id].get("reward_tier", "normal")
				if rt == "t3_chance":
					btn.text += " ★高回报"
			if id == run.current_node_id:
				btn.text += " ★"
			# —— 已通关节点可回放（玩家验收：想重玩之前的节点）——
			var visited := RunFlow.is_visited(run, id)
			if visited and id != run.current_node_id:
				btn.text += " ✓"   # 已通关可回放
			# 可点：当前节点（→提示，不灰锁不静默）/ DAG 前进可达 / 已通关回放；其余灰掉。
			if id == run.current_node_id:
				btn.pressed.connect(_on_current_clicked)
			elif RunFlow.can_advance_node(run, id) or (visited and id != run.current_node_id):
				btn.pressed.connect(_on_enter_node.bind(id))
			else:
				btn.disabled = true
			_layer.add_child(btn)
	var back := Button.new(); back.position = Vector2(40, 520); back.text = "返回大本营"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn"))
	_layer.add_child(back)
	# —— 引导/反馈行（玩家验收：点哪个节点不直观）——
	_hint = Label.new()
	_hint.position = Vector2(40, 560)
	_hint.text = "→ 点击相邻亮起节点进入（★ 当前位置 · ✓ 已通关可回放 · 灰=未可达）"
	_hint.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
	_layer.add_child(_hint)

## 节点类型 → 中文标签（玩家验收：start/duel 等英文不直观）。
func _type_label(ty: String) -> String:
	match ty:
		"start": return "起点"
		"duel": return "决斗"
		"sparring": return "切磋"
		"hazard": return "险地"
		"visit": return "造访"
		"escort": return "护送"
		"boss": return "BOSS"
		_: return ty

## 点当前节点（★）：不进战，给引导反馈（避免"点了没反应"或"灰锁看不懂"）。
func _on_current_clicked() -> void:
	if _hint != null:
		_hint.text = "你已在当前位置 ★，请点击相邻亮起的节点前进（下一列）"

func _on_enter_node(node_id: String) -> void:
	var run := MetaSession.current_run
	RunFlow.enter_node(run, node_id)
	var ty: String = run.chapter_maps[run.current_chapter]["nodes"][node_id]["type"]
	match ty:
		"boss","duel","sparring","hazard":
			MetaSession.current_node_cfg = _node_cfg_for(ty, node_id)
			get_tree().change_scene_to_file("res://src/scenes/battle/battle.tscn")
		"visit","escort":
			# —— T10 招募经济：访问/护送节点挣信用（招募同袍的材料）——
			run.jianghu_credit += Tuning.new().credit_per_visit
			var reward: Variant = UnlockRules.roll_unlock_reward(MetaSession.meta_state.meta_unlocked_pool, ty, _node_cfg_for(ty,node_id), run.rng_seed)
			if reward != null and not run.unlocked_techniques.has(reward):
				run.unlocked_techniques.append(reward)
			_refresh_scene()
		"start","_":
			_refresh_scene()

func _node_cfg_for(node_type: String, node_id: String) -> Dictionary:
	# —— T10e Bug A：读节点真实数据，让 BattleBuilder 构造 boss / EnemyPool 抽敌人 ——
	# 修复前：硬编码 boss=hailianzheng + 敌人=chifeng，ch2/3/4 真实游戏所有 boss 战变赫连铮、
	# 所有普通战同一 chifeng 敌人（BOSS_CONFIG/EnemyPool 数据层只在 harness/snap 用，实装游戏失效）。
	var run := MetaSession.current_run
	var rng_seed: int = run.rng_seed if run != null else 0
	if node_type == "boss":
		# 读节点真实 boss_id（ch1 boss 节点无 boss_id 字段 → 回退 hailianzheng，章1逐字节不变）；
		# 让 BattleBuilder.build 走 _unit_from_boss 构造（trait/曲线/personality 由 BossConfig 提供）。
		var bid: String = "hailianzheng"
		if run != null and run.chapter_maps.has(run.current_chapter):
			var m: Dictionary = run.chapter_maps[run.current_chapter]
			if m["nodes"].has(node_id):
				bid = String(m["nodes"][node_id].get("boss_id", "hailianzheng"))
		return {"boss_id": bid, "node_type": "boss"}
	# 非 boss：EnemyPool.pick 取组合（复刻 harness _node_cfg_for 非 boss 分支）。
	# risk：hazard=1（险地偏好高 difficulty），其余=0。
	var risk: int = 1 if node_type == "hazard" else 0
	var chapter: int = run.current_chapter if run != null else 1
	var combo: Dictionary = EnemyPool.pick(chapter, node_type, risk, rng_seed)
	return {
		"node_type": node_type,
		"risk": risk,
		"personality": String(combo.get("personality", "brain")),
		"enemies": combo.get("enemies", []),
	}

func _refresh_scene() -> void:
	for c in _layer.get_children(): c.queue_free()
	await get_tree().process_frame
	_build_ui()
