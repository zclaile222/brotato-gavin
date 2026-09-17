class_name BrotatoData
extends RefCounted

const CATALOG_DIR := "res://data/brotato"

const REQUIRED_FILES := {
	"manifest": "catalog_manifest.json",
	"effect_schema": "effect_schema.json",
	"item_tags": "item_tags.json",
	"weapon_classes": "weapon_classes.json",
	"weapons": "weapons.json",
	"items": "items.json",
	"upgrades": "upgrades.json",
	"characters": "characters.json",
	"enemy_waves": "enemy_waves.json",
}

const DEFAULT_CHARACTER_IDS := ["well_rounded", "brawler", "crazy", "ranger", "mage"]
const RUNTIME_ITEM_EFFECTS := ["stat_delta", "pickup_range_percent", "weapon_special"]
const RUNTIME_ITEM_SPECIAL_RULES := [
	"materials_plus_15_when_crate_pickup",
	"projectiles_pierce_plus_1",
	"shoot_6_alien_eyes_every_3_seconds",
	"enemy_corpse_fires_ranged_damage_bullet",
	"gain_1_material_when_killing_cursed_enemy",
	"elemental_damage_plus_1_per_30_burning_kills_max_4_per_wave",
	"explode_on_hit_chance",
	"once_per_wave_explode_below_40_percent_health",
	"hp_regeneration_plus_1_per_different_tier_1_item",
	"hp_regeneration_minus_3_per_different_tier_4_item",
	"each_wave_random_primary_stats_plus_8",
	"each_wave_additional_elite_chance_10_percent",
	"locked_shop_entries_chance_to_become_cursed",
	"duplicate_next_shop_item_without_exceeding_limits",
	"broken_mirror_duplicated_item_state",
	"resting_goldfish_post_use_state",
	"crit_kill_chance_to_heal_1_hp",
	"gain_1_material_on_critical_kill_chance",
	"heal_1_hp_on_material_pickup_chance",
	"double_picked_material_value_chance",
	"hit_enemy_speed_reduction",
	"heal_5_hp_on_dodge_chance_50_percent",
	"nullify_one_hit_taken_per_wave",
	"start_wave_with_hp_percent_delta",
	"piercing_damage_cannot_exceed_base_damage",
	"material_drop_instant_attract_chance",
	"material_pickup_luck_damage_chance",
	"enemy_death_luck_damage_chance",
	"heal_1_hp_on_enemy_kill_chance",
	"dodge_cap_70_percent",
	"burn_on_hit",
	"burn_spread",
	"enemy_death_explosion_chance",
	"deal_melee_damage_on_dodge",
	"critical_hits_deal_current_hp_bonus_damage",
	"luck_plus_2_per_1_crit_chance_percent",
	"damage_percent_plus_5_every_5_seconds_until_wave_end",
	"hp_regeneration_doubled_below_50_percent_health",
	"max_hp_plus_1_on_consumable_pickup_at_full_health_max_8_per_wave",
	"hp_regeneration_plus_2_every_5_seconds_until_wave_end",
	"temporary_hp_regeneration_plus_1_on_full_health_consumable_pickup",
	"start_next_wave_with_1_hp",
	"max_hp_plus_1_per_80_materials",
	"damage_percent_minus_2_when_hit_until_wave_end",
	"damage_percent_plus_1_per_1_knockback",
	"damage_percent_plus_1_per_1_permanent_speed_percent",
	"attack_speed_percent_plus_2_per_1_dodge_percent",
	"max_hp_plus_1_per_1_permanent_armor",
	"engineering_plus_1_per_1_permanent_elemental_damage",
	"damage_percent_plus_3_end_wave",
	"max_hp_plus_3_end_wave",
	"hp_regeneration_plus_1_end_wave",
	"lifesteal_plus_1_percent_end_wave",
	"melee_damage_plus_3_end_wave",
	"engineering_plus_3_end_wave",
	"max_hp_minus_1_end_wave",
	"armor_minus_1_end_wave",
	"hp_regeneration_plus_1_on_level_up",
	"lifesteal_plus_1_percent_and_max_hp_minus_1_on_level_up",
	"level_upgrade_stats_plus_35_percent",
	"curse_plus_1_on_level_up",
	"decrease_current_wave_count_by_1",
	"broken_hourglass_start_next_wave_with_1_hp",
	"max_hp_capped_at_current_value",
	"speed_capped_at_current_value",
	"materials_plus_20_percent_start_wave_until_wave_20",
	"max_hp_plus_1_per_distinct_weapon",
	"attack_speed_percent_plus_6_per_different_weapon",
	"attack_speed_percent_minus_3_per_different_weapon",
	"hp_regeneration_plus_2_per_negative_1_permanent_speed_percent",
	"harvesting_growth_percent_plus_8_end_wave",
	"xp_gain_percent_plus_5_end_wave",
	"next_wave_xp_gain_percent_plus_100",
	"next_wave_xp_gain_percent_plus_50",
	"next_wave_enemy_health_percent_plus_100",
	"next_wave_enemy_damage_percent_plus_50",
	"next_wave_enemy_speed_percent_plus_25",
	"next_wave_additional_loot_aliens",
	"spawn_special_enemies_next_wave",
	"nightmare_fog_visibility_percent_plus_25",
	"nightmare_fog_visibility_percent_plus_50",
	"nightmare_fog_visibility_percent_plus_75",
	"elemental_damage_plus_1_when_getting_elemental_damage_item",
	"damage_percent_plus_20_for_2_seconds_after_consumable_pickup",
	"speed_percent_plus_10_for_3_seconds_when_taking_damage",
	"one_free_shop_reroll",
	"extra_item_chance_in_crate",
	"take_1_damage_per_second_without_invulnerability",
	"damage_percent_plus_2_per_1_lifesteal_percent",
	"structures_attack_speed_scales_with_player_attack_speed",
	"engineering_minus_1_per_structure",
	"armor_plus_8_while_standing_still",
	"attack_speed_percent_plus_40_while_standing_still",
	"dodge_percent_plus_20_while_standing_still",
	"hp_regeneration_plus_10_while_standing_still",
	"burning_activates_20_percent_faster",
	"burning_activates_100_percent_slower",
	"weapon_damage_scales_with_10_percent_elemental_damage",
	"weapon_damage_scales_with_20_percent_engineering",
	"enemies_take_10_percent_more_damage_for_3_seconds_on_first_elemental_hit",
	"burning_deals_current_enemy_hp_bonus_damage",
	"attack_speed_percent_plus_1_every_second_until_wave_end_lost_on_damage",
	"attack_speed_percent_plus_1_per_living_enemy",
	"hp_regeneration_plus_1_per_currently_burning_enemy",
	"damage_percent_plus_1_per_10_permanent_luck",
	"extra_pearl_chance_in_crate",
	"weapon_minimum_cooldown_0_75_seconds",
	"projectiles_gain_1_piercing_on_critical_hit",
	"restore_5_hp_per_second_cannot_heal_other_way",
	"consumables_heal_over_4_seconds_instead_of_instant",
	"weapons_can_no_longer_be_upgraded_or_recycled",
	"items_one_tier_higher_after_next_reroll",
	"shop_reroll_damage_percent_plus_1_chance",
	"shop_reroll_max_hp_minus_1_chance",
	"swap_highest_and_lowest_positive_primary_stats_on_pickup",
	"upgrade_random_weapon_entering_shop_or_gain_2_armor",
	"more_trees_spawn",
	"trees_die_in_one_hit",
	"enemies_have_higher_fruit_drop_chance",
	"spawn_garden_creates_fruit_every_15_seconds",
	"spawn_turret_each_wave",
	"spawn_landmine_every_12_seconds",
	"spawn_explosive_turret",
	"spawn_incendiary_turret",
	"spawn_laser_turret",
	"spawn_medical_turret",
	"structures_can_crit",
	"killing_tree_spawns_turret",
	"spawn_tyler",
	"spawn_wandering_bot_that_slows_nearby_enemies",
	"unique_builders_turret",
	"knock_nearby_enemies_back_every_3_seconds",
	"projectiles_bounce_plus_1",
	"every_ranged_weapon_fifth_projectile_has_plus_3_projectiles",
	"consumable_explosion_chance",
]
const RUNTIME_ITEM_STATS := [
	"max_hp",
	"hp_regeneration",
	"armor",
	"speed_percent",
	"attack_speed_percent",
	"damage_percent",
	"melee_damage",
	"ranged_damage",
	"elemental_damage",
	"engineering",
	"crit_chance",
	"lifesteal",
	"luck",
	"dodge",
	"harvesting",
	"range",
	"knockback",
	"consumable_heal",
	"xp_gain_percent",
	"pickup_range_percent",
	"item_price_percent",
	"reroll_price_percent",
	"recycling_materials_percent",
	"enemy_health_percent",
	"enemy_damage_percent",
	"boss_elite_damage_percent",
	"enemy_speed_percent",
	"enemies_percent",
	"materials_dropped_percent",
	"piercing_damage_percent",
	"explosion_damage_percent",
	"explosion_size_percent",
	"damage_against_high_health_targets_percent",
	"structure_attack_speed_percent",
	"accuracy_percent",
	"curse",
	"loot_alien_chance_percent",
	"loot_alien_speed_percent",
]

