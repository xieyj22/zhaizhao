class_name BattleView
extends Node2D

var cell: int = 64
var grid_size: Vector2i = Vector2i(7, 7)
var state: BattleState

const TEAM_COLORS: Array = [Color(0.2, 0.6, 1.0), Color(1.0, 0.4, 0.3)]
const ROLE_COLORS: Array = [Color(1.0, 0.5, 0.3), Color(0.3, 0.7, 1.0), Color(0.7, 0.7, 0.7)]  # 攻/守/中

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
		# 方块（团队色）+ 角色描边（攻守中色）
		draw_rect(Rect2(origin + Vector2(8, 8), Vector2(cell - 16, cell - 16)), col)
		var role_col: Color = ROLE_COLORS[Stance.role(u.stance)]
		draw_rect(Rect2(origin + Vector2(6, 6), Vector2(cell - 12, cell - 12)), role_col, false, 2.0)
		# HP 条（绿）+ 破绽条（橙）
		var hp_w := float(u.hp) / float(u.max_hp) * (cell - 16)
		draw_rect(Rect2(origin + Vector2(8, 2), Vector2(hp_w, 4)), Color(0.1, 0.9, 0.2))
		var op_w := float(u.opening) / float(max(1, u.max_opening)) * (cell - 16)
		draw_rect(Rect2(origin + Vector2(8, cell - 8), Vector2(op_w, 4)), Color(0.9, 0.6, 0.1))
		# 名字（4.7: Node2D 无 get_theme_default_font()，用 ThemeDB.fallback_font）
		draw_string(ThemeDB.fallback_font, origin + Vector2(8, cell - 12), String(u.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
