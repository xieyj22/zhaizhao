class_name TechniqueDB
extends RefCounted

## 招式查询层（M3；spec m3-tech §2.6）。懒加载 all_techniques() 建 id→Technique 索引。

static var _by_id: Dictionary = {}

static func _ensure() -> void:
	if not _by_id.is_empty(): return
	for t in TechniqueData.all_techniques():
		_by_id[StringName(t.id)] = t

## 按 id 查招式；无则返回 null。
## 注：方法名用 find 而非 get —— GDScript 解析 `Class.get(...)` 静态调用时
## 会与 Object.get() 内置方法冲突报 "Could not resolve external class member"。
static func find(id: StringName) -> Technique:
	_ensure()
	return _by_id.get(id)

## 从 id 池中筛出指定 tier 的子集（tier_of 默认 T1，故通用招落在 T1）。
static func tier_ids(pool: Array, tier: int) -> Array:
	return pool.filter(func(id): return TechniqueData.tier_of(StringName(id)) == tier)
