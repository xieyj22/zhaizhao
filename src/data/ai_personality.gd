class_name AIPersonality
extends Resource

## L3 性格（design §5.1）。覆写 L1/L2 权重倍率 + 虚招倾向。M2 代码 new()/工厂；.tres 化留 M4。

@export var display_name: String = "通用"
@export var w_predict_mul: float = 1.0    # L2 反制权重倍率（智将>1，莽将≈0）
@export var feint_rate: float = 0.0       # 主动出虚招概率（诡将高）
@export var aggression: float = 1.0       # 侵略性：放大 opening/morale 维度
@export var caution: float = 1.0          # 龟缩度：放大 risk 维度
@export var top_n_mul: float = 1.0        # 冒险度：top-N 倍率（>1 更随机更冒险）

## 智将：死磕 L2，少主动虚招，稳重
static func brain() -> AIPersonality:
	var p := AIPersonality.new()
	p.display_name = "智将"
	p.w_predict_mul = 2.0
	p.feint_rate = 0.1
	p.aggression = 1.0
	p.caution = 1.2
	p.top_n_mul = 1.0
	return p

## 莽将：L1 碾压，高侵略，更随机
static func brute() -> AIPersonality:
	var p := AIPersonality.new()
	p.display_name = "莽将"
	p.w_predict_mul = 0.0
	p.feint_rate = 0.0
	p.aggression = 1.8
	p.caution = 0.5
	p.top_n_mul = 1.5
	return p

## 诡将：狂出虚招逼你读它
static func trick() -> AIPersonality:
	var p := AIPersonality.new()
	p.display_name = "诡将"
	p.w_predict_mul = 1.2
	p.feint_rate = 0.7
	p.aggression = 1.0
	p.caution = 1.0
	p.top_n_mul = 1.2
	return p
