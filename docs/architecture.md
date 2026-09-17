# 架构文档

## 模块依赖图

```
project.godot
  ├── Autoload: GameState.gd   （角色定义、难度、全局状态）
  ├── Autoload: Effects.gd     （粒子/视觉效果工厂）
  └── Autoload: SaveSystem.gd  （存档、解锁、成就）

MainMenu.gd
  └── → CharacterSelect.gd（场景切换）

CharacterSelect.gd
  ├── → GameState（读取角色数据、写入 selected_character/difficulty）
  ├── → SaveSystem（查询角色解锁状态）
  └── → Main.gd（场景切换）

Main.gd（战斗主场景）
  ├── → HUD.gd（实例化、信号连接）
  ├── → Shop.gd（实例化、信号连接）
  ├── → Player（通过 group "player" 查找、信号连接）
  ├── → Enemy.tscn（实例化、信号连接）
  ├── → Bullet / EnemyBullet / XPOrb（对象池管理）
  ├── → GameState（读取难度倍率、无尽模式）
  ├── → SaveSystem（更新记录、检查解锁/成就）
  └── → Effects（调用视觉效果）

Player.gd
  ├── → WeaponDatabase / data/weapons.tres + BrotatoData（加载武器数据）
  ├── → GameState（读取角色属性）
  ├── → Effects（命中火花、升级闪光）
  └── → Main.gd（通过 get_parent() 获取对象池方法）

Enemy.gd
  ├── → GameState（读取难度倍率）
  ├── → Effects（伤害数字、死亡爆炸）
  └── → Main.gd（通过 get_parent() 使用对象池、连接 died 信号）

Shop.gd
  ├── → WeaponDatabase / data/weapons.tres + BrotatoData（加载武器商店条目）
  └── → Player（通过 player_ref 调用 apply_upgrade / remove_upgrade）

HUD.gd
  └── 纯 UI 层，通过信号接收数据，不直接依赖游戏逻辑
```

## Brotato Content Catalog

`scripts/BrotatoData.gd` loads structured non-art content data from `data/brotato/*.json`.
The current seed catalog contains the manifest, effect schema, item tags, weapon classes, upgrades, item rows, all 62 reference character rows, and expanded weapon tier rows.
Weapon rows may define `minimum_tier` when the reference weapon only appears from a higher tier; `BrotatoData.validate()` only requires tiers from that minimum through Tier 4.

Runtime integration is staged:

- `GameState.get_character_select_entries()` exposes data-backed Brotato default characters to `CharacterSelect.gd`.
- `GameState.get_character()` converts catalog characters into the existing Player-compatible stat dictionary.
- `WeaponDatabase.catalog_combat_dict()` converts catalog weapon tier rows into the current combat dictionary format, including higher-`minimum_tier` weapons through exact per-tier entries.
- `PlayerCombat.gd` merges catalog combat rows over legacy `data/weapons.tres` rows, keeping old weapons as fallback.
- `WeaponDatabase` filters empty and `Unknown` legacy placeholder weapon types before exposing fallback combat or shop entries.
- `Shop.gd` uses catalog weapon shop entries as the canonical shop weapon source when available; legacy weapon entries are used only if the catalog yields no shop weapon entries.

The catalog is now the canonical place for new Brotato-like non-art content. Legacy hardcoded pools remain only as compatibility fallback until weapon special-rule runtime coverage and 237-item data migrations are complete.

## 数据流

### 角色选择 → 战斗初始化

```
CharacterSelect._on_char_selected(key)
  → GameState.selected_character = key
  → GameState.difficulty = diff_id
  → get_tree().change_scene_to_file("res://scenes/Main.tscn")

Main._ready()
  → player = get_tree().get_first_node_in_group("player")
  → 连接 Player 的所有信号到 HUD

Player._ready()
  → c = GameState.get_character()    # 读取角色定义
  → max_hp = 5 + c.hp_bonus          # 应用角色属性
  → base_speed = 300.0 + c.spd_bonus
  → equip_weapon(c.weapon)           # 装备起始武器
  → _init_character_passive()        # 初始化角色专属被动
```

