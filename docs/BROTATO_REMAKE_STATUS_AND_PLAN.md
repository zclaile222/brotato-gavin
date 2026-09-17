# Brotato 复刻版 — 现状与执行明细

> 生成日期：2026-07-17
> 最近更新：**2026-09-17**（商店 UI 交互重做 + 相机/3×3 屏大地图 + Danger 0-5 + 元素 Boss 独特机制；
> 并**补记两处此前从未被本文件跟踪的系统** —— 「相机 + 大地图」与「商店 UI」，见 §6.2 / §7.12 / §7.13）
> 基于分支：`master`
> 目标：作为后续分阶段修复的主文档，替代已陈旧的 `docs/PROGRESS.md` 与 `DEV_REPORT.md`。

> ⚠️ **关于历史**：本仓库的 git 对象库经历两次损毁（2026-09-15 直接 unlink / 2026-09-17 经回收站），
> 原始 186 个提交的内容**不可恢复**。2026-09-17 的工作区现状成为**新基线**，
> 历史自此重新开始（当前 14 个提交）。取证结论见 `docs/GIT_HISTORY_RECOVERY.md`。

---

## 一、项目概览

| 维度 | 现状（2026-09-17 实测） |
|------|------|
| 引擎 | Godot 4.6.1，GDScript，GL Compatibility，1280×720 |
| 主代码量 | 41 个 GDScript 文件，**18,368 行** |
| 测试代码量 | 31 个冒烟测试，**19,931 行** |
| 场景 | 12 个 `.tscn` 场景 |
| 数据目录 | 8 个 JSON（角色 62 / 武器 78 / 物品 235 / 升级 100） |
| 冒烟测试 | **31 个**，`tests/run_all.sh` → **PASS=31 FAIL=0**（2026-09-17 实测） |
| 最大脚本 | `Player.gd` **2,088** 行、`PlayerUpgrades.gd` 1,651 行、`Shop.gd` 1,431 行 |
| 分支 | `master`（远端 `main`） |

> 上表为**实测**值（`scripts/**/*.gd` 与 `tests/**/*.gd` 逐文件计行 + `run_all.sh` 实跑）。
> 09-15 版本的数字（35 文件 / 12,707 行 / 11 套件）已全面过期。
> **注意「文件数」与「套件数」是两个量**：`.gd` 计数含被测试加载的辅助脚本，
> 套件数以 `tests/run_all.sh` 的 `TESTS` 列表为准 —— 目前两者恰好都是 31，但别当成同一个数。

---

## 二、已完成的核心里程碑

### v0.1 基础玩法（2026-03-26）
- 20 波战斗 + Boss 波（5/10/15/20）+ 无尽模式
- 14 个角色、16 种武器、15 种敌人、程序化视觉/音效
- 商店、升级、连击、成就、存档

### 重构与性能优化（2026-04-24）
- `Player.gd`、`Main.gd`、`HUD.gd` 拆分为 12 个模块
- 对象池、AI 分帧、碰撞缓存等性能优化

### Brotato Fidelity Phase 1（2026-05-27）
- 材料经济（材料 = XP + 货币）
- 波次时长表（20/25/30/35/40/45/50/55/60/90 秒）
- 波末升级四选一队列
- 材料袋机制
- `ShopRules` 驱动的商店生成

### Phase 2A 战利品与武器合成（2026-05-27）
- 水果、箱子、传奇箱战利品
- 武器 T1-T4 同名同阶合成
- 满槽购买自动合成规则

### Phase D 数据目录（2026-05-28）
- **62 个角色**全部录入并接入角色选择
- **78 把武器**全部录入，武器类与 `attack_kind` 对齐官方
- **235 个物品**全部录入，135 种特殊规则在 `PlayerUpgrades.gd` 中已有处理
- 角色规则运行时：属性修正、起始物品、武器槽上限、Creature 特殊规则等

---

## 三、当前数据现状

### 3.1 目录规模

| 目录 | 实际数量 | 目标/原版数量 | 状态 |
|------|---------|--------------|------|
| 角色 | 62 | 62 | 完成 |
| 武器 | 78 | 78 | 结构完成，规则未运行 |
| 物品 | 235 | **235（已完成）** | 2026-09-15 用 wiki API 核实：目录**完整**，无缺失（见 §3.2 / §7.8） |
| 升级 | **100** | ~100（25 种 × 4 tier） | **完成**（2026-09-15，见 P2-2） |

### 3.2 关键字段卫生问题

- ~~**`items.json` 的 `implemented` 字段**~~：**已解决并扩大到全部目录**（2026-09-15，见 §7.8）。
  六个目录（items / weapons / characters / weapon_classes / item_tags / upgrades）共 **288 处**
  `implemented` 字段全部删除；每个目录改用一条真实判据，不再有「字段说不可用、实际照常可用」的矛盾。
- ~~**`upgrades.json` 基本未使用**~~：**已解决**（2026-09-15）。升级目录扩为 25 属性 × 4 tier，`UpgradeChoiceRules` 改为目录驱动，`BrotatoData.get_level_up_choices(wave)` 成为唯一候选池来源。
- ~~**物品目录缺 8 个 DLC 物品**~~：**该结论是错的，已推翻**（2026-09-15 复核）。
  **物品目录 235 条是完整的**：以 wiki 的 MediaWiki API 取 `Template:Infobox Item` 的反向引用，
  恰好得到 **235 个真实物品页**，与目录逐名 1:1 吻合；`catalog_manifest.json` 里那个
  `items_total: 237` **本身就是错数字**（已更正为 235）。详见 §7.8。
- **武器 `special_rules`**：65 条规则已接线 54 条（83%），剩余 11 条均有明确暂缓理由（见 §7.7）。

---

## 四、当前代码现状

### 4.1 脚本行数排名

| 脚本 | 行数 | 说明 |
|------|------|------|
| `scripts/Player.gd` | **2,088** | 严重膨胀，承载大量物品效果逻辑 |
| `scripts/PlayerUpgrades.gd` | **1,651** | 物品效果分发 |
| `scripts/Shop.gd` | **1,431** | 商店：卡片 / 拖拽 / 出售 / 锁定 / 布局全在这里 |
| `scripts/BrotatoData.gd` | **1,358** | 数据加载/验证/转换 |
| `scripts/Enemy.gd` | 1,230 | 敌人 AI + Boss 变体 + 独特机制 |
| `scripts/PlayerCombat.gd` | **1,133** | 武器开火 + 规则分发（已从 298 行长回本行） |
| `scripts/HUD.gd` | 886 | UI 协调 |
| `scripts/Main.gd` | 765 | 主协调 |
| `scripts/WaveManager.gd` | 727 | 波次状态机 + 难度维度 |
| `scripts/Effects.gd` | 629 | 特效池 |

> 2026-09-17 实测前 10 名。与 09-15 版对比值得注意的两处：
> `PlayerCombat.gd` 从 298 → **1,133 行**（P1 规则分发的真实工作量落在这里，与「过薄」的判断一致），
> `Shop.gd` 从 798 → **1,431 行**（UI 交互重做，见 §7.13）。

### 4.2 架构问题

- **Player.gd 重新成为 God Object**：4 月重构后它一度减到 188 行，但 D4 阶段把每个物品的专用函数直接塞回门面，导致目前比重构前还翻倍（现 **2,088 行**）。
- **缺少统一 EffectDispatcher**：135 种物品规则靠 `PlayerUpgrades.gd` 字符串分发，65 种武器规则分散在 `PlayerCombat.gd` 的 `_has_rule` / `_get_rule` 分支里。
- ~~**PlayerCombat.gd 过薄**~~：**已不成立**（2026-09-17 实测 1,133 行）。P1 的 55 条武器规则分发确实落在这里，与当初「过薄」的判断一致 —— 但代价是它也变成了一个大文件。
- **新增：`Shop.gd` 1,431 行的合理性存疑**。商店的**布局算法**（`_compute_panel_height` / `_sync_dynamic_layout` / `_place_area`）
  与**业务逻辑**（购买 / 出售 / 合成 / 锁定）混在同一文件里。P3 抽模块时应一并考虑把布局独立出去。

---

## 五、验证状态

| 验证项 | 状态 | 备注 |
|--------|------|------|
| Headless 项目加载 | 通过 | 2026-05-27 |
| Phase 1 规则冒烟测试 | 通过 | `PHASE1_RULE_SMOKE_PASS` |
| Phase 1 Main 场景冒烟测试 | 通过 | `PHASE1_MAIN_SCENE_SMOKE_PASS` |
| Phase 2A 战利品/武器合成冒烟测试 | 通过 | `PHASE2_LOOT_WEAPON_SMOKE_PASS` |
| 目录冒烟测试 | 通过 | `BROTATO_DATA_CATALOG_SMOKE_PASS` |
| D1 武器目录冒烟测试 | 通过 | `PHASE_D1_WEAPON_CATALOG_SMOKE_PASS` |
| D2 角色运行时冒烟测试 | 通过 | `PHASE_D2_CHARACTER_RUNTIME_SMOKE_PASS`（2026-09-15 修断言） |
| D4 物品运行时冒烟测试 | 通过 | `PHASE_D4_CATALOG_ITEM_RUNTIME_SMOKE_PASS` |
| 武器特殊规则冒烟测试 | 通过 | `WEAPON_SPECIAL_RULES_SMOKE_PASS` |
| 敌人池空闲态冒烟测试（新增） | 通过 | `ENEMY_POOL_IDLE_STATE_SMOKE_PASS`，见 §十 |
| 升级目录冒烟测试（新增） | 通过 | `LEVEL_UP_CATALOG_SMOKE_PASS`，见 §7.1 |
| 武器属性贡献冒烟测试（新增） | 通过 | `WEAPON_STAT_CONTRIBUTION_SMOKE_PASS`，见 §7.2 |
| 武器穿透规则冒烟测试（新增） | 通过 | `WEAPON_PIERCE_RULES_SMOKE_PASS`，见 §7.3 |
| 武器命中附加冒烟测试（新增） | 通过 | `WEAPON_ON_HIT_EFFECTS_SMOKE_PASS`，见 §7.4 |
| 武器弹跳规则冒烟测试（新增） | 通过 | `WEAPON_BOUNCE_RULES_SMOKE_PASS`，见 §7.5 |
| 武器冷却/成长冒烟测试（新增） | 通过 | `WEAPON_COOLDOWN_GROWTH_SMOKE_PASS`，见 §7.6 |
| 武器杂项规则冒烟测试（新增） | 通过 | `WEAPON_MISC_RULES_SMOKE_PASS`，见 §7.7 |
| 远程武器上下文冒烟测试（新增） | 通过 | `RANGED_WEAPON_CONTEXT_SMOKE_PASS`，见 §7.9 |
| 波次表冒烟测试（新增） | 通过 | `ENEMY_WAVE_TABLE_SMOKE_PASS`，见 §7.10 |
| 元素 Boss 冒烟测试（新增） | 通过 | `ELEMENTAL_BOSS_SMOKE_PASS`，见 §7.11 |
| 角色属性单位冒烟测试（新增） | 通过 | `CHARACTER_STAT_UNIT_SMOKE_PASS`，见 §10.4 |
| 战斗目标有效性冒烟测试（新增） | 通过 | `COMBAT_TARGET_VALIDITY_SMOKE_PASS`，见 §10.5 |
| 效果池场景切换冒烟测试 | 通过 | `EFFECTS_POOL_SCENE_CHANGE_SMOKE_PASS` |
| **相机 + 大地图冒烟测试（新增）** | 通过 | `CAMERA_ARENA_SMOKE_PASS`，见 §7.12 |
| **商店布局冒烟测试（新增）** | 通过 | `SHOP_LAYOUT_SMOKE_PASS`（7 类判据），见 §7.13 |
| **商店拖拽/合成/锁定冒烟测试（新增）** | 通过 | `SHOP_DRAG_COMBINE_SMOKE_PASS`，见 §7.13 |
| **商店账本/撤回冒烟测试（新增）** | 通过 | `SHOP_INVENTORY_SMOKE_PASS`，见 §7.13 |
| **武器按 tier 精确移除冒烟测试（新增）** | 通过 | `WEAPON_REMOVE_BY_TIER_SMOKE_PASS`，见 §7.13 |
| **升级面板布局冒烟测试（新增）** | 通过 | `UPGRADE_PANEL_LAYOUT_SMOKE_PASS`，见 §7.13 |
| **Danger 0-5 难度模型冒烟测试（新增）** | 通过 | `DANGER_MODEL_SMOKE_PASS`，见 §7.14 |
| **Boss 独特机制冒烟测试（新增）** | 通过 | `BOSS_MECHANICS_SMOKE_PASS`，见 §7.14 |
| ~~`tests/item_runtime_effect_smoke.gd`~~ | **已删除** | 自创建起从未成功运行；调用不存在的静态 API，覆盖范围已由 D4 承担 |
| **Godot 编辑器手动游玩验证** | **仍未做** | 所有阶段的 Manual verification 复选框均空；**商店的可见性缺陷正是靠人眼截图发现的**（见 §7.13） |
| Godot headless 沙箱运行 | **正常** | **31 个套件可全量 headless 执行**，PASS=31（2026-09-17 实测） |

### 一键跑全套

```bash
bash tests/run_all.sh
# 测某个套件：
"<Godot>/Godot_v4.6.1-stable_win64_console.exe" --headless --path . \
  --script res://tests/enemy_pool_idle_state_smoke.gd
```

> 本表在 2026-09-15 重新核对：当时 10 个测试中 **2 红**（`phase_d2` 断言过期、`item_runtime_effect_smoke` 解析错误）。
> 根因是缺少一键入口，缺陷长期无人发现。`tests/run_all.sh` 即为补上的入口。
>
> **2026-09-17 再次核对的结论（更重要）**：套件从 11 涨到 **31**、全绿，
> 但玩家仍然反馈「**运行游戏时没发现这些改动**」。
> **全绿 ≠ 功能可用** —— 既有 30 个套件只断言「节点存在、数据正确」，
> 从不检查**布局位置与可见几何**。商店的三处缺陷（Panel 不布局 / 区块重叠 / 内容不撑满）
> 全部逃过了 30 个绿灯。补上的判据见 §7.13，这是本文件里最值得记的一次教训。

**⚠️ 单独跑测试前的两个前置条件**（一键入口已自动处理，用 `--script` 手跑时要自己做）：

1. **新增带 `class_name` 的脚本后，必须先让 Godot 扫描一次项目**
   （`"<Godot>" --headless --path . --import`）。全局类名要写进
   `.godot/global_script_class_cache.cfg` 之后才会被识别；跳过这一步的话，
   所有引用该类的脚本都会解析失败，而症状是一大片互不相关的
   `Invalid access to property ... on a base object of type ...`
   （挂在节点上的脚本压根没加载），极难定位。
   `run_all.sh` 因此在跑测试前静默扫一次（设 `SKIP_IMPORT=1` 可跳过）。
2. **新增 `.gd` 后要生成 `.uid` 侧车**（同一条 `--import` 即可，项目有意跟踪 `.uid`）。

---

## 六、与原版 Brotato 的关键差距

### 6.1 战斗与数值系统

| 系统 | 当前状态 | 原版目标 | 差距 |
|------|---------|---------|------|
| 武器特殊规则 | 65 条中已接线 **55 条（85%）**，未接线 10 条（全部因目录缺取值或需新子系统，见 §7.7） | 78 把武器各有鲜明机制 | **小** |
| 升级选项池 | ~~8 种属性硬编码，无 tier~~ → **25 属性 × 4 tier，按波次分档** | ~25 属性 × 4 tier，随波次解锁 | **已闭合**（P2-2） |
| 敌人波次构成 | ~~硬编码，12 波后冻结~~ → **目录驱动（P4-1，2026-09-15）**：20 波各有主题 / 时长 / 刷怪节奏 / 敌人池权重 | 按波次的敌人池、精英词缀、群落事件 | **小**（仅剩精英词缀与群落事件） |
| 难度模型 | ~~简单/普通/困难 + 动态缩放~~ → **Danger 0-5（P4-3，2026-09-17）**：`GameState.MIN/MAX_DANGER`、强度倍率 / 刷怪密度倍率 / 额外精英概率三个维度，角色选择界面有 6 档卡片 | Danger 0-5 | **已闭合**（含三处有意偏差，见 §7.14） |
| Boss 轮换 | **四个 Boss 波各不相同（P4-4 + P4-5 的 P0/P1，2026-09-15）**：第 5 波冰霜 / 第 10 波火焰 / 第 15 波雷电 / 第 20 波均衡型双 Boss。三种变体各有独立数值、弹幕元素与阶段速度倍率 | 每 5 波特定 Boss，20 波双 Boss，各有独特机制 | **已闭合**（P2 独特机制于 2026-09-17 完成，见 §7.14） |
| 玩家受击反馈 | ~~玩家侧完全没有状态效果~~ → **燃烧 / 减速 / 眩晕（P4-5 的 P1，2026-09-15）**，由元素子弹命中时施加；闪避 / 无敌帧 / 免伤挡下的命中不会附带 | 原版同样用元素威胁制造走位压力 | **已闭合**（数值待 playtest 定标） |

