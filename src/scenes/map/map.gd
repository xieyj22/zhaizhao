extends Node2D
## 当前章节节点图（T4 §1）。M3 占位渲染（每层一列按钮）。
var _layer: CanvasLayer

func _ready() -> void:
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
			btn.text = "%s\n%s" % [id, ty]
			btn.custom_minimum_size = Vector2(100, 40)
			if id == run.current_node_id:
				btn.text += " ★"
			if RunFlow.can_advance_node(run, id):
				btn.pressed.connect(_on_enter_node.bind(id))
			else:
				btn.disabled = (id != run.current_node_id)
			_layer.add_child(btn)
	var back := Button.new(); back.position = Vector2(40, 520); back.text = "返回大本营"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://src/scenes/hub/hub.tscn"))
	_layer.add_child(back)

func _on_enter_node(node_id: String) -> void:
	var run := MetaSession.current_run
	RunFlow.enter_node(run, node_id)
	var ty: String = run.chapter_maps[run.current_chapter]["nodes"][node_id]["type"]
	match ty:
		"boss","duel","sparring","hazard":
			MetaSession.current_node_cfg = _node_cfg_for(ty, node_id)
			get_tree().change_scene_to_file("res://src/scenes/battle/battle.tscn")
		"visit","escort":
			var reward: Variant = UnlockRules.roll_unlock_reward(MetaSession.meta_state.meta_unlocked_pool, ty, _node_cfg_for(ty,node_id), run.rng_seed)
			if reward != null and not run.unlocked_techniques.has(reward):
				run.unlocked_techniques.append(reward)
			_refresh_scene()
		"start","_":
			_refresh_scene()

func _node_cfg_for(node_type: String, node_id: String) -> Dictionary:
	if node_type == "boss":
		return {"boss_id":"hailianzheng","personality":"brute","enemies":[
			{"id":"hailianzheng","faction":"F2","personality":"brute","grid_pos":[5,3],"stance":Stance.Id.METAL,"kit":["chifeng_lianci","chifeng_yajin","xueyi_xuedao"]}]}
	return {"enemies":[{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,3],"stance":Stance.Id.WOOD,"kit":["chifeng_lianci","chifeng_yajin"]}]}

func _refresh_scene() -> void:
	for c in _layer.get_children(): c.queue_free()
	await get_tree().process_frame
	_build_ui()