### 波次循环

```
Main._on_wave_started()              # Shop.wave_started 信号触发
  → wave += 1
  → wave_timer = WaveManager.get_wave_duration(wave, endless_mode)
  → state = State.WAVE
  → _pick_wave_modifier(wave)        # 随机波次修饰词
  → economy.begin_wave_snapshot()    # 记录本波起始材料
  → player.wave_regen()              # 每波回血
  → player.on_wave_start()           # 角色被动触发
  → spawn_boss() × boss_count        # 数量取自波次表，第 20 波为 2
  → _try_trigger_event()             # 特殊事件（每5波40%概率）
```

本波的**时长、刷怪间隔、敌人池权重、Boss 类型与数量**全部来自
`data/brotato/enemy_waves.json`：由 `BrotatoData` 加载并做结构校验，`WaveManager` 消费。
改波次节奏只动这一个数据文件，不需要碰 `.gd`。

| 字段 | 作用 |
|------|------|
| `theme` | 波次主题；该波没有随机修饰词时作为横幅显示（「第 7 波 · 远火」）|
| `duration` | 本波时长（秒）|
| `spawn_interval` | **基础**刷怪间隔。实际间隔 = 本值 ÷ 难度倍率 ÷ 动态难度 ÷ (1 + enemies_percent)，并受 `MIN_SPAWN_INTERVAL` 下界约束 |
| `pool[{type,weight}]` | 敌人类型与权重，按权重抽取；目录里未定义的类型会被剔除并告警一次 |
| `boss` / `boss_count` | Boss 类型与同时在场数量；空字符串表示非 Boss 波。判据的唯一来源就是这里 |

```

Main._process(delta)                 # 战斗阶段
  → wave_timer -= delta
  → spawn_timer -= delta → spawn_enemy()  # 定时生成敌人
  → _process_turrets(delta)          # 工程师炮塔
  → _process_undeads(delta)          # 死灵法师亡灵

Main.end_wave()                      # wave_timer <= 0
  → state = State.SHOP
  → 未拾取材料进入 material_bag
  → 清理敌人/炮塔/亡灵
  → hud.show_wave_summary(...材料...)
  → 依次处理 pending_level_ups 升级选择
  → shop.open(wave, materials, luck, player)
```

### 商店 → 下一波

```
Shop.open(wave, materials, luck, player)
  → ShopRules.roll_offers(...)       # 基于波次、幸运和锁定格生成4个商品
  → _refresh_sell_area()             # 已购物品（可出售）
  → _refresh_upgrade_area()          # 武器升级区

Shop._on_buy_pressed(index)
  → player.spend_materials(price)
  → item_purchased.emit(item)        # 通知 Main

Main._on_item_purchased(upgrade)
  → player.apply_upgrade(upgrade)    # 应用升级效果

Shop._on_start_wave_pressed()
  → wave_started.emit()              # 通知 Main 开始下一波
```

## 信号总线

### Player 信号

| 信号 | 发射时机 | 连接目标 |
|------|---------|---------|
| `hp_changed(hp, max_hp)` | 受伤/治疗 | `hud.update_hp` |
| `xp_changed(xp, xp_to_next)` | 获得 XP / 升级 | `hud.update_xp` |
| `level_up(lv)` | 升级 | `main._on_level_up` → `hud.update_level` + `hud.show_level_up` |
| `weapons_changed(names)` | 装备/升级武器 | `hud.update_weapons` |
| `hurt` | 受伤 | `main._on_player_hurt`（屏幕震动 + 伤害闪烁） |
| `died` | 死亡 | `main._on_player_died`（游戏结束） |
| `gold_changed(gold)` | 材料变化（Phase 1 兼容信号名） | `hud.update_gold` |
| `shield_changed(shield, max_shield)` | 护盾变化 | `hud.update_shield` |
| `synergy_activated(synergy_name)` | 协同效果激活 | `main._on_synergy_activated`（通知 + 成就） |
| `buff_changed(active_pickups)` | 临时增益变化 | `hud.update_buffs` |
| `request_turret(pos)` | 工程师炮塔冷却到 | `main._on_request_turret` |
| `request_undead(pos)` | 死灵法师召唤触发 | `main._on_request_undead` |