### 6.2 场地、相机与 UI（**本节为 2026-09-17 新增**）

> ⚠️ **为什么新增这一节**：§6.1 只覆盖「逻辑/数值系统」。
> 「相机 + 大地图」与「商店 UI」这两个系统**从未进入任何状态跟踪** ——
> 实测（2026-09-17，改动本文档之前）：
> `grep 'arena\|Arena\|相机'` **零命中**；`grep '场地'` 仅 1 处命中，
> 而那一处是 §10.2 里**描述 bug 成因**的顺带提及（「Main 的场地布局按视口尺寸铺开」），
> **不是任何系统条目**。「商店」同理（`Shop.gd` 只在 §4.1 的行数表里出现过一行）。
> 这一点很关键：**「某词出现过」不等于「该系统的状态被跟踪」** ——
> 判据应当是「它是否是某个表格里的一行 / 某个 P 编号」，而不是关键词命中。
> 分类缺口比数字过期更危险：功能做完了，却没人知道该验收什么。

| 系统 | 当前状态 | 原版目标 | 差距 |
|------|---------|---------|------|
| **相机 + 大地图** | **已实现（2026-09-17）**：`scripts/Arena.gd` 作为场地边界**单一数据源**；世界 = **3×3 屏**；相机跟随玩家并**钳位**（场地边缘永远贴住视口边）；刷怪 / 子弹出界 / 玩家移动钳位三种边界一次讲清 | 原版是固定单屏场地，**本项目选择了更大的场地** | **超出原版**（有意差异，见 §7.12） |
| **商店 UI / 交互** | **已实现（2026-09-17）**：拖拽合成/交换、武器出售、锁定跨波次价格冻结、玩家侧权威「已获得道具」账本、卡槽与装备位语义分离；布局由 `_sync_dynamic_layout()` 单一权威驱动 | 拖拽合成 / 出售 / 锁定 三件套 | **已闭合**（数值口径偏差登记在 §7.13 末） |
| **波末升级面板** | 已实现；布局缺陷已修（锚点预设调用时机，见 §7.13） | — | **已闭合** |
| 视觉/音频 | 程序化几何图形 + 程序化音效 | 像素精灵、动画、真实音效 | 大（但项目约束允许保留程序化风格） |

> **本节的两个「从未被跟踪」缺口已补上。** 若下一轮再出现「做了但没人验收」的功能，
> 先问一句：**它属于 6.1 还是 6.2？都不属于就该新增一节。**

---

## 七、分阶段执行明细

### P0 — 现状确认与仓库卫生（已完成）

目标：确认 master 可玩，清理脏状态，更新文档。

| 编号 | 任务 | 具体操作 | 状态 | 成功标准 |
|------|------|---------|------|---------|
| P0-1 | 手动游玩验证 | 在 Godot 编辑器完整运行一局普通难度 20 波 | **待用户在 Windows 执行** | 无崩溃、商店/升级/胜利流程走完 |
| P0-2 | 运行未提交测试 | 在沙箱外 Godot 运行 `tests/item_runtime_effect_smoke.gd` | **待用户执行** | 输出 `ITEM_RUNTIME_EFFECT_SMOKE_PASS` |
| P0-3 | 提交未跟踪文件 | 决定 `boss-variants-design.md`、`weapon-runtime-coverage.md`、`weapon-special-rule-audit.md`、`item_runtime_effect_smoke.gd` 是否保留 | **完成** | 工作区干净 |
| P0-4 | 清理陈旧 worktree 与 stash | 删除 `.worktrees/brotato-fidelity-core`，处理 `stash@{0}` | **完成** | 无遗留 |
| P0-5 | 更新主进度文档 | 用本文件替代 `docs/PROGRESS.md` 成为主状态页；更新 `CLAUDE.md` 中技术债描述 | **完成** | 后续不再出现 Player.gd 900+ 行等过时描述 |

提交信息：`fecf962 feat: implement weapon special rules runtime (P1 core)`。

### P1 — 武器特殊规则运行时（进行中，核心规则已实现）

目标：让 78 把武器拥有原版差异化机制，优先覆盖高频武器。

| 编号 | 任务 | 目标文件 | 状态 | 实现要点 |
|------|------|---------|------|---------|
| P1-1 | 透传武器规则 | `scripts/BrotatoData.gd` | **完成** | `weapon_tier_to_combat_entry()` 现在复制完整 tier 行并附加 `special_rules` 和 `attack_kind` |
| P1-2 | 建立规则分发器 | `scripts/PlayerCombat.gd` | **完成** | 新增 `_has_rule`/`_get_rule`/`_get_weapon_state`、`_apply_weapon_hit_effects`、生命周期钩子 |
| P1-3 | 高优先级规则 batch 1 | `scripts/PlayerCombat.gd` + `scripts/Bullet.gd` + `scripts/Enemy.gd` | **完成** | `burn`（含 `burn_damage`/`burn_instances`）、`slow`、`pierce_falloff`、`full_pierce`、`burn_spread_by_tier` |
| P1-4 | 高优先级规则 batch 2 | `scripts/PlayerCombat.gd` | **完成** | `alternate_thrust_and_sweep`、`sixth_shot_longer_cooldown`、`damage_charges_until_hit`、`material_on_critical_kill`、`every_nth_projectile_guaranteed_crit` |
| P1-5 | 伤害/冷却修饰规则 | `scripts/PlayerCombat.gd` | **完成** | `bonus_damage_against_low_health`、`current_health_bonus_damage`、`bonus_damage_per_free_weapon_slot`、`bonus_damage_above_health_threshold`、`bonus_damage_for_duplicate_sticks`、`damage_growth_per_kills_this_wave`、`damage_growth_when_damaged_this_wave`、`attack_speed_growth_over_wave`、`reload_every_n_attacks_by_tier`、`attack_speed_penalty` |
| P1-6 | 命中效果规则 | `scripts/PlayerCombat.gd` + `scripts/Bullet.gd` | **完成** | `projectile_explosion_on_hit`、`melee_hit_explosion_chance`、`hit_explosion_chance_by_tier` |
| P1-7 | 冒烟测试 | `tests/weapon_special_rules_smoke.gd` | **完成** | 验证关键规则的战斗条目存在性；`WEAPON_SPECIAL_RULES_SMOKE_PASS` |
| P1-8 | 中低优先级规则 | `scripts/PlayerCombat.gd` | **基本完成（30/40）** | 2026-09-15 连续七批：属性贡献 9 条（§7.2）、穿透数值化 1 条（§7.3）、命中附加 + 自持结构 6 条（§7.4）、弹跳 + 工程减速 5 条（§7.5）、冷却 + 击杀成长 4 条（§7.6）、杂项 4 条（§7.7）、远程上下文 + 弹片 1 条（§7.9）；剩余 **10 条均有明确暂缓理由** |
| P1-9 | 手动验证 | Godot 编辑器 | **待用户执行** | 用 Torch、Revolver、Rocket Launcher、Harpoon Gun、Sickle 等关键武器各打一局 |

**规则覆盖率（2026-09-15 实测）**：`weapons.json` 共 65 条唯一 `special_rules`，
**已接线 55 条（85%）**，未接线 10 条。统计口径：规则 id 是否在 `scripts/*.gd` 里被引用。

> 未接线的 10 条**全部**属于「目录缺取值」或「需新建子系统」，逐条理由见 §7.7 / §7.9。
> 要推进它们，需要先在 `weapons.json` 里补数值（这是数据设计决策），或先做魅惑子系统。

> 覆盖率只看「规则名是否出现」，会**低估**共享机制的修复价值 —— 例如 §7.3 只让 1 条规则名进了代码，
> 却修好了 16 把武器的穿透行为。评估批次价值时要同时看「涉及武器数」。

> P1-8 的注意事项：剩余 31 条**每条都只涉及 1 把武器**，所以「按命中武器数排优先级」已无意义，
> 应按**共享机制**分批（召唤类共用 TurretManager、投射物行为共用 Bullet、成长类共用波次计数）。
> 动手前先核对两件事：① 该规则在 `weapons.json` 里是否真有取值键；
> ② 底层能力是否已存在（本项目大量能力只被物品调用过，武器规则常常只是「接线」而非新建系统）。

**已实现的武器特殊规则（约 22 条）**：
`burn`、`burn_spread_by_tier`、`slow`、`pierce_falloff`、`full_pierce`、`alternate_thrust_and_sweep`、`sixth_shot_longer_cooldown`、`damage_charges_until_hit`、`material_on_critical_kill`、`every_nth_projectile_guaranteed_crit`、`bonus_damage_against_low_health`、`current_health_bonus_damage`、`bonus_damage_per_free_weapon_slot`、`bonus_damage_above_health_threshold`、`bonus_damage_for_duplicate_sticks`、`damage_growth_per_kills_this_wave`、`damage_growth_when_damaged_this_wave`、`attack_speed_growth_over_wave`、`reload_every_n_attacks_by_tier`、`attack_speed_penalty`、`projectile_explosion_on_hit`、`melee_hit_explosion_chance`、`hit_explosion_chance_by_tier`。

**待实现的规则（约 40 条）**：
`burning_damage_by_tier`、`cooldown_every_100_shots`、`material_pickup_resets_cooldown`、`reload_every_n_shots_by_tier`、`harvesting_by_tier`、`range_gain_per_steps_during_wave`、`charm_low_health_enemy_on_hit`、`damage_taken_debuff_on_hit`、`spawn_fruit_garden`、`break_and_drop_materials_on_hit`、`armor_and_hp_bonus_by_tier`、`lifesteal_per_missing_health`、`flat_knockback_bonus`、`reset_offensive_turret_cooldowns_on_attack`、`spawn_landmine_by_tier`、`spawn_structure_by_tier`、`crit_pierce_by_tier`、`consumable_heal_bonus_by_tier`、`instant_kill_chance_by_tier`、`armor_penalty_per_weapon`、`speed_bonus_by_tier`、`damage_penalty_while_standing_still`、`always_crit_burning_targets`、`spawn_projectiles_on_hit`、`critical_hit_bounce`、`spawn_lightning_projectile_on_hit`、`spawn_lightning_projectiles_on_hit`、`negative_knockback_pull`、`projectile_slow_aura`、`pull_distance_damage_reduction`、`xp_gain_by_tier`、`bounce_by_tier`、`shoot_thorns`、`pierce_99_for_one_damage`。

### P2 — 数据目录补齐与字段卫生（P2-2 已完成）

目标：消除数据文档矛盾，补齐缺失目录。

| 编号 | 任务 | 目标文件 | 状态 | 实现要点 |
|------|------|---------|------|---------|
| P2-1 | 修复 `implemented` 字段 | `data/brotato/items.json` + `scripts/BrotatoData.gd` | **完成** | 采用方案 A：删除 235 处字段，`get_items(false)` 改判据为 `_item_has_runtime_effects()`。见 §7.8 |
| P2-2 | 补齐升级目录 | `data/brotato/upgrades.json` + `scripts/UpgradeChoiceRules.gd` | **完成** | 3 条 → **100 条（25 属性 × 4 tier）**，详见 §7.1 |
| P2-3 | 补齐物品目录 | `data/brotato/items.json` + `catalog_manifest.json` | **完成** | 复核后确认物品目录**本就完整（235/235）**；真正的错误是 `items_total: 237`，已更正为 235 并加了一致性门。见 §7.8 |
| P2-4 | 目录冒烟测试更新 | `tests/brotato_data_catalog_smoke.gd` | **部分完成** | 升级目录校验已加强；物品侧新增「不得再有 `implemented` 字段」与「`get_items(false)` 与 `get_shop_pool(false)` 判据一致」两条断言 |

#### 7.1 P2-2 交付明细（2026-09-15）

**问题**：四选一由 `UpgradeChoiceRules.CHOICE_POOL` 硬编码 8 种属性，单一数值、无 tier、无波次门槛；
`generate_choices(level, luck, count)` 的 `level` 与 `luck` 参数**被完全忽略**；
`BrotatoData.get_level_up_choices()` 无任何调用方，`upgrades.json` 只有 3 条。

**改动**：

| 文件 | 改动 |
|------|------|
| `data/brotato/upgrades.json` | 100 条：25 属性 × 4 tier，每条含 `tier/stat/value/weight/min_wave/max_wave` |
| `scripts/BrotatoData.gd` | `get_level_up_choices(wave)` 变为唯一候选池来源（按 `min_wave/max_wave` 过滤，并产出 HUD 直接可用的 `name`/`desc`/`stat`/`tier`/`rarity`）；抽出 `_format_stat_delta_value()`；`_validate_upgrades()` 增加三条硬校验 |
| `scripts/UpgradeChoiceRules.gd` | 重写：目录驱动 + 权重抽取（幸运把权重推向高阶）+ 四选项保证属性互不重复；`apply_choice()` 改走 `PlayerUpgrades.apply_catalog_rule_effects()`，角色的 `catalog_stat_modification_multipliers`、Barnacle 的 `level_upgrade_stat_percent_bonus` 等修正因此自动生效；保留目录不可用时的兜底池 |
| `scripts/Player.gd` | 新增 `_current_wave()`，把波次传给四选一；去掉从未使用的 `level` 实参 |

**分档与权重**（`min_wave`/`max_wave` 定义档位，`weight` 决定同档内的稀有度）：

| tier | 波次门槛 | 基础权重 | 示例（速度） |
|------|---------|---------|-------------|
| I | 1 – 6 | 1.00 | +4% |
| II | 1 – 12 | 0.80 | +7% |
| III | 4 – ∞ | 0.60 | +10% |
| IV | 8 – ∞ | 0.45 | +13% |

幸运通过 `1 + luck × 0.01 × (tier - 1)` 放大高阶权重：tier 越高受幸运影响越大，负幸运则更偏低阶。
实测（各 500 次抽取）：`wave 1 / luck 0` → T1 56.0% / T2 44.0%（正好对应权重 1.0 : 0.8）；
`wave 13 / luck -20 → 20` 时 T4 占比 34.4% → 47.0%，单调上升。

**验证**：`tests/level_up_catalog_smoke.gd`（新增）固定「目录形状 / 波次分档 / 四选一合法性 / 幸运偏向 /
每个属性都能落到真实 Player 属性上」五组不变量。已验证非空转：关掉波次过滤后该测试报 372 项失败，
把 `STAT_PROPERTY_MAP` 故意错配后报「应用 armor 后 luck 未发生变化」。

#### 7.2 P1-8 第一批：武器持有期属性贡献（2026-09-15，9 条规则）

**问题**：一批武器的规则效果是「只要装备着就提供某属性」，此前在 `weapons.json` 里存在但运行时完全不生效。

**机制**：`PlayerCombat._refresh_weapon_contributions()`，在 `emit_weapons_changed()` 触发
—— 后者是所有武器增删路径（装备 / 合成 / 从物品系统移除）的**唯一收敛点**。
实现要点：

- 用「目标总量 vs 已应用总量」的**差量**方式应用，因此重复触发是幂等的；
- 遍历「目标」与「已应用」的**并集**，否则卸下武器时目标里不再出现该属性，撤回逻辑会被跳过；
- 属性应用统一走 `PlayerUpgrades.apply_catalog_rule_effects()`（与物品同一套应用器），
  增减语义由 `direction` 承载、`value` 传绝对值，与物品系统的既有约定一致。

**本批接通的规则**：