var manifest: Dictionary = {}
var effect_schema: Dictionary = {}
var item_tags: Dictionary = {}
var weapon_classes: Dictionary = {}
var weapons: Dictionary = {}
var items: Dictionary = {}
var upgrades: Dictionary = {}
var characters: Dictionary = {}
# 波次表：enemy_waves 按波号字符串索引（"1".."20"）；
# enemy_wave_config 存文档级字段（total_waves / fallback）。
var enemy_waves: Dictionary = {}
var enemy_wave_config: Dictionary = {}

var _weapon_aliases: Dictionary = {}
var _character_aliases: Dictionary = {}
var _loaded := false
var _load_errors: Array[String] = []

func load_catalog() -> Array[String]:
	_clear()
	for key in REQUIRED_FILES:
		var path = "%s/%s" % [CATALOG_DIR, REQUIRED_FILES[key]]
		var parsed = _read_json(path)
		if parsed == null:
			continue
		match key:
			"manifest":
				if parsed is Dictionary:
					manifest = parsed
				else:
					_load_errors.append("%s must be an object" % path)
			"effect_schema":
				if parsed is Dictionary:
					effect_schema = parsed
				else:
					_load_errors.append("%s must be an object" % path)
			"item_tags":
				item_tags = _index_array(path, parsed)
			"weapon_classes":
				weapon_classes = _index_array(path, parsed)
			"weapons":
				weapons = _index_array(path, parsed)
			"items":
				items = _index_array(path, parsed)
			"upgrades":
				upgrades = _index_array(path, parsed)
			"characters":
				characters = _index_array(path, parsed)
			"enemy_waves":
				# 这个文件是「文档 + waves 数组」结构，不是顶层数组，
				# 因此不能直接交给 _index_array。
				if not (parsed is Dictionary):
					_load_errors.append("%s must be an object" % path)
				elif not (parsed.get("waves") is Array):
					_load_errors.append("%s.waves must be an array" % path)
				else:
					enemy_waves = _index_array(path, parsed["waves"])
					enemy_wave_config = {
						"total_waves": int(parsed.get("total_waves", parsed["waves"].size())),
						"fallback": parsed.get("fallback", {}),
					}
	_build_aliases()
	_loaded = _load_errors.is_empty()
	return _load_errors.duplicate()

func validate() -> Array[String]:
	if not _loaded:
		load_catalog()
	var errors: Array[String] = []
	errors.append_array(_load_errors)
	_validate_manifest(errors)
	_validate_effect_schema(errors)
	_validate_tags(errors)
	_validate_weapon_classes(errors)
	_validate_weapons(errors)
	_validate_items(errors)
	_validate_upgrades(errors)
	_validate_characters(errors)
	_validate_enemy_waves(errors)
	return errors

func get_default_character_ids() -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in DEFAULT_CHARACTER_IDS:
		if characters.has(id):
			result.append(id)
	return result

func get_character(id: String) -> Dictionary:
	_ensure_loaded()
	var resolved_id = _character_aliases.get(id, id)
	if characters.has(resolved_id):
		return characters[resolved_id].duplicate(true)
	return {}

func get_characters(include_unimplemented: bool = true) -> Dictionary:
	_ensure_loaded()
	# 目录内 62 个角色全部已接入角色选择（见 phase_d2 冒烟测试），没有「不可用」的行，
	# 因此这里没有过滤条件 —— 参数保留是为了兼容既有调用方，实际不产生筛选。
	# 历史上靠 `implemented` 过滤，但该字段 62 个角色里只有 1 个为 true，是死字段，已删除。
	return characters.duplicate(true)

func get_character_ids_for_unlock_condition(condition: String) -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in characters:
		var row: Dictionary = characters[id]
		var unlock: Dictionary = row.get("unlock", {})
		if str(unlock.get("condition", "")) == condition:
			result.append(id)
	return result

func get_weapon(id: String) -> Dictionary:
	_ensure_loaded()
	var resolved_id = _weapon_aliases.get(id, id)
	if weapons.has(resolved_id):
		return weapons[resolved_id].duplicate(true)
	return {}

func get_weapons(include_unimplemented: bool = true) -> Dictionary:
	_ensure_loaded()
	# 武器是否「可用」的唯一判据：其最低可获得 tier 在 tiers 里真实存在。
	# 与 get_weapon_shop_entries() 用的是同一个 _weapon_has_runtime_tier()。
	# 历史上用 `implemented`（78 把里只有 5 把为 true），是死字段，已删除。
	if include_unimplemented:
		return weapons.duplicate(true)
	var result: Dictionary = {}
	for id in weapons:
		var row: Dictionary = weapons[id]
		if _weapon_has_runtime_tier(row):
			result[id] = row.duplicate(true)
	return result

func get_weapon_class(id: String) -> Dictionary:
	_ensure_loaded()
	return weapon_classes.get(id, {}).duplicate(true)

func get_weapon_ids_by_class(class_id: String, include_unimplemented: bool = true) -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in weapons:
		var row: Dictionary = weapons[id]
		if not include_unimplemented and not _weapon_has_runtime_tier(row):
			continue
		if class_id in row.get("groups", []):
			result.append(id)
	return result

func get_item(id: String) -> Dictionary:
	_ensure_loaded()
	if items.has(id):
		return items[id].duplicate(true)
	return {}

func get_items(include_unimplemented: bool = true) -> Dictionary:
	_ensure_loaded()
	# items.json 已不再有 `implemented` 字段（历史上 235 条全是 false，是死字段）。
	# 现在「这个物品是否可用」只有唯一判据：效果是否受运行时支持 ——
	# 与 get_shop_pool() 完全一致。此前两者判据不同，正是本字段误导的来源。
	if include_unimplemented:
		return items.duplicate(true)
	var result: Dictionary = {}
	for id in items:
		var row: Dictionary = items[id]
		if _item_has_runtime_effects(row):
			result[id] = row.duplicate(true)
	return result

func get_shop_pool(include_unimplemented: bool = false) -> Array:
	_ensure_loaded()
	var pool: Array = []
	for id in items:
		var row: Dictionary = items[id]
		if not include_unimplemented and not _item_has_runtime_effects(row):
			continue
		pool.append(_item_to_shop_entry(row))
	return pool

func item_to_shop_entry(id: String) -> Dictionary:
	_ensure_loaded()
	var row = get_item(id)
	if row.is_empty():
		return {}
	return _item_to_shop_entry(row)

func get_weapon_shop_entries(include_unimplemented: bool = false) -> Array:
	_ensure_loaded()
	var entries: Array = []
	for id in weapons:
		var row: Dictionary = weapons[id]
		if not include_unimplemented and not _weapon_has_runtime_tier(row):
			continue
		var minimum_tier = _weapon_minimum_tier(row)
		var tier_row: Dictionary = row.get("tiers", {}).get(str(minimum_tier), {})
		entries.append({
			"name": row.get("display_name", row.get("source_name", id)),
			"desc": "目录武器",
			"price": int(tier_row.get("base_price", 1)),
			"rarity": minimum_tier - 1,
			"type": "weapon",
			"weapon_type": id,
			"source_id": id,
			"minimum_tier": minimum_tier,
		})
	return entries

func get_level_up_choices(wave: int = 0) -> Array:
	# 波末四选一的候选池。wave <= 0 表示不按波次过滤（供测试与调试使用）。
	_ensure_loaded()
	var choices: Array = []
	for id in upgrades:
		var row: Dictionary = upgrades[id]
		# 升级目录的 `implemented` 字段已删除（100/100 为 true，是死字段）；候选资格只看波次门槛
		if wave > 0 and not _upgrade_available_at_wave(row, wave):
			continue
		choices.append(_level_up_choice_entry(row))
	return choices

