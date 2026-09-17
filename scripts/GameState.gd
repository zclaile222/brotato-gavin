extends Node

# 角色定义 — 每个字段说明：
# hp_bonus, spd_bonus, dmg_bonus, fr_bonus : 基础属性加减
# crit_bonus : 暴击率加成（0~1）
# lifesteal_bonus : 生命偷取（0~1）
# regen_bonus : 每波回血量
# luck_bonus : 幸运值（影响商店稀有度）
# armor_bonus : 护甲（每次受伤减少固定伤害）
# weapon, extra_weapon : 起始武器

const CHARACTERS = {
	"normal": {
		"name": "普通人",
		"desc": "均衡属性\n无特殊加减",
		"color": Color(0.3, 0.9, 0.4),
		"hp_bonus": 0,  "spd_bonus": 0,   "dmg_bonus": 0,  "fr_bonus":  0.0,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "pistol", "extra_weapon": "",
		"unlock_condition": "默认解锁"
	},
	"warrior": {
		"name": "战士",
		"desc": "HP+5  护甲+1\n速度-40  射速-20%",
		"color": Color(0.9, 0.3, 0.3),
		"hp_bonus": 5,  "spd_bonus": -40, "dmg_bonus": 0,  "fr_bonus": -0.2,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 1,
		"luck_bonus": 0, "armor_bonus": 1,
		"weapon": "pistol", "extra_weapon": "",
		"unlock_condition": "默认解锁"
	},
	"hunter": {
		"name": "猎手",
		"desc": "射速+30%  暴击+8%\nHP-3  速度-10",
		"color": Color(0.3, 0.8, 1.0),
		"hp_bonus": -3, "spd_bonus": -10, "dmg_bonus": 0,  "fr_bonus":  0.3,
		"crit_bonus": 0.08, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "sniper", "extra_weapon": "",
		"unlock_condition": "默认解锁"
	},
	"gunner": {
		"name": "枪手",
		"desc": "双手枪  伤害+2\n速度-30  HP-1",
		"color": Color(1.0, 0.75, 0.2),
		"hp_bonus": -1, "spd_bonus": -30, "dmg_bonus": 2,  "fr_bonus":  0.0,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "pistol", "extra_weapon": "pistol",
		"unlock_condition": "通关一次游戏"
	},
	"berserker": {
		"name": "狂战士",
		"desc": "HP+2  速度+30\n射速-25%  伤害-1",
		"color": Color(0.8, 0.2, 0.9),
		"hp_bonus": 2,  "spd_bonus": 30,  "dmg_bonus": -1, "fr_bonus": -0.25,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "shotgun", "extra_weapon": "",
		"unlock_condition": "单波击杀30个敌人"
	},
	"engineer": {
		"name": "工程师",
		"desc": "速度+40  射速+20%  幸运+2\nHP-3  伤害-1",
		"color": Color(0.4, 1.0, 0.6),
		"hp_bonus": -3, "spd_bonus": 40,  "dmg_bonus": -1, "fr_bonus":  0.2,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 2, "armor_bonus": 0,
		"weapon": "machinegun", "extra_weapon": "",
		"unlock_condition": "购买10个升级道具"
	},
	# --- 新增角色 ---
	"ninja": {
		"name": "忍者",
		"desc": "快如疾风，难以捉摸\n速度+200  暴击+20%  射速+50%\nHP-3  伤害-20%",
		"color": Color(0.2, 0.2, 0.5),
		"hp_bonus": -3, "spd_bonus": 200, "dmg_bonus": -1, "fr_bonus": 0.5,
		"crit_bonus": 0.2, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "sword", "extra_weapon": "",
		"unlock_condition": "在困难模式下通关"
	},
	"wizard": {
		"name": "巫师",
		"desc": "强大的法术力量\n伤害+3  暴击+10%\n速度-80  射速-30%",
		"color": Color(0.5, 0.2, 1.0),
		"hp_bonus": -2, "spd_bonus": -80, "dmg_bonus": 3, "fr_bonus": -0.3,
		"crit_bonus": 0.1, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "plasma", "extra_weapon": "",
		"unlock_condition": "达到20级"
	},
	"knight": {
		"name": "骑士",
		"desc": "钢铁防御，坚不可摧\nHP+8  护甲+5\n速度-110  射速-10%",
		"color": Color(0.7, 0.7, 0.8),
		"hp_bonus": 8, "spd_bonus": -110, "dmg_bonus": 0, "fr_bonus": -0.1,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 1,
		"luck_bonus": 0, "armor_bonus": 5,
		"weapon": "sword", "extra_weapon": "",
		"unlock_condition": "受伤超过500次存活"
	},
	"archer": {
		"name": "弓箭手",
		"desc": "精准射击，百步穿杨\n伤害+1  射速+20%\nHP-1  速度-30",
		"color": Color(0.3, 0.7, 0.3),
		"hp_bonus": -1, "spd_bonus": -30, "dmg_bonus": 1, "fr_bonus": 0.2,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "crossbow", "extra_weapon": "",
		"unlock_condition": "在第15波前击杀100个敌人"
	},
	"merchant": {
		"name": "商人",
		"desc": "财富就是力量\n幸运+20  初始材料+30\nHP-1  伤害-1  速度-30",
		"color": Color(1.0, 0.85, 0.2),
		"hp_bonus": -1, "spd_bonus": -30, "dmg_bonus": -1, "fr_bonus": 0.0,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 20, "armor_bonus": 0,
		"starting_gold": 30,
		"weapon": "pistol", "extra_weapon": "",
		"unlock_condition": "单局积累200材料"
	},
	"berserker2": {
		"name": "暴徒",
		"desc": "暴力美学的极致\n伤害+2  速度+40  暴击+15%  暴击伤害2.5x\nHP-2  射速+30%",
		"color": Color(0.9, 0.1, 0.1),
		"hp_bonus": -2, "spd_bonus": 40, "dmg_bonus": 2, "fr_bonus": 0.3,
		"crit_bonus": 0.15, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"crit_damage_bonus": 0.5,
		"weapon": "smg", "extra_weapon": "",
		"unlock_condition": "连击达到10x"
	},
	"ghost": {
		"name": "幽灵",
		"desc": "虚无缥缈，难以触碰\n25%完全闪避  速度+60\nHP-4  伤害-1",
		"color": Color(0.6, 0.7, 1.0),
		"hp_bonus": -4, "spd_bonus": 60, "dmg_bonus": -1, "fr_bonus": 0.0,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "pistol", "extra_weapon": "",
		"unlock_condition": "闪避累计50次攻击"
	},
	"necromancer": {
		"name": "死灵法师",
		"desc": "亡灵大军的主宰\n击杀10%召唤亡灵  伤害+1\nHP-3  速度-50",
		"color": Color(0.5, 0.2, 0.6),
		"hp_bonus": -3, "spd_bonus": -50, "dmg_bonus": 1, "fr_bonus": 0.0,
		"crit_bonus": 0.0, "lifesteal_bonus": 0.0, "regen_bonus": 0,
		"luck_bonus": 0, "armor_bonus": 0,
		"weapon": "plasma", "extra_weapon": "",
		"unlock_condition": "累计击杀500个敌人"
	},
}

