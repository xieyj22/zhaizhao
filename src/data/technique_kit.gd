class_name TechniqueKit
extends RefCounted

## 共享招式工厂（玩家与 AI 共用，取代场景硬编码，spec §7）。.tres 化留 M4。
## 约定：MOVE 的 resulting_stance = -1（保持当前架势，Resolver 据此跳过架势赋值）。

static func strike_close() -> Technique:
	var t := Technique.new()
	t.id = &"strike_close"; t.display_name = "近打"
	t.type = Technique.Type.STRIKE
	t.required_range = RangeBand.Id.CLOSE
	t.base_damage = 5; t.speed = 5; t.opening_dealt = 1
	t.resulting_stance = Stance.Id.METAL   # 攻势
	return t

static func strike_mid() -> Technique:
	var t := Technique.new()
	t.id = &"strike_mid"; t.display_name = "中打"
	t.type = Technique.Type.STRIKE
	t.required_range = RangeBand.Id.MID
	t.base_damage = 4; t.speed = 5; t.opening_dealt = 1
	t.resulting_stance = Stance.Id.FIRE    # 攻势
	return t

static func strike_far() -> Technique:
	var t := Technique.new()
	t.id = &"strike_far"; t.display_name = "远打"
	t.type = Technique.Type.STRIKE
	t.required_range = RangeBand.Id.FAR
	t.base_damage = 3; t.speed = 5; t.opening_dealt = 1
	t.resulting_stance = Stance.Id.WATER   # 守势（远程偏稳）
	return t

static func step(dx: int, dy: int) -> Technique:
	var t := Technique.new()
	t.id = &"step"; t.display_name = "进退步"
	t.type = Technique.Type.MOVE
	t.required_range = 0
	t.speed = 6; t.move_delta = Vector2i(dx, dy)
	t.resulting_stance = -1   # 保持当前架势
	return t

static func switch_to(s: int) -> Technique:
	var t := Technique.new()
	t.id = StringName("switch_%d" % s); t.display_name = "切架势"
	t.type = Technique.Type.STANCE_SWITCH
	t.required_range = 0
	t.speed = 7; t.resulting_stance = s
	return t

## 伪装打击虚招（design §2.3）：apparent=诱饵架势，real 打击复用 base_damage
static func feint_strike(apparent: int, real_dmg := 4, real_stance := -1) -> Technique:
	var t := Technique.new()
	t.id = &"feint_strike"; t.display_name = "虚招·诱打"
	t.type = Technique.Type.FEINT
	t.required_range = RangeBand.Id.FAR
	t.base_damage = real_dmg; t.speed = 5; t.opening_dealt = 1
	t.resulting_stance = real_stance   # -1 = 保持
	t.apparent_stance = apparent
	t.feint_bonus_mult = 1.5; t.feint_fail_mult = 0.7
	return t

## M1 通用 kit：3 打击 + 4 方向移动 + 5 切架势。
static func default_kit() -> Array:
	var kit: Array = []
	kit.append(strike_close())
	kit.append(strike_mid())
	kit.append(strike_far())
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		kit.append(step(d.x, d.y))
	for s in Stance.ALL:
		kit.append(switch_to(s))
	return kit
