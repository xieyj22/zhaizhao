class_name Stance
extends RefCounted

## 5 势成环（M0 占位名 = 五行）+ 攻守角色（M1）。
enum Id { METAL, WOOD, EARTH, WATER, FIRE }
const ALL: Array = [Id.METAL, Id.WOOD, Id.EARTH, Id.WATER, Id.FIRE]

const _COUNTERS: Dictionary = {
	Id.METAL: Id.WOOD, Id.WOOD: Id.EARTH, Id.EARTH: Id.WATER,
	Id.WATER: Id.FIRE, Id.FIRE: Id.METAL,
}

static func counters(a: int, b: int) -> bool:
	return _COUNTERS.get(a) == b

static func counter_of(a: int) -> int:
	return _COUNTERS[a]

## —— M1: 攻守角色（spec §3）。占位分配，正式名/分配待 worldbuilder。——
enum Role { OFFENSIVE, DEFENSIVE, NEUTRAL }
const ROLE: Dictionary = {
	Id.METAL: Role.OFFENSIVE, Id.FIRE: Role.OFFENSIVE,
	Id.WOOD: Role.DEFENSIVE, Id.WATER: Role.DEFENSIVE,
	Id.EARTH: Role.NEUTRAL,
}
static func role(s: int) -> int:
	return ROLE[s]
