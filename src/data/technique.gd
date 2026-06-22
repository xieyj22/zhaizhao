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

## —— FEINT 两段式骨架（spec §2.3；完整结算 M2）——
## 表象：对手读到的假招/假架势
@export var apparent: Resource
## 实情：揭晓时的真效果
@export var real_effect: Resource
