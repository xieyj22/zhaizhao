# 拆招 — 架势/招式命名 + 技谱解锁层（M2.5 · 基础 pass）

- **用途**：M3 招式 `.tres` 化、`display_name` 迁移、技谱 codex 解锁曲线的命名/字段底座。深度招式演出/书法粒子/对白留 M3–M4。
- **一致性约束**：严格对齐 T1 `01-world-bible.md`（五势叙事名 锐金/盘根/厚土/流水/烈火；攻守中角色；机制叙事）与 T2 `02-factions.md`（8 门派招牌招**概念**）。
- **机制约束**：招牌招只复用现有 `Technique.Type`（MOVE/STRIKE/STANCE_SWITCH/FEINT/SPECIAL）+ `RangeBand.Id`（CLOSE/MID/FAR）+ `Stance.Id`（METAL/WOOD/EARTH/WATER/FIRE）；**绝对不改 enum 值**，只设计 `display_name` 映射与新 `id`。数值与现有量级一致（`base_damage` 3–7、`speed` 5–7、`opening_dealt` 0–2、`required_range ∈ {0,1,2}`、`resulting_stance ∈ Stance.Id ∪ {-1}`）。
- **命名说明**：本文只设计"正式 display_name + 新 id + 招牌招字段值 + 解锁层"。M3 落地时迁移 `TechniqueKit` 工厂与存档兼容，**M2.5 不动代码**。

---

## 一句话

江湖中的每一招都是门派传下来的"字"——主角每学一招，就是补全师门一个字。本文把这堆"字"从代码占位名（`strike_close` / `switch_0`）落成**有武侠魂的正式名**（「镜照·初照」「盘根·老树」），并给 M3 一张**技谱三阶解锁曲线**：开局带够、中期成长、后期爆发。

> spec §2.2 + T1 维度 5 落地：招式 = 门派所传的"字"，汇聚成**技谱**（codex）。命名不是装饰——它是"读招博弈"的叙事载体（玩家看到"烈焰·燎原"就知道这是 FIRE 攻势高风险，看到"听潮·远潮"就知道这是 WATER 守势远距渗透）。

---

## 维度 1：5 架势正式名 + 角色叙事（T1 维度 5 落地为 display_name）

> **绝对不改 enum 值**：`Stance.Id.METAL/WOOD/EARTH/WATER/FIRE` 一字不动。M3 只在 `stance.gd` 加一张 `const DISPLAY_NAME: Dictionary` 映射表，或在 `.tres` 化时给每个 stance 资源填 `display_name` 字段。下表是这张映射表的草稿。

### 1.1 `stance_display_names` 映射表草稿（M3 直接抄）

| 代码 enum（**不改**） | 正式 display_name | 身段描述（一句） | 攻/守/中角色（Role，**不改**） | 武侠说法 |
|--------------------|-----------------|---------------|----------------------------|---------|
| `Stance.Id.METAL` | **锐金势** | 兵刃集全力于一线，锋向前指，身形如锥 | 攻 `OFFENSIVE` | "一点破面"——兵刃之锐，决绝贯之 |
| `Stance.Id.WOOD` | **盘根势** | 双足钉地、重心下沉，身形如老树盘根 | 守 `DEFENSIVE` | "立地生根"——深扎盘错，任风雨不摧 |
| `Stance.Id.EARTH` | **厚土势** | 中正安舒、不偏不倚，身形如磐 | 中 `NEUTRAL` | "中正不倚"——不攻不守，却制攻守之机 |
| `Stance.Id.WATER` | **流水势** | 身形连绵、重心随形流转，如潮进退 | 守 `DEFENSIVE` | "随形成势"——不争而胜，善利万物 |
| `Stance.Id.FIRE` | **烈火势** | 身形前压、门户大开，如烈焰腾空 | 攻 `OFFENSIVE` | "燎原莫御"——焚敌亦焚己，凌厉则后空 |

### 1.2 角色（Role）的武侠说法（T1 维度 5 + 维度 6 对齐）

| 代码 Role（**不改**） | 现占位 | 武侠正式说法（M3 UI/文案用） | 机制含义（叙事化） |
|--------------------|--------|--------------------------|----------------|
| `OFFENSIVE` | 攻 | **攻势** | 凌厉则后空——每回合自身破绽 +1（`offensive_self_opening`），风险/回报 |
| `DEFENSIVE` | 守 | **守势** | 善养气——每回合破绽回落额外 +1（`defensive_decay_bonus`），稳如磐石 |
| `NEUTRAL` | 中 | **中势** | 承转枢纽——不偏不倚，破绽自然回落，制攻守之机 |

> **M3 落地提醒**：`Stance.Role` enum 值（`OFFENSIVE/DEFENSIVE/NEUTRAL`）**不改**；`display_name` 层把"攻/守/中"展示为"攻势/守势/中势"即可，与 T1 维度 6 完全对齐。

---

## 维度 2：12 通用招式命名（现 id → 正式 display_name）

> 现有 `TechniqueKit` 的 12 通用招（3 打击 + 4 方向移动 + 5 切架势）+ 2 玩家虚招预设 = 14 占位名。本文给它们武侠正式名，M3 迁移 `display_name`（id 迁移见维度 5）。

