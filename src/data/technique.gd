class_name Technique
extends Resource

## 招式（spec §2.2）。M0 用代码 new() 构造；M1+ 落成 .tres 由 inspector 调。
enum Type { MOVE, STRIKE, STANCE_SWITCH, FEINT, SPECIAL }

@export var id: StringName = &"unnamed"
@export var display_name: String = "未命名招式"
@export var type: Type = Type.STRIKE
## 所需距离档：0=近身 1=中距 2=远距（M0 仅记录，结算在 M1 距离门槛里用）
@export var required_range: int = 0
## 出招后进入的架势（MOVE 时保持原架势，调用方设为原值）
@export var resulting_stance: int = Stance.Id.METAL
## 揭晓优先级：速度高的先结算（spec §2.5）
@export var speed: int = 5
@export var base_damage: int = 0
## 造破绽值
@export var opening_dealt: int = 0
## MOVE 类型的格点位移
@export var move_delta: Vector2i = Vector2i.ZERO

## —— FEINT 完整语义（M2；design §2.3）——
## 诱饵架势：FEINT 出招者本回合对外显示的假架势；-1=非虚招/不伪装。
## Resolver 用 apparent_stance 作「感知架势」参与克制判断（对手按表象读）。
@export var apparent_stance: int = -1
## 对手上钩（按 apparent 针对了它）时，real 伤害倍率（惩罚）
@export var feint_bonus_mult: float = 1.5
## 对手识破（未针对 apparent）时，real 伤害倍率（落空感）
@export var feint_fail_mult: float = 0.7
## real 效果复用 base_damage / resulting_stance / required_range / opening_dealt（v1 = 伪装打击）

## [deprecated M2 unused] M0 两段式 Resource 骨架，保留字段不破坏旧测试，M2 不读不写。
@export var apparent: Resource
@export var real_effect: Resource
