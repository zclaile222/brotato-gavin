extends CharacterBody2D

const MAX_WEAPONS    = 6
const INVINCIBLE_TIME = 0.8
const AXOLOTL_PRIMARY_STATS := [
	"max_hp",
	"hp_regeneration",
	"lifesteal",
	"damage_percent",
	"melee_damage",
	"ranged_damage",
	"elemental_damage",
	"attack_speed_percent",
	"crit_chance",
	"engineering",
	"range",
	"armor",
	"dodge",
	"speed_percent",
	"luck",
	"harvesting",
]
const LEVEL_UP_CATALOG_STAT_KEYS := [
	"max_hp",
	"melee_damage",
	"ranged_damage",
	"elemental_damage",
	"engineering",
]

# 移动 & 生存
var speed       = 300.0
var max_hp      = 5
var hp          = 5
var armor       = 0

# 战斗输出
var damage_bonus         = 0
var damage_percent_bonus = 0.0
var melee_damage_bonus   = 0
var ranged_damage_bonus  = 0
var elemental_damage_bonus = 0
var engineering_bonus    = 0
var fire_rate_multiplier = 1.0
var crit_chance          = 0.0
var crit_damage          = 2.0
var lifesteal            = 0.0

# 辅助
var magnet_range = 160.0
var range_bonus  = 0.0
var knockback_bonus = 0.0
var consumable_heal_bonus = 0
var fruit_drop_chance_bonus = 0.0
var hp_regen     = 0
var luck         = 0
var curse        = 0
var accuracy_percent = 0.0
var item_price_percent = 0.0
var reroll_price_percent = 0.0
var recycling_materials_percent = 0.0
var enemy_health_percent = 0.0
var enemy_damage_percent = 0.0
var boss_elite_damage_percent = 0.0
var enemy_speed_percent = 0.0
var enemies_percent = 0.0
var materials_dropped_percent = 0.0
var loot_alien_chance_percent = 0.0
var loot_alien_speed_percent = 0.0
var crate_material_bonus = 0
var projectile_pierce_bonus = 0
var critical_hit_projectile_pierce_bonus = 0
var piercing_damage_percent = 0.0
var piercing_damage_cap_sources = 0
var piercing_damage_cap_at_base = false
var projectile_bounce_bonus = 0
var seashell_projectile_sources = 0
var seashell_ranged_shot_counter = 0
var alien_eyes_sources = 0
var alien_eyes_timer = 0.0
var alien_eyes_interval = 3.0
var alien_eyes_projectile_count = 6
var alien_eyes_base_damage = 6.0
var alien_eyes_max_hp_damage_coefficient = 0.50
var corpse_bullet_sources = 0
var corpse_bullet_base_damage = 0.0
var corpse_bullet_ranged_damage_coefficient = 0.0
var cursed_enemy_material_bonus_sources = 0
var burning_kill_elemental_damage_sources = 0
var burning_kill_elemental_kill_counter = 0
var burning_kill_elemental_gained_this_wave = 0
var burning_kill_elemental_threshold = 30
var burning_kill_elemental_max_per_wave = 4
var catalog_owned_item_tier_counts: Dictionary = {}
var fairy_tier1_regen_sources = 0
var fairy_tier4_regen_sources = 0
var fairy_item_tier_regen_bonus = 0
var candy_bag_random_stat_sources = 0
var candy_bag_random_stat_value = 8.0
var candy_bag_random_stat_bonus: Dictionary = {}
var additional_elite_chance = 0.0
var locked_shop_entry_curse_chance = 0.0
var mirror_duplicate_next_shop_item_pending = 0
var broken_mirror_duplicated_item_sources = 0
var resting_goldfish_post_use_sources = 0
var crit_kill_heal_chance = 0.0
var crit_kill_material_chance = 0.0
var material_pickup_heal_chance = 0.0
var double_material_pickup_chance = 0.0
var material_drop_instant_attract_chance = 0.0
var material_pickup_luck_damage_chance = 0.0
var material_pickup_luck_damage_sources = 0
var material_pickup_luck_damage_base = 0.0
var material_pickup_luck_damage_coefficient = 0.0
var enemy_death_luck_damage_chance = 0.0
var enemy_death_luck_damage_sources = 0
var enemy_death_luck_damage_base = 0.0
var enemy_death_luck_damage_coefficient = 0.0
var enemy_death_explosion_chance = 0.0
var enemy_death_explosion_sources = 0
var enemy_death_explosion_base = 0.0
var enemy_death_explosion_melee_coefficient = 0.0
var enemy_death_explosion_radius = 200.0
var enemy_kill_heal_chance = 0.0
var burn_on_hit_chance = 0.0
var burn_spread_sources = 0
var burn_spread_radius = 200.0
var burn_tick_interval_percent_modifier = 0.0
var elemental_vulnerability_sources = 0
var elemental_vulnerability_percent = 0.10
var elemental_vulnerability_duration = 3.0
var burn_current_hp_bonus_sources = 0
var burn_current_hp_bonus_enemy_percent = 0.0
var burn_current_hp_bonus_boss_elite_percent = 0.0
var elemental_weapon_damage_scaling_sources = 0
var engineering_weapon_damage_scaling_sources = 0
var curse_weapon_damage_scaling_coefficient = 0.0
var dodge_damage_chance = 0.0
var dodge_damage_sources = 0
var dodge_damage_base = 0.0
var dodge_damage_melee_coefficient = 0.0
var critical_current_hp_bonus_sources = 0
var critical_current_hp_bonus_enemy_percent = 0.0
var critical_current_hp_bonus_boss_elite_percent = 0.0
var crit_scaling_luck_sources = 0
var crit_scaling_luck_per_percent = 0.0
var crit_scaling_luck_bonus = 0
var luck_scaling_damage_sources = 0
var luck_scaling_damage_bonus = 0.0
var wisdom_damage_sources = 0
var wisdom_damage_timer = 0.0
var wisdom_damage_bonus = 0.0
var low_health_regen_double_sources = 0
var full_health_consumable_max_hp_gain_sources = 0
var full_health_consumable_max_hp_gain_cap_per_wave = 0
var full_health_consumable_max_hp_gained_this_wave = 0
var full_health_consumable_temp_hp_regen_sources = 0
var full_health_consumable_temp_hp_regen_bonus = 0
var medikit_hp_regen_sources = 0
var medikit_hp_regen_timer = 0.0
var medikit_hp_regen_bonus = 0
var crystal_attack_speed_sources = 0
var crystal_attack_speed_timer = 0.0
var crystal_attack_speed_bonus = 0.0
var living_enemy_attack_speed_sources = 0
var living_enemy_attack_speed_bonus = 0.0
var burning_enemy_hp_regen_sources = 0
var burning_enemy_hp_regen_bonus = 0
var hit_enemy_slow_percent_per_hit = 0.0
var hit_enemy_slow_percent_max = 0.0
var dodge_heal_chance = 0.0
var dodge_heal_amount = 0
var nullify_hits_per_wave = 0
var nullify_hits_remaining = 0
var wave_start_hp_percent_delta = 0.0
var start_next_wave_with_one_hp_sources = 0
var explosion_damage_percent = 0.0
var explosion_size_percent = 0.0
var hit_explosion_chance = 0.0
var hit_explosion_sources = 0
var hit_explosion_base_damage = 0.0
var hit_explosion_curse_coefficient = 0.0
var hit_explosion_radius = 180.0
var low_health_explosion_sources = 0
var low_health_explosion_triggered_this_wave = false
var low_health_explosion_threshold = 0.40
var low_health_explosion_base_damage = 0.0
var low_health_explosion_melee_coefficient = 0.0
var low_health_explosion_ranged_coefficient = 0.0
var low_health_explosion_elemental_coefficient = 0.0
var low_health_explosion_engineering_coefficient = 0.0
var low_health_explosion_radius = 220.0
var spicy_sauce_explosion_chance = 0.0
var spicy_sauce_explosion_sources = 0
var spicy_sauce_explosion_base = 0.0
var spicy_sauce_explosion_max_hp_coefficient = 0.0
var spicy_sauce_explosion_radius = 200.0
var damage_against_high_health_targets_percent = 0.0
var high_health_target_damage_threshold = 0.80
var knockback_scaling_damage_sources = 0
var knockback_scaling_damage_bonus = 0.0
var speed_scaling_damage_sources = 0
var speed_scaling_damage_bonus = 0.0
var dodge_scaling_attack_speed_sources = 0
var dodge_scaling_attack_speed_bonus = 0.0
var armor_scaling_max_hp_sources = 0
var armor_scaling_max_hp_bonus = 0
var elemental_scaling_engineering_sources = 0
var elemental_scaling_engineering_bonus = 0
var end_wave_damage_percent_sources = 0
var end_wave_max_hp_gain_sources = 0
var end_wave_hp_regen_gain_sources = 0
var end_wave_lifesteal_gain_sources = 0
var end_wave_melee_damage_gain_sources = 0
var end_wave_engineering_gain_sources = 0
var end_wave_max_hp_loss_sources = 0
var end_wave_armor_loss_sources = 0
var end_wave_range_delta = 0
var level_upgrade_stat_percent_bonus = 0.0
var level_up_curse_gain_sources = 0
var level_up_hp_regen_gain_sources = 0
var level_up_lifesteal_gain_sources = 0
var level_up_max_hp_loss_sources = 0
var level_up_catalog_stat_deltas: Dictionary = {}
var material_scaling_max_hp_sources = 0
var material_scaling_max_hp_per_source_materials = 80
var material_scaling_max_hp_bonus = 0
var damage_loss_on_hit_sources = 0
var damage_loss_on_hit_amount = 0.02
var damage_loss_on_hit_bonus = 0.0
var catalog_stat_modifiers: Dictionary = {}
var catalog_stat_actual_modifiers: Dictionary = {}
var catalog_stat_suppressed_modifiers: Dictionary = {}
var catalog_stat_suppressed_modifiers_by_source: Dictionary = {}
var catalog_stat_modification_multipliers: Dictionary = {}
var max_hp_cap_sources = 0
var max_hp_cap_value = 0
var speed_cap_sources = 0
var speed_cap_value = 0.0
var piggy_bank_sources = 0
var piggy_bank_growth_percent = 0.20
var piggy_bank_wave_limit = 20
var distinct_weapon_max_hp_sources = 0
var distinct_weapon_max_hp_bonus = 0
var distinct_weapon_attack_speed_per_weapon = 0.0
var distinct_weapon_attack_speed_bonus = 0.0
var negative_speed_regen_sources = 0
var negative_speed_regen_bonus = 0
var end_wave_harvesting_growth_percent = 0.0
var end_wave_xp_gain_percent = 0.0
var next_wave_xp_gain_percent_pending = 0.0
var next_wave_xp_gain_percent_active = 0.0
var next_wave_enemy_health_percent_pending = 0.0
var next_wave_enemy_health_percent_active = 0.0
var next_wave_enemy_damage_percent_pending = 0.0
var next_wave_enemy_damage_percent_active = 0.0
var next_wave_enemy_speed_percent_pending = 0.0
var next_wave_enemy_speed_percent_active = 0.0
var next_wave_loot_alien_count_pending = 0
var next_wave_special_enemy_count_pending = 0
var nightmare_fog_visibility_percent = 0.0
var elemental_item_pickup_bonus_sources = 0
var elemental_item_pickup_bonus_granted = 0
var consumable_damage_boost_sources = 0
var consumable_damage_boost_bonus = 0.0
var consumable_damage_boost_timer = 0.0
var consumable_damage_boost_amount = 0.20
var consumable_damage_boost_duration = 2.0
var damage_taken_speed_boost_sources = 0
var damage_taken_speed_boost_bonus = 0.0
var damage_taken_speed_boost_timer = 0.0
var damage_taken_speed_boost_amount = 0.10
var damage_taken_speed_boost_duration = 3.0
var periodic_knockback_sources = 0
var periodic_knockback_timer = 0.0
var periodic_knockback_interval = 3.0
var periodic_knockback_radius = 180.0
var periodic_knockback_distance = 80.0
var free_shop_rerolls = 0
var extra_crate_reward_chance = 0.0
var extra_pearl_crate_chance = 0.0
var torture_healing_sources = 0
var torture_heal_timer = 0.0
var torture_heal_per_second = 5
var delayed_consumable_heal_sources = 0
var delayed_consumable_heal_duration = 4.0
var delayed_consumable_heal_entries: Array = []
var weapon_upgrade_locked_sources = 0
var shop_next_reroll_tier_bonus_pending = 0
var shop_reroll_damage_gain_chance = 0.0
var shop_reroll_max_hp_loss_chance = 0.0
var shop_reroll_damage_gain_amount = 0.01
var shop_reroll_max_hp_loss_amount = 1
var shop_entry_weapon_upgrade_sources = 0
var tree_spawn_bonus_sources = 0
var trees_die_in_one_hit_sources = 0
var garden_spawn_sources = 0
var catalog_turret_sources = 0
var catalog_turret_base_damage = 10.0
var catalog_turret_engineering_coefficient = 0.80
var catalog_turret_range = 300.0
var catalog_turret_cooldown = 0.73
var landmine_spawn_sources = 0
var landmine_base_damage = 10.0
var landmine_engineering_coefficient = 1.0
var landmine_base_radius = 80.0
var structures_can_crit_sources = 0
var structure_engineering_penalty_sources = 0
var structure_engineering_penalty_bonus = 0
var pocket_factory_sources = 0
var builders_turret_sources = 0
var tyler_sources = 0
var tyler_base_damage = 12.0
var tyler_engineering_coefficient = 0.90
var tyler_elemental_coefficient = 0.90
var tyler_projectiles = 10
var tyler_range = 360.0
var tyler_cooldown = 1.0
var wandering_bot_sources = 0
var wandering_bot_slow_percent = 0.30
var wandering_bot_slow_duration = 0.5
var wandering_bot_radius = 180.0
var explosive_turret_sources = 0
var explosive_turret_base_damage = 25.0
var explosive_turret_engineering_coefficient = 1.50
var explosive_turret_range = 300.0
var explosive_turret_cooldown = 1.0
var explosive_turret_radius = 120.0
var incendiary_turret_sources = 0
var incendiary_turret_base_damage = 5.0
var incendiary_turret_engineering_coefficient = 0.33
var incendiary_turret_range = 260.0
var incendiary_turret_cooldown = 1.0
var incendiary_turret_hit_count = 8
var laser_turret_sources = 0
var laser_turret_base_damage = 20.0
var laser_turret_engineering_coefficient = 1.25
var laser_turret_range = 360.0
var laser_turret_cooldown = 1.0
var medical_turret_sources = 0
var medical_turret_base_healing = 3.0
var medical_turret_engineering_heal_coefficient = 0.05
var medical_turret_range = 250.0
var medical_turret_cooldown = 2.0
var self_damage_per_second_sources = 0
var self_damage_timer = 0.0
var lifesteal_scaling_damage_sources = 0
var lifesteal_scaling_damage_bonus = 0.0
var structure_attack_speed_percent = 0.0
var structures_scale_with_player_attack_speed_sources = 0
var weapon_minimum_cooldown = 0.0
var weapon_minimum_cooldown_sources = 0
var stand_still_armor_sources = 0
var stand_still_armor_bonus = 0
var stand_still_attack_speed_sources = 0
var stand_still_attack_speed_bonus = 0.0
var stand_still_dodge_sources = 0
var stand_still_dodge_bonus = 0.0
var stand_still_hp_regen_sources = 0
var stand_still_hp_regen_bonus = 0