### 2.1 通用招命名表

| 现 id（代码） | 现占位 display_name | 正式 display_name（M3 用） | 备注 |
|--------------|-------------------|--------------------------|------|
| `strike_close` | "近打" | **通式·近打** | 近身 STRIKE，base_damage=5，入锐金（METAL 攻势） |
| `strike_mid` | "中打" | **通式·中打** | 中距 STRIKE，base_damage=4，入烈火（FIRE 攻势） |
| `strike_far` | "远打" | **通式·远打** | 远距 STRIKE，base_damage=3，入流水（WATER 守势） |
| `step`（+x） | "进退步" | **通式·进步** | MOVE 向右，speed=6，保持架势 |
| `step`（−x） | "进退步" | **通式·退步** | MOVE 向左，speed=6，保持架势 |
| `step`（+y） | "进退步" | **通式·侧步·上** | MOVE 向上，speed=6，保持架势 |
| `step`（−y） | "进退步" | **通式·侧步·下** | MOVE 向下，speed=6，保持架势 |
| `switch_0`（METAL） | "切架势" | **通式·转锐金** | STANCE_SWITCH 入 METAL，speed=7 |
| `switch_1`（WOOD） | "切架势" | **通式·转盘根** | STANCE_SWITCH 入 WOOD，speed=7 |
| `switch_2`（EARTH） | "切架势" | **通式·转厚土** | STANCE_SWITCH 入 EARTH，speed=7 |
| `switch_3`（WATER） | "切架势" | **通式·转流水** | STANCE_SWITCH 入 WATER，speed=7 |
| `switch_4`（FIRE） | "切架势" | **通式·转烈火** | STANCE_SWITCH 入 FIRE，speed=7 |
| `feint_lure_metal` | "虚招·装金（诱敌克金）" | **通式·虚招·装金** | FEINT apparent=METAL，real_dmg=4，speed=5 |
| `feint_lure_water` | "虚招·装水（诱敌克水）" | **通式·虚招·装水** | FEINT apparent=WATER，real_dmg=4，speed=5 |

### 2.2 命名说明

- **"通式"前缀**：这些是**无门派归属的江湖通式**——任何武人都会的基础招（走步、切势、近中远三打）。"通式"二字标明其**门派中立**，与维度 3 的门派招牌招（"门派名·招名"）形成对照。
- **切架势用"转 + 势名"**：与维度 1 的架势正式名（锐金/盘根/厚土/流水/烈火）严格咬合——玩家看到"转锐金"就知道进 METAL 攻势。
- **虚招用"装 + 势名"**：与 T1 维度 6 虚招叙事（"你见我盘根，实则流水已蓄"）一致——"装"字点明这是诱饵架势。

---

## 维度 3：门派招牌招字段化（T2 概念 → 具体 Technique）

> T2 给了每派 1–2 个**招牌招概念**（如"军阵连击 = 近距 STRIKE 连发"）。本节把这些概念落成**具体 Technique 字段值**——这是 M3 `.tres` 化的直接基础。**字段值与现有 `Technique` 完全兼容**（无新 Type / 无新字段，数值在现有量级）。
>
> **数值约束自查**：`base_damage ∈ [3,7]`、`speed ∈ [5,7]`、`opening_dealt ∈ [0,2]`、`required_range ∈ {0(CLOSE),1(MID),2(FAR)}`、`resulting_stance ∈ {0..4} ∪ {-1}`。`counter_bonus_damage=+2`（tuning），故招牌招 base_damage 不超过 7（克制时 9，与现有 strike_close 克制 7 同量级）。

### 3.1 镜照门（F1）— 2 招（读招拆招、架势流转）

| 字段 | 值 |
|------|---|
| `id` | `jingzhao_chuzhao` |
| `display_name` | **镜照·初照** |
| `type` | `STRIKE` |
| `required_range` | `1`（MID） |
| `base_damage` | `4` |
| `speed` | `6` |
| `resulting_stance` | `Stance.Id.EARTH`（2，厚土中势——镜照门以厚土为枢纽流转） |
| `opening_dealt` | `1` |
| 叙事 | 明镜先生所传的入门心法——"初照"即心眼初开，一招朴素但落点在中势，为下一手的流转占克留余地。brain 性格 NPC 偏爱此招（读招后占克势再发）。 |

| 字段 | 值 |
|------|---|
| `id` | `jingzhao_yingzhao` |
| `display_name` | **镜照·映照** |
| `type` | `STANCE_SWITCH` |
| `required_range` | `0` |
| `base_damage` | `0` |
| `speed` | `7`（最快——心眼读势，圆转无端） |
| `resulting_stance` | `Stance.Id.EARTH`（2，默认流转到厚土枢纽；实战中由 AI/玩家据读招结果选目标势） |
| `opening_dealt` | `0` |
| 叙事 | 镜照门核心——"映照"即心眼映出对手架势转移之意，提前流转到克制势。机制上 = `switch_to` 的快速密集使用，不发明新机制（T2 F1 招牌招族）。 |

### 3.2 赤锋军门（F2）— 2 招（军阵连击、压制突进）

