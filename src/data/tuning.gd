class_name Tuning
extends Resource

## 全局可调常数（spec §8 数据驱动；M0 先 new()，M1 落 .tres）
@export var opening_damage_mult: float = 1.0    # 破绽每点放大多少伤害
@export var opening_decay_per_turn: int = 1     # 破绽每回合自然回落
@export var counter_bonus_damage: int = 2       # 架势克制方增伤
@export var counter_bonus_opening: int = 1      # 架势克制方额外造破绽
@export var max_opening_default: int = 6        # 破绽满 → 招架崩溃
@export var guard_break_stun_turns: int = 1     # 崩溃后眩晕回合（M1 实装 stun，M0 仅记录）