var selected_character = "normal"
var endless_mode: bool = false
var _brotato_data = null
var _catalog_available := false

# ─── Danger 0-5 难度模型（P4-3）───
#
# 权威数值来源：Brotato Wiki《Danger Levels》
#   https://brotato.wiki.spellsandguns.com/index.php?title=Danger_Levels
#   原版对敌人的强化（wiki 原文 "The Health and Damage increases are the total for
#   that danger level" —— 是**该档的总量**，不是逐级叠加）：
#     D0/D1/D2 = 无属性强化；D3 = +12% 伤害与 HP；D4 = +26%；D5 = +40%
#   原版机制侧的变化：
#     D1 = 新敌人登场；D2 = 精英/虫群登场（第 11 或 12 波，1 轮）；
#     D4 = 精英/虫群更多（第 11-18 波共 3 轮）；D5 = 第 20 波双 Boss（Boss HP -25%）。
#
# 与本项目改造前的三档（0=简单 0.7 / 1=普通 1.0 / 2=困难 1.4）的衔接：
#   旧「普通」= Danger 1（基准 1.00，21 套既有测试全部跑在这一档）；
#   旧「困难」= 强度 1.40 = 新 Danger 5（见 LEGACY_DIFFICULTY_TO_DANGER）。
#
# 三处**有意偏差**，各自都有对应常量的推导注释：
#   ① Danger 0 = 0.70：原版 D0 也是 1.00（无修饰）。本作把「调低敌人强度」固化成
#      Danger 0 入门档，数值沿用改造前「简单」档的 0.70，避免旧体验丢失
#      （原版把这件事交给无障碍滑条，本作选择显式给一档）。
#   ② 刷怪密度：原版不改刷怪间隔，本作新增这一档位旋钮（DANGER_SPAWN_MULTIPLIERS）。
#   ③ 额外精英概率：原版只按「精英/虫群轮次」表达，本作折算成概率（DANGER_ELITE_CHANCES）。

