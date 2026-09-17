# Brotato Gavin — 项目指南

## 项目概述

Brotato（土豆兄弟）复刻版，使用 Godot 4.6 + GDScript 开发，GL Compatibility 渲染模式。全部视觉效果和音频均为程序化生成，无外部美术/音频资源。

## 运行方式

Godot 编辑器打开 `project.godot`，按 F5 直接运行。主场景为 `MainMenu.tscn`。

## 代码规范

- **PascalCase**：场景名、类名（如 `WeaponData`、`WeaponDatabase`）
- **snake_case**：变量名、函数名（如 `hp_changed`、`equip_weapon`）
- **信号命名**：`xxx_changed`、`xxx_started`、`xxx_activated` 等过去式
- **常量**：UPPER_SNAKE_CASE（如 `MAX_WEAPONS`、`ENEMY_TYPES`）
- **节点引用**：`@onready` 获取场景内节点，Autoload 通过名称直接访问

## 文件组织

```
scripts/        GDScript 脚本
scenes/         Godot 场景文件（.tscn）
data/           数据资源（weapons.tres）
docs/           项目文档
```

## 场景流程

```
MainMenu → CharacterSelect → Main（战斗 + 商店循环，共 20 波）
                                  ↓
                            GameOver / Victory
```

- **MainMenu**：开始游戏、设置（音量/分辨率/全屏）、退出
- **CharacterSelect**：角色选择（14 种角色，含锁定解锁机制）、难度选择（简单/普通/困难）、无尽模式开关
- **Main**：战斗波次（20秒/波）→ 商店（购买升级/武器）→ 下一波，Boss 波为第 5/10/15/20 波

## 架构概览

### Autoload 单例

| 单例 | 职责 |
|------|------|
| `GameState` | 角色定义（14 种）、难度系统（0.7x/1.0x/1.4x）、无尽模式状态 |
| `Effects` | 粒子/视觉效果（命中火花、死亡爆炸、升级闪光、浮动伤害数字） |
| `SaveSystem` | 存档（user://brotato_save.json）、角色解锁、成就系统（10 项） |

### 核心脚本

| 脚本 | 职责 |
|------|------|
| `Main.gd` | 战斗主循环：波次管理、敌人生成、对象池、特殊事件、拾取物、炮塔/亡灵 |
| `Player.gd` | 玩家角色：移动、射击、受伤、升级、武器管理、协同效果、临时增益 |
| `Enemy.gd` | 敌人系统：15 种敌人类型、状态效果（燃烧/冻结/减速/眩晕）、Boss 阶段 |
| `Shop.gd` | 商店：物品池（武器+被动）、稀有度加权、刷新/锁定/出售、武器升级 |
| `HUD.gd` | UI 层：血条/XP/金币/波次/连击/小地图/Boss 血条/通知/暂停菜单 |
| `WeaponData.gd` | 武器数据资源类（Resource），定义战斗属性和特殊属性 |
| `WeaponDatabase.gd` | 武器数据库资源类，管理武器列表，提供战斗字典和商店条目转换 |
| `Bullet.gd` / `EnemyBullet.gd` | 子弹系统（支持对象池） |
| `XPOrb.gd` | XP 球（支持对象池） |
| `AudioManager.gd` | 程序化音频生成（BGM + 音效） |

### 通信方式

信号驱动通信。Player 通过信号通知 HUD 和 Main，Main 协调各子系统。

## 已知技术债

- `Player.gd`：900+ 行，职责过重（移动、射击、武器管理、协同效果、临时增益全部在一个文件）
- `Main.gd`：1100+ 行，职责过重（波次管理、敌人生成、对象池、特殊事件、拾取物、炮塔/亡灵）
- `HUD.gd`：职责过多（UI 构建、通知系统、连击系统、小地图、暂停菜单等全在一个文件）

## 开发约束

- 无外部美术资源，所有图形通过 `Polygon2D`、`ColorRect` 等程序化生成
- 无外部音频资源，`AudioManager` 程序化生成音效和 BGM
- 渲染模式为 GL Compatibility，不使用高级渲染特性
- 视口分辨率 1280×720