### Enemy 信号

| 信号 | 发射时机 | 连接目标 |
|------|---------|---------|
| `died` | 敌人死亡 | `main._on_enemy_died(enemy)` |
| `hp_changed(hp, max_hp)` | Boss/miniboss 受伤 | `hud.update_boss_bar` |
| `phase_changed(phase)` | Boss 阶段切换 | `main._on_boss_phase_changed` |

### Shop 信号

| 信号 | 发射时机 | 连接目标 |
|------|---------|---------|
| `item_purchased(upgrade)` | 购买物品 | `main._on_item_purchased` |
| `wave_started` | 点击"开始下一波" | `main._on_wave_started` |

### HUD 信号

| 信号 | 发射时机 | 连接目标 |
|------|---------|---------|
| `event_accepted` | 接受特殊事件 | `main._on_event_accepted` |
| `event_rejected` | 拒绝特殊事件 | `main._on_event_rejected` |
| `combo_milestone(count)` | 连击达到 5/10/15/20 | `main._on_combo_milestone` |

## 对象池机制

Main.gd 管理三类对象池，避免频繁实例化/销毁：

### 子弹池（Player Bullets）

```
const BULLET_POOL_SIZE = 80
var bullet_pool = []

_init_pools():
  → 实例化 80 个 Bullet，设为不可见 + 停止处理

get_bullet() -> Node:
  → 遍历池，返回第一个 b.visible == false 的子弹
  → 如果池满（全部可见），动态扩容：实例化新子弹并加入池
  → 返回的子弹调用 activate(...) 激活

子弹命中/飞出屏幕 → _return_to_pool():
  → visible = false, set_process(false)
```

### 敌人子弹池（Enemy Bullets）

```
const ENEMY_BULLET_POOL_SIZE = 60
var enemy_bullet_pool = []

机制与玩家子弹池相同
get_enemy_bullet() -> Node
```

### 材料拾取物池

```
const XP_ORB_POOL_SIZE = 40
var xp_orb_pool = []

get_xp_orb() -> Node
Phase 1 仍复用 XPOrb 场景名；玩家拾取后同时获得材料和 XP → _return_to_pool()
```

**扩容策略**：所有池在满时自动创建新实例并追加到池中，不会丢弃对象。

## 敌人类型系统

Enemy.gd 的 `ENEMY_TYPES` 字典定义了所有敌人类型的属性：

```gdscript
const ENEMY_TYPES = {
  "type_name": {
    "spd": float,     # 基础速度
    "hp_m": float,    # HP 倍率（乘以波次基础值）
    "sc": float,      # 缩放大小
    "color": Color,   # 显示颜色
    "xp": int,        # 基础材料/XP 掉落
    "dmg": int,       # 接触伤害
    "dist": float,    # 偏好距离（0=近战，>0=远程保持距离）
    "gold": int,      # Phase 1 遗留字段，敌人死亡不再直接支付
  }
}
```

### 20 种敌人类型

> **哪些类型会出现在常规波次里由 `data/brotato/enemy_waves.json` 的 `pool` 决定**，
> 不在池里的类型由专用路径生成：`tree`（材料树）、`loot_alien`（战利品外星人）、
> `boss` 系列与小 Boss（由波次表的 `boss` / `boss_count` 驱动）。
> `boss` / `boss_fire` / `boss_frost` / `boss_lightning` 属于 Boss 家族，
> 判据统一走 `Enemy.is_boss_type()` / `uses_boss_behavior()`，不要再散写字符串比较。

