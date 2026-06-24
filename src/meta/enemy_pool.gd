class_name EnemyPool
extends RefCounted

## 章 1 敌人组合池（M3.5；spec B.1）。替换 map.gd 硬编码。seeded 抽。
## 每组合：id/faction/personality/enemies[单位]/affinity[节点类型]/difficulty
## 单位：id/faction/personality/grid_pos/stance/hp/kit[招 id]
## stance 值：Stance.Id.METAL=0/WOOD=1/EARTH=2/WATER=3/FIRE=4。
## kit id 全部在 technique_data（TechniqueDB.find 可解析）。
## 注：spec 原写 jianghu_ronin.kit=tongshi_jinda/zhongda，但通式招在 technique_kit
## 工厂而非 technique_data 表，TechniqueDB 不会索引；改为 F1 招牌 jingzhao_*（两招）。
const POOL := [
	{"id":"chifeng_patrol","faction":"F2","personality":"brute","difficulty":1,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,2],"stance":0,"hp":20,"kit":["chifeng_lianci","chifeng_yajin"]},{"id":"e2","faction":"F2","personality":"brute","grid_pos":[5,4],"stance":0,"hp":20,"kit":["chifeng_lianci","chifeng_yajin"]}]},
	{"id":"pangen_elder","faction":"F3","personality":"brain","difficulty":1,"affinity":["duel","sparring"],"enemies":[{"id":"e1","faction":"F3","personality":"brain","grid_pos":[5,3],"stance":1,"hp":30,"kit":["pangen_lagen","pangen_jiajia"]}]},
	{"id":"huazong_trickster","faction":"F6","personality":"trick","difficulty":1,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F6","personality":"trick","grid_pos":[5,3],"stance":2,"hp":20,"kit":["huazong_zhuangtu","huazong_zhuanghuo"]}]},
	{"id":"tingchao_scholar","faction":"F4","personality":"brain","difficulty":0,"affinity":["duel"],"enemies":[{"id":"e1","faction":"F4","personality":"brain","grid_pos":[5,3],"stance":3,"hp":18,"kit":["tingchao_yuanchao","tingchao_xieli"]}]},
	{"id":"jianghu_ronin","faction":"F1","personality":"brain","difficulty":0,"affinity":["sparring"],"enemies":[{"id":"e1","faction":"F1","personality":"brain","grid_pos":[5,3],"stance":2,"hp":16,"kit":["jingzhao_chuzhao","jingzhao_yingzhao"]}]},
	{"id":"xueyi_scout_elite","faction":"F8","personality":"brute","difficulty":2,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F8","personality":"brute","grid_pos":[5,2],"stance":0,"hp":24,"kit":["xueyi_xuedao","xueyi_zhuangjin"]},{"id":"e2","faction":"F8","personality":"brute","grid_pos":[5,4],"stance":0,"hp":24,"kit":["xueyi_xuedao"]}]},
	{"id":"hailianzheng","faction":"F2","personality":"brute","difficulty":9,"affinity":["boss"],"enemies":[{"id":"hailianzheng","faction":"F2","personality":"brute","grid_pos":[5,3],"stance":0,"hp":40,"kit":["chifeng_lianci","chifeng_yajin","xueyi_xuedao"]}]},
]

static func get_pool() -> Array:
	return POOL

## 据 node_type + risk + seed 抽组合。boss 固定；其余按 affinity 过滤后 seeded 抽。
## 注：方法名用 pick 而非 get —— GDScript 解析 `Class.get(...)` 静态调用时
## 会与 Object.get() 内置方法冲突报 "Could not resolve external class member"
## （同 TechniqueDB.find 的坑）。
static func pick(node_type: String, risk: int, rng_seed: int) -> Dictionary:
	if node_type == "boss":
		return _by_id("hailianzheng")
	var candidates: Array = POOL.filter(func(c): return (c["affinity"] as Array).has(node_type))
	if candidates.is_empty():
		candidates = POOL.filter(func(c): return c["id"] != "hailianzheng")
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	# risk 高时偏好高 difficulty（risk>0 过滤 difficulty>=1，无则全留）
	if risk > 0:
		var hard: Array = candidates.filter(func(c): return int(c["difficulty"]) >= 1)
		if not hard.is_empty():
			candidates = hard
	return candidates[rng.randi() % candidates.size()]

static func _by_id(id: String) -> Dictionary:
	for c in POOL:
		if c["id"] == id:
			return c
	return {}
