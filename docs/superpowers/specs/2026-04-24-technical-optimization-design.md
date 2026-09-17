# Brotato Clone — 技术优化设计方案

## 目标

对 Brotato_Gavin 项目进行全面技术整理，分两个阶段、四个并行 Agent 执行。

## 约束

- 不改功能逻辑，重构前后行为完全一致
- 不 push、不创建远程仓库
- 不安装新依赖
- 全部在 `Godot/brotato-gavin/` 目录内工作

---

## 阶段 1（并行）

### Agent-1：Git 初始化

**职责**：初始化 git 仓库，保护现有代码。

**步骤**：
1. `git init` 在 `Godot/brotato-gavin/`
2. 检查并补充 `.gitignore`（当前已有 `.godot/` 和 `/android/`，需确认是否完整）
3. `git add` 所有项目文件
4. 创建初始提交："Initial commit — Brotato_Gavin v0.1"

**交付物**：干净的 git 仓库 + 首次提交

---

### Agent-2：项目文档

**职责**：编写项目文档，理清架构，为后续开发提供参考。

**CLAUDE.md 内容**：
- 项目概述：Brotato 复刻版，Godot 4.6，GDScript，GL Compatibility 渲染
- 运行方式：Godot 编辑器打开 `project.godot` 直接运行
- 代码规范：PascalCase 场景/类名、snake_case 变量/函数、信号命名 `xxx_changed`
- 文件组织：`scripts/` 脚本、`scenes/` 场景、`data/` 数据资源
- 架构概览：autoload 单例（GameState、Effects、SaveSystem）、场景层级
- 已知技术债：大文件清单、重复代码位置
- 开发约束：无外部美术/音频资源，全部程序化生成

**docs/architecture.md 内容**：
- 模块依赖图
- 数据流：角色选择 → Main → 波次循环 → 商店 → 下一波
- 信号总线：各模块间信号连接关系
- 对象池机制说明

**交付物**：`CLAUDE.md` + `docs/architecture.md`

---

## 阶段 2（并行，依赖阶段 1 完成）

### Agent-3：深度代码重构

**职责**：拆分大文件，重新设计模块边界。

**Player.gd（900+行）→ 5 个模块**：
| 新文件 | 职责 |
|--------|------|
| `PlayerCore.gd` | 移动、HP、受伤、无敌帧、基础属性 |
| `PlayerCombat.gd` | 武器系统、射击逻辑、暴击/吸血计算 |
| `PlayerUpgrades.gd` | 被动效果应用/移除、协同效果系统 |
| `PlayerBuffs.gd` | 临时增益（拾取物）、元素弹药 |
| `PlayerStats.gd` | 统计数据追踪、动态难度采样 |

**Main.gd（1100+行）→ 4 个模块**：
| 新文件 | 职责 |
|--------|------|
| `WaveManager.gd` | 波次状态机、生成逻辑、波次修饰词 |
| `PickupManager.gd` | 战利品拾取物生成/收集/消失 |
| `TurretManager.gd` | 工程师炮塔 + 死灵法师亡灵 |
| `EventManager.gd` | 特殊事件系统 |

**HUD.gd → 3 个模块**：
| 新文件 | 职责 |
|--------|------|
| `HUDCore.gd` | HP/XP/金币/波次等基础显示 |
| `HUDCombat.gd` | 连击、Boss血条、伤害闪烁 |
| `HUDPanels.gd` | 暂停菜单、结算面板、成就通知 |

**接口设计原则**：
- 通过信号通信，不直接引用其他模块内部状态
- 每个模块暴露清晰的公共方法接口
- Main.gd 作为协调者，持有各 Manager 引用并连接信号
- Player 子模块通过 `owner`（CharacterBody2D）引用共享状态

**交付物**：重构后的代码，功能与重构前完全一致

---

### Agent-4：性能优化

**职责**：优化运行时性能，减少卡顿和内存压力。

**对象池扩展**：
- 敌人池化（当前每波 `queue_free` + `instantiate`）
- 拾取物池化（当前用 `Area2D.new()` 动态创建）
- 伤害数字/特效粒子池化（Effects.gd 当前每次 `new`）

**帧计算优化**：
- `DetectArea.get_overlapping_bodies()` 缓存 + 定时刷新（每 0.1 秒）
- 敌人 AI 分帧处理：不是所有敌人每帧都更新
- 协同效果检查改为增量更新（当前每次购买全量遍历）

**内存管理**：
- `damage_events` 更积极清理
- 状态效果 `modulate` 改为状态变更时才更新

**HUD 优化**：
- 标签文本更新改为值变化时才执行（信号驱动）

**交付物**：优化后的代码，功能不变

---

## 验证方式

每个 Agent 完成后：
1. 项目能在 Godot 4.6 中正常打开
2. 能从 MainMenu 开始一局游戏
3. 能完成至少 1 波战斗 + 商店阶段
4. 无 GDScript 编译错误

## 风险

- 重构可能引入信号连接遗漏 → 通过 grep 检查所有 `.connect(` 调用
- 性能优化可能改变行为边界 → 只改缓存/刷新频率，不改逻辑
- 多 Agent 并行可能产生文件冲突 → 阶段 2 的两个 Agent 改不同文件
