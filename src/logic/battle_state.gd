class_name BattleState
extends RefCounted

## 战场状态：单位列表 + 网格 + 回合数。JSON-safe。
var units: Array = []                      # Array[UnitState]
var grid_size: Vector2i = Vector2i(7, 7)
var turn: int = 0

func unit_at(p: Vector2i) -> UnitState:
	for u in units:
		if u.alive and u.grid_pos == p:
			return u
	return null

func clamp_to_grid(p: Vector2i) -> Vector2i:
	return Vector2i(clampi(p.x, 0, grid_size.x - 1), clampi(p.y, 0, grid_size.y - 1))

func alive_teams() -> Array:
	var teams: Dictionary = {}
	for u in units:
		if u.alive:
			teams[u.team] = true
	return teams.keys()

func is_over() -> bool:
	return alive_teams().size() <= 1

func to_dict() -> Dictionary:
	return {
		"grid_size": [grid_size.x, grid_size.y],
		"turn": turn,
		"units": units.map(func(u): return u.to_dict()),
	}

static func from_dict(d: Dictionary) -> BattleState:
	var s := BattleState.new()
	s.grid_size = Vector2i(d["grid_size"][0], d["grid_size"][1])
	s.turn = d["turn"]
	s.units = (d["units"] as Array).map(func(u): return UnitState.from_dict(u))
	return s
