extends Node2D
## 单一 meta hub = 镜照山·旧址（T4 §3）。M3 占位 UI。
var _layer: CanvasLayer
var _status: Label

func _ready() -> void:
	MetaSession.meta_state = MetaState.load_from()
	_build_ui()

func _build_ui() -> void:
	_layer = CanvasLayer.new(); add_child(_layer)
	var root := VBoxContainer.new()
	root.position = Vector2(40, 40); root.custom_minimum_size = Vector2(400, 0)
	_layer.add_child(root)
	_status = Label.new()
	root.add_child(_status)
	_refresh_status()
	var btn_new := Button.new(); btn_new.text = "开始新一局"
	btn_new.pressed.connect(_on_new_run)
	root.add_child(btn_new)
	var btn_cont := Button.new(); btn_cont.text = "继续闯荡（节点图）"
	btn_cont.pressed.connect(_on_open_map)
	root.add_child(btn_cont)
	for f in ["F1 镜照","F2 赤锋","F4 听潮"]:
		var lbl := Label.new(); lbl.text = "【%s 代表】（招募/关系/技谱）" % f
		root.add_child(lbl)

func _refresh_status() -> void:
	var m := MetaSession.meta_state
	_status.text = "镜照山·旧址 | 通关 %d 次 | 解锁招 %d 招" % [m.meta_runs_completed, m.meta_unlocked_pool.size()]
	if MetaSession.current_run != null:
		_status.text += " | 当前章 %d" % MetaSession.current_run.current_chapter

func _on_new_run() -> void:
	var seed := 7
	MetaSession.current_run = RunFactory.init_run(MetaSession.meta_state, seed)
	_open_map()

func _on_open_map() -> void:
	if MetaSession.current_run == null: return
	_open_map()

func _open_map() -> void:
	get_tree().change_scene_to_file("res://src/scenes/map/map.tscn")
