extends SceneTree

## 叙事 UI 实渲染截图工具（Wave2 验收）。模式真源 = snap_bosses.gd：
## SceneTree 脚本、必须非 headless 运行、运行时取 /root/MetaSession（-s 期 autoload
## 全局标识符未注册）、逐场景实例化 + 等帧 + viewport 截图 + queue_free 清理、
## 单场景失败隔离（print ERR 继续）。只读项目窗口尺寸（project.godot 1280×800）。
##
## 运行（非 headless，弹窗一闪正常）：
##   "$GODOT" --path . -s res://src/playtest/snap_scenes.gd
## 产出 8 张到 .superpowers/sdd/shots/scene_*.png：
##   scene_map_ch1_open        新开局进图 → map._ready 自动弹本章 open 入章过场
##   scene_map_ch3_visit_mid   ch3 L4 visit → _on_enter_node → mid 散文行（幽灵行修复实证）
##   scene_hub_codex_shanhe/wudao/renwu   中期进度 meta → hub 江湖志三 tab（含灰显）
##   scene_dialog_rm           reduce_motion 下 boss 战前对白 2 帧即全不透明（瞬切验证）
##   scene_dialog_post_win/loss  yanwujiu 战后对白 widget 级渲染
##
## seed 固定 7（确定性，与 snap_bosses/测试一致）。触发全部走真实代码路径
## （_ready 自动过场 / _on_enter_node / _on_open_codex / _build_codex_panel / battle
## _ready 对白门 / DialogBox.open），唯一注入 = 复刻玩家已看过的 interlude_shown 预烧
## （test_map_narrative 同款）与任务指定的 visit 节点 layer=4。

const SHOTS_DIR := "E:/claude/zhaizhao/.superpowers/sdd/shots/"
const MAP_TSCN := "res://src/scenes/map/map.tscn"
const HUB_TSCN := "res://src/scenes/hub/hub.tscn"
const BATTLE_TSCN := "res://src/scenes/battle/battle.tscn"
const DIALOG_GD := "res://src/ui/dialog_box.gd"
const SEED := 7

## 等帧数（gl_compatibility 渲染稳定）。注意：本机非 headless 下帧率随场景负载波动
## （空场景可达数百 fps），DialogBox 0.18s 淡入不能按帧数等——淡入相关等待一律用
## 真实计时器（S_FADE_SEC ≥ 0.18s）再补帧渲染，帧数只用于树处理（queue_free 结算等）。
const F_REFRESH := 3       # map _refresh_scene（内部 await 1 帧 + _build_ui 重建）
const F_HUB_READY := 4     # hub _ready 构建
const F_HUB_BUILD := 2     # codex 面板同步构建后渲染
const F_HUB_TAB := 3       # tab 重建：旧子 queue_free 需帧末结算（test 同款等 2 帧起）
const F_RM := 2            # reduce_motion 瞬切验证：只等 2 帧（无淡入，帧数即可）
const S_FADE := 0.3        # 盖过 DialogBox 0.18s 淡入的真实秒数
const F_AFTER_FREE := 2

var _ms: Node   # 运行时取得的 /root/MetaSession

func _initialize() -> void:
	call_deferred("_snap_all")

func _snap_all() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS_DIR)
	_ms = get_root().get_node("/root/MetaSession")
	if _ms == null:
		push_error("snap_scenes: autoload /root/MetaSession 未找到")
		quit(1)
		return
	var results: Array = []
	results.append(_rec("scene_map_ch1_open",
		"入章过场框：『第1章』+open 散文淡入完成",
		await _shot_map_ch1_open()))
	results.append(_rec("scene_map_ch3_visit_mid",
		"底部 y590 暖色(0.78/0.62/0.42) mid 散文行",
		await _shot_map_ch3_visit_mid()))
	results.append(_rec("scene_hub_codex_shanhe",
		"山河志 5 条：ch1-3 解锁 3 条 + 血衣总坛/无相原灰显『？？？』",
		await _shot_hub_codex("山河志", "shanhe")))
	results.append(_rec("scene_hub_codex_wudao",
		"武道志：已习招字帖解锁 + 道统/笔记/通关条目灰显",
		await _shot_hub_codex("武道志", "wudao")))
	results.append(_rec("scene_hub_codex_renwu",
		"人物志 8 条：赫连铮/莫青娘/晏九解锁，其余灰显『？？？』",
		await _shot_hub_codex("人物志", "renwu")))
	results.append(_rec("scene_dialog_rm",
		"reduce_motion 下战前对白面板 2 帧即全不透明（无淡入）",
		await _shot_dialog_rm()))
	results.append(_rec("scene_dialog_post_win",
		"颜无咎 post_win 对白（名条+正文+计数 1/6）",
		await _shot_dialog_post("post_win")))
	results.append(_rec("scene_dialog_post_loss",
		"颜无咎 post_loss 对白（名条+正文+计数 1/5）",
		await _shot_dialog_post("post_loss")))
	print("\n=== snap_scenes 完成 ===")
	var ok_n := 0
	for r in results:
		if bool(r.ok):
			ok_n += 1
	print("ok %d / %d" % [ok_n, results.size()])
	for r in results:
		print("  %s [%s]: %s" % [r.id, "OK" if bool(r.ok) else "FAIL", r.expect])
	quit()

