class_name Morale
extends RefCounted

## 战意（防龟缩，缓升曲线，spec §2）。纯函数，对称影响双方。

enum Phase { NORMAL, ACTIVE, ESCALATED }

static func accumulation(turn: int, t: Tuning) -> int:
	if turn >= t.morale_turn2:
		return t.morale_accum2
	if turn >= t.morale_turn1:
		return t.morale_accum1
	return 0

static func decay_modifier(turn: int, t: Tuning) -> int:
	return t.morale_decay_reduction if turn >= t.morale_turn1 else 0

static func phase(turn: int, t: Tuning) -> int:
	if turn >= t.morale_turn2:
		return Phase.ESCALATED
	if turn >= t.morale_turn1:
		return Phase.ACTIVE
	return Phase.NORMAL
