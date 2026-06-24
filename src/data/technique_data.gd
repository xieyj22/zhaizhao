class_name TechniqueData
extends RefCounted

## 32 招注册（M3；spec m3-tech §2.5/§2.6）。通用 14 经 TechniqueKit 工厂；招牌 16 + 隐藏 2 经数据表。
## 这是 tech spec 钦定的「fallback 代码工厂」模式；per-move .tres 留 M4。
## 注：const Dictionary 字面量里 key 必须用字符串字面量（"id"）—— GDScript 不像
## 某些语言会把 bare word 自动 stringify 成 key；bare `id:` 会被当成标识符解析报错。
const _SIGNATURE := [
	# F1 镜照门
	{"id":&"jingzhao_chuzhao", "name":"镜照·初照", "type":"STRIKE", "range":1, "dmg":4, "spd":6, "op":1, "stance":Stance.Id.EARTH, "fac":"F1", "tier":2},
	{"id":&"jingzhao_yingzhao", "name":"镜照·映照", "type":"STANCE_SWITCH", "range":0, "dmg":0, "spd":7, "op":0, "stance":Stance.Id.EARTH, "fac":"F1", "tier":2},
	# F2 赤锋军门
	{"id":&"chifeng_lianci", "name":"赤锋·连刺", "type":"STRIKE", "range":0, "dmg":6, "spd":5, "op":2, "stance":Stance.Id.METAL, "fac":"F2", "tier":2},
	{"id":&"chifeng_yajin", "name":"赤锋·压阵", "type":"MOVE", "range":0, "dmg":0, "spd":6, "op":0, "stance":-1, "mv":Vector2i(1,0), "fac":"F2", "tier":2},
	# F3 盘根寨
	{"id":&"pangen_lagen", "name":"盘根·老树", "type":"STANCE_SWITCH", "range":0, "dmg":0, "spd":7, "op":0, "stance":Stance.Id.WOOD, "fac":"F3", "tier":2},
	{"id":&"pangen_jiajia", "name":"盘根·架架", "type":"STRIKE", "range":0, "dmg":4, "spd":5, "op":1, "stance":Stance.Id.WOOD, "fac":"F3", "tier":2},
	# F4 听潮书院
	{"id":&"tingchao_yuanchao", "name":"听潮·远潮", "type":"STRIKE", "range":2, "dmg":3, "spd":5, "op":1, "stance":Stance.Id.WATER, "fac":"F4", "tier":2},
	{"id":&"tingchao_xieli", "name":"听潮·卸力", "type":"MOVE", "range":0, "dmg":0, "spd":6, "op":0, "stance":-1, "mv":Vector2i(-1,0), "fac":"F4", "tier":2},
	# F5 烈焰堂
	{"id":&"lieyan_liaoyuan", "name":"烈焰·燎原", "type":"STRIKE", "range":1, "dmg":7, "spd":5, "op":2, "stance":Stance.Id.FIRE, "fac":"F5", "tier":2},
	{"id":&"lieyan_huoqi", "name":"烈焰·破空", "type":"STRIKE", "range":2, "dmg":4, "spd":6, "op":1, "stance":Stance.Id.FIRE, "fac":"F5", "tier":2},
	# F6 幻踪门（FEINT；resulting_stance=-1 保持，apparent_stance 独立）
	{"id":&"huazong_zhuangtu", "name":"幻踪·装土", "type":"FEINT", "range":2, "dmg":4, "spd":5, "op":1, "stance":-1, "apparent":Stance.Id.EARTH, "fac":"F6", "tier":2},
	{"id":&"huazong_zhuanghuo", "name":"幻踪·装火", "type":"FEINT", "range":1, "dmg":5, "spd":5, "op":1, "stance":-1, "apparent":Stance.Id.FIRE, "fac":"F6", "tier":2},
	# F7 夜枭镖局
	{"id":&"yexiao_tujin", "name":"夜枭·突进", "type":"MOVE", "range":0, "dmg":0, "spd":7, "op":0, "stance":-1, "mv":Vector2i(1,0), "fac":"F7", "tier":2},
	{"id":&"yexiao_liuzhuan", "name":"夜枭·流转", "type":"STANCE_SWITCH", "range":0, "dmg":0, "spd":7, "op":0, "stance":Stance.Id.EARTH, "fac":"F7", "tier":2},
	# F8 血衣教（tier 3）
	{"id":&"xueyi_xuedao", "name":"血衣·血祭", "type":"STRIKE", "range":0, "dmg":7, "spd":5, "op":2, "stance":Stance.Id.METAL, "fac":"F8", "tier":3},
	{"id":&"xueyi_zhuangjin", "name":"血衣·装金", "type":"FEINT", "range":1, "dmg":5, "spd":5, "op":1, "stance":-1, "apparent":Stance.Id.METAL, "fac":"F8", "tier":3},
]
const _HIDDEN := [
	{"id":&"mingjing_yizhao", "name":"明镜·遗照", "type":"STANCE_SWITCH", "range":0, "dmg":0, "spd":7, "op":0, "stance":Stance.Id.WATER, "fac":"F1", "tier":3},
	{"id":&"wuming_wuxiang", "name":"无名·无相", "type":"SPECIAL", "range":0, "dmg":0, "spd":5, "op":0, "stance":Stance.Id.EARTH, "fac":"F1", "tier":3},
]

static func all_techniques() -> Array:
	var out: Array = []
	# 通用 14：3 打击 + 4 步法 + 5 切势 + 2 虚招预设（经 TechniqueKit 工厂）
	for t in [TechniqueKit.strike_close(), TechniqueKit.strike_mid(), TechniqueKit.strike_far(),
			TechniqueKit.step(1,0), TechniqueKit.step(-1,0), TechniqueKit.step(0,1), TechniqueKit.step(0,-1),
			TechniqueKit.switch_to(0), TechniqueKit.switch_to(1), TechniqueKit.switch_to(2),
			TechniqueKit.switch_to(3), TechniqueKit.switch_to(4)]:
		out.append(t)
	out.append_array(TechniqueKit.feint_presets())
	# 招牌 16 + 隐藏 2（经数据表）
	for d in _SIGNATURE + _HIDDEN:
		out.append(_from_data(d))
	return out   # 12 + 2 + 16 + 2 = 32

## 从数据字典构造 Technique（招牌/隐藏招；通用招走 TechniqueKit 工厂）。
static func _from_data(d: Dictionary) -> Technique:
	var t := Technique.new()
	t.id = d.id; t.display_name = d.name; t.type = _type(d.type)
	t.required_range = d.range; t.base_damage = d.dmg; t.speed = d.spd
	t.opening_dealt = d.op; t.resulting_stance = d.stance
	if d.type == "MOVE" and d.has("mv"):
		t.move_delta = d.mv
	if d.type == "FEINT":
		t.apparent_stance = d.apparent   # 诱饵架势独立（T3：feint resulting_stance=-1 保持）
		t.feint_bonus_mult = 1.5; t.feint_fail_mult = 0.7
	return t

static func _type(s: String) -> Technique.Type:
	match s:
		"STRIKE": return Technique.Type.STRIKE
		"MOVE": return Technique.Type.MOVE
		"STANCE_SWITCH": return Technique.Type.STANCE_SWITCH
		"FEINT": return Technique.Type.FEINT
		_: return Technique.Type.SPECIAL

## 招牌/隐藏招的 tier 来自数据表；通用招默认 T1。
static func tier_of(id: StringName) -> int:
	for d in _SIGNATURE: if d.id == id: return d.tier
	for d in _HIDDEN: if d.id == id: return d.tier
	return 1   # 通用招默认 T1
