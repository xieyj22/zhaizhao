extends Node

## 运行期会话单例（HUB ↔ battle 传 RunState + node_cfg）。autoload 注册为 MetaSession。
var current_run: RunState = null
var current_node_cfg: Dictionary = {}
var meta_state: MetaState = null
var last_battle_outcome: int = 0
## 进战前的 current_node_id 快照（撤退时回到此位置——本场不算，玩家可换打别的节点）。
var previous_node_id: String = ""
## reduce_motion 跨战斗持久（a11y）：BattleView 每场 new() 会重置实例字段，
## 故真实态存此 autoload，battle.gd 同步给 view。不落盘（本会话内存态）。
var reduce_motion: bool = false
## Wave2 codex：上次 hub 展示时的已解锁数（-1=未初始化，首次不报新增）。会话内存态。
var codex_seen_count: int = -1

func _ready() -> void:
	if meta_state == null:
		meta_state = MetaState.load_from()