| 规则 | 武器 | 贡献 | 数据键 |
|------|------|------|--------|
| `harvesting_by_tier` | Hand | 收获 | `harvesting_bonus` 3/6/9/18 |
| `xp_gain_by_tier` | Quarterstaff | 经验获取 | `xp_gain` 0.02/0.05/0.09/0.15 |
| `armor_and_hp_bonus_by_tier` | Rock | 护甲 + 最大生命值 | `armor_bonus` / `max_hp_bonus` |
| `speed_bonus_by_tier` | Jousting Lance | 速度 | `speed_bonus` 0.02–0.05（× `SPEED_PERCENT_BASE` 300） |
| `consumable_heal_bonus_by_tier` | Chopper | 消耗品治疗 | `consumable_heal_bonus` 1/1/1/2 |
| `flat_knockback_bonus` | Hammer | 击退 | `knockback_bonus` 2/4/6（该武器无 tier 1） |
| `armor_penalty_per_weapon` | Excalibur | 护甲（**按武器数量缩放**） | `armor_penalty_per_weapon` -3 |
| `always_crit_burning_targets` | Spoon | 对燃烧目标必定暴击 | `always_crits_burning_targets` |
| `lifesteal_per_missing_health` | Sharp Tooth | 缺失生命换算生命偷取 | `missing_health_lifesteal_step` 25/20/15/10 |

`always_crit_burning_targets` 与 `lifesteal_per_missing_health` 不是持有期属性，而是命中时效果，
分别落在 `_fire_melee()` 的暴击判定与 `_apply_weapon_hit_effects()` 中。

**验证**：`tests/weapon_stat_contribution_smoke.gd`（新增）固定五组不变量
（装上变化 / 卸下还原 / tier 越高越多 / 按武器数缩放 / 重复刷新不重复累加），
并对两条命中类规则做了行为断言（燃烧目标伤害 = 普通命中 × 暴击倍率；缺失生命越多回复越多，
满血时不回复）。已验证非空转：摘掉机制报 13 项失败（逐条显示「实际 +0.00」），
单独摘掉两条命中规则各报 1 项失败。

**本批**未采纳**的候选及原因**（记下来避免重复评估）：
- ~~`pierce_99_for_one_damage`~~：已于 §7.3 连同「穿透数值化」一起解决；
- `crit_pierce_by_tier`（Crossbow）：`weapons.json` 里**没有任何取值键**，实现等于凭空发明数值，暂缓；
- `spawn_structure_by_tier`（Wrench）：`spawn_structure` 随 tier 变化（turret/incendiary/laser/explosive），
  但数据里没有节奏参数，需要先确定「武器自持建筑」的生成与上限语义。

#### 7.3 P1-8 第二批：穿透（pierce）数值化（2026-09-15，实际修好 16 把武器）

**问题**：`weapons.json` 的 tier 行里 `pierce` 是 `{count, damage_multiplier}`，
但运行时把它当布尔用，`count` 与 `damage_multiplier` **被所有武器忽略**，一律按「3 次命中、无衰减」处理。

**关键发现：字典在数据管道里就被丢掉了，有两处塌陷点**（这是本批最有价值的部分）：

| 位置 | 原代码 | 后果 |
|------|--------|------|
| `BrotatoData.weapon_tier_to_combat_entry()` | `entry = row.duplicate(true)` 之后又 `entry["pierce"] = true` | 字典刚复制完就被布尔冲掉 |
| `PlayerCombat._apply_tier_stats()` | T3 起对非近战武器**无条件** `data["pierce"] = true` | 连已有字典也一起覆盖（harpoon_gun T4 的 count=5 直接消失） |

所以下游手上**从来只有一个布尔**，硬编码「3 次命中」是被迫的猜测值，不是设计。
这也解释了为什么 `pierce_falloff_percent`（默认 -0.25）全项目无人赋值 —— 衰减量级的真正来源是 `damage_multiplier`。

**修复**：
- 两处塌陷点均改为「目录优先」：`BrotatoData` 不再覆盖；`_apply_tier_stats` 仅在目录**未给出** pierce 时
  才授予 T3 基础穿透（保留原作者「高阶枪械获得穿透」的设计意图）；
- `_fire_ranged` 解析 `{count, damage_multiplier}`：`count` = 额外穿透数 → 可命中总数 = count + 1
  （与 `Bullet.pierce_hit_limit` 的语义一致，该值在 `pierce_count >= limit` 时归还子弹）；
- `Bullet` 新增 `pierce_damage_multiplier`，第 n 个后续命中按 `multiplier^n` 衰减；
  旧的 `pierce_falloff` 线性路径保留为「目录未给出倍率时」的兜底。

**顺带成立的规则**：Flamethrower 的 `damage_multiplier: 0` 会落到 `max(1, …)` 下界，
即后续命中固定 1 点 —— **`pierce_99_for_one_damage` 无需特判分支**，由数据自然成立。

**典型武器**：

| 武器 | count | 可命中总数（旧 → 新） | 衰减倍率 |
|------|-------|---------------------|---------|
| Pistol | 1 | 3 → **2** | 0.5 |
| Double Barrel Shotgun T4 | 3 | 3 → **4** | 0.7 |
| Harpoon Gun T4 | 5 | 3 → **6** | 0.75 |
| Javelin T1 | 2 | 3 → **3** | 0.75 |
| Flamethrower | 99 | 3 → **100** | 0（→ 每击 1 点） |
| Minigun T4 | 2 | 3 → **3** | 0.5 |
| Obliterator（`full_pierce`） | — | 999（不变） | 1.0 |

**验证**：`tests/weapon_pierce_rules_smoke.gd`（新增）固定四组不变量：
容量传导（9 把武器逐一对齐 count → limit 与倍率）、衰减行为（第 2/3 个命中按倍率的幂次递减）、
Flamethrower 每击 1 点、无穿透武器只能命中 1 个目标。
**非空转证据来自修复前的同一次运行**：当时报 16 项失败，同时覆盖容量（`harpoon_gun T4 应为 6，实际 3`）
与衰减（`第 2 个命中应为 1（9 × -1.00^1），实际 7` —— 7 正是旧线性路径 −25% 的结果）。

**注意这是一次平衡性改动**：T3/T4 远程武器的穿透数从统一 3 变成按目录取值（多数变少、部分变多），
属向数据靠拢；需要人工试玩确认手感。

#### 7.4 P1-8 第三批：近战命中附加 + 武器自持结构（2026-09-15，6 条）

| 规则 | 武器 | 触发时机 | 实现落点 | 数据键 |
|------|------|---------|---------|--------|
| `damage_taken_debuff_on_hit` | Lute | 每次命中 | `_apply_weapon_hit_effects()` | `damage_taken_bonus` / `_cap` / `_duration` |
| `break_and_drop_materials_on_hit` | Brick | 每次命中 | 同上 | `break_chance` / `break_materials` |
| `shoot_thorns` | Cacti Club | 每次挥击 | `_apply_melee_attack_effects()` | `thorn_projectiles` / `thorn_damage_scaling` |
| `reset_offensive_turret_cooldowns_on_attack` | War Hammer | 每次挥击 | 同上 | 无（T3 起才有该规则） |
| `spawn_landmine_by_tier` | Screwdriver | 周期 | `_process_weapon_state()` | `mine_spawn_interval` / `mine_damage` |
| `spawn_fruit_garden` | Pruner | 周期 | 同上 | `garden_fruit_interval` |

**关键区分**：召唤类规则按「**周期**」实现（放在 `_process_weapon_state`），而不是「每次挥击」——
因为它们的目录参数是时间间隔（Screwdriver T1 12s → T4 3s；Pruner T1 15s → T4 10s），
而不是触发次数。因此这两条规则的生效与打不打得到敌人无关。
新增的 `_apply_melee_attack_effects()` 只承载「每次挥击一次」的规则（与命中敌人数无关）。

**复用的既有能力**（本批几乎全是接线，没有新建系统）：
`TurretManager.spawn_landmine()` / `spawn_garden()` / `spawn_catalog_turret()`、
`Enemy.apply_damage_taken_bonus()`、`Player.earn_gold()`（物品的 `material_on_critical_kill` 同款做法）。

**两处实现细节**：
- Lute 的易伤用「**敌人当前值 + 一步**、再按 cap 截断」而不是在武器状态里叠计数 ——
  敌人身上的计时器到期后 `damage_taken_percent_bonus` 会自动归零，这样天然自洽；
- War Hammer 重置冷却时**跳过医疗炮台**（`is_medical_turret` meta），规则名限定为「进攻型建筑」。

**未采纳**：`spawn_structure_by_tier`（Wrench）继续暂缓 —— `spawn_structure` 随 tier 变
（turret/incendiary/laser/explosive），但**数据里没有任何节奏或持续时间参数**，
实现它就要凭空空发明一个数值，与 `crit_pierce_by_tier` 同理。

**验证**：`tests/weapon_on_hit_effects_smoke.gd`（新增）固定五组不变量：
易伤按步叠加并封顶（0.1 → cap 0.3）、碎材料是 `break_materials` 的整数倍、荆棘弹数等于
`thorn_projectiles`、挥击重置进攻型建筑冷却但不动医疗炮台、
自持结构严格按目录间隔生成（**含「不到间隔不生成」的反向断言**）。
Brick 是 1% 概率规则，用固定种子跑 3000 次让「一次都不触发」的概率可忽略。

**非空转验证**：在三个入口函数（`_apply_weapon_hit_effects` / `_apply_melee_attack_effects` /
`_process_weapon_state`）临时加早退，一次运行即报 8 项失败，**6 条规则逐条给出精确证据**
（`Lute 易伤应为 0.10 实际 0.00`、`荆棘弹应为 6 实际 0`、`冷却应归零实际 5.00`、
`应埋下 1 颗地雷实际新增 0`、`应结出 1 个花园实际新增 0` 等）。

#### 7.5 P1-8 第四批：投射物弹跳与工程减速（2026-09-15，5 条）

| 规则 | 武器 | 取值来源 |
|------|------|---------|
| `bounce_by_tier` | Slingshot | 目录 `bounces` 1/2/3/4 |
| `bounce_once` | Grenade Launcher | **由规则名确定 = 1**（无目录取值） |
| `critical_hit_bounce` | Shuriken | 目录 `crit_bounces` 1/2/3/4，仅暴击时叠加 |
| `cannot_bounce` | Particle Accelerator | **由规则名确定 = 禁止**（并压过玩家的 `projectile_bounce_bonus`） |
| `engineering_based_slow` | Particle Accelerator | 目录 `engineering_slow_per_point` × 工程点数，上限 0.9 |

**判据说明**：`bounce_once`（"一次"）与 `cannot_bounce`（"禁止"）的值由规则名唯一确定，
不需要目录取值 —— 这类「名字即语义」的规则可以直接实现；而
`projectile_explosion_chance`（Shredder）、`projectile_slow_aura` 与
`pull_distance_damage_reduction`（Harpoon Gun）的目录里**没有任何取值键**，
按既定原则继续排除（不发明数值）。

**实现**：弹跳次数在 `_fire_ranged` 的**每发子弹循环内**计算 —— 因为 `critical_hit_bounce`
依赖「这一发是否暴击」；`cannot_bounce` 通过短路直接压过玩家加成。

**测试踩到的坑（值得记下）**：`queue_free()` 是**延迟释放**，测试内紧接着做同步断言时，
被"释放"的节点仍留在场景树与 `enemies` 组里，会被 `Bullet._try_bounce_to_next_target`
当成「最近的敌人」选中（距离 0 → `normalized()` 得到零向量），污染弹跳方向断言。
**测试内同步清理必须用 `free()` 而非 `queue_free()`。**
另一个坑：验证「命中即回收」不能选 `Pistol` —— 它有 1 次穿透，首击后本来就该继续飞，
应选完全无穿透也无弹跳的武器（SMG T1）。

**验证**：`tests/weapon_bounce_rules_smoke.gd`（新增）固定五组不变量：弹跳次数传导、
暴击才有弹跳、`cannot_bounce` 压过玩家加成、工程减速随点数线性增长、行为层（有弹跳时命中后不回收
并转向下一个敌人 / 无弹跳时立刻回收）。非空转验证：中和弹跳与减速两处实现后报 8 项失败，
覆盖全部 5 条规则。

#### 7.6 P1-8 第五批：冷却节奏与击杀成长（2026-09-15，4 条）

| 规则 | 武器 | 数据键 |
|------|------|--------|
| `cooldown_every_100_shots` | Chain Gun | `cooldown_every_shots`(100) / `reload_cooldown`(2.04) |
| `material_pickup_resets_cooldown` | Blunderbuss | 无（规则名即语义） |
| `attack_speed_growth_per_kills_this_wave` | Ghost Flint | `attack_speed_growth_kill_interval` / `attack_speed_growth` |
| `max_hp_growth_per_kills_this_wave` | Ghost Scepter | `max_hp_growth_kill_interval` / `max_hp_growth` |

**按 §7.5 的判据排除两条**：
- `reload_every_n_shots_by_tier`（Grenade Launcher）：**对照组 Chainsaw 有
  `reload_interval` / `reload_cooldown`，而 Grenade Launcher 两者皆无** → 无法确定 N 与冷却时长；
- `range_gain_per_steps_during_wave`（Hiking Pole）：有步长阈值 `range_gain_steps`，
  但**没有每次的增量值** → 无法确定 += 多少。

**实现要点**：

1. **成长类优先「即时计算」而不是「改动玩家属性」。** `attack_speed_growth_per_kills_this_wave`
   在 `_cooldown_for_weapon()` 里按击杀数即时折算，因此波末 `kills_this_wave` 归零后加成自动消失，
   **不需要回滚逻辑** —— 与既有的 `attack_speed_growth_over_wave`、`damage_growth_per_kills_this_wave` 一致。
2. **只有 `max_hp_growth_per_kills_this_wave` 必须真的改玩家属性**（`max_hp` 会被 HUD 与伤害计算直接读取）。
   因此用 `max_hp_growth_applied` 记录已发放的档数，并在 `on_wave_start()` 开头**按同一记录原样扣回**。
3. `material_pickup_resets_cooldown` 的钩子挂在 `XPOrb.collect()`（真正的材料拾取路径），
   而不是 `Player.earn_gold()` —— 后者也被 `material_on_critical_kill`、材料雨、Brick 等**非拾取**来源调用，
   挂错地方会让"拾取时重置"变成"任何加钱都重置"。

**本批抓到一个自身实现 bug（值得记）**：`attack_speed_growth_per_kills_this_wave` 第一版被插在
`raw_cooldown` **计算之后**，而它改的是 `fire_rate` —— 结果冷却恒定不变。测试报
`满一档击杀后冷却应为 1.2178，实际 1.2300` 把它抓了出来。**改 `fire_rate` 的规则必须位于
`raw_cooldown = 1/(fire_rate × multiplier)` 之前，改 `raw_cooldown` 的规则（如追加冷却）才可以放在之后。**

**验证**：`tests/weapon_cooldown_growth_smoke.gd`（新增）固定四组不变量：打满 N 发才追加冷却
（含「未打满不受影响」与「跨过后恢复」）、材料拾取清零冷却且不影响无该规则的武器、
击杀档数按「击杀数 / 间隔」向下取整（**含未满一档不发的反向断言**）、
两种成长都只在本波内生效（波次开始时清空 / 扣回）。
非空转验证：临时让 `_has_rule()` 恒为 false，报 7 项失败，4 条规则逐条给出精确证据。

#### 7.7 P1-8 第六批 + 剩余 11 条的处理结论（2026-09-15）

**本批实现的 4 条**：

| 规则 | 武器 | 数据键 | 落点 |
|------|------|--------|------|
| `damage_penalty_while_standing_still` | Jousting Lance | `standing_still_damage_penalty` | `_damage_for_weapon()`，按开火瞬间的 `velocity` 判定 |
| `instant_kill_chance_by_tier` | Vorpal Sword | `instant_kill_chance` | `_apply_weapon_hit_effects()` |
| `spawn_lightning_projectile_on_hit` | Lightning Shiv | `lightning_damage` / `lightning_bounces` | 同上，复用 §7.4 的 `_spawn_simple_projectile()` |
| `explosion_damage_growth_per_explosion_this_wave` | DEX-troyer | `explosion_damage_growth_per_explosion` | `Player.deal_catalog_explosion()` + `PlayerCombat` 计数 |

**两处实现细节**：
- 站定判定沿用既有物品的写法（`velocity.length_squared() <= 0.01`，见
  `Player.update_stand_still_item_bonuses()`），且**按开火瞬间计算**，不做状态记录 ⇒ 天然可逆；
