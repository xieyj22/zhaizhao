class_name Stance
extends RefCounted

## 5 势成环（M0 占位名 = 五行；正式名待 worldbuilder 产出，spec §11）
## 克制环（五行相克）：金→木→土→水→火→金
enum Id { METAL, WOOD, EARTH, WATER, FIRE }

const ALL: Array = [Id.METAL, Id.WOOD, Id.EARTH, Id.WATER, Id.FIRE]

const _COUNTERS: Dictionary = {
	Id.METAL: Id.WOOD,   # 金克木
	Id.WOOD: Id.EARTH,   # 木克土
	Id.EARTH: Id.WATER,  # 土克水
	Id.WATER: Id.FIRE,   # 水克火
	Id.FIRE: Id.METAL,   # 火克金
}

## a 是否克制 b
static func counters(a: int, b: int) -> bool:
	return _COUNTERS.get(a) == b

## a 克制的那个势
static func counter_of(a: int) -> int:
	return _COUNTERS[a]