# 新被动升级变量
var shield = 0
var max_shield = 0
var burn_chance = 0.0
var freeze_chance = 0.0
var chain_lightning = false
var xp_boost = 1.0
var gold_interest = 0.0
var thorns = 0.0
var revenge_bonus = false
var adrenaline = false
var steel_will = false
var war_machine_stacks = 0
var war_machine_enabled = false
var base_speed = 300.0

# 角色专属被动
var character_passive = ""
var passive_timer = 0.0
var passive_active = false
var passive_bonus_damage = 0
var dodge_chance = 0.0
var dodge_cap = 0.90
var dodge_cap_sources = 0
var dodge_cap_20_sources = 0
var gold_per_wave = 0
var damage_cap = 0
var turret_timer = 0.0
var turret_cd = 15.0
var berserker_hp_bonus = 0
var ghost_dodge_chance = 0.0
var ghost_flicker_timer = 0.0
var necro_summon_chance = 0.0
var total_dodges = 0

# 元素弹药
var ammo_type = ""

# 动态难度采样
var damage_events = []

# 统计
var total_damage_dealt = 0
var total_damage_taken = 0
var game_time = 0.0

# 进度
var xp         = 0
var level      = 1
var xp_to_next = 10
var gold       = 0 # Transitional alias for current materials during Phase 1.
var economy: RunEconomy = null
var pending_level_ups: int = 0

var invincible_timer = 0.0
var equipped_weapons = []
var max_weapon_slots = MAX_WEAPONS
var max_one_weapon_sources = 0
var bullet_scene = preload("res://scenes/Bullet.tscn")

signal hp_changed(hp, max_hp)
signal xp_changed(xp, xp_to_next)
signal level_up(lv)
signal weapons_changed(names)
signal hurt
signal died
signal gold_changed(gold)
signal shield_changed(shield, max_shield)
signal synergy_activated(synergy_name)
signal buff_changed(active_pickups)
signal request_turret(pos)
signal request_undead(pos)

var active_synergies: Array = []
var active_pickups: Dictionary = {}

# 子模块
var core: PlayerCore
var combat: PlayerCombat
var upgrades: PlayerUpgrades
var buffs: PlayerBuffs
var stats_module: PlayerStats
# 元素状态（燃烧 / 减速 / 眩晕），由敌方元素子弹施加
var status: PlayerStatus
var upgrade_choice_rules: UpgradeChoiceRules
var current_upgrade_choices: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE

	core = PlayerCore.new()
	core.init(self)
	combat = PlayerCombat.new()
	combat.init(self)
	upgrades = PlayerUpgrades.new()
	upgrades.init(self)
	buffs = PlayerBuffs.new()
	buffs.init(self)
	stats_module = PlayerStats.new()
	stats_module.init(self)
	status = PlayerStatus.new()
	status.init(self)
	upgrade_choice_rules = UpgradeChoiceRules.new()

	add_to_group("player")
	var c = GameState.get_character()
	var use_catalog_runtime_stats = c.has("catalog_id")
	max_hp               = 5  + (0 if use_catalog_runtime_stats else int(c.get("hp_bonus", 0)))
	hp                   = max_hp
	base_speed           = 300.0 + (0 if use_catalog_runtime_stats else int(c.get("spd_bonus", 0)))
	speed                = base_speed
	damage_bonus         = 0 if use_catalog_runtime_stats else int(c.get("dmg_bonus", 0))
	fire_rate_multiplier = 1.0 + (0.0 if use_catalog_runtime_stats else float(c.get("fr_bonus", 0.0)))
	crit_chance          = 0.0 if use_catalog_runtime_stats else float(c.get("crit_bonus", 0.0))
	lifesteal            = 0.0 if use_catalog_runtime_stats else float(c.get("lifesteal_bonus", 0.0))
	hp_regen             = 0 if use_catalog_runtime_stats else int(c.get("regen_bonus", 0))
	luck                 = 0 if use_catalog_runtime_stats else int(c.get("luck_bonus", 0))
	curse                = 0 if use_catalog_runtime_stats else int(c.get("curse_bonus", 0))
	armor                = 0 if use_catalog_runtime_stats else int(c.get("armor_bonus", 0))
	crit_damage          = 2.0 + c.get("crit_damage_bonus", 0.0)
	gold                 = c.get("starting_gold",  0)
	equip_weapon(c.weapon)
	if c.extra_weapon != "":
		equip_weapon(c.extra_weapon)
	_apply_character_catalog_rules(c)
	_apply_character_starting_items(c)
	character_passive = GameState.selected_character
	core.init_character_passive()
	# 形状语言：玩家用固定轮廓（六边形 + 统一描边），与所有敌人区分开
	UnitVisual.apply(self, $Body, "player")

func _apply_character_starting_items(character_data: Dictionary):
	var starting_items = character_data.get("starting_items", [])
	if not (starting_items is Array):
		return
	for entry in starting_items:
		if not (entry is Dictionary):
			continue
		var item_id = str(entry.get("item_id", ""))
		if item_id == "":
			continue
		var item = GameState.get_catalog_item_shop_entry(item_id)
		if item.is_empty():
			continue
		if bool(entry.get("cursed", false)):
			item["catalog_cursed"] = true
			item["is_cursed"] = true
			item["cursed"] = true
		apply_upgrade(item)

func _apply_character_catalog_rules(character_data: Dictionary):
	var rules = character_data.get("rules", [])
	if not (rules is Array):
		return
	var runtime_rules: Array = []
	for rule in rules:
		if not (rule is Dictionary):
			continue
		if str(rule.get("effect", "")) in ["stat_delta", "pickup_range_percent", "weapon_special", "stat_modifications_multiplier"]:
			runtime_rules.append(rule)
	if runtime_rules.is_empty():
		return
	upgrades.apply_catalog_rule_effects(runtime_rules, 1.0, true)

func recalculate_dodge_cap():
	var next_cap = 0.90
	if dodge_cap_sources > 0:
		next_cap = min(next_cap, 0.70)
	if dodge_cap_20_sources > 0:
		next_cap = min(next_cap, 0.20)
	dodge_cap = next_cap
	dodge_chance = min(dodge_chance, dodge_cap)