func _upgrade_available_at_wave(row: Dictionary, wave: int) -> bool:
	return wave >= int(row.get("min_wave", 1)) and wave <= int(row.get("max_wave", 999))

func _level_up_choice_entry(row: Dictionary) -> Dictionary:
	# 统一成 HUD 与 UpgradeChoiceRules 直接可用的形状。
	# name 是「标签 + 罗马数字」层级名，desc 只放数值增量（HUD 分两行渲染）。
	var stat = str(row.get("stat", ""))
	var value = float(row.get("value", 0.0))
	var tier = int(row.get("tier", 1))
	return {
		"id": str(row.get("id", "")),
		"stat": stat,
		"value": value,
		"tier": tier,
		"rarity": max(0, tier - 1),
		"weight": max(0.0, float(row.get("weight", 1.0))),
		"name": str(row.get("display_name", _stat_label(stat))),
		"stat_label": _stat_label(stat),
		"desc": _format_stat_delta_value(stat, value),
	}

func character_can_equip_weapon(character_id: String, weapon_id: String) -> bool:
	_ensure_loaded()
	var character = get_character(character_id)
	var weapon = get_weapon(weapon_id)
	if character.is_empty() or weapon.is_empty():
		return false
	for rule in character.get("rules", []):
		if not (rule is Dictionary):
			continue
		if rule.get("effect", "") == "forbid_weapon_group":
			var forbidden_group = str(rule.get("group", ""))
			if forbidden_group in weapon.get("groups", []):
				return false
			var attack_kind = str(weapon.get("attack_kind", ""))
			if forbidden_group == "ranged" and attack_kind.begins_with("ranged"):
				return false
			if forbidden_group == "melee" and attack_kind.begins_with("melee"):
				return false
	return true

func to_game_state_character(id: String) -> Dictionary:
	_ensure_loaded()
	var row = get_character(id)
	if row.is_empty():
		return {}
	var stats: Dictionary = row.get("base_stats", {})
	var starting_weapons: Array = row.get("starting_weapons", [])
	var primary_weapon = starting_weapons[0] if not starting_weapons.is_empty() else "pistol"
	var extra_weapon = starting_weapons[1] if starting_weapons.size() > 1 else ""
	var rules: Array = row.get("rules", [])
	var fixed_starting_items: Array = row.get("fixed_starting_items", [])
	var starting_items := _normalize_character_starting_items(rules, fixed_starting_items)
	var canonical_id = str(row.get("id", id))
	return {
		"catalog_id": canonical_id,
		"name": row.get("display_name", row.get("source_name", id)),
		"desc": _character_desc(row),
		"color": _character_color(canonical_id),
		"rules": rules.duplicate(true),
		"fixed_starting_items": fixed_starting_items.duplicate(true),
		"starting_items": starting_items,
		"hp_bonus": int(stats.get("max_hp", 0)),
		"spd_bonus": int(float(stats.get("speed_percent", 0.0)) * 300.0),
		"dmg_bonus": int(stats.get("ranged_damage", stats.get("melee_damage", 0))),
		"fr_bonus": float(stats.get("attack_speed_percent", 0.0)) / 100.0,
		"crit_bonus": float(stats.get("crit_chance", 0.0)),
		"lifesteal_bonus": float(stats.get("lifesteal", 0.0)),
		"regen_bonus": int(stats.get("hp_regeneration", 0)),
		"luck_bonus": int(stats.get("luck", 0)),
		"curse_bonus": int(stats.get("curse", 0)),
		"armor_bonus": int(stats.get("armor", 0)),
		"weapon": primary_weapon,
		"extra_weapon": extra_weapon,
		"unlock_condition": _character_unlock_condition(row),
	}

func _normalize_character_starting_items(rules: Array, fixed_starting_items: Array) -> Array:
	var result: Array = []
	for rule in rules:
		if not (rule is Dictionary):
			continue
		if str(rule.get("effect", "")) != "starting_item":
			continue
		var item_id = str(rule.get("item_id", ""))
		if item_id == "":
			continue
		var count = max(1, int(rule.get("count", 1)))
		for i in range(count):
			result.append({
				"item_id": item_id,
				"cursed": bool(rule.get("cursed", false)),
			})
	if not result.is_empty():
		return result
	for item_id in fixed_starting_items:
		var normalized_id = str(item_id)
		if normalized_id == "":
			continue
		result.append({
			"item_id": normalized_id,
			"cursed": false,
		})
	return result

func weapon_tier_to_combat_entry(id: String, tier: int = 1) -> Dictionary:
	_ensure_loaded()
	var weapon = get_weapon(id)
	if weapon.is_empty():
		return {}
	var tiers: Dictionary = weapon.get("tiers", {})
	var tier_key = str(clamp(tier, 1, 4))
	if not tiers.has(tier_key):
		return {}
	var row: Dictionary = tiers[tier_key]
	var damage: Dictionary = row.get("damage", {})
	var cooldown = max(0.01, float(row.get("cooldown", 1.0)))
	var spread_degrees = float(row.get("spread", 0.0))
	# Start from the raw tier row so that tier-level special fields (burn_damage,
	# explosion_chance, reload_interval, current_health_bonus_damage, etc.) are
	# preserved for runtime weapon-special-rule dispatch.
	var entry: Dictionary = row.duplicate(true)
	entry["name"] = weapon.get("display_name", weapon.get("source_name", id))
	entry["damage"] = int(damage.get("base", 1))
	entry["fire_rate"] = 1.0 / cooldown
	entry["count"] = int(row.get("projectiles", 1))
	entry["spread"] = spread_degrees
	entry["spd"] = float(row.get("projectile_speed", 500.0))
	entry["color"] = _tier_color(tier)
	entry["range"] = float(row.get("range", 0.0))
	entry["special_rules"] = weapon.get("special_rules", []).duplicate(true)
	entry["attack_kind"] = str(weapon.get("attack_kind", ""))
	# 注意：这里**不要**把 row.pierce 塌成布尔。目录里 pierce 是
	# {count, damage_multiplier}（穿透容量 + 每层衰减），上面的 duplicate 已经带过来了；
	# 历史上这里写过 `entry["pierce"] = true`，导致 count/damage_multiplier 在数据管道里
	# 就丢失，下游只能退回「凡有穿透一律 3 次命中」的猜测值。
	if str(weapon.get("attack_kind", "")).begins_with("melee"):
		entry["melee"] = true
		entry["melee_radius"] = float(row.get("range", 150.0))
	return entry

func get_combat_dict(include_unimplemented: bool = false) -> Dictionary:
	_ensure_loaded()
	var result: Dictionary = {}
	for id in weapons:
		var row: Dictionary = weapons[id]
		if not include_unimplemented and not _weapon_has_runtime_tier(row):
			continue
		var minimum_tier = _weapon_minimum_tier(row)
		var combat_entry = weapon_tier_to_combat_entry(id, minimum_tier)
		if combat_entry.is_empty():
			continue
		var tier_entries: Dictionary = {}
		for tier in range(minimum_tier, 5):
			var tier_entry = weapon_tier_to_combat_entry(id, tier)
			if not tier_entry.is_empty():
				tier_entries[str(tier)] = tier_entry
		combat_entry["minimum_tier"] = minimum_tier
		combat_entry["catalog_tiers"] = tier_entries
		result[id] = combat_entry
		for alias in row.get("runtime_aliases", []):
			result[str(alias)] = result[id].duplicate(true)
	return result

func _item_to_shop_entry(row: Dictionary) -> Dictionary:
	var effects: Array = row.get("effects", [])
	return {
		"name": row.get("display_name", row.get("source_name", row.get("id", ""))),
		"desc": _format_item_effects(effects),
		"price": int(row.get("base_price", 1)),
		"rarity": max(0, int(row.get("tier", 1)) - 1),
		"type": "catalog_item",
		"source_id": row.get("id", ""),
		"limit": row.get("limit", null),
		"tags": row.get("tags", []),
		"is_dlc": bool(row.get("is_dlc", false)),
		"effects": effects,
		"effect_text": _format_item_effects(effects),
	}

func _item_has_runtime_effects(row: Dictionary) -> bool:
	var effects: Array = row.get("effects", [])
	if effects.is_empty():
		return false
	for effect in effects:
		if not _effect_has_item_runtime_support(effect):
			return false
	return true