- 爆炸成长同样**按计数即时折算**（`explosion_damage_growth_bonus()`），不改
  `explosion_damage_percent`，波末计数归零即自动回到基线。计数写在
  `deal_catalog_explosion()`（`deal_hit_explosion()` 内部委托到它，只需挂一处）。
  斩杀用「剩余血量 × 4」作为伤害，是为了越过百分比减伤（armored 敌人减伤 50%），
  让「即死」名副其实 —— 代价是 `total_damage_dealt` 会被略微高估。

**剩余 11 条：全部暂缓，且都有明确理由**（不要重复评估）：

| 规则 | 武器 | 暂缓理由 |
|------|------|---------|
| `burning_damage_by_tier` | Flamethrower | 目录里**没有任何 burn 取值键** |
| `crit_pierce_by_tier` | Crossbow | 目录里**没有任何取值键** |
| `spawn_structure_by_tier` | Wrench | 有 `spawn_structure`（随 tier 变）但**无节奏/持续时间参数** |
| `reload_every_n_shots_by_tier` | Grenade Launcher | **对照组 Chainsaw 有 `reload_interval`/`reload_cooldown`，它两者皆无** |
| `range_gain_per_steps_during_wave` | Hiking Pole | 有步长阈值 `range_gain_steps`，但**没有每次的增量值** |
| `spawn_lightning_projectiles_on_hit` | Thunder Sword | **缺 base damage**（只有 `lightning_bounces`/`lightning_scaling`），且**未给出弹射数量** |
| `projectile_explosion_chance` | Shredder | 需要概率值，**目录无** |
| `projectile_slow_aura` | Harpoon Gun | 需要半径与减速量，**目录无** |
| `pull_distance_damage_reduction` | Harpoon Gun | 需要衰减曲线，**目录无** |
| `spawn_projectiles_on_hit` | Sniper Gun | ~~缺「投射物携带武器身份」的机制~~ → **已实现**，见 §7.9 |
| `charm_low_health_enemy_on_hit` | Flute | 数据齐全（`charm_health_threshold`/`charm_chance`/`charm_duration`），但**需要新建敌人转化机制**（被魅惑的敌人改打同伴、到期恢复）——这是子系统级工作量，不是接线 |

**两个值得记下的架构发现**：
1. **远程命中缺少武器上下文。** 近战命中效果能直接拿 `weapon`（`_fire_melee` 里就有），
   但远程命中是 `Bullet` → `Player.on_enemy_hit_by_attack(enemy, context)`，
   `context` 里只有 `is_crit`/`damage`。任何「按武器差异化的远程命中效果」都必须先让
   投射物携带武器身份（例如 `activate()` 追加一个 `special_rules` 快照参数）。
   这也是 `spawn_projectiles_on_hit` 无法实现的根因。
2. **`activate()` 的位置参数已达 37 个**，新增参数只能追加到末尾。因此像「弹跳余量」
   这类单值，直接在 `activate()` 之后赋值（`bullet.bounce_remaining = n`）比继续加参数更清晰。

**顺带：两个语义待定的数据字段**（本批按原则未使用，需后续确认，不要当作已实现）：
- `spawned_projectile_range_scaling`（Sniper Gun）：正好是该武器 `damage.scaling` 中
  `range` 系数的一半（0.2→0.1、0.3→0.15），倾向理解为「生成弹的伤害同样按 range 缩放但系数减半」；
- `lightning_scaling`（Lightning Shiv / Thunder Sword）：在 Lightning Shiv 上等于该武器
  `melee_damage` 系数（同为 0.8），但在 Thunder Sword 上（1 vs 1.25/1.5）不等 ——
  无法判断是「同武器的缩放属性」还是「武器伤害的百分比」，故未使用。

#### 7.8 P2-1 字段卫生（已完成）+ P2-3 的前提修正（2026-09-15）

**P2-1：删除 `implemented` 死字段（方案 A，已扩大到全部 6 个目录）**

- **事实**：该字段在**每个**目录里都与实际可用性脱节 ——

  | 目录 | 条目 | `implemented=true` | 实际情况 |
  |------|------|-------------------|---------|
  | items | 235 | **0** | 全部照常被商店刷出（`get_shop_pool` 用的是 `_item_has_runtime_effects`）|
  | weapons | 78 | **5** | 78 把全部可获得，角色/商店都在用 |
  | characters | 62 | **1** | 62 个全部已接入角色选择 |
  | weapon_classes | 17 | **0** | 类加成阈值照常生效 |
  | item_tags | 31 | 3 | 纯描述性标签 |
  | upgrades | 100 | **100** | 全为 true，等于没有筛选作用 |

  **同一份数据上存在两个判据**，其中一个恒为 false（或恒为 true），属典型误导性死字段。
- **改动**：删除全部 **288 处** `implemented`；六个目录各改用一条**真实判据**：
  - items → `_item_has_runtime_effects()`（与 `get_shop_pool()` 完全一致）
  - weapons → `_weapon_has_runtime_tier()`（与 `get_weapon_shop_entries()` 一致；
    实测 78 把全部通过，故传 `false` 不再误伤）
  - characters / weapon_classes / item_tags / upgrades → **全部可用，无过滤条件**
    （参数保留以兼容调用方，实际不产生筛选；已在代码注释中写明）
  - 删除因此变成死函数的 `_filter_dictionary()`
  - 6 处 `_require_fields()` 的必填字段列表同步移除 `implemented`
- **顺手修掉一个真实缺陷**：`get_combat_dict(include_unimplemented := false)` 的**默认值是 `false`**，
  而它原本用 `row.get("implemented", false)` 过滤 weapons（78 把里只有 5 把为 true）——
  即**用默认参数调用只会拿到 5 把武器**。此前唯一调用方实传 `true` 所以没爆，
  但删字段后它会变成返回空表。现已统一为 `_weapon_has_runtime_tier()`，默认参数不再有陷阱。
- **新增断言**（`tests/brotato_data_catalog_smoke.gd`）：①六个目录都不得再出现 `implemented`；
  ②`get_items(false)` 与 `get_shop_pool(false)` 规模一致；
  ③`get_weapons(false)` / `get_characters(false)` / `get_combat_dict()`（**用默认参数**）
  都不得丢数据。已验证有效：临时把字段塞回 `weapons.json` 的一行，测试立即报
  `weapons 目录中仍有已删除的 implemented 字段: double_barrel_shotgun`。

**P2-3：任务前提有误 —— 而且我第一次的「补齐」结论也错了（两次都记下来，因为教训有价值）**

**第 1 次判断（错误）**：任务描述说「补齐 2 个物品到 237」。我用网页摘要的方式读 wiki 的
`/Items` 页并逐名比对，得到「A–R 段就缺 8 个」的结论（Blazemander / Bonk Dog / Bot-o-mine /
Catling Gun / Doc Moth / Jellyshield / Lootworm / Ratzilla），并据此推断真实总数 ≥ 243。

**为什么错**：那 8 个名字**是从长页面里让模型"列出全部物品名"得来的**。该页很长、被截断，
模型在真实条目之间穿插生成了 8 个**不存在**的名字 —— 它们按字母顺序整齐插在真实物品中间，
看起来毫无破绽。反查证实：`Ratzilla`、`Catling Gun` 等在 wiki 上**没有页面**，
在本项目的 items / weapons / characters 三个目录里也都不存在。

**第 2 次判断（已核实，正确）**：改用 **wiki 的 MediaWiki API** 取结构化数据，不经过任何模型摘要：

```
GET https://brotato.wiki.spellsandguns.com/api.php
    ?action=query&list=embeddedin&eititle=Template:Infobox Item&einamespace=0&eilimit=500
```

先确认真实物品页（如 `/Acid`）使用 `Template:Infobox Item`，再用**反向引用**枚举全部使用者 →
**恰好 235 个页面**。与目录 235 条归一化后逐名比对：

| 比对结果 | 数量 | 说明 |
|---------|------|------|
| wiki 有、目录没有 | **1** | `Ban System` —— 该页自述 *"This isn't a real item but a 'system'"*，只是复用了信息框模板，**不是物品** |
| 目录有、wiki 无独立页 | **1** | `Builder's Turret` —— 真实物品（被 Characters / Abyssal Terrors DLC / Seashell 引用），只是没有独立页面 |

**结论：物品目录 235 条是完整的，没有任何缺失。`items_total: 237` 是错数字，已更正为 235。**
原先的 237 并非「未达成的目标」，而是从未成立过的数字。

**改动**：
- `catalog_manifest.json`：`items_total` 237 → **235**；`notes` 记录核实方法与日期；
  `source_urls` 补上 API 查询地址（可复算）；
- 测试新增**一致性门**：`get_items(true).size()` 必须等于 manifest 的 `items_total`
  （这个不变量正是被 237 长期破坏的）。

**方法论教训（重要）**：**不要用"让模型总结长页面"的方式获取权威清单。**
分页/长列表场景下会产生「格式完全正确、位置完全合理」的幻觉条目。改用**结构化 API**
（MediaWiki 的 `list=` / `prop=` 查询、`embeddedin` 反向引用等）直接取数据 —— 可复算、可复核。
本次若不是回头做了「这 8 个名字在 wiki 上到底有没有页面」的对照检查，错误结论就会被写进文档并付之实施。

#### 7.9 远程武器命中上下文 + 弹片 + 一个连带修好的燃烧缺陷（2026-09-15）

**架构缺口（本轮补上）**：近战命中能直接拿到 `weapon`（`_fire_melee()` 里就有），
但远程命中是 `Bullet._on_body_entered()` → `Player.on_enemy_hit_by_attack(enemy, context)`，
而 `context` 里只有 `is_crit` / `damage` —— **不知道是哪把武器开的火**。
于是任何「按武器差异化的远程命中效果」都实现不了。

**改动链**：

| 位置 | 改动 |
|------|------|
| `Bullet` | 新增 `source_weapon_runtime_id`；`activate()` 追加该参数（位置参数已 37 个，只能追加到末尾）；命中回调的 `context` 带上它；`_return_to_pool()` 重置 |
| `PlayerCombat._fire_ranged()` | 发射时传入 `weapon.runtime_id` |
| `Player.on_enemy_hit_by_attack()` | 若 `context` 带 `weapon_runtime_id` → 转给 `combat.apply_ranged_weapon_hit_effects()` |
| `PlayerCombat` | 新增 `apply_ranged_weapon_hit_effects()` + `_find_weapon_by_runtime_id()` + `_apply_ranged_weapon_hit_effects()` |

**两个设计决定**：

1. **远程用独立的分发器**，不复用近战的 `_apply_weapon_hit_effects()` ——
   后者含 `burn` / `slow` 分支，而这两条在远程路径上由 `Bullet` 自己的
   `burn_damage` / `slow_on_hit` 通道施加，复用会导致**同一发子弹重复施加**。
   所以 `_apply_ranged_weapon_hit_effects()` 只放远程专属规则。
2. **武器身份用 `runtime_id` 而不是 `weapon.data` 快照**：子弹飞行途中武器可能被合成/移除，
   反查取不到就静默跳过（正确的容错）；同时避免每发子弹复制一份数据。

**顺带实现**：`spawn_projectiles_on_hit`（Sniper Gun）—— 命中后在目标处炸开
`spawned_projectiles_on_hit`（T3=5 / T4=8）个弹片，伤害取 `spawned_projectile_damage_base`（5）。
弹片**不携带武器身份**，因此不会递归触发本规则。
（`spawned_projectile_range_scaling` 语义待定，本批未使用 —— 见 §7.7 末尾。）

**连带发现的真实缺陷（已修）**：带 `burn` 规则的 5 把武器里 **3 把是远程**
（`particle_accelerator` / `wand` / `fireball`），而 `Bullet` 施加燃烧的**门槛是玩家的
`burn_chance`**（只来自 `fire_master` 协同或物品）—— 于是这 3 把武器的
`burn_damage` / `burn_instances` **完全是死数据**（近战走 `_apply_weapon_hit_effects`，不受影响）。
修法：**武器自带 burn 值时无条件施加**（这是武器规则，不该再掷骰子）；
玩家的 `burn_chance` 降级为「额外来源」，作用于不自带燃烧的武器。语义更清晰且不丢协同效果。

**验证**：`tests/ranged_weapon_context_smoke.gd`（新增）固定六组不变量：
身份随子弹传递、身份可反查并分发、弹片数量与伤害取自目录、**弹片不递归**、
武器已消失时静默跳过、远程分发器**不**处理 burn（防止重复施加），
以及「远程武器自带 burn 值时命中必须点燃 / 不带 burn 值在 `burn_chance=0` 时不得点燃」。
非空转验证：去掉 `context` 里的武器身份 → 报「应生成 8 个弹片，实际 0」；
把 `should_burn` 写死为 `false` → 报「自带 burn 值时命中应点燃，实际 burn_timer=0.00」。

#### 7.10 P4-1 交付明细：波次表目录化（2026-09-15）

**改造前的三个缺陷**（都不是「功能缺失」，而是「判据不可见」）：

1. **敌人池硬编码且会冻结**。`WaveManager._pick_enemy_type()` 是一串 `if main.wave >= N: pool.append(...)`，
   用「累积 append + 等概率抽取」表达权重 —— 所有已登场类型权重相同，配比既不可读也不可调；
   更关键的是**第 12 波之后再无任何分支，13-20 波实际是同一波**。
2. **刷怪间隔曲线是算出来的、不是设计出来的**。原式 `(2.0 - wave_num * 0.1)` 在第 20 波正好减到 0，
   被 `max(0.2, …)` 兜住 —— 于是 18/19/20 三波的间隔是同一个值，曲线尾段形状由下界决定。
3. **Boss 波次有三份判据**。`WaveManager.BOSS_WAVES`、`Main.BOSS_WAVES`、
   `HUDPanels.show_wave_summary` 里内联的 `[5, 10, 15, 20]`。改数据必然漂移。

**设计原则**（从原版 Brotato 的波次结构推导，写在 `enemy_waves.json` 的 `notes` 里）：

| # | 原则 | 落点 |
|---|------|------|
| 1 | 每波有一个**可命名的主题**，玩家据此形成针对性决策（补护甲 / 补射程 / 清场） | `theme` 字段；无修饰词时作为波次横幅显示 |
| 2 | 新敌种在固定波次登场，**登场后不回退**，存在感靠 `weight` 调节而不是开关 | 各波 `pool` 显式列出 |
| 3 | 威胁曲线是**阶梯 + 平台**：新类型登场那波压力突增，随后几波平台期让玩家成长追上 | `spawn_interval` 单调不增 + 池子平台期上限 2 波 |
| 4 | **数量与质量替代**：早期靠数量，后期由 armored / charger / shooter_spread / elite 接管 | 填充型权重 100%→11%，精英 0%→16%（第 20 波） |
| 5 | 目录只描述「刷什么、多久刷一只、刷多久」，**缩放全部留在代码里** | 难度倍率 / 动态难度 / 无尽倍率 / `enemies_percent` 仍在 `get_spawn_interval()` 计算 |

**改动**：

| 文件 | 改动 |
|------|------|
| `data/brotato/enemy_waves.json`（新） | 20 波 × {theme, duration, spawn_interval, boss, boss_count, pool[{type, weight}]} + 文档级 `total_waves` / `fallback` |
| `scripts/BrotatoData.gd` | 注册 `enemy_waves` 目录（该文件是「文档 + waves 数组」结构，需单独处理而非交给 `_index_array`）；新增 `_validate_enemy_waves()`：波号必须覆盖 1..total、主题非空、时长/间隔为正、`boss` 与 `boss_count` 自洽、`pool` 非空且权重为正、不允许有超出 `total_waves` 的多余波次 |
| `scripts/WaveManager.gd` | 时长 / 间隔 / 敌人池 / Boss 类型与数量全部改为读目录；`_pick_enemy_type()` 改为按权重抽取；新增 `get_wave_entry` / `get_wave_theme` / `get_boss_type` / `get_boss_count` / `total_waves()` / `enemy_types()`；**消费端兜底**：池里出现 `ENEMY_TYPES` 不存在的类型时剔除并只告警一次，整池被剔除则回落兜底池（`Enemy.setup()` 会做 `ENEMY_TYPES[type]` 直查，未知类型是运行时硬错误） |
| `scripts/Main.gd` | 删除 `TOTAL_WAVES` / `BOSS_WAVES` 两个副本，`_is_boss_wave()` 与通关判断改为转发 `WaveManager` |
| `scripts/HUDPanels.gd` + `scripts/HUD.gd` | `show_wave_summary()` 增加 `p_is_boss` 形参，删掉内联的 `[5, 10, 15, 20]` |
| `tests/enemy_wave_table_smoke.gd`（新） | 见下 |