func _physics_process(delta):
	stats_module.update_game_time(delta)
	core.process_movement(delta)
	update_stand_still_item_bonuses()
	recalculate_living_enemy_attack_speed()
	recalculate_burning_enemy_hp_regen()
	recalculate_structure_engineering_penalty()
	core.process_invincibility(delta)
	core.process_passive_timers(delta)
	status.process(delta)
	buffs.process_buff_timers(delta)
	process_consumable_damage_boost(delta)
	process_damage_taken_speed_boost(delta)
	process_periodic_knockback(delta)
	process_alien_eyes(delta)
	process_torture_healing(delta)
	process_delayed_consumable_healing(delta)
	process_self_damage_over_time(delta)
	# 只在战斗阶段开火。波次结束后玩家仍在树上（process_mode = PAUSABLE，
	# 而商店阶段并不暂停整棵树），所以在结算 / 开箱 / 升级 / 商店里原本会继续射击。
	if _is_combat_phase():
		combat.process_weapons(delta)
	# 范围环与「是否开火」无关，始终跟随当前武器 —— 换武器立刻反映
	combat.update_melee_indicator()

# ─── 近战可视化 ───
#
# 近战武器此前**完全没有视觉**：打没打、打多远、多久一下，全都看不出来
# （远程至少有子弹）。这里补上两层：
#   ① 常显的**攻击范围环**（暗）—— 近战命中判定是「半径内的所有敌人」，不分方向，
#      所以用整圈表示范围，与 `_fire_melee` 的判定完全一致；
#   ② 挥击时的**闪光弧**（亮、向外扩散后淡出）—— 一眼看出攻击频率。
# 范围环的频率是「跟手」的：它由当前装备的近战武器实时算出，
# 换武器 / 拿到范围加成立刻反映，不需要额外 UI。

const MELEE_REACH_COLOR := Color(0.85, 0.92, 1.0, 0.18)
const MELEE_RING_SEGMENTS := 28
const MELEE_SWING_HALF_ANGLE := deg_to_rad(52.0)
const MELEE_SWEEP_HALF_ANGLE := deg_to_rad(140.0)

var _melee_reach: Line2D = null
var _melee_swing: Line2D = null
var _melee_swing_tween: Tween = null


# 由 PlayerCombat 每帧告知当前近战范围（没有近战武器时半径 <= 0）
func set_melee_reach(radius: float):
	_ensure_melee_nodes()
	if radius <= 0.0:
		_melee_reach.visible = false
		_melee_swing.visible = false
		return
	_melee_reach.visible = true
	_melee_reach.points = _circle_points(radius, MELEE_RING_SEGMENTS)


func hide_melee_reach():
	if _melee_reach != null and is_instance_valid(_melee_reach):
		_melee_reach.visible = false
	if _melee_swing != null and is_instance_valid(_melee_swing):
		_melee_swing.visible = false


# 挥击一次：亮起一条朝向目标的弧并向外扩散淡出。
# 扩散 + 淡出都在 0.18s 内完成，与最快的近战冷却同量级，所以连击时能看清节奏。
func show_melee_swing(radius: float, color: Color, dir: Vector2, is_sweep: bool):
	_ensure_melee_nodes()
	_melee_swing.visible = true
	var half_angle := MELEE_SWEEP_HALF_ANGLE if is_sweep else MELEE_SWING_HALF_ANGLE
	_melee_swing.points = _arc_points(radius, dir, half_angle)
	_melee_swing.default_color = color
	_melee_swing.modulate = Color(1, 1, 1, 1)
	_melee_swing.scale = Vector2.ONE * 0.72
	if _melee_swing_tween != null and _melee_swing_tween.is_valid():
		_melee_swing_tween.kill()
	_melee_swing_tween = create_tween()
	_melee_swing_tween.set_parallel(true)
	_melee_swing_tween.tween_property(_melee_swing, "scale", Vector2.ONE * 1.10, 0.18)
	_melee_swing_tween.tween_property(_melee_swing, "modulate:a", 0.0, 0.18)