const MIN_DANGER := 0
const MAX_DANGER := 5
# 基准档：其余各档的百分比展示都以它为参照（CharacterSelect 的档位提示用）。
const BASELINE_DANGER := 1
# 旧模型里「困难」的落点。旧困难强度 1.40，恰好等于新 Danger 5 的强度。
const LEGACY_HARD_DANGER := 5

# 非法难度值的回退：中性倍率 = Danger 1 的基准。
# 旧实现就是 `DIFFICULTY_MULTIPLIERS.get(difficulty, 1.0)` —— 越界回退中性值 1.0，
# 而**不是**夹到最近的合法档。这个语义必须保持：消费端 scripts/Enemy.gd:206 不归本次改造所有。
const DANGER_SAFE_DEFAULT := 1.0

# 敌人强度倍率：作用于敌人 HP / 接触伤害 / 移速（消费端 scripts/Enemy.gd:206-212）。
#   D1-D5 取原版 wiki 值。注意 **D1 与 D2 都是 1.00** —— 这不是漏填，
#   原版 D0-D2 就是无属性强化，这三档的差异体现在精英率与刷怪密度上。
#   D0 = 0.70 为入门档（见上文偏差 ①）。
#   ⚠ **已知偏离（刻意保持）**：原版 Danger 只缩放敌人的**伤害与 HP**，不动移速；
#     本作的 get_difficulty_multiplier() 自改造前起就同时乘移速（Enemy.gd:207），
#     这是既有契约，本次刻意不改（Enemy.gd 不归本项改造所有）。
#     后果：本作高难档的敌人比原版更「贴身」，评测难度手感时不要按原版预期。
const DIFFICULTY_MULTIPLIERS = { 0: 0.70, 1: 1.00, 2: 1.00, 3: 1.12, 4: 1.26, 5: 1.40 }

# 刷怪密度倍率：>1 更密（WaveManager 把它作为刷怪间隔的除数因子）。
# 推导式 `1.00 + (强度倍率 - 1.00) * 0.50`，即**密度只吃强度增量的一半**：
#   D0 = 1 + (-0.30)*0.5 = 0.85；D3 = 1.06；D4 = 1.13；D5 = 1.20。
# 系数取 0.5（而不是 1.0）的两条理由：
#   ① 波次表自身已把第 20 波的基础间隔压到 MIN_SPAWN_INTERVAL = 0.2 的下界
#      （见 data/brotato/enemy_waves.json 的 notes 与 WaveManager.get_spawn_interval），
#      密度若全量叠加，晚期波次会被下界整段吃掉、白改；
#   ② 间隔是 `base / 强度 / 密度`，强度已经在除，密度再全量叠加会让高难档的刷怪量
#      呈平方增长（1.4 × 1.4 ≈ 2 倍），超出「逐级加压」的设计意图。
# 本表与公式等价，写成字面量是为了审阅时一眼可核（测试同时校验公式与字面量）。
const DANGER_SPAWN_MULTIPLIERS = { 0: 0.85, 1: 1.00, 2: 1.00, 3: 1.06, 4: 1.13, 5: 1.20 }

