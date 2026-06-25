class_name EnemyPool
extends RefCounted

## 按章敌人组合池（M4 T7；spec §6.4 主题）。seeded 抽。
## 每组合：id/faction/personality/enemies[单位]/affinity[节点类型]/difficulty
## 单位：id/faction/personality/grid_pos/stance/hp/kit[招 id]
## stance 值：Stance.Id.METAL=0/WOOD=1/EARTH=2/WATER=3/FIRE=4。
## kit id 全部在 technique_data（TechniqueDB.find 可解析），来源 faction_data.SIGNATURE_KITS。
##
## 主题（product §6.4）：
##  - 章 1（破庙/赤锋哨站周边）：赤锋/盘根/幻踪/听潮/镜照/血衣斥候混编 → hailianzheng
##  - 章 2（听潮书院/夜枭镖局周边）：听潮/幻踪/夜枭 trick·brain 系 → moqingniang（双 boss moqingniang/yanjiu）
##  - 章 3（沉剑谷险地）：赤锋/烈焰/血衣斥候 brute 系 + 险地密集 → zongzhenglie（双 boss zongzhenglie/peiyuan）
##  - 章 4（血衣教总坛精锐）：血衣教精锐 brute 极化 + 多 2v1 → yanwujiu（掌门）
##
## 注：spec 原写 jianghu_ronin.kit=tongshi_jinda/zhongda，但通式招在 technique_kit
## 工厂而非 technique_data 表，TechniqueDB 不会索引；改为 F1 招牌 jingzhao_*（两招）。