func _effect_has_item_runtime_support(effect) -> bool:
	if not (effect is Dictionary):
		return false
	var effect_id = str(effect.get("effect", ""))
	if effect_id not in RUNTIME_ITEM_EFFECTS:
		return false
	if effect_id == "stat_delta":
		return str(effect.get("stat", "")) in RUNTIME_ITEM_STATS
	if effect_id == "weapon_special":
		return str(effect.get("rule", "")) in RUNTIME_ITEM_SPECIAL_RULES
	return true

func _format_item_effects(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var effect_id = str(effect.get("effect", ""))
		match effect_id:
			"stat_delta":
				parts.append(_format_stat_delta(str(effect.get("stat", "")), float(effect.get("value", 0.0))))
			"pickup_range_percent":
				parts.append("拾取范围 %s" % _format_signed_percent(float(effect.get("value", 0.0))))
			"weapon_special":
				if str(effect.get("rule", "")) == "materials_plus_15_when_crate_pickup":
					parts.append("开箱材料 +15")
				elif str(effect.get("rule", "")) == "projectiles_pierce_plus_1":
					parts.append("投射物穿透 +1")
				elif str(effect.get("rule", "")) == "shoot_6_alien_eyes_every_3_seconds":
					parts.append("每3秒发射6枚外星之眼")
				elif str(effect.get("rule", "")) == "enemy_corpse_fires_ranged_damage_bullet":
					parts.append("敌人尸体发射远程伤害子弹")
				elif str(effect.get("rule", "")) == "gain_1_material_when_killing_cursed_enemy":
					parts.append("击杀诅咒敌人获得1材料")
				elif str(effect.get("rule", "")) == "elemental_damage_plus_1_per_30_burning_kills_max_4_per_wave":
					parts.append("每30次燃烧击杀获得元素伤害+1，每波最多+4")
				elif str(effect.get("rule", "")) == "explode_on_hit_chance":
					parts.append("命中爆炸概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "once_per_wave_explode_below_40_percent_health":
					parts.append("生命值低于40%时每波爆炸一次")
				elif str(effect.get("rule", "")) == "hp_regeneration_plus_1_per_different_tier_1_item":
					parts.append("每持有不同T1物品，生命回复+1")
				elif str(effect.get("rule", "")) == "hp_regeneration_minus_3_per_different_tier_4_item":
					parts.append("每持有不同T4物品，生命回复-3")
				elif str(effect.get("rule", "")) == "each_wave_random_primary_stats_plus_8":
					parts.append("每波随机主要属性 +%d" % int(effect.get("value", 8)))
				elif str(effect.get("rule", "")) == "each_wave_additional_elite_chance_10_percent":
					parts.append("每波额外精英概率 %s" % _format_signed_percent(float(effect.get("chance", 0.10))))
				elif str(effect.get("rule", "")) == "locked_shop_entries_chance_to_become_cursed":
					parts.append("锁定商店条目有%d%%概率被诅咒" % int(round(float(effect.get("chance", 0.0)) * 100.0)))
				elif str(effect.get("rule", "")) == "duplicate_next_shop_item_without_exceeding_limits":
					parts.append("复制下一个商店物品（不超限）")
				elif str(effect.get("rule", "")) == "broken_mirror_duplicated_item_state":
					parts.append("破碎镜子使用后状态")
				elif str(effect.get("rule", "")) == "resting_goldfish_post_use_state":
					parts.append("休息的金鱼使用后状态")
				elif str(effect.get("rule", "")) == "crit_kill_chance_to_heal_1_hp":
					parts.append("暴击击杀治疗概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "gain_1_material_on_critical_kill_chance":
					parts.append("暴击击杀材料概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "heal_1_hp_on_material_pickup_chance":
					parts.append("拾取材料治疗概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "double_picked_material_value_chance":
					parts.append("材料双倍拾取概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "hit_enemy_speed_reduction":
					parts.append("命中敌人速度 %s" % _format_signed_percent(-float(effect.get("value", 0.0))))
				elif str(effect.get("rule", "")) == "heal_5_hp_on_dodge_chance_50_percent":
					parts.append("闪避治疗概率 +50%")
				elif str(effect.get("rule", "")) == "nullify_one_hit_taken_per_wave":
					parts.append("每波免伤 +1")
				elif str(effect.get("rule", "")) == "start_wave_with_hp_percent_delta":
					parts.append("波次开始生命 %s" % _format_signed_percent(float(effect.get("value", 0.0))))
				elif str(effect.get("rule", "")) == "piercing_damage_cannot_exceed_base_damage":
					parts.append("穿透伤害不超过基础值")
				elif str(effect.get("rule", "")) == "material_drop_instant_attract_chance":
					parts.append("材料掉落瞬间吸引概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "material_pickup_luck_damage_chance":
					parts.append("拾取材料幸运伤害概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "enemy_death_luck_damage_chance":
					parts.append("敌人死亡幸运伤害概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "heal_1_hp_on_enemy_kill_chance":
					parts.append("击杀敌人治疗概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "dodge_cap_70_percent":
					parts.append("闪避上限70%")
				elif str(effect.get("rule", "")) == "burn_on_hit":
					parts.append("命中燃烧概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "burn_spread":
					parts.append("燃烧扩散至附近敌人")
				elif str(effect.get("rule", "")) == "enemy_death_explosion_chance":
					parts.append("敌人死亡爆炸概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "deal_melee_damage_on_dodge":
					parts.append("闪避近战伤害概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "critical_hits_deal_current_hp_bonus_damage":
					parts.append("暴击造成当前生命伤害 %s（Boss/精英 %s）" % [
						_format_signed_percent(float(effect.get("enemy_current_hp_percent", 0.0))),
						_format_signed_percent(float(effect.get("boss_elite_current_hp_percent", 0.0)))
					])
				elif str(effect.get("rule", "")) == "luck_plus_2_per_1_crit_chance_percent":
					parts.append("每+1%暴击率，幸运+2")
				elif str(effect.get("rule", "")) == "damage_percent_plus_5_every_5_seconds_until_wave_end":
					parts.append("每5秒伤害+5%，持续到波次结束")
				elif str(effect.get("rule", "")) == "hp_regeneration_doubled_below_50_percent_health":
					parts.append("生命低于50%时生命回复翻倍")
				elif str(effect.get("rule", "")) == "max_hp_plus_1_on_consumable_pickup_at_full_health_max_8_per_wave":
					parts.append("满血拾取消耗品时最大生命+1，每波最多+8")
				elif str(effect.get("rule", "")) == "hp_regeneration_plus_2_every_5_seconds_until_wave_end":
					parts.append("每5秒生命回复+2，持续到波次结束")
				elif str(effect.get("rule", "")) == "temporary_hp_regeneration_plus_1_on_full_health_consumable_pickup":
					parts.append("满血拾取消耗品时临时生命回复+1")
				elif str(effect.get("rule", "")) == "start_next_wave_with_1_hp":
					parts.append("下一波以1点生命开始")
				elif str(effect.get("rule", "")) == "max_hp_plus_1_per_80_materials":
					parts.append("每80材料最大生命+1")
				elif str(effect.get("rule", "")) == "damage_percent_minus_2_when_hit_until_wave_end":
					parts.append("受击时伤害-2%，持续到波次结束")
				elif str(effect.get("rule", "")) == "damage_percent_plus_1_per_1_knockback":
					parts.append("每1击退，伤害+1%")
				elif str(effect.get("rule", "")) == "damage_percent_plus_1_per_1_permanent_speed_percent":
					parts.append("每+1%速度，伤害+1%")
				elif str(effect.get("rule", "")) == "attack_speed_percent_plus_2_per_1_dodge_percent":
					parts.append("每+1%闪避，攻击速度+2%")
				elif str(effect.get("rule", "")) == "max_hp_plus_1_per_1_permanent_armor":
					parts.append("每1护甲，最大生命+1")
				elif str(effect.get("rule", "")) == "engineering_plus_1_per_1_permanent_elemental_damage":
					parts.append("每1元素伤害，工程+1")
				elif str(effect.get("rule", "")) == "damage_percent_plus_3_end_wave":
					parts.append("波次结束时伤害+3%")
				elif str(effect.get("rule", "")) == "max_hp_plus_3_end_wave":
					parts.append("波次结束时最大生命+3")
				elif str(effect.get("rule", "")) == "hp_regeneration_plus_1_end_wave":
					parts.append("波次结束时生命回复+1")
				elif str(effect.get("rule", "")) == "lifesteal_plus_1_percent_end_wave":
					parts.append("波次结束时生命偷取+1%")
				elif str(effect.get("rule", "")) == "melee_damage_plus_3_end_wave":
					parts.append("波次结束时近战伤害+3")
				elif str(effect.get("rule", "")) == "engineering_plus_3_end_wave":
					parts.append("波次结束时工程+3")
				elif str(effect.get("rule", "")) == "max_hp_minus_1_end_wave":
					parts.append("波次结束时最大生命-1")
				elif str(effect.get("rule", "")) == "armor_minus_1_end_wave":
					parts.append("波次结束时护甲-1")
				elif str(effect.get("rule", "")) == "hp_regeneration_plus_1_on_level_up":
					parts.append("升级时生命回复+1")
				elif str(effect.get("rule", "")) == "lifesteal_plus_1_percent_and_max_hp_minus_1_on_level_up":
					parts.append("升级时生命偷取+1%且最大生命-1")
				elif str(effect.get("rule", "")) == "level_upgrade_stats_plus_35_percent":
					parts.append("升级属性提升增强35%")
				elif str(effect.get("rule", "")) == "curse_plus_1_on_level_up":
					parts.append("升级时诅咒+1")
				elif str(effect.get("rule", "")) == "decrease_current_wave_count_by_1":
					parts.append("当前波数-1")
				elif str(effect.get("rule", "")) == "broken_hourglass_start_next_wave_with_1_hp":
					parts.append("下一波以1点生命开始")
				elif str(effect.get("rule", "")) == "max_hp_capped_at_current_value":
					parts.append("最大生命封顶为当前值")
				elif str(effect.get("rule", "")) == "speed_capped_at_current_value":
					parts.append("速度封顶为当前值")
				elif str(effect.get("rule", "")) == "materials_plus_20_percent_start_wave_until_wave_20":
					parts.append("波次开始材料+20%，持续到第20波")
				elif str(effect.get("rule", "")) == "max_hp_plus_1_per_distinct_weapon":
					parts.append("每持有一种不同武器，最大生命+1")
				elif str(effect.get("rule", "")) == "attack_speed_percent_plus_6_per_different_weapon":
					parts.append("每持有一种不同武器，攻击速度+6%")
				elif str(effect.get("rule", "")) == "attack_speed_percent_minus_3_per_different_weapon":
					parts.append("每持有一种不同武器，攻击速度-3%")
				elif str(effect.get("rule", "")) == "hp_regeneration_plus_2_per_negative_1_permanent_speed_percent":
					parts.append("每负1%速度，生命回复+2")
				elif str(effect.get("rule", "")) == "harvesting_growth_percent_plus_8_end_wave":
					parts.append("波次结束时收获成长+8%")
				elif str(effect.get("rule", "")) == "xp_gain_percent_plus_5_end_wave":
					parts.append("波次结束时经验获取+5%")
				elif str(effect.get("rule", "")) == "next_wave_xp_gain_percent_plus_100":
					parts.append("下一波经验获取+100%")
				elif str(effect.get("rule", "")) == "next_wave_xp_gain_percent_plus_50":
					parts.append("下一波经验获取+50%")
				elif str(effect.get("rule", "")) == "next_wave_enemy_health_percent_plus_100":
					parts.append("下一波敌人生命+100%")
				elif str(effect.get("rule", "")) == "next_wave_enemy_damage_percent_plus_50":
					parts.append("下一波敌人伤害+50%")
				elif str(effect.get("rule", "")) == "next_wave_enemy_speed_percent_plus_25":
					parts.append("下一波敌人速度+25%")
				elif str(effect.get("rule", "")) == "next_wave_additional_loot_aliens":
					parts.append("下一波材料外星人 +%d" % int(effect.get("count", 0)))
				elif str(effect.get("rule", "")) == "spawn_special_enemies_next_wave":
					parts.append("下一波生成特殊敌人")
				elif str(effect.get("rule", "")) == "nightmare_fog_visibility_percent_plus_25":
					parts.append("噩梦迷雾可见度+25%")
				elif str(effect.get("rule", "")) == "nightmare_fog_visibility_percent_plus_50":
					parts.append("噩梦迷雾可见度+50%")
				elif str(effect.get("rule", "")) == "nightmare_fog_visibility_percent_plus_75":
					parts.append("噩梦迷雾可见度+75%")
				elif str(effect.get("rule", "")) == "elemental_damage_plus_1_when_getting_elemental_damage_item":
					parts.append("从物品获得元素伤害时，元素伤害+1")
				elif str(effect.get("rule", "")) == "damage_percent_plus_20_for_2_seconds_after_consumable_pickup":
					parts.append("拾取消耗品后2秒内伤害+20%")
				elif str(effect.get("rule", "")) == "speed_percent_plus_10_for_3_seconds_when_taking_damage":
					parts.append("受击后3秒内速度+10%")
				elif str(effect.get("rule", "")) == "one_free_shop_reroll":
					parts.append("一次免费商店刷新")
				elif str(effect.get("rule", "")) == "extra_item_chance_in_crate":
					parts.append("箱子额外物品概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "take_1_damage_per_second_without_invulnerability":
					parts.append("每秒受到1点伤害（不触发无敌）")
				elif str(effect.get("rule", "")) == "damage_percent_plus_2_per_1_lifesteal_percent":
					parts.append("每1%生命偷取，伤害+2%")
				elif str(effect.get("rule", "")) == "structures_attack_speed_scales_with_player_attack_speed":
					parts.append("建筑攻击速度随玩家攻击速度缩放")
				elif str(effect.get("rule", "")) == "engineering_minus_1_per_structure":
					parts.append("每持有一个建筑，工程-1")
				elif str(effect.get("rule", "")) == "armor_plus_8_while_standing_still":
					parts.append("站立不动时护甲+8")
				elif str(effect.get("rule", "")) == "attack_speed_percent_plus_40_while_standing_still":
					parts.append("站立不动时攻击速度+40%")
				elif str(effect.get("rule", "")) == "dodge_percent_plus_20_while_standing_still":
					parts.append("站立不动时闪避+20%")
				elif str(effect.get("rule", "")) == "hp_regeneration_plus_10_while_standing_still":
					parts.append("站立不动时生命回复+10")
				elif str(effect.get("rule", "")) == "burning_activates_20_percent_faster":
					parts.append("燃烧触发速度+20%")
				elif str(effect.get("rule", "")) == "burning_activates_100_percent_slower":
					parts.append("燃烧触发速度-100%")
				elif str(effect.get("rule", "")) == "weapon_damage_scales_with_10_percent_elemental_damage":
					parts.append("武器伤害随元素伤害的10%缩放")
				elif str(effect.get("rule", "")) == "weapon_damage_scales_with_20_percent_engineering":
					parts.append("武器伤害随工程的20%缩放")
				elif str(effect.get("rule", "")) == "enemies_take_10_percent_more_damage_for_3_seconds_on_first_elemental_hit":
					parts.append("元素命中使敌人3秒内受伤+10%")
				elif str(effect.get("rule", "")) == "burning_deals_current_enemy_hp_bonus_damage":
					parts.append("燃烧造成当前生命加成伤害")
				elif str(effect.get("rule", "")) == "attack_speed_percent_plus_1_every_second_until_wave_end_lost_on_damage":
					parts.append("每秒攻击速度+1%直到波次结束；受击时失去")
				elif str(effect.get("rule", "")) == "attack_speed_percent_plus_1_per_living_enemy":
					parts.append("每个存活敌人攻击速度+1%")
				elif str(effect.get("rule", "")) == "hp_regeneration_plus_1_per_currently_burning_enemy":
					parts.append("每个燃烧敌人生命回复+1")
				elif str(effect.get("rule", "")) == "damage_percent_plus_1_per_10_permanent_luck":
					parts.append("每10幸运，伤害+1%")
				elif str(effect.get("rule", "")) == "extra_pearl_chance_in_crate":
					parts.append("箱子中珍珠概率 %s" % _format_signed_percent(float(effect.get("chance", 0.0))))
				elif str(effect.get("rule", "")) == "weapon_minimum_cooldown_0_75_seconds":
					parts.append("武器最小冷却0.75秒")
				elif str(effect.get("rule", "")) == "projectiles_gain_1_piercing_on_critical_hit":
					parts.append("暴击投射物穿透+1")
				elif str(effect.get("rule", "")) == "restore_5_hp_per_second_cannot_heal_other_way":
					parts.append("每秒恢复5点生命；无法通过其他方式治疗")
				elif str(effect.get("rule", "")) == "consumables_heal_over_4_seconds_instead_of_instant":
					parts.append("消耗品治疗改为4秒持续恢复")
				elif str(effect.get("rule", "")) == "weapons_can_no_longer_be_upgraded_or_recycled":
					parts.append("武器无法升级或回收")
				elif str(effect.get("rule", "")) == "items_one_tier_higher_after_next_reroll":
					parts.append("下次刷新后物品提升一阶")
				elif str(effect.get("rule", "")) == "shop_reroll_damage_percent_plus_1_chance":
					parts.append("商店刷新有%d%%概率获得+1%%伤害" % int(round(float(effect.get("chance", 0.0)) * 100.0)))
				elif str(effect.get("rule", "")) == "shop_reroll_max_hp_minus_1_chance":
					parts.append("商店刷新有%d%%概率失去1点最大生命" % int(round(float(effect.get("chance", 0.0)) * 100.0)))
				elif str(effect.get("rule", "")) == "swap_highest_and_lowest_positive_primary_stats_on_pickup":
					parts.append("拾取时交换最高和最低的主要属性")
				elif str(effect.get("rule", "")) == "upgrade_random_weapon_entering_shop_or_gain_2_armor":
					parts.append("进入商店时随机升级一把武器或获得+2护甲")
				elif str(effect.get("rule", "")) == "more_trees_spawn":
					parts.append("生成更多树木")
				elif str(effect.get("rule", "")) == "trees_die_in_one_hit":
					parts.append("树木一击必杀")
				elif str(effect.get("rule", "")) == "enemies_have_higher_fruit_drop_chance":
					parts.append("敌人掉落水果概率提升")
				elif str(effect.get("rule", "")) == "spawn_garden_creates_fruit_every_15_seconds":
					parts.append("生成花园，每15秒产生水果")
				elif str(effect.get("rule", "")) == "spawn_turret_each_wave":
					parts.append("每波生成一个炮塔")
				elif str(effect.get("rule", "")) == "spawn_landmine_every_12_seconds":
					parts.append("每12秒生成一个地雷")
				elif str(effect.get("rule", "")) == "spawn_explosive_turret":
					parts.append("生成爆炸炮塔")
				elif str(effect.get("rule", "")) == "spawn_incendiary_turret":
					parts.append("生成燃烧炮塔")
				elif str(effect.get("rule", "")) == "spawn_laser_turret":
					parts.append("生成激光炮塔")
				elif str(effect.get("rule", "")) == "spawn_medical_turret":
					parts.append("生成医疗炮塔")
				elif str(effect.get("rule", "")) == "structures_can_crit":
					parts.append("建筑可以暴击")
				elif str(effect.get("rule", "")) == "killing_tree_spawns_turret":
					parts.append("击杀树木生成炮塔")
				elif str(effect.get("rule", "")) == "spawn_tyler":
					parts.append("生成泰勒")
				elif str(effect.get("rule", "")) == "spawn_wandering_bot_that_slows_nearby_enemies":
					parts.append("生成流浪机器人，减速附近敌人")
				elif str(effect.get("rule", "")) == "unique_builders_turret":
					parts.append("生成建造者炮塔")
				elif str(effect.get("rule", "")) == "knock_nearby_enemies_back_every_3_seconds":
					parts.append("每3秒击退附近敌人")
				elif str(effect.get("rule", "")) == "projectiles_bounce_plus_1":
					parts.append("投射物弹跳+1")
				elif str(effect.get("rule", "")) == "every_ranged_weapon_fifth_projectile_has_plus_3_projectiles":
					parts.append("每第五次远程射击增加3发投射物")
				elif str(effect.get("rule", "")) == "consumable_explosion_chance":
					parts.append("消耗品爆炸概率 %s" % _format_signed_percent(float(effect.get("chance", 0.50))))
	if parts.is_empty():
		return "Special effect pending runtime support"
	var text := ""
	for part in parts:
		if text != "":
			text += ", "
		text += part
	return text

func _format_stat_delta(stat: String, value: float) -> String:
	return "%s %s" % [_stat_label(stat), _format_stat_delta_value(stat, value)]

func _format_stat_delta_value(stat: String, value: float) -> String:
	# 只格式化增量本身（含正负号），供「标签与数值分行显示」的场景复用
	if _stat_is_fraction_percent(stat):
		return _format_signed_percent(value)
	if is_equal_approx(value, round(value)):
		return "%+d" % int(round(value))
	return "%+.2f" % value

func _stat_label(stat: String) -> String:
	match stat:
		"max_hp": return "最大生命值"
		"hp_regeneration": return "生命回复"
		"speed_percent": return "速度"
		"attack_speed_percent": return "攻击速度"
		"damage_percent": return "伤害"
		"melee_damage": return "近战伤害"
		"ranged_damage": return "远程伤害"
		"elemental_damage": return "元素伤害"
		"crit_chance": return "暴击率"
		"lifesteal": return "生命偷取"
		"consumable_heal": return "消耗品治疗"
		"xp_gain_percent": return "经验获取"
		"pickup_range_percent": return "拾取范围"
		"item_price_percent": return "物品价格"
		"reroll_price_percent": return "刷新价格"
		"recycling_materials_percent": return "回收材料"
		"enemy_health_percent": return "敌人生命"
		"enemy_damage_percent": return "敌人伤害"
		"boss_elite_damage_percent": return "Boss/精英伤害"
		"enemy_speed_percent": return "敌人速度"
		"enemies_percent": return "敌人数量"
		"materials_dropped_percent": return "材料掉落"
		"structure_attack_speed_percent": return "建筑攻击速度"
		"piercing_damage_percent": return "穿透伤害"
		"accuracy_percent": return "命中"
		"curse": return "诅咒"
		"loot_alien_chance_percent": return "材料外星人概率"
		"loot_alien_speed_percent": return "材料外星人速度"
		"dodge": return "闪避"
		"harvesting": return "收获"
		"armor": return "护甲"
		"engineering": return "工程"
		"knockback": return "击退"
		"luck": return "幸运"
		"range": return "射程"
		"hp": return "生命"
		"speed": return "速度"
		"explosion_damage_percent": return "爆炸伤害"
		"explosion_size_percent": return "爆炸范围"
		"damage_against_high_health_targets_percent": return "对高生命目标伤害"
		"dodge_cap": return "闪避上限"
		"max_weapon_slots": return "最大武器槽"
		"starting_weapon_slots": return "起始武器槽"
		"projectiles": return "投射物数量"
		"piercing": return "穿透"
		"melee_weapon_range": return "近战武器范围"
		"map_size_percent": return "地图大小"
		"weapon_price_percent": return "武器价格"
		"bait_price_percent": return "诱饵价格"
		"harpoon_gun_price_percent": return "鱼叉枪价格"
		"extra_trees": return "额外树木"
		"tree_materials_percent": return "树木材料"
		"xp_required": return "升级所需经验"
		"xp_required_multiplier": return "升级经验倍率"
		"start_wave_materials_percent": return "波次开始材料"
		"recycle_materials_percent": return "回收材料"
		"curse_end_wave_delta": return "波次结束诅咒变化"
		"range_end_wave_delta": return "波次结束射程变化"
		"enemy_health_end_wave_percent": return "波次结束敌人生命"
		"enemy_damage_end_wave_percent": return "波次结束敌人伤害"
		"xp_gain_end_wave_percent": return "波次结束经验获取"
		"harvesting_end_of_wave": return "波次结束收获"
		"harvesting_on_full_health_consumable": return "满血消耗品收获"
		_: return stat.capitalize()

func _stat_is_fraction_percent(stat: String) -> bool:
	return stat.ends_with("_percent") or stat in ["crit_chance", "lifesteal", "dodge"]

func _format_signed_percent(value: float) -> String:
	return "%+d%%" % int(round(value * 100.0))

func _clear():
	manifest = {}
	effect_schema = {}
	item_tags = {}
	weapon_classes = {}
	weapons = {}
	items = {}
	upgrades = {}
	characters = {}
	_weapon_aliases = {}
	_character_aliases = {}
	_loaded = false
	_load_errors.clear()

func _ensure_loaded():
	if not _loaded and _load_errors.is_empty():
		load_catalog()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		_load_errors.append("Missing catalog file: " + path)
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_load_errors.append("Failed to open catalog file: " + path)
		return null
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		_load_errors.append("Invalid JSON: " + path)
	return parsed

func _index_array(path: String, value) -> Dictionary:
	var indexed: Dictionary = {}
	if not (value is Array):
		_load_errors.append("%s must be an array" % path)
		return indexed
	for entry in value:
		if not (entry is Dictionary):
			_load_errors.append("%s contains a non-object entry" % path)
			continue
		var id = str(entry.get("id", ""))
		if id == "":
			_load_errors.append("%s contains an entry without id" % path)
			continue
		if indexed.has(id):
			_load_errors.append("%s contains duplicate id: %s" % [path, id])
			continue
		indexed[id] = entry
	return indexed

func _build_aliases():
	for id in weapons:
		var row: Dictionary = weapons[id]
		for alias in row.get("runtime_aliases", []):
			_weapon_aliases[str(alias)] = id
	for id in characters:
		var row: Dictionary = characters[id]
		for alias in row.get("runtime_aliases", []):
			_character_aliases[str(alias)] = id

func _weapon_minimum_tier(row: Dictionary) -> int:
	return clamp(int(row.get("minimum_tier", 1)), 1, 4)

func _weapon_has_runtime_tier(row: Dictionary) -> bool:
	var tiers: Dictionary = row.get("tiers", {})
	return tiers.has(str(_weapon_minimum_tier(row)))

func _validate_manifest(errors: Array[String]):
	for field in ["schema_version", "reference_game", "reference_version", "expected_counts", "source_urls"]:
		if not manifest.has(field):
			errors.append("catalog_manifest missing field: " + field)

func _validate_effect_schema(errors: Array[String]):
	for effect_id in effect_schema:
		var spec = effect_schema[effect_id]
		if not (spec is Dictionary):
			errors.append("effect_schema.%s must be an object" % effect_id)
			continue
		if not spec.has("required") or not (spec.required is Array):
			errors.append("effect_schema.%s.required must be an array" % effect_id)

func _validate_tags(errors: Array[String]):
	for id in item_tags:
		_require_fields(errors, "item_tags.%s" % id, item_tags[id], ["id", "source_name", "category"])

func _validate_weapon_classes(errors: Array[String]):
	for id in weapon_classes:
		var row: Dictionary = weapon_classes[id]
		_require_fields(errors, "weapon_classes.%s" % id, row, ["id", "source_name", "thresholds"])
		_validate_effects(errors, "weapon_classes.%s.thresholds" % id, _collect_threshold_effects(row.get("thresholds", {})))

func _validate_weapons(errors: Array[String]):
	for id in weapons:
		var row: Dictionary = weapons[id]
		_require_fields(errors, "weapons.%s" % id, row, ["id", "source_name", "display_name", "is_dlc", "groups", "attack_kind", "unlocked_by", "tiers", "special_rules"])
		for group in row.get("groups", []):
			if not weapon_classes.has(str(group)):
				errors.append("weapons.%s references missing weapon class: %s" % [id, group])
		var tiers: Dictionary = row.get("tiers", {})
		var minimum_tier = clamp(int(row.get("minimum_tier", 1)), 1, 4)
		for tier in range(minimum_tier, 5):
			var tier_key = str(tier)
			if not tiers.has(tier_key):
				errors.append("weapons.%s missing tier %s" % [id, tier_key])
				continue
			_require_fields(errors, "weapons.%s.tiers.%s" % [id, tier_key], tiers[tier_key], ["damage", "cooldown", "range", "crit_multiplier", "crit_chance", "knockback", "lifesteal", "base_price", "projectiles"])
		_validate_effects(errors, "weapons.%s.special_rules" % id, row.get("special_rules", []))

func _validate_items(errors: Array[String]):
	for id in items:
		var row: Dictionary = items[id]
		_require_fields(errors, "items.%s" % id, row, ["id", "source_name", "display_name", "is_dlc", "tier", "base_price", "limit", "unlocked_by", "tags", "effects"])
		for tag in row.get("tags", []):
			if not item_tags.has(str(tag)):
				errors.append("items.%s references missing item tag: %s" % [id, tag])
		_validate_effects(errors, "items.%s.effects" % id, row.get("effects", []))

func _validate_upgrades(errors: Array[String]):
	for id in upgrades:
		var path := "upgrades.%s" % id
		var row: Dictionary = upgrades[id]
		_require_fields(errors, path, row, ["id", "display_name", "tier", "stat", "value", "weight", "min_wave", "max_wave"])
		var stat = str(row.get("stat", ""))
		if stat.is_empty():
			continue
		# 升级选项最终由 PlayerUpgrades._apply_catalog_stat_delta 应用，
		# 写错属性名会静默无效，因此在这里硬性拦住。
		if stat not in RUNTIME_ITEM_STATS:
			errors.append("%s.stat 不在 RUNTIME_ITEM_STATS 中，运行时无法应用: %s" % [path, stat])
		var tier = int(row.get("tier", 0))
		if tier < 1 or tier > 4:
			errors.append("%s.tier 必须在 1-4 之间，实际 %d" % [path, tier])
		if int(row.get("min_wave", 1)) > int(row.get("max_wave", 999)):
			errors.append("%s 的 min_wave 大于 max_wave" % path)

func _validate_enemy_waves(errors: Array[String]):
	var total := int(enemy_wave_config.get("total_waves", 0))
	if total <= 0:
		errors.append("enemy_waves.total_waves 必须为正整数，实际 %d" % total)
	for wave_num in range(1, total + 1):
		var path := "enemy_waves.%d" % wave_num
		if not enemy_waves.has(str(wave_num)):
			errors.append("%s 缺少波次定义" % path)
			continue
		var row: Dictionary = enemy_waves[str(wave_num)]
		_require_fields(errors, path, row, ["id", "theme", "duration", "spawn_interval", "boss", "boss_count", "pool"])
		# 主题是「每波可命名」这一设计原则的载体，缺失会让波次退化为无意义的编号。
		if str(row.get("theme", "")).strip_edges().is_empty():
			errors.append("%s.theme 不能为空" % path)
		if float(row.get("duration", 0.0)) <= 0.0:
			errors.append("%s.duration 必须为正数，实际 %s" % [path, str(row.get("duration", 0.0))])
		if float(row.get("spawn_interval", 0.0)) <= 0.0:
			errors.append("%s.spawn_interval 必须为正数，实际 %s" % [path, str(row.get("spawn_interval", 0.0))])
		# boss 与 boss_count 必须一致，否则会出现「有 boss 定义却刷不出」或「没定义却要求刷」。
		var boss_type := str(row.get("boss", ""))
		var boss_count := int(row.get("boss_count", 0))
		if boss_type.is_empty() and boss_count != 0:
			errors.append("%s 未指定 boss，boss_count 却为 %d" % [path, boss_count])
		if not boss_type.is_empty() and boss_count < 1:
			errors.append("%s 指定了 boss=%s，boss_count 却小于 1" % [path, boss_type])
		var pool = row.get("pool", [])
		if not (pool is Array) or pool.is_empty():
			errors.append("%s.pool 不能为空" % path)
			continue
		for i in range(pool.size()):
			var entry = pool[i]
			if not (entry is Dictionary):
				errors.append("%s.pool[%d] 必须是对象" % [path, i])
				continue
			var type_name := str(entry.get("type", ""))
			if type_name.is_empty():
				errors.append("%s.pool[%d].type 不能为空" % [path, i])
			if float(entry.get("weight", 0.0)) <= 0.0:
				errors.append("%s.pool[%d].weight 必须为正数（type=%s）" % [path, i, type_name])
	for id in enemy_waves:
		if int(id) > total:
			errors.append("enemy_waves.%s 超出了 total_waves=%d" % [id, total])

func _validate_characters(errors: Array[String]):
	for id in characters:
		var row: Dictionary = characters[id]
		_require_fields(errors, "characters.%s" % id, row, ["id", "source_name", "display_name", "is_dlc", "unlock", "unlocks", "wanted_tags", "starting_weapons", "fixed_starting_weapons", "fixed_starting_items", "base_stats", "rules"])
		for weapon_id in row.get("starting_weapons", []):
			if get_weapon(str(weapon_id)).is_empty():
				errors.append("characters.%s references missing starting weapon: %s" % [id, weapon_id])
		for weapon_id in row.get("fixed_starting_weapons", []):
			if get_weapon(str(weapon_id)).is_empty():
				errors.append("characters.%s references missing fixed starting weapon: %s" % [id, weapon_id])
		for item_id in row.get("fixed_starting_items", []):
			if not items.has(str(item_id)):
				errors.append("characters.%s references missing fixed starting item: %s" % [id, item_id])
		for tag in row.get("wanted_tags", []):
			if not item_tags.has(str(tag)):
				errors.append("characters.%s references missing wanted tag: %s" % [id, tag])
		_validate_character_dodge_unit(errors, id, row)
		_validate_effects(errors, "characters.%s.rules" % id, row.get("rules", []))

# dodge 在 characters 里**必须是分数**（0.15 = 15%），base_stats 与 rules 两处都一样：
# 描述渲染（_character_desc 里 ×100）与运行时应用（dodge_chance += value）都按分数处理。
# 历史上 brawler / crazy 把它写成了百分点（15 / -30），当时靠 PlayerUpgrades 里一个
# 静默的 `abs(value) > 1.0 → /100` 归一化器兜住 —— 玩法侥幸没坏，但角色选择界面
# 显示成「闪避: 1500%」。这里改成加载期直接报错：**把静默容忍换成响亮的门**，
# 同时它也让「描述」与「玩法」不再各走一条单位转换路径。
func _validate_character_dodge_unit(errors: Array[String], id: String, row: Dictionary):
	var base_stats: Dictionary = row.get("base_stats", {})
	if base_stats.has("dodge"):
		var base_dodge = base_stats.get("dodge")
		if absf(float(base_dodge)) > 1.0:
			errors.append("characters.%s.base_stats.dodge 必须是分数（0.15 表示 15%%），实际 %s" % [id, str(base_dodge)])
	for rule in row.get("rules", []):
		if not (rule is Dictionary):
			continue
		if str(rule.get("stat", "")) != "dodge":
			continue
		var rule_value = float(rule.get("value", 0.0))
		if absf(rule_value) > 1.0:
			errors.append("characters.%s.rules 的 dodge 必须是分数（0.15 表示 15%%），实际 %s" % [id, str(rule_value)])

func _validate_effects(errors: Array[String], path: String, effects: Array):
	for i in range(effects.size()):
		var effect = effects[i]
		if not (effect is Dictionary):
			errors.append("%s[%d] must be an object" % [path, i])
			continue
		var effect_id = str(effect.get("effect", ""))
		if effect_id == "":
			errors.append("%s[%d] missing effect" % [path, i])
			continue
		if not effect_schema.has(effect_id):
			errors.append("%s[%d] references unknown effect: %s" % [path, i, effect_id])
			continue
		for field in effect_schema[effect_id].get("required", []):
			if not effect.has(str(field)):
				errors.append("%s[%d] effect %s missing field: %s" % [path, i, effect_id, field])

func _collect_threshold_effects(thresholds) -> Array:
	var result: Array = []
	if not (thresholds is Dictionary):
		return result
	for key in thresholds:
		var effects = thresholds[key]
		if effects is Array:
			result.append_array(effects)
	return result

func _require_fields(errors: Array[String], path: String, row: Dictionary, fields: Array):
	for field in fields:
		if not row.has(str(field)):
			errors.append("%s missing field: %s" % [path, field])

func _character_desc(row: Dictionary) -> String:
	var stats: Dictionary = row.get("base_stats", {})
	var parts: Array[String] = []
	for key in stats:
		var cn_key = key
		match key:
			"max_hp": cn_key = "最大生命值"
			"hp_regeneration": cn_key = "生命回复"
			"lifesteal": cn_key = "生命偷取"
			"damage": cn_key = "伤害"
			"melee_damage": cn_key = "近战伤害"
			"ranged_damage": cn_key = "远程伤害"
			"elemental_damage": cn_key = "元素伤害"
			"engineering": cn_key = "工程"
			"attack_speed_percent": cn_key = "攻击速度"
			"crit_chance": cn_key = "暴击率"
			"range": cn_key = "射程"
			"armor": cn_key = "护甲"
			"dodge": cn_key = "闪避"
			"speed_percent": cn_key = "速度"
			"luck": cn_key = "幸运"
			"harvesting": cn_key = "收获"
			"curse": cn_key = "诅咒"
			"xp_gain_percent": cn_key = "经验获取"
			"item_price_percent": cn_key = "物品价格"
			"enemy_health_percent": cn_key = "敌人生命"
			"enemy_damage_percent": cn_key = "敌人伤害"
			"enemy_speed_percent": cn_key = "敌人速度"
			"pickup_range": cn_key = "拾取范围"
			"pickup_range_percent": cn_key = "拾取范围"
			"boss_elite_damage_percent": cn_key = "Boss/精英伤害"
			"consumable_heal": cn_key = "消耗品治疗"
			"damage_percent": cn_key = "伤害"
			"dodge_cap": cn_key = "闪避上限"
			"enemies_percent": cn_key = "敌人数量"
			"explosion_damage_percent": cn_key = "爆炸伤害"
			"materials_dropped_percent": cn_key = "材料掉落"
			"max_weapon_slots": cn_key = "最大武器槽"
			"starting_weapon_slots": cn_key = "起始武器槽"
			"melee_weapon_range": cn_key = "近战武器范围"
			"map_size_percent": cn_key = "地图大小"
			"piercing": cn_key = "穿透"
			"piercing_damage_percent": cn_key = "穿透伤害"
			"projectiles": cn_key = "投射物数量"
			"weapon_price_percent": cn_key = "武器价格"
			"bait_price_percent": cn_key = "诱饵价格"
			"harpoon_gun_price_percent": cn_key = "鱼叉枪价格"
			"extra_trees": cn_key = "额外树木"
			"tree_materials_percent": cn_key = "树木材料"
			"xp_required": cn_key = "升级所需经验"
			"xp_required_multiplier": cn_key = "升级经验倍率"
			"start_wave_materials_percent": cn_key = "波次开始材料"
			"recycle_materials_percent": cn_key = "回收材料"
			"curse_end_wave_delta": cn_key = "波次结束诅咒变化"
			"range_end_wave_delta": cn_key = "波次结束射程变化"
			"enemy_health_end_wave_percent": cn_key = "波次结束敌人生命"
			"enemy_damage_end_wave_percent": cn_key = "波次结束敌人伤害"
			"xp_gain_end_wave_percent": cn_key = "波次结束经验获取"
			"harvesting_end_of_wave": cn_key = "波次结束收获"
			"harvesting_on_full_health_consumable": cn_key = "满血消耗品收获"
		var value = stats[key]
		var value_str = str(value)
		# base_stats 里除 attack_speed_percent 外，*_percent 键存的是分数（0.1 = 10%），
		# 与 to_game_state_character() 的消费方式一致（speed_percent × 300 得到速度）。
		# attack_speed_percent 是唯一例外：它按百分点存储（见 to_game_state_character()
		# 中的 `/ 100.0`），因此直接补 % 号，不能再乘 100。
		if key == "attack_speed_percent":
			value_str = "%d%%" % int(value)
		elif key.ends_with("_percent") or key in ["lifesteal", "crit_chance", "dodge", "speed_percent"]:
			value_str = "%d%%" % int(value * 100)
		parts.append("%s: %s" % [cn_key, value_str])
	return "\n".join(parts)

func _character_unlock_condition(row: Dictionary) -> String:
	var unlock: Dictionary = row.get("unlock", {})
	var unlock_type = str(unlock.get("type", ""))
	if unlock_type == "default":
		return "默认解锁"
	var condition = str(unlock.get("condition", ""))
	if condition != "":
		return "解锁条件: " + condition
	if unlock_type != "":
		return "解锁类型: " + unlock_type
	return "未解锁"

func _character_color(id: String) -> Color:
	match id:
		"well_rounded":
			return Color(0.3, 0.9, 0.4)
		"brawler":
			return Color(0.9, 0.45, 0.25)
		"crazy":
			return Color(0.9, 0.2, 0.6)
		"ranger":
			return Color(0.3, 0.8, 1.0)
		"mage":
			return Color(0.55, 0.25, 1.0)
		_:
			return Color(0.8, 0.8, 0.8)

func _tier_color(tier: int) -> Color:
	match clamp(tier, 1, 4):
		1:
			return Color(1, 1, 1)
		2:
			return Color(0.3, 0.8, 1.0)
		3:
			return Color(0.7, 0.3, 1.0)
		_:
			return Color(1.0, 0.75, 0.2)