| 字段 | 值 |
|------|---|
| `id` | `chifeng_lianci` |
| `display_name` | **赤锋·连刺** |
| `type` | `STRIKE` |
| `required_range` | `0`（CLOSE） |
| `base_damage` | `6`（高于通式近打 5——军阵长兵集全力一线） |
| `speed` | `5` |
| `resulting_stance` | `Stance.Id.METAL`（0，锐金攻势） |
| `opening_dealt` | `2`（军阵连击破绽大——攻势凌厉则后空） |
| 叙事 | 赤锋军门军阵杀人技——"三枪连刺、不给人喘息"。base_damage 6 + opening_dealt 2 表达"猛烈但门户愈开"，与 T2 F2 brute 性格（高侵略、不读你）咬合。 |

| 字段 | 值 |
|------|---|
| `id` | `chifeng_yajin` |
| `display_name` | **赤锋·压阵** |
| `type` | `MOVE` |
| `required_range` | `0` |
| `base_damage` | `0` |
| `speed` | `6` |
| `resulting_stance` | `-1`（保持架势——MOVE 约定） |
| `move_delta` | `Vector2i(1, 0)`（向敌推进；M3 可据朝向符号化） |
| `opening_dealt` | `0` |
| 叙事 | 军阵压上、逼人至死角——先 `压阵` 拉近距离，再 `连刺` 近身连打。机制上 = 现有 `step` 的推进偏好组合（T2 F2 招牌招族），无新机制。 |

### 3.3 盘根寨（F3）— 2 招（招架反击、固守不动）

| 字段 | 值 |
|------|---|
| `id` | `pangen_lagen` |
| `display_name` | **盘根·老树** |
| `type` | `STANCE_SWITCH` |
| `required_range` | `0` |
| `base_damage` | `0` |
| `speed` | `7` |
| `resulting_stance` | `Stance.Id.WOOD`（1，盘根守势） |
| `opening_dealt` | `0` |
| 叙事 | 立地生根、任风雨不摧——切到盘根守势占守，待对手攻势自叠破绽（攻势凌厉则后空）后反制。守势破绽回落快（`defensive_decay_bonus`），机制完全兼容（T2 F3 招牌招族）。 |

| 字段 | 值 |
|------|---|
| `id` | `pangen_jiajia` |
| `display_name` | **盘根·架架** |
| `type` | `STRIKE` |
| `required_range` | `0`（CLOSE） |
| `base_damage` | `4`（不重——盘根反击重在"克"，不在"力"） |
| `speed` | `5` |
| `resulting_stance` | `Stance.Id.WOOD`（1，保持盘根守势） |
| `opening_dealt` | `1` |
| 叙事 | 招架后的反制一击——复用 `Resolver.counter_bonus_damage`（克制方 +2 伤），盘根的强不在招本身，而在"读得准所以克制多"。与镜照门反制打击同源（T1 维度 5）。 |

### 3.4 听潮书院（F4）— 2 招（远程渗透、卸力位移）

| 字段 | 值 |
|------|---|
| `id` | `tingchao_yuanchao` |
| `display_name` | **听潮·远潮** |
| `type` | `STRIKE` |
| `required_range` | `2`（FAR） |
| `base_damage` | `3`（远距低伤但稳） |
| `speed` | `5` |
| `resulting_stance` | `Stance.Id.WATER`（3，流水守势） |
| `opening_dealt` | `1` |
| 叙事 | 气机如潮，远而不断——书院远程渗透打击。复用 `strike_far()` 概念，纯 STRIKE 无新字段（T2 F4 招牌招族）。 |

| 字段 | 值 |
|------|---|
| `id` | `tingchao_xieli` |
| `display_name` | **听潮·卸力** |
| `type` | `MOVE` |
| `required_range` | `0` |
| `base_damage` | `0` |
| `speed` | `6` |
| `resulting_stance` | `-1`（保持架势） |
| `move_delta` | `Vector2i(-1, 0)`（后退拉远；M3 据朝向符号化） |
| `opening_dealt` | `0` |
| 叙事 | 水来土掩，我来卸你——以退为进，拉开距离逼对手也走远距。机制上 = 现有 `step` 的后退偏好（T2 F4 招牌招族）。 |

### 3.5 烈焰堂（F5）— 2 招（燎原猛攻、火器压制）

| 字段 | 值 |
|------|---|
| `id` | `lieyan_liaoyuan` |
| `display_name` | **烈焰·燎原** |
| `type` | `STRIKE` |
| `required_range` | `1`（MID） |
| `base_damage` | `7`（招牌最高——一剑燎原，敌我皆焚） |
| `speed` | `5` |
| `resulting_stance` | `Stance.Id.FIRE`（4，烈火攻势） |
| `opening_dealt` | `2`（自叠破绽最大——焚敌亦焚己） |
| 叙事 | 烈焰堂招牌——中距高伤猛攻。base_damage 7 + opening_dealt 2 表达"极化风险/回报"，与 T2 F5 brute 极化性格（高侵略、凌厉后空）完全咬合。克制时 9 伤，量级合理。 |

