extends Node

## 运行期会话单例（HUB ↔ battle 传 RunState + node_cfg）。autoload 注册为 MetaSession。
var current_run: RunState = null
var current_node_cfg: Dictionary = {}
var meta_state: MetaState = null
var last_battle_outcome: int = 0
## reduce_motion 跨战斗持久（a11y）：BattleView 每场 new() 会重置实例字段，
## 故真实态存此 autoload，battle.gd 同步给 view。不落盘（本会话内存态）。
var reduce_motion: bool = false

func _ready() -> void:
	if meta_state == null:
		meta_state = MetaState.load_from()
