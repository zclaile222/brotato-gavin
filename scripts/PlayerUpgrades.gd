# PlayerUpgrades.gd — 升级系统、被动效果、协同效果
class_name PlayerUpgrades
extends RefCounted

var p: CharacterBody2D
const SPEED_PERCENT_BASE := 300.0
const PICKUP_RANGE_BASE := 160.0
const CURSED_ITEM_CURSE_PRICE_COEFFICIENT := 0.7

const SYNERGIES = {
	"fire_master": {
		"name": "火焰大师",
		"desc": "燃烧伤害+100%，燃烧概率+20%",
		"color": Color(1.0, 0.4, 0.0),
		"requires": {"weapons": ["flamethrower"], "effects": ["burn_chance"]},
		"bonuses": {"burn_chance": 0.2}
	},
	"ice_age": {
		"name": "冰河时代",
		"desc": "冻结持续时间翻倍，速度+30",
		"color": Color(0.4, 0.7, 1.0),
		"requires": {"effects": ["freeze_chance", "time_slow"]},
		"bonuses": {"speed": 30}
	},
	"bulletstorm": {
		"name": "弹幕风暴",
		"desc": "射速+25%，弹道散射-50%",
		"color": Color(1.0, 0.8, 0.2),
		"requires": {"weapons_any2": ["machinegun", "smg", "minigun"]},
		"bonuses": {"fire_rate": 0.25}
	},
	"glass_cannon": {
		"name": "玻璃大炮",
		"desc": "伤害+5，最大HP-3",
		"color": Color(1.0, 0.2, 0.2),
		"requires": {"effects": ["revenge"], "min_damage_bonus": 5},
		"bonuses": {"damage": 5, "hp_penalty": 3}
	},
	"tank_build": {
		"name": "钢铁堡垒",
		"desc": "护甲+3，每波回血+2",
		"color": Color(0.5, 0.5, 0.7),
		"requires": {"min_armor": 4, "min_max_hp": 15},
		"bonuses": {"armor": 3, "hp_regen": 2}
	},
	"vampire": {
		"name": "吸血鬼",
		"desc": "吸血+10%，击杀回1HP",
		"color": Color(0.8, 0.1, 0.2),
		"requires": {"min_lifesteal": 0.1, "effects": ["revenge"]},
		"bonuses": {"lifesteal": 0.1}
	},
	"speed_demon": {
		"name": "速度恶魔",
		"desc": "速度+60，暴击率+10%",
		"color": Color(0.2, 1.0, 0.6),
		"requires": {"effects": ["adrenaline"], "min_speed": 400},
		"bonuses": {"speed": 60, "crit_chance": 0.1}
	},
}

func init(player: CharacterBody2D):
	p = player

func apply_upgrade(upgrade):
	var changed_stats: Array = []
	match upgrade.type:
		"speed":
			p.speed += upgrade.value
			p.base_speed += upgrade.value
			changed_stats.append("speed")
		"fire_rate":   p.fire_rate_multiplier += upgrade.value
		"damage":
			p.damage_bonus += upgrade.value
			changed_stats.append("damage_bonus")
		"hp":
			p.max_hp += upgrade.value
			p.core.heal(upgrade.value)
			changed_stats.append("max_hp")
		"heal":        p.core.heal(upgrade.value)
		"magnet":      p.magnet_range += upgrade.value
		"armor":
			p.armor += upgrade.value
			changed_stats.append("armor")
		"crit_chance": p.crit_chance = min(p.crit_chance + upgrade.value, 0.8)
		"crit_damage":
			p.crit_damage += upgrade.value
			p.crit_chance = min(p.crit_chance + upgrade.get("crit_chance_bonus", 0.0), 0.8)
		"lifesteal":
			p.lifesteal = min(p.lifesteal + upgrade.value, 0.5)
			if p.has_method("recalculate_lifesteal_scaling_damage"):
				p.recalculate_lifesteal_scaling_damage()
			changed_stats.append("lifesteal")
		"hp_regen":    p.hp_regen += upgrade.value
		"luck":        p.luck += upgrade.value
		"weapon":
			var tier = int(upgrade.get("tier", upgrade.get("rolled_rarity", upgrade.get("rarity", 0)) + 1))
			if p.combat.equip_or_combine_weapon(upgrade.weapon_type, tier):
				changed_stats.append("weapons")
		"hp_armor":
			p.armor   += upgrade.get("armor_val",  0)
			p.max_hp  += upgrade.get("hp_val",     0)
			p.core.heal(upgrade.get("hp_val", 0))
			changed_stats.append("armor")
			changed_stats.append("max_hp")
		"passive":
			changed_stats = _apply_passive_effect(upgrade)
		"catalog_item":
			if p.has_method("record_catalog_item_ownership"):
				p.record_catalog_item_ownership(upgrade, 1.0)
			changed_stats = _apply_catalog_item_effects(upgrade, 1.0)
		"ammo":
			p.ammo_type = upgrade.get("ammo", "")
	check_synergies(changed_stats)

func apply_catalog_rule_effects(effects: Array, direction: float = 1.0, normalize_character_stats: bool = false) -> Array:
	var changed: Array = []
	for effect in effects:
		if not (effect is Dictionary):
			continue
		match str(effect.get("effect", "")):
			"stat_delta":
				var stat = str(effect.get("stat", ""))
				var value = float(effect.get("value", 0.0))
				if normalize_character_stats:
					value = _normalize_character_stat_delta(stat, value)
				changed.append_array(_apply_catalog_stat_delta(stat, value * direction, direction))
			"pickup_range_percent":
				var value = float(effect.get("value", 0.0))
				changed.append_array(_apply_catalog_stat_delta("pickup_range_percent", value * direction, direction))
			"stat_modifications_multiplier":
				_apply_catalog_stat_modification_multiplier(str(effect.get("stat", "")), float(effect.get("multiplier", 1.0)), direction)
				changed.append("stat_modifications_multiplier")
			"weapon_special":
				changed.append_array(_apply_catalog_special_rule(effect, direction))
	check_synergies(changed)
	return changed

func _normalize_character_stat_delta(stat: String, value: float) -> float:
	# 只保留 attack_speed_percent 的容忍：characters 里这个字段按**百分点**存
	# （25 表示 +25%），与本项目其它 *_percent（存分数）相反。
	# dodge 曾经也写错过单位（brawler=15 / crazy=-30），当时靠这里静默 /100 兜住 ——
	# 玩法没坏，但描述渲染走的是另一条路径，于是界面显示成「闪避: 1500%」。
	# 现已改为在 BrotatoData 加载期直接报错（_validate_character_dodge_unit），
	# 因此不再需要容忍分支：**两条路径各转各的，迟早会不一致。**
	match stat:
		"attack_speed_percent":
			if abs(value) > 2.0:
				return value / 100.0
	return value

func _apply_catalog_stat_modification_multiplier(stat: String, multiplier: float, direction: float):
	if stat == "":
		return
	if direction < 0.0:
		p.catalog_stat_modification_multipliers.erase(stat)
		return
	p.catalog_stat_modification_multipliers[stat] = multiplier

func _apply_catalog_level_up_stat_deltas(effect: Dictionary, direction: float):
	for stat in p.LEVEL_UP_CATALOG_STAT_KEYS:
		if not effect.has(stat):
			continue
		var delta = float(effect.get(stat, 0.0)) * direction
		var next_delta = float(p.level_up_catalog_stat_deltas.get(stat, 0.0)) + delta
		if is_equal_approx(next_delta, 0.0):
			p.level_up_catalog_stat_deltas.erase(stat)
		else:
			p.level_up_catalog_stat_deltas[stat] = next_delta

func _apply_catalog_item_effects(upgrade: Dictionary, direction: float) -> Array:
	var changed: Array = []
	var source_id = str(upgrade.get("source_id", upgrade.get("id", "")))
	var cursed_bonus = _get_catalog_cursed_item_curse_bonus(upgrade)
	if cursed_bonus != 0:
		p.curse = max(0, int(p.curse) + int(round(float(cursed_bonus) * direction)))
		changed.append("curse")
	for effect in upgrade.get("effects", []):
		if not (effect is Dictionary):
			continue
		match str(effect.get("effect", "")):
			"stat_delta":
				changed.append_array(_apply_catalog_stat_delta(str(effect.get("stat", "")), float(effect.get("value", 0.0)) * direction, direction, source_id))
			"pickup_range_percent":
				changed.append_array(_apply_catalog_stat_delta("pickup_range_percent", float(effect.get("value", 0.0)) * direction, direction, source_id))
			"weapon_special":
				changed.append_array(_apply_catalog_special_rule(effect, direction))
	return changed

func _get_catalog_cursed_item_curse_bonus(upgrade: Dictionary) -> int:
	if not (bool(upgrade.get("catalog_cursed", false)) or bool(upgrade.get("is_cursed", false)) or bool(upgrade.get("cursed", false))):
		return 0
	if upgrade.has("cursed_item_curse_bonus"):
		return max(0, int(upgrade.get("cursed_item_curse_bonus", 0)))
	return max(0, int(round(float(upgrade.get("price", 0)) * CURSED_ITEM_CURSE_PRICE_COEFFICIENT)))

