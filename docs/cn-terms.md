# Brotato 中文翻译术语表

> 目标：统一项目中的中文译名，优先使用 Brotato Steam/社区通用译名，其次使用描述性翻译。

---

## 通用规则

1. **纯中文替换**：不再保留英文原文（用户选定）。
2. **保留不翻译的符号/缩写**：`HP`、`XP`、`Boss`、`CD`（冷却时间）、`T1/T2/T3/T4`（武器 tier）。
3. **格式占位符保留**：如 `%d`、`%s`、`%.1f`、`\n` 不动。
4. **标点**：中文文本使用中文标点，但代码字符串内部可保留 `\n`。

---

## 通用 UI 术语

| 英文 | 中文 | 备注 |
|------|------|------|
| Materials | 材料 | 游戏货币 |
| Gold | 金币/材料 | 旧版别名，统一为“材料” |
| Wave | 波 | 波次 |
| Shop | 商店 | |
| Level Up | 升级 | |
| Upgrade | 升级/强化 | 视上下文 |
| Reroll | 刷新 | 商店重抽 |
| Lock | 锁定 | 商店锁定槽位 |
| Sell | 出售 | |
| Recycle | 回收 | 箱子/道具回收 |
| HP | HP | 不译 |
| XP | XP | 不译 |
| Armor | 护甲 | |
| Speed | 速度 | |
| Damage | 伤害 | |
| Crit Chance | 暴击率 | |
| Crit Damage | 暴击伤害 | |
| Attack Speed | 攻击速度 | |
| Range | 射程 | |
| Life Steal | 生命偷取 | |
| Luck | 幸运 | |
| Harvesting | 收获 | |
| Engineering | 工程 | |
| Dodge | 闪避 | |
| Magnet | 磁铁范围 | |
| Shield | 护盾 | |
| Combo | 连击 | |
| Pause | 暂停 | |
| Resume | 继续 | |
| Restart | 重新开始 | |
| Main Menu | 主菜单 | |
| Victory | 胜利 | |
| Game Over | 游戏结束 | |
| Endless Mode | 无尽模式 | |

---

## 难度

| 英文 | 中文 |
|------|------|
| Easy | 简单 |
| Normal | 普通 |
| Hard | 困难 |
| Nightmare | 噩梦 |

---

## 波次修饰词

| 英文 | 中文 |
|------|------|
| Speed | 急速 |
| Swarm | 虫群 |
| Elite Wave | 精英波 |
| Gold Rain | 材料雨 |
| Double XP | 双倍 XP |
| Armored | 装甲波 |
| Boss Rush | Boss 狂潮 |
| Healing | 生命涌动 |
| Tiny | 迷你 |
| None | 无修饰 |

---

## 特殊事件

| 英文 | 中文 |
|------|------|
| Healing Fountain | 治愈之泉 |
| Treasure Chest | 宝箱 |
| Ambush | 伏击 |
| Blessing | 祝福 |
| Curse | 诅咒 |

---

## 成就（保留key，翻译展示文本）

| Key | 中文 |
|-----|------|
| first_blood | 首次击杀 |
| kill_100 | 击杀 100 个敌人 |
| kill_500 | 击杀 500 个敌人 |
| kill_300 | 第 15 波前击杀 100 个 |
| reach_level_20 | 达到 20 级 |
| wave_5 | 通过第 5 波 |
| wave_10 | 通过第 10 波 |
| no_damage_wave | 无伤通过一波 |
| endless_30 | 无尽模式达到 30 波 |
| collect_300_materials | 单局积累 300 材料 |
| collect_10000_materials | 累计收集 10000 材料 |
| hold_3000_materials | 单局持有 3000 材料 |
| full_synergy | 激活全部协同 |
| damage_10000 | 单局输出 10000 伤害 |
| win_with_danger_0 | 危险 0 通关 |

---

## 角色（data/brotato/characters.json 部分参考）

| ID | 中文名 | 备注 |
|----|--------|------|
| well_rounded | 八面玲珑 | 已存在于 data/characters.json |
| brawler | 拳手 | |
| crazy | 狂人 | |
| ranger | 游侠 | |
| mage | 法师 | |
| chunky | 壮汉 | |
| old | 老头 | |
| mutant | 变异体 | |
| generalist | 通才 | |
| loud | 大嗓门 | |
| multitasker | 多面手 | |
| wildling | 野人 | |
| gladiator | 角斗士 | |
| sick | 病人 | |
| farmer | 农夫 | |
| ghost | 幽灵 | |
| speedy | 飞毛腿 | |
| lucky | 幸运儿 | |
| pacifist | 和平主义者 | |
| saver | 节俭者 | |
| entrepreneur | 企业家 | |
| engineer | 工程师 | |
| explorer | 探险家 | |
| doctor | 医生 | |
| hunter | 猎人 | |
| artificer | 工匠 | |
| arms_dealer | 军火商 | |
| streamer | 主播 | |
| cyborg | 赛博格 | |
| glutton | 贪吃鬼 | |
| jack | 杰克 | |
| lich | 巫妖 | |
| apprentice | 学徒 | |
| cryptid | 神秘生物 | |
| fisherman | 渔夫 | |
| golem | 魔像 | |
| king | 国王 | |
| renegade | 叛徒 | |
| one_armed | 独臂 | |
| bull | 公牛 | |
| soldier | 士兵 | |
| masochist | 受虐狂 | |
| knight | 骑士 | |
| demon | 恶魔 | |
| baby | 婴儿 | |
| vagabond | 流浪汉 | |
| technomage | 科技法师 | |
| vampire | 吸血鬼 | |
| sailor | 水手 | |
| curious | 好奇者 | |
| builder | 建筑师 | |
| captain | 船长 | |
| creature | 生物 | |
| chef | 厨师 | |
| druid | 德鲁伊 | |
| dwarf | 矮人 | |
| gangster | 黑帮 | |
| diver | 潜水员 | |
| hiker | 徒步者 | |
| buccaneer | 海盗 | |
| ogre | 食人魔 | |
| romantic | 浪漫主义者 | |

---

## 翻译阶段

- **P1**：核心 UI（MainMenu、CharacterSelect、HUD、Shop、UpgradeChoiceRules、Main 通知、WaveManager 修饰词、EventManager 事件）
- **P2**：武器目录（data/brotato/weapons.json）+ 物品目录（data/brotato/items.json）
- **P3**：角色目录（data/brotato/characters.json）+ 收尾一致性检查

*本表随翻译进度持续更新。*
