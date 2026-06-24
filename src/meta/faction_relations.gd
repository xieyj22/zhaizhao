class_name FactionRelations
extends RefCounted

## 关系纯函数（T4 §3.3/§3.4）。
const RECRUIT_THRESHOLD := 30          # T4 调参面：招募阈值
const GREY_FACTIONS := ["F5","F6","F7"] # 灰区派（T2 §F8.6）

static func can_recruit(relations: Dictionary, faction_id: String) -> bool:
	if faction_id == "F8": return false   # 血衣教不可招募
	return relations.get(faction_id, 0) >= RECRUIT_THRESHOLD

static func clamp(v: int) -> int:
	return clampi(v, -100, 100)   # 不变量 53

## 灰区派关系<0 时的决斗倒戈概率（T4 §3.3 简化）。非灰区派恒 0。
static func defection_chance(relations: Dictionary, faction_id: String) -> float:
	if not GREY_FACTIONS.has(faction_id): return 0.0
	var v: int = relations.get(faction_id, 0)
	if v >= 0: return 0.0
	# 关系越负倒戈概率越高：-100→0.5，线性
	return clampf((-v) / 200.0, 0.0, 0.5)
