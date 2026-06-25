class_name UnitState
extends RefCounted

## 单位战斗状态（spec §2.4 双系统：HP 管生死 + 破绽管节奏）。纯数据，JSON-safe。
var id: StringName = &"unit"
var team: int = 0
var hp: int = 10
var max_hp: int = 10
var opening: int = 0
var max_opening: int = 6
var stance: int = Stance.Id.METAL
var grid_pos: Vector2i = Vector2i.ZERO
## 0=E 1=S 2=W 3=N（顺时针）；背击加成 M1 实装，M0 留接口
var facing: int = 0
var guard_broken: bool = false
var alive: bool = true
## —— M4: boss 机制字段 ——
## frenzied 由 BossTrait.on_end_turn(frenzy) 置位（hp<50%）；resolver 读它把 dmg×1.5。
var frenzied: bool = false
## boss_id 标识 boss 单位（非 boss 留 ""），对应 BattleState.boss_traits 的 key。
var boss_id: String = ""
## —— M3: 由 battle_builder 构造时填充（不入 to_dict）——
var kit: Array = []   # Array[Technique]，战斗态，不序列化

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"team": team,
		"hp": hp,
		"max_hp": max_hp,
		"opening": opening,
		"max_opening": max_opening,
		"stance": stance,
		"grid_pos": [grid_pos.x, grid_pos.y],
		"facing": facing,
		"guard_broken": guard_broken,
		"alive": alive,
		"frenzied": frenzied,
		"boss_id": boss_id,
	}

static func from_dict(d: Dictionary) -> UnitState:
	var u := UnitState.new()
	u.id = StringName(d["id"])
	u.team = d["team"]
	u.hp = d["hp"]
	u.max_hp = d["max_hp"]
	u.opening = d["opening"]
	u.max_opening = d["max_opening"]
	u.stance = d["stance"]
	u.grid_pos = Vector2i(d["grid_pos"][0], d["grid_pos"][1])
	u.facing = d["facing"]
	u.guard_broken = d.get("guard_broken", false)
	u.alive = d.get("alive", true)
	u.frenzied = d.get("frenzied", false)
	u.boss_id = d.get("boss_id", "")
	return u