func _apply_catalog_stat_delta(stat: String, delta: float, direction: float = 1.0, source_id: String = "") -> Array:
	var changed: Array = []
	if direction > 0.0 and p.catalog_stat_modification_multipliers.has(stat):
		delta *= float(p.catalog_stat_modification_multipliers.get(stat, 1.0))
	_record_catalog_stat_delta(stat, delta)
	match stat:
		"max_hp":
			var hp_delta = _resolve_catalog_max_hp_delta(int(round(delta)), direction, source_id)
			var actual_delta = p.apply_max_hp_delta(hp_delta) if p.has_method("apply_max_hp_delta") else hp_delta
			if not p.has_method("apply_max_hp_delta"):
				p.max_hp = max(1, p.max_hp + actual_delta)
				if actual_delta > 0:
					p.hp = min(p.hp + actual_delta, p.max_hp)
				else:
					p.hp = min(p.hp, p.max_hp)
				p.hp_changed.emit(p.hp, p.max_hp)
			if direction > 0.0 and int(round(delta)) > actual_delta:
				_record_catalog_suppressed_stat_delta(stat, float(int(round(delta)) - actual_delta), source_id)
			_record_catalog_actual_stat_delta(stat, actual_delta)
			changed.append("max_hp")
		"hp_regeneration":
			p.hp_regen += int(round(delta))
			changed.append("hp_regen")
		"armor":
			p.armor += int(round(delta))
			if p.has_method("recalculate_armor_scaling_max_hp"):
				p.recalculate_armor_scaling_max_hp()
			changed.append("armor")
		"speed_percent":
			var speed_percent_delta = _resolve_catalog_speed_percent_delta(delta, direction, source_id)
			var speed_delta = SPEED_PERCENT_BASE * speed_percent_delta
			var actual_speed_delta = p.apply_speed_delta(speed_delta) if p.has_method("apply_speed_delta") else speed_delta
			if not p.has_method("apply_speed_delta"):
				p.speed = max(100.0, p.speed + actual_speed_delta)
				p.base_speed = max(100.0, p.base_speed + actual_speed_delta)
			var actual_speed_percent_delta = actual_speed_delta / SPEED_PERCENT_BASE
			if direction > 0.0 and delta > actual_speed_percent_delta:
				_record_catalog_suppressed_stat_delta(stat, delta - actual_speed_percent_delta, source_id)
			_record_catalog_actual_stat_delta(stat, actual_speed_percent_delta)
			if p.has_method("recalculate_speed_scaling_damage"):
				p.recalculate_speed_scaling_damage()
			if p.has_method("recalculate_negative_speed_regen"):
				p.recalculate_negative_speed_regen()
			changed.append("speed")
		"attack_speed_percent":
			p.fire_rate_multiplier = max(0.1, p.fire_rate_multiplier + delta)
		"damage_percent":
			p.damage_percent_bonus += delta
			changed.append("damage_bonus")
		"melee_damage":
			p.melee_damage_bonus += int(round(delta))
			changed.append("damage_bonus")
		"ranged_damage":
			p.ranged_damage_bonus += int(round(delta))
			changed.append("damage_bonus")
		"elemental_damage":
			p.elemental_damage_bonus += int(round(delta))
			if direction > 0.0 and delta > 0.0 and p.elemental_item_pickup_bonus_sources > 0:
				var bonus = p.elemental_item_pickup_bonus_sources
				p.elemental_damage_bonus += bonus
				p.elemental_item_pickup_bonus_granted += bonus
			if p.has_method("recalculate_elemental_scaling_engineering"):
				p.recalculate_elemental_scaling_engineering()
		"engineering":
			p.engineering_bonus += int(round(delta))
		"crit_chance":
			p.crit_chance = min(p.crit_chance + delta, 0.8)
			if p.has_method("recalculate_crit_scaling_luck"):
				p.recalculate_crit_scaling_luck()
		"lifesteal":
			p.lifesteal = min(p.lifesteal + delta, 0.5)
			if p.has_method("recalculate_lifesteal_scaling_damage"):
				p.recalculate_lifesteal_scaling_damage()
			changed.append("lifesteal")
		"luck":
			p.luck += int(round(delta))
			if p.has_method("recalculate_luck_scaling_damage"):
				p.recalculate_luck_scaling_damage()
		"curse":
			p.curse = max(0, int(p.curse) + int(round(delta)))
		"accuracy_percent":
			p.accuracy_percent += delta
		"dodge":
			p.dodge_chance = min(p.dodge_chance + delta, p.dodge_cap)
			if p.has_method("recalculate_dodge_scaling_attack_speed"):
				p.recalculate_dodge_scaling_attack_speed()
		"harvesting":
			p.gold_per_wave += int(round(delta))
		"range":
			p.range_bonus += delta
		"knockback":
			p.knockback_bonus += delta
			if p.has_method("recalculate_knockback_scaling_damage"):
				p.recalculate_knockback_scaling_damage()
		"consumable_heal":
			p.consumable_heal_bonus += int(round(delta))
		"xp_gain_percent":
			p.xp_boost = max(0.0, p.xp_boost + delta)
		"pickup_range_percent":
			p.magnet_range = max(20.0, p.magnet_range + PICKUP_RANGE_BASE * delta)
		"item_price_percent":
			p.item_price_percent = max(-0.95, p.item_price_percent + delta)
		"reroll_price_percent":
			p.reroll_price_percent = max(-0.95, p.reroll_price_percent + delta)
		"recycling_materials_percent":
			p.recycling_materials_percent = max(-0.95, p.recycling_materials_percent + delta)
		"enemy_health_percent":
			p.enemy_health_percent = max(-0.95, p.enemy_health_percent + delta)
		"enemy_damage_percent":
			p.enemy_damage_percent = max(-0.95, p.enemy_damage_percent + delta)
		"boss_elite_damage_percent":
			p.boss_elite_damage_percent = max(-0.95, p.boss_elite_damage_percent + delta)
		"enemy_speed_percent":
			p.enemy_speed_percent = max(-0.95, p.enemy_speed_percent + delta)
		"enemies_percent":
			p.enemies_percent = max(-0.95, p.enemies_percent + delta)
		"materials_dropped_percent":
			p.materials_dropped_percent = max(-0.95, p.materials_dropped_percent + delta)
		"loot_alien_chance_percent":
			p.loot_alien_chance_percent = max(0.0, p.loot_alien_chance_percent + delta)
		"loot_alien_speed_percent":
			p.loot_alien_speed_percent = max(-0.95, p.loot_alien_speed_percent + delta)
		"piercing_damage_percent":
			p.piercing_damage_percent = max(-0.95, p.piercing_damage_percent + delta)
		"explosion_damage_percent":
			p.explosion_damage_percent = max(-0.95, p.explosion_damage_percent + delta)
		"explosion_size_percent":
			p.explosion_size_percent = max(-0.95, p.explosion_size_percent + delta)
		"damage_against_high_health_targets_percent":
			p.damage_against_high_health_targets_percent = max(-0.95, p.damage_against_high_health_targets_percent + delta)
		"structure_attack_speed_percent":
			p.structure_attack_speed_percent = max(-0.95, p.structure_attack_speed_percent + delta)
			changed.append("structure_attack_speed_percent")
	return changed