**Boss 轮换与双 Boss**（P4-4 的数据侧）：波次表用 `boss` 指定类型、`boss_count` 指定数量，第 20 波为 2。
多 Boss 时血条只跟随「列表中第一个存活的」—— 改造前每只 Boss 都直连 `hud.update_boss_bar` /
`hud.hide_boss_bar`，多 Boss 会互相覆盖，且先死的那个会把还活着的 Boss 的血条一起藏掉；
现在改为经 `_refresh_boss_bar()` 交接，全部清空才隐藏。
**但 4 个 Boss 波目前仍指向同一个 `boss` 类型**，真正的差异化需要 `docs/boss-variants-design.md` 里的元素变体（P4-4 剩余 + P4-5）。

**数值调整入口**：改平衡只动 `data/brotato/enemy_waves.json` 一个文件，不需要碰任何 `.gd`。

**验证**：`tests/enemy_wave_table_smoke.gd` 固定五组不变量 —— 目录结构、跨文件一致性门
（池内类型与 Boss 类型必须存在于 `Enemy.ENEMY_TYPES`；池内不得出现 `tree` / `loot_alien` / `boss` / `miniboss`
这些有专用生成路径的类型）、威胁阶梯（敌种数单调不减、填充型占比下降、专业型占比上升、
**池子平台期不得超过 2 波**）、间隔曲线（单调不增且尾段不被下界抹平）、消费端契约
（8000 次抽样的频率分布符合权重、未知类型被剔除并回落、`get_spawn_interval` 仍随
`enemies_percent` 与难度倍率单调）。

非空转验证：① 把 `pick_enemy_type_for_wave()` 改成等概率抽取 → 8 项分布断言变红；
② 把 `_wave_pool()` 改成「13 波之后复用第 12 波」→ 7 项分布断言变红；
③ 把平台期上限调到 1 → 正确报出「第 1-2 波连续 2 波池子完全同构」。

**顺带修掉的一个测试缺陷**：`phase1_rules_smoke.gd` 的 `_check_wave_duration_source()` 原本是
grep `WaveManager.gd` 源码文本找 `1: 20.0`。时长搬到目录后该断言失效 —— 已改为直接读
`enemy_waves.json` 校验三条时长，并反向断言 `WaveManager.gd` 里**不得**再有硬编码时长表。

**⚠️ 待人工验证的平衡风险**：波次 1-15 的时长与间隔与改造前完全一致（不引入隐性平衡改动），
但 **13-20 波的池子此前是冻结的，现在补齐了演进**，后期实际压力会高于改造前
（精英权重由 5.6% 恒定升至 16%，装甲/冲锋/散射接管常规位）。这段曲线需要真机 playtest 定标，
调整入口就是 `enemy_waves.json`。

**遗留的重复判据**：`docs/architecture.md` 中仍有旧的波次描述待同步（本轮未动）。

#### 7.11 P4-5 交付明细：元素 Boss（P0 + P1，2026-09-15）

**范围**：按 `docs/boss-variants-design.md` 的分级，本轮只做前两级 ——
**P0 数据定义** + **P1 元素子弹 / 阶段差异化**；文档里的 P2（各 Boss 的独特机制）未做。

**一个必须先解决的前置事实**：设计文档写的是「Player 命中时 `apply_burn()`」，
但**玩家侧当时完全没有状态效果系统**（burn / slow / stun 一个都没有），
`apply_burn()` 这个函数并不存在。所以 P1 的真实工作量包含新建一个玩家状态模块。

**改动**：

| 文件 | 改动 |
|------|------|
| `scripts/PlayerStatus.gd`（新） | 玩家侧元素状态：燃烧 DoT / 减速 / 眩晕，含 `speed_multiplier()`、`process(delta)`、`clear()`、状态染色 |
| `scripts/Enemy.gd` | `ENEMY_TYPES` 加入 `boss_fire` / `boss_frost` / `boss_lightning`（取值即设计文档 P0 一节）；抽出 `BOSS_TYPES` + `is_boss_type()` / `uses_boss_behavior()` / `bullet_element()` 收敛原先散落的 4 处 `enemy_type == "boss" or "miniboss"`；`_on_phase_change` 改为按类型取速度倍率；Boss 弹幕按类型携带元素 |
| `scripts/EnemyBullet.gd` | 新增 `element` 字段（`activate()` 追加第三参数）、按元素染色、命中时把元素透传给 `take_damage()`；归还池时清空元素，避免池内残留 |
| `scripts/PlayerCore.gd` | `take_damage(amount, element)`：元素**只在伤害真正落地之后**施加；`process_movement()` 现乘 `status_speed_multiplier()` |
| `scripts/Player.gd` | 挂载 `status` 模块；`_physics_process` 推进；波次开始/结束清空状态 |
| `data/brotato/enemy_waves.json` | 第 5 / 10 / 15 波的 Boss 改为冰霜 / 火焰 / 雷电（按设计文档难度序），主题名同步改为「铁壁 / 烈焰 / 雷狱」 |
| `scripts/WaveManager.gd` | `spawn_boss()` 补 `return boss`（与 `spawn_tree` / `spawn_loot_alien` / `spawn_special_enemy` 保持一致）|

**三个设计决定**：

1. **不在消费点之外碰玩家属性。** 减速不写 `p.speed`，而是在 `process_movement()` 里现乘一个乘数。
   改属性再回滚是本项目反复踩过的坑（漏回滚就永久残留），而即时折算天然幂等。
2. **元素只在伤害真正落地后施加。** 位置选在 `PlayerCore.take_damage()` 过了
   无敌帧 / 闪避 / 免伤三道路径之后。语义上「被躲开的子弹不该上 debuff」；
   副作用同样是需要的 —— 一轮 8 发弹幕里只有第一发能落地，天然抑制眩晕连锁。
3. **眩晕必须「刷新」而不是「累加」，并带冷却。** 雷电 Boss 阶段 1 每轮 8 发；
   若累加，一轮就是 2.4 秒失控。另有 1.0s 冷却窗口，把最坏失控占比压到约 1/4。

**验证**：`tests/elemental_boss_smoke.gd` 固定七组不变量（数据与判据 / 弹幕元素与池化不串味 /
阶段差异化 / 命中落地门 / 状态语义 / 眩晕定量 / 波末清理）。

非空转验证（四刀，每刀都精确命中对应断言）：
① 把元素施加提前到三条守卫**之前** → 报「无敌帧内的命中不应附加减速」「被闪避的命中不应附加眩晕」
「被免伤挡下的命中不应附加减速」；
② 把 `apply_stun` 的 `max` 改成 `+=` → 报「眩晕应刷新而不是累加：剩余 0.25 + 施加 0.3 → 0.55」；
③ 去掉眩晕冷却 → 报「冷却期内的眩晕应被拒绝」；
④ 让三个变体的阶段倍率取同值 → 报「三个元素 Boss 的阶段速度倍率完全相同」。

**⚠️ 待 playtest 定标的数值**（全部集中在 `PlayerStatus.gd` 顶部，改一处即可）：

| 状态 | 取值 | 理由 / 风险 |
|------|------|------------|
| 燃烧 | 1 伤害 / 1 秒，最多 2 跳（2.0s） | 玩家基础 HP 只有 5，所以远轻于敌人身上的燃烧（3s / 0.5s tick）。重复命中只刷新时长不叠伤害 |
| 减速 | 30% × 2.0s | 取设计文档值；多个减速取更强者而非叠加，避免叠成「动不了」 |
| 眩晕 | 0.3s，结束后 1.0s 免疫 | 0.3s 是文档值；冷却与「刷新不累加」是本轮新增的防线 |

燃烧走 `apply_self_damage_without_invulnerability()`：DoT 不吃无敌帧也不吃护甲，
与敌人身上的燃烧语义一致（独立伤害通道）。否则「身上着火时刚好在无敌帧」会完全免疫。

~~**尚未实现（设计文档的 P2）**~~：**已于 2026-09-17 完成，见 §7.14。**
当时三个变体之间的差异只有 **数值 + 弹幕元素 + 阶段速度倍率**，机制上没有各自的印记。

**顺带记录一个新坑**（已写进 §五「单独跑测试前的两个前置条件」）：
新增带 `class_name` 的脚本后必须让 Godot 扫描一次项目，否则全局类名未注册，
所有引用该类的脚本静默解析失败、症状是一大片无关的 `Invalid access to property`。
`tests/run_all.sh` 已改为跑测试前静默 `--import` 一次。

---

#### 7.12 相机跟随 + 3×3 屏大地图（2026-09-17，**本文件首次记录**）

> 📌 **本节是补记。** 该系统在此之前**从未出现在本文档任何版本中**（见 §6.2 的说明）。
> 下面的事实全部来自 2026-09-17 对代码与测试的实测复核，不是事后追认的设计意图。

**问题**：改造前整个项目**没有「场地」这个概念**，于是有三处各自拿**视口**顶替场地。
在「相机固定」的年代这三处恰好等价，一旦相机开始跟随玩家，它们就**静默失效**：

| 调用点 | 代码里的语义 | 用视口顶替的后果 |
|---|---|---|
| 玩家移动钳位（`PlayerCore`） | 场地边界 | 玩家被锁死在一屏内 |
| 刷怪落点（`WaveManager`） | 屏幕外一圈 | 刷怪刷在玩家脸上 |
| 子弹出界回收（`Bullet` / `EnemyBullet`） | 离开视野 | 屏幕外的子弹收不回来 → 全图弹道堆积 → 卡顿 |

**解法**：新建 `scripts/Arena.gd`（`class_name Arena`）作为**单一数据源**，把三种边界一次讲清楚：

```gdscript
const WORLD_SCREENS_X: int = 3      # 世界 = 3×3 屏（用户确认的方案）
const WORLD_SCREENS_Y: int = 3
const SPAWN_MARGIN: float = 320.0   # 刷怪外扩 ≈ 一屏的 1/4
const FLOOR_SIZE := Vector2(1280.0, 720.0)   # 世界尺寸下界
const GROUND_ORIGIN := Vector2.ZERO          # 世界从 (0,0) 起算，不关于原点居中

func world_rect() -> Rect2          # 场地矩形 —— 玩家移动的硬边界
func camera_view_rect() -> Rect2    # 相机当前看到的矩形（约一屏）
func spawn_margin_rect() -> Rect2   # camera_view_rect() 外扩 SPAWN_MARGIN
func clamp_camera_center(desired)   # 相机钳位，场地边缘永远贴住视口边
func follow(target_position)        # 每帧跟随
func tick()                         # 刷新视口尺寸缓存（必须在 follow() 之前）
```

**接入方式**（`Main.gd:19-22` / `:78-90` / `:264-268`）：
`arena = Arena.new()` 作为第一个子节点 → `camera.make_current()` →
`camera.set_meta("__arena_follow", true)` → `arena.setup_camera(camera)`；
每物理帧先 `arena.tick()` **再** `arena.follow(player.position)`（顺序敏感，
理由见 `tick()` 的注释：否则窗口尺寸变化的那一帧相机会按旧尺寸钳位）。

**四个非显然的设计决定**：

1. **尺寸按视口算，不写死 3840×2160。** 玩家窗口可自由缩放，写死常数的话
   窗口一变大地图就不再是 3×3 屏了。
2. **世界原点不居中，`GROUND_ORIGIN = Vector2.ZERO`。** 这样**测试坐标与线上坐标语义一致**，
   不需要「测试坐标 ↔ 线上坐标」的额外换算。改成居中的话会同时改变
   玩家出生点、刷怪点、测试夹具三处语义，收益为零。
3. **不做 autoload。** 项目现有三个 autoload（`GameState` / `Effects` / `SaveSystem`）
   都是**无状态服务**；场地是**有状态**的（相机当前位置）且只在战斗场景里存在。
   做成 autoload 的话主菜单 / 角色选择 / 商店都会带着一份无意义的场地与相机状态，
   且每局重开还要额外处理重置。作为 `Main` 的子节点则天然随场景创建与销毁。
4. **`FLOOR_SIZE` 是实测需要的，不是防御性代码。** `--script` 模式下根视口是 64×64，
   没这个下界世界会塌成 192×64，相机每帧把玩家从测试摆好的位置拖走，
   一连串看似无关的断言都会红。

**一个踩过的注册时序坑**（`Arena._ready()` 的注释里留着）：
`Arena` 是 `Main.gd` 在运行时 `new()` 出来的，在场景树里排在 `Main.tscn` 里**写死的**
`ArenaBackground` 之后 —— `_ready()` 按子节点顺序走，背景先就绪时 `Arena.get_active()` 还是 null，
于是按「一屏视口」建了缓存。实测症状：`ARENA_BACKGROUND_READY world=1280x720`，而场地其实是 3840×2160。
修法是 `call_deferred("_register_now")` + 一份 `_deferred_listeners` 名单去唤醒早到的监听者。
**注意不能只 `resized.emit()`** —— 那些兄弟节点要连的是**将来**的那个实例，
实测此时 `resized.get_connections()` 是空的，只 emit 自己没人收到。

**验证**：`tests/camera_arena_smoke.gd`（362 行）固定五条不变量：
① 相机真的跟随且在世界边缘钳位（不露出地图外空白）；
② 玩家能在**超过一屏**的范围里活动（改造前被视口锁死）；
③ 世界是 3×3 屏且背景铺满整个世界（不是只铺一屏）；
④ 刷怪用的是「**相机外圈**」而不是「世界外圈」—— 否则相机在场地中央时敌人会刷在 3840px 之外，玩家永远见不到敌人；
⑤ 子弹按「离开视野」回收，按「离开世界」判的话全图弹道会堆积。

---

#### 7.13 商店 UI / 交互重做（2026-09-17，**本文件首次记录**）

> 📌 **本节的起点不是一句需求，而是一句玩家反馈：「运行游戏时没发现这些改动」。**
> 它推翻了「代码在仓库里 + 31 个套件全绿 = 工作完成」这个假设。
> 下面按「发现的顺序」写，因为这正是三处缺陷被逐个揪出来的真实过程。

**功能侧交付**（对应提交 `13805cd` / `68b1d4d` / `00bcbf8` / `cbf5560`）：

| 项 | 内容 |
|---|---|
| 拖拽合成 / 交换 | `_get_drag_data`(4) / `_can_drop_data`(3) / `_drop_data`(8) / `gui_is_dragging`(2)；两把同名同阶拖到一起 → 数量 −1 且剩者 tier +1 |
| 武器出售 | `_append_weapon_sell_rows()` / `_on_weapon_sell_pressed(slot_index)` / `_weapon_sell_price()` |
| 锁定跨波次 | `locked_indices` + `locked_prices`：锁定时**冻结价格快照**，重掷不改 |
| 玩家侧权威账本 | 新增「已获得道具」清单，记账条目数 / 字段 / 来源 / **实付价**，使出售能精确撤回 |
| 语义分离 | **卡槽号 ≠ 装备位号**。购买记录不再把商店卡槽号当 `slot_index` 存（`00bcbf8`），`get_weapon_info()` 的 `slot_index` 与下标严格一致 |

**布局侧：三处缺陷，逐个看**

**① `Panel` 不是容器 —— 内容完全渲染不出来（但不报错）**
`$Panel` 是 `Panel` 类型（非容器），`add_child()` **不替子节点布局**。
不显式给 `offset_*` 的话子节点停在 `(0,0)` 且 `size.x = 0`。
`SellScroll` / `UpgradeScroll` 因此整个不可见。

**② 动态区重叠 —— 「武器合成」标签压在商品卡上**
`HBoxContainer` 会**按子节点最小尺寸把自己撑开**，场景里写的 `offset_bottom` 管不住它
（ItemRow 设 300，实际撑到 435）。修法是让布局由 `_sync_dynamic_layout()` 单一权威驱动，
行高从卡片推导、面板高度取 `min(内容, 可用)` 且**只增不减**。

**③ 内容容器不撑满区域 —— 修完①②之后的第三起，也是玩家反馈的**真正成因****
修完①②我去截图验收，肉眼看到「已购买 / 已装备武器」两条标题下面**像是空的**。
但当时 **31 个套件全绿**，连刚补强过的判据①~⑥ 也全绿。

