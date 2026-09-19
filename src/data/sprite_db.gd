class_name SpriteDB
extends RefCounted

## 单位/地形 → sprite 路径映射（m4c spec §4.5）。
## 优先级：boss_id → 主角(id=="protagonist") → side+faction → 空串（渲染回退色块）。
## 运行时 load+缓存；资产缺失不炸（ResourceLoader.exists 门）。
const BOSS_PATHS := {
	"hailianzheng": "res://assets/sprites/boss/hailianzheng.png",
	"moqingniang": "res://assets/sprites/boss/moqingniang.png",
	"yanjiu": "res://assets/sprites/boss/yanjiu.png",
	"zongzhenglie": "res://assets/sprites/boss/zongzhenglie.png",
	"peiyuan": "res://assets/sprites/boss/peiyuan.png",
	"sikongyi": "res://assets/sprites/boss/sikongyi.png",
	"leiwanjun": "res://assets/sprites/boss/leiwanjun.png",
	"yanwujiu": "res://assets/sprites/boss/yanwujiu.png",
}
const HERO_PATH := "res://assets/sprites/hero/protagonist.png"
const ENEMY_PATHS := {
	"F1": "res://assets/sprites/enemy/F1.png", "F2": "res://assets/sprites/enemy/F2.png",
	"F3": "res://assets/sprites/enemy/F3.png", "F4": "res://assets/sprites/enemy/F4.png",
	"F5": "res://assets/sprites/enemy/F5.png", "F6": "res://assets/sprites/enemy/F6.png",
	"F7": "res://assets/sprites/enemy/F7.png", "F8": "res://assets/sprites/enemy/F8.png",
}
const ALLY_PATHS := {
	"F1": "res://assets/sprites/ally/F1.png", "F2": "res://assets/sprites/ally/F2.png",
	"F3": "res://assets/sprites/ally/F3.png", "F4": "res://assets/sprites/ally/F4.png",
	"F5": "res://assets/sprites/ally/F5.png", "F6": "res://assets/sprites/ally/F6.png",
	"F7": "res://assets/sprites/ally/F7.png", "F8": "res://assets/sprites/ally/F8.png",
}
const TERRAIN_PATHS := {
	TerrainRules.OBSTACLE: "res://assets/sprites/terrain/obstacle.png",
	TerrainRules.WATER: "res://assets/sprites/terrain/water.png",
	TerrainRules.HIGHLAND: "res://assets/sprites/terrain/highland.png",
	TerrainRules.HAZARD: "res://assets/sprites/terrain/hazard.png",
	"plain": "res://assets/sprites/terrain/plain.png",
}

static var _cache := {}

static func path_for(unit: UnitState) -> String:
	if unit.boss_id != "" and BOSS_PATHS.has(unit.boss_id):
		return String(BOSS_PATHS[unit.boss_id])
	if String(unit.id) == "protagonist":
		return HERO_PATH
	var side: Dictionary = ENEMY_PATHS if unit.team == 1 else ALLY_PATHS
	if unit.faction != "" and side.has(unit.faction):
		return String(side[unit.faction])
	return ""

static func texture_for(unit: UnitState) -> Texture2D:
	return _tex(path_for(unit))

static func terrain_texture(cell_type: String) -> Texture2D:
	if cell_type == "" or not TERRAIN_PATHS.has(cell_type):
		return null
	return _tex(String(TERRAIN_PATHS[cell_type]))

static func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_cache[path] = t
	return t
