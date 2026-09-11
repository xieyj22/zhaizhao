extends SceneTree

## boss 战实渲染截图工具（T10 Step4）。
## 对 BOSS_CONFIG 8 个 boss 各截一张战斗界面 PNG（1280×800，gl_compatibility），
## 供主控肉眼验布局（方块视觉 + boss 单位 + HP 条 + trait 指示 + 网格 + 右侧 UI）。
##
## 必须 **非 headless** 运行（headless 下 gl_compatibility 无 viewport texture）：
##   "$GODOT" --path "$PROJ" -s res://src/playtest/snap_bosses.gd
## 会弹窗一闪，正常。存盘到 .superpowers/sdd/shots/snap_<bid>.png。
##
## 纯工具脚本（不扫 tests/，非 GUT 测试）；seed 固定 7（确定性截图）；
## reduce_motion 保持默认 false（验渲染）；不引入 randi/randf。

const BATTLE_TSCN_PATH := "res://src/scenes/battle/battle.tscn"
const SHOTS_DIR := "E:/claude/zhaizhao/.superpowers/sdd/shots/"
const SEED := 7
## 多等几帧确保 _ready + BattleView._draw + queue_redraw 全部完成（gl_compatibility 下稳妥）。
const FRAMES_BEFORE_SHOT := 4
const FRAMES_AFTER_FREE := 2

func _initialize() -> void:
	call_deferred("_snap_all")

func _snap_all() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS_DIR)
	# 首玩默认 meta（足够构造 boss 战）；每 boss 新 run 保证确定性。
	var meta := MetaState.new_first_play()
	var ids: Array = BossConfig.BOSS_CONFIG.keys()
	var root := get_root()
	# -s 自定义 SceneTree 期，autoload 全局标识符在编译期未注册；
	# 此处运行时取 autoload node（注册已完成），透传给 _snap_one 避免 battle.gd 同款编译失败。
	var meta_session: Node = root.get_node("/root/MetaSession")
	if meta_session == null:
		push_error("snap_bosses: autoload /root/MetaSession 未找到")
		quit(1)
		return
	var results: Array = []   # [{bid, path, ok, err}]
	for bid in ids:
		var bstr := String(bid)
		var rec: Dictionary = {"bid": bstr, "path": SHOTS_DIR + "snap_%s.png" % bstr, "ok": false, "err": ""}
		# 单 boss 异常隔离：失败 print 继续，不整体崩。
		var err := await _snap_one(bstr, meta, root, meta_session)
		if err == "":
			rec.ok = true
			print("snap %s -> %s ok" % [bstr, rec.path])
		else:
			rec.err = err
			print("snap %s ERR: %s" % [bstr, err])
		results.append(rec)
	print("\n=== snap_bosses 完成 ===")
	var ok_n := 0
	for r in results:
		if bool(r.ok):
			ok_n += 1
	print("ok %d / %d" % [ok_n, results.size()])
	quit()

## 单个 boss 截图。返回 "" 成功，否则错误字符串。
## meta_session = 运行时取得的 autoload /root/MetaSession 节点（避免编译期全局标识符）。
func _snap_one(bid: String, meta: MetaState, root: Window, meta_session: Node) -> String:
	var cfg: Dictionary = BossConfig.get_boss(bid)
	if cfg.is_empty():
		return "BOSS_CONFIG 无此 id: " + bid
	var run := RunFactory.init_run(meta, SEED)
	# 设 run 当前章 = boss 所在章（影响 BB 难度曲线 + EnemyPool 兜底）
	run.current_chapter = int(cfg.get("chapter", 1))
	meta_session.set("current_run", run)
	meta_session.set("current_node_cfg", {"boss_id": bid, "node_type": "boss", "replay": true})   # replay：跳过战前对白，截战斗布局本体（Wave2）
	var battle: Node2D = null
	var img: Image = null
	# —— instantiate + 等帧渲染 ——
	# 运行时 load（非 const preload）：battle.gd 在解析期引用 autoload MetaSession，
	# 用 -s 自定义 SceneTree 时 preload 会在 autoload 注册前编译导致失败；运行时 load 已晚于注册。
	var tscn := load(BATTLE_TSCN_PATH) as PackedScene
	if tscn == null:
		return "无法加载 battle.tscn"
	battle = tscn.instantiate() as Node2D
	root.add_child(battle)
	for i in FRAMES_BEFORE_SHOT:
		await process_frame
	# —— 截图 ——
	var vp := battle.get_viewport()
	if vp == null:
		_cleanup(battle)
		return "viewport 为 null"
	var tex := vp.get_texture()
	if tex == null:
		_cleanup(battle)
		return "viewport texture 为 null"
	img = tex.get_image()
	if img == null:
		_cleanup(battle)
		return "get_image() 返回 null"
	var err_code := img.save_png(SHOTS_DIR + "snap_%s.png" % bid)
	_cleanup(battle)
	if err_code != OK:
		return "save_png 错误码 %d" % err_code
	return ""

func _cleanup(battle: Node2D) -> void:
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		for i in FRAMES_AFTER_FREE:
			await process_frame