| 类型 | 特点 |
|------|------|
| `normal` | 基础近战敌人 |
| `fast` | 高速低血，体型小 |
| `tank` | 高血高伤，体型大 |
| `ranged` | 保持距离，单发射击 |
| `boss` | 10x HP，扇形射击 + 螺旋弹，3 阶段；**无元素**（均衡基准）|
| `boss_fire` | 火焰变体：速度 55 / 9x HP，弹幕带 `fire`（命中点燃玩家）|
| `boss_frost` | 冰霜变体：速度 40 / 12x HP（最慢最厚），弹幕带 `frost`（命中减速）|
| `boss_lightning` | 雷电变体：速度 65 / 8x HP（最快最脆）、接触伤害 3，弹幕带 `lightning`（命中眩晕）|
| `exploder` | 死亡时发射 8 方向子弹 |
| `healer` | 每 3 秒治疗附近敌人 10% HP |
| `swarm` | 速度极快血量极低，一次生成 3 只 |
| `armored` | 伤害减免 50% |
| `ghost` | 3 秒无敌/3 秒正常循环 |
| `shooter_spread` | 保持距离，5 发扇形射击 |
| `charger` | 静止→冲刺循环，冲刺伤害高 |
| `summoner` | 每 5 秒召唤 2 只 swarm |
| `elite` | 随机继承 fast/armored/ghost 之一特性 |
| `miniboss` | 6x HP，扇形 + 螺旋弹，3 阶段 |
| `tree` | 材料树：不移动、不掉材料，走 `neutral_trees` 分组 |
| `loot_alien` | 战利品外星人：高速，击杀给材料箱相关收益 |

### 敌人属性缩放

```gdscript
base_speed = (d.spd + wave_num * 2.0) * diff_mult
hp = max(1, int((2 + wave_num) * d.hp_m * diff_mult))
xp_drop = d.xp + int(wave_num / 3)
contact_damage = max(1, int(d.dmg * diff_mult))
```

### 状态效果（敌人侧）

由玩家的武器/物品施加，实现在 `Enemy.gd`：

| 效果 | 持续 | 作用 |
|------|------|------|
| 燃烧 | 3 秒 | 每 0.5 秒扣 1 HP |
| 冻结 | 1.5 秒 | 速度减半 |
| 减速 | 可变 | 速度按系数降低 |
| 眩晕 | 可变 | 完全停止移动/攻击 |

### 状态效果（玩家侧）

由敌方**元素子弹**施加，实现在 `scripts/PlayerStatus.gd`（2026-09-15 新建；
此前玩家侧完全没有状态效果系统）。数值全部集中在文件顶部，待 playtest 定标：

| 元素 | 效果 | 持续 | 说明 |
|------|------|------|------|
| `fire` | 燃烧 | 2 秒 × 1 秒/跳 = 最多 2 点 | 走 `apply_self_damage_without_invulnerability()`，DoT 不吃无敌帧也不吃护甲 |
| `frost` | 减速 30% | 2 秒 | 多个减速取更强者，不叠加成「动不了」|
| `lightning` | 眩晕 | 0.3 秒 + 1.0 秒免疫 | 刷新而非累加；冷却把失控占比压到约 1/4 |

三条硬约束（改动时不要破坏）：

1. **只在伤害真正落地后施加** —— 位置在 `PlayerCore.take_damage()` 过了无敌帧 / 闪避 /
   免伤三道路径之后。被躲开的子弹不该上 debuff；副作用是一轮多发的弹幕只有第一发有效。
2. **减速不写 `p.speed`** —— 由 `PlayerCore.process_movement()` 现乘
   `player.status_speed_multiplier()`。改属性再回滚会漏出口，即时折算天然幂等。
3. **眩晕必须「刷新不累加」** —— 雷电 Boss 阶段 1 一轮 8 发，累加则一轮 2.4 秒失控。

### Boss 阶段系统

| 阶段 | 触发条件 | 行为变化 |
|------|---------|---------|
| 0（正常） | 默认 | 5 发扇形，1.8s 间隔 |
| 1（强化） | HP ≤ 75% | 8 发扇形 + 螺旋弹，速度按类型加速 |
| 2（狂暴） | HP ≤ 15% | 在阶段 1 之上再加一次速，狂暴连发（8方向×3连发）|