func _apply_catalog_special_rule(effect: Dictionary, direction: float) -> Array:
	var changed: Array = []
	match str(effect.get("rule", "")):
		"materials_plus_15_when_crate_pickup":
			p.crate_material_bonus = max(0, p.crate_material_bonus + int(round(15.0 * direction)))
			changed.append("crate_material_bonus")
		"projectiles_pierce_plus_1":
			p.projectile_pierce_bonus = max(0, p.projectile_pierce_bonus + int(round(direction)))
			changed.append("projectile_pierce_bonus")
		"shoot_6_alien_eyes_every_3_seconds":
			p.alien_eyes_sources = max(0, p.alien_eyes_sources + int(round(direction)))
			if direction > 0.0:
				p.alien_eyes_projectile_count = 6
				p.alien_eyes_base_damage = float(effect.get("damage", p.alien_eyes_base_damage))
				p.alien_eyes_max_hp_damage_coefficient = float(effect.get("max_hp_damage_coefficient", p.alien_eyes_max_hp_damage_coefficient))
			elif p.alien_eyes_sources == 0:
				p.alien_eyes_timer = 0.0
			changed.append("alien_eyes_projectiles")
		"enemy_corpse_fires_ranged_damage_bullet":
			p.corpse_bullet_sources = max(0, p.corpse_bullet_sources + int(round(direction)))
			if direction > 0.0:
				p.corpse_bullet_base_damage = float(effect.get("damage", p.corpse_bullet_base_damage))
				p.corpse_bullet_ranged_damage_coefficient = float(effect.get("ranged_damage_coefficient", p.corpse_bullet_ranged_damage_coefficient))
			elif p.corpse_bullet_sources == 0:
				p.corpse_bullet_base_damage = 0.0
				p.corpse_bullet_ranged_damage_coefficient = 0.0
			changed.append("corpse_bullet_projectiles")
		"gain_1_material_when_killing_cursed_enemy":
			p.cursed_enemy_material_bonus_sources = max(0, p.cursed_enemy_material_bonus_sources + int(round(direction)))
			changed.append("cursed_enemy_material_bonus")
		"elemental_damage_plus_1_per_30_burning_kills_max_4_per_wave":
			p.burning_kill_elemental_damage_sources = max(0, p.burning_kill_elemental_damage_sources + int(round(direction)))
			if p.burning_kill_elemental_damage_sources == 0 and p.has_method("reset_burning_kill_elemental_damage_wave_bonus"):
				p.reset_burning_kill_elemental_damage_wave_bonus()
			changed.append("burning_kill_elemental_damage")
		"explode_on_hit_chance":
			p.hit_explosion_chance = max(0.0, p.hit_explosion_chance + float(effect.get("chance", 0.0)) * direction)
			p.hit_explosion_sources = max(0, p.hit_explosion_sources + int(round(direction)))
			if direction > 0.0:
				p.hit_explosion_base_damage = float(effect.get("damage", p.hit_explosion_base_damage))
				p.hit_explosion_curse_coefficient = float(effect.get("curse_damage_coefficient", p.hit_explosion_curse_coefficient))
			elif p.hit_explosion_sources == 0:
				p.hit_explosion_base_damage = 0.0
				p.hit_explosion_curse_coefficient = 0.0
			changed.append("hit_explosion")
		"once_per_wave_explode_below_40_percent_health":
			p.low_health_explosion_sources = max(0, p.low_health_explosion_sources + int(round(direction)))
			if direction > 0.0:
				p.low_health_explosion_base_damage = float(effect.get("damage", p.low_health_explosion_base_damage))
				p.low_health_explosion_melee_coefficient = float(effect.get("melee_damage_coefficient", p.low_health_explosion_melee_coefficient))
				p.low_health_explosion_ranged_coefficient = float(effect.get("ranged_damage_coefficient", p.low_health_explosion_ranged_coefficient))
				p.low_health_explosion_elemental_coefficient = float(effect.get("elemental_damage_coefficient", p.low_health_explosion_elemental_coefficient))
				p.low_health_explosion_engineering_coefficient = float(effect.get("engineering_damage_coefficient", p.low_health_explosion_engineering_coefficient))
			elif p.low_health_explosion_sources == 0:
				p.low_health_explosion_triggered_this_wave = false
			changed.append("low_health_explosion")
		"hp_regeneration_plus_1_per_different_tier_1_item":
			p.fairy_tier1_regen_sources = max(0, p.fairy_tier1_regen_sources + int(round(direction)))
			if p.has_method("recalculate_fairy_item_tier_regeneration"):
				p.recalculate_fairy_item_tier_regeneration()
			changed.append("fairy_tier1_regen")
		"hp_regeneration_minus_3_per_different_tier_4_item":
			p.fairy_tier4_regen_sources = max(0, p.fairy_tier4_regen_sources + int(round(direction)))
			if p.has_method("recalculate_fairy_item_tier_regeneration"):
				p.recalculate_fairy_item_tier_regeneration()
			changed.append("fairy_tier4_regen")
		"each_wave_random_primary_stats_plus_8":
			p.candy_bag_random_stat_sources = max(0, p.candy_bag_random_stat_sources + int(round(direction)))
			if direction > 0.0:
				p.candy_bag_random_stat_value = float(effect.get("value", p.candy_bag_random_stat_value))
			elif p.candy_bag_random_stat_sources == 0 and p.has_method("clear_candy_bag_wave_random_stat"):
				p.clear_candy_bag_wave_random_stat()
			changed.append("candy_bag_random_stat")
		"each_wave_additional_elite_chance_10_percent":
			p.additional_elite_chance = max(0.0, p.additional_elite_chance + float(effect.get("chance", 0.10)) * direction)
			changed.append("additional_elite_chance")
		"locked_shop_entries_chance_to_become_cursed":
			p.locked_shop_entry_curse_chance = max(0.0, p.locked_shop_entry_curse_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("locked_shop_entry_curse_chance")
		"duplicate_next_shop_item_without_exceeding_limits":
			p.mirror_duplicate_next_shop_item_pending = max(0, p.mirror_duplicate_next_shop_item_pending + int(round(direction)))
			changed.append("mirror_duplicate_next_shop_item")
		"broken_mirror_duplicated_item_state":
			p.broken_mirror_duplicated_item_sources = max(0, p.broken_mirror_duplicated_item_sources + int(round(direction)))
			changed.append("broken_mirror_duplicated_item_state")
		"resting_goldfish_post_use_state":
			p.resting_goldfish_post_use_sources = max(0, p.resting_goldfish_post_use_sources + int(round(direction)))
			changed.append("resting_goldfish_post_use_state")
		"crit_kill_chance_to_heal_1_hp":
			p.crit_kill_heal_chance = max(0.0, p.crit_kill_heal_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("crit_kill_heal_chance")
		"gain_1_material_on_critical_kill_chance":
			p.crit_kill_material_chance = max(0.0, p.crit_kill_material_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("crit_kill_material_chance")
		"heal_1_hp_on_material_pickup_chance":
			p.material_pickup_heal_chance = max(0.0, p.material_pickup_heal_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("material_pickup_heal_chance")
		"double_picked_material_value_chance":
			p.double_material_pickup_chance = max(0.0, p.double_material_pickup_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("double_material_pickup_chance")
		"hit_enemy_speed_reduction":
			p.hit_enemy_slow_percent_per_hit = max(0.0, p.hit_enemy_slow_percent_per_hit + float(effect.get("value", 0.0)) * direction)
			p.hit_enemy_slow_percent_max = max(0.0, p.hit_enemy_slow_percent_max + float(effect.get("max", 0.0)) * direction)
			changed.append("hit_enemy_slow")
		"heal_5_hp_on_dodge_chance_50_percent":
			p.dodge_heal_chance = max(0.0, p.dodge_heal_chance + 0.50 * direction)
			p.dodge_heal_amount = max(0, p.dodge_heal_amount + int(round(5.0 * direction)))
			changed.append("dodge_heal")
		"nullify_one_hit_taken_per_wave":
			var delta = int(round(direction))
			p.nullify_hits_per_wave = max(0, p.nullify_hits_per_wave + delta)
			p.nullify_hits_remaining = clamp(p.nullify_hits_remaining + delta, 0, p.nullify_hits_per_wave)
			changed.append("nullify_hits")
		"start_wave_with_hp_percent_delta":
			p.wave_start_hp_percent_delta += float(effect.get("value", 0.0)) * direction
			changed.append("wave_start_hp")
		"start_next_wave_with_1_hp":
			p.start_next_wave_with_one_hp_sources = max(0, p.start_next_wave_with_one_hp_sources + int(round(direction)))
			changed.append("start_next_wave_with_one_hp")
		"broken_hourglass_start_next_wave_with_1_hp":
			p.start_next_wave_with_one_hp_sources = max(0, p.start_next_wave_with_one_hp_sources + int(round(direction)))
			changed.append("start_next_wave_with_one_hp")
		"max_hp_capped_at_current_value":
			if direction > 0.0:
				if p.max_hp_cap_sources <= 0:
					p.max_hp_cap_value = max(1, int(p.max_hp))
				p.max_hp_cap_sources += int(round(direction))
				if int(p.max_hp) > int(p.max_hp_cap_value) and p.has_method("apply_max_hp_delta"):
					p.apply_max_hp_delta(int(p.max_hp_cap_value) - int(p.max_hp), false, false)
			else:
				p.max_hp_cap_sources = max(0, p.max_hp_cap_sources + int(round(direction)))
				if p.max_hp_cap_sources == 0:
					p.max_hp_cap_value = 0
			changed.append("max_hp_cap")
		"speed_capped_at_current_value":
			if direction > 0.0:
				if p.speed_cap_sources <= 0:
					p.speed_cap_value = float(p.base_speed)
				p.speed_cap_sources += int(round(direction))
				if float(p.base_speed) > float(p.speed_cap_value) and p.has_method("apply_speed_delta"):
					p.apply_speed_delta(float(p.speed_cap_value) - float(p.base_speed), false)
			else:
				p.speed_cap_sources = max(0, p.speed_cap_sources + int(round(direction)))
				if p.speed_cap_sources == 0:
					p.speed_cap_value = 0.0
			changed.append("speed_cap")
		"materials_plus_20_percent_start_wave_until_wave_20":
			p.piggy_bank_sources = max(0, p.piggy_bank_sources + int(round(direction)))
			changed.append("piggy_bank")
		"max_hp_plus_1_per_distinct_weapon":
			p.distinct_weapon_max_hp_sources = max(0, p.distinct_weapon_max_hp_sources + int(round(direction)))
			if p.has_method("recalculate_distinct_weapon_scaling"):
				p.recalculate_distinct_weapon_scaling()
			changed.append("distinct_weapon_max_hp")
		"attack_speed_percent_plus_6_per_different_weapon":
			p.distinct_weapon_attack_speed_per_weapon += 0.06 * direction
			if is_equal_approx(p.distinct_weapon_attack_speed_per_weapon, 0.0):
				p.distinct_weapon_attack_speed_per_weapon = 0.0
			if p.has_method("recalculate_distinct_weapon_scaling"):
				p.recalculate_distinct_weapon_scaling()
			changed.append("distinct_weapon_attack_speed")
		"attack_speed_percent_minus_3_per_different_weapon":
			p.distinct_weapon_attack_speed_per_weapon -= 0.03 * direction
			if is_equal_approx(p.distinct_weapon_attack_speed_per_weapon, 0.0):
				p.distinct_weapon_attack_speed_per_weapon = 0.0
			if p.has_method("recalculate_distinct_weapon_scaling"):
				p.recalculate_distinct_weapon_scaling()
			changed.append("distinct_weapon_attack_speed")
		"hp_regeneration_plus_2_per_negative_1_permanent_speed_percent":
			p.negative_speed_regen_sources = max(0, p.negative_speed_regen_sources + int(round(direction)))
			if p.has_method("recalculate_negative_speed_regen"):
				p.recalculate_negative_speed_regen()
			changed.append("negative_speed_regen")
		"harvesting_growth_percent_plus_8_end_wave":
			p.end_wave_harvesting_growth_percent = max(0.0, p.end_wave_harvesting_growth_percent + 0.08 * direction)
			changed.append("end_wave_harvesting_growth")
		"xp_gain_percent_plus_5_end_wave":
			p.end_wave_xp_gain_percent = max(0.0, p.end_wave_xp_gain_percent + 0.05 * direction)
			changed.append("end_wave_xp_gain")
		"next_wave_xp_gain_percent_plus_100":
			p.next_wave_xp_gain_percent_pending = max(0.0, p.next_wave_xp_gain_percent_pending + 1.00 * direction)
			changed.append("next_wave_xp_gain")
		"next_wave_xp_gain_percent_plus_50":
			p.next_wave_xp_gain_percent_pending = max(0.0, p.next_wave_xp_gain_percent_pending + 0.50 * direction)
			changed.append("next_wave_xp_gain")
		"next_wave_enemy_health_percent_plus_100":
			p.next_wave_enemy_health_percent_pending = max(0.0, p.next_wave_enemy_health_percent_pending + 1.00 * direction)
			changed.append("next_wave_enemy_health")
		"next_wave_enemy_damage_percent_plus_50":
			p.next_wave_enemy_damage_percent_pending = max(0.0, p.next_wave_enemy_damage_percent_pending + 0.50 * direction)
			changed.append("next_wave_enemy_damage")
		"next_wave_enemy_speed_percent_plus_25":
			p.next_wave_enemy_speed_percent_pending = max(0.0, p.next_wave_enemy_speed_percent_pending + 0.25 * direction)
			changed.append("next_wave_enemy_speed")
		"next_wave_additional_loot_aliens":
			var count = int(effect.get("count", 0))
			p.next_wave_loot_alien_count_pending = max(0, p.next_wave_loot_alien_count_pending + int(round(float(count) * direction)))
			changed.append("next_wave_loot_aliens")
		"spawn_special_enemies_next_wave":
			if direction > 0.0:
				p.next_wave_special_enemy_count_pending += 1
			changed.append("next_wave_special_enemy")
		"nightmare_fog_visibility_percent_plus_25":
			p.nightmare_fog_visibility_percent = max(0.0, p.nightmare_fog_visibility_percent + 0.25 * direction)
			changed.append("nightmare_fog_visibility")
		"nightmare_fog_visibility_percent_plus_50":
			p.nightmare_fog_visibility_percent = max(0.0, p.nightmare_fog_visibility_percent + 0.50 * direction)
			changed.append("nightmare_fog_visibility")
		"nightmare_fog_visibility_percent_plus_75":
			p.nightmare_fog_visibility_percent = max(0.0, p.nightmare_fog_visibility_percent + 0.75 * direction)
			changed.append("nightmare_fog_visibility")
		"elemental_damage_plus_1_when_getting_elemental_damage_item":
			p.elemental_item_pickup_bonus_sources = max(0, p.elemental_item_pickup_bonus_sources + int(round(direction)))
			changed.append("elemental_item_pickup_bonus")
		"damage_percent_plus_20_for_2_seconds_after_consumable_pickup":
			p.consumable_damage_boost_sources = max(0, p.consumable_damage_boost_sources + int(round(direction)))
			if p.consumable_damage_boost_sources == 0 and p.has_method("clear_consumable_damage_boost"):
				p.clear_consumable_damage_boost()
			changed.append("consumable_damage_boost")
		"speed_percent_plus_10_for_3_seconds_when_taking_damage":
			p.damage_taken_speed_boost_sources = max(0, p.damage_taken_speed_boost_sources + int(round(direction)))
			if p.damage_taken_speed_boost_sources == 0 and p.has_method("clear_damage_taken_speed_boost"):
				p.clear_damage_taken_speed_boost()
			changed.append("damage_taken_speed_boost")
		"one_free_shop_reroll":
			p.free_shop_rerolls = max(0, p.free_shop_rerolls + int(round(direction)))
			changed.append("free_shop_rerolls")
		"extra_item_chance_in_crate":
			p.extra_crate_reward_chance = max(0.0, p.extra_crate_reward_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("extra_crate_reward_chance")
		"take_1_damage_per_second_without_invulnerability":
			p.self_damage_per_second_sources = max(0, p.self_damage_per_second_sources + int(round(direction)))
			if p.self_damage_per_second_sources == 0:
				p.self_damage_timer = 0.0
			changed.append("self_damage_per_second")
		"damage_percent_plus_2_per_1_lifesteal_percent":
			p.lifesteal_scaling_damage_sources = max(0, p.lifesteal_scaling_damage_sources + int(round(direction)))
			if p.has_method("recalculate_lifesteal_scaling_damage"):
				p.recalculate_lifesteal_scaling_damage()
			changed.append("lifesteal_scaling_damage")
		"structures_attack_speed_scales_with_player_attack_speed":
			p.structures_scale_with_player_attack_speed_sources = max(0, p.structures_scale_with_player_attack_speed_sources + int(round(direction)))
			changed.append("structure_attack_speed_scaling")
		"engineering_minus_1_per_structure":
			p.structure_engineering_penalty_sources = max(0, p.structure_engineering_penalty_sources + int(round(direction)))
			if p.has_method("recalculate_structure_engineering_penalty"):
				p.recalculate_structure_engineering_penalty()
			changed.append("structure_engineering_penalty")
		"armor_plus_8_while_standing_still":
			p.stand_still_armor_sources = max(0, p.stand_still_armor_sources + int(round(direction)))
			if p.has_method("update_stand_still_item_bonuses"):
				p.update_stand_still_item_bonuses()
			changed.append("stand_still_armor")
		"attack_speed_percent_plus_40_while_standing_still":
			p.stand_still_attack_speed_sources = max(0, p.stand_still_attack_speed_sources + int(round(direction)))
			if p.has_method("update_stand_still_item_bonuses"):
				p.update_stand_still_item_bonuses()
			changed.append("stand_still_attack_speed")
		"dodge_percent_plus_20_while_standing_still":
			p.stand_still_dodge_sources = max(0, p.stand_still_dodge_sources + int(round(direction)))
			if p.has_method("update_stand_still_item_bonuses"):
				p.update_stand_still_item_bonuses()
			changed.append("stand_still_dodge")
		"hp_regeneration_plus_10_while_standing_still":
			p.stand_still_hp_regen_sources = max(0, p.stand_still_hp_regen_sources + int(round(direction)))
			if p.has_method("update_stand_still_item_bonuses"):
				p.update_stand_still_item_bonuses()
			changed.append("stand_still_hp_regen")
		"burning_activates_20_percent_faster":
			p.burn_tick_interval_percent_modifier += -0.20 * direction
			changed.append("burn_tick_interval")
		"burning_activates_100_percent_slower":
			p.burn_tick_interval_percent_modifier += 1.00 * direction
			changed.append("burn_tick_interval")
		"enemies_take_10_percent_more_damage_for_3_seconds_on_first_elemental_hit":
			p.elemental_vulnerability_sources = max(0, p.elemental_vulnerability_sources + int(round(direction)))
			changed.append("elemental_vulnerability")
		"burning_deals_current_enemy_hp_bonus_damage":
			p.burn_current_hp_bonus_sources = max(0, p.burn_current_hp_bonus_sources + int(round(direction)))
			if direction > 0.0:
				p.burn_current_hp_bonus_enemy_percent = float(effect.get("enemy_current_hp_percent", p.burn_current_hp_bonus_enemy_percent))
				p.burn_current_hp_bonus_boss_elite_percent = float(effect.get("boss_elite_current_hp_percent", p.burn_current_hp_bonus_boss_elite_percent))
			elif p.burn_current_hp_bonus_sources == 0:
				p.burn_current_hp_bonus_enemy_percent = 0.0
				p.burn_current_hp_bonus_boss_elite_percent = 0.0
			changed.append("burn_current_hp_bonus")
		"weapon_damage_scales_with_10_percent_elemental_damage":
			p.elemental_weapon_damage_scaling_sources = max(0, p.elemental_weapon_damage_scaling_sources + int(round(direction)))
			changed.append("elemental_weapon_damage_scaling")
		"weapon_damage_scales_with_20_percent_engineering":
			p.engineering_weapon_damage_scaling_sources = max(0, p.engineering_weapon_damage_scaling_sources + int(round(direction)))
			changed.append("engineering_weapon_damage_scaling")
		"attack_speed_percent_plus_1_every_second_until_wave_end_lost_on_damage":
			p.crystal_attack_speed_sources = max(0, p.crystal_attack_speed_sources + int(round(direction)))
			if p.crystal_attack_speed_sources == 0 and p.has_method("reset_crystal_attack_speed_bonus"):
				p.reset_crystal_attack_speed_bonus()
			changed.append("crystal_attack_speed")
		"attack_speed_percent_plus_1_per_living_enemy":
			p.living_enemy_attack_speed_sources = max(0, p.living_enemy_attack_speed_sources + int(round(direction)))
			if p.living_enemy_attack_speed_sources == 0 and p.has_method("reset_living_enemy_attack_speed_bonus"):
				p.reset_living_enemy_attack_speed_bonus()
			elif p.has_method("recalculate_living_enemy_attack_speed"):
				p.recalculate_living_enemy_attack_speed()
			changed.append("living_enemy_attack_speed")
		"hp_regeneration_plus_1_per_currently_burning_enemy":
			p.burning_enemy_hp_regen_sources = max(0, p.burning_enemy_hp_regen_sources + int(round(direction)))
			if p.burning_enemy_hp_regen_sources == 0 and p.has_method("reset_burning_enemy_hp_regen_bonus"):
				p.reset_burning_enemy_hp_regen_bonus()
			elif p.has_method("recalculate_burning_enemy_hp_regen"):
				p.recalculate_burning_enemy_hp_regen()
			changed.append("burning_enemy_hp_regen")
		"damage_percent_plus_1_per_10_permanent_luck":
			p.luck_scaling_damage_sources = max(0, p.luck_scaling_damage_sources + int(round(direction)))
			if p.luck_scaling_damage_sources == 0 and p.has_method("reset_luck_scaling_damage_bonus"):
				p.reset_luck_scaling_damage_bonus()
			elif p.has_method("recalculate_luck_scaling_damage"):
				p.recalculate_luck_scaling_damage()
			changed.append("luck_scaling_damage")
		"extra_pearl_chance_in_crate":
			p.extra_pearl_crate_chance = max(0.0, p.extra_pearl_crate_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("extra_pearl_crate_chance")
		"weapon_minimum_cooldown_0_75_seconds":
			p.weapon_minimum_cooldown_sources = max(0, p.weapon_minimum_cooldown_sources + int(round(direction)))
			p.weapon_minimum_cooldown = 0.75 if p.weapon_minimum_cooldown_sources > 0 else 0.0
			changed.append("weapon_minimum_cooldown")
		"projectiles_gain_1_piercing_on_critical_hit":
			p.critical_hit_projectile_pierce_bonus = max(0, p.critical_hit_projectile_pierce_bonus + int(round(direction)))
			changed.append("critical_hit_projectile_pierce")
		"projectiles_bounce_plus_1":
			p.projectile_bounce_bonus = max(0, p.projectile_bounce_bonus + int(round(direction)))
			changed.append("projectile_bounce_bonus")
		"every_ranged_weapon_fifth_projectile_has_plus_3_projectiles":
			p.seashell_projectile_sources = max(0, p.seashell_projectile_sources + int(round(direction)))
			if p.seashell_projectile_sources == 0:
				p.seashell_ranged_shot_counter = 0
			changed.append("seashell_projectiles")
		"restore_5_hp_per_second_cannot_heal_other_way":
			p.torture_healing_sources = max(0, p.torture_healing_sources + int(round(direction)))
			if p.torture_healing_sources == 0:
				p.torture_heal_timer = 0.0
			changed.append("torture_healing")
		"consumables_heal_over_4_seconds_instead_of_instant":
			p.delayed_consumable_heal_sources = max(0, p.delayed_consumable_heal_sources + int(round(direction)))
			if p.delayed_consumable_heal_sources == 0 and p.has_method("reset_delayed_consumable_healing"):
				p.reset_delayed_consumable_healing()
			changed.append("delayed_consumable_heal")
		"weapons_can_no_longer_be_upgraded_or_recycled":
			p.weapon_upgrade_locked_sources = max(0, p.weapon_upgrade_locked_sources + int(round(direction)))
			changed.append("weapon_upgrade_lock")
		"items_one_tier_higher_after_next_reroll":
			p.shop_next_reroll_tier_bonus_pending = max(0, p.shop_next_reroll_tier_bonus_pending + int(round(direction)))
			changed.append("shop_next_reroll_tier_bonus")
		"shop_reroll_damage_percent_plus_1_chance":
			p.shop_reroll_damage_gain_chance = max(0.0, p.shop_reroll_damage_gain_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("shop_reroll_damage_gain_chance")
		"shop_reroll_max_hp_minus_1_chance":
			p.shop_reroll_max_hp_loss_chance = max(0.0, p.shop_reroll_max_hp_loss_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("shop_reroll_max_hp_loss_chance")
		"swap_highest_and_lowest_positive_primary_stats_on_pickup":
			if direction > 0.0 and p.has_method("apply_axolotl_primary_stat_swap"):
				p.apply_axolotl_primary_stat_swap()
			changed.append("primary_stat_swap")
		"upgrade_random_weapon_entering_shop_or_gain_2_armor":
			p.shop_entry_weapon_upgrade_sources = max(0, p.shop_entry_weapon_upgrade_sources + int(round(direction)))
			changed.append("shop_entry_weapon_upgrade")
		"more_trees_spawn":
			p.tree_spawn_bonus_sources = max(0, p.tree_spawn_bonus_sources + int(round(direction)))
			changed.append("tree_spawn_bonus")
		"trees_die_in_one_hit":
			p.trees_die_in_one_hit_sources = max(0, p.trees_die_in_one_hit_sources + int(round(direction)))
			changed.append("trees_die_in_one_hit")
		"enemies_have_higher_fruit_drop_chance":
			p.fruit_drop_chance_bonus = max(0.0, p.fruit_drop_chance_bonus + float(effect.get("chance", 0.10)) * direction)
			changed.append("fruit_drop_chance_bonus")
		"spawn_garden_creates_fruit_every_15_seconds":
			p.garden_spawn_sources = max(0, p.garden_spawn_sources + int(round(direction)))
			changed.append("garden_spawn")
		"spawn_turret_each_wave":
			p.catalog_turret_sources = max(0, p.catalog_turret_sources + int(round(direction)))
			if direction > 0.0:
				p.catalog_turret_base_damage = float(effect.get("damage", p.catalog_turret_base_damage))
				p.catalog_turret_engineering_coefficient = float(effect.get("engineering_damage_coefficient", p.catalog_turret_engineering_coefficient))
				p.catalog_turret_range = float(effect.get("range", p.catalog_turret_range))
				p.catalog_turret_cooldown = float(effect.get("cooldown", p.catalog_turret_cooldown))
			changed.append("catalog_turret_spawn")
		"spawn_landmine_every_12_seconds":
			p.landmine_spawn_sources = max(0, p.landmine_spawn_sources + int(round(direction)))
			if direction > 0.0:
				p.landmine_base_damage = float(effect.get("damage", p.landmine_base_damage))
				p.landmine_engineering_coefficient = float(effect.get("engineering_damage_coefficient", p.landmine_engineering_coefficient))
			changed.append("landmine_spawn")
		"structures_can_crit":
			p.structures_can_crit_sources = max(0, p.structures_can_crit_sources + int(round(direction)))
			changed.append("structures_can_crit")
		"killing_tree_spawns_turret":
			p.pocket_factory_sources = max(0, p.pocket_factory_sources + int(round(direction)))
			changed.append("pocket_factory")
		"unique_builders_turret":
			p.builders_turret_sources = max(0, p.builders_turret_sources + int(round(direction)))
			changed.append("builders_turret")
		"knock_nearby_enemies_back_every_3_seconds":
			p.periodic_knockback_sources = max(0, p.periodic_knockback_sources + int(round(direction)))
			if p.periodic_knockback_sources == 0:
				p.periodic_knockback_timer = 0.0
			changed.append("periodic_knockback")
		"spawn_tyler":
			p.tyler_sources = max(0, p.tyler_sources + int(round(direction)))
			if direction > 0.0:
				p.tyler_projectiles = int(effect.get("projectiles", p.tyler_projectiles))
				p.tyler_base_damage = float(effect.get("damage", p.tyler_base_damage))
				p.tyler_engineering_coefficient = float(effect.get("engineering_damage_coefficient", p.tyler_engineering_coefficient))
				p.tyler_elemental_coefficient = float(effect.get("elemental_damage_coefficient", p.tyler_elemental_coefficient))
			changed.append("tyler_spawn")
		"spawn_wandering_bot_that_slows_nearby_enemies":
			p.wandering_bot_sources = max(0, p.wandering_bot_sources + int(round(direction)))
			changed.append("wandering_bot_spawn")
		"spawn_explosive_turret":
			p.explosive_turret_sources = max(0, p.explosive_turret_sources + int(round(direction)))
			if direction > 0.0:
				p.explosive_turret_base_damage = float(effect.get("damage", p.explosive_turret_base_damage))
				p.explosive_turret_engineering_coefficient = float(effect.get("engineering_damage_coefficient", p.explosive_turret_engineering_coefficient))
			changed.append("explosive_turret_spawn")
		"spawn_incendiary_turret":
			p.incendiary_turret_sources = max(0, p.incendiary_turret_sources + int(round(direction)))
			if direction > 0.0:
				p.incendiary_turret_base_damage = float(effect.get("damage", p.incendiary_turret_base_damage))
				p.incendiary_turret_hit_count = int(effect.get("hit_count", p.incendiary_turret_hit_count))
				p.incendiary_turret_engineering_coefficient = float(effect.get("engineering_damage_coefficient", p.incendiary_turret_engineering_coefficient))
			changed.append("incendiary_turret_spawn")
		"spawn_laser_turret":
			p.laser_turret_sources = max(0, p.laser_turret_sources + int(round(direction)))
			if direction > 0.0:
				p.laser_turret_base_damage = float(effect.get("damage", p.laser_turret_base_damage))
				p.laser_turret_engineering_coefficient = float(effect.get("engineering_damage_coefficient", p.laser_turret_engineering_coefficient))
			changed.append("laser_turret_spawn")
		"spawn_medical_turret":
			p.medical_turret_sources = max(0, p.medical_turret_sources + int(round(direction)))
			if direction > 0.0:
				p.medical_turret_base_healing = float(effect.get("healing", p.medical_turret_base_healing))
				p.medical_turret_engineering_heal_coefficient = float(effect.get("engineering_heal_coefficient", p.medical_turret_engineering_heal_coefficient))
			changed.append("medical_turret_spawn")
		"max_hp_plus_1_per_80_materials":
			p.material_scaling_max_hp_sources = max(0, p.material_scaling_max_hp_sources + int(round(direction)))
			if p.has_method("recalculate_material_scaling_max_hp"):
				p.recalculate_material_scaling_max_hp()
			changed.append("material_scaling_max_hp")
		"damage_percent_minus_2_when_hit_until_wave_end":
			p.damage_loss_on_hit_sources = max(0, p.damage_loss_on_hit_sources + int(round(direction)))
			if p.damage_loss_on_hit_sources == 0 and p.has_method("reset_damage_loss_on_hit_bonus"):
				p.reset_damage_loss_on_hit_bonus()
			changed.append("damage_loss_on_hit")
		"damage_percent_plus_1_per_1_knockback":
			p.knockback_scaling_damage_sources = max(0, p.knockback_scaling_damage_sources + int(round(direction)))
			if p.has_method("recalculate_knockback_scaling_damage"):
				p.recalculate_knockback_scaling_damage()
			changed.append("knockback_scaling_damage")
		"damage_percent_plus_1_per_1_permanent_speed_percent":
			p.speed_scaling_damage_sources = max(0, p.speed_scaling_damage_sources + int(round(direction)))
			if p.has_method("recalculate_speed_scaling_damage"):
				p.recalculate_speed_scaling_damage()
			changed.append("speed_scaling_damage")
		"attack_speed_percent_plus_2_per_1_dodge_percent":
			p.dodge_scaling_attack_speed_sources = max(0, p.dodge_scaling_attack_speed_sources + int(round(direction)))
			if p.has_method("recalculate_dodge_scaling_attack_speed"):
				p.recalculate_dodge_scaling_attack_speed()
			changed.append("dodge_scaling_attack_speed")
		"max_hp_plus_1_per_1_permanent_armor":
			p.armor_scaling_max_hp_sources = max(0, p.armor_scaling_max_hp_sources + int(round(direction)))
			if p.has_method("recalculate_armor_scaling_max_hp"):
				p.recalculate_armor_scaling_max_hp()
			changed.append("armor_scaling_max_hp")
		"engineering_plus_1_per_1_permanent_elemental_damage":
			p.elemental_scaling_engineering_sources = max(0, p.elemental_scaling_engineering_sources + int(round(direction)))
			if p.has_method("recalculate_elemental_scaling_engineering"):
				p.recalculate_elemental_scaling_engineering()
			changed.append("elemental_scaling_engineering")
		"weapon_damage_additionally_scales_with_35_percent_curse":
			p.curse_weapon_damage_scaling_coefficient = max(0.0, p.curse_weapon_damage_scaling_coefficient + 0.35 * direction)
			changed.append("curse_weapon_damage_scaling")
		"damage_percent_plus_3_end_wave":
			p.end_wave_damage_percent_sources = max(0, p.end_wave_damage_percent_sources + int(round(direction)))
			changed.append("end_wave_damage_percent")
		"max_hp_plus_3_end_wave":
			p.end_wave_max_hp_gain_sources = max(0, p.end_wave_max_hp_gain_sources + int(round(direction)))
			changed.append("end_wave_max_hp_gain")
		"hp_regeneration_plus_1_end_wave":
			p.end_wave_hp_regen_gain_sources = max(0, p.end_wave_hp_regen_gain_sources + int(round(direction)))
			changed.append("end_wave_hp_regen_gain")
		"lifesteal_plus_1_percent_end_wave":
			p.end_wave_lifesteal_gain_sources = max(0, p.end_wave_lifesteal_gain_sources + int(round(direction)))
			changed.append("end_wave_lifesteal_gain")
		"melee_damage_plus_3_end_wave":
			p.end_wave_melee_damage_gain_sources = max(0, p.end_wave_melee_damage_gain_sources + int(round(direction)))
			changed.append("end_wave_melee_damage_gain")
		"engineering_plus_3_end_wave":
			p.end_wave_engineering_gain_sources = max(0, p.end_wave_engineering_gain_sources + int(round(direction)))
			changed.append("end_wave_engineering_gain")
		"max_hp_minus_1_end_wave":
			p.end_wave_max_hp_loss_sources = max(0, p.end_wave_max_hp_loss_sources + int(round(direction)))
			changed.append("end_wave_max_hp_loss")
		"armor_minus_1_end_wave":
			p.end_wave_armor_loss_sources = max(0, p.end_wave_armor_loss_sources + int(round(direction)))
			changed.append("end_wave_armor_loss")
		"range_minus_10_end_wave":
			p.end_wave_range_delta += int(round(-10.0 * direction))
			changed.append("end_wave_range_delta")
		"xp_gain_minus_5_percent_end_wave":
			p.end_wave_xp_gain_percent += -0.05 * direction
			changed.append("end_wave_xp_gain_percent")
		"hp_regeneration_plus_1_on_level_up":
			p.level_up_hp_regen_gain_sources = max(0, p.level_up_hp_regen_gain_sources + int(round(direction)))
			changed.append("level_up_hp_regen_gain")
		"lifesteal_plus_1_percent_and_max_hp_minus_1_on_level_up":
			p.level_up_lifesteal_gain_sources = max(0, p.level_up_lifesteal_gain_sources + int(round(direction)))
			p.level_up_max_hp_loss_sources = max(0, p.level_up_max_hp_loss_sources + int(round(direction)))
			changed.append("level_up_lifesteal_max_hp")
		"level_upgrade_stats_plus_35_percent":
			p.level_upgrade_stat_percent_bonus = max(0.0, p.level_upgrade_stat_percent_bonus + 0.35 * direction)
			changed.append("level_upgrade_stat_percent_bonus")
		"gain_stats_on_level_up":
			_apply_catalog_level_up_stat_deltas(effect, direction)
			changed.append("level_up_catalog_stat_deltas")
		"curse_plus_1_on_level_up":
			p.level_up_curse_gain_sources = max(0, p.level_up_curse_gain_sources + int(round(direction)))
			changed.append("level_up_curse_gain")
		"max_1_weapon":
			p.max_one_weapon_sources = max(0, p.max_one_weapon_sources + int(round(direction)))
			if p.has_method("recalculate_max_weapon_slots"):
				p.recalculate_max_weapon_slots()
			changed.append("max_weapon_slots")
		"decrease_current_wave_count_by_1":
			if direction > 0.0 and p.has_method("decrease_current_wave_count"):
				p.decrease_current_wave_count(1)
			changed.append("decrease_current_wave_count")
		"piercing_damage_cannot_exceed_base_damage":
			var delta = int(round(direction))
			p.piercing_damage_cap_sources = max(0, p.piercing_damage_cap_sources + delta)
			p.piercing_damage_cap_at_base = p.piercing_damage_cap_sources > 0
			changed.append("piercing_damage_cap")
		"material_drop_instant_attract_chance":
			p.material_drop_instant_attract_chance = max(0.0, p.material_drop_instant_attract_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("material_drop_instant_attract")
		"material_pickup_luck_damage_chance":
			p.material_pickup_luck_damage_chance = max(0.0, p.material_pickup_luck_damage_chance + float(effect.get("chance", 0.0)) * direction)
			p.material_pickup_luck_damage_sources = max(0, p.material_pickup_luck_damage_sources + int(round(direction)))
			if direction > 0.0:
				p.material_pickup_luck_damage_base = max(p.material_pickup_luck_damage_base, float(effect.get("damage", 0.0)))
				p.material_pickup_luck_damage_coefficient = max(p.material_pickup_luck_damage_coefficient, float(effect.get("luck_damage_coefficient", 0.0)))
			elif p.material_pickup_luck_damage_sources == 0:
				p.material_pickup_luck_damage_base = 0.0
				p.material_pickup_luck_damage_coefficient = 0.0
			changed.append("material_pickup_luck_damage")
		"enemy_death_luck_damage_chance":
			p.enemy_death_luck_damage_chance = max(0.0, p.enemy_death_luck_damage_chance + float(effect.get("chance", 0.0)) * direction)
			p.enemy_death_luck_damage_sources = max(0, p.enemy_death_luck_damage_sources + int(round(direction)))
			if direction > 0.0:
				p.enemy_death_luck_damage_base = max(p.enemy_death_luck_damage_base, float(effect.get("damage", 0.0)))
				p.enemy_death_luck_damage_coefficient = max(p.enemy_death_luck_damage_coefficient, float(effect.get("luck_damage_coefficient", 0.0)))
			elif p.enemy_death_luck_damage_sources == 0:
				p.enemy_death_luck_damage_base = 0.0
				p.enemy_death_luck_damage_coefficient = 0.0
			changed.append("enemy_death_luck_damage")
		"heal_1_hp_on_enemy_kill_chance":
			p.enemy_kill_heal_chance = max(0.0, p.enemy_kill_heal_chance + float(effect.get("chance", 0.0)) * direction)
			changed.append("enemy_kill_heal_chance")
		"dodge_cap_70_percent":
			p.dodge_cap_sources = max(0, p.dodge_cap_sources + int(round(direction)))
			if p.has_method("recalculate_dodge_cap"):
				p.recalculate_dodge_cap()
			else:
				p.dodge_cap = 0.70 if p.dodge_cap_sources > 0 else 0.90
				p.dodge_chance = min(p.dodge_chance, p.dodge_cap)
			changed.append("dodge_cap")
		"dodge_cap_20_percent":
			p.dodge_cap_20_sources = max(0, p.dodge_cap_20_sources + int(round(direction)))
			if p.has_method("recalculate_dodge_cap"):
				p.recalculate_dodge_cap()
			else:
				p.dodge_cap = 0.20 if p.dodge_cap_20_sources > 0 else 0.90
				p.dodge_chance = min(p.dodge_chance, p.dodge_cap)
			changed.append("dodge_cap")
		"burn_on_hit":
			p.burn_on_hit_chance = max(0.0, p.burn_on_hit_chance + float(effect.get("chance", 0.25)) * direction)
			changed.append("burn_on_hit_chance")
		"burn_spread":
			p.burn_spread_sources = max(0, p.burn_spread_sources + int(round(direction)))
			changed.append("burn_spread")
		"enemy_death_explosion_chance":
			p.enemy_death_explosion_chance = max(0.0, p.enemy_death_explosion_chance + float(effect.get("chance", 0.0)) * direction)
			p.enemy_death_explosion_sources = max(0, p.enemy_death_explosion_sources + int(round(direction)))
			if direction > 0.0:
				p.enemy_death_explosion_base = max(p.enemy_death_explosion_base, float(effect.get("damage", 0.0)))
				p.enemy_death_explosion_melee_coefficient = max(p.enemy_death_explosion_melee_coefficient, float(effect.get("melee_damage_coefficient", 0.0)))
				p.enemy_death_explosion_radius = max(p.enemy_death_explosion_radius, float(effect.get("radius", p.enemy_death_explosion_radius)))
			elif p.enemy_death_explosion_sources == 0:
				p.enemy_death_explosion_base = 0.0
				p.enemy_death_explosion_melee_coefficient = 0.0
			changed.append("enemy_death_explosion")
		"consumable_explosion_chance":
			p.spicy_sauce_explosion_chance = max(0.0, p.spicy_sauce_explosion_chance + float(effect.get("chance", 0.50)) * direction)
			p.spicy_sauce_explosion_sources = max(0, p.spicy_sauce_explosion_sources + int(round(direction)))
			if direction > 0.0:
				p.spicy_sauce_explosion_base = max(p.spicy_sauce_explosion_base, float(effect.get("damage", 10.0)))
				p.spicy_sauce_explosion_max_hp_coefficient = max(p.spicy_sauce_explosion_max_hp_coefficient, float(effect.get("max_hp_damage_coefficient", 1.0)))
				p.spicy_sauce_explosion_radius = max(p.spicy_sauce_explosion_radius, float(effect.get("radius", p.spicy_sauce_explosion_radius)))
			elif p.spicy_sauce_explosion_sources == 0:
				p.spicy_sauce_explosion_base = 0.0
				p.spicy_sauce_explosion_max_hp_coefficient = 0.0
				p.spicy_sauce_explosion_radius = 200.0
			changed.append("spicy_sauce_explosion")
		"deal_melee_damage_on_dodge":
			p.dodge_damage_chance = max(0.0, p.dodge_damage_chance + float(effect.get("chance", 0.0)) * direction)
			p.dodge_damage_sources = max(0, p.dodge_damage_sources + int(round(direction)))
			if direction > 0.0:
				p.dodge_damage_base = max(p.dodge_damage_base, float(effect.get("damage", 0.0)))
				p.dodge_damage_melee_coefficient = max(p.dodge_damage_melee_coefficient, float(effect.get("melee_damage_coefficient", 0.0)))
			elif p.dodge_damage_sources == 0:
				p.dodge_damage_base = 0.0
				p.dodge_damage_melee_coefficient = 0.0
			changed.append("dodge_damage")
		"critical_hits_deal_current_hp_bonus_damage":
			p.critical_current_hp_bonus_sources = max(0, p.critical_current_hp_bonus_sources + int(round(direction)))
			if direction > 0.0:
				p.critical_current_hp_bonus_enemy_percent = max(p.critical_current_hp_bonus_enemy_percent, float(effect.get("enemy_current_hp_percent", 0.0)))
				p.critical_current_hp_bonus_boss_elite_percent = max(p.critical_current_hp_bonus_boss_elite_percent, float(effect.get("boss_elite_current_hp_percent", 0.0)))
			elif p.critical_current_hp_bonus_sources == 0:
				p.critical_current_hp_bonus_enemy_percent = 0.0
				p.critical_current_hp_bonus_boss_elite_percent = 0.0
			changed.append("critical_current_hp_bonus")
		"luck_plus_2_per_1_crit_chance_percent":
			p.crit_scaling_luck_sources = max(0, p.crit_scaling_luck_sources + int(round(direction)))
			if direction > 0.0:
				p.crit_scaling_luck_per_percent = max(p.crit_scaling_luck_per_percent, float(effect.get("luck_per_crit_percent", 2.0)))
			elif p.crit_scaling_luck_sources == 0:
				p.crit_scaling_luck_per_percent = 0.0
			if p.has_method("recalculate_crit_scaling_luck"):
				p.recalculate_crit_scaling_luck()
			changed.append("crit_scaling_luck")
		"damage_percent_plus_5_every_5_seconds_until_wave_end":
			p.wisdom_damage_sources = max(0, p.wisdom_damage_sources + int(round(direction)))
			if p.wisdom_damage_sources == 0 and p.has_method("reset_wisdom_damage_bonus"):
				p.reset_wisdom_damage_bonus()
			changed.append("wisdom_damage")
		"hp_regeneration_doubled_below_50_percent_health":
			p.low_health_regen_double_sources = max(0, p.low_health_regen_double_sources + int(round(direction)))
			changed.append("low_health_regen_double")
		"max_hp_plus_1_on_consumable_pickup_at_full_health_max_8_per_wave":
			p.full_health_consumable_max_hp_gain_sources = max(0, p.full_health_consumable_max_hp_gain_sources + int(round(direction)))
			p.full_health_consumable_max_hp_gain_cap_per_wave = 8 if p.full_health_consumable_max_hp_gain_sources > 0 else 0
			p.full_health_consumable_max_hp_gained_this_wave = min(p.full_health_consumable_max_hp_gained_this_wave, p.full_health_consumable_max_hp_gain_cap_per_wave)
			changed.append("full_health_consumable_max_hp_gain")
		"hp_regeneration_plus_2_every_5_seconds_until_wave_end":
			p.medikit_hp_regen_sources = max(0, p.medikit_hp_regen_sources + int(round(direction)))
			if p.medikit_hp_regen_sources == 0 and p.has_method("reset_medikit_hp_regen_bonus"):
				p.reset_medikit_hp_regen_bonus()
			changed.append("medikit_hp_regen")
		"temporary_hp_regeneration_plus_1_on_full_health_consumable_pickup":
			p.full_health_consumable_temp_hp_regen_sources = max(0, p.full_health_consumable_temp_hp_regen_sources + int(round(direction)))
			if p.full_health_consumable_temp_hp_regen_sources == 0 and p.has_method("reset_full_health_consumable_temp_hp_regen_bonus"):
				p.reset_full_health_consumable_temp_hp_regen_bonus()
			changed.append("full_health_consumable_temp_hp_regen")
	return changed

func _record_catalog_stat_delta(stat: String, delta: float):
	p.catalog_stat_modifiers[stat] = float(p.catalog_stat_modifiers.get(stat, 0.0)) + delta
	if is_equal_approx(float(p.catalog_stat_modifiers.get(stat, 0.0)), 0.0):
		p.catalog_stat_modifiers.erase(stat)

func _record_catalog_actual_stat_delta(stat: String, delta: float):
	p.catalog_stat_actual_modifiers[stat] = float(p.catalog_stat_actual_modifiers.get(stat, 0.0)) + delta
	if is_equal_approx(float(p.catalog_stat_actual_modifiers.get(stat, 0.0)), 0.0):
		p.catalog_stat_actual_modifiers.erase(stat)

func _record_catalog_suppressed_stat_delta(stat: String, delta: float, source_id: String = ""):
	if delta <= 0.0:
		return
	p.catalog_stat_suppressed_modifiers[stat] = float(p.catalog_stat_suppressed_modifiers.get(stat, 0.0)) + delta
	if source_id == "" or p.get("catalog_stat_suppressed_modifiers_by_source") == null:
		return
	var source_modifiers: Dictionary = p.catalog_stat_suppressed_modifiers_by_source.get(source_id, {})
	source_modifiers[stat] = float(source_modifiers.get(stat, 0.0)) + delta
	p.catalog_stat_suppressed_modifiers_by_source[source_id] = source_modifiers

func _consume_catalog_suppressed_stat_delta(stat: String, requested_abs_delta: float, source_id: String = "") -> float:
	var suppressed = _get_catalog_suppressed_stat_delta(stat, source_id)
	if suppressed <= 0.0 or requested_abs_delta <= 0.0:
		return 0.0
	var consumed = min(requested_abs_delta, suppressed)
	var remaining = suppressed - consumed
	if source_id != "" and p.get("catalog_stat_suppressed_modifiers_by_source") != null and p.catalog_stat_suppressed_modifiers_by_source.has(source_id):
		var source_modifiers: Dictionary = p.catalog_stat_suppressed_modifiers_by_source[source_id]
		if is_equal_approx(remaining, 0.0):
			source_modifiers.erase(stat)
		else:
			source_modifiers[stat] = remaining
		if source_modifiers.is_empty():
			p.catalog_stat_suppressed_modifiers_by_source.erase(source_id)
		else:
			p.catalog_stat_suppressed_modifiers_by_source[source_id] = source_modifiers
		_decrease_catalog_suppressed_stat_total(stat, consumed)
		return consumed
	if is_equal_approx(remaining, 0.0):
		p.catalog_stat_suppressed_modifiers.erase(stat)
	else:
		p.catalog_stat_suppressed_modifiers[stat] = remaining
	return consumed

func _get_catalog_suppressed_stat_delta(stat: String, source_id: String = "") -> float:
	if source_id != "":
		if p.get("catalog_stat_suppressed_modifiers_by_source") != null and p.catalog_stat_suppressed_modifiers_by_source.has(source_id):
			var source_modifiers: Dictionary = p.catalog_stat_suppressed_modifiers_by_source[source_id]
			return max(0.0, float(source_modifiers.get(stat, 0.0)))
		return 0.0
	return max(0.0, float(p.catalog_stat_suppressed_modifiers.get(stat, 0.0)))

func _decrease_catalog_suppressed_stat_total(stat: String, consumed: float):
	if consumed <= 0.0:
		return
	var total = max(0.0, float(p.catalog_stat_suppressed_modifiers.get(stat, 0.0)))
	var remaining = max(0.0, total - consumed)
	if is_equal_approx(remaining, 0.0):
		p.catalog_stat_suppressed_modifiers.erase(stat)
	else:
		p.catalog_stat_suppressed_modifiers[stat] = remaining

func _resolve_catalog_max_hp_delta(delta: int, direction: float, source_id: String = "") -> int:
	if direction < 0.0 and delta < 0:
		var requested_abs = abs(delta)
		var suppressed_consumed = int(round(_consume_catalog_suppressed_stat_delta("max_hp", float(requested_abs), source_id)))
		var remaining_abs = requested_abs - suppressed_consumed
		if remaining_abs <= 0:
			return 0
		if p.max_hp_cap_sources <= 0:
			return -remaining_abs
		var actual_positive = max(0, int(round(float(p.catalog_stat_actual_modifiers.get("max_hp", 0.0)))))
		return -min(remaining_abs, actual_positive)
	return delta

func _resolve_catalog_speed_percent_delta(delta: float, direction: float, source_id: String = "") -> float:
	if direction < 0.0 and delta < 0.0:
		var requested_abs = abs(delta)
		var suppressed_consumed = _consume_catalog_suppressed_stat_delta("speed_percent", requested_abs, source_id)
		var remaining_abs = requested_abs - suppressed_consumed
		if remaining_abs <= 0.0 or is_equal_approx(remaining_abs, 0.0):
			return 0.0
		if p.speed_cap_sources <= 0:
			return -remaining_abs
		var actual_positive = max(0.0, float(p.catalog_stat_actual_modifiers.get("speed_percent", 0.0)))
		return -min(remaining_abs, actual_positive)
	return delta

func _apply_passive_effect(upgrade) -> Array:
	var effect = upgrade.get("effect", "")
	var value = upgrade.get("value", 0)
	var changed: Array = []
	match effect:
		"burn_chance":
			p.burn_chance = min(p.burn_chance + value, 0.8)
			changed.append("burn_chance")
		"freeze_chance":
			p.freeze_chance = min(p.freeze_chance + value, 0.6)
			changed.append("freeze_chance")
		"chain_lightning":   p.chain_lightning = true
		"explosive_bullet":  pass
		"piercing":          pass
		"double_shot":       p.fire_rate_multiplier += value * 0.5
		"gold_magnet":       p.magnet_range += 500
		"xp_boost":          p.xp_boost += value
		"gold_interest":     p.gold_interest += value
		"shield":
			p.max_shield += int(value)
			p.shield = min(p.shield + int(value), p.max_shield)
		"thorns":            p.thorns += value
		"revenge":
			p.revenge_bonus = true
			changed.append("revenge")
		"time_slow":         pass
		"blood_sacrifice":
			p.hp -= int(value)
			p.damage_bonus += 3
			p.hp_changed.emit(p.hp, p.max_hp)
			changed.append("damage_bonus")
		"adrenaline":
			p.adrenaline = true
			changed.append("adrenaline")
		"iron_will":         p.steel_will = true
		"chain_explosion":   pass
		"time_capsule":      pass
		"auto_repair":       p.hp_regen += value
		"gravity_well":      pass
		"war_machine":       p.war_machine_enabled = true
		"fanatic":           pass
		"first_aid":         pass
	return changed

# 定位「出售武器」应当移除的那一格，返回下标；找不到返回 -1。
#
# 为什么不能只按 type 匹配：玩家可能同时持有同类型的多把不同分阶武器（SMG T1 + SMG T2）。
# 旧实现只比 type，会移除先遍历到的那把 —— 卖 T2 结果把 T1 卖掉了。
#
# 判据优先级（越靠前越精确）：
#   1. slot_index —— 购买时记录的具体格子，天然处理 tier 无法唯一确定的情况；
#   2. type 相等且（若给了 tier）tier 相等；
#   3. 都不足以定位时（仅给 type），退回「第一个同类型」的旧行为，保持向后兼容。
#
# tier 的唯一权威是 weapon.get("tier", weapon.get("level", 1))，与 PlayerCombat 的既有写法一致。
func _find_weapon_slot_to_remove(upgrade) -> int:
	var size = p.equipped_weapons.size()
	var slot_index = upgrade.get("slot_index", -1)
	if slot_index != null and int(slot_index) >= 0 and int(slot_index) < size:
		# 索引是精确判据，但底层数组可能已被合成/卸下改变，校验一下它仍指向目标武器再采用。
		var wanted = str(upgrade.get("weapon_type", ""))
		if wanted == "" or str(p.equipped_weapons[int(slot_index)].type) == wanted:
			return int(slot_index)
		# 索引越界或已指向别的武器 → 安全降级到按 type(+tier) 查找，不崩。
	var wanted_type = str(upgrade.get("weapon_type", ""))
	var has_tier = upgrade.has("tier")
	var wanted_tier = 0
	if has_tier:
		wanted_tier = int(upgrade.get("tier", 1))
	for i in range(size):
		var weapon = p.equipped_weapons[i]
		if str(weapon.type) != wanted_type:
			continue
		if has_tier and int(weapon.get("tier", weapon.get("level", 1))) != wanted_tier:
			continue
		return i
	return -1

func remove_upgrade(upgrade):
	var effect = upgrade.get("effect", "")
	var value = upgrade.get("value", 0)
	var up_type = upgrade.get("type", "")
	if up_type == "weapon":
		var index = _find_weapon_slot_to_remove(upgrade)
		if index != -1:
			if p.combat.has_method("_on_weapon_removed"):
				p.combat._on_weapon_removed(p.equipped_weapons[index])
			p.equipped_weapons.remove_at(index)
			p.combat.emit_weapons_changed()
		return
	match up_type:
		"speed":
			p.speed = max(100, p.speed - value)
			p.base_speed = p.speed
			return
		"fire_rate":
			p.fire_rate_multiplier = max(0.1, p.fire_rate_multiplier - value)
			return
		"damage":
			p.damage_bonus = max(0, p.damage_bonus - value)
			return
		"hp":
			p.max_hp = max(1, p.max_hp - value)
			p.hp = min(p.hp, p.max_hp)
			p.hp_changed.emit(p.hp, p.max_hp)
			return
		"armor":
			p.armor = max(0, p.armor - value)
			return
		"crit_chance":
			p.crit_chance = max(0, p.crit_chance - value)
			return
		"crit_damage":
			p.crit_damage = max(1.0, p.crit_damage - value)
			p.crit_chance = max(0, p.crit_chance - upgrade.get("crit_chance_bonus", 0.0))
			return
		"lifesteal":
			p.lifesteal = max(0, p.lifesteal - value)
			if p.has_method("recalculate_lifesteal_scaling_damage"):
				p.recalculate_lifesteal_scaling_damage()
			return
		"luck":
			p.luck = max(0, p.luck - value)
			return
		"magnet":
			p.magnet_range = max(50, p.magnet_range - value)
			return
		"hp_regen":
			p.hp_regen = max(0, p.hp_regen - value)
			return
		"hp_armor":
			p.armor = max(0, p.armor - upgrade.get("armor_val", 0))
			p.max_hp = max(1, p.max_hp - upgrade.get("hp_val", 0))
			p.hp = min(p.hp, p.max_hp)
			p.hp_changed.emit(p.hp, p.max_hp)
			return
		"catalog_item":
			check_synergies(_apply_catalog_item_effects(upgrade, -1.0))
			if p.has_method("record_catalog_item_ownership"):
				p.record_catalog_item_ownership(upgrade, -1.0)
			return
	match effect:
		"shield":
			p.max_shield = max(0, p.max_shield - int(value))
			p.shield = min(p.shield, p.max_shield)
			p.shield_changed.emit(p.shield, p.max_shield)
		"xp_boost":
			p.xp_boost = max(1.0, p.xp_boost - value)
		"gold_interest":
			p.gold_interest = max(0, p.gold_interest - value)
		"thorns":
			p.thorns = max(0, p.thorns - value)
		"burn_chance":
			p.burn_chance = max(0, p.burn_chance - value)
		"freeze_chance":
			p.freeze_chance = max(0, p.freeze_chance - value)
		"gold_magnet":
			p.magnet_range = max(50, p.magnet_range - 500)
		"auto_repair":
			p.hp_regen = max(0, p.hp_regen - value)
		"adrenaline":
			p.adrenaline = false
		"revenge":
			p.revenge_bonus = false
		"iron_will":
			p.steel_will = false
		"war_machine":
			p.war_machine_enabled = false
			p.fire_rate_multiplier = max(0.1, p.fire_rate_multiplier - p.war_machine_stacks * 0.03)
			p.war_machine_stacks = 0
	check_synergies()

# ─── 协同效果系统 ───

# 属性 → 协同ID映射，用于增量更新
const STATS_TO_SYNERGIES = {
	"weapons": ["fire_master", "bulletstorm"],
	"burn_chance": ["fire_master"],
	"freeze_chance": ["ice_age"],
	"time_slow": ["ice_age"],
	"revenge": ["glass_cannon", "vampire"],
	"damage_bonus": ["glass_cannon"],
	"armor": ["tank_build"],
	"max_hp": ["tank_build"],
	"lifesteal": ["vampire"],
	"adrenaline": ["speed_demon"],
	"speed": ["speed_demon"],
}

func check_synergies(changed_stats: Array = []):
	var weapon_types = p.equipped_weapons.map(func(w): return w.type)
	var owned_effects: Array = []
	if p.burn_chance > 0: owned_effects.append("burn_chance")
	if p.freeze_chance > 0: owned_effects.append("freeze_chance")
	if p.chain_lightning: owned_effects.append("chain_lightning")
	if p.revenge_bonus: owned_effects.append("revenge")
	if p.adrenaline: owned_effects.append("adrenaline")
	if p.steel_will: owned_effects.append("iron_will")
	if p.war_machine_enabled: owned_effects.append("war_machine")
	if p.thorns > 0: owned_effects.append("thorns")
	if p.gold_interest > 0: owned_effects.append("gold_interest")
	if p.freeze_chance > 0: owned_effects.append("time_slow")

	# 增量更新：只检查受影响的协同
	var synergies_to_check = {}
	if changed_stats.is_empty():
		for syn_id in SYNERGIES:
			synergies_to_check[syn_id] = true
	else:
		for stat in changed_stats:
			if STATS_TO_SYNERGIES.has(stat):
				for syn_id in STATS_TO_SYNERGIES[stat]:
					synergies_to_check[syn_id] = true

	for syn_id in synergies_to_check:
		var syn = SYNERGIES[syn_id]
		var req = syn.requires
		var met = true

		if req.has("weapons"):
			for w in req.weapons:
				if w not in weapon_types:
					met = false
					break

		if met and req.has("weapons_any2"):
			var count = 0
			for w in req.weapons_any2:
				if w in weapon_types:
					count += 1
			if count < 2:
				met = false

		if met and req.has("effects"):
			for e in req.effects:
				if e not in owned_effects:
					met = false
					break

		if met and req.has("min_damage_bonus") and p.damage_bonus < req.min_damage_bonus:
			met = false
		if met and req.has("min_armor") and p.armor < req.min_armor:
			met = false
		if met and req.has("min_max_hp") and p.max_hp < req.min_max_hp:
			met = false
		if met and req.has("min_lifesteal") and p.lifesteal < req.min_lifesteal:
			met = false
		if met and req.has("min_speed") and p.speed < req.min_speed:
			met = false

		if met and syn_id not in p.active_synergies:
			_apply_synergy(syn_id)
		elif not met and syn_id in p.active_synergies:
			_remove_synergy(syn_id)

func _apply_synergy(syn_id: String):
	p.active_synergies.append(syn_id)
	var bonuses = SYNERGIES[syn_id].bonuses
	if bonuses.has("burn_chance"):
		p.burn_chance = min(p.burn_chance + bonuses.burn_chance, 0.8)
	if bonuses.has("speed"):
		p.speed += bonuses.speed
		p.base_speed += bonuses.speed
	if bonuses.has("fire_rate"):
		p.fire_rate_multiplier += bonuses.fire_rate
	if bonuses.has("damage"):
		p.damage_bonus += bonuses.damage
	if bonuses.has("hp_penalty"):
		p.max_hp = max(1, p.max_hp - bonuses.hp_penalty)
		p.hp = min(p.hp, p.max_hp)
		p.hp_changed.emit(p.hp, p.max_hp)
	if bonuses.has("armor"):
		p.armor += bonuses.armor
	if bonuses.has("hp_regen"):
		p.hp_regen += bonuses.hp_regen
	if bonuses.has("lifesteal"):
		p.lifesteal = min(p.lifesteal + bonuses.lifesteal, 0.5)
		if p.has_method("recalculate_lifesteal_scaling_damage"):
			p.recalculate_lifesteal_scaling_damage()
	if bonuses.has("crit_chance"):
		p.crit_chance = min(p.crit_chance + bonuses.crit_chance, 0.8)
	p.synergy_activated.emit(SYNERGIES[syn_id].name)

func _remove_synergy(syn_id: String):
	p.active_synergies.erase(syn_id)
	var bonuses = SYNERGIES[syn_id].bonuses
	if bonuses.has("burn_chance"):
		p.burn_chance = max(0, p.burn_chance - bonuses.burn_chance)
	if bonuses.has("speed"):
		p.speed = max(100, p.speed - bonuses.speed)
		p.base_speed = max(100, p.base_speed - bonuses.speed)
	if bonuses.has("fire_rate"):
		p.fire_rate_multiplier = max(0.1, p.fire_rate_multiplier - bonuses.fire_rate)
	if bonuses.has("damage"):
		p.damage_bonus = max(0, p.damage_bonus - bonuses.damage)
	if bonuses.has("hp_penalty"):
		p.max_hp += bonuses.hp_penalty
		p.hp_changed.emit(p.hp, p.max_hp)
	if bonuses.has("armor"):
		p.armor = max(0, p.armor - bonuses.armor)
	if bonuses.has("hp_regen"):
		p.hp_regen = max(0, p.hp_regen - bonuses.hp_regen)
	if bonuses.has("lifesteal"):
		p.lifesteal = max(0, p.lifesteal - bonuses.lifesteal)
		if p.has_method("recalculate_lifesteal_scaling_damage"):
			p.recalculate_lifesteal_scaling_damage()
	if bonuses.has("crit_chance"):
		p.crit_chance = max(0, p.crit_chance - bonuses.crit_chance)

func get_active_synergies() -> Array:
	var result = []
	for syn_id in p.active_synergies:
		var syn = SYNERGIES[syn_id]
		result.append({"id": syn_id, "name": syn.name, "desc": syn.desc, "color": syn.color})
	return result
