extends GutTest

## Task 9 集成测试：1v1 手动对战场景 pick-pick-reveal 全链路。
## 验证 presentation 层（battle.gd）正确驱动 logic 层（BattleState/Resolver/Orchestrator）。

func test_pick_pick_reveal_damages_target():
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	# _ready 已运行：state 有 2 个单位（玩家 team0 METAL，对手 team1 WOOD）
	var u0: UnitState = battle.state.units[0]
	var u1: UnitState = battle.state.units[1]
	var hp_before: int = u1.hp
	assert_eq(battle.state.units.size(), 2, "two units present after _ready")
	assert_true(u0.alive and u1.alive, "both alive at start")
	# 玩家打击（指向对手）；对手也打击（双方同速 5，METAL 克 WOOD → 玩家先结算）
	battle._on_pick(u0, battle._strike())
	battle._on_pick(u1, battle._strike())
	assert_eq(battle.pending.size(), 2, "both picks recorded")
	# 揭晓：玩家 METAL 克对手 WOOD → +2 克制增伤，对手掉 7（5+2）
	battle._on_reveal()
	assert_lt(u1.hp, hp_before, "enemy HP dropped after reveal")
	assert_eq(battle.pending.size(), 0, "pending cleared after reveal")
	assert_eq(u1.hp, hp_before - 7, "exact counter-bonus damage 5+2=7")
	remove_child(battle)
	battle.queue_free()

func test_reveal_blocked_until_both_pick():
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	var u0: UnitState = battle.state.units[0]
	var u1: UnitState = battle.state.units[1]
	var hp_before: int = u1.hp
	# 只玩家选，对手不选 → 揭晓应被拦截
	battle._on_pick(u0, battle._strike())
	battle._on_reveal()
	assert_eq(u1.hp, hp_before, "no damage when only one side picked")
	assert_eq(battle.pending.size(), 1, "pick still pending")
	remove_child(battle)
	battle.queue_free()

func test_battle_ends_when_hp_zero():
	var battle := preload("res://src/scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	var u0: UnitState = battle.state.units[0]
	var u1: UnitState = battle.state.units[1]
	# 直接把对手 HP 设到 1，一招带走
	u1.hp = 1
	# 玩家打击（5+2=7 克制伤害），对手也打击（保持 WOOD，被克制）
	battle._on_pick(u0, battle._strike())
	battle._on_pick(u1, battle._strike())
	battle._on_reveal()
	assert_false(u1.alive, "enemy dead")
	assert_true(battle.state.is_over(), "battle over")
	remove_child(battle)
	battle.queue_free()
