extends Node

## 运行期会话单例（HUB ↔ battle 传 RunState + node_cfg）。autoload 注册为 MetaSession。
var current_run: RunState = null
var current_node_cfg: Dictionary = {}
var meta_state: MetaState = null
var last_battle_outcome: int = 0

func _ready() -> void:
	if meta_state == null:
		meta_state = MetaState.load_from()