# —— 章 1（保留 M3 七组，逐字节不变）——
const _POOL_CH1 := [
	{"id":"chifeng_patrol","faction":"F2","personality":"brute","difficulty":1,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,2],"stance":0,"hp":20,"kit":["chifeng_lianci","chifeng_yajin"]},{"id":"e2","faction":"F2","personality":"brute","grid_pos":[5,4],"stance":0,"hp":20,"kit":["chifeng_lianci","chifeng_yajin"]}]},
	{"id":"pangen_elder","faction":"F3","personality":"brain","difficulty":1,"affinity":["duel","sparring"],"enemies":[{"id":"e1","faction":"F3","personality":"brain","grid_pos":[5,3],"stance":1,"hp":30,"kit":["pangen_lagen","pangen_jiajia"]}]},
	{"id":"huazong_trickster","faction":"F6","personality":"trick","difficulty":1,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F6","personality":"trick","grid_pos":[5,3],"stance":2,"hp":20,"kit":["huazong_zhuangtu","huazong_zhuanghuo"]}]},
	{"id":"tingchao_scholar","faction":"F4","personality":"brain","difficulty":0,"affinity":["duel"],"enemies":[{"id":"e1","faction":"F4","personality":"brain","grid_pos":[5,3],"stance":3,"hp":18,"kit":["tingchao_yuanchao","tingchao_xieli"]}]},
	{"id":"jianghu_ronin","faction":"F1","personality":"brain","difficulty":0,"affinity":["sparring"],"enemies":[{"id":"e1","faction":"F1","personality":"brain","grid_pos":[5,3],"stance":2,"hp":16,"kit":["jingzhao_chuzhao","jingzhao_yingzhao"]}]},
	{"id":"xueyi_scout_elite","faction":"F8","personality":"brute","difficulty":2,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F8","personality":"brute","grid_pos":[5,2],"stance":0,"hp":24,"kit":["xueyi_xuedao","xueyi_zhuangjin"]},{"id":"e2","faction":"F8","personality":"brute","grid_pos":[5,4],"stance":0,"hp":24,"kit":["xueyi_xuedao"]}]},
	{"id":"hailianzheng","faction":"F2","personality":"brute","difficulty":9,"affinity":["boss"],"enemies":[{"id":"hailianzheng","faction":"F2","personality":"brute","grid_pos":[5,3],"stance":0,"hp":40,"kit":["chifeng_lianci","chifeng_yajin","xueyi_xuedao"]}]},
]

# —— 章 2（听潮书院/夜枭镖局周边；trick/brain 为主：幻踪 F6 trick、夜枭 F7 trick、听潮 F4 brain）——
const _POOL_CH2 := [
	{"id":"tingchao_disciples","faction":"F4","personality":"brain","difficulty":1,"affinity":["duel","sparring"],"enemies":[{"id":"e1","faction":"F4","personality":"brain","grid_pos":[5,3],"stance":3,"hp":22,"kit":["tingchao_yuanchao","tingchao_xieli"]},{"id":"e2","faction":"F4","personality":"brain","grid_pos":[5,5],"stance":3,"hp":18,"kit":["tingchao_yuanchao"]}]},
	{"id":"huazong_illusionist","faction":"F6","personality":"trick","difficulty":2,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F6","personality":"trick","grid_pos":[5,3],"stance":1,"hp":22,"kit":["huazong_zhuangtu","huazong_zhuanghuo"]}]},
	{"id":"yexiao_escort","faction":"F7","personality":"trick","difficulty":2,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F7","personality":"trick","grid_pos":[5,2],"stance":0,"hp":20,"kit":["yexiao_tujin","yexiao_liuzhuan"]},{"id":"e2","faction":"F7","personality":"trick","grid_pos":[5,4],"stance":0,"hp":20,"kit":["yexiao_tujin"]}]},
	{"id":"tingchao_xueyi_joint","faction":"F4","personality":"brain","difficulty":2,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F4","personality":"brain","grid_pos":[5,3],"stance":3,"hp":20,"kit":["tingchao_yuanchao","tingchao_xieli"]},{"id":"e2","faction":"F8","personality":"brute","grid_pos":[5,5],"stance":0,"hp":22,"kit":["xueyi_xuedao"]}]},
	{"id":"huazong_yexiao_trap","faction":"F6","personality":"trick","difficulty":3,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F6","personality":"trick","grid_pos":[5,2],"stance":1,"hp":22,"kit":["huazong_zhuangtu","huazong_zhuanghuo"]},{"id":"e2","faction":"F7","personality":"trick","grid_pos":[5,4],"stance":2,"hp":22,"kit":["yexiao_tujin","yexiao_liuzhuan"]}]},
	{"id":"tingchao_sage","faction":"F4","personality":"brain","difficulty":3,"affinity":["duel"],"enemies":[{"id":"e1","faction":"F4","personality":"brain","grid_pos":[5,3],"stance":3,"hp":32,"kit":["tingchao_yuanchao","tingchao_xieli"]}]},
	{"id":"moqingniang","faction":"F6","personality":"trick","difficulty":9,"affinity":["boss"],"enemies":[{"id":"moqingniang","faction":"F6","personality":"trick","grid_pos":[5,3],"stance":1,"hp":32,"kit":["huazong_zhuangtu","huazong_zhuanghuo"]}]},
]

# —— 章 3（沉剑谷险地；brute 为主：赤锋 F2、烈焰 F5、血衣斥候 F8，险地密集）——
const _POOL_CH3 := [
	{"id":"chifeng_vanguard","faction":"F2","personality":"brute","difficulty":2,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,2],"stance":0,"hp":26,"kit":["chifeng_lianci","chifeng_yajin"]},{"id":"e2","faction":"F2","personality":"brute","grid_pos":[5,4],"stance":0,"hp":26,"kit":["chifeng_lianci","chifeng_yajin"]}]},
	{"id":"lieyan_fanatic","faction":"F5","personality":"brute","difficulty":3,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F5","personality":"brute","grid_pos":[5,3],"stance":4,"hp":28,"kit":["lieyan_liaoyuan","lieyan_huoqi"]}]},
	{"id":"xueyi_recon","faction":"F8","personality":"brute","difficulty":3,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F8","personality":"brute","grid_pos":[5,2],"stance":0,"hp":26,"kit":["xueyi_xuedao","xueyi_zhuangjin"]},{"id":"e2","faction":"F8","personality":"brute","grid_pos":[5,4],"stance":0,"hp":26,"kit":["xueyi_xuedao","xueyi_zhuangjin"]}]},
	{"id":"chifeng_lieyan_shock","faction":"F2","personality":"brute","difficulty":3,"affinity":["duel"],"enemies":[{"id":"e1","faction":"F2","personality":"brute","grid_pos":[5,2],"stance":0,"hp":26,"kit":["chifeng_lianci","chifeng_yajin"]},{"id":"e2","faction":"F5","personality":"brute","grid_pos":[5,4],"stance":4,"hp":28,"kit":["lieyan_liaoyuan","lieyan_huoqi"]}]},
	{"id":"lieyan_xueyi_burner","faction":"F5","personality":"brute","difficulty":4,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F5","personality":"brute","grid_pos":[5,3],"stance":4,"hp":28,"kit":["lieyan_liaoyuan","lieyan_huoqi"]},{"id":"e2","faction":"F8","personality":"brute","grid_pos":[5,5],"stance":0,"hp":26,"kit":["xueyi_xuedao"]}]},
	{"id":"xueyi_reaver_solo","faction":"F8","personality":"brute","difficulty":3,"affinity":["sparring"],"enemies":[{"id":"e1","faction":"F8","personality":"brute","grid_pos":[5,3],"stance":0,"hp":34,"kit":["xueyi_xuedao","xueyi_zhuangjin"]}]},
	{"id":"zongzhenglie","faction":"F2","personality":"brute","difficulty":9,"affinity":["boss"],"enemies":[{"id":"zongzhenglie","faction":"F2","personality":"brute","grid_pos":[5,3],"stance":0,"hp":45,"kit":["chifeng_lianci","chifeng_yajin"]}]},
]

# —— 章 4（血衣教总坛精锐；brute 极化、多 2v1、高难度）——
const _POOL_CH4 := [
	{"id":"xueyi_elite_pair","faction":"F8","personality":"brute","difficulty":4,"affinity":["duel","hazard"],"enemies":[{"id":"e1","faction":"F8","personality":"brute","grid_pos":[5,2],"stance":0,"hp":30,"kit":["xueyi_xuedao","xueyi_zhuangjin"]},{"id":"e2","faction":"F8","personality":"brute","grid_pos":[5,4],"stance":0,"hp":30,"kit":["xueyi_xuedao","xueyi_zhuangjin"]}]},
	{"id":"xueyi_priest_brain","faction":"F8","personality":"brain","difficulty":4,"affinity":["duel","sparring"],"enemies":[{"id":"e1","faction":"F8","personality":"brain","grid_pos":[5,3],"stance":3,"hp":30,"kit":["xueyi_xuedao","xueyi_zhuangjin"]}]},
	{"id":"xueyi_hybrid_squad","faction":"F8","personality":"brute","difficulty":5,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F8","personality":"brute","grid_pos":[5,2],"stance":0,"hp":30,"kit":["xueyi_xuedao","xueyi_zhuangjin"]},{"id":"e2","faction":"F8","personality":"trick","grid_pos":[5,4],"stance":1,"hp":28,"kit":["xueyi_zhuangjin"]}]},
	{"id":"sikongyi_miniboss","faction":"F4","personality":"brain","difficulty":6,"affinity":["duel"],"enemies":[{"id":"sikongyi","faction":"F4","personality":"brain","grid_pos":[5,3],"stance":3,"hp":50,"kit":["tingchao_yuanchao","tingchao_xieli"]}]},
	{"id":"leiwanjun_miniboss","faction":"F5","personality":"brute","difficulty":6,"affinity":["hazard"],"enemies":[{"id":"leiwanjun","faction":"F5","personality":"brute","grid_pos":[5,3],"stance":4,"hp":48,"kit":["lieyan_liaoyuan","lieyan_huoqi"]}]},
	{"id":"xueyi_guard_trio","faction":"F8","personality":"brute","difficulty":6,"affinity":["hazard"],"enemies":[{"id":"e1","faction":"F8","personality":"brute","grid_pos":[5,1],"stance":0,"hp":28,"kit":["xueyi_xuedao"]},{"id":"e2","faction":"F8","personality":"brute","grid_pos":[5,3],"stance":0,"hp":30,"kit":["xueyi_xuedao","xueyi_zhuangjin"]},{"id":"e3","faction":"F8","personality":"brute","grid_pos":[5,5],"stance":0,"hp":28,"kit":["xueyi_zhuangjin"]}]},
	{"id":"yanwujiu","faction":"F8","personality":"brute","difficulty":9,"affinity":["boss"],"enemies":[{"id":"yanwujiu","faction":"F8","personality":"brute","grid_pos":[5,3],"stance":0,"hp":65,"kit":["xueyi_xuedao","xueyi_zhuangjin","jingzhao_chuzhao"]}]},
]

const CHAPTER_POOLS: Dictionary = {
	1: _POOL_CH1,
	2: _POOL_CH2,
	3: _POOL_CH3,
	4: _POOL_CH4,
}

# 各章 boss 固定 id（boss 节点 pick 直接取）。多 boss 章取其一作 pool 代表；
# 真实多 boss 走 map_generator.boss_ids_for + node_cfg.boss_id 路径（BattleBuilder 优先 boss_id）。
const CHAPTER_BOSS_ID: Dictionary = {
	1: "hailianzheng",
	2: "moqingniang",
	3: "zongzhenglie",
	4: "yanwujiu",
}

## 取某章组合池（默认章 1；未定义章回退章 1，防御性）。
static func get_pool(chapter: int = 1) -> Array:
	return CHAPTER_POOLS.get(chapter, _POOL_CH1)

## 据 chapter + node_type + risk + seed 抽组合。boss 固定（按章）；其余按 affinity 过滤后 seeded 抽。
## 注：方法名用 pick 而非 get —— GDScript 解析 `Class.get(...)` 静态调用时
## 会与 Object.get() 内置方法冲突报 "Could not resolve external class member"
## （同 TechniqueDB.find 的坑）。
static func pick(chapter: int, node_type: String, risk: int, rng_seed: int) -> Dictionary:
	var pool: Array = get_pool(chapter)
	if node_type == "boss":
		return _by_id(pool, String(CHAPTER_BOSS_ID.get(chapter, "hailianzheng")))
	var candidates: Array = pool.filter(func(c): return (c["affinity"] as Array).has(node_type))
	if candidates.is_empty():
		candidates = pool.filter(func(c): return (c["affinity"] as Array).has("boss") == false)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	# risk 高时偏好高 difficulty（risk>0 过滤 difficulty>=1，无则全留）
	if risk > 0:
		var hard: Array = candidates.filter(func(c): return int(c["difficulty"]) >= 1)
		if not hard.is_empty():
			candidates = hard
	return candidates[rng.randi() % candidates.size()]

static func _by_id(pool: Array, id: String) -> Dictionary:
	for c in pool:
		if c["id"] == id:
			return c
	return {}
