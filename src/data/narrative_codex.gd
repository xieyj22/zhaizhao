class_name NarrativeCodex
extends RefCounted

## codex 条目（Wave2 spec §2.3）。仅山河志+武道志；人物志由 hub 从 NarrativeBoss 动态生成。
## 山河志条目不带 body 带 region_id（正文单一真源=REGION_PROSE）。
const CODEX_ENTRIES := [
	{"id": "geo_chenjianggu", "category": "山河志", "title": "沉剑谷", "region_id": "chenjianggu",
	 "unlock": {"type": "chapter_reached", "key": 3}},
	{"id": "geo_tingchao", "category": "山河志", "title": "听潮", "region_id": "tingchao",
	 "unlock": {"type": "chapter_reached", "key": 2}},
	{"id": "geo_yexiao", "category": "山河志", "title": "夜枭", "region_id": "yexiao",
	 "unlock": {"type": "chapter_reached", "key": 2}},
	{"id": "geo_xueyi_zongtan", "category": "山河志", "title": "血衣总坛", "region_id": "xueyi_zongtan",
	 "unlock": {"type": "chapter_reached", "key": 4}},
	{"id": "geo_wuxiang", "category": "山河志", "title": "无相原", "region_id": "wuxiang",
	 "unlock": {"type": "chapter_reached", "key": 4}},
	{"id": "lore_daotong_1", "category": "武道志", "title": "道统之争·上", "body": "（批E）",
	 "unlock": {"type": "always", "key": ""}},
]
