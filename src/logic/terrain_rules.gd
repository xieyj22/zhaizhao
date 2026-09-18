class_name TerrainRules
extends RefCounted

## 格级地形规则（m4c spec §2.3）。纯函数；空 terrain 全部旁路（边界守护）。
const OBSTACLE := "obstacle"
const WATER := "water"
const HIGHLAND := "highland"
const HAZARD := "hazard"

static func key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func at(terrain: Dictionary, cell: Vector2i) -> String:
	return String(terrain.get(key(cell.x, cell.y), ""))

static func blocks_move(terrain: Dictionary, cell: Vector2i) -> bool:
	return at(terrain, cell) == OBSTACLE

static func is_water(terrain: Dictionary, cell: Vector2i) -> bool:
	return at(terrain, cell) == WATER

static func is_highland(terrain: Dictionary, cell: Vector2i) -> bool:
	return at(terrain, cell) == HIGHLAND

static func is_hazard(terrain: Dictionary, cell: Vector2i) -> bool:
	return at(terrain, cell) == HAZARD

static func speed_delta(terrain: Dictionary, cell: Vector2i) -> int:
	return -1 if is_water(terrain, cell) else 0