实测（`tools/probe_scroll_width.gd`，A/B 对照）：

```
=== 补 flags 之前 ===
Panel/UpgradeScroll    区域宽=1200  内容容器宽=228   撑满=false  flags=1
Panel/SellScroll       区域宽=1200  内容容器宽=239   撑满=false  flags=1
>>> 已给两个内容容器补 size_flags_horizontal = SIZE_EXPAND_FILL
=== 补 flags 之后 ===
Panel/UpgradeScroll    区域宽=1200  内容容器宽=1200  撑满=true   flags=3
Panel/SellScroll       区域宽=1200  内容容器宽=1200  撑满=true   flags=3
WIDTH_PROBE_RESULT: 根因 = 缺 size_flags_horizontal
```

根因：**`ScrollContainer` 会把子节点按 `minimum` 尺寸摆放**，不给
`size_flags_horizontal = SIZE_EXPAND_FILL` 就永远撑不满。
条目虽然「存在且可见」，却全部挤在左侧一条 ~240 宽的窄柱里，
「出售(+N材料)」按钮离标签很远 —— 整块区域在视觉上读起来就是**空的**。
flags 取值：`1 = SIZE_FILL`（不撑满）vs `3 = SIZE_FILL|SIZE_EXPAND`（撑满）。

**修法**（`Shop.gd` 两处各一行，注释里带上了完整推导与外号，见 `:822` / `:1145`）：

```gdscript
sell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
upgrade_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

**测试盲区补强**：`tests/shop_layout_smoke.gd` 判据从 6 类升到 **7 类**。
前三类（容器矩形合法 / 在面板内 / 不重叠）**对宽度缺陷完全免疫**，这正是
「31 套件全绿但玩家看不见」的机制。新增判据⑦ 直接断言**两个中间量**：

- ⑦a 内容容器宽度必须撑满区域（`区域宽 - 子宽 > 1.0` 即报红，报文带上实测两侧数值）
- ⑦b 内容高度不得超出区域（否则底部被裁，玩家看不到）

**变异验证**（`tools/mutate_shop.cjs` + `tools/run_mutation.cjs`，实跑）：
新增 `content-no-expand` / `upgrade-no-expand` 两个变异，均为
「**编译自检通过 → 套件 FAIL(1 项) → 捕获**」。
判据⑦ 报红时实测 `子宽=239 区域宽=1200 差=961`，与原始症状一致，**而判据①~⑥ 仍全绿** ——
完整复现了「外框正确但内容挤成一坨」。

**确定性验收**：截图里「已购买」行为空还有**第二个原因** ——
`tools/capture_shop.gd` 按随机商品购买，买到武器就归入「已装备武器」。
改用**确定性探针** `tools/probe_sell_row.gd`（直接注入 `purchased_items` 一条非武器道具，
不靠抽卡运气），实测四行同时渲染、宽度均 1200、`y=0..108` 恰好铺满 108 高区域、零裁剪：

```
行[0] 已购买（点击出售返还50%材料）        size=(1200.0, 20.0)  y=0..20   标题
行[1] 测试护符                          size=(1200.0, 28.0)  y=24..52  **条目**
行[2] 已装备武器（点击出售返还50%材料）      size=(1200.0, 20.0)  y=56..76  标题
行[3] 手枪  T1                         size=(1200.0, 28.0)  y=80..108 **条目**
SELLROW_PASS
```

**另一处被证否的假说**：我肉眼判断「合成卡被裁」。`tools/probe_upgrade_card_height.gd` 实测
卡片 90 高、区域 110 高，**富余 20**，内部 VBox 只需 73~78。
**所以没有去修这个非缺陷** —— 卡片是左对齐挨着标签，属 HBox 正常行为。
（教训：截图上的「看起来被裁」不等于被裁，先量再说。）

**同轮修掉的相邻缺陷**：`tests/upgrade_panel_layout_smoke.gd` 覆盖的波末升级面板
「偏右 + 右边越界」。根因是 `set_anchors_preset(PRESET_CENTER)` 在面板**还没有尺寸**时被调用
（`custom_minimum_size` 只是**最小**尺寸，设置它不会立刻改变实际尺寸），
四个 offset 全被算成 0 → 矩形塌缩成屏幕中心一个点，之后内容把它撑开就**往右下长**。
**正解是交给铺满全屏的 `CenterContainer` 托管** —— 与尺寸、分辨率都无关，
改内容也不会复发，比「按顺序调 API」稳。

**同轮修掉的真实缺陷**：`PlayerUpgrades.remove_upgrade()` 的武器分支过去**只比较 `type`**：

```gdscript
for i in range(p.equipped_weapons.size()):
    if p.equipped_weapons[i].type == upgrade.get("weapon_type", ""):
        p.equipped_weapons.remove_at(i)   # ← 卖 T2 会移除先遍历到的 T1
