class_name Tuning
extends Resource

## —— M0 既有 ——
@export var opening_damage_mult: float = 1.0
@export var opening_decay_per_turn: int = 1
@export var counter_bonus_damage: int = 2
@export var counter_bonus_opening: int = 1
@export var max_opening_default: int = 6
@export var guard_break_stun_turns: int = 1

## —— M1: 战意（防龟缩，缓升曲线，spec §2/§5）——
@export var morale_turn1: int = 5          # turn≥5：战意 ACTIVE
@export var morale_accum1: int = 1         #   每回合全存活单位 +1 破绽
@export var morale_decay_reduction: int = 1 #   回落量 −1
@export var morale_turn2: int = 8          # turn≥8：ESCALATED
@export var morale_accum2: int = 2         #   每回合 +2 破绽
@export var morale_cap_turn: int = 12      # turn≥12 且无胜方 → DRAW

## —— M1: 架势角色（spec §3）——
@export var defensive_decay_bonus: int = 1  # 守势：回落 +1/回合
@export var offensive_self_opening: int = 1 # 攻势：自身破绽 +1/回合

## —— M1: 距离带（spec §4）——
@export var range_close_max: int = 1        # 曼哈顿距离 ≤1 = CLOSE
@export var range_mid_max: int = 3          # ≤3 = MID；>3 = FAR

## —— M1: L1 AI 权重（spec §6；M2 的 AIPersonality 会覆写）——
@export var ai_w_opening: float = 1.0
@export var ai_w_risk: float = 0.5
@export var ai_w_position: float = 0.3
@export var ai_w_morale: float = 0.8
@export var ai_kill_bonus: float = 10.0
@export var ai_top_n: int = 3

## —— M2: L2 玩家建模（spec §5；起步手挑特征，命门）——
@export var ai_w_predict: float = 3.0           # L2 反制维度权重（被 AIPersonality.w_predict_mul 缩放）；3.0 让 brain 的预测反制能压过 L1 opening 价值
@export var l2_min_samples: int = 3             # 样本不足此数 → predict 贡献归零，纯走 L1
@export var l2_confidence_cap: float = 0.65     # 预测最大概率封顶 → 永远 ≥35% 留给虚招反制出口（防开挂感）

## —— M3.5: 重玩多样性调参面（HP attrition + 信用稀缺；spec B.3）——
@export var rest_cap_per_chapter: int = 3          # 镖局休整上限/章（T10f 调平：2→3）
@export var credit_service_cost: int = 8           # 镖局服务单价（休整/升级/黑市）
@export var credit_income_chapter1: int = 25       # 章 1 信用产出（~2-4 次服务/run）