阶段加速**按 Boss 类型取值**（`PHASE1_SPEED_MULT` / `PHASE2_SPEED_MULT`），
这样三个元素变体的节奏才不同：阶段 1 基础/火焰/冰霜/雷电 = 1.2 / 1.25 / 1.15 / 1.3。

## 武器系统

### 数据结构

**WeaponData**（Resource 子类）：单个武器的完整定义

```gdscript
# 战斗属性
weapon_type: String    # 内部标识（如 "pistol", "shotgun"）
display_name: String   # 显示名称
damage: int            # 基础伤害
fire_rate: float       # 射速（发/秒）
count: int             # 每次射击子弹数
spread: float          # 子弹散射角度
speed: float           # 子弹速度
color: Color           # 子弹颜色

# 特殊属性
pierce: bool           # 穿透
splash: bool           # 溅射
splash_radius: float   # 溅射范围
melee: bool            # 近战武器
melee_radius: float    # 近战范围
returns: bool          # 回旋镖
gravity: bool          # 重力弹道
bullet_scale: Vector2  # 子弹大小
range_limit: float     # 射程限制
```

**WeaponDatabase**（Resource 子类）：武器集合

```gdscript
weapons: Array[WeaponData]

to_combat_dict() -> Dictionary   # 转为 Player 战斗用字典 { weapon_type: combat_entry }
to_shop_entries() -> Array       # 转为 Shop 商品条目
```

### 数据存储

武器数据存储在 `data/weapons.tres`（Godot 资源文件），由 `WeaponDatabase` 管理。

### 武器获取与升级

1. **起始武器**：角色定义中的 `weapon` 和 `extra_weapon` 字段
2. **商店购买**：Shop 从 `WeaponDatabase.to_shop_entries()` 生成武器商品
3. **装备上限**：`MAX_WEAPONS = 6`
4. **武器升级**：最高 5 级，每级伤害 ×1.25、射速 ×1.1
   - 3 级解锁特效：远程武器获得穿透，近战武器范围增大
   - 5 级变金色（视觉标记 ★）

### 协同效果系统

Player.gd 内置 7 种协同效果，当满足特定武器/被动组合时自动激活：

| 协同 | 条件 | 效果 |
|------|------|------|
| 火焰大师 | 喷火器 + 燃烧概率 | 燃烧概率 +20% |
| 冰河时代 | 冻结 + 时间减缓 | 速度 +30 |
| 弹幕风暴 | 任意 2 把机枪类武器 | 射速 +25% |
| 玻璃大炮 | 复仇 + 伤害 ≥5 | 伤害 +5，最大 HP -3 |
| 钢铁堡垒 | 护甲 ≥4 且 HP ≥15 | 护甲 +3，每波回血 +2 |
| 吸血鬼 | 吸血 ≥10% + 复仇 | 吸血 +10% |
| 速度恶魔 | 肾上腺素 + 速度 ≥400 | 速度 +60，暴击 +10% |

## 波次修饰词系统

每波开始随机选择一个修饰词（第 1 波除外，40% 概率无修饰词）：

| 修饰词 | 效果 |
|--------|------|
| 急速 | 敌人速度 +50% |
| 虫群 | 敌人数量 +60% |
| 精英波 | 所有敌人为精英类型 |
| 材料雨 | 击杀额外 +2 材料 |
| 双倍 XP | XP 获得 ×2 |
| 装甲波 | 敌人护甲 +50% |
| Boss 狂潮 | 非 Boss 波额外生成 Boss |
| 生命涌动 | 每击杀回复 0.5 HP |
| 迷你 | 敌人体型缩小但速度 +30% |

## 特殊事件系统

每 5 波、非 Boss 波、40% 概率触发，玩家可选择接受或拒绝：

| 事件 | 效果 |
|------|------|
| 治愈之泉 | 消耗 15 材料，恢复全部 HP |
| 宝箱 | 当波击杀 10 个敌人后获得 30 材料 |
| 伏击 | 敌人翻倍，击杀材料 +3 |
| 祝福 | 伤害 +30%，速度 +20%（当波有效） |
| 诅咒 | 敌人 HP +50%，XP ×2（当波有效） |
