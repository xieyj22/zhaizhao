class_name RangeBand
extends RefCounted

## 距离/范围门槛（spec §4）。距离 = 曼哈顿；required_range = 该招可达的最大档。
enum Id { CLOSE, MID, FAR }

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func band(d: int, t: Tuning) -> int:
	if d <= t.range_close_max:
		return Id.CLOSE
	if d <= t.range_mid_max:
		return Id.MID
	return Id.FAR

static func in_range(attacker_pos: Vector2i, target_pos: Vector2i, required_range: int, t: Tuning) -> bool:
	return band(distance(attacker_pos, target_pos), t) <= required_range
