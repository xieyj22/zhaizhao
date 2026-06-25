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

# —— 招募同袍（hub 运行时实装）——
# 玩家方站位槽（7×7 棋盘左半区 x∈[0,2]）。slot[0]=[1,3] 与主角固定 grid_pos 对齐（数据自洽守护）。
# 队友按 roster index 取槽，hub 传 idx，避免招募顺序错位。
const PLAYER_SLOTS: Array = [[1,3],[1,4],[2,3],[1,2],[2,4],[0,3],[2,2]]

# 派系 → 架势映射（按派系武学风格 + 招牌 resulting_stance 推导）。
# brain 派偏守势（WOOD/WATER），brute 派偏攻势（METAL/FIRE），trick 派折中。
# F6/F7 为设计推断（无显式文档），属 M3 调参面。
const FACTION_STANCE: Dictionary = {
	"F1": Stance.Id.METAL, "F2": Stance.Id.FIRE, "F3": Stance.Id.WOOD,
	"F4": Stance.Id.WATER, "F5": Stance.Id.FIRE, "F6": Stance.Id.WOOD,
	"F7": Stance.Id.METAL, "F8": Stance.Id.FIRE,
}
static func stance_for(faction_id: String) -> int:
	return int(FACTION_STANCE.get(faction_id, Stance.Id.METAL))

# 队友名（非战斗字段，固定无 RNG；M4 可扩派内多名池）。查表兜底"同袍"。
const ALLY_GIVEN_NAMES: Dictionary = {
	"F1":"照·寒锋", "F2":"锋·铁衣", "F3":"根·木客", "F4":"潮·墨客",
	"F5":"焰·火工", "F6":"踪·影卫", "F7":"枭·镖客",
}