func _rec(id: String, expect: String, err: String) -> Dictionary:
	if err == "":
		print("snap %s ok -> %s%s.png" % [id, SHOTS_DIR, id])
	else:
		print("snap %s ERR: %s" % [id, err])
	return {"id": id, "ok": err == "", "expect": expect}

# —— 截图 / 清理（snap_bosses 同款） ——

func _capture(node: Node, fname: String) -> String:
	var vp := node.get_viewport()
	if vp == null:
		return "viewport 为 null"
	var tex := vp.get_texture()
	if tex == null:
		return "viewport texture 为 null"
	var img := tex.get_image()
	if img == null:
		return "get_image() 返回 null"
	var rc := img.save_png(SHOTS_DIR + fname)
	if rc != OK:
		return "save_png 错误码 %d" % rc
	return ""

func _cleanup(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		for i in F_AFTER_FREE:
			await process_frame

# —— 1. 新开局 ch1：map._ready 真实路径自动弹 open 入章过场 ——

func _shot_map_ch1_open() -> String:
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, SEED)   # current_chapter=1 / current_node_id=""
	_ms.set("meta_state", meta)
	_ms.set("current_run", run)
	_ms.set("current_node_cfg", {})
	var tscn := load(MAP_TSCN) as PackedScene
	if tscn == null:
		return "无法加载 map.tscn"
	var map = tscn.instantiate()
	get_root().add_child(map)
	# 真实路径：_ready → place_at_chapter_start + _seg_open→"open" 非空 → DialogBox 弹章名+散文
	await create_timer(S_FADE).timeout   # 真实时间盖过 0.18s 淡入（帧率随负载波动，按帧等不可靠）
	await process_frame
	var err := _capture(map, "scene_map_ch1_open.png")
	await _cleanup(map)
	return err

# —— 2. ch3 L4 visit：mid 散文行（幽灵描写行修复实证） ——

func _shot_map_ch3_visit_mid() -> String:
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, SEED)
	# test_map_narrative._run_ch3 同款构造：ch3 图 + 预烧 open（复刻已看过入章过场的
	# 玩家态，聚焦 mid 行；非私有字段伪造——interlude_shown 本就是玩家进度数据）
	run.current_chapter = 3
	run.chapter_progress[3] = {"bosses_defeated": [], "nodes_visited": []}
	run.chapter_maps[3] = MapGenerator.generate_map(SEED, 3, 0)
	run.interlude_shown["3:open"] = true
	_ms.set("meta_state", meta)
	_ms.set("current_run", run)
	_ms.set("current_node_cfg", {})
	var tscn := load(MAP_TSCN) as PackedScene
	if tscn == null:
		return "无法加载 map.tscn"
	var map = tscn.instantiate()
	get_root().add_child(map)
	await process_frame   # _ready 落地（open 已烧 → 无过场侧噪）
	# 找 visit 节点（真实 ch3 数据 visit>=1；test_map_narrative._visit_node 同款）
	var vid := ""
	var nodes: Dictionary = run.chapter_maps[3]["nodes"]
	for nid in nodes:
		if String(nodes[nid]["type"]) == "visit":
			vid = String(nid)
			break
	if vid == "":
		await _cleanup(map)
		return "ch3 图无 visit 节点"
	nodes[vid]["layer"] = 4   # mid 段触发层（任务指定的最小注入）
	map._on_enter_node(vid)   # 复刻玩家点击进节点：visit 分支 mid 散文 + _refresh_scene 重建
	for i in F_REFRESH:
		await process_frame
	# 实证检查：_refresh_scene 重建后散文行仍持有 mid 文本（幽灵行不复现）
	var prose := ""
	var ph = map.get("_prose_hint")
	if ph != null and is_instance_valid(ph):
		prose = String(ph.text)
	if prose == "":
		await _cleanup(map)
		return "_prose_hint 为空（幽灵描写行复现？）"
	print("  ch3 mid 散文行: %s…" % prose.substr(0, 24))
	var err := _capture(map, "scene_map_ch3_visit_mid.png")
	await _cleanup(map)
	return err