```

玩家同时持有同类型不同分阶武器时（SMG T1 + SMG T2，合成后的常规状态），
**卖 T2 会移除 T1**，而数量对得上 → 只看数量的断言发现不了。
修法与回归门见 `tests/weapon_remove_by_tier_smoke.gd`。

**⚠️ 未闭合项（登记，不在本轮范围）**：
- **商店数值口径偏差**：重掷公式与回收比例与原版有差 —— 用户明确本轮不动，属**设计决策**而非缺陷。
- **约定 R1**：商店 UI 的状态（选中 / 禁用）**不得用 `modulate` 表达**
  （它是乘算且作用于整棵子树，会把文字一起压暗）。已加断言（`45110b6`），
  状态一律表达在**边框 / 底色 / 字体色**上。

---

#### 7.14 Danger 0-5 难度模型（P4-3）+ 元素 Boss 独特机制（P4-5 的 P2）（2026-09-17）

**P4-3 难度模型**（`scripts/GameState.gd:185-290`）

改造前只有三档（0=简单 0.7 / 1=普通 1.0 / 2=困难 1.4），经由
`get_difficulty_multiplier()` **一个标量**同时影响敌人强度与刷怪间隔。
本次升级为 Danger 0-5，每档**三个维度**：

| 维度 | 常量 | 取值 |
|---|---|---|
| 敌人强度倍率（HP / 接触伤害 / 移速） | `DIFFICULTY_MULTIPLIERS` | `{0:0.70, 1:1.00, 2:1.00, 3:1.12, 4:1.26, 5:1.40}` |
| 刷怪密度倍率（>1 更密，作刷怪间隔的除数因子） | `DANGER_SPAWN_MULTIPLIERS` | `{0:0.85, 1:1.00, 2:1.00, 3:1.06, 4:1.13, 5:1.20}` |
| 每档**额外**精英概率（池外叠加） | `DANGER_ELITE_CHANCES` | `{0:0, 1:0, 2:0.05, 3:0.05, 4:0.15, 5:0.15}` |

**权威数值来源**：Brotato Wiki《Danger Levels》。原版对敌人的强化是**该档的总量**、
**不是逐级叠加**（wiki 原文 "The Health and Damage increases are the total for that danger level"）。
**注意 D1 与 D2 都是 1.00 —— 这不是漏填**，原版 D0-D2 就是无属性强化，
这三档的差异体现在精英率与刷怪密度上。

**三处有意偏差**（各自都有对应常量的推导注释，不要「修正」它们）：

1. **Danger 0 = 0.70**（原版 D0 也是 1.00）。本作把「调低敌人强度」固化成入门档，
   数值沿用改造前「简单」档的 0.70，避免旧体验丢失（原版把这件事交给无障碍滑条）。
2. **刷怪密度是本作新增的档位旋钮**（原版不改刷怪间隔）。
   推导式 `1.00 + (强度倍率 - 1.00) * 0.50` —— 密度只吃强度增量的**一半**。
   系数取 0.5 的两条理由：① 波次表自身已把第 20 波基础间隔压到 `MIN_SPAWN_INTERVAL = 0.2` 下界，
   密度全量叠加会被下界整段吃掉；② 间隔是 `base / 强度 / 密度`，密度再全量叠加会让高难档
   刷怪量呈**平方增长**（1.4 × 1.4 ≈ 2 倍），超出「逐级加压」的设计意图。
3. **精英概率是「轮次 → 概率」的换算口径，不是原版直给的数**。原版形状是**阶梯**
   （D2 == D3、D4 == D5，两档一台阶；`gameplay.tips` 的独立攻略给出同一结构，两来源互证）：
   按 `total_waves = 20` 折算「每只敌人附带额外精英的概率」—— 1 次事件 / 20 波 = 0.05；
   3 次 / 20 波 = 0.15。
   ⚠ **原版没有「每档 +5 个百分点」这条直线 —— 那种写法是在真实值之间插中值，属凭空造数，
   不要写回来。测试里有一条反向断言专门守住这一点。**

**已知偏离（刻意保持）**：原版 Danger 只缩放敌人的**伤害与 HP**，**不动移速**；
本作的 `get_difficulty_multiplier()` 自改造前起就同时乘移速（`Enemy.gd:207`），
这是既有契约，本次刻意不改。**后果：本作高难档的敌人比原版更「贴身」，
评测难度手感时不要按原版预期。**

**衔接**：旧「普通」= Danger 1（基准 1.00，既有测试全部跑在这一档）；
旧「困难」= 强度 1.40 = 新 Danger 5（见 `LEGACY_DIFFICULTY_TO_DANGER`）。
角色选择界面有 6 档卡片（`CharacterSelect.DANGER_INFO`：轻松 / 常规 / 危险 / 危险+ / 高难 / 噩梦），
数值一律经 `GameState.get_danger_profile()` **现取**，界面上不存第二份 ——
否则改了模型却忘了改界面，玩家看到的就是上一版的数字。

**验证**：`tests/danger_model_smoke.gd`（674 行）同时校验公式与字面量。

---

**P4-5 的 P2：元素 Boss 独特机制**（`scripts/Enemy.gd` + 新增 `scenes/BurnZone.tscn`）

§7.11 留下的 P2 已于本轮完成。三个变体现在**机制上各有印记**，不再只是「数值不同的同一个 Boss」：

| Boss | 独特机制 | 关键常量（`Enemy.gd`） |
|---|---|---|
| 火焰 | 火焰冲锋 + 燃烧区域（`BurnZone`）+ 烈焰光环 | `BURN_ZONE_SPACING`、`BURN_ZONE_SCENE = preload("res://scenes/BurnZone.tscn")` |
| 冰霜 | 冰甲循环（减伤）+ 冻结脉冲（1s 蓄力预警） | `FROST_ARMOR_REDUCTION := 30`、`FREEZE_PULSE_STUN := 1.5` |
| 雷电 | 闪现传送 + 链式闪电 + 雷暴领域 | `BLINK_MIN_DIST := 100.0` / `BLINK_MAX_DIST := 200.0`、`CHAIN_BOUNCES_P1 := 2` / `CHAIN_BOUNCES_P2 := 3`、`STORM_DAMAGE := 3` / `STORM_DELAY := 0.8` |

关键实现点：`Enemy.gd:5` `const BURN_ZONE_SCENE = preload(...)`、`:1141` `_shoot_chain_bolt()`、
`:1118` `_blink()`、`:917` `_on_phase_change()`。

**验证**：`tests/boss_mechanics_smoke.gd`（783 行）。两条写法值得记：

1. **每条机制既有正向断言，也有反向断言** —— 只有正向断言的测试可能恒真；
   周期/间隔类机制一律带「不到间隔不应触发」的反向断言，否则间隔参数是否生效根本没被验到。
2. **位移不受传入 delta 控制**：这些机制都跑在 `_physics_process` 里，测试手动调用它
   （先 `set_physics_process(false)`）所以**计时器**的 delta 可控；但
   `move_and_slide()` 内部用引擎固定步长（1/tick），「同步推 N 步」只推进
   N × velocity / 60 的位移。这条正是「冲锋余量」的来源 ——
   `DASH_MARGIN_MIN_RATIO := 1.2` 是**显式断言**的下限（实测 68.4px 位移 vs 40px 阈值 = 1.71× 余量），
   目的是让物理推进退化时红灯落在「余量自检」这条明确断言上，
   而不是让「冲锋路径应生成燃烧区域」变成一条读不出原因的随机红。

### P3 — 架构还债（2-3 天）

目标：控制 Player.gd 规模，建立统一效果系统。

| 编号 | 任务 | 目标文件 | 实现要点 |
|------|------|---------|---------|
| P3-1 | 抽取物品效果模块 | `scripts/ItemEffects.gd`（新） | 把 `Player.gd` 中物品专用函数（Candy Bag、Axolotl、 burning kill 等）迁移到这里 |
| P3-2 | 抽取爆炸/状态效果模块 | `scripts/CombatEffects.gd`（新） | 把 `deal_catalog_explosion`、`deal_hit_explosion`、`on_enemy_elemental_hit` 等通用战斗效果迁移 |
| P3-3 | Player.gd 回归门面 | `scripts/Player.gd` | 只保留协调函数，目标减到 400 行以内 |
| P3-4 | 更新文档 | `CLAUDE.md`、`docs/architecture.md` | 反映新的模块边界 |

### P4 — Phase 2 保真：敌人、波次、难度、Boss（1-2 周）

目标：向原版 Brotato 的波次结构和难度模型靠拢。

| 编号 | 任务 | 目标文件 | 状态 | 实现要点 |
|------|------|---------|------|---------|
| P4-1 | 敌人波次表 | `data/brotato/enemy_waves.json`（新）+ `scripts/WaveManager.gd` | **完成（2026-09-15）** | 20 波各定义主题 / 时长 / 基础刷怪间隔 / 敌人池权重；连带修掉「12 波后池子冻结」与「间隔曲线被下界抹平」两个缺陷。见 §7.10 |
| P4-2 | 精英词缀系统 | `scripts/Enemy.gd` | **仍待做** | 现有 `elite_trait` 只有 fast / armored / ghost 三种硬编码特性；需扩为可配置词缀池（再生、反弹、护盾等）。**注意**：波次表已把精英权重从恒定 5.6% 提到第 20 波的 16%，Danger 4/5 还会再叠 15%，词缀丰富度的收益比改造前更高 |
| P4-3 | Danger 0-5 难度模型 | `scripts/GameState.gd` + `scripts/WaveManager.gd` + `scripts/CharacterSelect.gd` | **完成（2026-09-17）** | 替换简单/普通/困难，改为 Danger 0-5，三维度（强度 / 刷怪密度 / 额外精英概率）；三处**有意偏差**各有推导注释，不要「修正」。见 §7.14 |
| P4-4 | Boss 轮换 | `scripts/WaveManager.gd` + `scripts/Enemy.gd` | **完成（2026-09-15）** | 类型/数量由波次表驱动、20 波双 Boss；配合 P4-5 后四个 Boss 波已各不相同（冰霜 → 火焰 → 雷电 → 均衡双 Boss）|
| P4-5 | 元素 Boss 变体 | `scripts/Enemy.gd` + `scripts/EnemyBullet.gd` + `scripts/PlayerStatus.gd`（新）+ `scenes/BurnZone.tscn` | **P0 + P1 + P2 全部完成（2026-09-17）** | P0/P1（2026-09-15）：三变体的数据定义、弹幕元素、阶段速度倍率差异，以及**玩家侧全新的燃烧/减速/眩晕状态系统**（此前完全不存在），见 §7.11。P2（2026-09-17）：三个 Boss 各自的独特机制 —— 火焰冲锋+燃烧区域 / 冰甲+冻结脉冲 / 闪现+链式闪电+雷暴领域，见 §7.14 |

### P5 — 场地与 UI（2026-09-17 新增分类）

> ⚠️ **本分类是补上的。** P1–P4 只覆盖逻辑/数值系统，
> 「相机 + 大地图」与「商店 UI」在此之前**不属于任何分类** —— 功能做了却没进跟踪表。
> 与 §6.2 是同一件事的两个视角（一个看差距、一个看任务）。

| 编号 | 任务 | 目标文件 | 状态 | 实现要点 |
|------|------|---------|------|---------|
| P5-1 | 场地单一数据源 | `scripts/Arena.gd`（新）+ `scripts/Main.gd` | **完成（2026-09-17）** | 场地 / 相机可视 / 刷怪外扩三种矩形一次讲清，取代三处「拿视口顶替场地」；世界 3×3 屏、相机跟随并钳位。见 §7.12 |
| P5-2 | 战场背景铺满世界 | `scripts/ArenaBackground.gd`（新） | **完成（2026-09-17）** | 几何缓存按 `Arena` 尺寸重建（比一帧绘制贵得多，不能每帧重算）；用 `Arena.on_ready_geometry()` 订阅，**不必关心自己排在 Arena 前面还是后面** |
| P5-3 | 商店拖拽 / 出售 / 锁定 | `scripts/Shop.gd` + `scripts/PlayerUpgrades.gd` | **完成（2026-09-17）** | 拖拽合成交换、武器出售、锁定跨波次价格冻结；武器移除改为按 **tier 精确定位**（原先只比 `type`，卖 T2 会移除 T1）。见 §7.13 |
| P5-4 | 商店布局权威 | `scripts/Shop.gd` | **完成（2026-09-17）** | `_sync_dynamic_layout()` 单一权威：行高从卡片推导、面板高度 `min(内容, 可用)` 且只增不减。修掉三处缺陷，见 §7.13 |
| P5-5 | 升级面板居中 | `scripts/HUD.gd` | **完成（2026-09-17）** | 交给铺满全屏的 `CenterContainer` 托管，取代「在尺寸为 0 时调 `set_anchors_preset`」 |
| P5-6 | ~~商店数值口径对齐~~ | `scripts/Shop.gd` | **用户明确本轮不动** | 重掷公式与回收比例与原版有差 —— 属**设计决策**而非缺陷 |

---

## 八、风险与依赖

| 风险 | 影响 | 缓解 |
|------|------|------|
| ~~Godot headless 在沙箱内崩溃~~ | ~~自动化验证受阻~~ | **已消解**：2026-09-17 实测 `--headless` 可正常跑全部 **31** 个套件，入口为 `bash tests/run_all.sh` |
| **`Player.gd` 继续堆积（现 2,088 行）** | P1/P3 改动冲突 | P1 先只做最小侵入式分发；P3 再重构 |
| **新增：`Shop.gd` 也涨到 1,431 行** | 布局与业务逻辑混在一处，改动易互相干扰 | P3 时一并抽出布局模块（见 §4.2） |
| 🔴 **测试全绿但功能不可用** | 玩家反馈「运行游戏时没发现这些改动」，而 30 个套件全绿 | **这是本项目最严重的一类风险**：既有断言只测「节点存在 / 数据正确」，不测**可见几何与布局**。已补判据（§7.13 判据⑦ + `camera_arena_smoke`），但**根治手段是把「人眼截图验收」固定进交付流程**，不能只靠事后补测试 |
| 🔴 **`.git` 已三次出现异常** | 对象库损毁 → 历史丢失（已发生两次，186 个提交不可恢复） | ① 本机对象库**不能是唯一副本**，必须保持远端同步；② 任何涉及 `.git` 的操作前先跑 `git count-objects -v` 看 `in-pack` 是否为 0；③ 保持 `CODEBUDDY_SAFE_DELETE_REPORT_PATH` 有值。取证见 `docs/GIT_HISTORY_RECOVERY.md` |
| 武器规则数量多（65 种） | 一次性实现易出错 | 按 batch 优先级分周交付，每批配测试 |
| ~~升级目录改动影响存档~~ | ~~破坏旧存档~~ | **无影响**：四选一是按需生成的运行时状态，不进存档 |
| 存档版本号与新内容 | 未来加内容时破坏旧存档 | 加内容前先确认 `SaveSystem` 的字段容忍度，必要时版本号加 1 并迁移 |
| 数据目录 `implemented` 字段语义不清 | 后续开发者困惑 | P2-1 明确方案并删除歧义 |
| ~~`base_stats` 单位约定不统一~~ | ~~属性描述文本出现荒谬数值（如「闪避: -3000%」）~~ | **已缓解（2026-09-15，见 §10.4）**：`dodge` 已加加载期校验门，且数据统一为分数。新增属性时仍要先确认 `to_game_state_character()` 的消费方式 |

---

## 十、已知回归与修复记录

| 问题 | 发现时间 | 修复提交 | 说明 |
|------|---------|---------|------|
| 波次切换崩溃：`Cannot call method 'get_first_node_in_group' on a null value` | 2026-07-18 | `be1899c` | 在 `Enemy.gd` 的 `_ready`、`_reset_spawn_state`、`_drop_xp` 以及 `XPOrb.gd` 的 `activate()` 中对 `get_tree()` 加 null 保护；同时删除 `.godot` 缓存以排除导入导致的敌人不可见问题。|
| 敌人不可见 | 2026-07-18 | `9aeff45` | 新增 `_ensure_visible()` 安全网，强制校正 `visible`/`modulate`/`$Body` 透明度。**注：这是对下述池缺陷的症状性补丁** |
| **敌人池空闲态失效（根因）** | 2026-09-15 | 见下 | 详见 §10.1 |
| `phase_d2` 角色名断言过期 | 2026-09-15 | 见下 | 断言写死英文 `"Romantic"`，而 7-20 的 i18n 提交已把目录文案改为「浪漫主义者」。已改为从目录读取期望值，避免随文案失效 |
| `item_runtime_effect_smoke.gd` 解析错误 | 2026-09-15 | 已删除 | 自创建起从未运行：静态调用实例方法 `BrotatoData.get_shop_pool()`，并调用不存在的 `PlayerUpgrades.apply_catalog_item()`/`remove_catalog_item()`。覆盖范围由 D4 承担 |
| **`phase2_loot_weapon_smoke` 偶发假失败**（旧记「约 8%」，实测 25%~55%） | 2026-09-15 首记<br>2026-09-16 重新定位 | 见下 | 详见 §10.2。**旧根因（敌人碰撞）与「40 次全过」已被推翻**，真因是 headless 视口只有 64×64 导致子弹被出屏回收 |
| **Boss 生成时刷 `Parameter "data.tree" is null`** | 2026-09-15 | 见 §10.3 | `_reset_spawn_state()` 用 `get_tree() != null` 做守卫，但节点不在树里时**调用 `get_tree()` 本身就会报错** —— 守卫拦在调用之后，来不及生效。Boss / 小 Boss 走的正是「先 `setup()` 再 `add_child()`」的路径 |
| **玩家报的 5 个战斗 bug**（移动时不开火 / 波末仍开火且击杀隐形物掉经验 / 子弹打不到树 / 近战无视觉 / 碰撞体与显示不符） | 2026-09-15 | 见 §10.5 | 前两条同一根因：`DetectArea` 报的是**物理重叠**，池实例只被移出分组、没关碰撞层 |
| **`phase_d4` 的 Rip and Tear 检查间歇失败** | 2026-09-15 | 见 §10.5 末 | 测试把三只敌人与玩家摆在同一 y 线，飞行中的子弹打到「半径外诱饵」。用改动前的提交连跑 8 次全过，确认是测试隔离缺陷而非既有偶发 |
| **角色闪避描述显示成「闪避: 1500%」** | 2026-09-15 | 见 §10.4 | `characters.json` 把 `dodge` 写成百分点（brawler=15 / crazy=-30），而描述渲染与运行时应用都按分数处理。玩法侧有一个静默的 `/100` 容忍分支所以没坏，描述渲染没有这条分支 → 界面出现荒谬数值。**根因是同一份数据有两条单位转换路径，其中一条漏了** |
| **远程武器的 `burn` 规则完全失效** | 2026-09-15 | 见 §7.9 | `Bullet` 施加燃烧的门槛是玩家的 `burn_chance`（只来自 `fire_master` 协同/物品），于是 3 把远程武器（particle_accelerator / wand / fireball）的 `burn_damage` / `burn_instances` 是死数据。已改为「武器自带 burn 值即无条件施加，玩家 burn_chance 降级为额外来源」 |

### 10.1 敌人池空闲态失效（2026-09-15）

**症状**：headless 每次运行刷 30+ 行 `Enemy visibility restored: normal pos=(0.0, 0.0)`；玩家在游戏里被看不见的东西攻击。

**根因**：`Main._init_pools()` 在 `add_child()` **之前**调用 `set_physics_process(false)` / `set_process(false)`。
Godot 的 `Node.set_physics_process()` 在内部标记已等于目标值时直接早退，而节点进入场景树时又会因为脚本定义了
`_physics_process` 而重新启用处理 —— 这两行完全无效。由此产生两个后果：

1. 预建的 30 个敌人每物理帧运行**完整 AI**：朝玩家移动、造成接触伤害。这正是「敌人不可见却会挨打」的成因；
   而 `9aeff45` 的可见性安全网只是把它们从「看不见的攻击者」变成了「角落里的 30 个红方块」。
2. `_ensure_visible()` 每物理帧把这些空闲实例的 `visible` 拨回 `true`，而 `Main.get_enemy()` 正是用
   `if not e.visible` 判定实例是否空闲 —— 于是池永远命中不到空闲实例，**每次刷怪都新建节点**，
   实测启动阶段池规模即从 30 膨胀到 31。对象池（提交 `1d81726` 的性能优化）形同虚设。

**修复**：
- `Main._init_pools()`：改为先 `add_child(e)` 再 `e.recycle()`，并在注释中写明顺序敏感性。
- `Enemy.recycle()`：补上 `remove_from_group("enemies")`。空闲池实例不属于活敌人 —— 这与
  `Enemy.die()` 中已有的 `remove_from_group("enemies")` 以及 `Main.get_enemy()` 取用时重新入组互为镜像，
  原本就漏了一处。炮台 / 地雷 / 小地图 / 各类 AoE 都以该组为扫描范围，且多数以 `visible` 作二次过滤。

**回归测试**：`tests/enemy_pool_idle_state_smoke.gd`。已验证非空转：把 `_init_pools` 还原为错误顺序后，
该测试立刻变红并复现 `31 → 32` 的池膨胀与全部刷屏。

**遗留项：已修，见 §10.4。** 当时发现 `characters.json` 的 `dodge` 单位不统一
（`-30 / 15` 百分点 vs `-0.2 / -0.05 / 0.3` 分数），会渲染出「闪避: -3000%」这类文本。
2026-09-15 已把静默的归一化容忍换成加载期报错，并把数据统一为分数。

### 10.2 `phase2_loot_weapon_smoke` 偶发假失败（2026-09-15 首记 / 2026-09-16 重新定位）

> ⚠️ **本节 2026-09-15 的根因结论（敌人压在玩家身上触发 `_on_body_entered`）与
> 「修复后连续 40 次全部通过」都已被推翻。真实根因是出屏回收，与碰撞无关。**
> 旧结论错在一个没被检验的前提上：原文第 863 行写着「`_process` 里的出屏回收不会触发该问题
> —— 玩家位置在视口内」。这个前提在 headless 下不成立。

**症状**：报 `ERROR: Activated player bullet should be visible`。只有根节点 `visible` 为 false，
`Body.visible` / 比例 / z_index 全过。

**真实根因**：headless 下**根视口实际是 64×64**，不是 `project.godot` 声明的 1280×720。连锁反应：

1. Main 的场地布局按视口尺寸铺开 → 玩家落在 `(44, 44)`；
2. `Bullet._process()` 的出屏线是 `screen.x + 50 = 114`；
3. 本测试自身的同步建场工作（实例化整个 Main）把下一帧 `delta` 抬到 ~0.14s，
   子弹 500px/s × 0.14s = 70px，一发就从 x=44 越过 114 → 被回收。

探针原始输出（临时在 `Bullet._return_to_pool()` 开头打 `Engine.get_process_frames()` 与
`get_stack()`，只在测试打过 `meta("probe_tag")` 的实例上打印；**测量完成后已完整还原，
`scripts/Bullet.gd` 与 HEAD 逐字节一致**。下面栈里的行号来自打了探针的那份临时副本）：

```
[DIAG] frames=0 viewport=(64.0, 64.0) player.pos=(44.0, 44.0)
[DIAG] enemies_total=0 near_player(<80px)=0
[PROBE] activate_tail visible=true mon=false mask=0 pos=(44.0, 44.0) | frame=0
[PROBE] process_tick delta=0.14306 life_before=0.0000 pos=(44.0, 44.0) | frame=0
[PROBE] RETURN_TO_POOL visible=true life=0.1431 pos=(115.5317, 44.0) mon=true mask=0 | frame=0
    #1 _return_to_pool @ res://scripts/Bullet.gd:135
    #2 _process @ res://scripts/Bullet.gd:196      ← 出屏分支
```

判读：`pos.x = 115.53 > 64 + 50 = 114` 越线；`life = 0.143 < 3.0` 排除寿命回收；
`returns` / `gravity_fall` 均为 false 排除回旋与重力分支；栈指向 `_process` 的出屏那两行。
而 **`enemies_total = 0`** —— 旧结论说的「敌人压在玩家身上」在这条路径上根本不可能发生。

**旧修复为何失效**：`collision_mask = 0` 针对的是**碰撞路径**，真因在**移动路径**，
两者毫无关系，所以它必然挡不住。原记录的「连续 40 次全过」是**运气**：是否越线取决于那一帧的
`delta`，而 `delta` 随机器负载浮动（阈值 `delta > 0.14s`）。旁证：改动前在本机连跑 20 次失败 11 次
（55%），在干净 master 上连跑 12 次失败 3 次（25%）—— 同一份代码，两个比例。

**新修复**：在 `_run()` 开头把根视口还原成工程声明的尺寸，尺寸从 `ProjectSettings` 读，
不写死数字：

```gdscript
var viewport_w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
var viewport_h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
root.size = Vector2i(viewport_w, viewport_h)
```

这不是「让测试变绿」：断言、`await process_frame`、检查内容全部原样保留，改的是**测试环境失真**。
出屏线随之移到 1330px 外，本检查不可能再被它影响。原有的 `collision_mask` 隔离保留
（它只隔离与断言意图无关的碰撞子系统，成本为零），但注释已按实测改正，不再宣称它是本次偶发红的修复。

**验证**：改动前连跑 20 次失败 11 次；改动后**连续 45 次全部通过**。

**留给后面的教训**：一个「玩家位置在视口内」的直觉前提，在 headless 里是错的（视口只有 64×64）。
凡是依赖视口 / 世界边界的产品逻辑，在 headless 测试里都要先把视口尺寸摆正；
否则测试跑的不是线上那个世界。

### 10.3 Boss 生成时的 `get_tree()` 报错（2026-09-15）

**症状**：每次生成 Boss / 小 Boss 都刷两行
`ERROR: Parameter "data.tree" is null. at: get_tree (scene/main/node.h:549)`，
调用链为 `_reset_spawn_state → setup → spawn_boss → advance_wave`。功能本身正常，属于纯噪音。

**根因**：`Enemy._reset_spawn_state()` 里写的是

```gdscript
if player == null or not is_instance_valid(player):
    if get_tree() != null:            # ← 这个守卫不起作用
        player = get_tree().get_first_node_in_group("player")
