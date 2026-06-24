class_name BattleState
extends RefCounted

enum Outcome { ONGOING, TEAM0_WIN, TEAM1_WIN, DRAW }

## 战场状态：单位列表 + 网格 + 回合数。JSON-safe。
var units: Array = []                      # Array[UnitState]
var grid_size: Vector2i = Vector2i(7, 7)
var turn: int = 0
var hazard_modifiers: Dictionary = {}      # M3 险地修饰符（chaos/ban_close/imbalance）；空=无（与 M0-M2 一致）

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

## M1：含平局的终局判定（spec §5）。is_over() 不含 DRAW，故 M1 用 outcome()!=ONGOING 判终止。
func outcome(t: Tuning) -> int:
	var teams := alive_teams()
	if teams.size() >= 2:
		return Outcome.ONGOING if turn < t.morale_cap_turn else Outcome.DRAW
	if teams.is_empty():
		return Outcome.DRAW
	return Outcome.TEAM0_WIN if teams[0] == 0 else Outcome.TEAM1_WIN

func to_dict() -> Dictionary:
	return {
		"grid_size": [grid_size.x, grid_size.y],
		"turn": turn,
		"units": units.map(func(u): return u.to_dict()),
		"hazard_modifiers": hazard_modifiers,
	}

static func from_dict(d: Dictionary) -> BattleState:
	var s := BattleState.new()
	s.grid_size = Vector2i(d["grid_size"][0], d["grid_size"][1])
	s.turn = d["turn"]
	s.units = (d["units"] as Array).map(func(u): return UnitState.from_dict(u))
	s.hazard_modifiers = d.get("hazard_modifiers", {})
	return s