# —— 3-5. hub 江湖志三 tab（中期进度 meta：含未解锁灰显） ——

func _shot_hub_codex(tab: String, suffix: String) -> String:
	# 中期进度 meta（test_hub_codex/test_meta_state 同款字段真名）：
	# 到过章 1-3；跨 run 击败 ch1-3 三 boss；招式池 = 首玩 tier1 全 + 赤锋两招。
	var meta := MetaState.new_first_play()
	meta.chapters_reached = [1, 2, 3]
	meta.bosses_defeated_all = ["hailianzheng", "moqingniang", "yanjiu"]
	meta.meta_unlocked_pool.append("chifeng_lianci")
	meta.meta_unlocked_pool.append("chifeng_yajin")
	_ms.set("meta_state", meta)
	_ms.set("current_run", null)   # 纯 hub 态（无进行中 run）
	var tscn := load(HUB_TSCN) as PackedScene
	if tscn == null:
		return "无法加载 hub.tscn"
	var hub = tscn.instantiate()
	get_root().add_child(hub)
	for i in F_HUB_READY:
		await process_frame
	hub._on_open_codex()   # 玩家点『江湖志』真实入口（默认 tab 人物志）
	for i in F_HUB_BUILD:
		await process_frame
	if tab != "人物志":
		hub._build_codex_panel(tab)   # 玩家点 tab 按钮的真实路径（按钮 bind 同函数）
		for i in F_HUB_TAB:
			await process_frame
	var err := _capture(hub, "scene_hub_codex_%s.png" % suffix)
	await _cleanup(hub)
	return err

# —— 6. reduce_motion 瞬切：yanwujiu 战前对白 2 帧即全不透明 ——

func _shot_dialog_rm() -> String:
	_ms.set("reduce_motion", true)   # 真实开关：autoload 字段（battle 内 M 键切换的同一真源）
	var meta := MetaState.new_first_play()
	var run := RunFactory.init_run(meta, SEED)
	run.current_chapter = 4   # yanwujiu 所在章（snap_bosses 同款：设章影响难度曲线）
	_ms.set("meta_state", meta)
	_ms.set("current_run", run)
	_ms.set("current_node_cfg", {"boss_id": "yanwujiu", "node_type": "boss", "replay": false})   # 非回放 → _ready 弹战前对白
	var tscn := load(BATTLE_TSCN) as PackedScene
	if tscn == null:
		return "无法加载 battle.tscn"
	var battle = tscn.instantiate()
	get_root().add_child(battle)
	for i in F_RM:
		await process_frame   # 只等 2 帧：rm 下面板应无淡入直接全不透明
	var err := _capture(battle, "scene_dialog_rm.png")
	await _cleanup(battle)
	_ms.set("reduce_motion", false)   # 复原，隔离后续截图
	_ms.set("current_node_cfg", {})
	return err

# —— 7/8. yanwujiu 战后对白 widget 级渲染（battle._show_dialog 同签名） ——

func _shot_dialog_post(key: String) -> String:
	_ms.set("reduce_motion", false)   # 默认路径（有淡入，等帧盖过）
	var lines: Array = NarrativeBoss.dialogue("yanwujiu", key)
	if lines.is_empty():
		return "yanwujiu 无 %s 对白" % key
	var speaker := String(BossConfig.get_boss("yanwujiu").get("name", "yanwujiu"))
	# 运行时 load（非 preload）：dialog_box.gd 解析期引用 autoload MetaSession，
	# -s 自定义 SceneTree 下 preload 会编译失败（snap_bosses 同坑注释）。
	var box = load(DIALOG_GD).new()
	get_root().add_child(box)
	box.open(lines, speaker, func() -> void: box.queue_free())   # 名条：行内 s 优先，空 s 回退 boss 名
	await create_timer(S_FADE).timeout   # 真实时间盖过 0.18s 淡入（任务写 4 帧；实测空场景帧率
	await process_frame                  # 极高，按帧等 14 帧淡入也仅 ~25%，改真实计时器）
	var err := _capture(box, "scene_dialog_%s.png" % key)   # key=post_win/post_loss → scene_dialog_post_win.png
	await _cleanup(box)
	return err
