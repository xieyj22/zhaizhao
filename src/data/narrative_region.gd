class_name NarrativeRegion
extends RefCounted

## 区散文+章节过场（Wave2 spec §2.2）。region_id 与 CHAPTER_GEO 对齐。
const REGION_PROSE := {
	"chenjianggu": "沉剑谷不葬人，只葬剑。谷口第一柄剑插在何时，没人说得清，只知千百年里，败了的、心死了的、还债来的，都把剑扔了进来。剑锈在土里，剑意没锈，在雾底横冲直撞，五行乱了套：锐金忽而克不动盘根，流水反倒淹了烈火。走谷的人都说，这里的架势不讲道理，你按祖训去读势，势偏不按祖训走。雾是活的，一吞吐，整条谷就换了脾气。老辈人只劝一句：进谷别带好剑。它认。",
	# tingchao / yexiao / xueyi_zongtan / wuxiang — 批D 灌入
}
const REGION_CHAPTER := {"chenjianggu": 3, "tingchao": 2, "yexiao": 2, "xueyi_zongtan": 4, "wuxiang": 4}
const CHAPTER_INTERLUDES := {
	3: {"open": "第三章，沉剑谷。出了赤锋地界，风里的铁腥味变了，变成旧剑的锈气。晏九的赌局、莫青娘的药香都甩在身后，前头是谷口。剑鸣从雾底传上来，一声一声，像有人在很深的地方，把千百年前的旧账，一柄一柄地数。", "mid": "", "close": ""},
	# 1/2/4 — 批D 灌入
}

static func interlude(chapter: int, seg: String) -> String:
	var c: Dictionary = CHAPTER_INTERLUDES.get(chapter, {})
	return String(c.get(seg, ""))

static func prose(region_id: String) -> String:
	return String(REGION_PROSE.get(region_id, ""))
