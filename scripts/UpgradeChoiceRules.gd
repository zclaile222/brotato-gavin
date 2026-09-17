class_name UpgradeChoiceRules
extends RefCounted

# 波末四选一。
#
# 候选池来自 data/brotato/upgrades.json（25 种属性 × 4 tier，按波次门槛分档），
# 不再是硬编码的属性表；应用走 PlayerUpgrades.apply_catalog_rule_effects()，
# 因此角色的 catalog_stat_modification_multipliers、Barnacle 之类的
# level_upgrade_stat_percent_bonus 等修正都会正常生效。
#
# 与旧版的差异（2026-09-15）：
#   - 旧版 CHOICE_POOL 是 8 种属性、无 tier、level/luck 参数被完全忽略；
#   - 现在按波次过滤 tier 档位，并用幸运把权重往高阶推。

const DEFAULT_CHOICE_COUNT := 4
# 每点幸运对「高一阶选项」的权重加成；tier 越高受幸运影响越大，负幸运则更偏低阶
const LUCK_TIER_BIAS := 0.01
const MIN_EFFECTIVE_WEIGHT := 0.05

# 目录不可用时的兜底池，保证任何情况下四选一都不会开天窗
const FALLBACK_POOL = [
	{"id": "max_hp_fallback", "stat": "max_hp", "value": 3, "tier": 1, "weight": 1.0, "name": "最大生命值", "stat_label": "最大生命值", "desc": "+3"},
	{"id": "damage_percent_fallback", "stat": "damage_percent", "value": 0.05, "tier": 1, "weight": 1.0, "name": "伤害", "stat_label": "伤害", "desc": "+5%"},
	{"id": "attack_speed_percent_fallback", "stat": "attack_speed_percent", "value": 0.05, "tier": 1, "weight": 1.0, "name": "攻击速度", "stat_label": "攻击速度", "desc": "+5%"},
	{"id": "speed_percent_fallback", "stat": "speed_percent", "value": 0.04, "tier": 1, "weight": 1.0, "name": "速度", "stat_label": "速度", "desc": "+4%"},
	{"id": "armor_fallback", "stat": "armor", "value": 1, "tier": 1, "weight": 1.0, "name": "护甲", "stat_label": "护甲", "desc": "+1"},
	{"id": "crit_chance_fallback", "stat": "crit_chance", "value": 0.05, "tier": 1, "weight": 1.0, "name": "暴击率", "stat_label": "暴击率", "desc": "+5%"},
	{"id": "luck_fallback", "stat": "luck", "value": 5, "tier": 1, "weight": 1.0, "name": "幸运", "stat_label": "幸运", "desc": "+5"},
	{"id": "harvesting_fallback", "stat": "harvesting", "value": 2, "tier": 1, "weight": 1.0, "name": "收获", "stat_label": "收获", "desc": "+2"},
]

var _catalog = null


func generate_choices(luck: int, count: int = DEFAULT_CHOICE_COUNT, wave: int = 0) -> Array:
	# wave <= 0 表示不按波次过滤（供测试与调试使用）。
	var pool = _candidate_pool(wave)
	if pool.is_empty():
		return []
	var weighted = _weighted_pool(pool, luck)
	var choices: Array = []
	var used_stats: Dictionary = {}
	while choices.size() < count and not weighted.is_empty():
		var index = _pick_weighted_index(weighted)
		if index < 0:
			break
		var entry: Dictionary = weighted[index]
		weighted.remove_at(index)
		var stat = str(entry.get("stat", ""))
		if stat.is_empty() or used_stats.has(stat):
			continue
		used_stats[stat] = true
		entry.erase("_weight")
		choices.append(entry)
	return choices


func apply_choice(player, choice: Dictionary) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	# stat 优先；旧调用方写的是 {"id": "speed", ...}，此时 id 即属性名
	var stat = str(choice.get("stat", choice.get("id", "")))
	if stat.is_empty():
		return []
	var upgrades = player.get("upgrades")
	if upgrades == null or not upgrades.has_method("apply_catalog_rule_effects"):
		push_warning("PlayerUpgrades 不可用，无法应用升级选项: " + stat)
		return []
	var value = _scaled_choice_value(player, choice)
	return upgrades.apply_catalog_rule_effects([
		{"effect": "stat_delta", "stat": stat, "value": value},
	], 1.0)


func _scaled_choice_value(player, choice: Dictionary) -> float:
	var value = float(choice.get("value", 0.0))
	if player != null and is_instance_valid(player) and player.get("level_upgrade_stat_percent_bonus") != null:
		value *= max(0.0, 1.0 + float(player.get("level_upgrade_stat_percent_bonus")))
	return value


func _candidate_pool(wave: int) -> Array:
	var catalog = _get_catalog()
	if catalog != null and catalog.has_method("get_level_up_choices"):
		var entries: Array = catalog.get_level_up_choices(wave)
		if not entries.is_empty():
			return entries
	push_warning("升级目录不可用，波末四选一退回内置兜底池")
	return FALLBACK_POOL.duplicate(true)


func _get_catalog():
	if _catalog != null:
		return _catalog
	var script = load("res://scripts/BrotatoData.gd")
	if script == null:
		return null
	var data = script.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		push_warning("Brotato 升级目录加载失败: " + str(errors))
		return null
	_catalog = data
	return _catalog


func _weighted_pool(pool: Array, luck: int) -> Array:
	var result: Array = []
	for entry in pool:
		var weighted: Dictionary = entry.duplicate(true)
		weighted["_weight"] = _effective_weight(weighted, luck)
		result.append(weighted)
	return result


func _effective_weight(entry: Dictionary, luck: int) -> float:
	var base = max(0.0, float(entry.get("weight", 1.0)))
	var tier = max(1, int(entry.get("tier", 1)))
	var luck_bias = 1.0 + float(luck) * LUCK_TIER_BIAS * float(tier - 1)
	return max(MIN_EFFECTIVE_WEIGHT, base * max(0.0, luck_bias))


func _pick_weighted_index(pool: Array) -> int:
	if pool.is_empty():
		return -1
	var total = 0.0
	for entry in pool:
		total += float(entry.get("_weight", 0.0))
	if total <= 0.0:
		return randi() % pool.size()
	var roll = randf() * total
	var accumulated = 0.0
	for i in range(pool.size()):
		accumulated += float(pool[i].get("_weight", 0.0))
		if roll <= accumulated:
			return i
	return pool.size() - 1
