class_name BattleView
extends Node2D

var cell: int = 64
var grid_size: Vector2i = Vector2i(7, 7)
var state: BattleState

const TEAM_COLORS: Array = [Color(0.2, 0.6, 1.0), Color(1.0, 0.4, 0.3)]
const ROLE_COLORS: Array = [Color(1.0, 0.5, 0.3), Color(0.3, 0.7, 1.0), Color(0.7, 0.7, 0.7)]  # 攻/守/中

# —— juice（game-ui-design: motion 克制、accessibility 预留 reduce_motion）——
var floaters: Array = []              # 伤害飘字 {pos, text, color, size, age, life}
var shake: float = 0.0
var reduce_motion: bool = false
var _t: float = 0.0
var hp_white: Dictionary = {}         # 削切白条：id -> 显示 hp（lerp 慢追真实 hp）
var flashes: Dictionary = {}          # 受击闪白：pos_key -> 计时

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	# 飘字：上浮 + 淡出
	var alive: Array = []
	for f in floaters:
		f.age += delta
		if f.age < f.life:
			alive.append(f)
	floaters = alive
	# HP 削切白条：慢追真实 hp（受击时绿条瞬降，白条延迟追上）
	if state != null:
		for u in state.units:
			var key := String(u.id)
			var cur: float = float(hp_white.get(key, u.hp))
			hp_white[key] = lerpf(cur, float(u.hp), clampf(delta * 6.0, 0.0, 1.0))
	# 受击闪白衰减
	var fkeys: Array = flashes.keys()
	for k in fkeys:
		flashes[k] = float(flashes[k]) - delta
		if float(flashes[k]) <= 0.0:
			flashes.erase(k)
	# 震屏衰减 + 应用 position
	shake = maxf(0.0, shake - delta * 30.0)
	if reduce_motion or shake <= 0.0:
		position = Vector2.ZERO
	else:
		position = Vector2(randf_range(-1.0, 1.0) * shake, randf_range(-1.0, 1.0) * shake * 0.7)
	queue_redraw()

## 命中飘字。critical（崩溃翻倍）= 黄字 150% + 震屏
func spawn_floater(grid_pos: Vector2i, text: String, critical := false) -> void:
	floaters.append({
		"pos": Vector2(grid_pos.x * cell + cell / 2, grid_pos.y * cell),
		"text": text,
		"color": Color(1.2, 0.95, 0.2) if critical else Color(1.0, 1.0, 1.0),
		"size": 20 if critical else 13,
		"age": 0.0,
		"life": 1.0 if critical else 0.8,
	})
	if critical:
		add_shake(5.0)

## 受击闪白（命中瞬间方块叠白）
func flash_at(grid_pos: Vector2i) -> void:
	flashes["%d,%d" % [grid_pos.x, grid_pos.y]] = 0.18

func add_shake(amount: float) -> void:
	if not reduce_motion:
		shake = maxf(shake, amount)

func _draw() -> void:
	if state == null:
		return
	var grid_color := Color(0.4, 0.4, 0.4, 0.5)
	for x in grid_size.x + 1:
		draw_line(Vector2(x * cell, 0), Vector2(x * cell, grid_size.y * cell), grid_color)
	for y in grid_size.y + 1:
		draw_line(Vector2(0, y * cell), Vector2(grid_size.x * cell, y * cell), grid_color)
	for u in state.units:
		if not u.alive:
			continue
		var origin := Vector2(u.grid_pos.x * cell, u.grid_pos.y * cell)
		var col: Color = TEAM_COLORS[u.team % TEAM_COLORS.size()]
		draw_rect(Rect2(origin + Vector2(8, 8), Vector2(cell - 16, cell - 16)), col)
		# 描边：崩溃=红加粗；破绽警告(>=max-1)=闪红；否则角色色
		var edge_col: Color = ROLE_COLORS[Stance.role(u.stance)]
		var edge_w := 2.0
		if u.guard_broken:
			edge_col = Color(1.0, 0.15, 0.15)
			edge_w = 3.0
		elif u.opening >= u.max_opening - 1:
			var pulse := 0.5 + 0.5 * sin(_t * 8.0)
			edge_col = Color(1.0, 0.3, 0.2, 0.5 + 0.5 * pulse)
			edge_w = 2.5
		draw_rect(Rect2(origin + Vector2(6, 6), Vector2(cell - 12, cell - 12)), edge_col, false, edge_w)
		# 受击闪白叠层
		var fkey := "%d,%d" % [u.grid_pos.x, u.grid_pos.y]
		if flashes.has(fkey):
			var a: float = clampf(float(flashes[fkey]) / 0.18, 0.0, 1.0)
			draw_rect(Rect2(origin + Vector2(8, 8), Vector2(cell - 16, cell - 16)), Color(1, 1, 1, a * 0.8))
		# HP 条：白条（延迟追）+ 绿条（真实 hp）
		var hp_rect := Rect2(origin + Vector2(8, 2), Vector2(cell - 16, 4))
		var white_w := float(hp_white.get(String(u.id), u.hp)) / float(u.max_hp) * (cell - 16)
		draw_rect(hp_rect, Color(0.9, 0.9, 0.9))   # 底白条（削切）
		draw_rect(Rect2(origin + Vector2(8, 2), Vector2(white_w, 4)), Color(0.9, 0.9, 0.9))
		var hp_w := float(u.hp) / float(u.max_hp) * (cell - 16)
		draw_rect(Rect2(origin + Vector2(8, 2), Vector2(hp_w, 4)), Color(0.1, 0.9, 0.2))
		# 破绽条（橙）
		var op_w := float(u.opening) / float(max(1, u.max_opening)) * (cell - 16)
		draw_rect(Rect2(origin + Vector2(8, cell - 8), Vector2(op_w, 4)), Color(0.9, 0.6, 0.1))
		draw_string(ThemeDB.fallback_font, origin + Vector2(8, cell - 12), String(u.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	# 飘字（最上层）
	for f in floaters:
		var progress: float = f.age / f.life
		var y: float = f.pos.y - progress * 28.0
		var c: Color = f.color
		c.a = 1.0 - progress
		draw_string(ThemeDB.fallback_font, Vector2(f.pos.x, y), f.text, HORIZONTAL_ALIGNMENT_CENTER, -1, f.size, c)