| 字段 | 值 |
|------|---|
| `id` | `lieyan_huoqi` |
| `display_name` | **烈焰·破空** |
| `type` | `STRIKE` |
| `required_range` | `2`（FAR） |
| `base_damage` | `4`（火器远距压制，高于听潮·远潮的 3） |
| `speed` | `6`（火器快于气机） |
| `resulting_stance` | `Stance.Id.FIRE`（4，烈火攻势——区别于听潮·远潮入 WATER） |
| `opening_dealt` | `1` |
| 叙事 | 火铳/暗器远程压制——同样是远距 STRIKE，但入 FIRE 攻势（区别于听潮·远潮入 WATER 守势），表达"凌厉无伦"vs"远而不断"的流派之别（T2 F5 招牌招族）。 |

### 3.6 幻踪门（F6）— 2 招（虚招诱敌、层层嵌套）

| 字段 | 值 |
|------|---|
| `id` | `huazong_zhuangtu` |
| `display_name` | **幻踪·装土** |
| `type` | `FEINT` |
| `required_range` | `2`（FAR） |
| `base_damage` | `4`（real 打击） |
| `speed` | `5` |
| `resulting_stance` | `-1`（保持——real 打击不切势） |
| `apparent_stance` | `Stance.Id.EARTH`（2，厚土——中性架势作伪装最可信） |
| `feint_bonus_mult` | `1.5` |
| `feint_fail_mult` | `0.7` |
| `opening_dealt` | `1` |
| 叙事 | 声东击西——"你见我厚土，实则锐金已蓄"。表象用厚土诱对手克土（出 WOOD），实情 real 打击命中。复用现有 `feint_strike`，无新字段（T2 F6 招牌招族）。 |

| 字段 | 值 |
|------|---|
| `id` | `huazong_zhuanghuo` |
| `display_name` | **幻踪·装火** |
| `type` | `FEINT` |
| `required_range` | `1`（MID） |
| `base_damage` | `5`（real 打击略重——幻踪门中距诱杀） |
| `speed` | `5` |
| `resulting_stance` | `-1` |
| `apparent_stance` | `Stance.Id.FIRE`（4，烈火——诱对手克火出 WATER，实情 real 命中） |
| `feint_bonus_mult` | `1.5` |
| `feint_fail_mult` | `0.7` |
| `opening_dealt` | `1` |
| 叙事 | 表象之下还有表象——幻踪门层层嵌套虚招的中距变体。与装土形成"远土近火"的双层诱杀，逼对手读穿（T2 F6 trick 性格 feint_rate=0.7 的来源）。 |

### 3.7 夜枭镖局（F7）— 2 招（位移突进、中性流转）

| 字段 | 值 |
|------|---|
| `id` | `yexiao_tujin` |
| `display_name` | **夜枭·突进** |
| `type` | `MOVE` |
| `required_range` | `0` |
| `base_damage` | `0` |
| `speed` | `7`（最快——灯笼一晃人已在身后） |
| `resulting_stance` | `-1` |
| `move_delta` | `Vector2i(1, 0)`（突进；M3 据朝向符号化） |
| `opening_dealt` | `0` |
| 叙事 | 镖师走位突袭——speed 7 表达"快"，与赤锋·压阵（speed 6）区分在"快而诡"vs"稳而重"。机制上 = 现有 `step` 的突进偏好（T2 F7 招牌招族）。 |

| 字段 | 值 |
|------|---|
| `id` | `yexiao_liuzhuan` |
| `display_name` | **夜枭·流转** |
| `type` | `STANCE_SWITCH` |
| `required_range` | `0` |
| `base_damage` | `0` |
| `speed` | `7` |
| `resulting_stance` | `Stance.Id.EARTH`（2，默认厚土中势；实战据势选 EARTH/WATER） |
| `opening_dealt` | `0` |
| 叙事 | 镖局老油条，见势不对先溜——在厚土与流水间中性流转。机制上 = 现有 `switch_to` 的 EARTH/WATER 偏好（T2 F7 招牌招族）。 |

### 3.8 血衣教（F8）— 2 招（强攻破万法、分堂虚招）

| 字段 | 值 |
|------|---|
| `id` | `xueyi_xuedao` |
| `display_name` | **血衣·血祭** |
| `type` | `STRIKE` |
| `required_range` | `0`（CLOSE） |
| `base_damage` | `7`（仇派招牌——以血祭道，攻势不绝） |
| `speed` | `5` |
| `resulting_stance` | `Stance.Id.METAL`（0，锐金攻势——信"攻势为尊"） |
| `opening_dealt` | `2`（自叠破绽最大——血祭之道，焚敌亦焚己） |
| 叙事 | 血衣教教众 default 高侵略招牌——近身高伤猛攻。与烈焰·燎原（base 7 入 FIRE）区分在"入 METAL 锐金"vs"入 FIRE 烈火"，对应血衣教双攻势（METAL+FIRE）。克制时 9 伤，量级合理（T2 F8 招牌招族）。 |

