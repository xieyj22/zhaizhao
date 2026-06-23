class_name PlayerModel
extends RefCounted

## L2 玩家建模（design §5.1 命门）。条件频率表：5 特征 → 招式 4 大类计数。
## 纯逻辑、JSON-safe、确定性。每 AI 方一个，建模对方整队出招分布。

const _BUCKETS: Array = [
	Technique.Type.MOVE, Technique.Type.STRIKE,
	Technique.Type.STANCE_SWITCH, Technique.Type.FEINT,
]

## 特征编码 String → {tech_type_int: count}
var table: Dictionary = {}
var total: int = 0
## 记录每单位上回合出的招大类（featurize 的第 4 特征来源）
var last_type_by_unit: Dictionary = {}   # String(unit.id) -> int (Technique.Type)

# ---------- 特征 ----------
## 5 特征编码（design §5.4 起步手挑）：role|band|phase|last|opening_band
func featurize(observed: UnitState, state: BattleState, tuning: Tuning) -> String:
	var role := Stance.role(observed.stance)
	var band := _nearest_foe_band(observed, state, tuning)
	var phase := Morale.phase(state.turn, tuning)
	var last: int = last_type_by_unit.get(String(observed.id), -1)
	var ob := _opening_band(observed)
	return "%d|%d|%d|%d|%d" % [role, band, phase, last, ob]

static func _nearest_foe_band(observed: UnitState, state: BattleState, tuning: Tuning) -> int:
	var best := 1 << 30
	for u in state.units:
		if u.team != observed.team and u.alive:
			best = mini(best, RangeBand.distance(observed.grid_pos, u.grid_pos))
	if best == (1 << 30):
		return RangeBand.Id.FAR
	return RangeBand.band(best, tuning)

static func _opening_band(u: UnitState) -> int:
	var mx := maxi(1, u.max_opening)
	if u.opening < 2:
		return 0
	if u.opening >= mx - 1:
		return 2
	return 1

# ---------- 更新 ----------
## 记一次观察。unit_id 必须等于 String(unit.id)（与 featurize 的读取 key 对齐），
## 否则 last_type_by_unit 不匹配 → 第 4 特征(last) 恒为 -1。调用方须统一传 String(unit.id)。
func observe(key: String, tech_type: int, unit_id: String) -> void:
	var bucket: Dictionary = table.get(key, {})
	bucket[tech_type] = bucket.get(tech_type, 0) + 1
	table[key] = bucket
	total += 1
	last_type_by_unit[unit_id] = tech_type

# ---------- 查询 ----------
func predict(key: String) -> Dictionary:
	var bucket: Dictionary = table.get(key, {})
	var n := 0
	for v in bucket.values():
		n += v
	var K := _BUCKETS.size()
	var out := {}
	for tt in _BUCKETS:
		out[tt] = (float(bucket.get(tt, 0)) + 1.0) / float(n + K)
	return out

func confidence(key: String, tuning: Tuning) -> float:
	var bucket: Dictionary = table.get(key, {})
	var n := 0
	for v in bucket.values():
		n += v
	if n < tuning.l2_min_samples:
		return 0.0
	var mx := 0.0
	for v in predict(key).values():
		mx = maxf(mx, v)
	return minf(mx, tuning.l2_confidence_cap)

func argmax_type(key: String) -> int:
	# 同分时按 _BUCKETS 插入序破平（predict 返回的 Dictionary 保持该序）→ 确定性。
	var pred := predict(key)
	var best_t := -1
	var best_p := -1.0
	for tt in pred.keys():
		if pred[tt] > best_p:
			best_p = pred[tt]
			best_t = tt
	return best_t

# ---------- JSON-safe ----------
func to_dict() -> Dictionary:
	var serial_table := {}
	for k in table.keys():
		var bucket: Dictionary = table[k]
		var sb := {}
		for tk in bucket.keys():
			sb[str(tk)] = bucket[tk]
		serial_table[k] = sb
	return {"table": serial_table, "total": total, "last": last_type_by_unit.duplicate()}

static func from_dict(d: Dictionary) -> PlayerModel:
	var pm := PlayerModel.new()
	pm.total = int(d.get("total", 0))
	var st: Dictionary = d.get("table", {})
	for k in st.keys():
		var sb: Dictionary = st[k]
		var bucket := {}
		for tk in sb.keys():
			bucket[int(tk)] = sb[tk]
		pm.table[k] = bucket
	pm.last_type_by_unit = (d.get("last", {}) as Dictionary).duplicate()
	return pm