func _ensure_melee_nodes():
	if _melee_reach == null or not is_instance_valid(_melee_reach):
		_melee_reach = Line2D.new()
		_melee_reach.name = "MeleeReach"
		_melee_reach.width = 2.0
		_melee_reach.default_color = MELEE_REACH_COLOR
		_melee_reach.joint_mode = Line2D.LINE_JOINT_ROUND
		# 画在单位之下：它是地面上的范围提示，不该盖住角色
		_melee_reach.z_index = -1
		_melee_reach.visible = false
		add_child(_melee_reach)
	if _melee_swing == null or not is_instance_valid(_melee_swing):
		_melee_swing = Line2D.new()
		_melee_swing.name = "MeleeSwing"
		_melee_swing.width = 5.0
		_melee_swing.default_color = Color(1, 1, 1, 0.9)
		_melee_swing.joint_mode = Line2D.LINE_JOINT_ROUND
		_melee_swing.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_melee_swing.end_cap_mode = Line2D.LINE_CAP_ROUND
		_melee_swing.z_index = 1
		_melee_swing.visible = false
		add_child(_melee_swing)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _arc_points(radius: float, dir: Vector2, half_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var base := dir.angle() if dir.length_squared() > 0.0 else 0.0
	var steps := 16
	for i in range(steps + 1):
		var a := base - half_angle + (2.0 * half_angle) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


# 没有 Main 父节点时（独立场景 / 测试）按战斗中处理，保持既有行为不变。
func _is_combat_phase() -> bool:
	var parent = get_parent()
	if parent == null or not is_instance_valid(parent):
		return true
	if not parent.has_method("is_combat_phase"):
		return true
	return bool(parent.is_combat_phase())

# ─── 公共接口（委托给子模块） ───

func equip_weapon(type):
	combat.equip_weapon(type)

func can_equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	return combat.can_equip_or_combine_weapon(type, tier)

func equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	return combat.equip_or_combine_weapon(type, tier)

func can_combine_weapon(slot_index: int) -> bool:
	return combat.can_combine_weapon(slot_index)

func combine_weapon(slot_index: int) -> bool:
	return combat.combine_weapon(slot_index)

func get_max_weapon_slots() -> int:
	return max(0, int(max_weapon_slots))

func recalculate_max_weapon_slots():
	max_weapon_slots = 1 if max_one_weapon_sources > 0 else MAX_WEAPONS

func upgrade_weapon(slot_index: int) -> bool:
	return combat.upgrade_weapon(slot_index)

func get_weapon_info() -> Array:
	return combat.get_weapon_info()

func take_damage(amount, element: String = ""):
	core.take_damage(amount, element)

# 元素状态的移动乘数查询（由 PlayerCore.process_movement 在消费点调用）
func status_speed_multiplier() -> float:
	if status == null:
		return 1.0
	return status.speed_multiplier()

func heal(amount: float):
	core.heal(amount)

func force_heal(amount: float):
	core.heal(amount, true)

func apply_consumable_heal(amount: int):
	var heal_amount = max(0, int(amount))
	if heal_amount <= 0:
		return
	if delayed_consumable_heal_sources > 0:
		delayed_consumable_heal_entries.append({
			"amount": heal_amount,
			"elapsed": 0.0,
			"ticks_elapsed": 0,
			"healed": 0,
		})
		return
	heal(heal_amount)

func on_shop_rerolled():
	if shop_reroll_damage_gain_chance > 0.0 and randf() < shop_reroll_damage_gain_chance:
		damage_percent_bonus += shop_reroll_damage_gain_amount
	if shop_reroll_max_hp_loss_chance > 0.0 and randf() < shop_reroll_max_hp_loss_chance:
		apply_max_hp_delta(-shop_reroll_max_hp_loss_amount)

func on_shop_opened():
	for i in range(max(0, shop_entry_weapon_upgrade_sources)):
		_apply_shop_entry_weapon_upgrade_or_armor()

func _apply_shop_entry_weapon_upgrade_or_armor():
	var candidates: Array[int] = []
	if weapon_upgrade_locked_sources <= 0:
		for i in range(equipped_weapons.size()):
			var weapon = equipped_weapons[i]
			var weapon_type = str(weapon.get("type", ""))
			var tier = int(weapon.get("tier", weapon.get("level", 1)))
			if weapon_type != "" and tier < 4 and combat.WEAPON_DATA.has(weapon_type):
				candidates.append(i)
	if candidates.is_empty():
		armor += 2
		if has_method("recalculate_armor_scaling_max_hp"):
			recalculate_armor_scaling_max_hp()
		return
	var chosen_index = candidates[randi() % candidates.size()]
	var chosen_weapon = equipped_weapons[chosen_index]
	var chosen_type = str(chosen_weapon.get("type", ""))
	var chosen_tier = int(chosen_weapon.get("tier", chosen_weapon.get("level", 1)))
	equipped_weapons[chosen_index] = combat._make_weapon(chosen_type, chosen_tier + 1)
	combat.emit_weapons_changed()
	upgrades.check_synergies()

func apply_axolotl_primary_stat_swap():
	var lowest := {}
	var highest := {}
	for stat_id in AXOLOTL_PRIMARY_STATS:
		var stat_value = _get_primary_stat_display_value(stat_id)
		if stat_value <= 0.0:
			continue
		if lowest.is_empty() or stat_value < float(lowest.get("value", 0.0)):
			lowest = {"id": stat_id, "value": stat_value}
		if highest.is_empty() or stat_value > float(highest.get("value", 0.0)):
			highest = {"id": stat_id, "value": stat_value}
	if lowest.is_empty() or highest.is_empty() or str(lowest.get("id", "")) == str(highest.get("id", "")):
		return
	_set_primary_stat_display_value(str(lowest.get("id", "")), float(highest.get("value", 0.0)))
	_set_primary_stat_display_value(str(highest.get("id", "")), float(lowest.get("value", 0.0)))
	_refresh_primary_stat_dependencies()

func _get_primary_stat_display_value(stat_id: String) -> float:
	match stat_id:
		"max_hp": return float(max_hp)
		"hp_regeneration": return float(hp_regen)
		"lifesteal": return lifesteal * 100.0
		"damage_percent": return damage_percent_bonus * 100.0
		"melee_damage": return float(melee_damage_bonus)
		"ranged_damage": return float(ranged_damage_bonus)
		"elemental_damage": return float(elemental_damage_bonus)
		"attack_speed_percent": return (fire_rate_multiplier - 1.0) * 100.0
		"crit_chance": return crit_chance * 100.0
		"engineering": return float(engineering_bonus)
		"range": return float(range_bonus)
		"armor": return float(armor)
		"dodge": return dodge_chance * 100.0
		"speed_percent": return ((base_speed - 300.0) / 300.0) * 100.0
		"luck": return float(luck)
		"harvesting": return float(gold_per_wave)
	return 0.0

func _set_primary_stat_display_value(stat_id: String, value: float):
	match stat_id:
		"max_hp":
			apply_max_hp_delta(int(round(value)) - int(max_hp))
		"hp_regeneration":
			hp_regen = int(round(value))
		"lifesteal":
			lifesteal = clamp(value / 100.0, 0.0, 0.5)
		"damage_percent":
			damage_percent_bonus = value / 100.0
		"melee_damage":
			melee_damage_bonus = int(round(value))
		"ranged_damage":
			ranged_damage_bonus = int(round(value))
		"elemental_damage":
			elemental_damage_bonus = int(round(value))
		"attack_speed_percent":
			fire_rate_multiplier = max(0.1, 1.0 + value / 100.0)
		"crit_chance":
			crit_chance = clamp(value / 100.0, 0.0, 0.8)
		"engineering":
			engineering_bonus = int(round(value))
		"range":
			range_bonus = value
		"armor":
			armor = int(round(value))
		"dodge":
			dodge_chance = clamp(value / 100.0, 0.0, dodge_cap)
		"speed_percent":
			var target_speed = 300.0 * (1.0 + value / 100.0)
			apply_speed_delta(target_speed - base_speed)
		"luck":
			luck = int(round(value))
		"harvesting":
			gold_per_wave = int(round(value))

func _refresh_primary_stat_dependencies():
	recalculate_crit_scaling_luck()
	recalculate_luck_scaling_damage()
	recalculate_lifesteal_scaling_damage()
	recalculate_speed_scaling_damage()
	recalculate_dodge_scaling_attack_speed()
	recalculate_armor_scaling_max_hp()
	recalculate_elemental_scaling_engineering()
	recalculate_negative_speed_regen()

func apply_candy_bag_wave_random_stat(stat_id: String = ""):
	if candy_bag_random_stat_sources <= 0:
		return
	var chosen_stat = stat_id
	if chosen_stat == "" or not AXOLOTL_PRIMARY_STATS.has(chosen_stat):
		chosen_stat = AXOLOTL_PRIMARY_STATS[randi() % AXOLOTL_PRIMARY_STATS.size()]
	clear_candy_bag_wave_random_stat()
	var before = _get_primary_stat_display_value(chosen_stat)
	_set_primary_stat_display_value(chosen_stat, before + candy_bag_random_stat_value)
	var actual = _get_primary_stat_display_value(chosen_stat) - before
	if is_equal_approx(actual, 0.0):
		return
	candy_bag_random_stat_bonus = {
		"stat_id": chosen_stat,
		"value": actual,
	}
	_refresh_primary_stat_dependencies()

func clear_candy_bag_wave_random_stat():
	if candy_bag_random_stat_bonus.is_empty():
		return
	var stat_id = str(candy_bag_random_stat_bonus.get("stat_id", ""))
	var value = float(candy_bag_random_stat_bonus.get("value", 0.0))
	if stat_id != "" and AXOLOTL_PRIMARY_STATS.has(stat_id) and not is_equal_approx(value, 0.0):
		_set_primary_stat_display_value(stat_id, _get_primary_stat_display_value(stat_id) - value)
		_refresh_primary_stat_dependencies()
	candy_bag_random_stat_bonus.clear()

func gain_xp(amount):
	core.gain_xp(amount)

func has_pending_level_ups() -> bool:
	return pending_level_ups > 0

func pop_upgrade_choices() -> Array:
	if pending_level_ups <= 0:
		current_upgrade_choices = []
		return []
	current_upgrade_choices = upgrade_choice_rules.generate_choices(luck, 4, _current_wave())
	return current_upgrade_choices

func _current_wave() -> int:
	# 四选一按波次分档（tier 门槛见 data/brotato/upgrades.json 的 min_wave/max_wave）。
	# 取不到 Main 时返回 0，交由 UpgradeChoiceRules 视为「不过滤」。
	var main_node = get_parent()
	if main_node == null or not is_instance_valid(main_node) or not ("wave" in main_node):
		return 0
	return int(main_node.wave)

func apply_upgrade_choice(index: int):
	if index < 0 or index >= current_upgrade_choices.size():
		return
	upgrade_choice_rules.apply_choice(self, current_upgrade_choices[index])
	pending_level_ups = max(0, pending_level_ups - 1)
	current_upgrade_choices = []

func earn_gold(amount):
	core.earn_gold(amount)

func on_material_picked_up(_value: int):
	# 仅由 XPOrb 的材料拾取路径调用（区别于 material_on_critical_kill 之类直接发钱）
	if combat != null:
		combat.on_material_picked_up()

func spend_materials(amount: int) -> bool:
	return core.spend_materials(amount)

func apply_upgrade(upgrade):
	upgrades.apply_upgrade(upgrade)

func remove_upgrade(upgrade):
	upgrades.remove_upgrade(upgrade)

func get_active_synergies() -> Array:
	return upgrades.get_active_synergies()

func apply_temp_buff(buff_type: String, duration: float):
	buffs.apply_temp_buff(buff_type, duration)

func on_kill():
	buffs.on_kill()

func on_enemy_died(enemy = null):
	if enemy_kill_heal_chance > 0.0 and randf() < enemy_kill_heal_chance:
		heal(1)
	if enemy_death_luck_damage_chance > 0.0 and randf() < enemy_death_luck_damage_chance:
		_deal_enemy_death_luck_damage(enemy)
	if enemy_death_explosion_chance > 0.0 and randf() < enemy_death_explosion_chance:
		_deal_enemy_death_explosion(enemy)
	if corpse_bullet_sources > 0:
		fire_enemy_corpse_bullet(enemy)
	if cursed_enemy_material_bonus_sources > 0 and is_catalog_cursed_enemy(enemy):
		earn_gold(cursed_enemy_material_bonus_sources)
	if burning_kill_elemental_damage_sources > 0:
		record_burning_enemy_kill(enemy)

func is_catalog_cursed_enemy(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_meta("catalog_cursed") and bool(enemy.get_meta("catalog_cursed")):
		return true
	var cursed_value = enemy.get("catalog_cursed")
	return cursed_value != null and bool(cursed_value)

func record_burning_enemy_kill(enemy):
	if burning_kill_elemental_damage_sources <= 0 or not _is_burning_enemy(enemy):
		return
	burning_kill_elemental_kill_counter += 1
	var threshold = max(1, burning_kill_elemental_threshold)
	var max_gain = max(1, burning_kill_elemental_max_per_wave) * max(1, burning_kill_elemental_damage_sources)
	while burning_kill_elemental_kill_counter >= threshold and burning_kill_elemental_gained_this_wave < max_gain:
		burning_kill_elemental_kill_counter -= threshold
		burning_kill_elemental_gained_this_wave += 1
		elemental_damage_bonus += 1
		if has_method("recalculate_elemental_scaling_engineering"):
			recalculate_elemental_scaling_engineering()

func reset_burning_kill_elemental_damage_wave_bonus():
	burning_kill_elemental_kill_counter = 0
	burning_kill_elemental_gained_this_wave = 0

func _is_burning_enemy(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var burn_value = enemy.get("burn_timer")
	if burn_value != null and float(burn_value) > 0.0:
		return true
	return enemy.has_meta("catalog_burning") and bool(enemy.get_meta("catalog_burning"))

func on_tree_killed(tree = null):
	if pocket_factory_sources <= 0:
		return
	var main = get_parent()
	if main == null or not is_instance_valid(main) or main.get("turret_manager") == null:
		return
	var spawn_position = tree.position if tree != null and is_instance_valid(tree) else position
	for i in range(max(0, pocket_factory_sources)):
		var turret = main.turret_manager.spawn_catalog_turret(
			spawn_position + Vector2(float(i) * 18.0, 0.0),
			catalog_turret_base_damage,
			catalog_turret_engineering_coefficient,
			catalog_turret_range,
			catalog_turret_cooldown
		)
		if turret != null and is_instance_valid(turret):
			turret.set_meta("variant", "pocket_factory_turret")
			turret.add_to_group("pocket_factory_turrets")

func on_enemy_killed_by_hit(context: Dictionary = {}):
	if combat != null:
		combat.on_enemy_killed(null)
	if bool(context.get("is_crit", false)) and crit_kill_heal_chance > 0.0:
		if randf() < crit_kill_heal_chance:
			heal(1)
	if bool(context.get("is_crit", false)) and crit_kill_material_chance > 0.0:
		if randf() < crit_kill_material_chance:
			earn_gold(1)

func apply_material_pickup_modifiers(value: int) -> int:
	var final_value = max(0, value)
	if final_value > 0 and double_material_pickup_chance > 0.0 and randf() < double_material_pickup_chance:
		final_value *= 2
	if final_value > 0 and material_pickup_heal_chance > 0.0 and randf() < material_pickup_heal_chance:
		heal(1)
	if final_value > 0 and material_pickup_luck_damage_chance > 0.0 and randf() < material_pickup_luck_damage_chance:
		_deal_material_pickup_luck_damage()
	return final_value

func on_consumable_pickup(pickup_type: String, was_full_health: bool, pickup_position = null, explosion_roll: float = -1.0):
	if pickup_type not in ["fruit", "crate", "legendary_crate"]:
		return
	if pickup_position != null and spicy_sauce_explosion_chance > 0.0:
		var roll = randf() if explosion_roll < 0.0 else explosion_roll
		if roll < spicy_sauce_explosion_chance:
			deal_consumable_explosion(pickup_position)
	if pickup_type != "fruit":
		return
	activate_consumable_damage_boost()
	if not was_full_health:
		return
	if full_health_consumable_max_hp_gain_sources > 0:
		var cap = max(0, full_health_consumable_max_hp_gain_cap_per_wave)
		if cap > 0 and full_health_consumable_max_hp_gained_this_wave < cap:
			if apply_max_hp_delta(1) > 0:
				full_health_consumable_max_hp_gained_this_wave += 1
	if full_health_consumable_temp_hp_regen_sources > 0:
		var regen_gain = full_health_consumable_temp_hp_regen_sources
		hp_regen += regen_gain
		full_health_consumable_temp_hp_regen_bonus += regen_gain

func deal_catalog_explosion(origin: Vector2, amount: int, radius: float = 200.0, excluded_enemy = null, color: Color = Color(1.0, 0.45, 0.1)) -> int:
	var final_radius = max(1.0, radius * max(0.0, 1.0 + float(explosion_size_percent)))
	# DEX-troyer：本波每次爆炸提升爆炸伤害（按计数即时折算，不改 explosion_damage_percent）
	var growth_bonus = combat.explosion_damage_growth_bonus() if combat != null else 0.0
	var final_amount = max(1, int(round(float(amount) * max(0.0, 1.0 + float(explosion_damage_percent) + growth_bonus))))
	var hit_count = 0
	Effects.death_burst(origin, color)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == excluded_enemy:
			continue
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		if int(enemy.get("hp")) <= 0:
			continue
		if origin.distance_to(enemy.position) > final_radius:
			continue
		enemy.take_damage(final_amount)
		total_damage_dealt += final_amount
		hit_count += 1
	# 计数放在伤害计算之后：本次爆炸用旧计数，下一次才吃到加成。
	# deal_hit_explosion() 内部委托到本函数，所以只需在这一处计数。
	if combat != null:
		combat.on_explosion_dealt()
	return hit_count

func deal_hit_explosion(source_enemy) -> int:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return 0
	var amount = max(1, int(round(hit_explosion_base_damage + float(curse) * hit_explosion_curse_coefficient)))
	return deal_catalog_explosion(source_enemy.position, amount, hit_explosion_radius, source_enemy, Color(0.45, 0.9, 1.0))

func trigger_low_health_explosion() -> bool:
	if low_health_explosion_sources <= 0 or low_health_explosion_triggered_this_wave:
		return false
	if max_hp <= 0 or float(hp) / float(max_hp) > low_health_explosion_threshold:
		return false
	var amount = low_health_explosion_base_damage
	amount += float(melee_damage_bonus) * low_health_explosion_melee_coefficient
	amount += float(ranged_damage_bonus) * low_health_explosion_ranged_coefficient
	amount += float(elemental_damage_bonus) * low_health_explosion_elemental_coefficient
	amount += float(engineering_bonus) * low_health_explosion_engineering_coefficient
	deal_catalog_explosion(position, max(1, int(round(amount))), low_health_explosion_radius, null, Color(0.25, 0.9, 1.0))
	low_health_explosion_triggered_this_wave = true
	return true

func deal_consumable_explosion(origin: Vector2):
	var radius = spicy_sauce_explosion_radius
	radius = max(1.0, radius * max(0.0, 1.0 + float(explosion_size_percent)))
	var amount = max(1, int(round(spicy_sauce_explosion_base + float(max_hp) * spicy_sauce_explosion_max_hp_coefficient)))
	amount = max(1, int(round(float(amount) * max(0.0, 1.0 + float(explosion_damage_percent)))))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		if origin.distance_to(enemy.position) <= radius:
			enemy.take_damage(amount)
			Effects.hit_spark(enemy.position, Color(1.0, 0.35, 0.15))
			total_damage_dealt += amount

func modify_damage_against_target(amount: int, target, context: Dictionary = {}) -> int:
	var final_amount = max(1, amount)
	if not is_equal_approx(boss_elite_damage_percent, 0.0) and _is_boss_or_elite_target(target):
		final_amount = max(1, int(round(float(final_amount) * (1.0 + boss_elite_damage_percent))))
	if not is_equal_approx(damage_against_high_health_targets_percent, 0.0) and _is_high_health_target(target):
		final_amount = max(1, int(round(float(final_amount) * (1.0 + damage_against_high_health_targets_percent))))
	if elemental_weapon_damage_scaling_sources > 0 and elemental_damage_bonus > 0:
		final_amount += int(round(float(elemental_damage_bonus) * 0.10 * float(elemental_weapon_damage_scaling_sources)))
	if engineering_weapon_damage_scaling_sources > 0 and engineering_bonus > 0:
		final_amount += int(round(float(engineering_bonus) * 0.20 * float(engineering_weapon_damage_scaling_sources)))
	if bool(context.get("is_crit", false)):
		var current_hp_percent = critical_current_hp_bonus_boss_elite_percent if _is_boss_or_elite_target(target) else critical_current_hp_bonus_enemy_percent
		if current_hp_percent > 0.0 and target != null and is_instance_valid(target):
			var hp_value = target.get("hp")
			var current_hp = 0.0
			if hp_value != null:
				current_hp = float(hp_value)
			final_amount += max(0, int(round(current_hp * current_hp_percent)))
	return final_amount

func on_enemy_elemental_hit(enemy):
	if elemental_vulnerability_sources <= 0:
		return
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("apply_damage_taken_bonus"):
		return
	var percent = elemental_vulnerability_percent * float(elemental_vulnerability_sources)
	enemy.apply_damage_taken_bonus(percent, elemental_vulnerability_duration, "ice_cube_elemental_vulnerability")

func modify_burn_tick_damage(amount: int, target) -> int:
	var final_amount = max(1, int(amount))
	if burn_current_hp_bonus_sources <= 0 or target == null or not is_instance_valid(target):
		return final_amount
	var percent = burn_current_hp_bonus_boss_elite_percent if _is_boss_or_elite_target(target) else burn_current_hp_bonus_enemy_percent
	if percent <= 0.0:
		return final_amount
	var hp_value = target.get("hp")
	if hp_value == null:
		return final_amount
	var bonus = int(round(float(hp_value) * percent * float(burn_current_hp_bonus_sources)))
	return final_amount + max(0, bonus)

func _is_boss_or_elite_target(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var enemy_type_value = target.get("enemy_type")
	if enemy_type_value == null:
		return false
	return str(enemy_type_value) in ["boss", "miniboss", "elite"]

func _is_high_health_target(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var hp_value = target.get("hp")
	var max_hp_value = target.get("max_hp")
	if hp_value == null or max_hp_value == null:
		return false
	var max_hp_value_float = float(max_hp_value)
	if max_hp_value_float <= 0.0:
		return false
	return float(hp_value) / max_hp_value_float >= high_health_target_damage_threshold

func recalculate_crit_scaling_luck():
	var next_bonus = 0
	if crit_scaling_luck_sources > 0 and crit_scaling_luck_per_percent > 0.0:
		next_bonus = max(0, int(round(max(0.0, crit_chance) * 100.0 * crit_scaling_luck_per_percent)))
	var delta = next_bonus - crit_scaling_luck_bonus
	if delta != 0:
		luck += delta
	crit_scaling_luck_bonus = next_bonus

func recalculate_luck_scaling_damage():
	var next_bonus = 0.0
	if luck_scaling_damage_sources > 0 and luck > 0:
		next_bonus = float(int(floor(float(max(0, luck)) / 10.0))) * 0.01 * float(luck_scaling_damage_sources)
	var delta = next_bonus - luck_scaling_damage_bonus
	if not is_equal_approx(delta, 0.0):
		damage_percent_bonus += delta
	luck_scaling_damage_bonus = next_bonus

func reset_luck_scaling_damage_bonus():
	if not is_equal_approx(luck_scaling_damage_bonus, 0.0):
		damage_percent_bonus -= luck_scaling_damage_bonus
	luck_scaling_damage_bonus = 0.0

func process_wisdom_damage(delta: float):
	if wisdom_damage_sources <= 0:
		return
	wisdom_damage_timer += delta
	while wisdom_damage_timer >= 5.0:
		wisdom_damage_timer -= 5.0
		damage_percent_bonus += 0.05
		wisdom_damage_bonus += 0.05

func reset_wisdom_damage_bonus():
	if not is_equal_approx(wisdom_damage_bonus, 0.0):
		damage_percent_bonus -= wisdom_damage_bonus
	wisdom_damage_bonus = 0.0
	wisdom_damage_timer = 0.0

func process_medikit_hp_regen(delta: float):
	if medikit_hp_regen_sources <= 0:
		return
	medikit_hp_regen_timer += delta
	while medikit_hp_regen_timer >= 5.0:
		medikit_hp_regen_timer -= 5.0
		var regen_gain = 2 * medikit_hp_regen_sources
		hp_regen += regen_gain
		medikit_hp_regen_bonus += regen_gain

func reset_medikit_hp_regen_bonus():
	if medikit_hp_regen_bonus != 0:
		hp_regen -= medikit_hp_regen_bonus
	medikit_hp_regen_bonus = 0
	medikit_hp_regen_timer = 0.0

func process_crystal_attack_speed(delta: float):
	if crystal_attack_speed_sources <= 0:
		return
	crystal_attack_speed_timer += delta
	while crystal_attack_speed_timer >= 1.0:
		crystal_attack_speed_timer -= 1.0
		var attack_speed_gain = 0.01 * float(crystal_attack_speed_sources)
		fire_rate_multiplier = max(0.1, fire_rate_multiplier + attack_speed_gain)
		crystal_attack_speed_bonus += attack_speed_gain

func reset_crystal_attack_speed_bonus():
	if not is_equal_approx(crystal_attack_speed_bonus, 0.0):
		fire_rate_multiplier = max(0.1, fire_rate_multiplier - crystal_attack_speed_bonus)
	crystal_attack_speed_bonus = 0.0
	crystal_attack_speed_timer = 0.0

func recalculate_living_enemy_attack_speed(enemy_count: int = -1):
	var count = enemy_count
	if count < 0:
		count = _count_living_enemies()
	var next_bonus = 0.0
	if living_enemy_attack_speed_sources > 0:
		next_bonus = float(max(0, count)) * 0.01 * float(living_enemy_attack_speed_sources)
	var delta = next_bonus - living_enemy_attack_speed_bonus
	if not is_equal_approx(delta, 0.0):
		fire_rate_multiplier = max(0.1, fire_rate_multiplier + delta)
	living_enemy_attack_speed_bonus = next_bonus

func reset_living_enemy_attack_speed_bonus():
	if not is_equal_approx(living_enemy_attack_speed_bonus, 0.0):
		fire_rate_multiplier = max(0.1, fire_rate_multiplier - living_enemy_attack_speed_bonus)
	living_enemy_attack_speed_bonus = 0.0

func recalculate_burning_enemy_hp_regen(enemy_count: int = -1):
	var count = enemy_count
	if count < 0:
		count = _count_burning_enemies()
	var next_bonus = 0
	if burning_enemy_hp_regen_sources > 0:
		next_bonus = max(0, count) * burning_enemy_hp_regen_sources
	var delta = next_bonus - burning_enemy_hp_regen_bonus
	if delta != 0:
		hp_regen += delta
	burning_enemy_hp_regen_bonus = next_bonus

func reset_burning_enemy_hp_regen_bonus():
	if burning_enemy_hp_regen_bonus != 0:
		hp_regen -= burning_enemy_hp_regen_bonus
	burning_enemy_hp_regen_bonus = 0

func _count_living_enemies() -> int:
	var count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != null and is_instance_valid(enemy) and enemy.visible and int(enemy.get("hp")) > 0:
			count += 1
	return count

func _count_burning_enemies() -> int:
	var count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible:
			continue
		if int(enemy.get("hp")) <= 0:
			continue
		if float(enemy.get("burn_timer")) > 0.0:
			count += 1
	return count

func reset_full_health_consumable_temp_hp_regen_bonus():
	if full_health_consumable_temp_hp_regen_bonus != 0:
		hp_regen -= full_health_consumable_temp_hp_regen_bonus
	full_health_consumable_temp_hp_regen_bonus = 0

func on_damage_taken(amount: int):
	if amount <= 0:
		return
	activate_damage_taken_speed_boost()
	trigger_low_health_explosion()
	reset_crystal_attack_speed_bonus()
	if damage_loss_on_hit_sources <= 0:
		return
	var loss = damage_loss_on_hit_amount * float(damage_loss_on_hit_sources)
	damage_percent_bonus -= loss
	damage_loss_on_hit_bonus += loss

func reset_damage_loss_on_hit_bonus():
	if not is_equal_approx(damage_loss_on_hit_bonus, 0.0):
		damage_percent_bonus += damage_loss_on_hit_bonus
	damage_loss_on_hit_bonus = 0.0

func apply_temporary_speed_delta(delta: float) -> float:
	var before = speed
	speed = max(100.0, speed + delta)
	return speed - before

func activate_consumable_damage_boost():
	if consumable_damage_boost_sources <= 0:
		return
	clear_consumable_damage_boost()
	consumable_damage_boost_bonus = consumable_damage_boost_amount * float(consumable_damage_boost_sources)
	damage_percent_bonus += consumable_damage_boost_bonus
	consumable_damage_boost_timer = consumable_damage_boost_duration

func clear_consumable_damage_boost():
	if not is_equal_approx(consumable_damage_boost_bonus, 0.0):
		damage_percent_bonus -= consumable_damage_boost_bonus
	consumable_damage_boost_bonus = 0.0
	consumable_damage_boost_timer = 0.0

func process_consumable_damage_boost(delta: float):
	if consumable_damage_boost_timer <= 0.0:
		return
	consumable_damage_boost_timer -= delta
	if consumable_damage_boost_timer <= 0.0:
		clear_consumable_damage_boost()

func activate_damage_taken_speed_boost():
	if damage_taken_speed_boost_sources <= 0:
		return
	clear_damage_taken_speed_boost()
	var requested = 300.0 * damage_taken_speed_boost_amount * float(damage_taken_speed_boost_sources)
	damage_taken_speed_boost_bonus = apply_temporary_speed_delta(requested)
	damage_taken_speed_boost_timer = damage_taken_speed_boost_duration

func clear_damage_taken_speed_boost():
	if not is_equal_approx(damage_taken_speed_boost_bonus, 0.0):
		apply_temporary_speed_delta(-damage_taken_speed_boost_bonus)
	damage_taken_speed_boost_bonus = 0.0
	damage_taken_speed_boost_timer = 0.0

func process_damage_taken_speed_boost(delta: float):
	if damage_taken_speed_boost_timer <= 0.0:
		return
	damage_taken_speed_boost_timer -= delta
	if damage_taken_speed_boost_timer <= 0.0:
		clear_damage_taken_speed_boost()

func process_periodic_knockback(delta: float):
	if periodic_knockback_sources <= 0:
		periodic_knockback_timer = 0.0
		return
	periodic_knockback_timer -= delta
	if periodic_knockback_timer > 0.0:
		return
	trigger_periodic_knockback()
	periodic_knockback_timer = periodic_knockback_interval

func trigger_periodic_knockback():
	if periodic_knockback_sources <= 0:
		return
	var radius = max(1.0, periodic_knockback_radius)
	var distance = max(1.0, periodic_knockback_distance + max(0.0, knockback_bonus))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible:
			continue
		if position.distance_to(enemy.position) > radius:
			continue
		var direction = enemy.position - position
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
		enemy.position += direction.normalized() * distance * float(periodic_knockback_sources)

func process_alien_eyes(delta: float):
	if alien_eyes_sources <= 0:
		alien_eyes_timer = 0.0
		return
	alien_eyes_timer += max(0.0, delta)
	while alien_eyes_timer >= alien_eyes_interval:
		alien_eyes_timer -= alien_eyes_interval
		fire_alien_eyes()

func fire_alien_eyes():
	if alien_eyes_sources <= 0:
		return
	var projectile_count = max(1, alien_eyes_projectile_count) * max(1, alien_eyes_sources)
	var amount = max(1, int(round(alien_eyes_base_damage + float(max_hp) * alien_eyes_max_hp_damage_coefficient)))
	var start_angle = randf() * TAU
	for i in range(projectile_count):
		var angle = start_angle + TAU * float(i) / float(projectile_count)
		spawn_catalog_projectile(position, Vector2.RIGHT.rotated(angle), amount, Color(0.6, 1.0, 0.4), 520.0, Vector2(0.75, 0.75))

func fire_enemy_corpse_bullet(source_enemy):
	if corpse_bullet_sources <= 0 or source_enemy == null or not is_instance_valid(source_enemy):
		return
	var origin = source_enemy.position
	var target = _find_nearest_visible_enemy(origin, source_enemy)
	var direction = Vector2.RIGHT
	if target != null:
		direction = target.position - origin
	if direction.length_squared() <= 0.01:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	var amount = max(1, int(round(corpse_bullet_base_damage + float(ranged_damage_bonus) * corpse_bullet_ranged_damage_coefficient)))
	var count = max(1, corpse_bullet_sources)
	for i in range(count):
		var shot_direction = direction.normalized()
		if count > 1:
			var offset = (float(i) - float(count - 1) * 0.5) * deg_to_rad(8.0)
			shot_direction = shot_direction.rotated(offset)
		spawn_catalog_projectile(origin, shot_direction, amount, Color(1.0, 0.95, 0.55), 560.0, Vector2(0.8, 0.8))

func spawn_catalog_projectile(origin: Vector2, direction: Vector2, amount: int, color: Color, speed_value: float = 520.0, bullet_scale_value: Vector2 = Vector2(1, 1)):
	var shot_direction = direction
	if shot_direction.length_squared() <= 0.01:
		shot_direction = Vector2.RIGHT
	var main_node = get_parent()
	var use_pool = main_node != null and is_instance_valid(main_node) and main_node.has_method("get_bullet")
	var bullet = main_node.get_bullet() if use_pool else bullet_scene.instantiate()
	bullet.activate(
		origin,
		shot_direction.normalized(),
		speed_value,
		color,
		self,
		max(1, int(amount)),
		false,
		false,
		false,
		0,
		false,
		false,
		bullet_scale_value
	)
	if not use_pool and main_node != null and is_instance_valid(main_node) and bullet.get_parent() == null:
		main_node.add_child(bullet)
	return bullet

func _find_nearest_visible_enemy(origin: Vector2, excluded_enemy = null):
	var closest = null
	var closest_distance = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == excluded_enemy:
			continue
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		if int(enemy.get("hp")) <= 0:
			continue
		var distance = origin.distance_to(enemy.position)
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	return closest

func process_torture_healing(delta: float):
	if torture_healing_sources <= 0:
		torture_heal_timer = 0.0
		return
	torture_heal_timer += delta
	while torture_heal_timer >= 1.0:
		torture_heal_timer -= 1.0
		force_heal(torture_heal_per_second * torture_healing_sources)
		if hp >= max_hp:
			torture_heal_timer = 0.0
			break

func reset_delayed_consumable_healing():
	delayed_consumable_heal_entries.clear()

func process_delayed_consumable_healing(delta: float):
	if delayed_consumable_heal_entries.is_empty():
		return
	var updated_entries: Array = []
	var duration = max(0.001, delayed_consumable_heal_duration)
	for entry in delayed_consumable_heal_entries:
		if not (entry is Dictionary):
			continue
		var amount = max(0, int(entry.get("amount", 0)))
		if amount <= 0:
			continue
		var elapsed = min(duration, float(entry.get("elapsed", 0.0)) + max(0.0, delta))
		var ticks_elapsed = min(int(ceil(duration)), int(floor(elapsed)))
		var healed = clamp(int(entry.get("healed", 0)), 0, amount)
		var last_tick = clamp(int(entry.get("ticks_elapsed", 0)), 0, ticks_elapsed)
		for tick in range(last_tick + 1, ticks_elapsed + 1):
			var target_healed = min(amount, int(floor(float(amount) * float(tick) / duration)))
			var heal_delta = max(0, target_healed - healed)
			if heal_delta > 0:
				heal(heal_delta)
				healed = target_healed
		if elapsed >= duration and healed < amount:
			heal(amount - healed)
			healed = amount
		if healed < amount:
			entry["elapsed"] = elapsed
			entry["ticks_elapsed"] = ticks_elapsed
			entry["healed"] = healed
			updated_entries.append(entry)
	delayed_consumable_heal_entries = updated_entries

func process_self_damage_over_time(delta: float):
	if self_damage_per_second_sources <= 0:
		self_damage_timer = 0.0
		return
	self_damage_timer += delta
	while self_damage_timer >= 1.0:
		self_damage_timer -= 1.0
		apply_self_damage_without_invulnerability(self_damage_per_second_sources)
		if hp <= 0:
			break

func apply_self_damage_without_invulnerability(amount: int):
	var damage = max(0, int(amount))
	if damage <= 0 or hp <= 0:
		return
	hp -= damage
	total_damage_taken += damage
	damage_events.append(Time.get_ticks_msec() / 1000.0)
	hurt.emit()
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()

func recalculate_lifesteal_scaling_damage():
	var next_bonus = 0.0
	if lifesteal_scaling_damage_sources > 0 and lifesteal > 0.0:
		next_bonus = max(0.0, lifesteal) * 2.0 * float(lifesteal_scaling_damage_sources)
	var delta = next_bonus - lifesteal_scaling_damage_bonus
	if not is_equal_approx(delta, 0.0):
		damage_percent_bonus += delta
	lifesteal_scaling_damage_bonus = next_bonus

func get_structure_attack_speed_multiplier() -> float:
	var bonus = structure_attack_speed_percent
	if structures_scale_with_player_attack_speed_sources > 0:
		bonus += (fire_rate_multiplier - 1.0) * float(structures_scale_with_player_attack_speed_sources)
	return max(0.05, 1.0 + bonus)

func get_structure_attack_interval(base_interval: float) -> float:
	return max(0.05, float(base_interval) / get_structure_attack_speed_multiplier())

func update_stand_still_item_bonuses():
	var active = velocity.length_squared() <= 0.01
	_apply_stand_still_armor_bonus((8 * stand_still_armor_sources) if active else 0)
	_apply_stand_still_attack_speed_bonus((0.40 * float(stand_still_attack_speed_sources)) if active else 0.0)
	_apply_stand_still_dodge_bonus((0.20 * float(stand_still_dodge_sources)) if active else 0.0)
	_apply_stand_still_hp_regen_bonus((10 * stand_still_hp_regen_sources) if active else 0)

func _apply_stand_still_armor_bonus(target_bonus: int):
	var delta = int(target_bonus) - stand_still_armor_bonus
	if delta == 0:
		return
	armor += delta
	stand_still_armor_bonus += delta
	if has_method("recalculate_armor_scaling_max_hp"):
		recalculate_armor_scaling_max_hp()

func _apply_stand_still_attack_speed_bonus(target_bonus: float):
	var desired_delta = float(target_bonus) - stand_still_attack_speed_bonus
	if is_equal_approx(desired_delta, 0.0):
		return
	var before = fire_rate_multiplier
	fire_rate_multiplier = max(0.1, fire_rate_multiplier + desired_delta)
	stand_still_attack_speed_bonus += fire_rate_multiplier - before

func _apply_stand_still_dodge_bonus(target_bonus: float):
	var desired_delta = float(target_bonus) - stand_still_dodge_bonus
	if is_equal_approx(desired_delta, 0.0):
		return
	var before = dodge_chance
	if desired_delta > 0.0:
		dodge_chance = min(dodge_chance + desired_delta, dodge_cap)
	else:
		dodge_chance = max(0.0, dodge_chance + desired_delta)
	stand_still_dodge_bonus += dodge_chance - before
	if has_method("recalculate_dodge_scaling_attack_speed"):
		recalculate_dodge_scaling_attack_speed()

func _apply_stand_still_hp_regen_bonus(target_bonus: int):
	var delta = int(target_bonus) - stand_still_hp_regen_bonus
	if delta == 0:
		return
	hp_regen += delta
	stand_still_hp_regen_bonus += delta

func apply_max_hp_delta(delta: int, heal_positive: bool = true, respect_cap: bool = true) -> int:
	var requested = int(delta)
	var actual = requested
	if respect_cap and requested > 0 and max_hp_cap_sources > 0:
		actual = min(requested, max(0, max_hp_cap_value - max_hp))
	if actual == 0:
		return 0
	var before = max_hp
	max_hp = max(1, max_hp + actual)
	actual = max_hp - before
	if actual > 0 and heal_positive:
		hp = min(hp + actual, max_hp)
	else:
		hp = min(hp, max_hp)
	hp_changed.emit(hp, max_hp)
	return actual

func apply_speed_delta(delta: float, respect_cap: bool = true) -> float:
	var requested = float(delta)
	var actual = requested
	if respect_cap and requested > 0.0 and speed_cap_sources > 0:
		actual = min(requested, max(0.0, speed_cap_value - base_speed))
	if is_equal_approx(actual, 0.0):
		return 0.0
	var before_base = base_speed
	base_speed = max(100.0, base_speed + actual)
	actual = base_speed - before_base
	speed = max(100.0, speed + actual)
	return actual

func apply_piggy_bank_start_wave_materials(current_wave: int):
	if piggy_bank_sources <= 0:
		return
	if current_wave <= 0 or current_wave > piggy_bank_wave_limit:
		return
	var held_materials = economy.materials if economy != null else gold
	var gained = int(floor(float(max(0, held_materials)) * piggy_bank_growth_percent * float(piggy_bank_sources)))
	if gained <= 0:
		return
	earn_gold(gained)

func get_distinct_weapon_count() -> int:
	var seen := {}
	for weapon in equipped_weapons:
		var weapon_type = str(weapon.get("type", ""))
		if weapon_type != "":
			seen[weapon_type] = true
	return seen.size()

func record_catalog_item_ownership(upgrade: Dictionary, direction: float):
	if str(upgrade.get("type", "")) != "catalog_item":
		return
	var source_id = str(upgrade.get("source_id", ""))
	if source_id == "":
		return
	var tier = int(upgrade.get("tier", int(upgrade.get("rolled_rarity", upgrade.get("rarity", 0))) + 1))
	tier = clamp(tier, 1, 4)
	var tier_key = str(tier)
	if not catalog_owned_item_tier_counts.has(tier_key):
		catalog_owned_item_tier_counts[tier_key] = {}
	var tier_counts: Dictionary = catalog_owned_item_tier_counts[tier_key]
	var next_count = max(0, int(tier_counts.get(source_id, 0)) + int(round(direction)))
	if next_count <= 0:
		tier_counts.erase(source_id)
	else:
		tier_counts[source_id] = next_count
	if tier_counts.is_empty():
		catalog_owned_item_tier_counts.erase(tier_key)
	else:
		catalog_owned_item_tier_counts[tier_key] = tier_counts
	recalculate_fairy_item_tier_regeneration()

func get_distinct_owned_item_count_for_tier(tier: int) -> int:
	var tier_key = str(clamp(tier, 1, 4))
	if not catalog_owned_item_tier_counts.has(tier_key):
		return 0
	var tier_counts = catalog_owned_item_tier_counts[tier_key]
	return tier_counts.size() if tier_counts is Dictionary else 0

func get_catalog_item_owned_count(source_id: String) -> int:
	var count = 0
	for tier_key in catalog_owned_item_tier_counts:
		var tier_counts = catalog_owned_item_tier_counts[tier_key]
		if tier_counts is Dictionary:
			count += int(tier_counts.get(source_id, 0))
	return count

func can_receive_catalog_item_duplicate(upgrade: Dictionary) -> bool:
	if str(upgrade.get("type", "")) != "catalog_item":
		return false
	var source_id = str(upgrade.get("source_id", ""))
	if source_id == "":
		return false
	var limit_value = upgrade.get("limit", null)
	if limit_value == null:
		return true
	var limit = int(limit_value)
	if limit <= 0:
		return false
	return get_catalog_item_owned_count(source_id) < limit

func consume_mirror_duplicate_for_shop_item(upgrade: Dictionary) -> bool:
	if mirror_duplicate_next_shop_item_pending <= 0:
		return false
	if str(upgrade.get("type", "")) != "catalog_item":
		return false
	var source_id = str(upgrade.get("source_id", ""))
	if source_id in ["mirror", "broken_mirror", "resting_goldfish"]:
		return false
	mirror_duplicate_next_shop_item_pending = max(0, mirror_duplicate_next_shop_item_pending - 1)
	if not can_receive_catalog_item_duplicate(upgrade):
		return false
	var duplicate = upgrade.duplicate(true)
	duplicate["mirror_duplicate"] = true
	apply_upgrade(duplicate)
	broken_mirror_duplicated_item_sources += 1
	return true

func recalculate_fairy_item_tier_regeneration():
	var next_bonus = 0
	if fairy_tier1_regen_sources > 0:
		next_bonus += get_distinct_owned_item_count_for_tier(1) * fairy_tier1_regen_sources
	if fairy_tier4_regen_sources > 0:
		next_bonus -= get_distinct_owned_item_count_for_tier(4) * 3 * fairy_tier4_regen_sources
	var delta = next_bonus - fairy_item_tier_regen_bonus
	if delta != 0:
		hp_regen += delta
	fairy_item_tier_regen_bonus = next_bonus

func recalculate_distinct_weapon_scaling():
	var distinct_count = get_distinct_weapon_count()
	var next_max_hp_bonus = distinct_count * distinct_weapon_max_hp_sources
	var max_hp_delta = next_max_hp_bonus - distinct_weapon_max_hp_bonus
	if max_hp_delta != 0:
		var actual_delta = apply_max_hp_delta(max_hp_delta)
		distinct_weapon_max_hp_bonus += actual_delta

	var next_attack_speed_bonus = float(distinct_count) * distinct_weapon_attack_speed_per_weapon
	var attack_speed_delta = next_attack_speed_bonus - distinct_weapon_attack_speed_bonus
	if not is_equal_approx(attack_speed_delta, 0.0):
		var before = fire_rate_multiplier
		fire_rate_multiplier = max(0.1, fire_rate_multiplier + attack_speed_delta)
		distinct_weapon_attack_speed_bonus += fire_rate_multiplier - before

func recalculate_negative_speed_regen():
	var next_bonus = 0
	if negative_speed_regen_sources > 0 and base_speed < 300.0:
		var negative_speed_percent = int(floor(((300.0 - base_speed) / 300.0) * 100.0 + 0.0001))
		next_bonus = max(0, negative_speed_percent) * 2 * negative_speed_regen_sources
	var delta = next_bonus - negative_speed_regen_bonus
	if delta != 0:
		hp_regen += delta
	negative_speed_regen_bonus = next_bonus

func recalculate_structure_engineering_penalty(structure_count: int = -1):
	if structure_engineering_penalty_sources <= 0 and structure_engineering_penalty_bonus == 0:
		return
	var count = structure_count
	if count < 0:
		count = _count_owned_structures()
	var next_penalty = 0
	if structure_engineering_penalty_sources > 0:
		next_penalty = -max(0, count) * structure_engineering_penalty_sources
	var delta = next_penalty - structure_engineering_penalty_bonus
	if delta != 0:
		engineering_bonus += delta
	structure_engineering_penalty_bonus = next_penalty

func _count_owned_structures() -> int:
	var main_node = get_parent()
	if main_node != null and is_instance_valid(main_node) and main_node.get("turret_manager") != null:
		var manager = main_node.get("turret_manager")
		var count = 0
		for property_name in ["active_turrets", "active_gardens", "active_landmines", "active_wandering_bots"]:
			var structures = manager.get(property_name)
			if not (structures is Array):
				continue
			for structure in structures:
				if structure != null and is_instance_valid(structure):
					count += 1
		return count
	var fallback_count = 0
	for structure in get_tree().get_nodes_in_group("structures"):
		if structure != null and is_instance_valid(structure):
			fallback_count += 1
	return fallback_count

func activate_next_wave_modifiers():
	if not is_equal_approx(next_wave_xp_gain_percent_pending, 0.0):
		xp_boost += next_wave_xp_gain_percent_pending
		next_wave_xp_gain_percent_active += next_wave_xp_gain_percent_pending
		next_wave_xp_gain_percent_pending = 0.0
	if not is_equal_approx(next_wave_enemy_health_percent_pending, 0.0):
		enemy_health_percent += next_wave_enemy_health_percent_pending
		next_wave_enemy_health_percent_active += next_wave_enemy_health_percent_pending
		next_wave_enemy_health_percent_pending = 0.0
	if not is_equal_approx(next_wave_enemy_damage_percent_pending, 0.0):
		enemy_damage_percent += next_wave_enemy_damage_percent_pending
		next_wave_enemy_damage_percent_active += next_wave_enemy_damage_percent_pending
		next_wave_enemy_damage_percent_pending = 0.0
	if not is_equal_approx(next_wave_enemy_speed_percent_pending, 0.0):
		enemy_speed_percent += next_wave_enemy_speed_percent_pending
		next_wave_enemy_speed_percent_active += next_wave_enemy_speed_percent_pending
		next_wave_enemy_speed_percent_pending = 0.0

func clear_next_wave_active_modifiers():
	if not is_equal_approx(next_wave_xp_gain_percent_active, 0.0):
		xp_boost = max(0.0, xp_boost - next_wave_xp_gain_percent_active)
		next_wave_xp_gain_percent_active = 0.0
	if not is_equal_approx(next_wave_enemy_health_percent_active, 0.0):
		enemy_health_percent = max(-0.95, enemy_health_percent - next_wave_enemy_health_percent_active)
		next_wave_enemy_health_percent_active = 0.0
	if not is_equal_approx(next_wave_enemy_damage_percent_active, 0.0):
		enemy_damage_percent = max(-0.95, enemy_damage_percent - next_wave_enemy_damage_percent_active)
		next_wave_enemy_damage_percent_active = 0.0
	if not is_equal_approx(next_wave_enemy_speed_percent_active, 0.0):
		enemy_speed_percent = max(-0.95, enemy_speed_percent - next_wave_enemy_speed_percent_active)
		next_wave_enemy_speed_percent_active = 0.0

func decrease_current_wave_count(amount: int = 1):
	var main_node = get_parent()
	if main_node == null or not is_instance_valid(main_node) or not ("wave" in main_node):
		return
	main_node.wave = max(1, int(main_node.wave) - max(1, int(amount)))
	if main_node.get("hud") != null and is_instance_valid(main_node.hud) and main_node.hud.has_method("update_wave"):
		main_node.hud.update_wave(main_node.wave, 20)

func recalculate_material_scaling_max_hp(materials_value: int = -1):
	var held_materials = materials_value
	if held_materials < 0:
		held_materials = economy.materials if economy != null else gold
	var next_bonus = 0
	if material_scaling_max_hp_sources > 0 and material_scaling_max_hp_per_source_materials > 0:
		next_bonus = int(floor(float(max(0, held_materials)) / float(material_scaling_max_hp_per_source_materials))) * material_scaling_max_hp_sources
	var delta = next_bonus - material_scaling_max_hp_bonus
	if delta != 0:
		var actual_delta = apply_max_hp_delta(delta)
		material_scaling_max_hp_bonus += actual_delta

func recalculate_knockback_scaling_damage():
	var next_bonus = 0.0
	if knockback_scaling_damage_sources > 0:
		next_bonus = max(0.0, float(knockback_bonus)) * 0.01 * float(knockback_scaling_damage_sources)
	var delta = next_bonus - knockback_scaling_damage_bonus
	if not is_equal_approx(delta, 0.0):
		damage_percent_bonus += delta
	knockback_scaling_damage_bonus = next_bonus

func recalculate_speed_scaling_damage():
	var next_bonus = 0.0
	if speed_scaling_damage_sources > 0 and base_speed > 300.0:
		next_bonus = ((base_speed - 300.0) / 300.0) * float(speed_scaling_damage_sources)
	var delta = next_bonus - speed_scaling_damage_bonus
	if not is_equal_approx(delta, 0.0):
		damage_percent_bonus += delta
	speed_scaling_damage_bonus = next_bonus

func recalculate_dodge_scaling_attack_speed():
	var next_bonus = 0.0
	if dodge_scaling_attack_speed_sources > 0 and dodge_chance > 0.0:
		next_bonus = dodge_chance * 2.0 * float(dodge_scaling_attack_speed_sources)
	var delta = next_bonus - dodge_scaling_attack_speed_bonus
	if not is_equal_approx(delta, 0.0):
		fire_rate_multiplier = max(0.1, fire_rate_multiplier + delta)
	dodge_scaling_attack_speed_bonus = next_bonus

func recalculate_armor_scaling_max_hp():
	var next_bonus = 0
	if armor_scaling_max_hp_sources > 0 and armor > 0:
		next_bonus = max(0, armor) * armor_scaling_max_hp_sources
	var delta = next_bonus - armor_scaling_max_hp_bonus
	if delta != 0:
		var actual_delta = apply_max_hp_delta(delta)
		armor_scaling_max_hp_bonus += actual_delta

func recalculate_elemental_scaling_engineering():
	var next_bonus = 0
	if elemental_scaling_engineering_sources > 0 and elemental_damage_bonus > 0:
		next_bonus = max(0, elemental_damage_bonus) * elemental_scaling_engineering_sources
	var delta = next_bonus - elemental_scaling_engineering_bonus
	if delta != 0:
		engineering_bonus += delta
	elemental_scaling_engineering_bonus = next_bonus

func _deal_material_pickup_luck_damage():
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != null and is_instance_valid(enemy) and enemy.visible and enemy.has_method("take_damage") and int(enemy.get("hp")) > 0:
			candidates.append(enemy)
	if candidates.is_empty():
		return
	var target = candidates[randi() % candidates.size()]
	var amount = max(1, int(round(material_pickup_luck_damage_base + float(luck) * material_pickup_luck_damage_coefficient)))
	target.take_damage(amount)
	total_damage_dealt += amount

func _deal_enemy_death_luck_damage(excluded_enemy = null):
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if excluded_enemy != null and enemy == excluded_enemy:
			continue
		if enemy != null and is_instance_valid(enemy) and enemy.visible and enemy.has_method("take_damage") and int(enemy.get("hp")) > 0:
			candidates.append(enemy)
	if candidates.is_empty():
		return
	var target = candidates[randi() % candidates.size()]
	var amount = max(1, int(round(enemy_death_luck_damage_base + float(luck) * enemy_death_luck_damage_coefficient)))
	target.take_damage(amount)
	total_damage_dealt += amount

func _deal_enemy_death_explosion(source_enemy):
	if source_enemy == null or not is_instance_valid(source_enemy):
		return
	var amount = max(1, int(round(enemy_death_explosion_base + float(melee_damage_bonus) * enemy_death_explosion_melee_coefficient)))
	Effects.death_burst(source_enemy.position, Color(1.0, 0.45, 0.1))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == source_enemy:
			continue
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		if int(enemy.get("hp")) <= 0:
			continue
		if source_enemy.position.distance_to(enemy.position) > enemy_death_explosion_radius:
			continue
		enemy.take_damage(amount)
		total_damage_dealt += amount

func on_enemy_hit_by_attack(enemy, context: Dictionary = {}):
	# 远程武器专属命中效果：子弹命中时会把发射它的武器身份放在 context 里。
	# （近战不走这里 —— _fire_melee() 直接调 combat._apply_weapon_hit_effects()）
	if context.has("weapon_runtime_id") and combat != null:
		combat.apply_ranged_weapon_hit_effects(
			int(context.get("weapon_runtime_id", 0)),
			enemy,
			int(context.get("damage", 0)),
			bool(context.get("is_crit", false))
		)
	if hit_explosion_chance > 0.0 and enemy != null and is_instance_valid(enemy):
		var roll = randf()
		if roll < hit_explosion_chance:
			deal_hit_explosion(enemy)
	if burn_on_hit_chance > 0.0 and enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_burn"):
		if randf() < burn_on_hit_chance:
			enemy.apply_burn(self)
			on_enemy_burn_applied(enemy)
	if hit_enemy_slow_percent_per_hit <= 0.0 or hit_enemy_slow_percent_max <= 0.0:
		return
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_catalog_hit_slow"):
		enemy.apply_catalog_hit_slow(hit_enemy_slow_percent_per_hit, hit_enemy_slow_percent_max)

func on_enemy_burn_applied(enemy):
	if burn_spread_sources <= 0:
		return
	_spread_burn_from_enemy(enemy)

func _spread_burn_from_enemy(source_enemy):
	if source_enemy == null or not is_instance_valid(source_enemy):
		return
	var closest = null
	var closest_distance = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == source_enemy:
			continue
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("apply_burn"):
			continue
		if int(enemy.get("hp")) <= 0 or float(enemy.get("burn_timer")) > 0.0:
			continue
		var distance = source_enemy.position.distance_to(enemy.position)
		if distance <= burn_spread_radius and distance < closest_distance:
			closest = enemy
			closest_distance = distance
	if closest != null:
		closest.apply_burn()

func on_damage_dodged():
	if dodge_heal_chance > 0.0 and dodge_heal_amount > 0 and randf() < dodge_heal_chance:
		heal(dodge_heal_amount)
	if dodge_damage_chance > 0.0 and randf() < dodge_damage_chance:
		_deal_dodge_melee_damage()

func _deal_dodge_melee_damage():
	var closest = null
	var closest_distance = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		if int(enemy.get("hp")) <= 0:
			continue
		var distance = position.distance_to(enemy.position)
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	if closest == null:
		return
	var amount = max(1, int(round(dodge_damage_base + float(melee_damage_bonus) * dodge_damage_melee_coefficient)))
	closest.take_damage(amount)
	total_damage_dealt += amount

func on_wave_end():
	if combat != null:
		combat.on_wave_end()
	if status != null:
		status.clear()
	clear_next_wave_active_modifiers()
	if not is_equal_approx(end_wave_harvesting_growth_percent, 0.0) and gold_per_wave > 0:
		gold_per_wave += int(floor(float(gold_per_wave) * end_wave_harvesting_growth_percent))
	if not is_equal_approx(end_wave_xp_gain_percent, 0.0):
		xp_boost = max(0.0, xp_boost + end_wave_xp_gain_percent)
	if end_wave_damage_percent_sources > 0:
		damage_percent_bonus += 0.03 * float(end_wave_damage_percent_sources)
	if end_wave_hp_regen_gain_sources > 0:
		hp_regen += end_wave_hp_regen_gain_sources
	if end_wave_lifesteal_gain_sources > 0:
		lifesteal = min(0.5, lifesteal + 0.01 * float(end_wave_lifesteal_gain_sources))
		recalculate_lifesteal_scaling_damage()
	if end_wave_melee_damage_gain_sources > 0:
		melee_damage_bonus += 3 * end_wave_melee_damage_gain_sources
	if end_wave_engineering_gain_sources > 0:
		engineering_bonus += 3 * end_wave_engineering_gain_sources
	if end_wave_armor_loss_sources > 0:
		armor -= end_wave_armor_loss_sources
		if has_method("recalculate_armor_scaling_max_hp"):
			recalculate_armor_scaling_max_hp()
	if end_wave_range_delta != 0:
		range_bonus += end_wave_range_delta

	var max_hp_delta = (3 * end_wave_max_hp_gain_sources) - end_wave_max_hp_loss_sources
	if max_hp_delta != 0:
		apply_max_hp_delta(max_hp_delta)

func on_level_up(_new_level: int):
	if not level_up_catalog_stat_deltas.is_empty():
		_apply_level_up_catalog_stat_deltas()
	if level_up_curse_gain_sources > 0:
		curse += level_up_curse_gain_sources
	if level_up_hp_regen_gain_sources > 0:
		hp_regen += level_up_hp_regen_gain_sources
	if level_up_lifesteal_gain_sources > 0:
		lifesteal = min(0.5, lifesteal + 0.01 * float(level_up_lifesteal_gain_sources))
		recalculate_lifesteal_scaling_damage()
	if level_up_max_hp_loss_sources > 0:
		apply_max_hp_delta(-level_up_max_hp_loss_sources)

func _apply_level_up_catalog_stat_deltas():
	var changed = false
	for stat in level_up_catalog_stat_deltas.keys():
		var stat_id = str(stat)
		var delta = float(level_up_catalog_stat_deltas.get(stat_id, 0.0))
		if is_equal_approx(delta, 0.0):
			continue
		_set_primary_stat_display_value(stat_id, _get_primary_stat_display_value(stat_id) + delta)
		changed = true
	if changed:
		_refresh_primary_stat_dependencies()

func on_wave_start(current_wave: int = 0):
	if combat != null:
		combat.on_wave_start()
	# 元素状态只在波内有效，不带进商店或下一波
	if status != null:
		status.clear()
	nullify_hits_remaining = nullify_hits_per_wave
	reset_wisdom_damage_bonus()
	reset_medikit_hp_regen_bonus()
	reset_crystal_attack_speed_bonus()
	reset_living_enemy_attack_speed_bonus()
	reset_burning_enemy_hp_regen_bonus()
	reset_burning_kill_elemental_damage_wave_bonus()
	low_health_explosion_triggered_this_wave = false
	reset_full_health_consumable_temp_hp_regen_bonus()
	reset_damage_loss_on_hit_bonus()
	clear_consumable_damage_boost()
	clear_damage_taken_speed_boost()
	full_health_consumable_max_hp_gained_this_wave = 0
	apply_candy_bag_wave_random_stat()
	apply_piggy_bank_start_wave_materials(current_wave)
	activate_next_wave_modifiers()
	if not is_equal_approx(wave_start_hp_percent_delta, 0.0):
		var hp_multiplier = max(0.0, 1.0 + wave_start_hp_percent_delta)
		hp = clamp(int(ceil(float(max_hp) * hp_multiplier)), 1, max_hp)
		hp_changed.emit(hp, max_hp)
	if start_next_wave_with_one_hp_sources > 0:
		start_next_wave_with_one_hp_sources = 0
		hp = 1
		hp_changed.emit(hp, max_hp)
	buffs.on_wave_start()

func wave_regen():
	buffs.wave_regen()

func get_recent_damage_count(window: float) -> int:
	return stats_module.get_recent_damage_count(window)