| 字段 | 值 |
|------|---|
| `id` | `xueyi_zhuangjin` |
| `display_name` | **血衣·装金** |
| `type` | `FEINT` |
| `required_range` | `1`（MID） |
| `base_damage` | `5`（real 打击） |
| `speed` | `5` |
| `resulting_stance` | `-1` |
| `apparent_stance` | `Stance.Id.METAL`（0，锐金——诱对手克金出 FIRE，实情 real 命中） |
| `feint_bonus_mult` | `1.5` |
| `feint_fail_mult` | `0.7` |
| `opening_dealt` | `1` |
| 叙事 | 血衣教并非只会硬攻——左护法莫青娘（巫医）、暗哨裴渊（易容）的分堂虚招。与幻踪·装土/装火区分在"apparent=METAL 锐金"（血衣教主修），表达"邪道亦通心眼之反用"（T2 F8 招牌招族 + T1 内在矛盾 #3 正邪之辨）。 |

### 3.9 招牌招字段兼容性自检

- [x] **无新 Type**：全部用 `STRIKE / MOVE / STANCE_SWITCH / FEINT`，无 `SPECIAL`（M2 占位未启用）。
- [x] **无新字段**：FEINT 招复用 `apparent_stance / feint_bonus_mult / feint_fail_mult`；MOVE 招复用 `move_delta`；STRIKE/STANCE_SWITCH 复用 `base_damage / opening_dealt / resulting_stance`。
- [x] **数值量级一致**：
  - `base_damage`：3（听潮·远潮）– 7（烈焰·燎原 / 血衣·血祭），与现有 strike_far=3 / strike_close=5 同量级，`counter_bonus_damage=+2` 后最大 9，合理。
  - `speed`：5–7，与现有（strike=5 / step=6 / switch=7）完全一致。
  - `opening_dealt`：0–2，与现有（strike=1）同量级，2 表达"高破绽招"（军阵连击/燎原/血祭）。
  - `required_range`：0/1/2，全部 ∈ `RangeBand.Id`。
  - `resulting_stance`：0–4 或 -1，全部 ∈ `Stance.Id ∪ {-1}`。
- [x] **8 门派招牌招无机制重复**：每派 2 招，16 招覆盖 STRIKE(7) / MOVE(3) / STANCE_SWITCH(3) / FEINT(3)，分布合理，无两派招牌招机制雷同（区别在 id/display_name/数值/resulting_stance）。

---

## 维度 4：技谱解锁层（3 阶曲线）

> 所有招（14 通用 + 16 招牌 = **30 招**）分 3 层。给 M3 一张解锁曲线：**开局初始 kit**（主角出身镜照门起手招，~6–8 招）/ **中期解锁**（节点奖励，~10–15 招）/ **后期/传承**（boss 掉落/隐藏，~5–8 招）。

### 4.1 三阶总览

| 阶 | 名称 | 招数 | 获得方式 | gameplay 节奏 |
|----|------|------|---------|--------------|
| **T1 开局** | **镜照起手** | 8 | 主角出身镜照门自带（run 开始即有） | 够用——五势流转 + 近中远三打 + 基础虚招，能应对早期 brain/brute 首领 |
| **T2 中期** | **江湖阅历** | 14 | 节点奖励（切磋/拜访/险地通关）+ 招募败将传承 | 成长——补全门派招牌招，build 空间打开，应对中期 trick/brain 强化首领 |
| **T3 后期** | **传承秘要** | 8 | boss 掉落（七高手/掌门）+ 隐藏节点（沉剑谷/无相原） | 爆发——高数值招牌 + 仇派秘要，应对后期 boss 与终局 |

> **30 招 = 8 + 14 + 8**，分布合理（开局够用、中期主力、后期爆发）。

### 4.2 T1 开局：镜照起手（8 招，run 开始即有）

主角出身镜照门，明镜先生所传的入门心法 + 江湖通式基础：

| 招式 | 来源 | 用途 |
|------|------|------|
| 通式·近打 | 通式 | 近身 STRIKE 主力 |
| 通式·中打 | 通式 | 中距 STRIKE |
| 通式·远打 | 通式 | 远距 STRIKE |
| 通式·进步 / 退步 | 通式 | 基础走位（2 招） |
| 通式·转锐金 / 转盘根 / 转厚土 / 转流水 / 转烈火 | 通式 | 五势流转（5 招，镜照门五势圆融的体现） |

> 实际为 3 打 + 2 移动（进退）+ 5 切势 = **10 招**（侧步暂不放开局，避免 picker 拥挤；M3 可调）。**核心是五势全转**——这是镜照门"五势圆融"的玩法标识（T1 维度 5 + T2 F1）。

### 4.3 T2 中期：江湖阅历（14 招，节点奖励 + 招募传承）

闯荡残照江湖过程中，通过**切磋（学招）/ 拜访（传招）/ 险地（悟招）/ 招募败将（承招）**获得。每派 1–2 招招牌招散落各节点：

