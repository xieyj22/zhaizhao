class_name Opening
extends RefCounted

## 破绽×伤害放大 + 回落（spec §2.4），纯函数。

## 最终伤害 = base + floor(opening * mult)；招架崩溃时翻倍
static func compute_damage(base: int, target_opening: int, mult: float, guard_broken: bool) -> int:
	var dmg: int = base + int(floor(target_opening * mult))
	if guard_broken:
		dmg *= 2
	return max(0, dmg)

## 破绽每回合自然回落（守势加速回稳在 M1 stance role 里加）
static func decay(opening: int, rate: int) -> int:
	return max(0, opening - rate)
