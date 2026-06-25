class_name BossConfig
extends RefCounted

## 8 boss 配置（M4 product §5.1）。trait 见 BossTrait。layer=6 为章4 mini-boss，7 为章末 boss。
const BOSS_CONFIG := {
	"hailianzheng": {"name":"赫连铮","title":"铁面","chapter":1,"layer":7,"personality":"brute","stance":Stance.Id.METAL,"hp_base":40,"kit":["chifeng_lianci","chifeng_yajin","xueyi_xuedao"],"trait":""},
	"moqingniang": {"name":"莫青娘","title":"白骨","chapter":2,"layer":7,"personality":"trick","stance":Stance.Id.WOOD,"hp_base":32,"kit":["huazong_zhuangtu","huazong_zhuanghuo"],"trait":""},
	"yanjiu": {"name":"晏九","title":"笑面","chapter":2,"layer":7,"personality":"brain","stance":Stance.Id.WATER,"hp_base":30,"kit":["tingchao_yuanchao","tingchao_xieli"],"trait":""},
	"zongzhenglie": {"name":"宗政烈","title":"裂碑","chapter":3,"layer":7,"personality":"brute","stance":Stance.Id.METAL,"hp_base":45,"kit":["chifeng_lianci","chifeng_yajin"],"trait":"iron_body"},
	"peiyuan": {"name":"裴渊","title":"影狐","chapter":3,"layer":7,"personality":"trick","stance":Stance.Id.WOOD,"hp_base":38,"kit":["huazong_zhuangtu","huazong_zhuanghuo"],"trait":"chain_feint"},
	"sikongyi": {"name":"司空弈","title":"棋仙","chapter":4,"layer":6,"personality":"brain","stance":Stance.Id.WATER,"hp_base":50,"kit":["tingchao_yuanchao","tingchao_xieli"],"trait":"mind_eye"},
	"leiwanjun": {"name":"雷万钧","title":"焚天","chapter":4,"layer":6,"personality":"brute","stance":Stance.Id.FIRE,"hp_base":48,"kit":["lieyan_liaoyuan","lieyan_huoqi"],"trait":"frenzy"},
	"yanwujiu": {"name":"颜无咎","title":"血尊","chapter":4,"layer":7,"personality":"brain_trick_hybrid","stance":Stance.Id.METAL,"hp_base":65,"kit":["xueyi_xuedao","xueyi_zhuangjin","jingzhao_chuzhao"],"trait":"blood_drain"},
}

## 按 id 取 boss 配置（未找到返回空 Dictionary）。
## 注：不命名为 get()，会覆盖 Object.get() 原生方法且触发 warn-as-error（M3 起严格）。
static func get_boss(boss_id: String) -> Dictionary:
	return BOSS_CONFIG.get(boss_id, {})

## 该章该层的 boss id 列表（map_generator 用）。
static func boss_ids_for(chapter: int, layer: int) -> Array:
	var out: Array = []
	for bid in BOSS_CONFIG:
		var b: Dictionary = BOSS_CONFIG[bid]
		if int(b["chapter"]) == chapter and int(b["layer"]) == layer:
			out.append(bid)
	return out