# 每档**额外**精英概率：叠加在波次表权重与玩家道具之上，只做加法、绝不覆盖。
#   （波次表在第 12-20 波已有 7% → 16% 的**池内**精英权重，那是 P4-1 的成果；
#     本表是**池外叠加**的概率，两者是不同的量，不要合并计算，也不得覆盖权重。
#     测试里有对应的「波次表未被难度改写」反向断言。）
#
# 原版形状是**阶梯**，不是逐档递增。Brotato Wiki《Danger Levels》原文（按轮次描述）：
#   D2 "An Elite or horde appears for 1 round (round 11 or 12)"
#   D3 "An Elite or horde appears for 1 round (rounds 11 or 12)"
#   D4 "An Elite or horde appears for 3 rounds (rounds 11 to 18)"
#   D5 "An Elite or horde appears for 3 rounds (rounds 11 to 18)"
# => D2 == D3、D4 == D5，两档一台阶。gameplay.tips 的独立攻略给出同一结构
#   （D2+ 波 11/12；D4+ 再加波 14/15 与波 17/18，即 3 次事件），两个来源互证。
#   ⚠ 原版**没有**「每档 +5 个百分点」这条直线 —— 那种写法是在真实值之间插中值，
#     属于凭空造数，不要写回来。测试有一条反向断言专门守住这一点。
#
# 「轮次 → 概率」这一步是**本作的换算口径，不是原版直给的数**（原版只给轮次）：
#   按 total_waves = 20 波折算「每只敌人附带额外精英的概率」——
#     1 次事件 / 20 波 = 0.05；3 次事件 / 20 波 = 0.15。
#   选「按波数占比」而不是「按轮次线性」的理由：本表的消费端是**每只敌人的独立抽取**
#   （WaveManager.roll_additional_elite_spawn_count），只能吃概率；而 20 波里被占用的
#   波数占比，正是原版那几轮事件在整局中的实际密度。（这也是本表与波次表池内权重
#   口径不同的原因：池内权重按「刷出的敌人里有多少是精英」，本表按「整局波数占比」。）
#
# D0/D1 = 0：原版 D1 只加「新敌人登场」、D0 无修饰，都不引入精英。
# Danger 1 必须为 0，否则会改变既有测试里 Candy Bag(+10%) 的精英抽取门槛。
const DANGER_ELITE_CHANCES = { 0: 0.00, 1: 0.00, 2: 0.05, 3: 0.05, 4: 0.15, 5: 0.15 }

# 旧三档（简单 0 / 普通 1 / 困难 2）在新六级里的落点。
# 判据是**敌人强度倍率**而不是档位序号：旧「困难」的 1.40 正好等于新 Danger 5 的强度，
# 所以 0→0（0.70）、1→1（1.00）、2→5（1.40）。这样任何「难度到达某档」的旧判据
# 换算之后语义不变（Main._check_unlock_conditions 的 ninja 解锁即按此改写）。
# 存档兼容：本项目的 SaveSystem 不落难度值（见 SaveSystem._data 的字段表），
# 所以这张表只服务于**旧代码里的硬编码判据**，不参与存档迁移。
const LEGACY_DIFFICULTY_TO_DANGER = { 0: 0, 1: 1, 2: 5 }

# 当前难度档位（0-5）。默认 1 = 基准档，与改造前「普通」等价。
var difficulty: int = 1

func _ready():
	_get_brotato_data()

func is_valid_danger(danger: int) -> bool:
	return danger >= MIN_DANGER and danger <= MAX_DANGER

func get_danger_level_count() -> int:
	return MAX_DANGER - MIN_DANGER + 1

# 签名与语义保持不变：返回**当前**难度对敌人的强度倍率（HP / 接触伤害 / 移速）。
# 非法难度回退中性值 1.0 —— 与旧实现 `.get(difficulty, 1.0)` 完全一致，
# 所以越界值既不会崩，也不会被悄悄夹到最近档位而改变难度。
func get_difficulty_multiplier() -> float:
	return DIFFICULTY_MULTIPLIERS.get(difficulty, DANGER_SAFE_DEFAULT)

