class_name UnlockRules
extends RefCounted

## 节点奖励纯函数（T4 §5.4 不变量 88）。返回 tech_id（String）或 null。
## 章 1 boss 固定掉落映射（T4 §5.2 第 83 条）。
const BOSS_DROPS := {"hailianzheng":"xueyi_xuedao"}

static func roll_unlock_reward(meta_pool: Array, node_type: String, node_cfg: Dictionary, rng_seed: int) -> Variant:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	match node_type:
		"duel":
			return _pick_tier(meta_pool, 2, rng)
		"sparring":
			return _faction_signature_pick(node_cfg.get("faction","F1"), rng)
		"visit":
			var f: Variant = node_cfg.get("fixed_tech", null)
			return f if f != null else null
		"hazard":
			# T2 抽 + 30% 概率 T3
			if rng.randf() < 0.3:
				var t3: Variant = _pick_tier(meta_pool, 3, rng)
				if t3 != null: return t3
			return _pick_tier(meta_pool, 2, rng)
		"escort":
			# 黑市：花 credit 买 T2（由 HUB 调用方扣 credit）；这里纯给候选
			return _pick_tier(meta_pool, 2, rng)
		"boss":
			return BOSS_DROPS.get(node_cfg.get("boss_id",""), null)
	return null

static func _pick_tier(pool: Array, tier: int, rng: RandomNumberGenerator) -> Variant:
	var candidates: Array = TechniqueDB.tier_ids(pool, tier)
	if candidates.is_empty(): return null
	return candidates[rng.randi() % candidates.size()]

static func _faction_signature_pick(faction_id: String, rng: RandomNumberGenerator) -> Variant:
	var sig: Array = FactionData.SIGNATURE_KITS.get(faction_id, [])
	if sig.is_empty(): return null
	return sig[rng.randi() % sig.size()]