| 招式 | 获得方式 | 节点倾向 |
|------|---------|---------|
| 镜照·初照 / 映照 | 镜照山·旧址 hub 升级（明镜先生遗物） | 拜访 |
| 赤锋·连刺 / 压阵 | 赤锋关联节点（边军遗孤线 / 赫连铮战） | 决斗/切磋 |
| 盘根·老树 / 架架 | 南疆密林节点（盘根寨分舵） | 险地/切磋 |
| 听潮·远潮 / 卸力 | 听潮书院（主角心眼修炼线，T1 维度 3） | 拜访/切磋 |
| 烈焰·燎原 / 破空 | 烈焰堂关联节点（游侠火器线） | 决斗/镖局 |
| 幻踪·装土 / 装火 | 幻踪门关联节点（江湖术士线） | 切磋/险地 |
| 夜枭·突进 / 流转 | 夜枭镖局（黑市购买 / 镖师卧底线） | 镖局 |
| 通式·侧步·上 / 下 | 青芦渡码头武人切磋 | 切磋 |
| 通式·虚招·装金 / 装水 | 听潮书院心法课（主角心眼修炼） | 拜访 |

> **14 招**覆盖 7 派招牌招（除血衣教，血衣招在 T3 仇派线）+ 通式补全。每招对应一个节点，给 M3 节点图奖励直接引用。

### 4.4 T3 后期：传承秘要（8 招，boss 掉落 + 隐藏）

后期高数值/仇派秘要，通过**击败血衣七高手（掉落）/ 隐藏险地（沉剑谷、无相原悟道）**获得：

| 招式 | 获得方式 | 说明 |
|------|---------|------|
| 血衣·血祭 | 击败"铁面"赫连铮（brute 首领，早期章节）掉落 | 仇派锐金高伤猛攻 |
| 血衣·装金 | 击败"白骨"莫青娘（trick 首领，中期章节）掉落 | 仇派分堂虚招 |
| 烈焰·燎原（强化版） | 击败"焚天"雷万钧（brute 极化，章节末）掉落 | base_damage 7 極化猛攻 |
| 幻踪·装火（强化版） | 击败"影狐"裴渊（trick 强化，后期）掉落 | 层层嵌套虚招 |
| 听潮·远潮（强化版） | 击败"棋仙"司空弈（brain 强化，后期）掉落 | 读招至境远距渗透 |
| 盘根·架架（强化版） | 击败"裂碑"宗政烈（brute 强化，中后期）掉落 | 横练反制 |
| **无名·无相**（隐藏） | 无相原终局悟道（真结局线，T1 未解之谜 #3） | 五势圆融至境——SPECIAL 类型占位（M3+ 决策是否启用 SPECIAL） |
| **明镜·遗照**（隐藏） | 沉剑谷险地深处（明镜先生遗物，T1 未解之谜 #1） | 镜照门不传之秘——STANCE_SWITCH 五势任意流转 |

> **8 招**含 6 强化版招牌 + 2 隐藏传承。强化版与基础版同 id 家族（M3 用 `variant` 字段或 id 后缀区分）。**无名·无相**与**明镜·遗照**是真结局/传承线钩子，与 T1 维度 3"承道"动机咬合。
>
> **M3+ 提醒**：`无名·无相`若启用 `SPECIAL` 类型，需 M3 决策 SPECIAL 语义（当前 M2 占位未用）。本文不预设，标 M3+ 扩展。

### 4.5 解锁曲线 gameplay 节奏自检

- [x] **开局够用**：8–10 招（五势全转 + 三打 + 进退步），玩家能应对早期 brain/brute 首领（赫连铮 brute、晏九 brain）。
- [x] **中期成长**：14 招散落 7 派节点，build 空间打开——玩家据偏好选路（偏守走盘根/听潮、偏攻走赤锋/烈焰、偏诡走幻踪/夜枭），应对中期 trick（莫青娘）/ brain 强化（司空弈）。
- [x] **后期爆发**：8 招含强化版 + 隐藏，数值量级达 base_damage 7，应对终局掌门颜无咎（brain+trick 合一）。
- [x] **与 T1 三动机咬合**：复仇（T3 boss 掉落）/ 重立（T1-T2 节点招募）/ 承道（T3 隐藏传承 + 无相原真结局）。

---

## 维度 5：technique id 迁移清单（M3 实现时迁移）

> **M2.5 只设计不执行迁移**。下表是 M3 迁移 `TechniqueKit` 工厂 + 存档兼容的依据。**现有代码 id（`strike_close` 等）→ 新正式 id** 的映射，标注迁移方式。

### 5.1 通用招 id 迁移（14 条）

| 现代码 id | 新正式 id | display_name | 迁移方式 |
|----------|----------|--------------|---------|
| `strike_close` | `tongshi_jinda` | 通式·近打 | 改 `TechniqueKit.strike_close()` 内 `t.id` |
| `strike_mid` | `tongshi_zhongda` | 通式·中打 | 改 `TechniqueKit.strike_mid()` 内 `t.id` |
| `strike_far` | `tongshi_yuanda` | 通式·远打 | 改 `TechniqueKit.strike_far()` 内 `t.id` |
| `step`(+x) | `tongshi_jinbu` | 通式·进步 | `step()` 据 dx 符号分赋 id（M3 改工厂签名或后处理） |
| `step`(−x) | `tongshi_tuibu` | 通式·退步 | 同上 |
| `step`(+y) | `tongshi_cebu_shang` | 通式·侧步·上 | 同上 |
| `step`(−y) | `tongshi_cebu_xia` | 通式·侧步·下 | 同上 |
| `switch_0`（METAL） | `tongshi_zhuan_ruijin` | 通式·转锐金 | `switch_to()` 据目标势分赋 id |
| `switch_1`（WOOD） | `tongshi_zhuan_pangen` | 通式·转盘根 | 同上 |
| `switch_2`（EARTH） | `tongshi_zhuan_houtu` | 通式·转厚土 | 同上 |
| `switch_3`（WATER） | `tongshi_zhuan_liushui` | 通式·转流水 | 同上 |
| `switch_4`（FIRE） | `tongshi_zhuan_liehuo` | 通式·转烈火 | 同上 |
| `feint_lure_metal` | `tongshi_zhuangjin` | 通式·装金 | 改 `feint_presets()` 内 `f1.id` |
| `feint_lure_water` | `tongshi_zhuangshui` | 通式·装水 | 改 `feint_presets()` 内 `f2.id` |

