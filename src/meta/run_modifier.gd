class_name RunModifier
extends RefCounted

## 局 modifier「天象/时令」（M3.5；spec A）。effect 按 hook 分组，apply 合并进 modifier_state。
## hook 键（消费者）：
##   kit_stance_damage_bonus {stance:Δ}   → battle_builder._build_kit
##   kit_stance_speed_bonus  {stance:Δ}   → 同上
##   kit_feint_bonus_delta   float        → 同上（feint_bonus_mult += Δ）
##   hazard_baseline         {hazard flags} → battle_builder.build 并入 hazard_modifiers
##   ai_confidence_cap_delta float        → battle.gd tuning override
##   morale_cap_delta        int          → battle.gd tuning override
##   roster_cap              int          → 招募（HUB）
##   relation_start_delta    int          → init_run 初始关系
##   credit_mult             float        → 信用产出/消费（节点奖励 + 镖局）
##   max_hp_mult             float        → init_run 主角 max_hp
##   hazard_node_count_delta int          → map_generator 险地数

const POOL := [
	{"id":"ruijin_dangling", "name":"锐金当令", "desc":"METAL 招 base_damage +1", "difficulty":1, "effect":{"kit_stance_damage_bonus":{"METAL":1}}},
	{"id":"hougu_zhenxie", "name":"厚土镇煞", "desc":"EARTH 招 speed +1", "difficulty":1, "effect":{"kit_stance_speed_bonus":{"EARTH":1}}},
	{"id":"xuesha_miman", "name":"血煞弥漫", "desc":"全局每场 opening +1/turn", "difficulty":2, "effect":{"hazard_baseline":{"chaos":true}}},
	{"id":"wangkai_yimian", "name":"网开一面", "desc":"虚招上钩倍率 +0.5", "difficulty":1, "effect":{"kit_feint_bonus_delta":0.5}},
	{"id":"shensi", "name":"慎思", "desc":"战意上限 -2（提早平局）", "difficulty":1, "effect":{"morale_cap_delta":-2}},
	{"id":"duxing", "name":"独行", "desc":"禁招队友，主角 max_hp x1.5", "difficulty":1, "effect":{"roster_cap":1, "max_hp_mult":1.5}},
	{"id":"zhongpan_qinli", "name":"众叛亲离", "desc":"开局关系 -20，信用产出 x2", "difficulty":1, "effect":{"relation_start_delta":-20, "credit_mult":2.0}},
	{"id":"duxin_po", "name":"读心破", "desc":"AI 读你更狠（cap +0.15）", "difficulty":2, "effect":{"ai_confidence_cap_delta":0.15}},
	{"id":"cebuczhun", "name":"测不准", "desc":"AI 读不准（cap -0.15）", "difficulty":-2, "effect":{"ai_confidence_cap_delta":-0.15}},
	{"id":"xianjin_renling", "name":"险地频仍", "desc":"节点图险地 +2", "difficulty":2, "effect":{"hazard_node_count_delta":2}},
]

## const 无法通过 Class.POOL 静态访问（GDScript 解析限制），通过 getter 暴露。
static func get_pool() -> Array:
	return POOL

## seeded roll 2 个去重。同 seed 同结果。
static func roll(rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var ids: Array = POOL.map(func(m): return m["id"])
	var picked: Array = []
	while picked.size() < 2:
		var id = ids[rng.randi() % ids.size()]
		if not picked.has(id):
			picked.append(id)
	return picked

## 合并多 modifier 的 effect 进 modifier_state（数值 hook 求和，dict hook 深合并）。
static func apply(modifier_ids: Array) -> Dictionary:
	var state: Dictionary = {}
	for id in modifier_ids:
		var m: Dictionary = _by_id(id)
		var eff: Dictionary = m.get("effect", {})
		for hook in eff:
			var v = eff[hook]
			if v is Dictionary:
				state[hook] = _deep_merge(state.get(hook, {}), v)
			elif v is float:
				state[hook] = float(state.get(hook, 0.0)) + float(v)
			else:
				state[hook] = int(state.get(hook, 0)) + int(v)
	return state

static func _by_id(id: String) -> Dictionary:
	for m in POOL:
		if m["id"] == id:
			return m
	return {}

## dict hook 深合并：bool 值（hazard flag）直接置；数值（stance bonus）求和。
## 两边皆 int 时保持 int（stance bonus 为 int），否则升 float。
static func _deep_merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate(true)
	for k in b:
		var bv = b[k]
		if bv is bool:
			out[k] = bv
		elif bv is int:
			var cur: int = int(out.get(k, 0))
			out[k] = cur + int(bv)
		else:
			var curf: float = float(out.get(k, 0.0))
			out[k] = curf + float(bv)
	return out
