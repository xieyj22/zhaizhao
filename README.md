# 拆招

同时回合制武侠战棋肉鸽——双方同时亮招，靠「读招 / 拆招」预判对手、见招拆招。

## 特色

- **同时回合制**：双方同时下达指令、交汇时结算，强调预判而非单纯先后手
- **三层 AI**：
  - L1 效用 AI——基础走位与攻击决策
  - L2 玩家建模——频率表追踪你的习惯
  - L3 性格——不同对手有不同决策倾向
- **读招 / 虚招语义**：AI 会读你的招，你也可以用虚招骗它
- **Meta 层**：招募、存档、seeded DAG 地图生成、解锁规则、章回流程

## 技术栈

- **引擎**：Godot 4.7 + GDScript
- **测试**：GUT（Godot Unit Test）
- **渲染**：gl_compatibility

## 目录

```
zhaizhao/
├── src/
│   ├── data/        # 游戏数据定义
│   ├── logic/       # 战斗与 AI 逻辑
│   ├── meta/        # Meta 层（RunState / MetaState / 地图生成 / 解锁）
│   ├── playtest/    # 对局测试工具
│   └── scenes/      # hub / battle 等场景
├── tests/           # GUT 测试
├── addons/          # GUT 等插件
├── assets/sprites/  # 像素 sprite（boss/enemy/ally/terrain，24 色圣经 + tools/sprite_check.py 验收）
└── docs/            # 设计文档
```

## 运行

用 Godot 4.7+ 打开 `project.godot` 即可。运行测试需 GUT 插件（已含于 `addons/`）。

## License

[MIT](./LICENSE)