```

节点不在场景树里时，**调用 `get_tree()` 这一步本身就会 push_error**，null 检查发生在调用**之后**，
拦不住。`spawn_boss()` / `_spawn_miniboss()` 是 `instantiate() → setup() → add_child()` 的顺序，
`setup()` 执行时节点尚未入树，因此必然踩到。

这与 §10.1「池实例处理顺序」属于同一类问题：**Godot 的节点 API 很多在树外调用会直接报错，
而不是安静地返回 null。** 判断能否安全调用，要用 `is_inside_tree()`，不能用 `get_tree() != null`。

**修复**：改用 `is_inside_tree()`。入树后 `_ready()` 会补上 player 的解析，所以这里跳过解析不影响行为。

**备注**：该缺陷改造前就存在（Boss 波各报一次）；P4-1 把第 20 波改成双 Boss 后噪音翻倍，
才在新增的双 Boss 集成检查里被注意到。

### 10.4 角色闪避描述显示成「闪避: 1500%」（2026-09-15）

**症状**：角色选择界面里 brawler 的闪避显示成 `1500%`、crazy 显示成 `-3000%`。

**根因不是「某条数据写错」，而是同一份数据有两条单位转换路径，其中一条漏了**：

| 路径 | 位置 | 是否做了单位换算 |
|------|------|-----------------|
| 运行时应用 | `PlayerUpgrades._normalize_character_stat_delta()` | ✅ 有 `if abs(value) > 1.0: return value / 100.0` |
| 描述渲染 | `BrotatoData._character_desc()` | ❌ 直接 `int(value * 100)` 拼 `%` |

于是 `dodge = 15`（本意 15%）被玩法侧静默救成 `0.15`（**玩法侥幸是对的**），
而描述侧算出 `15 × 100 = 1500%`。两条路径各自演化，必然会在某个时刻分叉。

**改动**：

| 文件 | 改动 |
|------|------|
| `scripts/BrotatoData.gd` | 新增 `_validate_character_dodge_unit()`：`base_stats.dodge` 与 `rules` 里的 dodge 必须是分数（`\|value\| ≤ 1` 表示 ≤100%），否则**加载期直接报错** |
| `scripts/PlayerUpgrades.gd` | 删掉 `_normalize_character_stat_delta()` 里的 `dodge` 容忍分支（只保留 `attack_speed_percent`，那个字段按百分点存是**已文档化的例外**）|
| `data/brotato/characters.json` | brawler `dodge` 15 → `0.15`、crazy `-30` → `-0.3`（`base_stats` 与 `rules` 两处）|

**为什么数据只改这 2 处**：全量扫描过 62 个角色，分数型字段里只有这 2 个值的绝对值 > 1；
其余如 `enemy_health_percent: 2.5`、`pickup_range_percent: 2` 是**合法的「超过 100% 的加成」**，
不是单位错误，不能一起「修」。

**为什么可以安全删掉容忍分支**：该分支的触发条件是 `abs(value) > 1.0`，而修完数据后
**没有任何角色满足它** —— 也就是说它对所有数据的落点与「不换算」完全相同。
现在由加载期报错接手：写错单位会立刻失败，而不是被悄悄纠正一半。

**验证**：`tests/character_stat_unit_smoke.gd`（新增）固定四组不变量 ——
全量单位门、描述与数据一致、门确实有牙（注入百分点写法后必须报错）、修复前后数值意图不变。

非空转验证：① 把 brawler 的数据改回 `15` → 直接复现原症状，报
「brawler 的闪避百分比不合理: 「闪避: 1500%」」等 5 条；② 摘掉校验门的调用 →
报「把 dodge 写成百分点（15）后校验竟然没报错 —— 单位门失效」。

**顺带清掉的两项**：删除零引用死代码 `scripts/UpgradeChoiceData.gd`（含 `.uid`）；
`docs/architecture.md` 的波次/敌人/状态效果描述已同步（原来声称「15 种敌人类型」，
实际已是 20 种）。

### 10.5 玩家报的五个战斗 bug（2026-09-15）

用户报告：BUG1 移动时无法射击、BUG2 回合结束还在射击 + 击杀不可见物体掉经验、
BUG3 枪械子弹打不到树、BUG4 近战武器没有视觉、BUG5 normal 敌人碰撞体积与显示不符。

#### BUG1 + BUG2 是**同一个**根因：目标缓存把池实例当成活敌人

`PlayerCombat._refresh_enemy_cache()` 直接拿 `DetectArea.get_overlapping_bodies()`。
那是**物理重叠**，与 `enemies` 分组无关；而 `Enemy.recycle()` 只把池实例移出分组、
**并没有关掉碰撞层**（`collision_layer = 2` 一直开着）。于是池里的隐形实例照样被扫到：

- `fire_weapon()` 取「最近的敌人」——最近的可能是**隐形池实例**。它若在射程外，
  就走到 `nearest_dist > range → return`，**一发都不开**（症状：移动时像是无法射击）；
  若在射程内，子弹则朝看不见的地方飞。
- 近战 `_fire_melee()` 遍历的就是这份缓存，且**不做分组/可见性过滤**，
  于是能把已经 `hp <= 0` 的池实例**再打死一次** → `die()` → 掉落经验球
  （症状：击杀不可见物体掉经验）。

**修法**：缓存按「在 `enemies` 组 + 可见 + `hp > 0`」二次过滤，与炮台 / AoE / 小地图的
既有判据（都以 `enemies` 分组为准）保持一致。

BUG2 还有两处独立成因，一并修掉：

- `Main._on_wave_ended()` **只回收敌人、不回收子弹**（`restart_game()` 一直有这段清理），
  敌方子弹会一路飞进商店阶段继续打玩家；
- 玩家在非战斗阶段照常开火：`Player.process_mode = PAUSABLE`，而商店阶段并不暂停整棵树 →
  新增 `Main.is_combat_phase()`，`Player` 只在战斗阶段调 `process_weapons()`。

#### BUG3 子弹打树

`Bullet._on_body_entered()` 第一行 `if not body.is_in_group("enemies"): return`，
而树在 `neutral_trees` 分组（`Enemy.setup` 会把它从 `enemies` 移出）→ 被整个挡掉。

修法不是简单放开分组，而是**给非敌人目标开一条「只吃伤害」的短路**：
击杀回调 / 命中回调 / 吸血 / 总伤害统计 / 点燃 / 元素 / 减速都是围绕「敌人」语义的，
套到树上会变成 bug（例如打不还手的树刷吸血）。顺带补上「不可见 / `hp <= 0` 不结算」。

#### BUG4 近战没有视觉

远程至少有子弹，近战此前**完全没有反馈**：打没打、打多远、多久一下都看不出来。
补两层：**常显范围环**（暗，整圈 —— 与「半径内所有敌人」的判定一致，不分方向）
+ **挥击闪光弧**（亮，朝向目标，向外扩散后淡出，0.18s ≈ 最快近战冷却量级）。

#### BUG5 碰撞体积与显示不符

场景里写死的 18 其实**正好等于**旧视觉 32×32 方块的等面积圆半径 `√(32²/π) ≈ 18` ——
原作者就是按「面积相等」定的。换成精灵后视觉尺寸改为按贴图计算，这个关系就断了。

- `UnitVisual.visual_radius()`：等面积圆半径（精灵按**不透明像素面积**算，隔点采样 + 缓存）
- `Enemy._sync_collision_extents()`：碰撞体与接触范围由它反推；
  **必须先 `duplicate()`** —— 场景里的 shape 是**共享 SubResource**，
  直接改半径会让所有实例互相污染（最后 setup 的那个敌人决定全场）

实测报文可直接佐证：`normal 的碰撞半径应为视觉等效半径 19.98，实际 18.00`。

#### 验证

新增 `tests/combat_target_validity_smoke.gd`。**五处修复逐一破坏，对应断言全部精确变红**
（含上面那条给出具体数值的报文）。过程中还发现**测试自身两处空转**并修掉：
未 `activate()` 的子弹（`visible=false` 会让 `_on_body_entered` 直接早退）、
以及读错位置的 `shots_fired` 计数（武器状态在 `_combat_state`，不在 weapon 字典里）。

#### 顺带修掉的一个既有测试隔离缺陷

`phase_d4_catalog_item_runtime_smoke` 的 Rip and Tear 检查间歇性失败（实测 2/10）。
用 `git worktree` 在**改动前的提交**上连跑 8 次全过，证明不是既有偶发，是我的修复引入的 ——
但根因在测试：它把三只敌人与玩家**摆在同一 y 线上**，
飞行中的手枪子弹会沿这条线飞到 640px 外命中作为「半径外诱饵」的 far_enemy
（掉 3 点 = 一发手枪；命中即回收，所以断言时看到的在场子弹是 0）。
基线之所以稳定只是时机凑巧。
**修法是隔离，不是放宽断言**（同 §10.2）：测量期间冻结世界 + 清空在场子弹后，连跑 12 次全过。

---

## 九、即时下一步

基线全绿（**31/31**，2026-09-17 实测，`bash tests/run_all.sh` → `PASS=31 FAIL=0`）。下一步分两条：

### 9.1 需要用户在 Godot 编辑器里人工确认（自动化测不到的部分）

> 🔴 **这一节现在是最高优先级。** 理由不是「惯例要求手动验证」，
> 而是 2026-09-17 实测证明：**31 个套件全绿的同时，商店的三处缺陷玩家一个都看不见。**
> 自动化能证明「对象在正确位置」，证明不了「人看得见、看得懂、点得到」。

1. **商店（本轮改动最密集，也是最需要看的）**：
   - 进入商店后，「已购买（点击出售返还50%材料）」与「已装备武器（点击出售返还50%材料）」
     两条标题下面**应该有内容**（条目 + 右侧的「出售(+N材料)」按钮）。
     **如果看起来是空的 —— 那就是缺陷还在**，参照 §7.13 判据⑦ 的成因（内容容器未撑满 → 挤成 239px 窄柱）。
   - 拖拽两把**同名同阶**武器到一起 → 应合成、数量 −1 且剩者 tier +1；
     拖两把**不同名**的 → 应**不**合成（这是反向预期）。
   - 点「锁定」后开始下一波再回来 → 该槽仍是原商品、**价格未变**。
   - 锁定 / 选中的状态应表达在**边框 / 底色 / 字体色**上；
     **若看到文字被压暗**，说明有地方误用了 `modulate`（约定 R1）。
2. **相机 + 大地图（本轮新增，人工最容易感知）**：
   - 世界应有 **3×3 屏**那么大 —— 按住方向键往一个方向走，应能走出远超过一屏的距离；
   - 走到场地边缘时，**不应看到地图外的空白**（相机应钳位）；
   - 相机移动时，**敌人不应突然出现在玩家脸上**（刷怪用的是相机外圈而非世界外圈）。
3. **波末升级面板**：选择框应完整落在屏幕内且大致居中（此前是「偏右 + 右边越界」，见 §7.13）。
4. **难度（Danger 0-5）**：角色选择界面应有 **6 档卡片**（轻松 / 常规 / 危险 / 危险+ / 高难 / 噩梦），
   切档时提示数值应随之变化、**不应恒为同一组数**（界面上不许存第二份数值）。
5. **三个 Boss 的独特机制**（第 5 / 10 / 15 波）：应能**肉眼分辨**出
   火焰冲锋留燃烧地面 / 冰霜冰甲循环与冻结脉冲 / 雷电闪现与链式闪电 ——
   在此之前它们只是「数值不同的同一个 Boss」。
6. 打开工程按 F5 跑一局，**第一波**的旧检查项仍然有效：
   - 屏幕左上角（世界坐标原点 0,0 附近）**不应**有红色方块聚集成群 —— 这是 §10.1 的池缺陷，
     修复前会有 30 个预建敌人在角落里游走向玩家逼近；
   - 玩家不应在视野内没有敌人的情况下持续掉血；
   - 小地图角落不应出现 30 个静止的敌人光点。
7. ~~确认角色选择界面的描述文案没有出现荒谬数值（如「闪避: -3000%」）~~
   **已修（2026-09-15，见 §10.4）**：数据单位已统一为分数，且加了加载期校验门，
   不会再出现这类文本。仍建议顺路扫一眼界面，确认描述整体读起来正常。
8. 波次结束后点击「开始」进入第二波不应报错。

### 9.2 继续推进的功能项（按优先级）

| 优先级 | 项 | 说明 |
|--------|-----|------|
| ~~0~~ | ~~P2-2 升级目录补齐~~ | **已完成（2026-09-15）**，见 §7.1 |
| ~~1~~ | ~~穿透（pierce）数值化~~ | **已完成（2026-09-15）**，见 §7.3 |
| ~~1~~ | ~~P1-8 武器规则~~ | **基本完成（已 55/65，85%）**。剩余 10 条全部确认为「目录缺取值」或「需新建子系统」，逐条理由见 §7.7 |
| ~~2~~ | ~~远程命中上下文~~ | **已完成（2026-09-15）**，并连带实现 `spawn_projectiles_on_hit`、修好远程武器 `burn` 失效的缺陷。见 §7.9 |
| 0 | ~~P2-3 物品目录：先做一个决策~~ | **已完成，且不需要决策**（2026-09-15）：复核确认目录本就完整（235/235），错误在 manifest 的 `items_total: 237`，已更正为 235。见 §7.8 |
| 1 | ~~P2-1 字段卫生~~ | **已完成并扩大到全部 6 个目录（2026-09-15）**，删除 288 处 `implemented`、各目录改用真实判据、顺手修掉 `get_combat_dict()` 默认参数的陷阱。见 §7.8 |
| ~~2~~ | ~~统一其余目录的 `implemented` 语义~~ | **已完成（2026-09-15）**，与 P2-1 合并完成。见 §7.8 |
| ~~1~~ | ~~P4-1 敌人波次表~~ | **已完成（2026-09-15）**，并连带修掉「12 波后池子冻结」与「间隔曲线被下界抹平」两个缺陷。见 §7.10 |
| ~~2~~ | ~~P4-4 Boss 轮换（数据侧）~~ | **部分完成（2026-09-15）**：类型/数量改为数据驱动、第 20 波双 Boss 已实现；4 个 Boss 波仍指向同一类型。见 §7.10 |
| ~~1~~ | ~~P4-5 元素 Boss 变体 P0 + P1~~ | **已完成（2026-09-15）**：三个变体的数据、弹幕元素、阶段倍率差异，以及**全新的玩家状态系统**（燃烧/减速/眩晕）。见 §7.11 |
| ~~1~~ | ~~P4-5 剩余：三个 Boss 的独特机制（设计文档的 P2）~~ | **已完成（2026-09-17）**：火焰冲锋+燃烧区域 / 冰甲循环+冻结脉冲 / 闪现+链式闪电+雷暴领域；`scenes/BurnZone.tscn` 已建。三个 Boss 不再只是「数值不同的同一个 Boss」。见 §7.14 |
| ~~4~~ | ~~P4-3 Danger 0-5 难度模型~~ | **已完成（2026-09-17）**：三维度模型（强度 / 刷怪密度 / 额外精英概率）+ 角色选择 6 档卡片；三处有意偏差各有推导注释。见 §7.14 |
| ~~0~~ | ~~**相机 + 大地图**~~ | **已完成（2026-09-17），且是补记** —— 该系统此前不在本文档任何分类里。`Arena.gd` 作单一数据源、世界 3×3 屏、相机跟随并钳位。见 §7.12 |
| ~~0~~ | ~~**商店 UI / 交互重做**~~ | **已完成（2026-09-17），同为补记**：拖拽合成交换 / 武器出售 / 锁定跨波次 / 权威账本；并修掉三处布局缺陷（其中一处是玩家反馈的真正成因）。见 §7.13 |
| **1** | **P4-2 精英词缀系统** | `Enemy.elite_trait` 目前只有 fast / armored / ghost 三种硬编码特性（`Enemy.gd:295-303`），需扩为可配置词缀池。注意：波次表已把精英权重从恒定 5.6% 提到第 20 波的 16%，**Danger 4/5 还会再叠 15% 的池外概率**，词缀丰富度的收益比改造前更高 |
| 2 | **P3 架构还债** | `Player.gd` 仍偏大（实测 **2,088 行**），按计划抽出 `ItemEffects.gd` / `CombatEffects.gd`。**建议一并处理 `Shop.gd`（1,431 行）**：它的布局算法与业务逻辑混在一处，是本轮布局缺陷反复出现的一个背景因素 |
| 3 | **补齐武器数据的空缺字段**（可选） | 若要让 §7.7 里那 10 条剩余规则中的 9 条也能实现，需要在 `weapons.json` 里补字段（各武器缺什么已在 §7.7 表中列清）。**这是数据设计决策** |
| ~~6~~ | ~~小项：清死代码 / 同步文档~~ | **已完成（2026-09-15）**：删除零引用的 `scripts/UpgradeChoiceData.gd`（含 `.uid`）；`docs/architecture.md` 的波次 / 敌人 / 状态效果描述已同步。见 §10.4 |
| 7 | **属性单位约定扩容（可选）** | `dodge` 已有加载期校验门（§10.4）。其余字段（`armor`/`range`/`luck` 等整型、`*_percent` 分数、`attack_speed_percent` 百分点）**仍只靠注释约定**。若再出现混用，照 §10.4 的做法把「单位白名单校验」扩到全部字段 |
| **8** | **把「人眼截图验收」固定进交付流程** | 本轮最贵的教训（§7.13）：31 个套件全绿，玩家却看不见功能。建议每次涉及 UI 的交付都跑一次 `tools/capture_shop.gd` 并**真的看图**。截图目前不入库（`shots/` 在 `.gitignore`），是否纳入跟踪值得决策 |
| 9 | **商店数值口径与本文件的两处未闭合项**（低优先） | ① 重掷公式 / 回收比例与原版的偏差（用户明确本轮不动，属设计决策）；② `refs/remotes/` 写不进盘导致 `origin/main` 无法 `rev-parse`（见 `docs/GIT_HISTORY_RECOVERY.md` 末）。 |

---

*本文件应随每次阶段完成而更新勾选状态和实际工时。*