# 当前难度的刷怪密度倍率（>1 更密）。非法难度回退 1.0（= 不改变刷怪节奏）。
func get_danger_spawn_multiplier() -> float:
	return DANGER_SPAWN_MULTIPLIERS.get(difficulty, DANGER_SAFE_DEFAULT)

# 当前难度的**额外**精英概率。非法难度回退 0.0（= 不额外刷精英）。
func get_danger_elite_chance() -> float:
	return DANGER_ELITE_CHANCES.get(difficulty, 0.0)

# 逐档查询入口，供 UI 与测试一次取到某一档的全部三个维度。
# 非法档 is_valid=false，且三个维度都给安全回退值（可安全喂给界面渲染）。
func get_danger_profile(danger: int) -> Dictionary:
	return {
		"danger": danger,
		"is_valid": is_valid_danger(danger),
		"enemy_multiplier": float(DIFFICULTY_MULTIPLIERS.get(danger, DANGER_SAFE_DEFAULT)),
		"spawn_multiplier": float(DANGER_SPAWN_MULTIPLIERS.get(danger, DANGER_SAFE_DEFAULT)),
		"elite_chance": float(DANGER_ELITE_CHANCES.get(danger, 0.0)),
	}

func _get_brotato_data():
	if _brotato_data != null:
		return _brotato_data
	var script = load("res://scripts/BrotatoData.gd")
	if script == null:
		_catalog_available = false
		return null
	_brotato_data = script.new()
	var errors = _brotato_data.load_catalog()
	_catalog_available = errors.is_empty()
	if not _catalog_available:
		push_warning("Brotato 目录不可用: " + "; ".join(errors))
	return _brotato_data

func get_brotato_data():
	return _get_brotato_data()

func is_brotato_catalog_available() -> bool:
	_get_brotato_data()
	return _catalog_available

func get_character_select_entries() -> Dictionary:
	var data = _get_brotato_data()
	if _catalog_available and data != null:
		var result: Dictionary = {}
		for id in data.get_characters(true).keys():
			var converted = data.to_game_state_character(id)
			if converted.is_empty():
				continue
			result[id] = converted
		if not result.is_empty():
			return result
	return CHARACTERS

func is_catalog_character_default_unlocked(char_id: String) -> bool:
	var data = _get_brotato_data()
	if not _catalog_available or data == null:
		return false
	var character = data.get_character(char_id)
	return not character.is_empty() and character.get("unlock", {}).get("type", "") == "default"

func get_character_display_name(char_id: String) -> String:
	var data = _get_brotato_data()
	if _catalog_available and data != null:
		var character = data.get_character(char_id)
		if not character.is_empty():
			return str(character.get("display_name", character.get("source_name", char_id)))
	if CHARACTERS.has(char_id):
		return str(CHARACTERS[char_id].get("name", char_id))
	return char_id

func get_character_ids_for_unlock_condition(condition: String) -> Array:
	var data = _get_brotato_data()
	if _catalog_available and data != null and data.has_method("get_character_ids_for_unlock_condition"):
		return data.get_character_ids_for_unlock_condition(condition)
	return []

func get_catalog_item_shop_entry(item_id: String) -> Dictionary:
	var data = _get_brotato_data()
	if not _catalog_available or data == null:
		return {}
	if data.has_method("item_to_shop_entry"):
		return data.item_to_shop_entry(item_id)
	for item in data.get_shop_pool(false):
		if str(item.get("source_id", "")) == item_id:
			return item.duplicate(true)
	return {}

func get_character() -> Dictionary:
	var data = _get_brotato_data()
	if _catalog_available and data != null:
		var converted = data.to_game_state_character(selected_character)
		if not converted.is_empty():
			return converted
		var fallback = data.to_game_state_character("well_rounded")
		if not fallback.is_empty():
			return fallback
	if CHARACTERS.has(selected_character):
		return CHARACTERS[selected_character]
	return CHARACTERS["normal"]