### 5.2 门派招牌招新 id（16 条，M3 新增 `.tres`）

| 新正式 id | display_name | 门派 | type |
|----------|--------------|------|------|
| `jingzhao_chuzhao` | 镜照·初照 | F1 镜照门 | STRIKE |
| `jingzhao_yingzhao` | 镜照·映照 | F1 镜照门 | STANCE_SWITCH |
| `chifeng_lianci` | 赤锋·连刺 | F2 赤锋军门 | STRIKE |
| `chifeng_yajin` | 赤锋·压阵 | F2 赤锋军门 | MOVE |
| `pangen_lagen` | 盘根·老树 | F3 盘根寨 | STANCE_SWITCH |
| `pangen_jiajia` | 盘根·架架 | F3 盘根寨 | STRIKE |
| `tingchao_yuanchao` | 听潮·远潮 | F4 听潮书院 | STRIKE |
| `tingchao_xieli` | 听潮·卸力 | F4 听潮书院 | MOVE |
| `lieyan_liaoyuan` | 烈焰·燎原 | F5 烈焰堂 | STRIKE |
| `lieyan_huoqi` | 烈焰·破空 | F5 烈焰堂 | STRIKE |
| `huazong_zhuangtu` | 幻踪·装土 | F6 幻踪门 | FEINT |
| `huazong_zhuanghuo` | 幻踪·装火 | F6 幻踪门 | FEINT |
| `yexiao_tujin` | 夜枭·突进 | F7 夜枭镖局 | MOVE |
| `yexiao_liuzhuan` | 夜枭·流转 | F7 夜枭镖局 | STANCE_SWITCH |
| `xueyi_xuedao` | 血衣·血祭 | F8 血衣教 | STRIKE |
| `xueyi_zhuangjin` | 血衣·装金 | F8 血衣教 | FEINT |

### 5.3 隐藏/传承招新 id（2 条，T3）

| 新正式 id | display_name | 来源 | type |
|----------|--------------|------|------|
| `wuming_wuxiang` | 无名·无相 | 无相原终局 | SPECIAL（M3+ 决策） |
| `mingjing_yizhao` | 明镜·遗照 | 沉剑谷隐藏 | STANCE_SWITCH |

### 5.4 存档兼容提醒（给 M3）

- **id 迁移是破坏性的**（`StringName` 比较）。M3 迁移时需在存档加载层加**旧→新 id 映射表**（如 `legacy_id_map: Dictionary`），旧存档读到的 `strike_close` 自动转 `tongshi_jinda`，避免回档丢失招式。
- **M0–M2 测试存档**若用旧 id 硬编码，迁移时一并改测试夹具。
- **enum 值绝不动**：`Stance.Id.METAL=0` 等不变，故 `resulting_stance` 字段的整数存档值无需迁移；只有 `id`（StringName）和 `display_name`（String）需迁移。

---

## 维度 6：命名风格规约（给 M3 一致性参考）

### 6.1 总原则

- **武侠正式名，非系统术语**：所有面向玩家的 display_name 用武侠说法（锐金/盘根/初照/燎原），不用代码术语（METAL/WOOD/strike_close）。
- **与 T1/T2 命名统一**：架势名（锐金/盘根/厚土/流水/烈火）严格沿用 T1 维度 5；门派名（镜照/赤锋/盘根/听潮/烈焰/幻踪/夜枭/血衣）严格沿用 T2。

### 6.2 命名模式

| 模式 | 适用 | 示例 |
|------|------|------|
| **通式·招名** | 无门派归属的江湖通式（14 通用招） | 通式·近打 / 通式·转锐金 / 通式·装金 |
| **门派名·招名** | 门派招牌招（16 招） | 镜照·初照 / 赤锋·连刺 / 血衣·血祭 |
| **特殊名·招名** | 隐藏/传承招（2 招） | 无名·无相 / 明镜·遗照 |

- **"·"分隔符**：统一用中圆点"·"分隔前缀（通式/门派/特殊）与招名，视觉清爽，与武侠小说招式命名惯例一致。
- **招名 2 字为主**：初照/映照/连刺/压阵/老树/架架/远潮/卸力/燎原/破空/装土/装火/突进/流转/血祭/装金——除"架架"（盘根寨横练重复感）外均为 2 字，简练有力。
- **招名与机制呼应**：
  - STRIKE 招名带"打击感"（连刺/燎原/血祭/破空）。
  - STANCE_SWITCH 招名带"流转感"（映照/老树/流转/转锐金）。
  - MOVE 招名带"位移感"（压阵/卸力/突进/进步）。
  - FEINT 招名带"伪装感"（装土/装火/装金/装水）。

