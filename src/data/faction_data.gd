class_name FactionData
extends RefCounted

## 8 门派数据（M3；T2 factions 文档）。关系值从"主角=镜照门 F1"视角。
const FACTIONS := ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"]
const NAMES := {
	"F1":"镜照门", "F2":"赤锋军门", "F3":"盘根寨", "F4":"听潮书院",
	"F5":"烈焰堂", "F6":"幻踪门", "F7":"夜枭镖局", "F8":"血衣教",
}
# 性格倾向（T2 §性格映射）：brain/brute/trick
const _TENDENCY := {
	"F1":"brain", "F2":"brute", "F3":"brain", "F4":"brain",
	"F5":"brute", "F6":"trick", "F7":"trick", "F8":"brute",
}
# 各派招牌招 id（队友 kit 用，T3 §5.2；与 TechniqueData 的 id 一致）
const SIGNATURE_KITS := {
	"F1":["jingzhao_chuzhao","jingzhao_yingzhao"],
	"F2":["chifeng_lianci","chifeng_yajin"],
	"F3":["pangen_lagen","pangen_jiajia"],
	"F4":["tingchao_yuanchao","tingchao_xieli"],
	"F5":["lieyan_liaoyuan","lieyan_huoqi"],
	"F6":["huazong_zhuangtu","huazong_zhuanghuo"],
	"F7":["yexiao_tujin","yexiao_liuzhuan"],
	"F8":["xueyi_xuedao","xueyi_zhuangjin"],
}

## 初始关系矩阵（主角=F1 视角；F4 暗盟 +40，F8 死敌 -100，其余 0）
static func initial_relations() -> Dictionary:
	var r := {}
	for f in FACTIONS: r[f] = 0
	r["F4"] = 40
	r["F8"] = -100
	return r

## 可招募派（F1–F7；F8 血衣教不可招募）
static func recruit_factions() -> Array:
	return ["F1","F2","F3","F4","F5","F6","F7"]

static func tendency(faction_id: String) -> String:
	return _TENDENCY.get(faction_id, "brain")