### 6.3 id 命名规约（给 M3 `.tres` 文件名/资源路径）

- **拼音全小写 + 下划线**：`jingzhao_chuzhao` / `chifeng_lianci` / `xueyi_xuedao`。
- **前缀 = 门派拼音首段**：`jingzhao`(镜照) / `chifeng`(赤锋) / `pangen`(盘根) / `tingchao`(听潮) / `lieyan`(烈焰) / `huazong`(幻踪) / `yexiao`(夜枭) / `xueyi`(血衣) / `tongshi`(通式) / `wuming`(无名) / `mingjing`(明镜)。
- **`.tres` 路径建议**：`res://data/techniques/{id}.tres`（M3 落地），如 `res://data/techniques/jingzhao_chuzhao.tres`。

---

## 设计自检（产出后自查）

- [x] **5 架势名 + 角色叙事**：锐金/盘根/厚土/流水/烈火（T1 维度 5 一致），标注 enum 不变 + `stance_display_names` 映射表草稿（维度 1.1）。
- [x] **12（14）通用招命名表**：现 id → 正式 display_name（维度 2.1），14 条（含 2 虚招预设）。
- [x] **门派招牌招字段值齐全且与 Technique 兼容**：8 派 × 2 招 = 16 招，字段完整（id/display_name/type/required_range/base_damage/speed/resulting_stance/opening_dealt + FEINT 的 apparent_stance/feint_*_mult + MOVE 的 move_delta），无新 Type / 无新字段，数值量级一致（维度 3.9 自检）。
- [x] **技谱 3 层解锁曲线 + 每层招数**：T1 开局 8–10 / T2 中期 14 / T3 后期 8，共 30 招，与 T1 三动机咬合（维度 4）。
- [x] **id 迁移清单完整**：14 通用迁移 + 16 招牌新增 + 2 隐藏 = 32 条（维度 5），含存档兼容提醒。
- [x] **命名风格规约**：通式/门派/特殊三模式 + "·"分隔 + 招名 2 字 + id 拼音规约（维度 6）。
- [x] **与 T1 一致**：
  - 五势叙事名（锐金/盘根/厚土/流水/烈火）+ 攻守中角色完全沿用 T1 维度 5。
  - 虚招叙事（"你见我盘根，实则流水已蓄"）对齐 T1 维度 6。
  - 主角三动机（雪恨/重立/承道）与技谱三阶（T3 boss 掉落/T1-T2 节点/T3 隐藏传承）咬合。
  - 心眼修炼线（听潮书院）= T2 招牌招 + T2 中期节点。
- [x] **与 T2 一致**：
  - 8 门派招牌招概念全部落成具体 Technique（F1–F8 每派 2 招），无遗漏。
  - 招牌招机制与 T2"招牌招族"概念对齐（镜照架势流转 / 赤锋军阵连击 / 盘根招架反击 / 听潮远程渗透 / 烈焰燎原猛攻 / 幻踪虚招诱敌 / 夜枭位移突进 / 血衣强攻+分堂虚招）。
  - AI 性格映射（brain/brute/trick）与招牌招数值风格咬合（brain 招低伤重克、brute 招高伤高破绽、trick 招虚招为主）。
- [x] **未改任何代码**：enum 值不动，只设计 display_name / 新 id / 字段值 / 解锁层；M3 落地时迁移。

---

## 与现有机制的潜在冲突 / M3+ 扩展点（给 M3 的提醒）

1. **`step()` / `switch_to()` 工厂签名**：现工厂用同一个 id（`step` / `switch_{n}`），维度 5 要求按方向/目标势分赋 id。M3 迁移时需**改工厂签名**（如 `step(dx, dy, id_override)`）或**后处理**（生成后据 move_delta/resulting_stance 改 id）——非冲突，是 M3 实现细节。

2. **强化版招牌招（T3）**：维度 4.4 的"强化版"与基础版同 id 家族。M3 可用 `variant` 字段（新增，M3 决策）或 id 后缀（如 `lieyan_liaoyuan_strong`）区分。**若新增 `variant` 字段需改 `Technique.gd`**——标 M3 决策，本文不预设。

3. **`无名·无相` 启用 SPECIAL 类型**：当前 `Technique.Type.SPECIAL` 是 M2 占位未用。若 T3 真结局招启用，M3 需定义 SPECIAL 语义（如"五势圆融 = 出招后可任选目标势"）。**M3+ 扩展，非冲突**。

4. **存档兼容映射表**：维度 5.4 提醒——id 迁移是破坏性的，M3 需在存档加载层加 `legacy_id_map`。**M3 实现项，非冲突**。

5. **招式与门派 NPC 绑定**：M3 落地门派 NPC 时，其 kit 应含本派招牌招（如赤锋军门 NPC 带 `chifeng_lianci` + `chifeng_yajin` + 通式）。本文已提供字段值，M3 直接 `.tres` 化引用——**M3 落地，非冲突**。
