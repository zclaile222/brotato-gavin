extends SceneTree

var failures: Array[String] = []
var shop = null
var player = null
var main = null

func _init():
	call_deferred("_run")

func _run():
	var game_state = root.get_node("/root/GameState")
	game_state.selected_character = "normal"
	game_state.difficulty = 1
	game_state.endless_mode = false
	var audio_manager = root.get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		root.remove_child(audio_manager)
		audio_manager.queue_free()
	_preload_script_classes()

	await _check_shop_uses_brotato_item_catalog()
	await _check_catalog_item_stat_deltas_apply_to_player()
	await _check_catalog_economy_stat_deltas_affect_shop_rules()
	await _check_catalog_enemy_and_material_modifiers_affect_runtime()
	await _check_catalog_loot_alien_items()
	await _check_catalog_nightmare_fog_visibility_items()
	await _check_catalog_lantern_periodic_knockback()
	await _check_catalog_bag_crate_material_bonus()
	await _check_catalog_shop_reroll_and_crate_reward_items()
	await _check_catalog_goldfish_next_reroll_tier_bonus()
	await _check_catalog_fish_hook_locked_shop_curse()
	await _check_catalog_mirror_and_post_use_state_items()
	await _check_catalog_bone_dice_shop_reroll_stat_mutation()
	await _check_catalog_axolotl_primary_stat_swap()
	await _check_catalog_anvil_shop_entry_weapon_upgrade()
	await _check_catalog_tree_spawn_and_lumberjack_shirt()
	await _check_catalog_fruit_basket_and_garden_consumables()
	await _check_catalog_spicy_sauce_consumable_explosion()
	await _check_catalog_turret_and_landmines_structures()
	await _check_catalog_curse_and_builders_turret_runtime()
	await _check_catalog_engineering_turret_variants()
	await _check_catalog_structure_crit_and_tree_factory()
	await _check_catalog_tyler_and_wandering_bot_structures()
	await _check_catalog_extra_stomach_full_health_consumable_max_hp()
	await _check_catalog_penguin_full_health_consumable_hp_regeneration()
	await _check_catalog_jerky_delayed_consumable_healing()
	await _check_catalog_padding_material_scaling_max_hp()
	await _check_catalog_triangle_of_power_damage_loss_on_hit()
	await _check_catalog_explosion_stat_modifiers()
	await _check_catalog_kraken_eye_and_sunken_bell_explosions()
	await _check_catalog_small_fish_high_health_damage()
	await _check_catalog_weapon_cooldown_and_critical_pierce_items()
	await _check_catalog_knot_weapon_upgrade_lock()
	await _check_catalog_coil_knockback_scaling_damage()
	await _check_catalog_stat_scaling_items()
	await _check_catalog_fairy_item_tier_regeneration()
	await _check_catalog_dynamic_weapon_and_speed_scaling_items()
	await _check_catalog_structure_attack_speed_items()
	await _check_catalog_stand_still_items()
	await _check_catalog_next_wave_and_growth_items()
	await _check_catalog_bait_and_hourglass_wave_items()
	await _check_catalog_candy_bag_wave_stat_and_elite_items()
	await _check_catalog_triggered_bonus_items()
	await _check_catalog_self_damage_and_lifesteal_scaling_items()
	await _check_catalog_end_wave_stat_items()
	await _check_catalog_level_up_stat_items()
	await _check_catalog_barnacle_and_lighthouse_level_structure_items()
	await _check_catalog_projectile_pierce_specials()
	await _check_catalog_pumpkin_piercing_cap()
	await _check_catalog_ricochet_and_seashell_projectiles()
	await _check_catalog_alien_eyes_and_baby_beard_projectiles()
	await _check_catalog_silver_bullet_boss_elite_damage()
	await _check_catalog_giant_belt_critical_current_hp_damage()
	await _check_catalog_lucky_coin_crit_scaling_luck()
	await _check_catalog_pearl_luck_damage_and_crate_reward()
	await _check_catalog_wisdom_timed_damage_growth()
	await _check_catalog_medikit_timed_hp_regeneration_growth()
	await _check_catalog_engineering_weapon_and_crystal_items()
	await _check_catalog_living_and_burning_enemy_scaling_items()
	await _check_catalog_ugly_tooth_hit_slow()
	await _check_catalog_scared_sausage_burn_on_hit()
	await _check_catalog_burning_speed_and_elemental_weapon_items()
	await _check_catalog_ice_cube_and_greek_fire_elemental_items()
	await _check_catalog_snake_burn_spread()
	await _check_catalog_adrenaline_dodge_heal()
	await _check_catalog_riposte_dodge_damage()
	await _check_catalog_regeneration_potion_low_health_regen()
	await _check_catalog_torture_fixed_healing()
	await _check_catalog_ghost_outfit_dodge_cap()
	await _check_catalog_tardigrade_hit_nullify()
	await _check_catalog_sad_tomato_wave_start_hp()
	await _check_catalog_weird_ghost_wave_start_one_hp()
	await _check_catalog_restrictive_start_wave_items()
	await _check_catalog_tentacle_crit_kill_heal()
	await _check_catalog_hunting_trophy_crit_kill_material()
	await _check_catalog_baby_gecko_material_drop_attract()
	await _check_catalog_baby_elephant_material_pickup_damage()
	await _check_catalog_cyberball_enemy_death_damage()
	await _check_catalog_black_flag_and_will_o_wisp_kill_items()
	await _check_catalog_goblet_enemy_kill_heal()
	await _check_catalog_rip_and_tear_enemy_death_explosion()
	await _check_catalog_material_pickup_specials()

	if is_instance_valid(shop):
		shop.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(main):
		main.queue_free()
	for i in range(5):
		await process_frame

	if failures.is_empty():
		print("PHASE_D4_CATALOG_ITEM_RUNTIME_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _preload_script_classes():
	for path in [
		"res://scripts/BrotatoData.gd",
		"res://scripts/WeaponData.gd",
		"res://scripts/WeaponDatabase.gd",
		"res://scripts/ShopRules.gd",
		"res://scripts/LootRules.gd",
		"res://scripts/RunEconomy.gd",
		"res://scripts/PlayerCore.gd",
		"res://scripts/PlayerCombat.gd",
		"res://scripts/PlayerUpgrades.gd",
		"res://scripts/PlayerBuffs.gd",
		"res://scripts/PlayerStats.gd",
		"res://scripts/UpgradeChoiceRules.gd",
		"res://scripts/HUDCore.gd",
		"res://scripts/HUDCombat.gd",
		"res://scripts/HUDPanels.gd",
		"res://scripts/WaveManager.gd",
		"res://scripts/PickupManager.gd",
		"res://scripts/TurretManager.gd",
		"res://scripts/EventManager.gd",
	]:
		var script = load(path)
		if script == null:
			failures.append("Failed to preload script class: " + path)

func _check_shop_uses_brotato_item_catalog():
	var packed = load("res://scenes/Shop.tscn")
	if packed == null:
		failures.append("Shop scene missing")
		return
	shop = packed.instantiate()
	root.add_child(shop)
	await process_frame
	var catalog_items: Array = []
	var has_legacy_chinese_passive := false
	for item in shop.ITEM_POOL:
		if item.get("type", "") == "catalog_item":
			catalog_items.append(item)
		if item.get("name", "") in ["急救包", "跑鞋", "火焰附魔"]:
			has_legacy_chinese_passive = true
	if catalog_items.size() < 90:
		failures.append("Shop should use BrotatoData catalog items instead of the legacy passive pool")
	if has_legacy_chinese_passive:
		failures.append("Shop ITEM_POOL should not expose legacy custom passive entries when the Brotato catalog loads")
	var acid = _find_by_source_id(catalog_items, "acid")
	if acid.is_empty():
		failures.append("Shop catalog item pool should include Acid")
	else:
		if acid.get("desc", "") == "Catalog item":
			failures.append("Catalog item shop entries should expose effect text, not a placeholder description")
		if not _has_stat_delta(acid.get("effects", []), "max_hp", 8.0):
			failures.append("Acid shop entry should preserve its max HP effect")

func _check_catalog_item_stat_deltas_apply_to_player():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog: " + str(errors))
		return
	var acid = _find_by_source_id(data.get_shop_pool(false), "acid")
	if acid.is_empty():
		failures.append("BrotatoData runtime shop pool should include Acid")
		return
	var packed = load("res://scenes/Player.tscn")
	if packed == null:
		failures.append("Player scene missing")
		return
	player = packed.instantiate()
	root.add_child(player)
	await process_frame
	var before_max_hp = int(player.max_hp)
	var before_hp = int(player.hp)
	var before_dodge = float(player.dodge_chance)
	player.apply_upgrade(acid)
	if int(player.max_hp) != before_max_hp + 8:
		failures.append("Applying Acid should increase player max HP by 8")
	if int(player.hp) != before_hp + 8:
		failures.append("Positive catalog max HP should heal by the same amount for current runtime compatibility")
	if not is_equal_approx(float(player.dodge_chance), before_dodge - 0.02):
		failures.append("Applying Acid should reduce dodge chance by 2 percentage points")
	var stat_modifiers = player.get("catalog_stat_modifiers")
	if not (stat_modifiers is Dictionary) or not is_equal_approx(float(stat_modifiers.get("knockback", 0.0)), -2.0):
		failures.append("Applying Acid should retain unsupported knockback delta in catalog_stat_modifiers")
	player.remove_upgrade(acid)
	if int(player.max_hp) != before_max_hp:
		failures.append("Removing Acid should restore player max HP")
	if not is_equal_approx(float(player.dodge_chance), before_dodge):
		failures.append("Removing Acid should restore dodge chance")

func _check_catalog_economy_stat_deltas_affect_shop_rules():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for economy item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var coupon = _find_by_source_id(pool, "coupon")
	var spyglass = _find_by_source_id(pool, "spyglass")
	var recycling_machine = _find_by_source_id(pool, "recycling_machine")
	if coupon.is_empty():
		failures.append("Runtime shop pool should include Coupon item price modifier")
	if spyglass.is_empty():
		failures.append("Runtime shop pool should include Spyglass reroll price modifier")
	if recycling_machine.is_empty():
		failures.append("Runtime shop pool should include Recycling Machine recycle modifier")
	if coupon.is_empty() or spyglass.is_empty() or recycling_machine.is_empty():
		return

	var packed = load("res://scenes/Player.tscn")
	if packed == null:
		failures.append("Player scene missing for economy item check")
		return
	var economy_player = packed.instantiate()
	root.add_child(economy_player)
	await process_frame
	economy_player.apply_upgrade(coupon)
	economy_player.apply_upgrade(spyglass)
	economy_player.apply_upgrade(recycling_machine)
	if not is_equal_approx(float(economy_player.get("item_price_percent")), -0.05):
		failures.append("Coupon should apply item price percent discount to player")
	if not is_equal_approx(float(economy_player.get("reroll_price_percent")), -0.25):
		failures.append("Spyglass should apply reroll price percent discount to player")
	if not is_equal_approx(float(economy_player.get("recycling_materials_percent")), 0.35):
		failures.append("Recycling Machine should apply recycle material bonus to player")

	var rules = ShopRules.new()
	var normal_price = rules.get_price(100, 0, 1)
	var discounted_price = rules.callv("get_price", [100, 0, 1, float(economy_player.get("item_price_percent"))])
	if normal_price != 100 or discounted_price != 95:
		failures.append("ShopRules.get_price should apply item_price_percent modifier")
	var normal_reroll = rules.get_reroll_cost(3)
	var discounted_reroll = rules.callv("get_reroll_cost", [3, float(economy_player.get("reroll_price_percent"))])
	if normal_reroll != 20 or discounted_reroll != 15:
		failures.append("ShopRules.get_reroll_cost should apply reroll_price_percent modifier")

	var loot_rules = load("res://scripts/LootRules.gd").new()
	var normal_recycle = loot_rules.get_recycle_value(100, 0, 1, rules)
	var boosted_recycle = loot_rules.callv("get_recycle_value", [100, 0, 1, rules, float(economy_player.get("recycling_materials_percent"))])
	if normal_recycle != 25 or boosted_recycle != 33:
		failures.append("LootRules.get_recycle_value should apply recycling_materials_percent modifier")
	economy_player.queue_free()

func _check_catalog_enemy_and_material_modifiers_affect_runtime():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for enemy modifier check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var alien_baby = _find_by_source_id(pool, "alien_baby")
	var snail = _find_by_source_id(pool, "snail")
	var gentle_alien = _find_by_source_id(pool, "gentle_alien")
	var gobbler_hat = _find_by_source_id(pool, "gobbler_s_hat")
	var starfish = _find_by_source_id(pool, "starfish")
	if alien_baby.is_empty():
		failures.append("Runtime shop pool should include Alien Baby enemy health modifier")
	if snail.is_empty():
		failures.append("Runtime shop pool should include Snail enemy speed modifier")
	if gentle_alien.is_empty():
		failures.append("Runtime shop pool should include Gentle Alien enemy count modifier")
	if gobbler_hat.is_empty():
		failures.append("Runtime shop pool should include Gobbler's Hat material drop modifier")
	if starfish.is_empty():
		failures.append("Runtime shop pool should include Starfish enemy damage/material modifier")
	if alien_baby.is_empty() or snail.is_empty() or gentle_alien.is_empty() or gobbler_hat.is_empty() or starfish.is_empty():
		return

	var packed_player = load("res://scenes/Player.tscn")
	var modifier_player = packed_player.instantiate()
	root.add_child(modifier_player)
	await process_frame
	modifier_player.apply_upgrade(alien_baby)
	modifier_player.apply_upgrade(snail)
	modifier_player.apply_upgrade(gentle_alien)
	modifier_player.apply_upgrade(gobbler_hat)
	modifier_player.apply_upgrade(starfish)
	if not is_equal_approx(float(modifier_player.get("enemy_health_percent")), 0.10):
		failures.append("Alien Baby should apply enemy health percent to player")
	if not is_equal_approx(float(modifier_player.get("enemy_speed_percent")), -0.08):
		failures.append("Snail should apply enemy speed percent to player")
	if not is_equal_approx(float(modifier_player.get("enemies_percent")), 0.05):
		failures.append("Gentle Alien should apply enemies percent to player")
	if not is_equal_approx(float(modifier_player.get("materials_dropped_percent")), 0.90):
		failures.append("Gobbler's Hat and Starfish should stack material drop percent on player")
	if not is_equal_approx(float(modifier_player.get("enemy_damage_percent")), 0.15):
		failures.append("Starfish should apply enemy damage percent to player")

	var packed_main = load("res://scenes/Main.tscn")
	main = packed_main.instantiate()
	root.add_child(main)
	await process_frame
	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 9)
	var base_hp = int(enemy.hp)
	var base_speed = float(enemy.base_speed)
	var base_xp_drop = int(enemy.xp_drop)
	enemy.contact_damage = 20
	if not enemy.has_method("apply_catalog_modifiers"):
		failures.append("Enemy should expose apply_catalog_modifiers for catalog runtime scaling")
	else:
		enemy.call("apply_catalog_modifiers", modifier_player)
		if int(enemy.hp) != int(round(base_hp * 1.10)):
			failures.append("Enemy catalog modifier should scale HP from player enemy_health_percent")
		if not is_equal_approx(float(enemy.base_speed), base_speed * 0.92):
			failures.append("Enemy catalog modifier should scale speed from player enemy_speed_percent")
		if int(enemy.xp_drop) != int(round(float(base_xp_drop) * 1.90)):
			failures.append("Enemy catalog modifier should scale material drop value")
		if int(enemy.contact_damage) != 23:
			failures.append("Enemy catalog modifier should scale contact damage")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	var wave_manager = main.wave_manager
	if not wave_manager.has_method("get_spawn_interval"):
		failures.append("WaveManager should expose get_spawn_interval for enemies_percent scaling")
	else:
		var normal_interval = float(wave_manager.call("get_spawn_interval", 1, 1.0, 1.0, 0.0))
		var more_enemies_interval = float(wave_manager.call("get_spawn_interval", 1, 1.0, 1.0, 0.50))
		var fewer_enemies_interval = float(wave_manager.call("get_spawn_interval", 1, 1.0, 1.0, -0.50))
		if not (more_enemies_interval < normal_interval and fewer_enemies_interval > normal_interval):
			failures.append("WaveManager spawn interval should shrink/grow with enemies_percent")
	modifier_player.queue_free()

func _check_catalog_loot_alien_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for loot alien item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var whistle = _find_by_source_id(pool, "whistle")
	var lure = _find_by_source_id(pool, "lure")
	if whistle.is_empty():
		failures.append("Runtime shop pool should include Whistle loot alien modifier")
	if lure.is_empty():
		failures.append("Runtime shop pool should include Lure next-wave loot alien item")
	if whistle.is_empty() or lure.is_empty():
		return
	if not _has_stat_delta(whistle.get("effects", []), "loot_alien_chance_percent", 0.50):
		failures.append("Whistle should preserve +50 percent loot alien chance")
	if not _has_stat_delta(whistle.get("effects", []), "loot_alien_speed_percent", 0.20):
		failures.append("Whistle should preserve +20 percent loot alien speed")
	if not _has_stat_delta(lure.get("effects", []), "hp_regeneration", 2.0):
		failures.append("Lure should preserve +2 HP Regeneration")
	if not _has_weapon_special_rule_number(lure.get("effects", []), "next_wave_additional_loot_aliens", "count", 2.0):
		failures.append("Lure should preserve next-wave +2 loot aliens rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for loot alien item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for loot alien item check")
		return
	for required_property in [
		"loot_alien_chance_percent",
		"loot_alien_speed_percent",
		"next_wave_loot_alien_count_pending",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for loot alien runtime" % required_property)
			return
	for required_method in [
		"roll_loot_alien_bonus_spawn_count",
		"spawn_loot_alien",
		"_spawn_pending_loot_aliens_for_wave_start",
	]:
		if main.wave_manager == null or not main.wave_manager.has_method(required_method):
			failures.append("WaveManager should expose %s for loot alien runtime" % required_method)
			return

	var before_chance = float(runtime_player.get("loot_alien_chance_percent"))
	var before_speed = float(runtime_player.get("loot_alien_speed_percent"))
	var before_pending = int(runtime_player.get("next_wave_loot_alien_count_pending"))
	var before_hp_regen = int(runtime_player.hp_regen)
	runtime_player.apply_upgrade(whistle)
	runtime_player.apply_upgrade(lure)
	if not is_equal_approx(float(runtime_player.get("loot_alien_chance_percent")), before_chance + 0.50):
		failures.append("Applying Whistle should add +50 percent loot alien chance")
	if not is_equal_approx(float(runtime_player.get("loot_alien_speed_percent")), before_speed + 0.20):
		failures.append("Applying Whistle should add +20 percent loot alien speed")
	if int(runtime_player.get("next_wave_loot_alien_count_pending")) != before_pending + 2:
		failures.append("Applying Lure should queue two next-wave loot aliens")
	if int(runtime_player.hp_regen) != before_hp_regen + 2:
		failures.append("Applying Lure should add +2 HP Regeneration")
	if int(main.wave_manager.callv("roll_loot_alien_bonus_spawn_count", [0.49])) != 1:
		failures.append("Whistle should let loot alien chance roll spawn a bonus loot alien")
	if int(main.wave_manager.callv("roll_loot_alien_bonus_spawn_count", [0.51])) != 0:
		failures.append("Whistle should not spawn a bonus loot alien when the roll exceeds chance")

	_reset_enemy_pool(main)
	runtime_player.loot_alien_speed_percent = 0.0
	var base_loot_alien = main.wave_manager.spawn_loot_alien(Vector2(220, 200))
	var base_speed = float(base_loot_alien.base_speed) if base_loot_alien != null and is_instance_valid(base_loot_alien) else 0.0
	_reset_enemy_pool(main)
	runtime_player.loot_alien_speed_percent = 0.20
	var fast_loot_alien = main.wave_manager.spawn_loot_alien(Vector2(220, 200))
	if fast_loot_alien == null or not is_instance_valid(fast_loot_alien):
		failures.append("WaveManager.spawn_loot_alien should return a loot alien enemy")
	else:
		if str(fast_loot_alien.get("enemy_type")) != "loot_alien":
			failures.append("spawn_loot_alien should create a loot_alien enemy type")
		if not is_equal_approx(float(fast_loot_alien.base_speed), base_speed * 1.20):
			failures.append("Whistle loot alien speed modifier should affect spawned loot aliens")
	var loot_rules = LootRules.new()
	var loot_alien_drop = loot_rules.roll_pickup_kind("loot_alien", 0, 0)
	if str(loot_alien_drop.get("kind", "")) != "crate":
		failures.append("Loot aliens should drop a crate through LootRules")

	_reset_enemy_pool(main)
	runtime_player.next_wave_loot_alien_count_pending = 2
	main.wave_manager._spawn_pending_loot_aliens_for_wave_start()
	if _count_visible_enemies_of_type(main, "loot_alien") != 2:
		failures.append("Lure should spawn two queued loot aliens at wave start")
	if int(runtime_player.get("next_wave_loot_alien_count_pending")) != 0:
		failures.append("Wave-start loot alien spawn should consume Lure pending count")

	_reset_enemy_pool(main)
	runtime_player.remove_upgrade(lure)
	runtime_player.remove_upgrade(whistle)
	if not is_equal_approx(float(runtime_player.get("loot_alien_chance_percent")), before_chance):
		failures.append("Removing Whistle should restore loot alien chance")
	if not is_equal_approx(float(runtime_player.get("loot_alien_speed_percent")), before_speed):
		failures.append("Removing Whistle should restore loot alien speed")
	if int(runtime_player.hp_regen) != before_hp_regen:
		failures.append("Removing Lure should restore HP Regeneration")

func _check_catalog_nightmare_fog_visibility_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for nightmare fog item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var campfire = _find_by_source_id(pool, "campfire")
	var candle = _find_by_source_id(pool, "candle")
	if campfire.is_empty():
		failures.append("Runtime shop pool should include Campfire nightmare fog item")
	if candle.is_empty():
		failures.append("Runtime shop pool should include Candle nightmare fog item")
	if campfire.is_empty() or candle.is_empty():
		return
	if not _has_stat_delta(campfire.get("effects", []), "elemental_damage", 2.0):
		failures.append("Campfire should preserve +2 Elemental Damage")
	if not _has_stat_delta(campfire.get("effects", []), "hp_regeneration", 2.0):
		failures.append("Campfire should preserve +2 HP Regeneration")
	if not _has_stat_delta(campfire.get("effects", []), "speed_percent", -0.02):
		failures.append("Campfire should preserve -2 percent Speed")
	if not _has_weapon_special_rule(campfire.get("effects", []), "nightmare_fog_visibility_percent_plus_50"):
		failures.append("Campfire should preserve +50 percent nightmare fog visibility")
	if not _has_stat_delta(candle.get("effects", []), "elemental_damage", 4.0):
		failures.append("Candle should preserve +4 Elemental Damage")
	if not _has_stat_delta(candle.get("effects", []), "hp_regeneration", 1.0):
		failures.append("Candle should preserve +1 HP Regeneration")
	if not _has_stat_delta(candle.get("effects", []), "enemies_percent", -0.10):
		failures.append("Candle should preserve -10 percent Enemies")
	if not _has_stat_delta(candle.get("effects", []), "damage_percent", -0.05):
		failures.append("Candle should preserve -5 percent Damage")
	if not _has_weapon_special_rule(candle.get("effects", []), "nightmare_fog_visibility_percent_plus_25"):
		failures.append("Candle should preserve +25 percent nightmare fog visibility")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for nightmare fog item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for nightmare fog item check")
		return
	if runtime_player.get("nightmare_fog_visibility_percent") == null:
		failures.append("Player should expose nightmare_fog_visibility_percent")
		return

	var before_fog = float(runtime_player.get("nightmare_fog_visibility_percent"))
	var before_elemental = int(runtime_player.elemental_damage_bonus)
	var before_hp_regen = int(runtime_player.hp_regen)
	var before_speed = float(runtime_player.base_speed)
	var before_enemies = float(runtime_player.get("enemies_percent"))
	var before_damage = float(runtime_player.damage_percent_bonus)
	runtime_player.apply_upgrade(campfire)
	runtime_player.apply_upgrade(candle)
	if not is_equal_approx(float(runtime_player.get("nightmare_fog_visibility_percent")), before_fog + 0.75):
		failures.append("Campfire and Candle should stack nightmare fog visibility")
	if int(runtime_player.elemental_damage_bonus) != before_elemental + 6:
		failures.append("Campfire and Candle should apply +6 total Elemental Damage")
	if int(runtime_player.hp_regen) != before_hp_regen + 3:
		failures.append("Campfire and Candle should apply +3 total HP Regeneration")
	if not is_equal_approx(float(runtime_player.base_speed), before_speed - 6.0):
		failures.append("Campfire should apply -2 percent Speed from the 300 base")
	if not is_equal_approx(float(runtime_player.get("enemies_percent")), before_enemies - 0.10):
		failures.append("Candle should apply -10 percent Enemies")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.05):
		failures.append("Candle should apply -5 percent Damage")

	runtime_player.remove_upgrade(candle)
	runtime_player.remove_upgrade(campfire)
	if not is_equal_approx(float(runtime_player.get("nightmare_fog_visibility_percent")), before_fog):
		failures.append("Removing Campfire and Candle should restore nightmare fog visibility")
	if int(runtime_player.elemental_damage_bonus) != before_elemental:
		failures.append("Removing Campfire and Candle should restore Elemental Damage")
	if int(runtime_player.hp_regen) != before_hp_regen:
		failures.append("Removing Campfire and Candle should restore HP Regeneration")
	if not is_equal_approx(float(runtime_player.base_speed), before_speed):
		failures.append("Removing Campfire should restore Speed")
	if not is_equal_approx(float(runtime_player.get("enemies_percent")), before_enemies):
		failures.append("Removing Candle should restore Enemies")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Candle should restore Damage")

func _check_catalog_lantern_periodic_knockback():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Lantern check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var lantern = _find_by_source_id(pool, "lantern")
	if lantern.is_empty():
		failures.append("Runtime shop pool should include Lantern periodic knockback item")
		return
	if not _has_stat_delta(lantern.get("effects", []), "damage_percent", 0.10):
		failures.append("Lantern should preserve +10 percent Damage")
	if not _has_stat_delta(lantern.get("effects", []), "range", 50.0):
		failures.append("Lantern should preserve +50 Range")
	if not _has_stat_delta(lantern.get("effects", []), "knockback", 15.0):
		failures.append("Lantern should preserve +15 Knockback")
	if not _has_weapon_special_rule(lantern.get("effects", []), "knock_nearby_enemies_back_every_3_seconds"):
		failures.append("Lantern should preserve periodic nearby knockback rule")
	if not _has_weapon_special_rule(lantern.get("effects", []), "nightmare_fog_visibility_percent_plus_75"):
		failures.append("Lantern should preserve +75 percent nightmare fog visibility")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Lantern check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Lantern check")
		return
	for required_property in [
		"periodic_knockback_sources",
		"nightmare_fog_visibility_percent",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Lantern" % required_property)
			return
	if not runtime_player.has_method("trigger_periodic_knockback"):
		failures.append("Player should expose trigger_periodic_knockback for Lantern")
		return

	var before_sources = int(runtime_player.get("periodic_knockback_sources"))
	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_range = float(runtime_player.range_bonus)
	var before_knockback = float(runtime_player.knockback_bonus)
	var before_fog = float(runtime_player.get("nightmare_fog_visibility_percent"))
	runtime_player.apply_upgrade(lantern)
	if int(runtime_player.get("periodic_knockback_sources")) != before_sources + 1:
		failures.append("Applying Lantern should enable periodic knockback")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.10):
		failures.append("Applying Lantern should add +10 percent Damage")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range + 50.0):
		failures.append("Applying Lantern should add +50 Range")
	if not is_equal_approx(float(runtime_player.knockback_bonus), before_knockback + 15.0):
		failures.append("Applying Lantern should add +15 Knockback")
	if not is_equal_approx(float(runtime_player.get("nightmare_fog_visibility_percent")), before_fog + 0.75):
		failures.append("Applying Lantern should add +75 percent nightmare fog visibility")

	_reset_enemy_pool(main)
	runtime_player.position = Vector2(300, 300)
	var near_enemy = main.get_enemy()
	near_enemy.setup("normal", main.wave)
	near_enemy.position = runtime_player.position + Vector2(40, 0)
	var far_enemy = main.get_enemy()
	far_enemy.setup("normal", main.wave)
	far_enemy.position = runtime_player.position + Vector2(400, 0)
	var near_before = near_enemy.position
	var far_before = far_enemy.position
	runtime_player.trigger_periodic_knockback()
	if near_enemy.position.distance_to(runtime_player.position) <= near_before.distance_to(runtime_player.position):
		failures.append("Lantern periodic knockback should push nearby enemies away from the player")
	if not far_enemy.position.is_equal_approx(far_before):
		failures.append("Lantern periodic knockback should not move enemies outside its radius")

	_reset_enemy_pool(main)
	runtime_player.remove_upgrade(lantern)
	if int(runtime_player.get("periodic_knockback_sources")) != before_sources:
		failures.append("Removing Lantern should disable periodic knockback")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Lantern should restore Damage")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range):
		failures.append("Removing Lantern should restore Range")
	if not is_equal_approx(float(runtime_player.knockback_bonus), before_knockback):
		failures.append("Removing Lantern should restore Knockback")
	if not is_equal_approx(float(runtime_player.get("nightmare_fog_visibility_percent")), before_fog):
		failures.append("Removing Lantern should restore nightmare fog visibility")

func _check_catalog_bag_crate_material_bonus():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Bag special check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var bag = _find_by_source_id(pool, "bag")
	if bag.is_empty():
		failures.append("Runtime shop pool should include Bag crate material bonus")
		return
	if not _has_weapon_special_rule(bag.get("effects", []), "materials_plus_15_when_crate_pickup"):
		failures.append("Bag shop entry should preserve its crate material special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Bag crate material check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Bag crate material check")
		return
	if main.economy == null:
		failures.append("Main scene should expose RunEconomy for Bag crate material check")
		return
	if main.pickup_manager == null:
		failures.append("Main scene should expose PickupManager for Bag crate material check")
		return
	if runtime_player.get("crate_material_bonus") == null:
		failures.append("Player should expose crate_material_bonus for Bag")
		return

	main.pending_crate_rewards.clear()
	var before_bonus = int(runtime_player.get("crate_material_bonus"))
	var before_materials = int(main.economy.materials)
	runtime_player.apply_upgrade(bag)
	if int(runtime_player.get("crate_material_bonus")) != before_bonus + 15:
		failures.append("Applying Bag should add 15 crate material bonus to player")
	main.pickup_manager._spawn_pickup(runtime_player.position, "crate")
	if main.pickup_manager.active_pickup_nodes.is_empty():
		failures.append("Bag crate material check should be able to spawn a crate pickup")
		runtime_player.remove_upgrade(bag)
		return
	var crate = main.pickup_manager.active_pickup_nodes[main.pickup_manager.active_pickup_nodes.size() - 1]
	main.pickup_manager._on_pickup_collected(runtime_player, crate, "crate")
	await process_frame
	if int(main.economy.materials) != before_materials + 15:
		failures.append("Collecting a crate with Bag should grant 15 materials")
	if main.pending_crate_rewards.size() != 1:
		failures.append("Collecting a crate with Bag should still enqueue the crate reward")
	runtime_player.remove_upgrade(bag)
	if int(runtime_player.get("crate_material_bonus")) != before_bonus:
		failures.append("Removing Bag should restore crate material bonus")

func _check_catalog_shop_reroll_and_crate_reward_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for shop reroll/crate reward item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var dangerous_bunny = _find_by_source_id(pool, "dangerous_bunny")
	var treasure_map = _find_by_source_id(pool, "treasure_map")
	if dangerous_bunny.is_empty():
		failures.append("Runtime shop pool should include Dangerous Bunny free reroll modifier")
	if treasure_map.is_empty():
		failures.append("Runtime shop pool should include Treasure Map extra crate reward modifier")
	if dangerous_bunny.is_empty() or treasure_map.is_empty():
		return
	if not _has_weapon_special_rule(dangerous_bunny.get("effects", []), "one_free_shop_reroll"):
		failures.append("Dangerous Bunny should preserve free shop reroll special rule")
	if not _has_weapon_special_rule_chance(treasure_map.get("effects", []), "extra_item_chance_in_crate", 0.20):
		failures.append("Treasure Map should preserve 20 percent extra crate item chance")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for shop reroll/crate reward item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for shop reroll/crate reward item check")
		return
	if main.economy == null:
		failures.append("Main scene should expose RunEconomy for Dangerous Bunny check")
		return
	if main.shop == null:
		failures.append("Main scene should expose Shop for Dangerous Bunny check")
		return
	for required_property in [
		"free_shop_rerolls",
		"extra_crate_reward_chance",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for shop reroll/crate reward items" % required_property)
			return

	main.economy.reset(0)
	runtime_player.gold = 0
	runtime_player.apply_upgrade(dangerous_bunny)
	if int(runtime_player.get("free_shop_rerolls")) != 1:
		failures.append("Applying Dangerous Bunny should add one free shop reroll")
	main.shop.open(3, 0, 0, runtime_player)
	var before_reroll_index = int(main.shop.reroll_index)
	var before_materials = int(main.economy.materials)
	main.shop._on_reroll_pressed()
	if int(main.shop.reroll_index) != before_reroll_index + 1:
		failures.append("Dangerous Bunny should allow a shop reroll with no materials")
	if int(main.economy.materials) != before_materials:
		failures.append("Dangerous Bunny free reroll should not spend materials")
	if int(runtime_player.get("free_shop_rerolls")) != 0:
		failures.append("Dangerous Bunny free reroll should be consumed after use")
	main.shop._on_reroll_pressed()
	if int(main.shop.reroll_index) != before_reroll_index + 1:
		failures.append("After its free reroll is consumed, Dangerous Bunny should not reroll without materials")
	runtime_player.remove_upgrade(dangerous_bunny)
	if int(runtime_player.get("free_shop_rerolls")) != 0:
		failures.append("Removing Dangerous Bunny should not leave free rerolls behind")

	main.pending_crate_rewards.clear()
	runtime_player.apply_upgrade(treasure_map)
	if not is_equal_approx(float(runtime_player.get("extra_crate_reward_chance")), 0.20):
		failures.append("Applying Treasure Map should add 20 percent extra crate reward chance")
	runtime_player.extra_crate_reward_chance = 1.0
	main.enqueue_crate_reward(1)
	if main.pending_crate_rewards.size() != 2:
		failures.append("Guaranteed Treasure Map extra crate chance should enqueue a second crate reward")
	runtime_player.extra_crate_reward_chance = 0.20
	runtime_player.remove_upgrade(treasure_map)
	if not is_equal_approx(float(runtime_player.get("extra_crate_reward_chance")), 0.0):
		failures.append("Removing Treasure Map should restore extra crate reward chance")

func _check_catalog_goldfish_next_reroll_tier_bonus():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Goldfish check: " + str(errors))
		return
	var goldfish = _find_by_source_id(data.get_shop_pool(false), "goldfish")
	if goldfish.is_empty():
		failures.append("Runtime shop pool should include Goldfish next-reroll tier modifier")
		return
	if not _has_weapon_special_rule(goldfish.get("effects", []), "items_one_tier_higher_after_next_reroll"):
		failures.append("Goldfish should preserve next-reroll tier special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Goldfish next-reroll tier check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Goldfish check")
		return
	if main.shop == null:
		failures.append("Main scene should expose Shop for Goldfish check")
		return
	if runtime_player.get("shop_next_reroll_tier_bonus_pending") == null:
		failures.append("Player should expose shop_next_reroll_tier_bonus_pending for Goldfish")
		return

	var before_pending = int(runtime_player.get("shop_next_reroll_tier_bonus_pending"))
	runtime_player.apply_upgrade(goldfish)
	if int(runtime_player.get("shop_next_reroll_tier_bonus_pending")) != before_pending + 1:
		failures.append("Applying Goldfish should queue one next-reroll tier bonus")

	var old_pool = main.shop.ITEM_POOL
	var old_current_items = main.shop.current_items.duplicate(true)
	var old_locked_indices = main.shop.locked_indices.duplicate()
	var controlled_pool = [
		{"name": "Goldfish Test Item A", "desc": "", "price": 10, "rarity": 0, "type": "catalog_item", "source_id": "goldfish_test_a", "effects": []},
		{"name": "Goldfish Test Item B", "desc": "", "price": 10, "rarity": 0, "type": "catalog_item", "source_id": "goldfish_test_b", "effects": []},
		{"name": "Goldfish Test Item C", "desc": "", "price": 10, "rarity": 0, "type": "catalog_item", "source_id": "goldfish_test_c", "effects": []},
		{"name": "Goldfish Test Weapon A", "desc": "", "price": 10, "rarity": 0, "type": "weapon", "weapon_type": "pistol", "source_id": "pistol", "minimum_tier": 1},
		{"name": "Goldfish Test Weapon B", "desc": "", "price": 10, "rarity": 0, "type": "weapon", "weapon_type": "smg", "source_id": "smg", "minimum_tier": 1},
	]
	main.shop.ITEM_POOL = controlled_pool
	main.shop.open(5, 0, 0, runtime_player)
	var locked_offer = controlled_pool[0].duplicate(true)
	locked_offer["rolled_rarity"] = 0
	main.shop.current_items = [locked_offer]
	main.shop.locked_indices.clear()
	main.shop.locked_indices.append(0)
	runtime_player.free_shop_rerolls = 1
	main.shop._on_reroll_pressed()
	if int(runtime_player.get("shop_next_reroll_tier_bonus_pending")) != before_pending:
		failures.append("Goldfish next-reroll tier bonus should be consumed by the reroll")
	if main.shop.current_items.size() != 4:
		failures.append("Goldfish reroll check should produce four shop offers")
	else:
		if int(main.shop.current_items[0].get("rolled_rarity", main.shop.current_items[0].get("rarity", 0))) != 0:
			failures.append("Goldfish should not alter locked shop offers")
		for i in range(1, main.shop.current_items.size()):
			var offer = main.shop.current_items[i]
			if int(offer.get("rolled_rarity", offer.get("rarity", 0))) < 1:
				failures.append("Goldfish should raise rerolled offer rarity by at least one tier")
			if str(offer.get("type", "")) == "weapon" and int(offer.get("tier", 1)) < 2:
				failures.append("Goldfish should raise rerolled weapon tier by at least one")

	runtime_player.remove_upgrade(goldfish)
	if int(runtime_player.get("shop_next_reroll_tier_bonus_pending")) != before_pending:
		failures.append("Removing consumed Goldfish should not underflow next-reroll tier bonus")
	runtime_player.free_shop_rerolls = 0
	main.shop.ITEM_POOL = old_pool
	main.shop.current_items = old_current_items
	main.shop.locked_indices.clear()
	for locked_index in old_locked_indices:
		main.shop.locked_indices.append(int(locked_index))

func _check_catalog_fish_hook_locked_shop_curse():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Fish Hook check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var fish_hook = _find_by_source_id(pool, "fish_hook")
	if fish_hook.is_empty():
		failures.append("Runtime shop pool should include Fish Hook locked-shop curse item")
		return
	if not _has_weapon_special_rule_chance(fish_hook.get("effects", []), "locked_shop_entries_chance_to_become_cursed", 0.20):
		failures.append("Fish Hook should preserve 20 percent locked-shop curse chance")
	if not _has_stat_delta(fish_hook.get("effects", []), "curse", 1.0):
		failures.append("Fish Hook should preserve +1 Curse stat delta")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Fish Hook check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Fish Hook check")
		return
	if runtime_player.get("locked_shop_entry_curse_chance") == null:
		failures.append("Player should expose locked_shop_entry_curse_chance for Fish Hook")
		return
	if main.shop == null or not main.shop.has_method("apply_locked_shop_entry_curse_chance"):
		failures.append("Shop should expose locked-shop curse application for Fish Hook")
		return

	var before_curse = int(runtime_player.curse)
	var before_chance = float(runtime_player.get("locked_shop_entry_curse_chance"))
	runtime_player.apply_upgrade(fish_hook)
	if int(runtime_player.curse) != before_curse + 1:
		failures.append("Applying Fish Hook should add 1 Curse")
	if not is_equal_approx(float(runtime_player.get("locked_shop_entry_curse_chance")), before_chance + 0.20):
		failures.append("Applying Fish Hook should add 20 percent locked-shop curse chance")

	var old_current_items = main.shop.current_items.duplicate(true)
	var old_locked_indices = main.shop.locked_indices.duplicate()
	var old_player_ref = main.shop.player_ref
	main.shop.player_ref = runtime_player
	var locked_offer = pool[0].duplicate(true)
	var unlocked_offer = pool[1].duplicate(true)
	locked_offer.erase("catalog_cursed")
	locked_offer.erase("is_cursed")
	locked_offer.erase("cursed")
	unlocked_offer.erase("catalog_cursed")
	unlocked_offer.erase("is_cursed")
	unlocked_offer.erase("cursed")
	main.shop.current_items = [locked_offer, unlocked_offer]
	main.shop.locked_indices.clear()
	main.shop.locked_indices.append(0)
	if int(main.shop.apply_locked_shop_entry_curse_chance({0: 0.19})) != 1:
		failures.append("Fish Hook should curse a locked shop entry when the roll hits")
	if not bool(main.shop.current_items[0].get("catalog_cursed", false)):
		failures.append("Fish Hook should mark hit locked shop entries as catalog_cursed")
	if not bool(main.shop.current_items[0].get("is_cursed", false)):
		failures.append("Fish Hook should expose cursed shop entries through is_cursed metadata")
	if bool(main.shop.current_items[1].get("catalog_cursed", false)):
		failures.append("Fish Hook should not curse unlocked shop entries")
	if int(main.shop.apply_locked_shop_entry_curse_chance({0: 0.0})) != 0:
		failures.append("Fish Hook should not recount an already-cursed locked shop entry")
	main.shop.current_items[0].erase("catalog_cursed")
	main.shop.current_items[0].erase("is_cursed")
	main.shop.current_items[0].erase("cursed")
	if int(main.shop.apply_locked_shop_entry_curse_chance({0: 0.21})) != 0:
		failures.append("Fish Hook should leave locked shop entries unchanged when the roll misses")
	if bool(main.shop.current_items[0].get("catalog_cursed", false)):
		failures.append("Fish Hook should not mark missed locked shop entries as cursed")

	main.shop.current_items = old_current_items
	main.shop.locked_indices.clear()
	for locked_index in old_locked_indices:
		main.shop.locked_indices.append(int(locked_index))
	main.shop.player_ref = old_player_ref
	runtime_player.remove_upgrade(fish_hook)
	if int(runtime_player.curse) != before_curse:
		failures.append("Removing Fish Hook should restore Curse")
	if not is_equal_approx(float(runtime_player.get("locked_shop_entry_curse_chance")), before_chance):
		failures.append("Removing Fish Hook should restore locked-shop curse chance")

func _check_catalog_mirror_and_post_use_state_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for mirror/post-use state check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var mirror = _find_by_source_id(pool, "mirror")
	var broken_mirror = _find_by_source_id(pool, "broken_mirror")
	var resting_goldfish = _find_by_source_id(pool, "resting_goldfish")
	if mirror.is_empty():
		failures.append("Runtime shop pool should include Mirror next-item duplication")
	if broken_mirror.is_empty():
		failures.append("Runtime shop pool should include Broken Mirror post-use state")
	if resting_goldfish.is_empty():
		failures.append("Runtime shop pool should include Resting Goldfish post-use state")
	if mirror.is_empty() or broken_mirror.is_empty() or resting_goldfish.is_empty():
		return
	if not _has_weapon_special_rule(mirror.get("effects", []), "duplicate_next_shop_item_without_exceeding_limits"):
		failures.append("Mirror should preserve next-shop-item duplication rule")
	if not _has_weapon_special_rule(broken_mirror.get("effects", []), "broken_mirror_duplicated_item_state"):
		failures.append("Broken Mirror should preserve duplicated-item post-use state rule")
	if not _has_weapon_special_rule(resting_goldfish.get("effects", []), "resting_goldfish_post_use_state"):
		failures.append("Resting Goldfish should preserve post-use state rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for mirror/post-use state check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for mirror/post-use state check")
		return
	for required_property in [
		"mirror_duplicate_next_shop_item_pending",
		"broken_mirror_duplicated_item_sources",
		"resting_goldfish_post_use_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for mirror/post-use states" % required_property)
			return
	if not runtime_player.has_method("consume_mirror_duplicate_for_shop_item"):
		failures.append("Player should expose consume_mirror_duplicate_for_shop_item for Mirror")
		return

	var before_pending = int(runtime_player.get("mirror_duplicate_next_shop_item_pending"))
	var before_broken_sources = int(runtime_player.get("broken_mirror_duplicated_item_sources"))
	var before_resting_sources = int(runtime_player.get("resting_goldfish_post_use_sources"))
	runtime_player.mirror_duplicate_next_shop_item_pending = 0
	runtime_player.broken_mirror_duplicated_item_sources = 0
	runtime_player.resting_goldfish_post_use_sources = 0

	runtime_player.apply_upgrade(broken_mirror)
	if int(runtime_player.get("broken_mirror_duplicated_item_sources")) != 1:
		failures.append("Applying Broken Mirror should register one duplicated-item post-use state")
	runtime_player.remove_upgrade(broken_mirror)
	if int(runtime_player.get("broken_mirror_duplicated_item_sources")) != 0:
		failures.append("Removing Broken Mirror should restore duplicated-item post-use state count")
	runtime_player.apply_upgrade(resting_goldfish)
	if int(runtime_player.get("resting_goldfish_post_use_sources")) != 1:
		failures.append("Applying Resting Goldfish should register one post-use state")
	runtime_player.remove_upgrade(resting_goldfish)
	if int(runtime_player.get("resting_goldfish_post_use_sources")) != 0:
		failures.append("Removing Resting Goldfish should restore post-use state count")

	var duplicate_target = {
		"type": "catalog_item",
		"name": "Mirror Test Max HP",
		"source_id": "mirror_test_max_hp",
		"rarity": 0,
		"limit": 2,
		"effects": [{"effect": "stat_delta", "stat": "max_hp", "value": 3}],
	}
	runtime_player.max_hp = 10
	runtime_player.hp = 10
	runtime_player.apply_upgrade(mirror)
	if int(runtime_player.get("mirror_duplicate_next_shop_item_pending")) != 1:
		failures.append("Applying Mirror should queue one next-shop-item duplication")
	runtime_player.apply_upgrade(duplicate_target)
	if int(runtime_player.max_hp) != 13:
		failures.append("Mirror duplicate target should apply once before duplication")
	if not runtime_player.consume_mirror_duplicate_for_shop_item(duplicate_target):
		failures.append("Mirror should duplicate the next eligible catalog shop item")
	if int(runtime_player.max_hp) != 16:
		failures.append("Mirror should apply the duplicated item's effects a second time")
	if int(runtime_player.get("mirror_duplicate_next_shop_item_pending")) != 0:
		failures.append("Mirror should consume pending duplication after the next eligible item")
	if int(runtime_player.get("broken_mirror_duplicated_item_sources")) != 1:
		failures.append("Mirror should leave a Broken Mirror duplicated-item state after use")
	runtime_player.remove_upgrade(duplicate_target)
	runtime_player.remove_upgrade(duplicate_target)
	runtime_player.remove_upgrade(mirror)

	var limit_one_target = {
		"type": "catalog_item",
		"name": "Mirror Test Limited",
		"source_id": "mirror_test_limited",
		"rarity": 0,
		"limit": 1,
		"effects": [{"effect": "stat_delta", "stat": "max_hp", "value": 4}],
	}
	runtime_player.max_hp = 10
	runtime_player.hp = 10
	runtime_player.broken_mirror_duplicated_item_sources = 0
	runtime_player.apply_upgrade(mirror)
	runtime_player.apply_upgrade(limit_one_target)
	if runtime_player.consume_mirror_duplicate_for_shop_item(limit_one_target):
		failures.append("Mirror should not duplicate an item beyond its catalog limit")
	if int(runtime_player.max_hp) != 14:
		failures.append("Mirror should leave limit-capped item effects at one application")
	if int(runtime_player.get("mirror_duplicate_next_shop_item_pending")) != 0:
		failures.append("Mirror should consume pending duplication even when the next item is limit-capped")
	runtime_player.remove_upgrade(limit_one_target)
	runtime_player.remove_upgrade(mirror)

	runtime_player.mirror_duplicate_next_shop_item_pending = before_pending
	runtime_player.broken_mirror_duplicated_item_sources = before_broken_sources
	runtime_player.resting_goldfish_post_use_sources = before_resting_sources

func _check_catalog_bone_dice_shop_reroll_stat_mutation():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Bone Dice check: " + str(errors))
		return
	var bone_dice = _find_by_source_id(data.get_shop_pool(false), "bone_dice")
	if bone_dice.is_empty():
		failures.append("Runtime shop pool should include Bone Dice shop-reroll stat mutation")
		return
	if not _has_weapon_special_rule_chance(bone_dice.get("effects", []), "shop_reroll_damage_percent_plus_1_chance", 0.50):
		failures.append("Bone Dice should preserve 50 percent reroll Damage gain chance")
	if not _has_weapon_special_rule_chance(bone_dice.get("effects", []), "shop_reroll_max_hp_minus_1_chance", 0.10):
		failures.append("Bone Dice should preserve 10 percent reroll Max HP loss chance")

	var packed = load("res://scenes/Player.tscn")
	if packed == null:
		failures.append("Player scene missing for Bone Dice shop reroll check")
		return
	var runtime_player = packed.instantiate()
	root.add_child(runtime_player)
	await process_frame
	for required_property in [
		"shop_reroll_damage_gain_chance",
		"shop_reroll_max_hp_loss_chance",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Bone Dice" % required_property)
			runtime_player.queue_free()
			return
	if not runtime_player.has_method("on_shop_rerolled"):
		failures.append("Player should expose on_shop_rerolled for Bone Dice")
		runtime_player.queue_free()
		return

	runtime_player.apply_upgrade(bone_dice)
	if not is_equal_approx(float(runtime_player.get("shop_reroll_damage_gain_chance")), 0.50):
		failures.append("Applying Bone Dice should add 50 percent reroll Damage gain chance")
	if not is_equal_approx(float(runtime_player.get("shop_reroll_max_hp_loss_chance")), 0.10):
		failures.append("Applying Bone Dice should add 10 percent reroll Max HP loss chance")
	var applied_damage_chance = float(runtime_player.get("shop_reroll_damage_gain_chance"))
	var applied_max_hp_loss_chance = float(runtime_player.get("shop_reroll_max_hp_loss_chance"))

	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_max_hp = int(runtime_player.max_hp)
	var before_hp = int(runtime_player.hp)
	runtime_player.shop_reroll_damage_gain_chance = 1.0
	runtime_player.shop_reroll_max_hp_loss_chance = 1.0
	runtime_player.on_shop_rerolled()
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.01):
		failures.append("Guaranteed Bone Dice Damage chance should add 1 percent Damage on shop reroll")
	if int(runtime_player.max_hp) != before_max_hp - 1:
		failures.append("Guaranteed Bone Dice Max HP chance should remove 1 Max HP on shop reroll")
	if int(runtime_player.hp) != min(before_hp, int(runtime_player.max_hp)):
		failures.append("Bone Dice Max HP loss should clamp current HP to the new maximum")
	runtime_player.shop_reroll_damage_gain_chance = applied_damage_chance
	runtime_player.shop_reroll_max_hp_loss_chance = applied_max_hp_loss_chance

	var packed_shop = load("res://scenes/Shop.tscn")
	if packed_shop == null:
		failures.append("Shop scene missing for Bone Dice shop reroll check")
		runtime_player.queue_free()
		return
	var runtime_shop = packed_shop.instantiate()
	root.add_child(runtime_shop)
	await process_frame
	var shop_damage_before = float(runtime_player.damage_percent_bonus)
	runtime_player.shop_reroll_damage_gain_chance = 1.0
	runtime_player.shop_reroll_max_hp_loss_chance = 0.0
	runtime_player.free_shop_rerolls = 1
	runtime_shop.open(4, 0, 0, runtime_player)
	runtime_shop._on_reroll_pressed()
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), shop_damage_before + 0.01):
		failures.append("Real shop reroll should trigger Bone Dice stat mutation")
	if int(runtime_player.get("free_shop_rerolls")) != 0:
		failures.append("Bone Dice shop-path check should consume the free reroll used for the test")
	runtime_player.shop_reroll_damage_gain_chance = applied_damage_chance
	runtime_player.shop_reroll_max_hp_loss_chance = applied_max_hp_loss_chance
	runtime_shop.queue_free()

	runtime_player.remove_upgrade(bone_dice)
	if not is_equal_approx(float(runtime_player.get("shop_reroll_damage_gain_chance")), 0.0):
		failures.append("Removing Bone Dice should restore reroll Damage gain chance")
	if not is_equal_approx(float(runtime_player.get("shop_reroll_max_hp_loss_chance")), 0.0):
		failures.append("Removing Bone Dice should restore reroll Max HP loss chance")
	runtime_player.queue_free()

func _check_catalog_axolotl_primary_stat_swap():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Axolotl check: " + str(errors))
		return
	var axolotl = _find_by_source_id(data.get_shop_pool(false), "axolotl")
	if axolotl.is_empty():
		failures.append("Runtime shop pool should include Axolotl primary stat swap")
		return
	if not _has_weapon_special_rule(axolotl.get("effects", []), "swap_highest_and_lowest_positive_primary_stats_on_pickup"):
		failures.append("Axolotl should preserve primary stat swap special rule")
		return

	var packed = load("res://scenes/Player.tscn")
	if packed == null:
		failures.append("Player scene missing for Axolotl primary stat swap check")
		return
	var runtime_player = packed.instantiate()
	root.add_child(runtime_player)
	await process_frame
	if not runtime_player.has_method("apply_axolotl_primary_stat_swap"):
		failures.append("Player should expose apply_axolotl_primary_stat_swap for Axolotl")
		runtime_player.queue_free()
		return

	runtime_player.max_hp = 12
	runtime_player.hp = 12
	runtime_player.damage_percent_bonus = 0.30
	runtime_player.melee_damage_bonus = 4
	runtime_player.luck = 2
	runtime_player.apply_upgrade(axolotl)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.02):
		failures.append("Axolotl should move the lowest positive primary stat into Damage")
	if int(runtime_player.luck) != 30:
		failures.append("Axolotl should move the highest positive primary stat into Luck")
	if int(runtime_player.max_hp) != 12:
		failures.append("Axolotl should leave non-extreme positive primary stats unchanged")
	if int(runtime_player.melee_damage_bonus) != 4:
		failures.append("Axolotl should only swap the highest and lowest positive primary stats")
	runtime_player.remove_upgrade(axolotl)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.02) or int(runtime_player.luck) != 30:
		failures.append("Removing Axolotl should not revert its one-shot pickup stat swap")
	runtime_player.queue_free()

func _check_catalog_anvil_shop_entry_weapon_upgrade():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Anvil check: " + str(errors))
		return
	var anvil = _find_by_source_id(data.get_shop_pool(false), "anvil")
	if anvil.is_empty():
		failures.append("Runtime shop pool should include Anvil shop-entry weapon upgrade")
		return
	if not _has_weapon_special_rule(anvil.get("effects", []), "upgrade_random_weapon_entering_shop_or_gain_2_armor"):
		failures.append("Anvil should preserve shop-entry weapon upgrade special rule")
		return

	var packed_player = load("res://scenes/Player.tscn")
	var packed_shop = load("res://scenes/Shop.tscn")
	if packed_player == null or packed_shop == null:
		failures.append("Player or Shop scene missing for Anvil shop-entry check")
		return
	var runtime_player = packed_player.instantiate()
	var runtime_shop = packed_shop.instantiate()
	root.add_child(runtime_player)
	root.add_child(runtime_shop)
	await process_frame
	if runtime_player.get("shop_entry_weapon_upgrade_sources") == null:
		failures.append("Player should expose shop_entry_weapon_upgrade_sources for Anvil")
		runtime_player.queue_free()
		runtime_shop.queue_free()
		return
	if not runtime_player.has_method("on_shop_opened"):
		failures.append("Player should expose on_shop_opened for Anvil")
		runtime_player.queue_free()
		runtime_shop.queue_free()
		return

	runtime_player.equipped_weapons.clear()
	runtime_player.equip_or_combine_weapon("pistol", 1)
	runtime_player.apply_upgrade(anvil)
	if int(runtime_player.get("shop_entry_weapon_upgrade_sources")) != 1:
		failures.append("Applying Anvil should enable one shop-entry weapon upgrade source")
	runtime_shop.open(6, 0, 0, runtime_player)
	if runtime_player.equipped_weapons.is_empty() or int(runtime_player.equipped_weapons[0].get("tier", 1)) != 2:
		failures.append("Entering the shop with Anvil should upgrade one eligible weapon")

	runtime_player.equipped_weapons = [runtime_player.combat._make_weapon("pistol", 4)]
	var before_armor = int(runtime_player.armor)
	runtime_shop.open(7, 0, 0, runtime_player)
	if int(runtime_player.armor) != before_armor + 2:
		failures.append("Anvil should grant 2 Armor when no equipped weapon can be upgraded")
	runtime_player.remove_upgrade(anvil)
	if int(runtime_player.get("shop_entry_weapon_upgrade_sources")) != 0:
		failures.append("Removing Anvil should clear shop-entry weapon upgrade sources")
	var armor_after_remove = int(runtime_player.armor)
	runtime_shop.open(8, 0, 0, runtime_player)
	if int(runtime_player.armor) != armor_after_remove:
		failures.append("Removing Anvil should stop future shop-entry Armor gains")
	runtime_player.queue_free()
	runtime_shop.queue_free()

func _check_catalog_tree_spawn_and_lumberjack_shirt():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Tree/Lumberjack Shirt check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var tree_item = _find_by_source_id(pool, "tree")
	var lumberjack_shirt = _find_by_source_id(pool, "lumberjack_shirt")
	if tree_item.is_empty():
		failures.append("Runtime shop pool should include Tree spawn modifier")
	if lumberjack_shirt.is_empty():
		failures.append("Runtime shop pool should include Lumberjack Shirt tree one-hit modifier")
	if tree_item.is_empty() or lumberjack_shirt.is_empty():
		return
	if not _has_weapon_special_rule(tree_item.get("effects", []), "more_trees_spawn"):
		failures.append("Tree shop entry should preserve more-trees special rule")
	if not _has_weapon_special_rule(lumberjack_shirt.get("effects", []), "trees_die_in_one_hit"):
		failures.append("Lumberjack Shirt shop entry should preserve tree one-hit special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Tree/Lumberjack Shirt check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Tree/Lumberjack Shirt check")
		return
	for required_property in [
		"tree_spawn_bonus_sources",
		"trees_die_in_one_hit_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Tree/Lumberjack Shirt" % required_property)
			return
	if main.wave_manager == null or not main.wave_manager.has_method("spawn_tree"):
		failures.append("WaveManager should expose spawn_tree for Tree item runtime")
		return
	if main.wave_manager == null or not main.wave_manager.has_method("roll_tree_spawn_count"):
		failures.append("WaveManager should expose roll_tree_spawn_count for Tree item runtime")
		return

	var before_tree_sources = int(runtime_player.get("tree_spawn_bonus_sources"))
	var before_one_hit_sources = int(runtime_player.get("trees_die_in_one_hit_sources"))
	runtime_player.apply_upgrade(tree_item)
	runtime_player.apply_upgrade(lumberjack_shirt)
	if int(runtime_player.get("tree_spawn_bonus_sources")) != before_tree_sources + 1:
		failures.append("Applying Tree should add one tree spawn source")
	if int(runtime_player.get("trees_die_in_one_hit_sources")) != before_one_hit_sources + 1:
		failures.append("Applying Lumberjack Shirt should add one tree one-hit source")
	if int(main.wave_manager.callv("roll_tree_spawn_count", [3.0, 1.0])) != 1:
		failures.append("Tree spawn smoother should produce the deterministic floor count from tree stat")

	_reset_enemy_pool(main)
	_reset_xp_orb_pool(main)
	main.pickup_manager.cleanup()
	var tree_enemy = main.wave_manager.spawn_tree(Vector2(320, 240))
	if tree_enemy == null or not is_instance_valid(tree_enemy):
		failures.append("WaveManager.spawn_tree should return a spawned tree node")
		runtime_player.remove_upgrade(lumberjack_shirt)
		runtime_player.remove_upgrade(tree_item)
		return
	if str(tree_enemy.get("enemy_type")) != "tree":
		failures.append("Spawned tree should use the tree enemy type")
	if not tree_enemy.is_in_group("neutral_trees"):
		failures.append("Spawned tree should be tracked as a neutral tree")
	if tree_enemy.is_in_group("enemies"):
		failures.append("Spawned tree should not count as a normal enemy group member")
	if int(tree_enemy.get("hp")) != 1:
		failures.append("Lumberjack Shirt should make spawned trees die in one hit")
	var before_kills = int(main.kills)
	var before_pickups = main.pickup_manager.active_pickup_nodes.size()
	tree_enemy.take_damage(1)
	await process_frame
	if int(main.kills) != before_kills:
		failures.append("Killing a tree should not increment the enemy kill counter")
	if main.pickup_manager.active_pickup_nodes.size() != before_pickups + 1:
		failures.append("Killing a tree should drop one consumable pickup")
	var tree_orb = _find_visible_xp_orb(main)
	if tree_orb == null:
		failures.append("Killing a tree should drop material value")
	else:
		var before_materials = int(main.economy.materials)
		tree_orb.collect(runtime_player)
		await process_frame
		if int(main.economy.materials) != before_materials + 3:
			failures.append("Killing a tree should drop 3 materials")

	main.pickup_manager.cleanup()
	_reset_xp_orb_pool(main)
	runtime_player.remove_upgrade(lumberjack_shirt)
	runtime_player.remove_upgrade(tree_item)
	if int(runtime_player.get("tree_spawn_bonus_sources")) != before_tree_sources:
		failures.append("Removing Tree should restore tree spawn sources")
	if int(runtime_player.get("trees_die_in_one_hit_sources")) != before_one_hit_sources:
		failures.append("Removing Lumberjack Shirt should restore tree one-hit sources")

func _check_catalog_fruit_basket_and_garden_consumables():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Fruit Basket/Garden check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var fruit_basket = _find_by_source_id(pool, "fruit_basket")
	var garden = _find_by_source_id(pool, "garden")
	if fruit_basket.is_empty():
		failures.append("Runtime shop pool should include Fruit Basket fruit-drop modifier")
	if garden.is_empty():
		failures.append("Runtime shop pool should include Garden fruit-spawning structure")
	if fruit_basket.is_empty() or garden.is_empty():
		return
	if not _has_weapon_special_rule(fruit_basket.get("effects", []), "enemies_have_higher_fruit_drop_chance"):
		failures.append("Fruit Basket shop entry should preserve higher-fruit-drop special rule")
	if not _has_weapon_special_rule(garden.get("effects", []), "spawn_garden_creates_fruit_every_15_seconds"):
		failures.append("Garden shop entry should preserve fruit-spawning garden special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Fruit Basket/Garden check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Fruit Basket/Garden check")
		return
	for required_property in [
		"fruit_drop_chance_bonus",
		"garden_spawn_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Fruit Basket/Garden" % required_property)
			return
	if main.turret_manager == null or not main.turret_manager.has_method("spawn_garden"):
		failures.append("TurretManager should expose spawn_garden for Garden runtime")
		return
	if main.turret_manager == null or not main.turret_manager.has_method("process_gardens"):
		failures.append("TurretManager should expose process_gardens for Garden runtime")
		return

	var before_fruit_bonus = float(runtime_player.get("fruit_drop_chance_bonus"))
	var before_garden_sources = int(runtime_player.get("garden_spawn_sources"))
	var before_hp_regen = int(runtime_player.hp_regen)
	runtime_player.apply_upgrade(fruit_basket)
	runtime_player.apply_upgrade(garden)
	if float(runtime_player.get("fruit_drop_chance_bonus")) <= before_fruit_bonus:
		failures.append("Applying Fruit Basket should increase enemy fruit drop chance")
	if int(runtime_player.hp_regen) != before_hp_regen - 3:
		failures.append("Applying Fruit Basket should retain its -3 HP Regeneration catalog stat delta")
	if int(runtime_player.get("garden_spawn_sources")) != before_garden_sources + 1:
		failures.append("Applying Garden should add one garden spawn source")

	var rules = load("res://scripts/LootRules.gd").new()
	var baseline_drop = rules.roll_pickup_kind("normal", 0, 0, 0.0, 0.15, 0.99)
	var boosted_drop = rules.roll_pickup_kind("normal", 0, 0, float(runtime_player.get("fruit_drop_chance_bonus")), 0.15, 0.99)
	if not baseline_drop.is_empty():
		failures.append("Fruit Basket deterministic drop check expected baseline enemy roll to miss")
	if boosted_drop.get("kind", "") != "fruit":
		failures.append("Fruit Basket should turn a near-miss enemy consumable roll into a fruit drop")

	main.pickup_manager.cleanup()
	var before_pickups = main.pickup_manager.active_pickup_nodes.size()
	var garden_node = main.turret_manager.spawn_garden(Vector2(360, 260), 15.0)
	if garden_node == null or not is_instance_valid(garden_node):
		failures.append("TurretManager.spawn_garden should return a garden structure")
	else:
		if not garden_node.is_in_group("gardens"):
			failures.append("Spawned Garden should be tracked in the gardens group")
		if not garden_node.is_in_group("structures"):
			failures.append("Spawned Garden should be tracked as a structure")
	if main.pickup_manager.active_pickup_nodes.size() != before_pickups + 1:
		failures.append("Garden should spawn one fruit immediately")
	if garden_node != null and is_instance_valid(garden_node):
		garden_node.set_meta("fruit_timer", 0.1)
		main.turret_manager.process_gardens(0.2)
		if main.pickup_manager.active_pickup_nodes.size() != before_pickups + 2:
			failures.append("Garden should spawn fruit again when its timer elapses")

	main.pickup_manager.cleanup()
	main.turret_manager.cleanup()
	runtime_player.remove_upgrade(garden)
	runtime_player.remove_upgrade(fruit_basket)
	if float(runtime_player.get("fruit_drop_chance_bonus")) != before_fruit_bonus:
		failures.append("Removing Fruit Basket should restore fruit drop chance bonus")
	if int(runtime_player.hp_regen) != before_hp_regen:
		failures.append("Removing Fruit Basket should restore HP Regeneration")
	if int(runtime_player.get("garden_spawn_sources")) != before_garden_sources:
		failures.append("Removing Garden should restore garden spawn sources")

func _check_catalog_turret_and_landmines_structures():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Turret/Landmines check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var turret_item = _find_by_source_id(pool, "turret")
	var landmines = _find_by_source_id(pool, "landmines")
	if turret_item.is_empty():
		failures.append("Runtime shop pool should include Turret structure item")
	if landmines.is_empty():
		failures.append("Runtime shop pool should include Landmines structure item")
	if turret_item.is_empty() or landmines.is_empty():
		return
	if not _has_weapon_special_rule(turret_item.get("effects", []), "spawn_turret_each_wave"):
		failures.append("Turret shop entry should preserve spawn-turret special rule")
	if not _has_weapon_special_rule(landmines.get("effects", []), "spawn_landmine_every_12_seconds"):
		failures.append("Landmines shop entry should preserve landmine spawn special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Turret/Landmines check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Turret/Landmines check")
		return
	for required_property in [
		"catalog_turret_sources",
		"landmine_spawn_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Turret/Landmines" % required_property)
			return
	for required_method in [
		"spawn_catalog_turret",
		"spawn_landmine",
		"trigger_landmine",
		"calculate_structure_damage",
	]:
		if main.turret_manager == null or not main.turret_manager.has_method(required_method):
			failures.append("TurretManager should expose %s for Turret/Landmines runtime" % required_method)
			return
	if main.turret_manager.get("active_landmines") == null:
		failures.append("TurretManager should track active_landmines")
		return
	if main.wave_manager == null or not main.wave_manager.has_method("_spawn_catalog_structures_for_wave_start"):
		failures.append("WaveManager should expose catalog structure wave-start spawning")
		return

	var before_turret_sources = int(runtime_player.get("catalog_turret_sources"))
	var before_landmine_sources = int(runtime_player.get("landmine_spawn_sources"))
	var before_engineering = int(runtime_player.engineering_bonus)
	runtime_player.engineering_bonus = 5
	runtime_player.apply_upgrade(turret_item)
	runtime_player.apply_upgrade(landmines)
	if int(runtime_player.get("catalog_turret_sources")) != before_turret_sources + 1:
		failures.append("Applying Turret should add one catalog turret source")
	if int(runtime_player.get("landmine_spawn_sources")) != before_landmine_sources + 1:
		failures.append("Applying Landmines should add one landmine spawn source")

	main.turret_manager.cleanup()
	main.wave_manager._spawn_catalog_structures_for_wave_start()
	if main.turret_manager.active_turrets.size() != 1:
		failures.append("Wave start should spawn one Turret structure from item source")
	if main.turret_manager.active_landmines.size() != 1:
		failures.append("Wave start should spawn one Landmine from item source")
	var spawned_turret = main.turret_manager.active_turrets[0] if main.turret_manager.active_turrets.size() > 0 else null
	if spawned_turret != null and is_instance_valid(spawned_turret):
		if not spawned_turret.is_in_group("structures"):
			failures.append("Spawned Turret should count as a structure")
		if not spawned_turret.is_in_group("catalog_turrets"):
			failures.append("Spawned Turret should be tagged as a catalog turret")
		if not is_equal_approx(float(spawned_turret.get_meta("attack_interval", 0.0)), 0.73):
			failures.append("Spawned Turret should preserve Brotato 0.73s cooldown")
		if int(main.turret_manager.calculate_structure_damage(spawned_turret)) != 14:
			failures.append("Turret damage should scale as 10 + 80% Engineering")

	var manual_mine = main.turret_manager.spawn_landmine(Vector2(420, 240), 10.0, 1.0, 80.0)
	if manual_mine == null or not is_instance_valid(manual_mine):
		failures.append("TurretManager.spawn_landmine should return a landmine")
	else:
		if not manual_mine.is_in_group("structures"):
			failures.append("Landmine should count as a structure")
		if not manual_mine.is_in_group("landmines"):
			failures.append("Landmine should be tagged as landmine")
		var target = main.get_enemy()
		target.setup("normal", main.wave)
		target.position = manual_mine.position + Vector2(20, 0)
		target.hp = 30
		target.max_hp = 30
		var far_target = main.get_enemy()
		far_target.setup("normal", main.wave)
		far_target.position = manual_mine.position + Vector2(260, 0)
		far_target.hp = 30
		far_target.max_hp = 30
		main.turret_manager.trigger_landmine(manual_mine)
		if int(target.get("hp")) != 15:
			failures.append("Landmine should deal 10 + 100% Engineering explosion damage in radius")
		if int(far_target.get("hp")) != 30:
			failures.append("Landmine should not damage enemies outside its explosion radius")
		_reset_enemy_pool(main)

	main.turret_manager.cleanup()
	runtime_player.remove_upgrade(landmines)
	runtime_player.remove_upgrade(turret_item)
	runtime_player.engineering_bonus = before_engineering
	if int(runtime_player.get("catalog_turret_sources")) != before_turret_sources:
		failures.append("Removing Turret should restore catalog turret sources")
	if int(runtime_player.get("landmine_spawn_sources")) != before_landmine_sources:
		failures.append("Removing Landmines should restore landmine spawn sources")

func _check_catalog_curse_and_builders_turret_runtime():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Curse/Builder's Turret check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var corrupted_shard = _find_by_source_id(pool, "corrupted_shard")
	var builders_turret = _find_by_source_id(pool, "builders_turret")
	if corrupted_shard.is_empty():
		failures.append("Runtime shop pool should include Corrupted Shard curse item")
	if builders_turret.is_empty():
		failures.append("Runtime shop pool should include Builder's Turret unique structure item")
	if corrupted_shard.is_empty() or builders_turret.is_empty():
		return
	if not _has_stat_delta(corrupted_shard.get("effects", []), "damage_percent", 0.03):
		failures.append("Corrupted Shard should preserve +3 percent Damage")
	if not _has_stat_delta(corrupted_shard.get("effects", []), "curse", 1.0):
		failures.append("Corrupted Shard should preserve +1 Curse")
	if not _has_weapon_special_rule(builders_turret.get("effects", []), "unique_builders_turret"):
		failures.append("Builder's Turret should preserve unique turret special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Curse/Builder's Turret check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Curse/Builder's Turret check")
		return
	for required_property in [
		"curse",
		"builders_turret_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Curse/Builder's Turret" % required_property)
			return
	if main.turret_manager == null or not main.turret_manager.has_method("spawn_builders_turret"):
		failures.append("TurretManager should expose spawn_builders_turret for Builder's Turret runtime")
		return

	var before_curse = int(runtime_player.get("curse"))
	var before_damage = float(runtime_player.damage_percent_bonus)
	runtime_player.apply_upgrade(corrupted_shard)
	if int(runtime_player.get("curse")) != before_curse + 1:
		failures.append("Applying Corrupted Shard should add +1 Curse")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.03):
		failures.append("Applying Corrupted Shard should add +3 percent Damage")
	runtime_player.remove_upgrade(corrupted_shard)
	if int(runtime_player.get("curse")) != before_curse:
		failures.append("Removing Corrupted Shard should restore Curse")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Corrupted Shard should restore Damage")

	var before_sources = int(runtime_player.get("builders_turret_sources"))
	var before_engineering = int(runtime_player.engineering_bonus)
	var before_weapons = runtime_player.equipped_weapons.duplicate(true)
	runtime_player.engineering_bonus = 6
	runtime_player.equipped_weapons = [
		{
			"type": "builder_test_ranged",
			"tier": 2,
			"data": {
				"name": "Builder Test Ranged",
				"damage": 12,
				"fire_rate": 2.0,
				"count": 2,
				"spread": 0.0,
				"spd": 500.0,
				"color": Color(1, 1, 1),
				"range": 420.0,
				"melee": false
			}
		}
	]
	runtime_player.apply_upgrade(builders_turret)
	if int(runtime_player.get("builders_turret_sources")) != before_sources + 1:
		failures.append("Applying Builder's Turret should add one unique turret source")
	main.turret_manager.cleanup()
	main.wave_manager._spawn_catalog_structures_for_wave_start()
	var spawned_builder = _find_structure_by_variant(main.turret_manager.active_turrets, "builders_turret")
	if spawned_builder == null:
		failures.append("Wave start should spawn Builder's Turret as a unique structure")
	else:
		if not spawned_builder.is_in_group("structures"):
			failures.append("Builder's Turret should count as a structure")
		if not spawned_builder.is_in_group("builders_turrets"):
			failures.append("Builder's Turret should be tagged in the builders_turrets group")
		if str(spawned_builder.get_meta("builder_weapon_type", "")) != "builder_test_ranged":
			failures.append("Builder's Turret should derive its profile from the best ranged weapon")
		if int(spawned_builder.get_meta("projectiles", 0)) != 2:
			failures.append("Builder's Turret should preserve the copied ranged weapon projectile count")
		if not is_equal_approx(float(spawned_builder.get_meta("attack_interval", 0.0)), 0.5):
			failures.append("Builder's Turret should derive cooldown from the copied ranged weapon fire rate")
		if int(main.turret_manager.calculate_structure_damage(spawned_builder)) != 18:
			failures.append("Builder's Turret damage should derive from weapon base damage and scale with Engineering")

	main.turret_manager.cleanup()
	runtime_player.remove_upgrade(builders_turret)
	runtime_player.engineering_bonus = before_engineering
	runtime_player.equipped_weapons = before_weapons
	if int(runtime_player.get("builders_turret_sources")) != before_sources:
		failures.append("Removing Builder's Turret should restore unique turret sources")

func _check_catalog_engineering_turret_variants():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for turret variant check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var explosive_turret = _find_by_source_id(pool, "explosive_turret")
	var incendiary_turret = _find_by_source_id(pool, "incendiary_turret")
	var laser_turret = _find_by_source_id(pool, "laser_turret")
	var medical_turret = _find_by_source_id(pool, "medical_turret")
	if explosive_turret.is_empty():
		failures.append("Runtime shop pool should include Explosive Turret structure item")
	if incendiary_turret.is_empty():
		failures.append("Runtime shop pool should include Incendiary Turret structure item")
	if laser_turret.is_empty():
		failures.append("Runtime shop pool should include Laser Turret structure item")
	if medical_turret.is_empty():
		failures.append("Runtime shop pool should include Medical Turret structure item")
	if explosive_turret.is_empty() or incendiary_turret.is_empty() or laser_turret.is_empty() or medical_turret.is_empty():
		return

	if not _has_weapon_special_rule_number(explosive_turret.get("effects", []), "spawn_explosive_turret", "damage", 25.0):
		failures.append("Explosive Turret should preserve 25 base damage special rule")
	if not _has_weapon_special_rule_number(explosive_turret.get("effects", []), "spawn_explosive_turret", "engineering_damage_coefficient", 1.50):
		failures.append("Explosive Turret should preserve 150% Engineering damage scaling")
	if not _has_weapon_special_rule_number(incendiary_turret.get("effects", []), "spawn_incendiary_turret", "damage", 5.0):
		failures.append("Incendiary Turret should preserve 5 base damage special rule")
	if not _has_weapon_special_rule_number(incendiary_turret.get("effects", []), "spawn_incendiary_turret", "hit_count", 8.0):
		failures.append("Incendiary Turret should preserve 8 hit count special rule")
	if not _has_weapon_special_rule_number(incendiary_turret.get("effects", []), "spawn_incendiary_turret", "engineering_damage_coefficient", 0.33):
		failures.append("Incendiary Turret should preserve 33% Engineering damage scaling")
	if not _has_weapon_special_rule_number(laser_turret.get("effects", []), "spawn_laser_turret", "damage", 20.0):
		failures.append("Laser Turret should preserve 20 base damage special rule")
	if not _has_weapon_special_rule_number(laser_turret.get("effects", []), "spawn_laser_turret", "engineering_damage_coefficient", 1.25):
		failures.append("Laser Turret should preserve 125% Engineering damage scaling")
	if not _has_weapon_special_rule_number(medical_turret.get("effects", []), "spawn_medical_turret", "healing", 3.0):
		failures.append("Medical Turret should preserve 3 base healing special rule")
	if not _has_weapon_special_rule_number(medical_turret.get("effects", []), "spawn_medical_turret", "engineering_heal_coefficient", 0.05):
		failures.append("Medical Turret should preserve 5% Engineering healing scaling")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for turret variant check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for turret variant check")
		return
	for required_property in [
		"explosive_turret_sources",
		"incendiary_turret_sources",
		"laser_turret_sources",
		"medical_turret_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for turret variants" % required_property)
			return
	for required_method in [
		"spawn_damage_turret_variant",
		"spawn_medical_turret",
		"calculate_structure_healing",
	]:
		if main.turret_manager == null or not main.turret_manager.has_method(required_method):
			failures.append("TurretManager should expose %s for turret variant runtime" % required_method)
			return
	if main.wave_manager == null or not main.wave_manager.has_method("_spawn_catalog_structures_for_wave_start"):
		failures.append("WaveManager should expose catalog structure wave-start spawning for turret variants")
		return

	var before_engineering = int(runtime_player.engineering_bonus)
	var before_explosion_damage = float(runtime_player.get("explosion_damage_percent")) if runtime_player.get("explosion_damage_percent") != null else 0.0
	var before_counts := {
		"explosive_turret_sources": int(runtime_player.get("explosive_turret_sources")),
		"incendiary_turret_sources": int(runtime_player.get("incendiary_turret_sources")),
		"laser_turret_sources": int(runtime_player.get("laser_turret_sources")),
		"medical_turret_sources": int(runtime_player.get("medical_turret_sources")),
	}
	runtime_player.engineering_bonus = 20
	if runtime_player.get("explosion_damage_percent") != null:
		runtime_player.set("explosion_damage_percent", 0.0)
	runtime_player.apply_upgrade(explosive_turret)
	runtime_player.apply_upgrade(incendiary_turret)
	runtime_player.apply_upgrade(laser_turret)
	runtime_player.apply_upgrade(medical_turret)
	if int(runtime_player.get("explosive_turret_sources")) != before_counts["explosive_turret_sources"] + 1:
		failures.append("Applying Explosive Turret should add one explosive turret source")
	if int(runtime_player.get("incendiary_turret_sources")) != before_counts["incendiary_turret_sources"] + 1:
		failures.append("Applying Incendiary Turret should add one incendiary turret source")
	if int(runtime_player.get("laser_turret_sources")) != before_counts["laser_turret_sources"] + 1:
		failures.append("Applying Laser Turret should add one laser turret source")
	if int(runtime_player.get("medical_turret_sources")) != before_counts["medical_turret_sources"] + 1:
		failures.append("Applying Medical Turret should add one medical turret source")

	main.turret_manager.cleanup()
	main.wave_manager._spawn_catalog_structures_for_wave_start()
	if main.turret_manager.active_turrets.size() != 4:
		failures.append("Wave start should spawn four turret variant structures from item sources")
	var spawned_explosive = _find_structure_by_variant(main.turret_manager.active_turrets, "explosive_turret")
	var spawned_incendiary = _find_structure_by_variant(main.turret_manager.active_turrets, "incendiary_turret")
	var spawned_laser = _find_structure_by_variant(main.turret_manager.active_turrets, "laser_turret")
	var spawned_medical = _find_structure_by_variant(main.turret_manager.active_turrets, "medical_turret")
	if spawned_explosive == null:
		failures.append("Wave start should spawn an Explosive Turret variant")
	else:
		if not bool(spawned_explosive.get_meta("uses_explosion_modifiers", false)):
			failures.append("Explosive Turret should use explosion modifiers")
		if int(main.turret_manager.calculate_structure_damage(spawned_explosive)) != 55:
			failures.append("Explosive Turret damage should scale as 25 + 150% Engineering")
	if spawned_incendiary == null:
		failures.append("Wave start should spawn an Incendiary Turret variant")
	else:
		if int(spawned_incendiary.get_meta("hit_count", 0)) != 8:
			failures.append("Incendiary Turret should carry 8-hit metadata")
		if str(spawned_incendiary.get_meta("ammo_type", "")) != "fire":
			failures.append("Incendiary Turret should be tagged as fire ammo")
		if int(main.turret_manager.calculate_structure_damage(spawned_incendiary)) != 12:
			failures.append("Incendiary Turret damage should scale as 5 + 33% Engineering")
	if spawned_laser == null:
		failures.append("Wave start should spawn a Laser Turret variant")
	else:
		if int(main.turret_manager.calculate_structure_damage(spawned_laser)) != 45:
			failures.append("Laser Turret damage should scale as 20 + 125% Engineering")
	if spawned_medical == null:
		failures.append("Wave start should spawn a Medical Turret variant")
	else:
		if not bool(spawned_medical.get_meta("is_medical_turret", false)):
			failures.append("Medical Turret should be tagged as a healing turret")
		if int(main.turret_manager.calculate_structure_healing(spawned_medical)) != 4:
			failures.append("Medical Turret healing should scale as 3 + 5% Engineering")

	main.turret_manager.cleanup()
	runtime_player.remove_upgrade(medical_turret)
	runtime_player.remove_upgrade(laser_turret)
	runtime_player.remove_upgrade(incendiary_turret)
	runtime_player.remove_upgrade(explosive_turret)
	runtime_player.engineering_bonus = before_engineering
	if runtime_player.get("explosion_damage_percent") != null:
		runtime_player.set("explosion_damage_percent", before_explosion_damage)
	for source_property in before_counts.keys():
		if int(runtime_player.get(source_property)) != before_counts[source_property]:
			failures.append("Removing turret variant items should restore %s" % source_property)

func _check_catalog_structure_crit_and_tree_factory():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for structure crit/factory check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var pile_of_books = _find_by_source_id(pool, "pile_of_books")
	var pocket_factory = _find_by_source_id(pool, "pocket_factory")
	if pile_of_books.is_empty():
		failures.append("Runtime shop pool should include Pile of Books structure crit item")
	if pocket_factory.is_empty():
		failures.append("Runtime shop pool should include Pocket Factory tree-kill turret item")
	if pile_of_books.is_empty() or pocket_factory.is_empty():
		return
	if not _has_weapon_special_rule(pile_of_books.get("effects", []), "structures_can_crit"):
		failures.append("Pile of Books shop entry should preserve structure crit special rule")
	if not _has_stat_delta(pile_of_books.get("effects", []), "crit_chance", 0.05):
		failures.append("Pile of Books should preserve +5 percent crit chance")
	if not _has_stat_delta(pile_of_books.get("effects", []), "engineering", 3.0):
		failures.append("Pile of Books should preserve +3 Engineering")
	if not _has_weapon_special_rule(pocket_factory.get("effects", []), "killing_tree_spawns_turret"):
		failures.append("Pocket Factory shop entry should preserve tree-kill turret special rule")
	if not _has_stat_delta(pocket_factory.get("effects", []), "engineering", 2.0):
		failures.append("Pocket Factory should preserve +2 Engineering")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for structure crit/factory check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for structure crit/factory check")
		return
	for required_property in [
		"structures_can_crit_sources",
		"pocket_factory_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for structure crit/factory items" % required_property)
			return
	if main.turret_manager == null or not main.turret_manager.has_method("calculate_structure_damage"):
		failures.append("TurretManager should expose calculate_structure_damage for structure crit runtime")
		return
	if not runtime_player.has_method("on_tree_killed"):
		failures.append("Player should expose on_tree_killed for Pocket Factory runtime")
		return

	var before_structure_crit_sources = int(runtime_player.get("structures_can_crit_sources"))
	var before_factory_sources = int(runtime_player.get("pocket_factory_sources"))
	var before_engineering = int(runtime_player.engineering_bonus)
	var before_crit_chance = float(runtime_player.crit_chance)
	runtime_player.engineering_bonus = 0
	runtime_player.crit_chance = 0.0
	runtime_player.apply_upgrade(pile_of_books)
	runtime_player.apply_upgrade(pocket_factory)
	if int(runtime_player.get("structures_can_crit_sources")) != before_structure_crit_sources + 1:
		failures.append("Applying Pile of Books should enable structure critical hits")
	if int(runtime_player.get("pocket_factory_sources")) != before_factory_sources + 1:
		failures.append("Applying Pocket Factory should enable tree-kill turret spawning")
	if int(runtime_player.engineering_bonus) != 5:
		failures.append("Pile of Books and Pocket Factory should apply +5 total Engineering")
	if not is_equal_approx(float(runtime_player.crit_chance), 0.05):
		failures.append("Pile of Books should apply +5 percent crit chance")

	main.turret_manager.cleanup()
	var structure = main.turret_manager.spawn_catalog_turret(Vector2(300, 240), 10.0, 1.0, 300.0, 1.0)
	var crit_damage = main.turret_manager.callv("calculate_structure_damage", [structure, 0.0])
	if int(crit_damage) != 30:
		failures.append("Pile of Books should allow structures to crit with player crit damage")

	main.turret_manager.cleanup()
	var before_turrets = main.turret_manager.active_turrets.size()
	var tree_enemy = main.wave_manager.spawn_tree(Vector2(340, 260))
	if tree_enemy == null or not is_instance_valid(tree_enemy):
		failures.append("WaveManager.spawn_tree should return a tree for Pocket Factory check")
	else:
		tree_enemy.take_damage(999)
		await process_frame
		if main.turret_manager.active_turrets.size() != before_turrets + 1:
			failures.append("Pocket Factory should spawn one turret when a tree dies")
		var factory_turret = main.turret_manager.active_turrets[0] if main.turret_manager.active_turrets.size() > 0 else null
		if factory_turret != null and is_instance_valid(factory_turret):
			if str(factory_turret.get_meta("variant", "")) != "pocket_factory_turret":
				failures.append("Pocket Factory spawned turret should be tagged by source")
			if not factory_turret.is_in_group("catalog_turrets"):
				failures.append("Pocket Factory spawned turret should reuse catalog turret behavior")

	main.turret_manager.cleanup()
	_reset_enemy_pool(main)
	runtime_player.remove_upgrade(pocket_factory)
	runtime_player.remove_upgrade(pile_of_books)
	runtime_player.engineering_bonus = before_engineering
	runtime_player.crit_chance = before_crit_chance
	if int(runtime_player.get("structures_can_crit_sources")) != before_structure_crit_sources:
		failures.append("Removing Pile of Books should restore structure crit sources")
	if int(runtime_player.get("pocket_factory_sources")) != before_factory_sources:
		failures.append("Removing Pocket Factory should restore factory sources")

func _check_catalog_tyler_and_wandering_bot_structures():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Tyler/Wandering Bot check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var tyler = _find_by_source_id(pool, "tyler")
	var wandering_bot = _find_by_source_id(pool, "wandering_bot")
	if tyler.is_empty():
		failures.append("Runtime shop pool should include Tyler structure item")
	if wandering_bot.is_empty():
		failures.append("Runtime shop pool should include Wandering Bot structure item")
	if tyler.is_empty() or wandering_bot.is_empty():
		return
	if not _has_weapon_special_rule_number(tyler.get("effects", []), "spawn_tyler", "projectiles", 10.0):
		failures.append("Tyler should preserve 10 projectile special rule")
	if not _has_weapon_special_rule_number(tyler.get("effects", []), "spawn_tyler", "damage", 12.0):
		failures.append("Tyler should preserve 12 base damage special rule")
	if not _has_weapon_special_rule_number(tyler.get("effects", []), "spawn_tyler", "engineering_damage_coefficient", 0.90):
		failures.append("Tyler should preserve 90 percent Engineering damage scaling")
	if not _has_weapon_special_rule_number(tyler.get("effects", []), "spawn_tyler", "elemental_damage_coefficient", 0.90):
		failures.append("Tyler should preserve 90 percent Elemental damage scaling")
	if not _has_weapon_special_rule(wandering_bot.get("effects", []), "spawn_wandering_bot_that_slows_nearby_enemies"):
		failures.append("Wandering Bot should preserve nearby enemy slow special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Tyler/Wandering Bot check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Tyler/Wandering Bot check")
		return
	for required_property in [
		"tyler_sources",
		"wandering_bot_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Tyler/Wandering Bot" % required_property)
			return
	for required_method in [
		"spawn_tyler",
		"spawn_wandering_bot",
		"process_wandering_bots",
	]:
		if main.turret_manager == null or not main.turret_manager.has_method(required_method):
			failures.append("TurretManager should expose %s for Tyler/Wandering Bot runtime" % required_method)
			return
	if main.turret_manager.get("active_wandering_bots") == null:
		failures.append("TurretManager should track active_wandering_bots")
		return

	var before_tyler_sources = int(runtime_player.get("tyler_sources"))
	var before_bot_sources = int(runtime_player.get("wandering_bot_sources"))
	var before_engineering = int(runtime_player.engineering_bonus)
	var before_elemental = int(runtime_player.elemental_damage_bonus)
	runtime_player.engineering_bonus = 10
	runtime_player.elemental_damage_bonus = 10
	runtime_player.apply_upgrade(tyler)
	runtime_player.apply_upgrade(wandering_bot)
	if int(runtime_player.get("tyler_sources")) != before_tyler_sources + 1:
		failures.append("Applying Tyler should add one Tyler source")
	if int(runtime_player.get("wandering_bot_sources")) != before_bot_sources + 1:
		failures.append("Applying Wandering Bot should add one wandering bot source")

	main.turret_manager.cleanup()
	main.wave_manager._spawn_catalog_structures_for_wave_start()
	var spawned_tyler = _find_structure_by_variant(main.turret_manager.active_turrets, "tyler")
	if spawned_tyler == null:
		failures.append("Wave start should spawn Tyler as a structure")
	else:
		if int(spawned_tyler.get_meta("projectiles", 0)) != 10:
			failures.append("Spawned Tyler should carry 10 projectile metadata")
		if int(main.turret_manager.calculate_structure_damage(spawned_tyler)) != 30:
			failures.append("Tyler damage should scale as 12 + 90% Engineering + 90% Elemental Damage")
	if main.turret_manager.active_wandering_bots.size() != 1:
		failures.append("Wave start should spawn one Wandering Bot structure")
	var spawned_bot = main.turret_manager.active_wandering_bots[0] if main.turret_manager.active_wandering_bots.size() > 0 else null
	if spawned_bot != null and is_instance_valid(spawned_bot):
		if not spawned_bot.is_in_group("structures"):
			failures.append("Wandering Bot should count as a structure")
		if not spawned_bot.is_in_group("wandering_bots"):
			failures.append("Wandering Bot should be tagged in the wandering_bots group")
		var enemy = main.get_enemy()
		enemy.setup("normal", main.wave)
		enemy.position = spawned_bot.position + Vector2(30, 0)
		main.turret_manager.process_wandering_bots(0.1)
		if not is_equal_approx(float(enemy.get("_slow_factor")), 0.70):
			failures.append("Wandering Bot should slow nearby enemies by 30 percent")
		_reset_enemy_pool(main)

	main.turret_manager.cleanup()
	runtime_player.remove_upgrade(wandering_bot)
	runtime_player.remove_upgrade(tyler)
	runtime_player.engineering_bonus = before_engineering
	runtime_player.elemental_damage_bonus = before_elemental
	if int(runtime_player.get("tyler_sources")) != before_tyler_sources:
		failures.append("Removing Tyler should restore Tyler sources")
	if int(runtime_player.get("wandering_bot_sources")) != before_bot_sources:
		failures.append("Removing Wandering Bot should restore wandering bot sources")

func _check_catalog_spicy_sauce_consumable_explosion():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Spicy Sauce check: " + str(errors))
		return
	var spicy_sauce = _find_by_source_id(data.get_shop_pool(false), "spicy_sauce")
	if spicy_sauce.is_empty():
		failures.append("Runtime shop pool should include Spicy Sauce consumable explosion item")
		return
	if not _has_weapon_special_rule(spicy_sauce.get("effects", []), "consumable_explosion_chance"):
		failures.append("Spicy Sauce shop entry should preserve consumable explosion special rule")
		return
	if not _has_weapon_special_rule_chance(spicy_sauce.get("effects", []), "consumable_explosion_chance", 0.50):
		failures.append("Spicy Sauce should preserve 50 percent consumable explosion chance")
	if not _has_weapon_special_rule_number(spicy_sauce.get("effects", []), "consumable_explosion_chance", "damage", 10.0):
		failures.append("Spicy Sauce should preserve 10 base explosion damage")
	if not _has_weapon_special_rule_number(spicy_sauce.get("effects", []), "consumable_explosion_chance", "max_hp_damage_coefficient", 1.0):
		failures.append("Spicy Sauce should preserve 100 percent Max HP explosion scaling")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Spicy Sauce check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Spicy Sauce check")
		return
	for required_property in [
		"spicy_sauce_explosion_chance",
		"spicy_sauce_explosion_base",
		"spicy_sauce_explosion_max_hp_coefficient",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Spicy Sauce" % required_property)
			return
	if not runtime_player.has_method("deal_consumable_explosion"):
		failures.append("Player should expose deal_consumable_explosion for Spicy Sauce")
		return

	_reset_enemy_pool(main)
	main.pickup_manager.cleanup()
	var before_max_hp = int(runtime_player.max_hp)
	var before_chance = float(runtime_player.get("spicy_sauce_explosion_chance"))
	var before_base = float(runtime_player.get("spicy_sauce_explosion_base"))
	var before_coefficient = float(runtime_player.get("spicy_sauce_explosion_max_hp_coefficient"))
	runtime_player.apply_upgrade(spicy_sauce)
	if int(runtime_player.max_hp) != before_max_hp + 3:
		failures.append("Applying Spicy Sauce should add +3 Max HP")
	if not is_equal_approx(float(runtime_player.get("spicy_sauce_explosion_chance")), before_chance + 0.50):
		failures.append("Applying Spicy Sauce should add 50 percent consumable explosion chance")
	if not is_equal_approx(float(runtime_player.get("spicy_sauce_explosion_base")), 10.0):
		failures.append("Applying Spicy Sauce should set 10 base consumable explosion damage")
	if not is_equal_approx(float(runtime_player.get("spicy_sauce_explosion_max_hp_coefficient")), 1.0):
		failures.append("Applying Spicy Sauce should set 100 percent Max HP explosion scaling")

	runtime_player.spicy_sauce_explosion_chance = 1.0
	runtime_player.hp = 5
	var expected_explosion_damage = int(round(10.0 + float(runtime_player.max_hp)))
	var target = main.get_enemy()
	target.setup("normal", main.wave)
	target.position = Vector2(420, 260)
	target.hp = 40
	target.max_hp = 40
	var far_target = main.get_enemy()
	far_target.setup("normal", main.wave)
	far_target.position = Vector2(700, 260)
	far_target.hp = 40
	far_target.max_hp = 40
	main.pickup_manager._spawn_pickup(Vector2(400, 260), "fruit")
	var fruit = main.pickup_manager.active_pickup_nodes[main.pickup_manager.active_pickup_nodes.size() - 1]
	# ⚠ 拾取物的碰撞体是**半径 80** 的圆（PickupManager 里 CircleShape2D），并连了
	# `body_entered → _on_pickup_collected`。本检查是**手动**调用那个回调的，
	# 而玩家此刻就在拾取半径内，于是紧随其后的物理帧又会通过真实重叠再触发一次 ——
	# 同一个水果算两次，爆炸打两轮（实测：手动后 target=17 正确，await 一帧后变成 -6）。
	# 本检查要测的是「一次拾取触发一次正确伤害」，所以测量期间**关掉整个拾取池的
	# monitoring**（不只是当前活跃的那个：池里被回收的实例仍连着旧回调，
	# 单个断开不够）。拾取半径本身由 PickupManager 单独保证。
	# 之前没暴露，是因为 `--script` 模式下视口是 64×64，玩家被旧视口钳位推到
	# 第一屏的边上，恰好离拾取物很远；引入场地钳位后玩家停在测试摆的位置，
	# 这个潜在的双触发才显现出来。
	var saved_monitoring = []
	var pool_nodes = main.pickup_manager.active_pickup_nodes.duplicate()
	for node in main.get_children():
		if node is Area2D and node.get("monitoring") != null:
			pool_nodes.append(node)
	for node in pool_nodes:
		if is_instance_valid(node):
			saved_monitoring.append([node, node.monitoring])
			node.monitoring = false
	main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
	await process_frame
	for entry in saved_monitoring:
		if is_instance_valid(entry[0]):
			entry[0].monitoring = entry[1]
	if int(target.get("hp")) != 40 - expected_explosion_damage:
		failures.append("Spicy Sauce should deal 10 + 100 percent Max HP explosion damage on fruit pickup (expected damage %d, target hp %d of 40)" % [
			expected_explosion_damage, int(target.get("hp"))
		])
	if int(far_target.get("hp")) != 40:
		failures.append("Spicy Sauce should not damage enemies outside the explosion radius")

	_reset_enemy_pool(main)
	main.pickup_manager.cleanup()
	runtime_player.spicy_sauce_explosion_chance = before_chance + 0.50
	runtime_player.spicy_sauce_explosion_base = 10.0
	runtime_player.spicy_sauce_explosion_max_hp_coefficient = 1.0
	runtime_player.remove_upgrade(spicy_sauce)
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Removing Spicy Sauce should restore Max HP")
	if not is_equal_approx(float(runtime_player.get("spicy_sauce_explosion_chance")), before_chance):
		failures.append("Removing Spicy Sauce should restore explosion chance")
	if not is_equal_approx(float(runtime_player.get("spicy_sauce_explosion_base")), before_base):
		failures.append("Removing Spicy Sauce should restore explosion base")
	if not is_equal_approx(float(runtime_player.get("spicy_sauce_explosion_max_hp_coefficient")), before_coefficient):
		failures.append("Removing Spicy Sauce should restore explosion Max HP coefficient")

func _check_catalog_extra_stomach_full_health_consumable_max_hp():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Extra Stomach check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var extra_stomach = _find_by_source_id(pool, "extra_stomach")
	if extra_stomach.is_empty():
		failures.append("Runtime shop pool should include Extra Stomach full-health consumable Max HP modifier")
		return
	if not _has_weapon_special_rule(extra_stomach.get("effects", []), "max_hp_plus_1_on_consumable_pickup_at_full_health_max_8_per_wave"):
		failures.append("Extra Stomach shop entry should preserve its full-health consumable Max HP special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Extra Stomach full-health consumable check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Extra Stomach check")
		return
	if main.pickup_manager == null:
		failures.append("Main scene should expose PickupManager for Extra Stomach check")
		return
	if runtime_player.get("full_health_consumable_max_hp_gain_sources") == null:
		failures.append("Player should expose full_health_consumable_max_hp_gain_sources for Extra Stomach")
		return
	if runtime_player.get("full_health_consumable_max_hp_gained_this_wave") == null:
		failures.append("Player should expose full_health_consumable_max_hp_gained_this_wave for Extra Stomach")
		return
	if runtime_player.get("full_health_consumable_max_hp_gain_cap_per_wave") == null:
		failures.append("Player should expose full_health_consumable_max_hp_gain_cap_per_wave for Extra Stomach")
		return

	var before_sources = int(runtime_player.get("full_health_consumable_max_hp_gain_sources"))
	var before_cap = int(runtime_player.get("full_health_consumable_max_hp_gain_cap_per_wave"))
	runtime_player.apply_upgrade(extra_stomach)
	if int(runtime_player.get("full_health_consumable_max_hp_gain_sources")) != before_sources + 1:
		failures.append("Applying Extra Stomach should enable full-health consumable Max HP gains")
	if int(runtime_player.get("full_health_consumable_max_hp_gain_cap_per_wave")) != 8:
		failures.append("Applying Extra Stomach should set its per-wave Max HP gain cap to 8")

	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.full_health_consumable_max_hp_gained_this_wave = 0
	main.pickup_manager._spawn_pickup(runtime_player.position, "fruit")
	var fruit = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
	await process_frame
	if int(runtime_player.max_hp) != 21:
		failures.append("Extra Stomach should add 1 Max HP when fruit is collected at full health")
	if int(runtime_player.hp) != 21:
		failures.append("Extra Stomach full-health fruit pickup should remain at full HP after the fruit heal")
	if int(runtime_player.get("full_health_consumable_max_hp_gained_this_wave")) != 1:
		failures.append("Extra Stomach should track one full-health consumable Max HP gain")

	runtime_player.hp = runtime_player.max_hp - 1
	var before_not_full_max_hp = int(runtime_player.max_hp)
	main.pickup_manager._spawn_pickup(runtime_player.position, "fruit")
	fruit = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
	await process_frame
	if int(runtime_player.max_hp) != before_not_full_max_hp:
		failures.append("Extra Stomach should not add Max HP when fruit is collected below full health")

	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.full_health_consumable_max_hp_gained_this_wave = 0
	for i in range(9):
		main.pickup_manager._spawn_pickup(runtime_player.position, "fruit")
		fruit = main.pickup_manager.active_pickup_nodes.back()
		main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
		await process_frame
	if int(runtime_player.max_hp) != 28:
		failures.append("Extra Stomach should cap full-health fruit Max HP gains at 8 per wave")
	if int(runtime_player.get("full_health_consumable_max_hp_gained_this_wave")) != 8:
		failures.append("Extra Stomach should cap its per-wave gain counter at 8")

	if main.get("pending_crate_rewards") != null:
		main.pending_crate_rewards.clear()
	runtime_player.max_hp = 30
	runtime_player.hp = 30
	runtime_player.full_health_consumable_max_hp_gained_this_wave = 0
	main.pickup_manager._spawn_pickup(runtime_player.position, "crate")
	var crate = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, crate, "crate")
	await process_frame
	if int(runtime_player.max_hp) != 30:
		failures.append("Extra Stomach should not count crate pickups as consumables")
	if int(runtime_player.get("full_health_consumable_max_hp_gained_this_wave")) != 0:
		failures.append("Extra Stomach should not advance its consumable counter on crate pickup")

	runtime_player.full_health_consumable_max_hp_gained_this_wave = 8
	runtime_player.on_wave_start()
	if int(runtime_player.get("full_health_consumable_max_hp_gained_this_wave")) != 0:
		failures.append("Extra Stomach should reset its per-wave gain counter on wave start")

	runtime_player.remove_upgrade(extra_stomach)
	if int(runtime_player.get("full_health_consumable_max_hp_gain_sources")) != before_sources:
		failures.append("Removing Extra Stomach should disable future full-health consumable Max HP gains")
	if int(runtime_player.get("full_health_consumable_max_hp_gain_cap_per_wave")) != before_cap:
		failures.append("Removing Extra Stomach should restore the full-health consumable Max HP gain cap")

func _check_catalog_penguin_full_health_consumable_hp_regeneration():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Penguin check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var penguin = _find_by_source_id(pool, "penguin")
	if penguin.is_empty():
		failures.append("Runtime shop pool should include Penguin full-health consumable HP regeneration modifier")
		return
	if not _has_stat_delta(penguin.get("effects", []), "hp_regeneration", 1.0):
		failures.append("Penguin shop entry should preserve HP regeneration bonus")
	if not _has_weapon_special_rule(penguin.get("effects", []), "temporary_hp_regeneration_plus_1_on_full_health_consumable_pickup"):
		failures.append("Penguin shop entry should preserve full-health consumable HP regeneration special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Penguin full-health consumable check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Penguin check")
		return
	if main.pickup_manager == null:
		failures.append("Main scene should expose PickupManager for Penguin check")
		return
	if runtime_player.get("full_health_consumable_temp_hp_regen_sources") == null:
		failures.append("Player should expose full_health_consumable_temp_hp_regen_sources for Penguin")
		return
	if runtime_player.get("full_health_consumable_temp_hp_regen_bonus") == null:
		failures.append("Player should expose full_health_consumable_temp_hp_regen_bonus for Penguin")
		return

	var before_regen = int(runtime_player.hp_regen)
	var before_sources = int(runtime_player.get("full_health_consumable_temp_hp_regen_sources"))
	runtime_player.apply_upgrade(penguin)
	if int(runtime_player.hp_regen) != before_regen + 1:
		failures.append("Applying Penguin should add 1 HP regeneration")
	if int(runtime_player.get("full_health_consumable_temp_hp_regen_sources")) != before_sources + 1:
		failures.append("Applying Penguin should enable one full-health consumable HP regeneration source")

	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.full_health_consumable_temp_hp_regen_bonus = 0
	main.pickup_manager._spawn_pickup(runtime_player.position, "fruit")
	var fruit = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
	await process_frame
	if int(runtime_player.hp_regen) != before_regen + 2:
		failures.append("Penguin should add temporary HP regeneration when fruit is collected at full health")
	if int(runtime_player.get("full_health_consumable_temp_hp_regen_bonus")) != 1:
		failures.append("Penguin should track one temporary HP regeneration bonus")

	runtime_player.hp = runtime_player.max_hp - 1
	main.pickup_manager._spawn_pickup(runtime_player.position, "fruit")
	fruit = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
	await process_frame
	if int(runtime_player.hp_regen) != before_regen + 2:
		failures.append("Penguin should not add temporary HP regeneration when fruit is collected below full health")

	if main.get("pending_crate_rewards") != null:
		main.pending_crate_rewards.clear()
	runtime_player.hp = runtime_player.max_hp
	main.pickup_manager._spawn_pickup(runtime_player.position, "crate")
	var crate = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, crate, "crate")
	await process_frame
	if int(runtime_player.hp_regen) != before_regen + 2:
		failures.append("Penguin should not count crate pickups as consumables")

	runtime_player.on_wave_start()
	if int(runtime_player.hp_regen) != before_regen + 1:
		failures.append("Penguin temporary HP regeneration should reset at wave start")
	if int(runtime_player.get("full_health_consumable_temp_hp_regen_bonus")) != 0:
		failures.append("Penguin tracked temporary HP regeneration should clear at wave start")

	runtime_player.hp = runtime_player.max_hp
	main.pickup_manager._spawn_pickup(runtime_player.position, "fruit")
	fruit = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
	await process_frame
	if int(runtime_player.hp_regen) != before_regen + 2:
		failures.append("Penguin should resume full-health fruit HP regeneration after wave reset")

	runtime_player.remove_upgrade(penguin)
	if int(runtime_player.hp_regen) != before_regen:
		failures.append("Removing Penguin should restore HP regeneration and clear temporary bonus")
	if int(runtime_player.get("full_health_consumable_temp_hp_regen_sources")) != before_sources:
		failures.append("Removing Penguin should disable full-health consumable HP regeneration source")
	if int(runtime_player.get("full_health_consumable_temp_hp_regen_bonus")) != 0:
		failures.append("Removing Penguin should clear temporary HP regeneration bonus")

func _check_catalog_jerky_delayed_consumable_healing():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Jerky check: " + str(errors))
		return
	var jerky = _find_by_source_id(data.get_shop_pool(false), "jerky")
	if jerky.is_empty():
		failures.append("Runtime shop pool should include Jerky delayed consumable healing modifier")
		return
	if not _has_stat_delta(jerky.get("effects", []), "consumable_heal", 3.0):
		failures.append("Jerky shop entry should preserve Consumable Healing bonus")
	if not _has_weapon_special_rule(jerky.get("effects", []), "consumables_heal_over_4_seconds_instead_of_instant"):
		failures.append("Jerky should preserve delayed consumable healing special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Jerky delayed consumable healing check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Jerky check")
		return
	if main.pickup_manager == null:
		failures.append("Main scene should expose PickupManager for Jerky check")
		return
	for required_property in [
		"delayed_consumable_heal_sources",
		"delayed_consumable_heal_duration",
		"delayed_consumable_heal_entries",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Jerky" % required_property)
			return
	if not runtime_player.has_method("apply_consumable_heal"):
		failures.append("Player should expose apply_consumable_heal for Jerky")
		return
	if not runtime_player.has_method("process_delayed_consumable_healing"):
		failures.append("Player should expose process_delayed_consumable_healing for Jerky")
		return

	var before_consumable_heal = int(runtime_player.get("consumable_heal_bonus"))
	var before_sources = int(runtime_player.get("delayed_consumable_heal_sources"))
	runtime_player.apply_upgrade(jerky)
	if int(runtime_player.get("consumable_heal_bonus")) != before_consumable_heal + 3:
		failures.append("Applying Jerky should add 3 Consumable Healing")
	if int(runtime_player.get("delayed_consumable_heal_sources")) != before_sources + 1:
		failures.append("Applying Jerky should enable delayed consumable healing")
	if not is_equal_approx(float(runtime_player.get("delayed_consumable_heal_duration")), 4.0):
		failures.append("Jerky should heal consumables over 4 seconds")

	runtime_player.max_hp = max(runtime_player.max_hp, 30)
	runtime_player.hp = runtime_player.max_hp - 10
	var before_hp = int(runtime_player.hp)
	runtime_player.delayed_consumable_heal_entries.clear()
	main.pickup_manager._spawn_pickup(runtime_player.position, "fruit")
	var fruit = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(runtime_player, fruit, "fruit")
	await process_frame
	if int(runtime_player.hp) != before_hp:
		failures.append("Jerky fruit pickup should not heal instantly")
	if runtime_player.delayed_consumable_heal_entries.size() != 1:
		failures.append("Jerky fruit pickup should queue delayed healing")
	runtime_player.process_delayed_consumable_healing(0.9)
	if int(runtime_player.hp) != before_hp:
		failures.append("Jerky delayed heal should wait for a full tick")
	runtime_player.process_delayed_consumable_healing(0.1)
	if int(runtime_player.hp) != before_hp + 1:
		failures.append("Jerky delayed heal should start after one second")
	runtime_player.process_delayed_consumable_healing(3.0)
	if int(runtime_player.hp) != before_hp + 6:
		failures.append("Jerky delayed heal should deliver the full fruit heal over 4 seconds")
	if not runtime_player.delayed_consumable_heal_entries.is_empty():
		failures.append("Jerky delayed heal queue should clear after healing completes")

	runtime_player.remove_upgrade(jerky)
	if int(runtime_player.get("consumable_heal_bonus")) != before_consumable_heal:
		failures.append("Removing Jerky should restore Consumable Healing")
	if int(runtime_player.get("delayed_consumable_heal_sources")) != before_sources:
		failures.append("Removing Jerky should disable delayed consumable healing")
	runtime_player.hp = runtime_player.max_hp - 10
	before_hp = int(runtime_player.hp)
	runtime_player.apply_consumable_heal(3)
	if int(runtime_player.hp) != before_hp + 3:
		failures.append("Removing Jerky should restore instant consumable healing")
	if not runtime_player.delayed_consumable_heal_entries.is_empty():
		failures.append("Removing Jerky should clear delayed consumable healing entries")

func _check_catalog_padding_material_scaling_max_hp():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Padding check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var padding = _find_by_source_id(pool, "padding")
	if padding.is_empty():
		failures.append("Runtime shop pool should include Padding material-scaling Max HP modifier")
		return
	if not _has_stat_delta(padding.get("effects", []), "max_hp", 3.0):
		failures.append("Padding shop entry should preserve Max HP bonus")
	if not _has_weapon_special_rule(padding.get("effects", []), "max_hp_plus_1_per_80_materials"):
		failures.append("Padding shop entry should preserve material-scaling Max HP special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Padding material-scaling check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Padding check")
		return
	if main.economy == null:
		failures.append("Main scene should expose RunEconomy for Padding check")
		return
	if runtime_player.get("material_scaling_max_hp_sources") == null:
		failures.append("Player should expose material_scaling_max_hp_sources for Padding")
		return
	if runtime_player.get("material_scaling_max_hp_bonus") == null:
		failures.append("Player should expose material_scaling_max_hp_bonus for Padding")
		return

	main.economy.reset(0)
	runtime_player.gold = 0
	var before_max_hp = int(runtime_player.max_hp)
	var before_hp = int(runtime_player.hp)
	var before_sources = int(runtime_player.get("material_scaling_max_hp_sources"))
	runtime_player.apply_upgrade(padding)
	if int(runtime_player.max_hp) != before_max_hp + 3:
		failures.append("Applying Padding should add 3 Max HP before material scaling")
	if int(runtime_player.hp) != before_hp + 3:
		failures.append("Applying Padding Max HP should heal by 3 for runtime compatibility")
	if int(runtime_player.get("material_scaling_max_hp_sources")) != before_sources + 1:
		failures.append("Applying Padding should enable one material-scaling Max HP source")

	runtime_player.earn_gold(79)
	await process_frame
	if int(runtime_player.max_hp) != before_max_hp + 3:
		failures.append("Padding should not add material-scaling Max HP before 80 materials")
	runtime_player.earn_gold(1)
	await process_frame
	if int(runtime_player.max_hp) != before_max_hp + 4:
		failures.append("Padding should add 1 Max HP at 80 materials")
	if int(runtime_player.get("material_scaling_max_hp_bonus")) != 1:
		failures.append("Padding should track one material-scaling Max HP bonus at 80 materials")
	runtime_player.earn_gold(80)
	await process_frame
	if int(runtime_player.max_hp) != before_max_hp + 5:
		failures.append("Padding should add another Max HP at 160 materials")
	if int(runtime_player.get("material_scaling_max_hp_bonus")) != 2:
		failures.append("Padding should track two material-scaling Max HP bonuses at 160 materials")

	if not runtime_player.spend_materials(90):
		failures.append("Padding check could not spend materials through RunEconomy")
	else:
		await process_frame
		if int(runtime_player.max_hp) != before_max_hp + 3:
			failures.append("Padding material-scaling Max HP should shrink when held materials drop below 80")
		if int(runtime_player.get("material_scaling_max_hp_bonus")) != 0:
			failures.append("Padding should clear material-scaling bonus after spending below 80 materials")

	runtime_player.earn_gold(170)
	await process_frame
	if int(runtime_player.get("material_scaling_max_hp_bonus")) < 2:
		failures.append("Padding should recalculate material-scaling Max HP after materials increase again")
	runtime_player.remove_upgrade(padding)
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Removing Padding should restore base and material-scaling Max HP bonuses")
	if int(runtime_player.get("material_scaling_max_hp_sources")) != before_sources:
		failures.append("Removing Padding should disable material-scaling Max HP source")
	if int(runtime_player.get("material_scaling_max_hp_bonus")) != 0:
		failures.append("Removing Padding should clear material-scaling Max HP bonus")

func _check_catalog_triangle_of_power_damage_loss_on_hit():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Triangle of Power check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var triangle = _find_by_source_id(pool, "triangle_of_power")
	if triangle.is_empty():
		failures.append("Runtime shop pool should include Triangle of Power damage-loss-on-hit modifier")
		return
	if not _has_stat_delta(triangle.get("effects", []), "damage_percent", 0.20):
		failures.append("Triangle of Power shop entry should preserve Damage bonus")
	if not _has_stat_delta(triangle.get("effects", []), "armor", 1.0):
		failures.append("Triangle of Power shop entry should preserve Armor bonus")
	if not _has_weapon_special_rule(triangle.get("effects", []), "damage_percent_minus_2_when_hit_until_wave_end"):
		failures.append("Triangle of Power shop entry should preserve damage-loss-on-hit special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Triangle of Power damage-loss check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Triangle of Power check")
		return
	if runtime_player.get("damage_loss_on_hit_sources") == null:
		failures.append("Player should expose damage_loss_on_hit_sources for Triangle of Power")
		return
	if runtime_player.get("damage_loss_on_hit_bonus") == null:
		failures.append("Player should expose damage_loss_on_hit_bonus for Triangle of Power")
		return

	runtime_player.dodge_chance = 0.0
	runtime_player.ghost_dodge_chance = 0.0
	runtime_player.nullify_hits_remaining = 0
	runtime_player.invincible_timer = 0.0
	runtime_player.hp = runtime_player.max_hp
	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_armor = int(runtime_player.armor)
	var before_sources = int(runtime_player.get("damage_loss_on_hit_sources"))
	runtime_player.apply_upgrade(triangle)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.20):
		failures.append("Applying Triangle of Power should add 20% Damage before hit penalties")
	if int(runtime_player.armor) != before_armor + 1:
		failures.append("Applying Triangle of Power should add 1 Armor")
	if int(runtime_player.get("damage_loss_on_hit_sources")) != before_sources + 1:
		failures.append("Applying Triangle of Power should enable one damage-loss-on-hit source")

	runtime_player.take_damage(4)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.18):
		failures.append("Triangle of Power should lose 2% Damage after one taken hit")
	if not is_equal_approx(float(runtime_player.get("damage_loss_on_hit_bonus")), 0.02):
		failures.append("Triangle of Power should track one 2% temporary damage loss")
	runtime_player.invincible_timer = 0.0
	runtime_player.take_damage(4)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.16):
		failures.append("Triangle of Power should stack another 2% Damage loss after a second hit")
	if not is_equal_approx(float(runtime_player.get("damage_loss_on_hit_bonus")), 0.04):
		failures.append("Triangle of Power should track stacked temporary damage loss")

	runtime_player.on_wave_start()
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.20):
		failures.append("Triangle of Power damage loss should reset on wave start while keeping item Damage")
	if not is_equal_approx(float(runtime_player.get("damage_loss_on_hit_bonus")), 0.0):
		failures.append("Triangle of Power should clear tracked temporary damage loss on wave start")
	runtime_player.remove_upgrade(triangle)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Triangle of Power should restore base Damage")
	if int(runtime_player.armor) != before_armor:
		failures.append("Removing Triangle of Power should restore base Armor")
	if int(runtime_player.get("damage_loss_on_hit_sources")) != before_sources:
		failures.append("Removing Triangle of Power should disable damage-loss-on-hit source")

func _check_catalog_explosion_stat_modifiers():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for explosion stat check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var dynamite = _find_by_source_id(pool, "dynamite")
	var explosive_shells = _find_by_source_id(pool, "explosive_shells")
	var plastic_explosive = _find_by_source_id(pool, "plastic_explosive")
	var honey = _find_by_source_id(pool, "honey")
	if dynamite.is_empty():
		failures.append("Runtime shop pool should include Dynamite explosion damage modifier")
	if explosive_shells.is_empty():
		failures.append("Runtime shop pool should include Explosive Shells explosion modifier")
	if plastic_explosive.is_empty():
		failures.append("Runtime shop pool should include Plastic Explosive explosion size modifier")
	if honey.is_empty():
		failures.append("Runtime shop pool should include Honey explosion modifier")
	if dynamite.is_empty() or explosive_shells.is_empty() or plastic_explosive.is_empty() or honey.is_empty():
		return
	if not _has_stat_delta(dynamite.get("effects", []), "explosion_damage_percent", 0.15):
		failures.append("Dynamite shop entry should preserve explosion damage bonus")
	if not _has_stat_delta(explosive_shells.get("effects", []), "explosion_damage_percent", 0.60):
		failures.append("Explosive Shells shop entry should preserve explosion damage bonus")
	if not _has_stat_delta(explosive_shells.get("effects", []), "explosion_size_percent", 0.15):
		failures.append("Explosive Shells shop entry should preserve explosion size bonus")
	if not _has_stat_delta(plastic_explosive.get("effects", []), "explosion_size_percent", 0.25):
		failures.append("Plastic Explosive shop entry should preserve explosion size bonus")
	if not _has_stat_delta(honey.get("effects", []), "explosion_damage_percent", 0.10):
		failures.append("Honey shop entry should preserve explosion damage bonus")
	if not _has_stat_delta(honey.get("effects", []), "explosion_size_percent", 0.05):
		failures.append("Honey shop entry should preserve explosion size bonus")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for explosion stat check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for explosion stat check")
		return
	if runtime_player.get("explosion_damage_percent") == null:
		failures.append("Player should expose explosion_damage_percent for explosive items")
		return
	if runtime_player.get("explosion_size_percent") == null:
		failures.append("Player should expose explosion_size_percent for explosive items")
		return

	var before_explosion_damage = float(runtime_player.get("explosion_damage_percent"))
	var before_explosion_size = float(runtime_player.get("explosion_size_percent"))
	runtime_player.apply_upgrade(dynamite)
	runtime_player.apply_upgrade(plastic_explosive)
	if not is_equal_approx(float(runtime_player.get("explosion_damage_percent")), before_explosion_damage + 0.15):
		failures.append("Applying Dynamite should add 15% explosion damage")
	if not is_equal_approx(float(runtime_player.get("explosion_size_percent")), before_explosion_size + 0.25):
		failures.append("Applying Plastic Explosive should add 25% explosion size")

	_reset_bullet_pool(main)
	var enemy = main.get_enemy()
	runtime_player.position = Vector2(100, 100)
	enemy.position = Vector2(200, 100)
	runtime_player.combat._cached_enemies = [enemy]
	var test_weapon = {
		"type": "test_explosive_projectile",
		"data": {
			"name": "Test Explosive Projectile",
			"damage": 100,
			"fire_rate": 1.0,
			"count": 1,
			"spread": 0.0,
			"spd": 500.0,
			"color": Color(1, 1, 1),
			"range": 500.0,
			"splash": true,
			"splash_radius": 80
		}
	}
	var base_projectile_damage = runtime_player.combat._damage_for_weapon(test_weapon)
	runtime_player.combat.fire_weapon(test_weapon)
	var fired_bullet = _find_visible_bullet(main)
	if fired_bullet == null:
		failures.append("Explosion stat check should fire a splash bullet")
	else:
		var expected_damage = max(1, int(round(float(base_projectile_damage) * (1.0 + before_explosion_damage + 0.15))))
		var expected_radius = max(0, int(round(80.0 * (1.0 + before_explosion_size + 0.25))))
		if int(fired_bullet.get("damage")) != expected_damage:
			failures.append("Explosion damage percent should scale fired splash bullet damage")
		if int(fired_bullet.get("splash_radius")) != expected_radius:
			failures.append("Explosion size percent should scale fired splash bullet radius")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)
	_reset_bullet_pool(main)
	runtime_player.remove_upgrade(plastic_explosive)
	runtime_player.remove_upgrade(dynamite)
	if not is_equal_approx(float(runtime_player.get("explosion_damage_percent")), before_explosion_damage):
		failures.append("Removing Dynamite should restore explosion damage percent")
	if not is_equal_approx(float(runtime_player.get("explosion_size_percent")), before_explosion_size):
		failures.append("Removing Plastic Explosive should restore explosion size percent")

func _check_catalog_kraken_eye_and_sunken_bell_explosions():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Kraken's Eye/Sunken Bell check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var kraken_eye = _find_by_source_id(pool, "kraken_s_eye")
	var sunken_bell = _find_by_source_id(pool, "sunken_bell")
	if kraken_eye.is_empty():
		failures.append("Runtime shop pool should include Kraken's Eye hit explosion item")
	if sunken_bell.is_empty():
		failures.append("Runtime shop pool should include Sunken Bell low-health explosion item")
	if kraken_eye.is_empty() or sunken_bell.is_empty():
		return
	if not _has_weapon_special_rule_chance(kraken_eye.get("effects", []), "explode_on_hit_chance", 0.50):
		failures.append("Kraken's Eye should preserve 50 percent hit explosion chance")
	if not _has_weapon_special_rule_number(kraken_eye.get("effects", []), "explode_on_hit_chance", "damage", 10.0):
		failures.append("Kraken's Eye should preserve hit explosion base damage")
	if not _has_weapon_special_rule_number(kraken_eye.get("effects", []), "explode_on_hit_chance", "curse_damage_coefficient", 5.0):
		failures.append("Kraken's Eye should preserve Curse damage coefficient")
	if not _has_weapon_special_rule_number(sunken_bell.get("effects", []), "once_per_wave_explode_below_40_percent_health", "damage", 100.0):
		failures.append("Sunken Bell should preserve low-health explosion base damage")
	if not _has_weapon_special_rule_number(sunken_bell.get("effects", []), "once_per_wave_explode_below_40_percent_health", "melee_damage_coefficient", 5.0):
		failures.append("Sunken Bell should preserve melee damage coefficient")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Kraken's Eye/Sunken Bell check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Kraken's Eye/Sunken Bell check")
		return
	for required_property in [
		"hit_explosion_chance",
		"hit_explosion_base_damage",
		"hit_explosion_curse_coefficient",
		"low_health_explosion_sources",
		"low_health_explosion_triggered_this_wave",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Kraken's Eye/Sunken Bell" % required_property)
			return
	for required_method in [
		"deal_hit_explosion",
		"trigger_low_health_explosion",
		"deal_catalog_explosion",
	]:
		if not runtime_player.has_method(required_method):
			failures.append("Player should expose %s for Kraken's Eye/Sunken Bell" % required_method)
			return

	var before_hit_chance = float(runtime_player.get("hit_explosion_chance"))
	var before_low_health_sources = int(runtime_player.get("low_health_explosion_sources"))
	var before_max_hp = int(runtime_player.max_hp)
	var before_hp = int(runtime_player.hp)
	var before_curse = int(runtime_player.curse)
	var before_melee_damage = int(runtime_player.melee_damage_bonus)
	var before_ranged_damage = int(runtime_player.ranged_damage_bonus)
	var before_elemental_damage = int(runtime_player.elemental_damage_bonus)
	var before_engineering = int(runtime_player.engineering_bonus)
	runtime_player.apply_upgrade(kraken_eye)
	runtime_player.apply_upgrade(sunken_bell)
	if not is_equal_approx(float(runtime_player.get("hit_explosion_chance")), before_hit_chance + 0.50):
		failures.append("Applying Kraken's Eye should add 50 percent hit explosion chance")
	if int(runtime_player.max_hp) != before_max_hp + 15:
		failures.append("Applying Kraken's Eye should add 15 Max HP")
	if int(runtime_player.curse) != before_curse + 15:
		failures.append("Applying Kraken's Eye should add 15 Curse")
	if int(runtime_player.get("low_health_explosion_sources")) != before_low_health_sources + 1:
		failures.append("Applying Sunken Bell should enable one low-health explosion source")

	_reset_enemy_pool(main)
	runtime_player.hit_explosion_chance = 1.0
	runtime_player.hit_explosion_base_damage = 10.0
	runtime_player.hit_explosion_curse_coefficient = 5.0
	runtime_player.curse = 3
	var hit_enemy = main.get_enemy()
	var nearby_enemy = main.get_enemy()
	hit_enemy.setup("normal", 1)
	nearby_enemy.setup("normal", 1)
	hit_enemy.position = Vector2(300, 300)
	nearby_enemy.position = Vector2(360, 300)
	hit_enemy.hp = 50
	nearby_enemy.hp = 50
	runtime_player.on_enemy_hit_by_attack(hit_enemy, {"damage": 1})
	if int(nearby_enemy.hp) != 25:
		failures.append("Kraken's Eye hit explosion should damage nearby enemies for 10 plus 5 per Curse")
	if is_instance_valid(hit_enemy):
		main.recycle_enemy(hit_enemy)
	if is_instance_valid(nearby_enemy):
		main.recycle_enemy(nearby_enemy)

	runtime_player.low_health_explosion_base_damage = 100.0
	runtime_player.low_health_explosion_melee_coefficient = 5.0
	runtime_player.low_health_explosion_ranged_coefficient = 5.0
	runtime_player.low_health_explosion_elemental_coefficient = 5.0
	runtime_player.low_health_explosion_engineering_coefficient = 5.0
	runtime_player.melee_damage_bonus = 2
	runtime_player.ranged_damage_bonus = 3
	runtime_player.elemental_damage_bonus = 4
	runtime_player.engineering_bonus = 5
	runtime_player.max_hp = 100
	runtime_player.hp = 39
	runtime_player.low_health_explosion_triggered_this_wave = false
	var low_health_target = main.get_enemy()
	low_health_target.setup("normal", 1)
	low_health_target.position = runtime_player.position + Vector2(80, 0)
	low_health_target.hp = 300
	runtime_player.on_damage_taken(1)
	if int(low_health_target.hp) != 130:
		failures.append("Sunken Bell should explode below 40 percent HP for base plus combat-stat scaling damage")
	low_health_target.hp = 300
	runtime_player.on_damage_taken(1)
	if int(low_health_target.hp) != 300:
		failures.append("Sunken Bell should trigger only once per wave")
	runtime_player.on_wave_start(2)
	runtime_player.hp = 39
	runtime_player.on_damage_taken(1)
	if int(low_health_target.hp) != 130:
		failures.append("Sunken Bell should reset its once-per-wave trigger on wave start")
	if is_instance_valid(low_health_target):
		main.recycle_enemy(low_health_target)

	runtime_player.hit_explosion_chance = before_hit_chance + 0.50
	runtime_player.curse = before_curse + 15
	runtime_player.max_hp = before_max_hp + 15
	runtime_player.hp = min(before_hp + 15, runtime_player.max_hp)
	runtime_player.remove_upgrade(sunken_bell)
	runtime_player.remove_upgrade(kraken_eye)
	if not is_equal_approx(float(runtime_player.get("hit_explosion_chance")), before_hit_chance):
		failures.append("Removing Kraken's Eye should restore hit explosion chance")
	if int(runtime_player.get("low_health_explosion_sources")) != before_low_health_sources:
		failures.append("Removing Sunken Bell should restore low-health explosion sources")
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Removing Kraken's Eye should restore Max HP")
	if int(runtime_player.curse) != before_curse:
		failures.append("Removing Kraken's Eye should restore Curse")
	runtime_player.hp = before_hp
	runtime_player.melee_damage_bonus = before_melee_damage
	runtime_player.ranged_damage_bonus = before_ranged_damage
	runtime_player.elemental_damage_bonus = before_elemental_damage
	runtime_player.engineering_bonus = before_engineering

func _check_catalog_small_fish_high_health_damage():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Small Fish check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var small_fish = _find_by_source_id(pool, "small_fish")
	if small_fish.is_empty():
		failures.append("Runtime shop pool should include Small Fish high-health damage modifier")
		return
	if not _has_stat_delta(small_fish.get("effects", []), "damage_against_high_health_targets_percent", 0.10):
		failures.append("Small Fish shop entry should preserve high-health target damage bonus")
	if not _has_stat_delta(small_fish.get("effects", []), "attack_speed_percent", -0.03):
		failures.append("Small Fish shop entry should preserve attack speed penalty")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Small Fish check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Small Fish check")
		return
	if runtime_player.get("damage_against_high_health_targets_percent") == null:
		failures.append("Player should expose damage_against_high_health_targets_percent for Small Fish")
		return

	var before_bonus = float(runtime_player.get("damage_against_high_health_targets_percent"))
	var before_fire_rate = float(runtime_player.fire_rate_multiplier)
	runtime_player.apply_upgrade(small_fish)
	if not is_equal_approx(float(runtime_player.get("damage_against_high_health_targets_percent")), before_bonus + 0.10):
		failures.append("Applying Small Fish should add 10% high-health target damage")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_fire_rate - 0.03):
		failures.append("Applying Small Fish should subtract 3% attack speed")

	var enemy = main.get_enemy()
	enemy.max_hp = 100
	enemy.hp = 90
	if int(runtime_player.modify_damage_against_target(100, enemy, {})) != 110:
		failures.append("Small Fish should add 10% damage against targets above 80% HP")
	enemy.hp = 70
	if int(runtime_player.modify_damage_against_target(100, enemy, {})) != 100:
		failures.append("Small Fish should not add damage against targets below 80% HP")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)
	runtime_player.remove_upgrade(small_fish)
	if not is_equal_approx(float(runtime_player.get("damage_against_high_health_targets_percent")), before_bonus):
		failures.append("Removing Small Fish should restore high-health target damage bonus")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_fire_rate):
		failures.append("Removing Small Fish should restore attack speed")

func _check_catalog_weapon_cooldown_and_critical_pierce_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for weapon cooldown/critical pierce check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var ball_and_chain = _find_by_source_id(pool, "ball_and_chain")
	var eyepatch = _find_by_source_id(pool, "eyepatch")
	if ball_and_chain.is_empty():
		failures.append("Runtime shop pool should include Ball and Chain weapon minimum cooldown")
	if eyepatch.is_empty():
		failures.append("Runtime shop pool should include Eyepatch critical-hit piercing")
	if ball_and_chain.is_empty() or eyepatch.is_empty():
		return
	if not _has_weapon_special_rule(ball_and_chain.get("effects", []), "weapon_minimum_cooldown_0_75_seconds"):
		failures.append("Ball and Chain should preserve weapon minimum cooldown rule")
	if not _has_stat_delta(ball_and_chain.get("effects", []), "damage_percent", 0.15):
		failures.append("Ball and Chain should preserve Damage bonus")
	if not _has_stat_delta(ball_and_chain.get("effects", []), "armor", 3.0):
		failures.append("Ball and Chain should preserve Armor bonus")
	if not _has_stat_delta(ball_and_chain.get("effects", []), "knockback", 5.0):
		failures.append("Ball and Chain should preserve Knockback bonus")
	if not _has_stat_delta(ball_and_chain.get("effects", []), "speed_percent", -0.03):
		failures.append("Ball and Chain should preserve Speed penalty")
	if not _has_weapon_special_rule(eyepatch.get("effects", []), "projectiles_gain_1_piercing_on_critical_hit"):
		failures.append("Eyepatch should preserve critical-hit piercing rule")
	if not _has_stat_delta(eyepatch.get("effects", []), "crit_chance", 0.03):
		failures.append("Eyepatch should preserve Crit Chance bonus")
	if not _has_stat_delta(eyepatch.get("effects", []), "accuracy_percent", -0.10):
		failures.append("Eyepatch should preserve Accuracy penalty")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for weapon cooldown/critical pierce check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for weapon cooldown/critical pierce check")
		return
	for required_property in [
		"weapon_minimum_cooldown",
		"weapon_minimum_cooldown_sources",
		"critical_hit_projectile_pierce_bonus",
		"accuracy_percent",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for weapon cooldown/critical pierce items" % required_property)
			return

	runtime_player.damage_percent_bonus = 0.0
	runtime_player.armor = 0
	runtime_player.knockback_bonus = 0.0
	runtime_player.base_speed = 300.0
	runtime_player.speed = 300.0
	runtime_player.weapon_minimum_cooldown = 0.0
	runtime_player.weapon_minimum_cooldown_sources = 0
	runtime_player.apply_upgrade(ball_and_chain)
	if int(runtime_player.get("weapon_minimum_cooldown_sources")) != 1:
		failures.append("Applying Ball and Chain should enable one weapon cooldown floor source")
	if not is_equal_approx(float(runtime_player.get("weapon_minimum_cooldown")), 0.75):
		failures.append("Applying Ball and Chain should set weapon cooldown floor to 0.75 seconds")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.15):
		failures.append("Applying Ball and Chain should add 15 percent Damage")
	if int(runtime_player.armor) != 3:
		failures.append("Applying Ball and Chain should add 3 Armor")
	if not is_equal_approx(float(runtime_player.knockback_bonus), 5.0):
		failures.append("Applying Ball and Chain should add 5 Knockback")
	if not is_equal_approx(float(runtime_player.base_speed), 291.0):
		failures.append("Applying Ball and Chain should subtract 3 percent Speed")

	_reset_bullet_pool(main)
	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	runtime_player.position = Vector2(100, 100)
	enemy.position = Vector2(200, 100)
	runtime_player.combat._cached_enemies = [enemy]
	var cooldown_weapon = {
		"type": "test_fast_projectile",
		"timer": 0.0,
		"data": {
			"name": "Test Fast Projectile",
			"damage": 5,
			"fire_rate": 4.0,
			"count": 1,
			"spread": 0.0,
			"spd": 500.0,
			"color": Color(1, 1, 1),
			"range": 500.0
		}
	}
	runtime_player.equipped_weapons = [cooldown_weapon]
	runtime_player.combat.process_weapons(0.0)
	if not is_equal_approx(float(runtime_player.equipped_weapons[0].timer), 0.75):
		failures.append("Ball and Chain should force fast weapons to at least 0.75 seconds cooldown")
	runtime_player.equipped_weapons.clear()
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)
	_reset_bullet_pool(main)
	runtime_player.remove_upgrade(ball_and_chain)
	if int(runtime_player.get("weapon_minimum_cooldown_sources")) != 0:
		failures.append("Removing Ball and Chain should clear weapon cooldown floor source count")
	if not is_equal_approx(float(runtime_player.get("weapon_minimum_cooldown")), 0.0):
		failures.append("Removing Ball and Chain should clear weapon cooldown floor")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.0):
		failures.append("Removing Ball and Chain should restore Damage")
	if int(runtime_player.armor) != 0:
		failures.append("Removing Ball and Chain should restore Armor")
	if not is_equal_approx(float(runtime_player.knockback_bonus), 0.0):
		failures.append("Removing Ball and Chain should restore Knockback")
	if not is_equal_approx(float(runtime_player.base_speed), 300.0):
		failures.append("Removing Ball and Chain should restore Speed")

	runtime_player.crit_chance = 0.0
	runtime_player.accuracy_percent = 0.0
	runtime_player.critical_hit_projectile_pierce_bonus = 0
	runtime_player.apply_upgrade(eyepatch)
	if not is_equal_approx(float(runtime_player.crit_chance), 0.03):
		failures.append("Applying Eyepatch should add 3 percent Crit Chance")
	if not is_equal_approx(float(runtime_player.get("accuracy_percent")), -0.10):
		failures.append("Applying Eyepatch should subtract 10 percent Accuracy")
	if int(runtime_player.get("critical_hit_projectile_pierce_bonus")) != 1:
		failures.append("Applying Eyepatch should add one critical-hit projectile pierce")

	_reset_bullet_pool(main)
	_reset_enemy_pool(main)
	var crit_enemy = main.get_enemy()
	crit_enemy.setup("normal", 1)
	runtime_player.position = Vector2(100, 100)
	crit_enemy.position = Vector2(200, 100)
	runtime_player.combat._cached_enemies = [crit_enemy]
	runtime_player.crit_chance = 1.0
	var crit_weapon = {
		"type": "test_crit_projectile",
		"data": {
			"name": "Test Crit Projectile",
			"damage": 5,
			"fire_rate": 1.0,
			"count": 1,
			"spread": 0.0,
			"spd": 500.0,
			"color": Color(1, 1, 1),
			"range": 500.0
		}
	}
	runtime_player.combat.fire_weapon(crit_weapon)
	var fired_bullet = _find_visible_bullet(main)
	if fired_bullet == null:
		failures.append("Eyepatch critical-hit pierce check should fire a bullet")
	else:
		if not bool(fired_bullet.get("is_crit")):
			failures.append("Eyepatch critical-hit pierce check should force a critical bullet")
		if not bool(fired_bullet.get("pierce")):
			failures.append("Eyepatch should make critical non-piercing bullets pierce")
		if int(fired_bullet.get("pierce_hit_limit")) != 2:
			failures.append("Eyepatch should let critical non-piercing bullets hit 2 enemies")
	if is_instance_valid(crit_enemy):
		main.recycle_enemy(crit_enemy)
	_reset_bullet_pool(main)
	runtime_player.remove_upgrade(eyepatch)
	if int(runtime_player.get("critical_hit_projectile_pierce_bonus")) != 0:
		failures.append("Removing Eyepatch should clear critical-hit projectile pierce")
	if not is_equal_approx(float(runtime_player.get("accuracy_percent")), 0.0):
		failures.append("Removing Eyepatch should restore Accuracy")
	runtime_player.crit_chance = 0.0

func _check_catalog_knot_weapon_upgrade_lock():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Knot check: " + str(errors))
		return
	var knot = _find_by_source_id(data.get_shop_pool(false), "knot")
	if knot.is_empty():
		failures.append("Runtime shop pool should include Knot weapon upgrade lock")
		return
	if not _has_stat_delta(knot.get("effects", []), "damage_percent", 0.15):
		failures.append("Knot should preserve Damage bonus")
	if not _has_stat_delta(knot.get("effects", []), "max_hp", 15.0):
		failures.append("Knot should preserve Max HP bonus")
	if not _has_weapon_special_rule(knot.get("effects", []), "weapons_can_no_longer_be_upgraded_or_recycled"):
		failures.append("Knot should preserve weapon upgrade/recycle lock rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Knot weapon upgrade lock check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Knot check")
		return
	if runtime_player.get("weapon_upgrade_locked_sources") == null:
		failures.append("Player should expose weapon_upgrade_locked_sources for Knot")
		return

	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_max_hp = int(runtime_player.max_hp)
	var before_sources = int(runtime_player.get("weapon_upgrade_locked_sources"))
	runtime_player.equipped_weapons.clear()
	runtime_player.apply_upgrade(knot)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.15):
		failures.append("Applying Knot should add 15 percent Damage")
	if int(runtime_player.max_hp) != before_max_hp + 15:
		failures.append("Applying Knot should add 15 Max HP")
	if int(runtime_player.get("weapon_upgrade_locked_sources")) != before_sources + 1:
		failures.append("Applying Knot should lock weapon upgrades")

	if not runtime_player.equip_or_combine_weapon("pistol", 1):
		failures.append("Knot should still allow equipping a weapon in an empty slot")
	if not runtime_player.equip_or_combine_weapon("pistol", 1):
		failures.append("Knot should allow buying a duplicate weapon when a slot is open")
	if runtime_player.equipped_weapons.size() != 2:
		failures.append("Knot should prevent duplicate weapons from auto-combining")
	else:
		if int(runtime_player.equipped_weapons[0].get("tier", 1)) != 1 or int(runtime_player.equipped_weapons[1].get("tier", 1)) != 1:
			failures.append("Knot should keep duplicate same-tier weapons unmerged")
	if runtime_player.can_combine_weapon(0):
		failures.append("Knot should disable explicit weapon combining")
	if runtime_player.combine_weapon(0):
		failures.append("Knot should block weapon combine execution")

	runtime_player.remove_upgrade(knot)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Knot should restore Damage")
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Removing Knot should restore Max HP")
	if int(runtime_player.get("weapon_upgrade_locked_sources")) != before_sources:
		failures.append("Removing Knot should clear weapon upgrade lock")
	if not runtime_player.can_combine_weapon(0):
		failures.append("Removing Knot should restore explicit weapon combining")
	if not runtime_player.combine_weapon(0):
		failures.append("Removing Knot should allow weapon combine execution")
	if runtime_player.equipped_weapons.size() != 1 or int(runtime_player.equipped_weapons[0].get("tier", 1)) != 2:
		failures.append("Removing Knot should let duplicate weapons combine into Tier 2")
	runtime_player.equipped_weapons.clear()

func _check_catalog_coil_knockback_scaling_damage():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Coil check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var coil = _find_by_source_id(pool, "coil")
	var boxing_glove = _find_by_source_id(pool, "boxing_glove")
	if coil.is_empty():
		failures.append("Runtime shop pool should include Coil knockback-scaling damage modifier")
	if boxing_glove.is_empty():
		failures.append("Runtime shop pool should include Boxing Glove knockback stat modifier for Coil check")
	if coil.is_empty() or boxing_glove.is_empty():
		return
	if not _has_stat_delta(coil.get("effects", []), "knockback", 5.0):
		failures.append("Coil shop entry should preserve knockback bonus")
	if not _has_weapon_special_rule(coil.get("effects", []), "damage_percent_plus_1_per_1_knockback"):
		failures.append("Coil shop entry should preserve knockback-scaling damage special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Coil check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Coil check")
		return
	if runtime_player.get("knockback_scaling_damage_sources") == null:
		failures.append("Player should expose knockback_scaling_damage_sources for Coil")
		return
	if runtime_player.get("knockback_scaling_damage_bonus") == null:
		failures.append("Player should expose knockback_scaling_damage_bonus for Coil")
		return

	var before_knockback = float(runtime_player.knockback_bonus)
	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_sources = int(runtime_player.get("knockback_scaling_damage_sources"))
	runtime_player.apply_upgrade(coil)
	if not is_equal_approx(float(runtime_player.knockback_bonus), before_knockback + 5.0):
		failures.append("Applying Coil should add 5 knockback")
	if int(runtime_player.get("knockback_scaling_damage_sources")) != before_sources + 1:
		failures.append("Applying Coil should enable one knockback-scaling damage source")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.05):
		failures.append("Applying Coil should add 1% Damage per current knockback")
	if not is_equal_approx(float(runtime_player.get("knockback_scaling_damage_bonus")), 0.05):
		failures.append("Coil should track knockback-scaling damage bonus")

	runtime_player.apply_upgrade(boxing_glove)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.08):
		failures.append("Coil should recalculate Damage when later knockback stats increase")
	runtime_player.remove_upgrade(boxing_glove)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.05):
		failures.append("Coil should recalculate Damage when later knockback stats are removed")

	runtime_player.remove_upgrade(coil)
	if not is_equal_approx(float(runtime_player.knockback_bonus), before_knockback):
		failures.append("Removing Coil should restore knockback")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Coil should restore knockback-scaling Damage")
	if int(runtime_player.get("knockback_scaling_damage_sources")) != before_sources:
		failures.append("Removing Coil should disable knockback-scaling damage source")
	if not is_equal_approx(float(runtime_player.get("knockback_scaling_damage_bonus")), 0.0):
		failures.append("Removing Coil should clear tracked knockback-scaling Damage")

func _check_catalog_stat_scaling_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for stat-scaling item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var power_generator = _find_by_source_id(pool, "power_generator")
	var beanie = _find_by_source_id(pool, "beanie")
	var hoodie = _find_by_source_id(pool, "retromation_s_hoodie")
	var adrenaline = _find_by_source_id(pool, "adrenaline")
	var stone_skin = _find_by_source_id(pool, "stone_skin")
	var helmet = _find_by_source_id(pool, "helmet")
	var strange_book = _find_by_source_id(pool, "strange_book")
	var charcoal = _find_by_source_id(pool, "charcoal")
	if power_generator.is_empty():
		failures.append("Runtime shop pool should include Power Generator speed-scaling damage modifier")
	if beanie.is_empty():
		failures.append("Runtime shop pool should include Beanie speed stat modifier for Power Generator check")
	if hoodie.is_empty():
		failures.append("Runtime shop pool should include Retromation's Hoodie dodge-scaling attack speed modifier")
	if adrenaline.is_empty():
		failures.append("Runtime shop pool should include Adrenaline dodge stat modifier for Hoodie check")
	if stone_skin.is_empty():
		failures.append("Runtime shop pool should include Stone Skin armor-scaling Max HP modifier")
	if helmet.is_empty():
		failures.append("Runtime shop pool should include Helmet armor stat modifier for Stone Skin check")
	if strange_book.is_empty():
		failures.append("Runtime shop pool should include Strange Book elemental-scaling Engineering modifier")
	if charcoal.is_empty():
		failures.append("Runtime shop pool should include Charcoal elemental damage stat modifier for Strange Book check")
	if power_generator.is_empty() or beanie.is_empty() or hoodie.is_empty() or adrenaline.is_empty() or stone_skin.is_empty() or helmet.is_empty() or strange_book.is_empty() or charcoal.is_empty():
		return
	if not _has_weapon_special_rule(power_generator.get("effects", []), "damage_percent_plus_1_per_1_permanent_speed_percent"):
		failures.append("Power Generator should preserve speed-scaling damage special rule")
	if not _has_weapon_special_rule(hoodie.get("effects", []), "attack_speed_percent_plus_2_per_1_dodge_percent"):
		failures.append("Retromation's Hoodie should preserve dodge-scaling attack speed special rule")
	if not _has_weapon_special_rule(stone_skin.get("effects", []), "max_hp_plus_1_per_1_permanent_armor"):
		failures.append("Stone Skin should preserve armor-scaling Max HP special rule")
	if not _has_weapon_special_rule(strange_book.get("effects", []), "engineering_plus_1_per_1_permanent_elemental_damage"):
		failures.append("Strange Book should preserve elemental-scaling Engineering special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for stat-scaling item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for stat-scaling item check")
		return
	for required_property in [
		"speed_scaling_damage_sources",
		"speed_scaling_damage_bonus",
		"dodge_scaling_attack_speed_sources",
		"dodge_scaling_attack_speed_bonus",
		"armor_scaling_max_hp_sources",
		"armor_scaling_max_hp_bonus",
		"elemental_scaling_engineering_sources",
		"elemental_scaling_engineering_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for stat-scaling catalog items" % required_property)
			return

	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_speed = float(runtime_player.base_speed)
	runtime_player.apply_upgrade(power_generator)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.05):
		failures.append("Applying Power Generator should keep its -5% Damage penalty before speed scaling")
	runtime_player.apply_upgrade(beanie)
	if not is_equal_approx(float(runtime_player.base_speed), before_speed + 12.0):
		failures.append("Applying Beanie should add 4% speed for Power Generator check")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.01):
		failures.append("Power Generator should add 1% Damage per positive permanent Speed percent")
	if not is_equal_approx(float(runtime_player.get("speed_scaling_damage_bonus")), 0.04):
		failures.append("Power Generator should track speed-scaling Damage bonus")
	runtime_player.remove_upgrade(beanie)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.05):
		failures.append("Power Generator should recalculate Damage when speed stats are removed")
	runtime_player.remove_upgrade(power_generator)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Power Generator should restore Damage")

	var before_attack_speed = float(runtime_player.fire_rate_multiplier)
	var before_dodge = float(runtime_player.dodge_chance)
	runtime_player.apply_upgrade(hoodie)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_attack_speed):
		failures.append("Retromation's Hoodie should not add attack speed before dodge is present")
	runtime_player.apply_upgrade(adrenaline)
	if not is_equal_approx(float(runtime_player.dodge_chance), before_dodge + 0.05):
		failures.append("Applying Adrenaline should add 5% dodge for Hoodie check")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_attack_speed + 0.10):
		failures.append("Retromation's Hoodie should add 2% attack speed per 1% dodge")
	if not is_equal_approx(float(runtime_player.get("dodge_scaling_attack_speed_bonus")), 0.10):
		failures.append("Retromation's Hoodie should track dodge-scaling attack speed bonus")
	runtime_player.remove_upgrade(adrenaline)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_attack_speed):
		failures.append("Retromation's Hoodie should recalculate attack speed when dodge is removed")
	runtime_player.remove_upgrade(hoodie)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_attack_speed):
		failures.append("Removing Retromation's Hoodie should restore attack speed")

	var before_max_hp = int(runtime_player.max_hp)
	var before_hp = int(runtime_player.hp)
	var before_armor = int(runtime_player.armor)
	runtime_player.apply_upgrade(stone_skin)
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Stone Skin should not add Max HP before armor is present")
	runtime_player.apply_upgrade(helmet)
	if int(runtime_player.armor) != before_armor + 1:
		failures.append("Applying Helmet should add 1 Armor for Stone Skin check")
	if int(runtime_player.max_hp) != before_max_hp + 1:
		failures.append("Stone Skin should add 1 Max HP per current Armor")
	if int(runtime_player.hp) != min(before_hp + 1, before_max_hp + 1):
		failures.append("Stone Skin dynamic Max HP gain should heal by the dynamic Max HP delta")
	if int(runtime_player.get("armor_scaling_max_hp_bonus")) != 1:
		failures.append("Stone Skin should track armor-scaling Max HP bonus")
	runtime_player.remove_upgrade(helmet)
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Stone Skin should recalculate Max HP when Armor is removed")
	runtime_player.remove_upgrade(stone_skin)
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Removing Stone Skin should restore Max HP")

	var before_engineering = int(runtime_player.engineering_bonus)
	var before_elemental = int(runtime_player.elemental_damage_bonus)
	runtime_player.apply_upgrade(strange_book)
	if int(runtime_player.engineering_bonus) != before_engineering:
		failures.append("Strange Book should not add Engineering before Elemental Damage is present")
	runtime_player.apply_upgrade(charcoal)
	if int(runtime_player.elemental_damage_bonus) != before_elemental + 1:
		failures.append("Applying Charcoal should add 1 Elemental Damage for Strange Book check")
	if int(runtime_player.engineering_bonus) != before_engineering + 1:
		failures.append("Strange Book should add 1 Engineering per current Elemental Damage")
	if int(runtime_player.get("elemental_scaling_engineering_bonus")) != 1:
		failures.append("Strange Book should track elemental-scaling Engineering bonus")
	runtime_player.remove_upgrade(charcoal)
	if int(runtime_player.engineering_bonus) != before_engineering:
		failures.append("Strange Book should recalculate Engineering when Elemental Damage is removed")
	runtime_player.remove_upgrade(strange_book)
	if int(runtime_player.engineering_bonus) != before_engineering:
		failures.append("Removing Strange Book should restore Engineering")

func _check_catalog_fairy_item_tier_regeneration():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Fairy check: " + str(errors))
		return
	var fairy = _find_by_source_id(data.get_shop_pool(false), "fairy")
	if fairy.is_empty():
		failures.append("Runtime shop pool should include Fairy item-tier regeneration modifier")
		return
	if not _has_weapon_special_rule(fairy.get("effects", []), "hp_regeneration_plus_1_per_different_tier_1_item"):
		failures.append("Fairy should preserve tier 1 item regeneration rule")
	if not _has_weapon_special_rule(fairy.get("effects", []), "hp_regeneration_minus_3_per_different_tier_4_item"):
		failures.append("Fairy should preserve tier 4 item regeneration penalty rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Fairy check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Fairy check")
		return
	for required_property in [
		"catalog_owned_item_tier_counts",
		"fairy_tier1_regen_sources",
		"fairy_tier4_regen_sources",
		"fairy_item_tier_regen_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Fairy" % required_property)
			return
	for required_method in [
		"record_catalog_item_ownership",
		"get_distinct_owned_item_count_for_tier",
		"recalculate_fairy_item_tier_regeneration",
	]:
		if not runtime_player.has_method(required_method):
			failures.append("Player should expose %s for Fairy" % required_method)
			return

	var before_hp_regen = int(runtime_player.hp_regen)
	var before_tier1_sources = int(runtime_player.get("fairy_tier1_regen_sources"))
	var before_tier4_sources = int(runtime_player.get("fairy_tier4_regen_sources"))
	runtime_player.catalog_owned_item_tier_counts.clear()
	runtime_player.fairy_item_tier_regen_bonus = 0
	var tier1_a = {"type": "catalog_item", "source_id": "fairy_test_tier_1_a", "rarity": 0, "effects": []}
	var tier1_b = {"type": "catalog_item", "source_id": "fairy_test_tier_1_b", "rarity": 0, "effects": []}
	var tier4_a = {"type": "catalog_item", "source_id": "fairy_test_tier_4_a", "rarity": 3, "effects": []}
	runtime_player.apply_upgrade(fairy)
	if int(runtime_player.get("fairy_tier1_regen_sources")) != before_tier1_sources + 1:
		failures.append("Applying Fairy should enable tier 1 regeneration scaling")
	if int(runtime_player.get("fairy_tier4_regen_sources")) != before_tier4_sources + 1:
		failures.append("Applying Fairy should enable tier 4 regeneration penalty scaling")
	runtime_player.apply_upgrade(tier1_a)
	runtime_player.apply_upgrade(tier1_b)
	runtime_player.apply_upgrade(tier4_a)
	if int(runtime_player.get_distinct_owned_item_count_for_tier(1)) < 2:
		failures.append("Fairy tracking should count distinct owned tier 1 items")
	if int(runtime_player.get_distinct_owned_item_count_for_tier(4)) < 1:
		failures.append("Fairy tracking should count distinct owned tier 4 items")
	if int(runtime_player.hp_regen) != before_hp_regen - 1:
		failures.append("Fairy should add +1 HP Regeneration per tier 1 item and -3 per tier 4 item")
	if int(runtime_player.get("fairy_item_tier_regen_bonus")) != -1:
		failures.append("Fairy should track its net item-tier HP Regeneration bonus")
	runtime_player.remove_upgrade(tier4_a)
	if int(runtime_player.hp_regen) != before_hp_regen + 2:
		failures.append("Removing a tier 4 item should remove Fairy's tier 4 HP Regeneration penalty")
	runtime_player.remove_upgrade(fairy)
	if int(runtime_player.hp_regen) != before_hp_regen:
		failures.append("Removing Fairy should clear item-tier HP Regeneration bonus")
	if int(runtime_player.get("fairy_tier1_regen_sources")) != before_tier1_sources:
		failures.append("Removing Fairy should restore tier 1 source count")
	if int(runtime_player.get("fairy_tier4_regen_sources")) != before_tier4_sources:
		failures.append("Removing Fairy should restore tier 4 source count")
	runtime_player.remove_upgrade(tier1_b)
	runtime_player.remove_upgrade(tier1_a)

func _check_catalog_dynamic_weapon_and_speed_scaling_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for dynamic weapon/speed scaling item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var jelly = _find_by_source_id(pool, "jelly")
	var spider = _find_by_source_id(pool, "spider")
	var focus = _find_by_source_id(pool, "focus")
	var estys_couch = _find_by_source_id(pool, "esty_s_couch")
	var beanie = _find_by_source_id(pool, "beanie")
	if jelly.is_empty():
		failures.append("Runtime shop pool should include Jelly distinct-weapon Max HP modifier")
	if spider.is_empty():
		failures.append("Runtime shop pool should include Spider distinct-weapon attack speed modifier")
	if focus.is_empty():
		failures.append("Runtime shop pool should include Focus distinct-weapon attack speed penalty")
	if estys_couch.is_empty():
		failures.append("Runtime shop pool should include Esty's Couch negative-Speed HP regeneration modifier")
	if beanie.is_empty():
		failures.append("Runtime shop pool should include Beanie for Esty's Couch speed recalculation check")
	if jelly.is_empty() or spider.is_empty() or focus.is_empty() or estys_couch.is_empty() or beanie.is_empty():
		return
	if not _has_weapon_special_rule(jelly.get("effects", []), "max_hp_plus_1_per_distinct_weapon"):
		failures.append("Jelly should preserve distinct-weapon Max HP special rule")
	if not _has_weapon_special_rule(spider.get("effects", []), "attack_speed_percent_plus_6_per_different_weapon"):
		failures.append("Spider should preserve distinct-weapon attack speed special rule")
	if not _has_weapon_special_rule(focus.get("effects", []), "attack_speed_percent_minus_3_per_different_weapon"):
		failures.append("Focus should preserve distinct-weapon attack speed penalty special rule")
	if not _has_weapon_special_rule(estys_couch.get("effects", []), "hp_regeneration_plus_2_per_negative_1_permanent_speed_percent"):
		failures.append("Esty's Couch should preserve negative-Speed HP regeneration special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for dynamic weapon/speed scaling item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for dynamic weapon/speed scaling item check")
		return
	for required_property in [
		"distinct_weapon_max_hp_sources",
		"distinct_weapon_max_hp_bonus",
		"distinct_weapon_attack_speed_per_weapon",
		"distinct_weapon_attack_speed_bonus",
		"negative_speed_regen_sources",
		"negative_speed_regen_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for dynamic weapon/speed scaling items" % required_property)
			return
	if not runtime_player.has_method("recalculate_distinct_weapon_scaling"):
		failures.append("Player should expose recalculate_distinct_weapon_scaling for Jelly/Spider/Focus")
		return
	if not runtime_player.has_method("recalculate_negative_speed_regen"):
		failures.append("Player should expose recalculate_negative_speed_regen for Esty's Couch")
		return

	runtime_player.equipped_weapons.clear()
	runtime_player.max_hp = 10
	runtime_player.hp = 10
	var before_max_hp = int(runtime_player.max_hp)
	runtime_player.apply_upgrade(jelly)
	if int(runtime_player.get("distinct_weapon_max_hp_sources")) != 1:
		failures.append("Applying Jelly should enable one distinct-weapon Max HP source")
	runtime_player.equip_or_combine_weapon("pistol", 1)
	if int(runtime_player.max_hp) != before_max_hp + 1:
		failures.append("Jelly should add 1 Max HP for one distinct weapon")
	runtime_player.equip_or_combine_weapon("laser_gun", 1)
	if int(runtime_player.max_hp) != before_max_hp + 2:
		failures.append("Jelly should add 1 Max HP for each distinct weapon")
	runtime_player.equip_or_combine_weapon("pistol", 1)
	if int(runtime_player.max_hp) != before_max_hp + 2:
		failures.append("Jelly should count distinct weapon types, not duplicate copies")
	runtime_player.equipped_weapons.clear()
	runtime_player.recalculate_distinct_weapon_scaling()
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Jelly should remove dynamic Max HP when distinct weapons are removed")
	runtime_player.remove_upgrade(jelly)
	if int(runtime_player.get("distinct_weapon_max_hp_sources")) != 0:
		failures.append("Removing Jelly should disable distinct-weapon Max HP scaling")

	runtime_player.equipped_weapons.clear()
	runtime_player.equip_or_combine_weapon("pistol", 1)
	runtime_player.equip_or_combine_weapon("laser_gun", 1)
	runtime_player.equip_or_combine_weapon("smg", 1)
	runtime_player.fire_rate_multiplier = 1.0
	runtime_player.damage_percent_bonus = 0.0
	runtime_player.dodge_chance = 0.0
	runtime_player.gold_per_wave = 0
	runtime_player.apply_upgrade(spider)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.12):
		failures.append("Applying Spider should add 12% Damage")
	if not is_equal_approx(float(runtime_player.dodge_chance), -0.03):
		failures.append("Applying Spider should subtract 3% Dodge")
	if int(runtime_player.gold_per_wave) != -5:
		failures.append("Applying Spider should subtract 5 Harvesting")
	if not is_equal_approx(float(runtime_player.get("distinct_weapon_attack_speed_per_weapon")), 0.06):
		failures.append("Applying Spider should add +6% Attack Speed per distinct weapon")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.18):
		failures.append("Spider should add Attack Speed based on current distinct weapon types")
	runtime_player.apply_upgrade(focus)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.42):
		failures.append("Applying Focus should add 30% Damage")
	if not is_equal_approx(float(runtime_player.get("distinct_weapon_attack_speed_per_weapon")), 0.03):
		failures.append("Focus should net against Spider's per-weapon Attack Speed coefficient")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.09):
		failures.append("Focus should recalculate Attack Speed from the net distinct-weapon coefficient")
	runtime_player.equip_or_combine_weapon("revolver", 1)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.12):
		failures.append("Distinct-weapon Attack Speed should recalculate when a new weapon type is equipped")
	runtime_player.remove_upgrade(focus)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.12):
		failures.append("Removing Focus should restore its Damage bonus")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.24):
		failures.append("Removing Focus should recalculate Spider's full distinct-weapon Attack Speed bonus")
	runtime_player.remove_upgrade(spider)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.0):
		failures.append("Removing Spider should restore its Damage bonus")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.0):
		failures.append("Removing Spider should clear distinct-weapon Attack Speed scaling")

	runtime_player.max_hp = 10
	runtime_player.hp = 10
	runtime_player.hp_regen = 0
	runtime_player.speed = 300.0
	runtime_player.base_speed = 300.0
	runtime_player.apply_upgrade(estys_couch)
	if int(runtime_player.max_hp) != 15:
		failures.append("Applying Esty's Couch should add 5 Max HP")
	if not is_equal_approx(float(runtime_player.base_speed), 240.0):
		failures.append("Applying Esty's Couch should subtract 20% Speed")
	if int(runtime_player.hp_regen) != 40:
		failures.append("Esty's Couch should add 2 HP Regeneration per negative 1% Speed")
	if int(runtime_player.get("negative_speed_regen_bonus")) != 40:
		failures.append("Esty's Couch should track its dynamic HP Regeneration bonus")
	runtime_player.apply_upgrade(beanie)
	if not is_equal_approx(float(runtime_player.base_speed), 252.0):
		failures.append("Applying Beanie should add 4% Speed for Esty's Couch recalculation")
	if int(runtime_player.hp_regen) != 32:
		failures.append("Esty's Couch should recalculate HP Regeneration when Speed becomes less negative")
	runtime_player.remove_upgrade(beanie)
	if int(runtime_player.hp_regen) != 40:
		failures.append("Esty's Couch should recalculate HP Regeneration when Speed becomes more negative again")
	runtime_player.remove_upgrade(estys_couch)
	if int(runtime_player.max_hp) != 10:
		failures.append("Removing Esty's Couch should restore Max HP")
	if int(runtime_player.hp_regen) != 0:
		failures.append("Removing Esty's Couch should clear dynamic HP Regeneration")
	if not is_equal_approx(float(runtime_player.base_speed), 300.0):
		failures.append("Removing Esty's Couch should restore Speed")

func _check_catalog_next_wave_and_growth_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for next-wave/growth item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var crown = _find_by_source_id(pool, "crown")
	var peacock = _find_by_source_id(pool, "peacock")
	var celery_tea = _find_by_source_id(pool, "celery_tea")
	var scarf = _find_by_source_id(pool, "scarf")
	if crown.is_empty():
		failures.append("Runtime shop pool should include Crown end-wave harvesting growth modifier")
	if peacock.is_empty():
		failures.append("Runtime shop pool should include Peacock next-wave XP/enemy damage modifier")
	if celery_tea.is_empty():
		failures.append("Runtime shop pool should include Celery Tea end-wave XP and next-wave enemy health modifier")
	if scarf.is_empty():
		failures.append("Runtime shop pool should include Scarf next-wave enemy speed modifier")
	if crown.is_empty() or peacock.is_empty() or celery_tea.is_empty() or scarf.is_empty():
		return
	if not _has_weapon_special_rule(crown.get("effects", []), "harvesting_growth_percent_plus_8_end_wave"):
		failures.append("Crown should preserve end-wave Harvesting growth special rule")
	if not _has_weapon_special_rule(peacock.get("effects", []), "next_wave_xp_gain_percent_plus_100"):
		failures.append("Peacock should preserve next-wave XP Gain special rule")
	if not _has_weapon_special_rule(peacock.get("effects", []), "next_wave_enemy_damage_percent_plus_50"):
		failures.append("Peacock should preserve next-wave enemy damage special rule")
	if not _has_weapon_special_rule(celery_tea.get("effects", []), "xp_gain_percent_plus_5_end_wave"):
		failures.append("Celery Tea should preserve end-wave XP Gain special rule")
	if not _has_weapon_special_rule(celery_tea.get("effects", []), "next_wave_xp_gain_percent_plus_50"):
		failures.append("Celery Tea should preserve next-wave XP Gain special rule")
	if not _has_weapon_special_rule(celery_tea.get("effects", []), "next_wave_enemy_health_percent_plus_100"):
		failures.append("Celery Tea should preserve next-wave enemy health special rule")
	if not _has_weapon_special_rule(scarf.get("effects", []), "next_wave_enemy_speed_percent_plus_25"):
		failures.append("Scarf should preserve next-wave enemy speed special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for next-wave/growth item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for next-wave/growth item check")
		return
	for required_property in [
		"end_wave_harvesting_growth_percent",
		"end_wave_xp_gain_percent",
		"next_wave_xp_gain_percent_pending",
		"next_wave_xp_gain_percent_active",
		"next_wave_enemy_health_percent_pending",
		"next_wave_enemy_health_percent_active",
		"next_wave_enemy_damage_percent_pending",
		"next_wave_enemy_damage_percent_active",
		"next_wave_enemy_speed_percent_pending",
		"next_wave_enemy_speed_percent_active",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for next-wave/growth items" % required_property)
			return

	runtime_player.gold_per_wave = 50
	runtime_player.apply_upgrade(crown)
	if not is_equal_approx(float(runtime_player.get("end_wave_harvesting_growth_percent")), 0.08):
		failures.append("Applying Crown should enable +8% end-wave Harvesting growth")
	runtime_player.on_wave_end()
	if int(runtime_player.gold_per_wave) != 54:
		failures.append("Crown should grow Harvesting by 8% at wave end")
	runtime_player.remove_upgrade(crown)
	var after_crown_remove_harvesting = int(runtime_player.gold_per_wave)
	runtime_player.on_wave_end()
	if int(runtime_player.gold_per_wave) != after_crown_remove_harvesting:
		failures.append("Removed Crown should not grow Harvesting on later wave ends")
	runtime_player.gold_per_wave = 0

	runtime_player.xp_boost = 1.0
	runtime_player.enemy_health_percent = 0.0
	runtime_player.apply_upgrade(celery_tea)
	if not is_equal_approx(float(runtime_player.get("end_wave_xp_gain_percent")), 0.05):
		failures.append("Applying Celery Tea should enable +5% end-wave XP Gain growth")
	if not is_equal_approx(float(runtime_player.get("next_wave_xp_gain_percent_pending")), 0.50):
		failures.append("Applying Celery Tea should queue +50% XP Gain for next wave")
	if not is_equal_approx(float(runtime_player.get("next_wave_enemy_health_percent_pending")), 1.0):
		failures.append("Applying Celery Tea should queue +100% enemy health for next wave")
	runtime_player.on_wave_start(6)
	if not is_equal_approx(float(runtime_player.xp_boost), 1.50):
		failures.append("Celery Tea should apply next-wave XP Gain at wave start")
	if not is_equal_approx(float(runtime_player.enemy_health_percent), 1.0):
		failures.append("Celery Tea should apply next-wave enemy health at wave start")
	if not is_equal_approx(float(runtime_player.get("next_wave_xp_gain_percent_pending")), 0.0):
		failures.append("Celery Tea should consume pending next-wave XP Gain on wave start")
	runtime_player.on_wave_end()
	if not is_equal_approx(float(runtime_player.xp_boost), 1.05):
		failures.append("Celery Tea should clear next-wave XP Gain and then add end-wave XP Gain")
	if not is_equal_approx(float(runtime_player.enemy_health_percent), 0.0):
		failures.append("Celery Tea should clear next-wave enemy health at wave end")
	runtime_player.remove_upgrade(celery_tea)
	var after_celery_xp = float(runtime_player.xp_boost)
	runtime_player.on_wave_end()
	if not is_equal_approx(float(runtime_player.xp_boost), after_celery_xp):
		failures.append("Removed Celery Tea should not add end-wave XP Gain on later wave ends")

	runtime_player.xp_boost = 1.0
	runtime_player.enemy_damage_percent = 0.0
	runtime_player.apply_upgrade(peacock)
	if not is_equal_approx(float(runtime_player.xp_boost), 1.25):
		failures.append("Applying Peacock should add its base 25% XP Gain")
	if not is_equal_approx(float(runtime_player.get("next_wave_xp_gain_percent_pending")), 1.0):
		failures.append("Applying Peacock should queue +100% XP Gain for next wave")
	if not is_equal_approx(float(runtime_player.get("next_wave_enemy_damage_percent_pending")), 0.50):
		failures.append("Applying Peacock should queue +50% enemy damage for next wave")
	runtime_player.on_wave_start(7)
	if not is_equal_approx(float(runtime_player.xp_boost), 2.25):
		failures.append("Peacock should apply next-wave XP Gain on top of its base XP Gain")
	if not is_equal_approx(float(runtime_player.enemy_damage_percent), 0.50):
		failures.append("Peacock should apply next-wave enemy damage at wave start")
	runtime_player.on_wave_end()
	if not is_equal_approx(float(runtime_player.xp_boost), 1.25):
		failures.append("Peacock should clear next-wave XP Gain at wave end while keeping base XP Gain")
	if not is_equal_approx(float(runtime_player.enemy_damage_percent), 0.0):
		failures.append("Peacock should clear next-wave enemy damage at wave end")
	runtime_player.remove_upgrade(peacock)
	if not is_equal_approx(float(runtime_player.xp_boost), 1.0):
		failures.append("Removing Peacock should restore its base XP Gain")

	runtime_player.hp_regen = 0
	runtime_player.melee_damage_bonus = 0
	runtime_player.speed = 300.0
	runtime_player.base_speed = 300.0
	runtime_player.enemy_speed_percent = 0.0
	runtime_player.apply_upgrade(scarf)
	if int(runtime_player.hp_regen) != 4:
		failures.append("Applying Scarf should add 4 HP Regeneration")
	if int(runtime_player.melee_damage_bonus) != 4:
		failures.append("Applying Scarf should add 4 Melee Damage")
	if not is_equal_approx(float(runtime_player.base_speed), 312.0):
		failures.append("Applying Scarf should add 4% Speed")
	if not is_equal_approx(float(runtime_player.get("next_wave_enemy_speed_percent_pending")), 0.25):
		failures.append("Applying Scarf should queue +25% enemy speed for next wave")
	runtime_player.on_wave_start(8)
	if not is_equal_approx(float(runtime_player.enemy_speed_percent), 0.25):
		failures.append("Scarf should apply next-wave enemy speed at wave start")
	runtime_player.on_wave_end()
	if not is_equal_approx(float(runtime_player.enemy_speed_percent), 0.0):
		failures.append("Scarf should clear next-wave enemy speed at wave end")
	runtime_player.remove_upgrade(scarf)
	if int(runtime_player.hp_regen) != 0:
		failures.append("Removing Scarf should restore HP Regeneration")
	if int(runtime_player.melee_damage_bonus) != 0:
		failures.append("Removing Scarf should restore Melee Damage")
	if not is_equal_approx(float(runtime_player.base_speed), 300.0):
		failures.append("Removing Scarf should restore Speed")

func _check_catalog_bait_and_hourglass_wave_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Bait/Hourglass check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var bait = _find_by_source_id(pool, "bait")
	var hourglass = _find_by_source_id(pool, "hourglass")
	if bait.is_empty():
		failures.append("Runtime shop pool should include Bait special-enemy item")
	if hourglass.is_empty():
		failures.append("Runtime shop pool should include Hourglass wave-count item")
	if bait.is_empty() or hourglass.is_empty():
		return
	if not _has_stat_delta(bait.get("effects", []), "damage_percent", 0.08):
		failures.append("Bait should preserve +8% Damage stat delta")
	if not _has_weapon_special_rule(bait.get("effects", []), "spawn_special_enemies_next_wave"):
		failures.append("Bait should preserve next-wave special enemy special rule")
	if not _has_weapon_special_rule(hourglass.get("effects", []), "decrease_current_wave_count_by_1"):
		failures.append("Hourglass should preserve wave-count decrease special rule")
	if not _has_weapon_special_rule(hourglass.get("effects", []), "start_next_wave_with_1_hp"):
		failures.append("Hourglass should preserve next-wave 1 HP special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Bait/Hourglass check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Bait/Hourglass check")
		return
	if runtime_player.get("next_wave_special_enemy_count_pending") == null:
		failures.append("Player should expose next_wave_special_enemy_count_pending for Bait")
		return
	if not runtime_player.has_method("decrease_current_wave_count"):
		failures.append("Player should expose decrease_current_wave_count for Hourglass")
		return
	if main.wave_manager == null or not main.wave_manager.has_method("_spawn_pending_special_enemies_for_wave_start"):
		failures.append("WaveManager should expose pending special enemy spawning for Bait")
		return

	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_pending_special = int(runtime_player.get("next_wave_special_enemy_count_pending"))
	runtime_player.apply_upgrade(bait)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage + 0.08):
		failures.append("Applying Bait should add 8% Damage")
	if int(runtime_player.get("next_wave_special_enemy_count_pending")) != before_pending_special + 1:
		failures.append("Applying Bait should queue one special enemy for next wave")
	_reset_enemy_pool(main)
	main.wave_manager._spawn_pending_special_enemies_for_wave_start()
	if int(runtime_player.get("next_wave_special_enemy_count_pending")) != 0:
		failures.append("Bait special enemy spawn should consume pending count")
	if _count_visible_enemies_of_type(main, "elite") != 1:
		failures.append("Bait should spawn one elite special enemy at next wave start")
	_reset_enemy_pool(main)
	runtime_player.remove_upgrade(bait)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Bait should restore Damage")

	var before_wave = int(main.wave)
	var before_one_hp_sources = int(runtime_player.get("start_next_wave_with_one_hp_sources"))
	main.wave = 5
	runtime_player.apply_upgrade(hourglass)
	if int(main.wave) != 4:
		failures.append("Hourglass should decrease current wave count by 1")
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_one_hp_sources + 1:
		failures.append("Hourglass should also queue next-wave 1 HP start")
	runtime_player.remove_upgrade(hourglass)
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_one_hp_sources:
		failures.append("Removing Hourglass should restore next-wave 1 HP source count in tests")
	main.wave = before_wave

func _check_catalog_candy_bag_wave_stat_and_elite_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Candy Bag check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var candy_bag = _find_by_source_id(pool, "candy_bag")
	if candy_bag.is_empty():
		failures.append("Runtime shop pool should include Candy Bag wave stat and elite item")
		return
	if not _has_weapon_special_rule_number(candy_bag.get("effects", []), "each_wave_random_primary_stats_plus_8", "value", 8.0):
		failures.append("Candy Bag should preserve +8 random primary stat wave rule")
	if not _has_weapon_special_rule_chance(candy_bag.get("effects", []), "each_wave_additional_elite_chance_10_percent", 0.10):
		failures.append("Candy Bag should preserve +10 percent additional elite chance rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Candy Bag check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Candy Bag check")
		return
	for required_property in [
		"candy_bag_random_stat_sources",
		"candy_bag_random_stat_value",
		"candy_bag_random_stat_bonus",
		"additional_elite_chance",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Candy Bag" % required_property)
			return
	for required_method in [
		"apply_candy_bag_wave_random_stat",
		"clear_candy_bag_wave_random_stat",
	]:
		if not runtime_player.has_method(required_method):
			failures.append("Player should expose %s for Candy Bag" % required_method)
			return
	if main.wave_manager == null or not main.wave_manager.has_method("roll_additional_elite_spawn_count"):
		failures.append("WaveManager should expose additional elite roll support for Candy Bag")
		return
	if not main.wave_manager.has_method("_spawn_additional_elites_from_chance"):
		failures.append("WaveManager should expose additional elite spawn support for Candy Bag")
		return

	var before_sources = int(runtime_player.get("candy_bag_random_stat_sources"))
	var before_elite_chance = float(runtime_player.get("additional_elite_chance"))
	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.damage_percent_bonus = 0.0
	runtime_player.clear_candy_bag_wave_random_stat()
	runtime_player.apply_upgrade(candy_bag)
	if int(runtime_player.get("candy_bag_random_stat_sources")) != before_sources + 1:
		failures.append("Applying Candy Bag should enable one random primary stat source")
	if not is_equal_approx(float(runtime_player.get("candy_bag_random_stat_value")), 8.0):
		failures.append("Applying Candy Bag should configure +8 random primary stat value")
	if not is_equal_approx(float(runtime_player.get("additional_elite_chance")), before_elite_chance + 0.10):
		failures.append("Applying Candy Bag should add 10 percent additional elite chance")

	runtime_player.apply_candy_bag_wave_random_stat("damage_percent")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.08):
		failures.append("Candy Bag should add +8 display points to percent primary stats")
	var damage_bonus = runtime_player.get("candy_bag_random_stat_bonus")
	if not (damage_bonus is Dictionary) or str(damage_bonus.get("stat_id", "")) != "damage_percent" or not is_equal_approx(float(damage_bonus.get("value", 0.0)), 8.0):
		failures.append("Candy Bag should track the active random stat bonus")
	runtime_player.apply_candy_bag_wave_random_stat("max_hp")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.0):
		failures.append("Candy Bag should clear the previous wave stat before applying a new one")
	if int(runtime_player.max_hp) != 28:
		failures.append("Candy Bag should add +8 display points to integer primary stats")
	runtime_player.clear_candy_bag_wave_random_stat()
	if int(runtime_player.max_hp) != 20:
		failures.append("Candy Bag should remove the current wave random primary stat bonus")
	if not runtime_player.get("candy_bag_random_stat_bonus").is_empty():
		failures.append("Candy Bag should clear tracked random stat state")

	runtime_player.apply_candy_bag_wave_random_stat("damage_percent")
	runtime_player.on_wave_start(11)
	var wave_start_bonus = runtime_player.get("candy_bag_random_stat_bonus")
	if not (wave_start_bonus is Dictionary) or wave_start_bonus.is_empty():
		failures.append("Candy Bag should roll a random primary stat at wave start")
	elif not is_equal_approx(float(wave_start_bonus.get("value", 0.0)), 8.0):
		failures.append("Candy Bag wave-start random stat should use +8 display points")
	runtime_player.clear_candy_bag_wave_random_stat()

	if int(main.wave_manager.roll_additional_elite_spawn_count(0.09)) != 1:
		failures.append("Candy Bag should spawn an additional elite when roll is below 10 percent")
	if int(main.wave_manager.roll_additional_elite_spawn_count(0.11)) != 0:
		failures.append("Candy Bag should not spawn an additional elite when roll misses 10 percent chance")
	_reset_enemy_pool(main)
	if int(main.wave_manager._spawn_additional_elites_from_chance(0.09)) != 1:
		failures.append("Candy Bag should expose deterministic additional elite spawning")
	if _count_visible_enemies_of_type(main, "elite") != 1:
		failures.append("Candy Bag should spawn one elite from its additional elite chance")
	_reset_enemy_pool(main)

	runtime_player.remove_upgrade(candy_bag)
	if int(runtime_player.get("candy_bag_random_stat_sources")) != before_sources:
		failures.append("Removing Candy Bag should restore random stat source count")
	if not is_equal_approx(float(runtime_player.get("additional_elite_chance")), before_elite_chance):
		failures.append("Removing Candy Bag should restore additional elite chance")

func _check_catalog_triggered_bonus_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for triggered bonus item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var snowball = _find_by_source_id(pool, "snowball")
	var charcoal = _find_by_source_id(pool, "charcoal")
	var cauldron = _find_by_source_id(pool, "cauldron")
	var saltwater = _find_by_source_id(pool, "saltwater")
	if snowball.is_empty():
		failures.append("Runtime shop pool should include Snowball elemental item trigger")
	if charcoal.is_empty():
		failures.append("Runtime shop pool should include Charcoal for Snowball trigger check")
	if cauldron.is_empty():
		failures.append("Runtime shop pool should include Cauldron consumable damage trigger")
	if saltwater.is_empty():
		failures.append("Runtime shop pool should include Saltwater damage-taken speed trigger")
	if snowball.is_empty() or charcoal.is_empty() or cauldron.is_empty() or saltwater.is_empty():
		return
	if not _has_weapon_special_rule(snowball.get("effects", []), "elemental_damage_plus_1_when_getting_elemental_damage_item"):
		failures.append("Snowball should preserve elemental item trigger special rule")
	if not _has_weapon_special_rule(cauldron.get("effects", []), "damage_percent_plus_20_for_2_seconds_after_consumable_pickup"):
		failures.append("Cauldron should preserve consumable damage trigger special rule")
	if not _has_weapon_special_rule(saltwater.get("effects", []), "speed_percent_plus_10_for_3_seconds_when_taking_damage"):
		failures.append("Saltwater should preserve damage-taken speed trigger special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for triggered bonus item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for triggered bonus item check")
		return
	for required_property in [
		"elemental_item_pickup_bonus_sources",
		"elemental_item_pickup_bonus_granted",
		"consumable_damage_boost_sources",
		"consumable_damage_boost_bonus",
		"consumable_damage_boost_timer",
		"damage_taken_speed_boost_sources",
		"damage_taken_speed_boost_bonus",
		"damage_taken_speed_boost_timer",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for triggered bonus items" % required_property)
			return
	if not runtime_player.has_method("process_consumable_damage_boost"):
		failures.append("Player should expose process_consumable_damage_boost for Cauldron")
		return
	if not runtime_player.has_method("process_damage_taken_speed_boost"):
		failures.append("Player should expose process_damage_taken_speed_boost for Saltwater")
		return

	runtime_player.elemental_damage_bonus = 0
	runtime_player.apply_upgrade(snowball)
	if int(runtime_player.get("elemental_item_pickup_bonus_sources")) != 1:
		failures.append("Applying Snowball should enable one elemental item pickup bonus source")
	runtime_player.apply_upgrade(charcoal)
	if int(runtime_player.elemental_damage_bonus) != 2:
		failures.append("Snowball should add +1 Elemental Damage when an Elemental Damage item is picked")
	if int(runtime_player.get("elemental_item_pickup_bonus_granted")) != 1:
		failures.append("Snowball should track granted elemental pickup bonuses")
	runtime_player.remove_upgrade(charcoal)
	if int(runtime_player.elemental_damage_bonus) != 1:
		failures.append("Snowball's granted Elemental Damage should persist when the triggering item is removed")
	runtime_player.remove_upgrade(snowball)
	if int(runtime_player.get("elemental_item_pickup_bonus_sources")) != 0:
		failures.append("Removing Snowball should disable future elemental pickup bonuses")
	runtime_player.apply_upgrade(charcoal)
	if int(runtime_player.elemental_damage_bonus) != 2:
		failures.append("After Snowball is removed, later Elemental Damage items should not grant extra bonus")
	runtime_player.remove_upgrade(charcoal)
	runtime_player.elemental_damage_bonus = 0

	runtime_player.damage_percent_bonus = 0.0
	runtime_player.hp_regen = 0
	runtime_player.magnet_range = 160.0
	runtime_player.apply_upgrade(cauldron)
	if not is_equal_approx(float(runtime_player.magnet_range), 240.0):
		failures.append("Applying Cauldron should add 50% pickup range")
	if int(runtime_player.hp_regen) != -2:
		failures.append("Applying Cauldron should subtract 2 HP Regeneration")
	if int(runtime_player.get("consumable_damage_boost_sources")) != 1:
		failures.append("Applying Cauldron should enable one consumable damage boost source")
	runtime_player.on_consumable_pickup("fruit", false)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.20):
		failures.append("Cauldron should add 20% Damage after a consumable pickup even below full health")
	if not is_equal_approx(float(runtime_player.get("consumable_damage_boost_timer")), 2.0):
		failures.append("Cauldron should start a 2 second damage boost timer")
	runtime_player.process_consumable_damage_boost(1.0)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.20):
		failures.append("Cauldron damage boost should remain active before its timer expires")
	runtime_player.process_consumable_damage_boost(1.1)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.0):
		failures.append("Cauldron damage boost should clear when its timer expires")
	runtime_player.remove_upgrade(cauldron)
	if not is_equal_approx(float(runtime_player.magnet_range), 160.0):
		failures.append("Removing Cauldron should restore pickup range")
	if int(runtime_player.hp_regen) != 0:
		failures.append("Removing Cauldron should restore HP Regeneration")

	runtime_player.speed = 300.0
	runtime_player.base_speed = 300.0
	runtime_player.fire_rate_multiplier = 1.0
	runtime_player.melee_damage_bonus = 0
	runtime_player.elemental_damage_bonus = 0
	runtime_player.apply_upgrade(saltwater)
	if int(runtime_player.melee_damage_bonus) != 2:
		failures.append("Applying Saltwater should add 2 Melee Damage")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.03):
		failures.append("Applying Saltwater should add 3% Attack Speed")
	if int(runtime_player.elemental_damage_bonus) != -1:
		failures.append("Applying Saltwater should subtract 1 Elemental Damage")
	if int(runtime_player.get("damage_taken_speed_boost_sources")) != 1:
		failures.append("Applying Saltwater should enable one damage-taken Speed boost source")
	runtime_player.on_damage_taken(1)
	if not is_equal_approx(float(runtime_player.speed), 330.0):
		failures.append("Saltwater should add 10% temporary Speed when damage is taken")
	if not is_equal_approx(float(runtime_player.base_speed), 300.0):
		failures.append("Saltwater temporary Speed should not change permanent base Speed")
	runtime_player.process_damage_taken_speed_boost(2.0)
	if not is_equal_approx(float(runtime_player.speed), 330.0):
		failures.append("Saltwater Speed boost should remain active before 3 seconds")
	runtime_player.process_damage_taken_speed_boost(1.1)
	if not is_equal_approx(float(runtime_player.speed), 300.0):
		failures.append("Saltwater Speed boost should clear after 3 seconds")
	runtime_player.remove_upgrade(saltwater)
	if int(runtime_player.melee_damage_bonus) != 0:
		failures.append("Removing Saltwater should restore Melee Damage")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.0):
		failures.append("Removing Saltwater should restore Attack Speed")
	if int(runtime_player.elemental_damage_bonus) != 0:
		failures.append("Removing Saltwater should restore Elemental Damage")

func _check_catalog_self_damage_and_lifesteal_scaling_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for self-damage/lifesteal scaling item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var blood_donation = _find_by_source_id(pool, "blood_donation")
	var bloody_hand = _find_by_source_id(pool, "bloody_hand")
	var whetstone = _find_by_source_id(pool, "whetstone")
	if blood_donation.is_empty():
		failures.append("Runtime shop pool should include Blood Donation self-damage modifier")
	if bloody_hand.is_empty():
		failures.append("Runtime shop pool should include Bloody Hand lifesteal-scaling modifier")
	if whetstone.is_empty():
		failures.append("Runtime shop pool should include Whetstone for Bloody Hand recalculation")
	if blood_donation.is_empty() or bloody_hand.is_empty() or whetstone.is_empty():
		return
	if not _has_weapon_special_rule(blood_donation.get("effects", []), "take_1_damage_per_second_without_invulnerability"):
		failures.append("Blood Donation should preserve self-damage special rule")
	if not _has_weapon_special_rule(bloody_hand.get("effects", []), "damage_percent_plus_2_per_1_lifesteal_percent"):
		failures.append("Bloody Hand should preserve lifesteal-scaling Damage special rule")
	if not _has_weapon_special_rule(bloody_hand.get("effects", []), "take_1_damage_per_second_without_invulnerability"):
		failures.append("Bloody Hand should preserve self-damage special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for self-damage/lifesteal scaling item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for self-damage/lifesteal scaling item check")
		return
	for required_property in [
		"self_damage_per_second_sources",
		"self_damage_timer",
		"lifesteal_scaling_damage_sources",
		"lifesteal_scaling_damage_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for self-damage/lifesteal scaling items" % required_property)
			return
	if not runtime_player.has_method("process_self_damage_over_time"):
		failures.append("Player should expose process_self_damage_over_time for Blood Donation/Bloody Hand")
		return
	if not runtime_player.has_method("recalculate_lifesteal_scaling_damage"):
		failures.append("Player should expose recalculate_lifesteal_scaling_damage for Bloody Hand")
		return

	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.armor = 999
	runtime_player.invincible_timer = 10.0
	runtime_player.gold_per_wave = 0
	runtime_player.apply_upgrade(blood_donation)
	if int(runtime_player.gold_per_wave) != 40:
		failures.append("Applying Blood Donation should add 40 Harvesting")
	if int(runtime_player.get("self_damage_per_second_sources")) != 1:
		failures.append("Applying Blood Donation should enable one self-damage source")
	runtime_player.process_self_damage_over_time(1.0)
	if int(runtime_player.hp) != 19:
		failures.append("Blood Donation self-damage should deal 1 damage per second")
	if not is_equal_approx(float(runtime_player.invincible_timer), 10.0):
		failures.append("Blood Donation self-damage should not consume or refresh invulnerability")
	runtime_player.process_self_damage_over_time(1.0)
	if int(runtime_player.hp) != 18:
		failures.append("Blood Donation self-damage should keep ticking through invulnerability")
	runtime_player.remove_upgrade(blood_donation)
	if int(runtime_player.gold_per_wave) != 0:
		failures.append("Removing Blood Donation should restore Harvesting")
	if int(runtime_player.get("self_damage_per_second_sources")) != 0:
		failures.append("Removing Blood Donation should disable self-damage")

	runtime_player.hp = 20
	runtime_player.invincible_timer = 0.0
	runtime_player.armor = 0
	runtime_player.lifesteal = 0.0
	runtime_player.damage_percent_bonus = 0.0
	runtime_player.apply_upgrade(bloody_hand)
	if not is_equal_approx(float(runtime_player.lifesteal), 0.10):
		failures.append("Applying Bloody Hand should add 10% Lifesteal")
	if int(runtime_player.get("lifesteal_scaling_damage_sources")) != 1:
		failures.append("Applying Bloody Hand should enable one lifesteal-scaling Damage source")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.20):
		failures.append("Bloody Hand should add 2% Damage per 1% current Lifesteal")
	if int(runtime_player.get("self_damage_per_second_sources")) != 1:
		failures.append("Applying Bloody Hand should enable self-damage")
	runtime_player.apply_upgrade(whetstone)
	if not is_equal_approx(float(runtime_player.lifesteal), 0.14):
		failures.append("Applying Whetstone should add 4% Lifesteal for Bloody Hand check")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.28):
		failures.append("Bloody Hand should recalculate Damage when Lifesteal increases")
	runtime_player.remove_upgrade(whetstone)
	if not is_equal_approx(float(runtime_player.lifesteal), 0.10):
		failures.append("Removing Whetstone should restore Lifesteal for Bloody Hand check")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.20):
		failures.append("Bloody Hand should recalculate Damage when Lifesteal decreases")
	runtime_player.process_self_damage_over_time(1.0)
	if int(runtime_player.hp) != 19:
		failures.append("Bloody Hand self-damage should tick once per second")
	runtime_player.remove_upgrade(bloody_hand)
	if not is_equal_approx(float(runtime_player.lifesteal), 0.0):
		failures.append("Removing Bloody Hand should restore Lifesteal")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.0):
		failures.append("Removing Bloody Hand should clear lifesteal-scaling Damage")
	if int(runtime_player.get("self_damage_per_second_sources")) != 0:
		failures.append("Removing Bloody Hand should disable self-damage")

func _check_catalog_structure_attack_speed_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for structure attack speed item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var clockwork_wasp = _find_by_source_id(pool, "clockwork_wasp")
	var improved_tools = _find_by_source_id(pool, "improved_tools")
	if clockwork_wasp.is_empty():
		failures.append("Runtime shop pool should include Clockwork Wasp structure attack speed modifier")
	if improved_tools.is_empty():
		failures.append("Runtime shop pool should include Improved Tools structure attack speed scaling modifier")
	if clockwork_wasp.is_empty() or improved_tools.is_empty():
		return
	if not _has_stat_delta(clockwork_wasp.get("effects", []), "structure_attack_speed_percent", 0.10):
		failures.append("Clockwork Wasp should preserve structure attack speed stat delta")
	if not _has_weapon_special_rule(improved_tools.get("effects", []), "structures_attack_speed_scales_with_player_attack_speed"):
		failures.append("Improved Tools should preserve structure attack speed scaling special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for structure attack speed item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for structure attack speed item check")
		return
	if runtime_player.get("structure_attack_speed_percent") == null:
		failures.append("Player should expose structure_attack_speed_percent")
		return
	if runtime_player.get("structures_scale_with_player_attack_speed_sources") == null:
		failures.append("Player should expose structures_scale_with_player_attack_speed_sources")
		return
	if not runtime_player.has_method("get_structure_attack_interval"):
		failures.append("Player should expose get_structure_attack_interval for TurretManager")
		return

	runtime_player.structure_attack_speed_percent = 0.0
	runtime_player.structures_scale_with_player_attack_speed_sources = 0
	runtime_player.fire_rate_multiplier = 1.0
	runtime_player.apply_upgrade(clockwork_wasp)
	if not is_equal_approx(float(runtime_player.get("structure_attack_speed_percent")), 0.10):
		failures.append("Applying Clockwork Wasp should add 10% structure attack speed")
	if not is_equal_approx(float(runtime_player.get_structure_attack_interval(2.0)), 2.0 / 1.10):
		failures.append("Clockwork Wasp should shorten structure attack interval")

	runtime_player.apply_upgrade(improved_tools)
	if int(runtime_player.get("structures_scale_with_player_attack_speed_sources")) != 1:
		failures.append("Applying Improved Tools should enable structure attack speed scaling")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.10):
		failures.append("Applying Improved Tools should add 10% Attack Speed")
	if not is_equal_approx(float(runtime_player.get_structure_attack_interval(2.0)), 2.0 / 1.20):
		failures.append("Improved Tools should let structures scale from player Attack Speed")

	main.turret_manager.cleanup()
	var turret = Node2D.new()
	turret.set_meta("lifetime", 20.0)
	turret.set_meta("shoot_timer", 0.0)
	turret.set_meta("damage", 1)
	var detect = Area2D.new()
	detect.name = "DetectArea"
	turret.add_child(detect)
	main.add_child(turret)
	main.turret_manager.active_turrets.append(turret)
	main.turret_manager.process_turrets(0.0)
	if not is_equal_approx(float(turret.get_meta("shoot_timer")), 2.0 / 1.20):
		failures.append("TurretManager should use player structure attack interval")
	main.turret_manager.cleanup()

	runtime_player.remove_upgrade(improved_tools)
	if int(runtime_player.get("structures_scale_with_player_attack_speed_sources")) != 0:
		failures.append("Removing Improved Tools should disable structure attack speed scaling")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.0):
		failures.append("Removing Improved Tools should restore Attack Speed")
	if not is_equal_approx(float(runtime_player.get_structure_attack_interval(2.0)), 2.0 / 1.10):
		failures.append("Clockwork Wasp structure attack speed should remain after removing Improved Tools")
	runtime_player.remove_upgrade(clockwork_wasp)
	if not is_equal_approx(float(runtime_player.get("structure_attack_speed_percent")), 0.0):
		failures.append("Removing Clockwork Wasp should restore structure attack speed")
	if not is_equal_approx(float(runtime_player.get_structure_attack_interval(2.0)), 2.0):
		failures.append("Removing structure attack speed items should restore base structure interval")

func _check_catalog_stand_still_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for stand-still item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var barricade = _find_by_source_id(pool, "barricade")
	var statue = _find_by_source_id(pool, "statue")
	var chameleon = _find_by_source_id(pool, "chameleon")
	var coral = _find_by_source_id(pool, "coral")
	if barricade.is_empty():
		failures.append("Runtime shop pool should include Barricade stand-still armor modifier")
	if statue.is_empty():
		failures.append("Runtime shop pool should include Statue stand-still attack speed modifier")
	if chameleon.is_empty():
		failures.append("Runtime shop pool should include Chameleon stand-still dodge modifier")
	if coral.is_empty():
		failures.append("Runtime shop pool should include Coral stand-still HP regeneration modifier")
	if barricade.is_empty() or statue.is_empty() or chameleon.is_empty() or coral.is_empty():
		return
	if not _has_weapon_special_rule(barricade.get("effects", []), "armor_plus_8_while_standing_still"):
		failures.append("Barricade should preserve stand-still armor special rule")
	if not _has_weapon_special_rule(statue.get("effects", []), "attack_speed_percent_plus_40_while_standing_still"):
		failures.append("Statue should preserve stand-still attack speed special rule")
	if not _has_weapon_special_rule(chameleon.get("effects", []), "dodge_percent_plus_20_while_standing_still"):
		failures.append("Chameleon should preserve stand-still dodge special rule")
	if not _has_weapon_special_rule(coral.get("effects", []), "hp_regeneration_plus_10_while_standing_still"):
		failures.append("Coral should preserve stand-still HP regeneration special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for stand-still item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for stand-still item check")
		return
	for required_property in [
		"stand_still_armor_sources",
		"stand_still_armor_bonus",
		"stand_still_attack_speed_sources",
		"stand_still_attack_speed_bonus",
		"stand_still_dodge_sources",
		"stand_still_dodge_bonus",
		"stand_still_hp_regen_sources",
		"stand_still_hp_regen_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for stand-still item bonuses" % required_property)
			return
	if not runtime_player.has_method("update_stand_still_item_bonuses"):
		failures.append("Player should expose update_stand_still_item_bonuses")
		return

	runtime_player.armor = 0
	runtime_player.dodge_cap = 0.9
	runtime_player.dodge_chance = 0.0
	runtime_player.fire_rate_multiplier = 1.0
	runtime_player.hp_regen = 0
	runtime_player.velocity = Vector2.ZERO
	runtime_player.apply_upgrade(barricade)
	runtime_player.apply_upgrade(statue)
	runtime_player.apply_upgrade(chameleon)
	runtime_player.apply_upgrade(coral)
	runtime_player.update_stand_still_item_bonuses()
	if int(runtime_player.armor) != 8:
		failures.append("Barricade should add 8 Armor while standing still")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.40):
		failures.append("Statue should add 40% Attack Speed while standing still")
	if not is_equal_approx(float(runtime_player.dodge_chance), 0.23):
		failures.append("Chameleon should keep 3% Dodge and add 20% while standing still")
	if int(runtime_player.hp_regen) != 10:
		failures.append("Coral should add 10 HP Regeneration while standing still")

	runtime_player.velocity = Vector2.RIGHT
	runtime_player.update_stand_still_item_bonuses()
	if int(runtime_player.armor) != 0:
		failures.append("Barricade stand-still Armor should clear while moving")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.0):
		failures.append("Statue stand-still Attack Speed should clear while moving")
	if not is_equal_approx(float(runtime_player.dodge_chance), 0.03):
		failures.append("Chameleon should keep only its base Dodge while moving")
	if int(runtime_player.hp_regen) != 0:
		failures.append("Coral stand-still HP Regeneration should clear while moving")

	runtime_player.velocity = Vector2.ZERO
	runtime_player.update_stand_still_item_bonuses()
	runtime_player.remove_upgrade(coral)
	runtime_player.remove_upgrade(chameleon)
	runtime_player.remove_upgrade(statue)
	runtime_player.remove_upgrade(barricade)
	if int(runtime_player.armor) != 0:
		failures.append("Removing Barricade should restore Armor")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.0):
		failures.append("Removing Statue should restore Attack Speed")
	if not is_equal_approx(float(runtime_player.dodge_chance), 0.0):
		failures.append("Removing Chameleon should restore Dodge")
	if int(runtime_player.hp_regen) != 0:
		failures.append("Removing Coral should restore HP Regeneration")

func _check_catalog_end_wave_stat_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for end-wave stat item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var vigilante_ring = _find_by_source_id(pool, "vigilante_ring")
	var magical_leaf = _find_by_source_id(pool, "grind_s_magical_leaf")
	var robot_arm = _find_by_source_id(pool, "robot_arm")
	var ashes = _find_by_source_id(pool, "ashes")
	if vigilante_ring.is_empty():
		failures.append("Runtime shop pool should include Vigilante Ring end-wave damage modifier")
	if magical_leaf.is_empty():
		failures.append("Runtime shop pool should include Grind's Magical Leaf end-wave stat modifier")
	if robot_arm.is_empty():
		failures.append("Runtime shop pool should include Robot Arm end-wave stat modifier")
	if ashes.is_empty():
		failures.append("Runtime shop pool should include Ashes end-wave armor loss modifier")
	if vigilante_ring.is_empty() or magical_leaf.is_empty() or robot_arm.is_empty() or ashes.is_empty():
		return
	if not _has_weapon_special_rule(vigilante_ring.get("effects", []), "damage_percent_plus_3_end_wave"):
		failures.append("Vigilante Ring should preserve end-wave Damage special rule")
	if not _has_weapon_special_rule(magical_leaf.get("effects", []), "max_hp_plus_3_end_wave"):
		failures.append("Grind's Magical Leaf should preserve end-wave Max HP special rule")
	if not _has_weapon_special_rule(magical_leaf.get("effects", []), "hp_regeneration_plus_1_end_wave"):
		failures.append("Grind's Magical Leaf should preserve end-wave HP Regeneration special rule")
	if not _has_weapon_special_rule(magical_leaf.get("effects", []), "lifesteal_plus_1_percent_end_wave"):
		failures.append("Grind's Magical Leaf should preserve end-wave Lifesteal special rule")
	if not _has_weapon_special_rule(robot_arm.get("effects", []), "melee_damage_plus_3_end_wave"):
		failures.append("Robot Arm should preserve end-wave Melee Damage special rule")
	if not _has_weapon_special_rule(robot_arm.get("effects", []), "engineering_plus_3_end_wave"):
		failures.append("Robot Arm should preserve end-wave Engineering special rule")
	if not _has_weapon_special_rule(robot_arm.get("effects", []), "max_hp_minus_1_end_wave"):
		failures.append("Robot Arm should preserve end-wave Max HP loss special rule")
	if not _has_weapon_special_rule(ashes.get("effects", []), "armor_minus_1_end_wave"):
		failures.append("Ashes should preserve end-wave Armor loss special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for end-wave stat item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for end-wave stat item check")
		return
	if not runtime_player.has_method("on_wave_end"):
		failures.append("Player should expose on_wave_end for end-wave stat items")
		return
	for required_property in [
		"end_wave_damage_percent_sources",
		"end_wave_max_hp_gain_sources",
		"end_wave_hp_regen_gain_sources",
		"end_wave_lifesteal_gain_sources",
		"end_wave_melee_damage_gain_sources",
		"end_wave_engineering_gain_sources",
		"end_wave_max_hp_loss_sources",
		"end_wave_armor_loss_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for end-wave stat items" % required_property)
			return

	runtime_player.armor = 3
	runtime_player.hp = runtime_player.max_hp
	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_max_hp = int(runtime_player.max_hp)
	var before_hp = int(runtime_player.hp)
	var before_hp_regen = int(runtime_player.hp_regen)
	var before_lifesteal = float(runtime_player.lifesteal)
	var before_melee = int(runtime_player.melee_damage_bonus)
	var before_engineering = int(runtime_player.engineering_bonus)
	var before_armor = int(runtime_player.armor)
	runtime_player.apply_upgrade(vigilante_ring)
	runtime_player.apply_upgrade(magical_leaf)
	runtime_player.apply_upgrade(robot_arm)
	runtime_player.apply_upgrade(ashes)
	if int(runtime_player.get("end_wave_damage_percent_sources")) != 1:
		failures.append("Applying Vigilante Ring should enable one end-wave Damage source")
	if int(runtime_player.get("end_wave_max_hp_gain_sources")) != 1:
		failures.append("Applying Grind's Magical Leaf should enable one end-wave Max HP source")
	if int(runtime_player.get("end_wave_melee_damage_gain_sources")) != 1:
		failures.append("Applying Robot Arm should enable one end-wave Melee Damage source")
	if int(runtime_player.get("end_wave_armor_loss_sources")) != 1:
		failures.append("Applying Ashes should enable one end-wave Armor loss source")

	var post_apply_damage = float(runtime_player.damage_percent_bonus)
	runtime_player.on_wave_end()
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), post_apply_damage + 0.03):
		failures.append("Vigilante Ring should add 3% Damage at wave end")
	if int(runtime_player.max_hp) != before_max_hp + 2:
		failures.append("Grind's Magical Leaf and Robot Arm should net +2 Max HP at wave end")
	if int(runtime_player.hp) != min(before_hp + 2, before_max_hp + 2):
		failures.append("End-wave Max HP delta should adjust current HP by the net Max HP change")
	if int(runtime_player.hp_regen) != before_hp_regen + 1:
		failures.append("Grind's Magical Leaf should add 1 HP Regeneration at wave end")
	if not is_equal_approx(float(runtime_player.lifesteal), before_lifesteal + 0.01):
		failures.append("Grind's Magical Leaf should add 1% Lifesteal at wave end")
	if int(runtime_player.melee_damage_bonus) != before_melee + 3:
		failures.append("Robot Arm should add 3 Melee Damage at wave end")
	if int(runtime_player.engineering_bonus) != before_engineering + 3:
		failures.append("Robot Arm should add 3 Engineering at wave end")
	if int(runtime_player.armor) != before_armor - 1:
		failures.append("Ashes should subtract 1 Armor at wave end")

	runtime_player.remove_upgrade(ashes)
	runtime_player.remove_upgrade(robot_arm)
	runtime_player.remove_upgrade(magical_leaf)
	runtime_player.remove_upgrade(vigilante_ring)
	if int(runtime_player.get("end_wave_damage_percent_sources")) != 0:
		failures.append("Removing Vigilante Ring should disable future end-wave Damage gains")
	if int(runtime_player.get("end_wave_armor_loss_sources")) != 0:
		failures.append("Removing Ashes should disable future end-wave Armor losses")
	var after_remove_damage = float(runtime_player.damage_percent_bonus)
	var after_remove_armor = int(runtime_player.armor)
	runtime_player.on_wave_end()
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), after_remove_damage):
		failures.append("Removed end-wave items should not grant additional Damage on later wave ends")
	if int(runtime_player.armor) != after_remove_armor:
		failures.append("Removed Ashes should not subtract Armor on later wave ends")
	runtime_player.damage_percent_bonus = before_damage
	runtime_player.max_hp = before_max_hp
	runtime_player.hp = before_hp
	runtime_player.hp_regen = before_hp_regen
	runtime_player.lifesteal = before_lifesteal
	runtime_player.melee_damage_bonus = before_melee
	runtime_player.engineering_bonus = before_engineering
	runtime_player.armor = before_armor

func _check_catalog_level_up_stat_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for level-up stat item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var baby_squid = _find_by_source_id(pool, "baby_squid")
	var decomposing_flesh = _find_by_source_id(pool, "decomposing_flesh")
	if baby_squid.is_empty():
		failures.append("Runtime shop pool should include Baby Squid level-up HP Regeneration modifier")
	if decomposing_flesh.is_empty():
		failures.append("Runtime shop pool should include Decomposing Flesh level-up Lifesteal/Max HP modifier")
	if baby_squid.is_empty() or decomposing_flesh.is_empty():
		return
	if not _has_weapon_special_rule(baby_squid.get("effects", []), "hp_regeneration_plus_1_on_level_up"):
		failures.append("Baby Squid should preserve level-up HP Regeneration special rule")
	if not _has_stat_delta(baby_squid.get("effects", []), "attack_speed_percent", -0.03):
		failures.append("Baby Squid should preserve attack speed penalty")
	if not _has_weapon_special_rule(decomposing_flesh.get("effects", []), "lifesteal_plus_1_percent_and_max_hp_minus_1_on_level_up"):
		failures.append("Decomposing Flesh should preserve level-up Lifesteal/Max HP special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for level-up stat item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for level-up stat item check")
		return
	if not runtime_player.has_method("on_level_up"):
		failures.append("Player should expose on_level_up for level-up stat items")
		return
	for required_property in [
		"level_up_hp_regen_gain_sources",
		"level_up_lifesteal_gain_sources",
		"level_up_max_hp_loss_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for level-up stat items" % required_property)
			return

	var before_level = int(runtime_player.level)
	var before_xp = int(runtime_player.xp)
	var before_xp_to_next = int(runtime_player.xp_to_next)
	var before_pending = int(runtime_player.pending_level_ups)
	var before_max_hp = int(runtime_player.max_hp)
	var before_hp = int(runtime_player.hp)
	var before_hp_regen = int(runtime_player.hp_regen)
	var before_lifesteal = float(runtime_player.lifesteal)
	var before_attack_speed = float(runtime_player.fire_rate_multiplier)
	runtime_player.max_hp = max(before_max_hp, 10)
	runtime_player.hp = runtime_player.max_hp
	runtime_player.xp = 0
	runtime_player.level = 1
	runtime_player.xp_to_next = 10
	runtime_player.pending_level_ups = 0

	runtime_player.apply_upgrade(baby_squid)
	runtime_player.apply_upgrade(decomposing_flesh)
	if int(runtime_player.get("level_up_hp_regen_gain_sources")) != 1:
		failures.append("Applying Baby Squid should enable one level-up HP Regeneration source")
	if int(runtime_player.get("level_up_lifesteal_gain_sources")) != 1:
		failures.append("Applying Decomposing Flesh should enable one level-up Lifesteal source")
	if int(runtime_player.get("level_up_max_hp_loss_sources")) != 1:
		failures.append("Applying Decomposing Flesh should enable one level-up Max HP loss source")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_attack_speed - 0.03):
		failures.append("Applying Baby Squid should subtract 3% attack speed")

	var applied_max_hp = int(runtime_player.max_hp)
	var applied_hp = int(runtime_player.hp)
	var level_up_callable = Callable(main, "_on_level_up")
	var was_level_up_connected = runtime_player.level_up.is_connected(level_up_callable)
	if was_level_up_connected:
		runtime_player.level_up.disconnect(level_up_callable)
	runtime_player.set_meta("suppress_level_up_effects", true)
	runtime_player.gain_xp(10)
	runtime_player.remove_meta("suppress_level_up_effects")
	if was_level_up_connected:
		runtime_player.level_up.connect(level_up_callable)
	if int(runtime_player.level) != 2:
		failures.append("Level-up stat item check should level the player through gain_xp")
	if int(runtime_player.hp_regen) != before_hp_regen + 1:
		failures.append("Baby Squid should add 1 HP Regeneration on level up")
	if not is_equal_approx(float(runtime_player.lifesteal), before_lifesteal + 0.01):
		failures.append("Decomposing Flesh should add 1% Lifesteal on level up")
	if int(runtime_player.max_hp) != applied_max_hp - 1:
		failures.append("Decomposing Flesh should subtract 1 Max HP on level up")
	if int(runtime_player.hp) != min(applied_hp, applied_max_hp - 1):
		failures.append("Level-up Max HP loss should clamp current HP")

	runtime_player.remove_upgrade(decomposing_flesh)
	runtime_player.remove_upgrade(baby_squid)
	if int(runtime_player.get("level_up_hp_regen_gain_sources")) != 0:
		failures.append("Removing Baby Squid should disable future level-up HP Regeneration")
	if int(runtime_player.get("level_up_lifesteal_gain_sources")) != 0:
		failures.append("Removing Decomposing Flesh should disable future level-up Lifesteal")
	var after_remove_hp_regen = int(runtime_player.hp_regen)
	var after_remove_lifesteal = float(runtime_player.lifesteal)
	var after_remove_max_hp = int(runtime_player.max_hp)
	runtime_player.on_level_up(runtime_player.level + 1)
	if int(runtime_player.hp_regen) != after_remove_hp_regen:
		failures.append("Removed Baby Squid should not add HP Regeneration on later level-ups")
	if not is_equal_approx(float(runtime_player.lifesteal), after_remove_lifesteal):
		failures.append("Removed Decomposing Flesh should not add Lifesteal on later level-ups")
	if int(runtime_player.max_hp) != after_remove_max_hp:
		failures.append("Removed Decomposing Flesh should not subtract Max HP on later level-ups")

	runtime_player.level = before_level
	runtime_player.xp = before_xp
	runtime_player.xp_to_next = before_xp_to_next
	runtime_player.pending_level_ups = before_pending
	runtime_player.max_hp = before_max_hp
	runtime_player.hp = before_hp
	runtime_player.hp_regen = before_hp_regen
	runtime_player.lifesteal = before_lifesteal
	runtime_player.fire_rate_multiplier = before_attack_speed

func _check_catalog_barnacle_and_lighthouse_level_structure_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Barnacle/Lighthouse check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var barnacle = _find_by_source_id(pool, "barnacle")
	var lighthouse = _find_by_source_id(pool, "lighthouse")
	if barnacle.is_empty():
		failures.append("Runtime shop pool should include Barnacle level-up scaling item")
	if lighthouse.is_empty():
		failures.append("Runtime shop pool should include Lighthouse structure Engineering item")
	if barnacle.is_empty() or lighthouse.is_empty():
		return
	if not _has_weapon_special_rule(barnacle.get("effects", []), "level_upgrade_stats_plus_35_percent"):
		failures.append("Barnacle should preserve level-up stat amplification special rule")
	if not _has_weapon_special_rule(barnacle.get("effects", []), "curse_plus_1_on_level_up"):
		failures.append("Barnacle should preserve Curse gain on level-up special rule")
	if not _has_stat_delta(lighthouse.get("effects", []), "engineering", 20.0):
		failures.append("Lighthouse should preserve +20 Engineering stat delta")
	if not _has_weapon_special_rule(lighthouse.get("effects", []), "engineering_minus_1_per_structure"):
		failures.append("Lighthouse should preserve Engineering penalty per structure special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Barnacle/Lighthouse check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Barnacle/Lighthouse check")
		return
	for required_property in [
		"level_upgrade_stat_percent_bonus",
		"level_up_curse_gain_sources",
		"structure_engineering_penalty_sources",
		"structure_engineering_penalty_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Barnacle/Lighthouse" % required_property)
			return
	if not runtime_player.has_method("recalculate_structure_engineering_penalty"):
		failures.append("Player should expose recalculate_structure_engineering_penalty for Lighthouse")
		return

	var before_level_bonus = float(runtime_player.get("level_upgrade_stat_percent_bonus"))
	var before_curse_sources = int(runtime_player.get("level_up_curse_gain_sources"))
	var before_curse = int(runtime_player.curse)
	var before_speed = float(runtime_player.speed)
	var before_base_speed = float(runtime_player.base_speed)
	runtime_player.apply_upgrade(barnacle)
	if not is_equal_approx(float(runtime_player.get("level_upgrade_stat_percent_bonus")), before_level_bonus + 0.35):
		failures.append("Applying Barnacle should add +35 percent level-up stat bonus")
	if int(runtime_player.get("level_up_curse_gain_sources")) != before_curse_sources + 1:
		failures.append("Applying Barnacle should enable Curse gain on level up")
	runtime_player.on_level_up(runtime_player.level + 1)
	if int(runtime_player.curse) != before_curse + 1:
		failures.append("Barnacle should add 1 Curse on level up")
	runtime_player.speed = before_speed
	runtime_player.base_speed = before_base_speed
	# 四选一自 2026-09-15 起走目录属性：speed_percent 是分数，×SPEED_PERCENT_BASE 得到平坦速度。
	# 断言的是「选项数值被 Barnacle 放大了 35%」这一意图，不再写死某个绝对速度值。
	var choice_speed_percent = 0.05
	var expected_speed_delta = float(runtime_player.upgrades.SPEED_PERCENT_BASE) * choice_speed_percent * 1.35
	runtime_player.upgrade_choice_rules.apply_choice(runtime_player, {"stat": "speed_percent", "value": choice_speed_percent})
	var actual_speed_delta = float(runtime_player.base_speed) - before_base_speed
	if abs(actual_speed_delta - expected_speed_delta) > 0.51:
		failures.append("Barnacle should amplify level-up stat choice values by 35 percent (expected %.2f, got %.2f)" % [expected_speed_delta, actual_speed_delta])
	runtime_player.speed = before_speed
	runtime_player.base_speed = before_base_speed
	runtime_player.remove_upgrade(barnacle)
	if not is_equal_approx(float(runtime_player.get("level_upgrade_stat_percent_bonus")), before_level_bonus):
		failures.append("Removing Barnacle should restore level-up stat bonus")
	if int(runtime_player.get("level_up_curse_gain_sources")) != before_curse_sources:
		failures.append("Removing Barnacle should restore Curse gain source count")
	runtime_player.curse = before_curse

	var before_engineering = int(runtime_player.engineering_bonus)
	var before_structure_sources = int(runtime_player.get("structure_engineering_penalty_sources"))
	main.turret_manager.cleanup()
	runtime_player.apply_upgrade(lighthouse)
	if int(runtime_player.engineering_bonus) != before_engineering + 20:
		failures.append("Applying Lighthouse should add 20 Engineering before structure penalty")
	if int(runtime_player.get("structure_engineering_penalty_sources")) != before_structure_sources + 1:
		failures.append("Applying Lighthouse should enable Engineering penalty per structure")
	main.turret_manager.spawn_catalog_turret(Vector2(300, 240), 10.0, 1.0, 300.0, 1.0)
	main.turret_manager.spawn_garden(Vector2(360, 240), 15.0)
	runtime_player.recalculate_structure_engineering_penalty()
	if int(runtime_player.engineering_bonus) != before_engineering + 18:
		failures.append("Lighthouse should subtract 1 Engineering per owned structure")
	if int(runtime_player.get("structure_engineering_penalty_bonus")) != -2:
		failures.append("Lighthouse should track the active structure Engineering penalty")
	main.turret_manager.cleanup()
	runtime_player.recalculate_structure_engineering_penalty()
	if int(runtime_player.engineering_bonus) != before_engineering + 20:
		failures.append("Lighthouse should restore Engineering when structures are removed")
	runtime_player.remove_upgrade(lighthouse)
	if int(runtime_player.engineering_bonus) != before_engineering:
		failures.append("Removing Lighthouse should restore Engineering after clearing structure penalty")
	if int(runtime_player.get("structure_engineering_penalty_sources")) != before_structure_sources:
		failures.append("Removing Lighthouse should restore structure penalty source count")

func _check_catalog_projectile_pierce_specials():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for projectile pierce check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var sharp_bullet = _find_by_source_id(pool, "sharp_bullet")
	var bandana = _find_by_source_id(pool, "bandana")
	if sharp_bullet.is_empty():
		failures.append("Runtime shop pool should include Sharp Bullet projectile pierce modifier")
	if bandana.is_empty():
		failures.append("Runtime shop pool should include Bandana projectile pierce modifier")
	if sharp_bullet.is_empty() or bandana.is_empty():
		return
	if not _has_weapon_special_rule(sharp_bullet.get("effects", []), "projectiles_pierce_plus_1"):
		failures.append("Sharp Bullet shop entry should preserve projectile pierce special rule")
	if not _has_stat_delta(sharp_bullet.get("effects", []), "piercing_damage_percent", -0.20):
		failures.append("Sharp Bullet shop entry should preserve piercing damage penalty")
	if not _has_weapon_special_rule(bandana.get("effects", []), "projectiles_pierce_plus_1"):
		failures.append("Bandana shop entry should preserve projectile pierce special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for projectile pierce check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for projectile pierce check")
		return
	if runtime_player.get("projectile_pierce_bonus") == null:
		failures.append("Player should expose projectile_pierce_bonus for projectile pierce items")
		return
	if runtime_player.get("piercing_damage_percent") == null:
		failures.append("Player should expose piercing_damage_percent for Sharp Bullet")
		return

	var before_pierce = int(runtime_player.get("projectile_pierce_bonus"))
	var before_piercing_damage = float(runtime_player.get("piercing_damage_percent"))
	runtime_player.apply_upgrade(sharp_bullet)
	runtime_player.apply_upgrade(bandana)
	if int(runtime_player.get("projectile_pierce_bonus")) != before_pierce + 2:
		failures.append("Sharp Bullet and Bandana should stack projectile pierce bonus")
	if not is_equal_approx(float(runtime_player.get("piercing_damage_percent")), before_piercing_damage - 0.20):
		failures.append("Sharp Bullet should apply piercing damage percent penalty")

	var enemy = main.get_enemy()
	runtime_player.position = Vector2(100, 100)
	enemy.position = Vector2(200, 100)
	runtime_player.combat._cached_enemies = [enemy]
	var test_weapon = {
		"type": "test_projectile",
		"data": {
			"name": "Test Projectile",
			"damage": 10,
			"fire_rate": 1.0,
			"count": 1,
			"spread": 0.0,
			"spd": 500.0,
			"color": Color(1, 1, 1),
			"range": 500.0
		}
	}
	runtime_player.combat.fire_weapon(test_weapon)
	var fired_bullet = _find_visible_bullet(main)
	if fired_bullet == null:
		failures.append("Projectile pierce check should fire a bullet; parent=%s has_get_bullet=%s cached_enemies=%d bullet_pool=%d" % [
			runtime_player.get_parent().name,
			str(runtime_player.get_parent().has_method("get_bullet")),
			runtime_player.combat._cached_enemies.size(),
			main.bullet_pool.size()
		])
	else:
		if not bool(fired_bullet.get("pierce")):
			failures.append("Projectile pierce bonus should make non-piercing ranged bullets pierce")
		if int(fired_bullet.get("pierce_hit_limit")) != 3:
			failures.append("Two projectile pierce bonuses should allow a non-piercing bullet to hit 3 enemies")
		if not is_equal_approx(float(fired_bullet.get("piercing_damage_percent")), -0.20):
			failures.append("Fired bullet should carry Sharp Bullet piercing damage penalty")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)
	runtime_player.remove_upgrade(bandana)
	runtime_player.remove_upgrade(sharp_bullet)
	if int(runtime_player.get("projectile_pierce_bonus")) != before_pierce:
		failures.append("Removing projectile pierce items should restore projectile pierce bonus")
	if not is_equal_approx(float(runtime_player.get("piercing_damage_percent")), before_piercing_damage):
		failures.append("Removing Sharp Bullet should restore piercing damage percent")

func _check_catalog_pumpkin_piercing_cap():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Pumpkin check: " + str(errors))
		return
	var pumpkin = _find_by_source_id(data.get_shop_pool(false), "pumpkin")
	if pumpkin.is_empty():
		failures.append("Runtime shop pool should include Pumpkin piercing cap modifier")
		return
	if not _has_stat_delta(pumpkin.get("effects", []), "piercing_damage_percent", 0.15):
		failures.append("Pumpkin shop entry should preserve piercing damage bonus")
	if not _has_weapon_special_rule(pumpkin.get("effects", []), "piercing_damage_cannot_exceed_base_damage"):
		failures.append("Pumpkin shop entry should preserve piercing damage cap special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Pumpkin piercing cap check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Pumpkin piercing cap check")
		return
	if runtime_player.get("piercing_damage_cap_at_base") == null:
		failures.append("Player should expose piercing_damage_cap_at_base for Pumpkin")
		return

	var before_piercing_damage = float(runtime_player.get("piercing_damage_percent"))
	var before_pierce_bonus = int(runtime_player.get("projectile_pierce_bonus"))
	runtime_player.apply_upgrade(pumpkin)
	if not is_equal_approx(float(runtime_player.get("piercing_damage_percent")), before_piercing_damage + 0.15):
		failures.append("Applying Pumpkin should add 15 percent piercing damage")
	if not bool(runtime_player.get("piercing_damage_cap_at_base")):
		failures.append("Applying Pumpkin should enable piercing damage cap at base damage")

	var enemy_a = main.get_enemy()
	var enemy_b = main.get_enemy()
	enemy_a.setup("normal", 1)
	enemy_b.setup("normal", 1)
	enemy_a.hp = 100
	enemy_a.max_hp = 100
	enemy_b.hp = 100
	enemy_b.max_hp = 100
	enemy_a.position = runtime_player.position + Vector2(100, 0)
	enemy_b.position = runtime_player.position + Vector2(160, 0)
	_reset_bullet_pool(main)
	runtime_player.projectile_pierce_bonus = 1
	runtime_player.piercing_damage_percent = 0.50
	runtime_player.combat._cached_enemies = [enemy_a]
	var test_weapon = {
		"type": "pumpkin_test_projectile",
		"data": {
			"name": "Pumpkin Test Projectile",
			"damage": 10,
			"fire_rate": 1.0,
			"count": 1,
			"spread": 0.0,
			"spd": 500.0,
			"color": Color(1, 1, 1),
			"range": 500.0
		}
	}
	runtime_player.combat.fire_weapon(test_weapon)
	var fired_bullet = _find_visible_bullet(main)
	if fired_bullet == null:
		failures.append("Pumpkin piercing cap check should fire a bullet")
	else:
		if not bool(fired_bullet.get("piercing_damage_cap_at_base")):
			failures.append("Fired bullet should carry Pumpkin piercing damage cap")
		fired_bullet._on_body_entered(enemy_a)
		fired_bullet._on_body_entered(enemy_b)
		if int(enemy_b.hp) != 90:
			failures.append("Pumpkin should cap pierced-target damage at base damage")
	if is_instance_valid(enemy_a):
		main.recycle_enemy(enemy_a)
	if is_instance_valid(enemy_b):
		main.recycle_enemy(enemy_b)

	runtime_player.projectile_pierce_bonus = before_pierce_bonus
	runtime_player.piercing_damage_percent = before_piercing_damage + 0.15
	runtime_player.remove_upgrade(pumpkin)
	if not is_equal_approx(float(runtime_player.get("piercing_damage_percent")), before_piercing_damage):
		failures.append("Removing Pumpkin should restore piercing damage percent")
	if bool(runtime_player.get("piercing_damage_cap_at_base")):
		failures.append("Removing Pumpkin should disable piercing damage cap")

func _check_catalog_ricochet_and_seashell_projectiles():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Ricochet/Seashell check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var ricochet = _find_by_source_id(pool, "ricochet")
	var seashell = _find_by_source_id(pool, "seashell")
	if ricochet.is_empty():
		failures.append("Runtime shop pool should include Ricochet projectile bounce item")
	if seashell.is_empty():
		failures.append("Runtime shop pool should include Seashell fifth-shot projectile item")
	if ricochet.is_empty() or seashell.is_empty():
		return
	if not _has_weapon_special_rule(ricochet.get("effects", []), "projectiles_bounce_plus_1"):
		failures.append("Ricochet should preserve projectile bounce special rule")
	if not _has_stat_delta(ricochet.get("effects", []), "damage_percent", -0.25):
		failures.append("Ricochet should preserve -25 percent Damage")
	if not _has_weapon_special_rule(seashell.get("effects", []), "every_ranged_weapon_fifth_projectile_has_plus_3_projectiles"):
		failures.append("Seashell should preserve fifth ranged projectile special rule")
	if not _has_stat_delta(seashell.get("effects", []), "damage_percent", -0.10):
		failures.append("Seashell should preserve -10 percent Damage")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Ricochet/Seashell check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Ricochet/Seashell check")
		return
	for required_property in [
		"projectile_bounce_bonus",
		"seashell_projectile_sources",
		"seashell_ranged_shot_counter",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Ricochet/Seashell" % required_property)
			return
	var bullet = main.get_bullet()
	if bullet.get("bounce_remaining") == null:
		failures.append("Bullet should expose bounce_remaining for Ricochet")
		return
	if bullet.has_method("_return_to_pool"):
		bullet._return_to_pool()

	var before_bounce = int(runtime_player.get("projectile_bounce_bonus"))
	var before_seashell_sources = int(runtime_player.get("seashell_projectile_sources"))
	var before_damage = float(runtime_player.damage_percent_bonus)
	runtime_player.apply_upgrade(ricochet)
	runtime_player.apply_upgrade(seashell)
	if int(runtime_player.get("projectile_bounce_bonus")) != before_bounce + 1:
		failures.append("Applying Ricochet should add one projectile bounce")
	if int(runtime_player.get("seashell_projectile_sources")) != before_seashell_sources + 1:
		failures.append("Applying Seashell should enable fifth-shot projectile bonus")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.35):
		failures.append("Ricochet and Seashell should apply their Damage penalties")

	_reset_bullet_pool(main)
	_reset_enemy_pool(main)
	runtime_player.position = Vector2(100, 100)
	var enemy_a = main.get_enemy()
	var enemy_b = main.get_enemy()
	enemy_a.setup("normal", 1)
	enemy_b.setup("normal", 1)
	enemy_a.position = Vector2(200, 100)
	enemy_b.position = Vector2(250, 100)
	enemy_a.hp = 50
	enemy_b.hp = 50
	runtime_player.combat._cached_enemies = [enemy_a, enemy_b]
	var test_weapon = {
		"type": "ricochet_test_projectile",
		"data": {
			"name": "Ricochet Test Projectile",
			"damage": 10,
			"fire_rate": 1.0,
			"count": 1,
			"spread": 0.0,
			"spd": 500.0,
			"color": Color(1, 1, 1),
			"range": 500.0
		}
	}
	runtime_player.combat.fire_weapon(test_weapon)
	var fired_bullet = _find_visible_bullet(main)
	if fired_bullet == null:
		failures.append("Ricochet check should fire a bullet")
	else:
		if int(fired_bullet.get("bounce_remaining")) != 1:
			failures.append("Ricochet should make fired bullets carry one bounce")
		fired_bullet._on_body_entered(enemy_a)
		if not fired_bullet.visible:
			failures.append("Ricochet bullet should stay active after its first hit if a bounce target exists")
		if int(fired_bullet.get("bounce_remaining")) != 0:
			failures.append("Ricochet should consume one bounce after redirecting")
		if fired_bullet.direction.dot((enemy_b.position - fired_bullet.position).normalized()) < 0.95:
			failures.append("Ricochet should redirect the bullet toward another enemy")

	_reset_bullet_pool(main)
	runtime_player.seashell_ranged_shot_counter = 4
	runtime_player.combat._cached_enemies = [enemy_a]
	runtime_player.combat.fire_weapon(test_weapon)
	var visible_bullets = _count_visible_bullets(main)
	if visible_bullets != 4:
		failures.append("Seashell should add +3 projectiles on every fifth ranged shot")
	_reset_enemy_pool(main)
	_reset_bullet_pool(main)

	runtime_player.remove_upgrade(seashell)
	runtime_player.remove_upgrade(ricochet)
	if int(runtime_player.get("projectile_bounce_bonus")) != before_bounce:
		failures.append("Removing Ricochet should restore projectile bounce bonus")
	if int(runtime_player.get("seashell_projectile_sources")) != before_seashell_sources:
		failures.append("Removing Seashell should restore Seashell sources")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Ricochet and Seashell should restore Damage")

func _check_catalog_alien_eyes_and_baby_beard_projectiles():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Alien Eyes/Baby with a Beard check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var alien_eyes = _find_by_source_id(pool, "alien_eyes")
	var baby_beard = _find_by_source_id(pool, "baby_with_a_beard")
	if alien_eyes.is_empty():
		failures.append("Runtime shop pool should include Alien Eyes timed projectile item")
	if baby_beard.is_empty():
		failures.append("Runtime shop pool should include Baby with a Beard corpse projectile item")
	if alien_eyes.is_empty() or baby_beard.is_empty():
		return
	if not _has_weapon_special_rule_number(alien_eyes.get("effects", []), "shoot_6_alien_eyes_every_3_seconds", "damage", 6.0):
		failures.append("Alien Eyes should preserve base projectile damage")
	if not _has_weapon_special_rule_number(alien_eyes.get("effects", []), "shoot_6_alien_eyes_every_3_seconds", "max_hp_damage_coefficient", 0.50):
		failures.append("Alien Eyes should preserve Max HP damage coefficient")
	if not _has_weapon_special_rule_number(baby_beard.get("effects", []), "enemy_corpse_fires_ranged_damage_bullet", "damage", 1.0):
		failures.append("Baby with a Beard should preserve base corpse bullet damage")
	if not _has_weapon_special_rule_number(baby_beard.get("effects", []), "enemy_corpse_fires_ranged_damage_bullet", "ranged_damage_coefficient", 1.0):
		failures.append("Baby with a Beard should preserve Ranged Damage coefficient")
	if not _has_stat_delta(baby_beard.get("effects", []), "range", -50.0):
		failures.append("Baby with a Beard should preserve -50 Range")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Alien Eyes/Baby with a Beard check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Alien Eyes/Baby with a Beard check")
		return
	for required_property in [
		"alien_eyes_sources",
		"alien_eyes_timer",
		"corpse_bullet_sources",
		"corpse_bullet_base_damage",
		"corpse_bullet_ranged_damage_coefficient",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Alien Eyes/Baby with a Beard" % required_property)
			return
	for required_method in [
		"process_alien_eyes",
		"fire_enemy_corpse_bullet",
		"spawn_catalog_projectile",
	]:
		if not runtime_player.has_method(required_method):
			failures.append("Player should expose %s for Alien Eyes/Baby with a Beard" % required_method)
			return

	var before_alien_sources = int(runtime_player.get("alien_eyes_sources"))
	var before_corpse_sources = int(runtime_player.get("corpse_bullet_sources"))
	var before_range = float(runtime_player.range_bonus)
	runtime_player.apply_upgrade(alien_eyes)
	runtime_player.apply_upgrade(baby_beard)
	if int(runtime_player.get("alien_eyes_sources")) != before_alien_sources + 1:
		failures.append("Applying Alien Eyes should enable one timed projectile source")
	if int(runtime_player.get("corpse_bullet_sources")) != before_corpse_sources + 1:
		failures.append("Applying Baby with a Beard should enable one corpse projectile source")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range - 50.0):
		failures.append("Applying Baby with a Beard should subtract 50 Range")

	_reset_bullet_pool(main)
	runtime_player.position = Vector2(320, 240)
	runtime_player.max_hp = 20
	runtime_player.alien_eyes_timer = 0.0
	runtime_player.process_alien_eyes(3.0)
	if _count_visible_bullets(main) != 6:
		failures.append("Alien Eyes should fire six timed projectiles")
	var alien_bullet = _find_visible_bullet(main)
	if alien_bullet == null:
		failures.append("Alien Eyes should create a visible bullet")
	else:
		if int(alien_bullet.get("damage")) != 16:
			failures.append("Alien Eyes projectile damage should be 6 + 50 percent Max HP")
		if alien_bullet.position.distance_to(runtime_player.position) > 1.0:
			failures.append("Alien Eyes projectiles should spawn from the player position")
	_reset_bullet_pool(main)

	_reset_enemy_pool(main)
	var corpse = main.get_enemy()
	var target = main.get_enemy()
	corpse.setup("normal", 1)
	target.setup("normal", 1)
	corpse.position = Vector2(250, 250)
	target.position = Vector2(430, 250)
	corpse.hp = 0
	target.hp = 50
	var before_ranged_damage = int(runtime_player.ranged_damage_bonus)
	runtime_player.ranged_damage_bonus = 7
	runtime_player.fire_enemy_corpse_bullet(corpse)
	var corpse_bullet = _find_visible_bullet(main)
	if corpse_bullet == null:
		failures.append("Baby with a Beard should fire a visible bullet from the corpse")
	else:
		if int(corpse_bullet.get("damage")) != 8:
			failures.append("Baby with a Beard corpse bullet should deal 1 + Ranged Damage")
		if corpse_bullet.position.distance_to(corpse.position) > 1.0:
			failures.append("Baby with a Beard corpse bullet should spawn at the dead enemy")
		if corpse_bullet.direction.dot((target.position - corpse.position).normalized()) < 0.95:
			failures.append("Baby with a Beard corpse bullet should aim at another visible enemy")
	runtime_player.ranged_damage_bonus = before_ranged_damage
	_reset_enemy_pool(main)
	_reset_bullet_pool(main)

	runtime_player.remove_upgrade(baby_beard)
	runtime_player.remove_upgrade(alien_eyes)
	if int(runtime_player.get("alien_eyes_sources")) != before_alien_sources:
		failures.append("Removing Alien Eyes should restore timed projectile sources")
	if int(runtime_player.get("corpse_bullet_sources")) != before_corpse_sources:
		failures.append("Removing Baby with a Beard should restore corpse projectile sources")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range):
		failures.append("Removing Baby with a Beard should restore Range")

func _check_catalog_silver_bullet_boss_elite_damage():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Silver Bullet check: " + str(errors))
		return
	var silver_bullet = _find_by_source_id(data.get_shop_pool(false), "silver_bullet")
	if silver_bullet.is_empty():
		failures.append("Runtime shop pool should include Silver Bullet boss/elite damage modifier")
		return
	if not _has_stat_delta(silver_bullet.get("effects", []), "boss_elite_damage_percent", 0.25):
		failures.append("Silver Bullet shop entry should preserve boss/elite damage bonus")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Silver Bullet boss/elite damage check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Silver Bullet boss/elite damage check")
		return
	if runtime_player.get("boss_elite_damage_percent") == null:
		failures.append("Player should expose boss_elite_damage_percent for Silver Bullet")
		return

	var before_bonus = float(runtime_player.get("boss_elite_damage_percent"))
	runtime_player.apply_upgrade(silver_bullet)
	if not is_equal_approx(float(runtime_player.get("boss_elite_damage_percent")), before_bonus + 0.25):
		failures.append("Applying Silver Bullet should add 25 percent boss/elite damage")

	_reset_enemy_pool(main)
	var normal = main.get_enemy()
	var boss = main.get_enemy()
	var elite = main.get_enemy()
	normal.setup("normal", 1)
	boss.setup("boss", 1)
	elite.setup("elite", 1)
	for enemy in [normal, boss, elite]:
		enemy.max_hp = 100
		enemy.hp = 100
		enemy.armor_value = 0
		enemy.ghost_invincible = false
		enemy.position = runtime_player.position + Vector2(80, 0)
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 20, false)
	bullet._on_body_entered(normal)
	bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 20, false)
	bullet._on_body_entered(boss)
	bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 20, false)
	bullet._on_body_entered(elite)
	if int(normal.hp) != 80:
		failures.append("Silver Bullet should not change normal enemy damage")
	if int(boss.hp) != 75:
		failures.append("Silver Bullet should add 25 percent damage against bosses")
	if int(elite.hp) != 75:
		failures.append("Silver Bullet should add 25 percent damage against elites")
	if is_instance_valid(normal):
		main.recycle_enemy(normal)
	if is_instance_valid(boss):
		main.recycle_enemy(boss)
	if is_instance_valid(elite):
		main.recycle_enemy(elite)

	runtime_player.boss_elite_damage_percent = before_bonus + 0.25
	runtime_player.remove_upgrade(silver_bullet)
	if not is_equal_approx(float(runtime_player.get("boss_elite_damage_percent")), before_bonus):
		failures.append("Removing Silver Bullet should restore boss/elite damage")

func _check_catalog_giant_belt_critical_current_hp_damage():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Giant Belt check: " + str(errors))
		return
	var giant_belt = _find_by_source_id(data.get_shop_pool(false), "giant_belt")
	if giant_belt.is_empty():
		failures.append("Runtime shop pool should include Giant Belt critical current-HP modifier")
		return
	if not _has_weapon_special_rule(giant_belt.get("effects", []), "critical_hits_deal_current_hp_bonus_damage"):
		failures.append("Giant Belt shop entry should preserve current-HP critical special rule")
		return
	if not _has_weapon_special_rule_number(giant_belt.get("effects", []), "critical_hits_deal_current_hp_bonus_damage", "enemy_current_hp_percent", 0.10):
		failures.append("Giant Belt should preserve 10 percent current-HP critical damage")
	if not _has_weapon_special_rule_number(giant_belt.get("effects", []), "critical_hits_deal_current_hp_bonus_damage", "boss_elite_current_hp_percent", 0.01):
		failures.append("Giant Belt should preserve 1 percent boss/elite current-HP critical damage")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Giant Belt current-HP critical damage check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Giant Belt current-HP critical damage check")
		return
	if runtime_player.get("critical_current_hp_bonus_enemy_percent") == null:
		failures.append("Player should expose critical_current_hp_bonus_enemy_percent for Giant Belt")
		return
	if runtime_player.get("critical_current_hp_bonus_boss_elite_percent") == null:
		failures.append("Player should expose critical_current_hp_bonus_boss_elite_percent for Giant Belt")
		return

	var before_enemy_percent = float(runtime_player.get("critical_current_hp_bonus_enemy_percent"))
	var before_boss_percent = float(runtime_player.get("critical_current_hp_bonus_boss_elite_percent"))
	runtime_player.apply_upgrade(giant_belt)
	if not is_equal_approx(float(runtime_player.get("critical_current_hp_bonus_enemy_percent")), before_enemy_percent + 0.10):
		failures.append("Applying Giant Belt should add 10 percent normal current-HP critical damage")
	if not is_equal_approx(float(runtime_player.get("critical_current_hp_bonus_boss_elite_percent")), before_boss_percent + 0.01):
		failures.append("Applying Giant Belt should add 1 percent boss/elite current-HP critical damage")

	_reset_enemy_pool(main)
	var normal_noncrit = main.get_enemy()
	var normal_crit = main.get_enemy()
	var boss_crit = main.get_enemy()
	var elite_crit = main.get_enemy()
	normal_noncrit.setup("normal", 1)
	normal_crit.setup("normal", 1)
	boss_crit.setup("boss", 1)
	elite_crit.setup("elite", 1)
	for enemy in [normal_noncrit, normal_crit, boss_crit, elite_crit]:
		enemy.max_hp = 100
		enemy.hp = 100
		enemy.armor_value = 0
		enemy.ghost_invincible = false
		enemy.position = runtime_player.position + Vector2(80, 0)
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 10, false)
	bullet._on_body_entered(normal_noncrit)
	bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 10, true)
	bullet._on_body_entered(normal_crit)
	bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 10, true)
	bullet._on_body_entered(boss_crit)
	bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 10, true)
	bullet._on_body_entered(elite_crit)
	if int(normal_noncrit.hp) != 90:
		failures.append("Giant Belt should not add current-HP damage on non-critical hits")
	if int(normal_crit.hp) != 80:
		failures.append("Giant Belt critical hits should add 10 percent of current HP against normal enemies")
	if int(boss_crit.hp) != 89:
		failures.append("Giant Belt critical hits should add 1 percent of current HP against bosses")
	if int(elite_crit.hp) != 89:
		failures.append("Giant Belt critical hits should add 1 percent of current HP against elites")
	for enemy in [normal_noncrit, normal_crit, boss_crit, elite_crit]:
		if is_instance_valid(enemy):
			main.recycle_enemy(enemy)

	runtime_player.critical_current_hp_bonus_enemy_percent = before_enemy_percent + 0.10
	runtime_player.critical_current_hp_bonus_boss_elite_percent = before_boss_percent + 0.01
	runtime_player.remove_upgrade(giant_belt)
	if not is_equal_approx(float(runtime_player.get("critical_current_hp_bonus_enemy_percent")), before_enemy_percent):
		failures.append("Removing Giant Belt should restore normal current-HP critical damage")
	if not is_equal_approx(float(runtime_player.get("critical_current_hp_bonus_boss_elite_percent")), before_boss_percent):
		failures.append("Removing Giant Belt should restore boss/elite current-HP critical damage")

func _check_catalog_lucky_coin_crit_scaling_luck():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Lucky Coin check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var lucky_coin = _find_by_source_id(pool, "lucky_coin")
	var insanity = _find_by_source_id(pool, "insanity")
	if lucky_coin.is_empty():
		failures.append("Runtime shop pool should include Lucky Coin crit-scaling luck modifier")
		return
	if insanity.is_empty():
		failures.append("Runtime shop pool should include Insanity for Lucky Coin dynamic crit-scaling check")
		return
	if not _has_weapon_special_rule(lucky_coin.get("effects", []), "luck_plus_2_per_1_crit_chance_percent"):
		failures.append("Lucky Coin shop entry should preserve crit-scaling luck special rule")
	if not _has_stat_delta(lucky_coin.get("effects", []), "armor", -2.0):
		failures.append("Lucky Coin shop entry should preserve armor penalty")
	if not _has_stat_delta(insanity.get("effects", []), "crit_chance", 0.06):
		failures.append("Insanity should preserve crit chance for Lucky Coin dynamic scaling check")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Lucky Coin crit-scaling check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Lucky Coin crit-scaling check")
		return
	if runtime_player.get("crit_scaling_luck_sources") == null:
		failures.append("Player should expose crit_scaling_luck_sources for Lucky Coin")
		return
	if runtime_player.get("crit_scaling_luck_per_percent") == null:
		failures.append("Player should expose crit_scaling_luck_per_percent for Lucky Coin")
		return
	if runtime_player.get("crit_scaling_luck_bonus") == null:
		failures.append("Player should expose crit_scaling_luck_bonus for Lucky Coin")
		return

	var before_luck = int(runtime_player.luck)
	var before_armor = int(runtime_player.armor)
	var before_crit = float(runtime_player.crit_chance)
	runtime_player.crit_chance = 0.10
	runtime_player.apply_upgrade(lucky_coin)
	if int(runtime_player.armor) != before_armor - 2:
		failures.append("Applying Lucky Coin should subtract 2 armor")
	if int(runtime_player.luck) != before_luck + 20:
		failures.append("Applying Lucky Coin should add 2 luck per crit percent")
	if int(runtime_player.get("crit_scaling_luck_bonus")) != 20:
		failures.append("Lucky Coin should track its derived luck bonus")
	if not is_equal_approx(float(runtime_player.get("crit_scaling_luck_per_percent")), 2.0):
		failures.append("Lucky Coin should track 2 luck per crit percent")

	runtime_player.apply_upgrade(insanity)
	if not is_equal_approx(float(runtime_player.crit_chance), 0.16):
		failures.append("Applying Insanity should add 6 percent crit chance")
	if int(runtime_player.luck) != before_luck + 32:
		failures.append("Lucky Coin should recalculate luck when crit chance increases")
	if int(runtime_player.get("crit_scaling_luck_bonus")) != 32:
		failures.append("Lucky Coin should update its derived luck bonus after crit changes")

	runtime_player.remove_upgrade(insanity)
	if not is_equal_approx(float(runtime_player.crit_chance), 0.10):
		failures.append("Removing Insanity should restore crit chance for Lucky Coin check")
	if int(runtime_player.luck) != before_luck + 20:
		failures.append("Lucky Coin should recalculate luck when crit chance decreases")

	runtime_player.remove_upgrade(lucky_coin)
	if int(runtime_player.armor) != before_armor:
		failures.append("Removing Lucky Coin should restore armor")
	if int(runtime_player.luck) != before_luck:
		failures.append("Removing Lucky Coin should remove derived luck")
	if int(runtime_player.get("crit_scaling_luck_sources")) != 0:
		failures.append("Removing Lucky Coin should clear crit-scaling luck source count")
	if int(runtime_player.get("crit_scaling_luck_bonus")) != 0:
		failures.append("Removing Lucky Coin should clear derived luck bonus")
	runtime_player.crit_chance = before_crit

func _check_catalog_pearl_luck_damage_and_crate_reward():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Pearl check: " + str(errors))
		return
	var pearl = _find_by_source_id(data.get_shop_pool(false), "pearl")
	if pearl.is_empty():
		failures.append("Runtime shop pool should include Pearl luck-scaling damage and crate special")
		return
	if not _has_weapon_special_rule(pearl.get("effects", []), "damage_percent_plus_1_per_10_permanent_luck"):
		failures.append("Pearl should preserve Luck-scaling damage rule")
	if not _has_weapon_special_rule_chance(pearl.get("effects", []), "extra_pearl_chance_in_crate", 0.03):
		failures.append("Pearl should preserve 3 percent extra Pearl crate chance")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Pearl check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Pearl check")
		return
	for required_property in [
		"luck_scaling_damage_sources",
		"luck_scaling_damage_bonus",
		"extra_pearl_crate_chance",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Pearl" % required_property)
			return
	if not runtime_player.has_method("recalculate_luck_scaling_damage"):
		failures.append("Player should expose recalculate_luck_scaling_damage for Pearl")
		return

	var before_luck = int(runtime_player.luck)
	var before_damage = float(runtime_player.damage_percent_bonus)
	var before_extra_crate = float(runtime_player.extra_crate_reward_chance)
	runtime_player.luck = 25
	runtime_player.damage_percent_bonus = 0.0
	runtime_player.luck_scaling_damage_sources = 0
	runtime_player.luck_scaling_damage_bonus = 0.0
	runtime_player.extra_crate_reward_chance = 0.0
	runtime_player.extra_pearl_crate_chance = 0.0
	runtime_player.apply_upgrade(pearl)
	if int(runtime_player.get("luck_scaling_damage_sources")) != 1:
		failures.append("Applying Pearl should enable Luck-scaling damage")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.02):
		failures.append("Pearl should add 1 percent Damage per 10 current Luck")
	if not is_equal_approx(float(runtime_player.get("luck_scaling_damage_bonus")), 0.02):
		failures.append("Pearl should track derived Luck-scaling Damage")
	if not is_equal_approx(float(runtime_player.get("extra_pearl_crate_chance")), 0.03):
		failures.append("Applying Pearl should add 3 percent extra Pearl crate chance")
	runtime_player.luck = 49
	runtime_player.recalculate_luck_scaling_damage()
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.04):
		failures.append("Pearl should recalculate Damage when current Luck changes")

	main.pending_crate_rewards.clear()
	runtime_player.extra_pearl_crate_chance = 1.0
	main.enqueue_crate_reward(1)
	if main.pending_crate_rewards.size() != 2:
		failures.append("Guaranteed Pearl crate chance should append one extra crate reward")
	elif str(main.pending_crate_rewards[1].get("source_id", "")) != "pearl":
		failures.append("Guaranteed Pearl crate chance should append Pearl as the extra reward")
	main.pending_crate_rewards.clear()
	runtime_player.extra_pearl_crate_chance = 0.03

	runtime_player.remove_upgrade(pearl)
	if int(runtime_player.get("luck_scaling_damage_sources")) != 0:
		failures.append("Removing Pearl should disable Luck-scaling damage")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), 0.0):
		failures.append("Removing Pearl should clear derived Luck-scaling Damage")
	if not is_equal_approx(float(runtime_player.get("extra_pearl_crate_chance")), 0.0):
		failures.append("Removing Pearl should restore extra Pearl crate chance")
	runtime_player.luck = before_luck
	runtime_player.damage_percent_bonus = before_damage
	runtime_player.extra_crate_reward_chance = before_extra_crate

func _check_catalog_wisdom_timed_damage_growth():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Wisdom check: " + str(errors))
		return
	var wisdom = _find_by_source_id(data.get_shop_pool(false), "wisdom")
	if wisdom.is_empty():
		failures.append("Runtime shop pool should include Wisdom timed damage growth modifier")
		return
	if not _has_weapon_special_rule(wisdom.get("effects", []), "damage_percent_plus_5_every_5_seconds_until_wave_end"):
		failures.append("Wisdom shop entry should preserve timed damage growth special rule")
	if not _has_stat_delta(wisdom.get("effects", []), "damage_percent", -0.15):
		failures.append("Wisdom shop entry should preserve initial damage penalty")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Wisdom timed damage check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Wisdom timed damage check")
		return
	if runtime_player.get("wisdom_damage_sources") == null:
		failures.append("Player should expose wisdom_damage_sources for Wisdom")
		return
	if runtime_player.get("wisdom_damage_timer") == null:
		failures.append("Player should expose wisdom_damage_timer for Wisdom")
		return
	if runtime_player.get("wisdom_damage_bonus") == null:
		failures.append("Player should expose wisdom_damage_bonus for Wisdom")
		return

	var before_damage = float(runtime_player.damage_percent_bonus)
	runtime_player.apply_upgrade(wisdom)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.15):
		failures.append("Applying Wisdom should subtract 15 percent damage before timed growth")
	if int(runtime_player.get("wisdom_damage_sources")) != 1:
		failures.append("Applying Wisdom should enable one timed damage growth source")
	runtime_player.stats_module.update_game_time(4.9)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.15):
		failures.append("Wisdom should not add timed damage before five seconds")
	runtime_player.stats_module.update_game_time(0.1)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.10):
		failures.append("Wisdom should add 5 percent damage after five seconds")
	runtime_player.stats_module.update_game_time(5.0)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.05):
		failures.append("Wisdom should add another 5 percent damage every five seconds")
	if not is_equal_approx(float(runtime_player.get("wisdom_damage_bonus")), 0.10):
		failures.append("Wisdom should track its current wave damage bonus")

	runtime_player.on_wave_start()
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.15):
		failures.append("Wisdom timed damage bonus should reset at wave start")
	if not is_equal_approx(float(runtime_player.get("wisdom_damage_bonus")), 0.0):
		failures.append("Wisdom tracked bonus should clear at wave start")

	runtime_player.stats_module.update_game_time(5.0)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage - 0.10):
		failures.append("Wisdom should resume timed damage growth after wave reset")
	runtime_player.remove_upgrade(wisdom)
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), before_damage):
		failures.append("Removing Wisdom should restore damage percent and clear active timed bonus")
	if int(runtime_player.get("wisdom_damage_sources")) != 0:
		failures.append("Removing Wisdom should clear timed damage source count")
	if not is_equal_approx(float(runtime_player.get("wisdom_damage_bonus")), 0.0):
		failures.append("Removing Wisdom should clear timed damage bonus")

func _check_catalog_medikit_timed_hp_regeneration_growth():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Medikit check: " + str(errors))
		return
	var medikit = _find_by_source_id(data.get_shop_pool(false), "medikit")
	if medikit.is_empty():
		failures.append("Runtime shop pool should include Medikit timed HP regeneration growth modifier")
		return
	if not _has_weapon_special_rule(medikit.get("effects", []), "hp_regeneration_plus_2_every_5_seconds_until_wave_end"):
		failures.append("Medikit shop entry should preserve timed HP regeneration growth special rule")
	if not _has_stat_delta(medikit.get("effects", []), "hp_regeneration", 10.0):
		failures.append("Medikit shop entry should preserve HP regeneration bonus")
	if not _has_stat_delta(medikit.get("effects", []), "luck", -10.0):
		failures.append("Medikit shop entry should preserve Luck penalty")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Medikit timed HP regeneration check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Medikit timed HP regeneration check")
		return
	if runtime_player.get("medikit_hp_regen_sources") == null:
		failures.append("Player should expose medikit_hp_regen_sources for Medikit")
		return
	if runtime_player.get("medikit_hp_regen_timer") == null:
		failures.append("Player should expose medikit_hp_regen_timer for Medikit")
		return
	if runtime_player.get("medikit_hp_regen_bonus") == null:
		failures.append("Player should expose medikit_hp_regen_bonus for Medikit")
		return

	var before_regen = int(runtime_player.hp_regen)
	var before_luck = int(runtime_player.luck)
	runtime_player.apply_upgrade(medikit)
	if int(runtime_player.hp_regen) != before_regen + 10:
		failures.append("Applying Medikit should add 10 HP regeneration before timed growth")
	if int(runtime_player.luck) != before_luck - 10:
		failures.append("Applying Medikit should subtract 10 Luck")
	if int(runtime_player.get("medikit_hp_regen_sources")) != 1:
		failures.append("Applying Medikit should enable one timed HP regeneration growth source")
	runtime_player.stats_module.update_game_time(4.9)
	if int(runtime_player.hp_regen) != before_regen + 10:
		failures.append("Medikit should not add timed HP regeneration before five seconds")
	runtime_player.stats_module.update_game_time(0.1)
	if int(runtime_player.hp_regen) != before_regen + 12:
		failures.append("Medikit should add 2 HP regeneration after five seconds")
	runtime_player.stats_module.update_game_time(5.0)
	if int(runtime_player.hp_regen) != before_regen + 14:
		failures.append("Medikit should add another 2 HP regeneration every five seconds")
	if int(runtime_player.get("medikit_hp_regen_bonus")) != 4:
		failures.append("Medikit should track its current wave HP regeneration bonus")

	runtime_player.on_wave_start()
	if int(runtime_player.hp_regen) != before_regen + 10:
		failures.append("Medikit timed HP regeneration bonus should reset at wave start")
	if int(runtime_player.get("medikit_hp_regen_bonus")) != 0:
		failures.append("Medikit tracked HP regeneration bonus should clear at wave start")

	runtime_player.stats_module.update_game_time(5.0)
	if int(runtime_player.hp_regen) != before_regen + 12:
		failures.append("Medikit should resume timed HP regeneration growth after wave reset")
	runtime_player.remove_upgrade(medikit)
	if int(runtime_player.hp_regen) != before_regen:
		failures.append("Removing Medikit should restore HP regeneration and clear active timed bonus")
	if int(runtime_player.luck) != before_luck:
		failures.append("Removing Medikit should restore Luck")
	if int(runtime_player.get("medikit_hp_regen_sources")) != 0:
		failures.append("Removing Medikit should clear timed HP regeneration source count")
	if int(runtime_player.get("medikit_hp_regen_bonus")) != 0:
		failures.append("Removing Medikit should clear timed HP regeneration bonus")

func _check_catalog_engineering_weapon_and_crystal_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for engineering weapon/Crystal check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var nail = _find_by_source_id(pool, "nail")
	var crystal = _find_by_source_id(pool, "crystal")
	if nail.is_empty():
		failures.append("Runtime shop pool should include Nail engineering weapon damage scaling")
	if crystal.is_empty():
		failures.append("Runtime shop pool should include Crystal timed attack speed growth")
	if nail.is_empty() or crystal.is_empty():
		return
	if not _has_stat_delta(nail.get("effects", []), "engineering", 5.0):
		failures.append("Nail should preserve Engineering bonus")
	if not _has_stat_delta(nail.get("effects", []), "ranged_damage", -2.0):
		failures.append("Nail should preserve Ranged Damage penalty")
	if not _has_weapon_special_rule(nail.get("effects", []), "weapon_damage_scales_with_20_percent_engineering"):
		failures.append("Nail should preserve engineering weapon damage scaling rule")
	if not _has_stat_delta(crystal.get("effects", []), "attack_speed_percent", 0.05):
		failures.append("Crystal should preserve base Attack Speed bonus")
	if not _has_stat_delta(crystal.get("effects", []), "engineering", -2.0):
		failures.append("Crystal should preserve Engineering penalty")
	if not _has_weapon_special_rule(crystal.get("effects", []), "attack_speed_percent_plus_1_every_second_until_wave_end_lost_on_damage"):
		failures.append("Crystal should preserve timed attack speed growth rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for engineering weapon/Crystal check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for engineering weapon/Crystal check")
		return
	for required_property in [
		"engineering_weapon_damage_scaling_sources",
		"crystal_attack_speed_sources",
		"crystal_attack_speed_timer",
		"crystal_attack_speed_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for engineering weapon/Crystal items" % required_property)
			return

	runtime_player.engineering_bonus = 0
	runtime_player.ranged_damage_bonus = 0
	runtime_player.damage_percent_bonus = 0.0
	runtime_player.elemental_weapon_damage_scaling_sources = 0
	runtime_player.engineering_weapon_damage_scaling_sources = 0
	runtime_player.apply_upgrade(nail)
	if int(runtime_player.engineering_bonus) != 5:
		failures.append("Applying Nail should add 5 Engineering")
	if int(runtime_player.ranged_damage_bonus) != -2:
		failures.append("Applying Nail should subtract 2 Ranged Damage")
	if int(runtime_player.get("engineering_weapon_damage_scaling_sources")) != 1:
		failures.append("Applying Nail should enable engineering weapon damage scaling")
	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.max_hp = 20
	enemy.hp = 20
	enemy.position = runtime_player.position + Vector2(80, 0)
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 1, false)
	bullet._on_body_entered(enemy)
	if int(enemy.hp) != 18:
		failures.append("Nail should add 20 percent Engineering as weapon damage")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)
	runtime_player.remove_upgrade(nail)
	if int(runtime_player.engineering_bonus) != 0:
		failures.append("Removing Nail should restore Engineering")
	if int(runtime_player.ranged_damage_bonus) != 0:
		failures.append("Removing Nail should restore Ranged Damage")
	if int(runtime_player.get("engineering_weapon_damage_scaling_sources")) != 0:
		failures.append("Removing Nail should disable engineering weapon damage scaling")

	runtime_player.fire_rate_multiplier = 1.0
	runtime_player.crystal_attack_speed_sources = 0
	runtime_player.crystal_attack_speed_timer = 0.0
	runtime_player.crystal_attack_speed_bonus = 0.0
	runtime_player.apply_upgrade(crystal)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.05):
		failures.append("Applying Crystal should add 5 percent base Attack Speed")
	if int(runtime_player.get("engineering_bonus")) != -2:
		failures.append("Applying Crystal should subtract 2 Engineering")
	if int(runtime_player.get("crystal_attack_speed_sources")) != 1:
		failures.append("Applying Crystal should enable timed Attack Speed growth")
	runtime_player.stats_module.update_game_time(0.9)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.05):
		failures.append("Crystal should not add timed Attack Speed before one second")
	runtime_player.stats_module.update_game_time(0.1)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.06):
		failures.append("Crystal should add 1 percent Attack Speed after one second")
	runtime_player.stats_module.update_game_time(2.0)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.08):
		failures.append("Crystal should add 1 percent Attack Speed every second")
	if not is_equal_approx(float(runtime_player.get("crystal_attack_speed_bonus")), 0.03):
		failures.append("Crystal should track current wave Attack Speed bonus")
	runtime_player.on_damage_taken(1)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.05):
		failures.append("Crystal timed Attack Speed bonus should be lost on damage")
	if not is_equal_approx(float(runtime_player.get("crystal_attack_speed_bonus")), 0.0):
		failures.append("Crystal tracked Attack Speed bonus should clear on damage")
	runtime_player.stats_module.update_game_time(1.0)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.06):
		failures.append("Crystal should resume timed Attack Speed growth after damage reset")
	runtime_player.on_wave_start()
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.05):
		failures.append("Crystal timed Attack Speed bonus should reset at wave start")
	runtime_player.remove_upgrade(crystal)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.0):
		failures.append("Removing Crystal should restore base Attack Speed and clear timed bonus")
	if int(runtime_player.get("engineering_bonus")) != 0:
		failures.append("Removing Crystal should restore Engineering")
	if int(runtime_player.get("crystal_attack_speed_sources")) != 0:
		failures.append("Removing Crystal should clear timed Attack Speed source count")

func _check_catalog_living_and_burning_enemy_scaling_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for living/burning enemy scaling check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var community_support = _find_by_source_id(pool, "community_support")
	var fried_rice = _find_by_source_id(pool, "fried_rice")
	if community_support.is_empty():
		failures.append("Runtime shop pool should include Community Support living enemy attack speed scaling")
	if fried_rice.is_empty():
		failures.append("Runtime shop pool should include Fried Rice burning enemy HP regeneration scaling")
	if community_support.is_empty() or fried_rice.is_empty():
		return
	if not _has_weapon_special_rule(community_support.get("effects", []), "attack_speed_percent_plus_1_per_living_enemy"):
		failures.append("Community Support should preserve living enemy attack speed scaling rule")
	if not _has_stat_delta(community_support.get("effects", []), "armor", -2.0):
		failures.append("Community Support should preserve Armor penalty")
	if not _has_weapon_special_rule(fried_rice.get("effects", []), "hp_regeneration_plus_1_per_currently_burning_enemy"):
		failures.append("Fried Rice should preserve burning enemy HP regeneration scaling rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for living/burning enemy scaling check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for living/burning enemy scaling check")
		return
	for required_property in [
		"living_enemy_attack_speed_sources",
		"living_enemy_attack_speed_bonus",
		"burning_enemy_hp_regen_sources",
		"burning_enemy_hp_regen_bonus",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for living/burning enemy scaling items" % required_property)
			return
	if not runtime_player.has_method("recalculate_living_enemy_attack_speed"):
		failures.append("Player should expose recalculate_living_enemy_attack_speed")
		return
	if not runtime_player.has_method("recalculate_burning_enemy_hp_regen"):
		failures.append("Player should expose recalculate_burning_enemy_hp_regen")
		return

	_reset_enemy_pool(main)
	runtime_player.fire_rate_multiplier = 1.0
	runtime_player.armor = 0
	runtime_player.living_enemy_attack_speed_sources = 0
	runtime_player.living_enemy_attack_speed_bonus = 0.0
	runtime_player.apply_upgrade(community_support)
	if int(runtime_player.armor) != -2:
		failures.append("Applying Community Support should subtract 2 Armor")
	if int(runtime_player.get("living_enemy_attack_speed_sources")) != 1:
		failures.append("Applying Community Support should enable living enemy Attack Speed scaling")
	var living_enemies: Array = []
	for i in range(3):
		var enemy = main.get_enemy()
		enemy.setup("normal", 1)
		enemy.max_hp = 10
		enemy.hp = 10
		living_enemies.append(enemy)
	runtime_player.recalculate_living_enemy_attack_speed()
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.03):
		failures.append("Community Support should add 1 percent Attack Speed per living enemy")
	main.recycle_enemy(living_enemies.pop_back())
	runtime_player.recalculate_living_enemy_attack_speed()
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.02):
		failures.append("Community Support should shrink Attack Speed bonus when a living enemy is removed")
	runtime_player.remove_upgrade(community_support)
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), 1.0):
		failures.append("Removing Community Support should clear living enemy Attack Speed bonus")
	if int(runtime_player.armor) != 0:
		failures.append("Removing Community Support should restore Armor")
	if int(runtime_player.get("living_enemy_attack_speed_sources")) != 0:
		failures.append("Removing Community Support should clear living enemy Attack Speed source count")
	for enemy in living_enemies:
		if is_instance_valid(enemy):
			main.recycle_enemy(enemy)

	_reset_enemy_pool(main)
	runtime_player.hp_regen = 0
	runtime_player.burning_enemy_hp_regen_sources = 0
	runtime_player.burning_enemy_hp_regen_bonus = 0
	runtime_player.apply_upgrade(fried_rice)
	if int(runtime_player.get("burning_enemy_hp_regen_sources")) != 1:
		failures.append("Applying Fried Rice should enable burning enemy HP regeneration scaling")
	var burning_a = main.get_enemy()
	var burning_b = main.get_enemy()
	var unburned = main.get_enemy()
	for enemy in [burning_a, burning_b, unburned]:
		enemy.setup("normal", 1)
		enemy.max_hp = 10
		enemy.hp = 10
	burning_a.apply_burn()
	burning_b.apply_burn()
	runtime_player.recalculate_burning_enemy_hp_regen()
	if int(runtime_player.hp_regen) != 2:
		failures.append("Fried Rice should add 1 HP Regeneration per burning enemy")
	burning_b.burn_timer = 0.0
	runtime_player.recalculate_burning_enemy_hp_regen()
	if int(runtime_player.hp_regen) != 1:
		failures.append("Fried Rice should shrink HP Regeneration bonus when an enemy stops burning")
	runtime_player.remove_upgrade(fried_rice)
	if int(runtime_player.hp_regen) != 0:
		failures.append("Removing Fried Rice should clear burning enemy HP Regeneration bonus")
	if int(runtime_player.get("burning_enemy_hp_regen_sources")) != 0:
		failures.append("Removing Fried Rice should clear burning enemy HP Regeneration source count")
	for enemy in [burning_a, burning_b, unburned]:
		if is_instance_valid(enemy):
			main.recycle_enemy(enemy)

func _check_catalog_ugly_tooth_hit_slow():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Ugly Tooth check: " + str(errors))
		return
	var ugly_tooth = _find_by_source_id(data.get_shop_pool(false), "ugly_tooth")
	if ugly_tooth.is_empty():
		failures.append("Runtime shop pool should include Ugly Tooth hit slow modifier")
		return
	if not _has_weapon_special_rule(ugly_tooth.get("effects", []), "hit_enemy_speed_reduction"):
		failures.append("Ugly Tooth shop entry should preserve hit slow special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Ugly Tooth hit slow check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Ugly Tooth hit slow check")
		return
	if runtime_player.get("hit_enemy_slow_percent_per_hit") == null:
		failures.append("Player should expose hit_enemy_slow_percent_per_hit for Ugly Tooth")
		return
	if runtime_player.get("hit_enemy_slow_percent_max") == null:
		failures.append("Player should expose hit_enemy_slow_percent_max for Ugly Tooth")
		return

	var before_per_hit = float(runtime_player.get("hit_enemy_slow_percent_per_hit"))
	var before_max = float(runtime_player.get("hit_enemy_slow_percent_max"))
	runtime_player.apply_upgrade(ugly_tooth)
	if not is_equal_approx(float(runtime_player.get("hit_enemy_slow_percent_per_hit")), before_per_hit + 0.05):
		failures.append("Applying Ugly Tooth should add 5 percent hit slow per hit")
	if not is_equal_approx(float(runtime_player.get("hit_enemy_slow_percent_max")), before_max + 0.20):
		failures.append("Applying Ugly Tooth should add 20 percent hit slow cap")

	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.hp = 20
	enemy.max_hp = 20
	enemy.position = runtime_player.position + Vector2(80, 0)
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 1, false)
	bullet._on_body_entered(enemy)
	bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 1, false)
	bullet._on_body_entered(enemy)
	if not is_equal_approx(float(enemy.get("catalog_hit_slow_percent")), 0.10):
		failures.append("Ugly Tooth should stack enemy hit slow by 5 percent per hit")
	if not is_equal_approx(float(enemy.get("_slow_factor")), 0.90):
		failures.append("Ugly Tooth should reduce enemy speed factor according to stacked slow")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	runtime_player.remove_upgrade(ugly_tooth)
	if not is_equal_approx(float(runtime_player.get("hit_enemy_slow_percent_per_hit")), before_per_hit):
		failures.append("Removing Ugly Tooth should restore hit slow per-hit value")
	if not is_equal_approx(float(runtime_player.get("hit_enemy_slow_percent_max")), before_max):
		failures.append("Removing Ugly Tooth should restore hit slow cap")

func _check_catalog_scared_sausage_burn_on_hit():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Scared Sausage check: " + str(errors))
		return
	var scared_sausage = _find_by_source_id(data.get_shop_pool(false), "scared_sausage")
	if scared_sausage.is_empty():
		failures.append("Runtime shop pool should include Scared Sausage burn-on-hit modifier")
		return
	if not _has_weapon_special_rule(scared_sausage.get("effects", []), "burn_on_hit"):
		failures.append("Scared Sausage shop entry should preserve burn-on-hit special rule")
		return
	if not _has_weapon_special_rule_chance(scared_sausage.get("effects", []), "burn_on_hit", 0.25):
		failures.append("Scared Sausage shop entry should preserve 25 percent burn-on-hit chance")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Scared Sausage burn-on-hit check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Scared Sausage burn-on-hit check")
		return
	if runtime_player.get("burn_on_hit_chance") == null:
		failures.append("Player should expose burn_on_hit_chance for Scared Sausage")
		return

	var before_chance = float(runtime_player.get("burn_on_hit_chance"))
	runtime_player.apply_upgrade(scared_sausage)
	if not is_equal_approx(float(runtime_player.get("burn_on_hit_chance")), before_chance + 0.25):
		failures.append("Applying Scared Sausage should add 25 percent burn-on-hit chance")

	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.max_hp = 20
	enemy.hp = 20
	enemy.position = runtime_player.position + Vector2(80, 0)
	runtime_player.burn_on_hit_chance = 1.0
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 1, false)
	bullet._on_body_entered(enemy)
	await process_frame
	if not (float(enemy.get("burn_timer")) > 0.0):
		failures.append("Guaranteed Scared Sausage should apply burn through the attack hit path")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	runtime_player.burn_on_hit_chance = before_chance + 0.25
	runtime_player.remove_upgrade(scared_sausage)
	if not is_equal_approx(float(runtime_player.get("burn_on_hit_chance")), before_chance):
		failures.append("Removing Scared Sausage should restore burn-on-hit chance")

func _check_catalog_burning_speed_and_elemental_weapon_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for burning speed/elemental weapon item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var eyes_surgery = _find_by_source_id(pool, "eyes_surgery")
	var frozen_heart = _find_by_source_id(pool, "frozen_heart")
	if eyes_surgery.is_empty():
		failures.append("Runtime shop pool should include Eyes Surgery burning speed modifier")
	if frozen_heart.is_empty():
		failures.append("Runtime shop pool should include Frozen Heart burning speed and elemental weapon modifier")
	if eyes_surgery.is_empty() or frozen_heart.is_empty():
		return
	if not _has_weapon_special_rule(eyes_surgery.get("effects", []), "burning_activates_20_percent_faster"):
		failures.append("Eyes Surgery should preserve burn-speed special rule")
	if not _has_weapon_special_rule(frozen_heart.get("effects", []), "burning_activates_100_percent_slower"):
		failures.append("Frozen Heart should preserve burn-slow special rule")
	if not _has_weapon_special_rule(frozen_heart.get("effects", []), "weapon_damage_scales_with_10_percent_elemental_damage"):
		failures.append("Frozen Heart should preserve elemental weapon damage special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for burning speed/elemental weapon item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for burning speed/elemental weapon item check")
		return
	for required_property in [
		"burn_tick_interval_percent_modifier",
		"elemental_weapon_damage_scaling_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for burning speed/elemental weapon items" % required_property)
			return

	runtime_player.elemental_damage_bonus = 0
	runtime_player.burn_tick_interval_percent_modifier = 0.0
	runtime_player.elemental_weapon_damage_scaling_sources = 0
	runtime_player.apply_upgrade(eyes_surgery)
	if not is_equal_approx(float(runtime_player.get("burn_tick_interval_percent_modifier")), -0.20):
		failures.append("Eyes Surgery should make burning activate 20 percent faster")
	runtime_player.apply_upgrade(frozen_heart)
	if int(runtime_player.elemental_damage_bonus) != 9:
		failures.append("Eyes Surgery and Frozen Heart should add 9 Elemental Damage total")
	if not is_equal_approx(float(runtime_player.get("burn_tick_interval_percent_modifier")), 0.80):
		failures.append("Frozen Heart should add a 100 percent burn slowdown modifier")
	if int(runtime_player.get("elemental_weapon_damage_scaling_sources")) != 1:
		failures.append("Frozen Heart should enable elemental weapon damage scaling")

	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.max_hp = 20
	enemy.hp = 20
	enemy.position = runtime_player.position + Vector2(80, 0)
	runtime_player.burn_on_hit_chance = 1.0
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 1, false)
	bullet._on_body_entered(enemy)
	if not is_equal_approx(float(enemy.get("burn_tick_interval")), 0.90):
		failures.append("Burning applied with Eyes Surgery and Frozen Heart should use the player's burn tick interval modifier")
	if int(enemy.hp) != 18:
		failures.append("Frozen Heart should add 10 percent Elemental Damage as weapon damage")
	enemy._physics_process(0.5)
	if int(enemy.hp) != 18:
		failures.append("Burning should not tick before the modified burn interval elapses")
	enemy._physics_process(0.4)
	if int(enemy.hp) != 17:
		failures.append("Burning should tick when the modified burn interval elapses")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	runtime_player.remove_upgrade(frozen_heart)
	if int(runtime_player.get("elemental_weapon_damage_scaling_sources")) != 0:
		failures.append("Removing Frozen Heart should disable elemental weapon damage scaling")
	if not is_equal_approx(float(runtime_player.get("burn_tick_interval_percent_modifier")), -0.20):
		failures.append("Removing Frozen Heart should leave Eyes Surgery burn-speed modifier")
	runtime_player.remove_upgrade(eyes_surgery)
	if not is_equal_approx(float(runtime_player.get("burn_tick_interval_percent_modifier")), 0.0):
		failures.append("Removing Eyes Surgery should restore burn-speed modifier")
	runtime_player.burn_on_hit_chance = 0.0

func _check_catalog_ice_cube_and_greek_fire_elemental_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Ice Cube/Greek Fire check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var ice_cube = _find_by_source_id(pool, "ice_cube")
	var greek_fire = _find_by_source_id(pool, "greek_fire")
	if ice_cube.is_empty():
		failures.append("Runtime shop pool should include Ice Cube elemental vulnerability item")
	if greek_fire.is_empty():
		failures.append("Runtime shop pool should include Greek Fire burn current-HP item")
	if ice_cube.is_empty() or greek_fire.is_empty():
		return
	if not _has_weapon_special_rule(ice_cube.get("effects", []), "enemies_take_10_percent_more_damage_for_3_seconds_on_first_elemental_hit"):
		failures.append("Ice Cube should preserve elemental-hit vulnerability special rule")
	if not _has_weapon_special_rule_number(greek_fire.get("effects", []), "burning_deals_current_enemy_hp_bonus_damage", "enemy_current_hp_percent", 0.10):
		failures.append("Greek Fire should preserve 10 percent current enemy HP burn bonus")
	if not _has_weapon_special_rule_number(greek_fire.get("effects", []), "burning_deals_current_enemy_hp_bonus_damage", "boss_elite_current_hp_percent", 0.01):
		failures.append("Greek Fire should preserve 1 percent boss/elite current HP burn bonus")
	if not _has_weapon_special_rule(greek_fire.get("effects", []), "nightmare_fog_visibility_percent_plus_75"):
		failures.append("Greek Fire should preserve +75 percent nightmare fog visibility")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Ice Cube/Greek Fire check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Ice Cube/Greek Fire check")
		return
	for required_property in [
		"elemental_vulnerability_sources",
		"burn_current_hp_bonus_sources",
		"burn_current_hp_bonus_enemy_percent",
		"burn_current_hp_bonus_boss_elite_percent",
		"nightmare_fog_visibility_percent",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Ice Cube/Greek Fire" % required_property)
			return
	if not runtime_player.has_method("on_enemy_elemental_hit"):
		failures.append("Player should expose on_enemy_elemental_hit for Ice Cube")
		return

	var before_vulnerability_sources = int(runtime_player.get("elemental_vulnerability_sources"))
	var before_burn_sources = int(runtime_player.get("burn_current_hp_bonus_sources"))
	var before_fog = float(runtime_player.get("nightmare_fog_visibility_percent"))
	runtime_player.apply_upgrade(ice_cube)
	runtime_player.apply_upgrade(greek_fire)
	if int(runtime_player.get("elemental_vulnerability_sources")) != before_vulnerability_sources + 1:
		failures.append("Applying Ice Cube should enable elemental-hit vulnerability")
	if int(runtime_player.get("burn_current_hp_bonus_sources")) != before_burn_sources + 1:
		failures.append("Applying Greek Fire should enable current-HP burn damage")
	if not is_equal_approx(float(runtime_player.get("burn_current_hp_bonus_enemy_percent")), 0.10):
		failures.append("Greek Fire should track 10 percent current enemy HP burn bonus")
	if not is_equal_approx(float(runtime_player.get("burn_current_hp_bonus_boss_elite_percent")), 0.01):
		failures.append("Greek Fire should track 1 percent boss/elite current HP burn bonus")
	if not is_equal_approx(float(runtime_player.get("nightmare_fog_visibility_percent")), before_fog + 0.75):
		failures.append("Greek Fire should add +75 percent nightmare fog visibility")

	_reset_enemy_pool(main)
	var vulnerable_enemy = main.get_enemy()
	vulnerable_enemy.setup("normal", main.wave)
	vulnerable_enemy.hp = 100
	vulnerable_enemy.max_hp = 100
	if vulnerable_enemy.get("damage_taken_percent_bonus") == null or not vulnerable_enemy.has_method("process_damage_taken_bonus"):
		failures.append("Enemy should expose timed damage-taken bonus for Ice Cube")
	else:
		runtime_player.on_enemy_elemental_hit(vulnerable_enemy)
		if not is_equal_approx(float(vulnerable_enemy.get("damage_taken_percent_bonus")), 0.10):
			failures.append("Ice Cube should apply +10 percent damage taken on first elemental hit")
		vulnerable_enemy.take_damage(10)
		if int(vulnerable_enemy.hp) != 89:
			failures.append("Ice Cube vulnerability should amplify subsequent damage for 3 seconds")
		vulnerable_enemy.process_damage_taken_bonus(3.1)
		vulnerable_enemy.take_damage(10)
		if int(vulnerable_enemy.hp) != 79:
			failures.append("Ice Cube vulnerability should expire after 3 seconds")

	_reset_enemy_pool(main)
	var burning_enemy = main.get_enemy()
	burning_enemy.setup("normal", main.wave)
	burning_enemy.hp = 100
	burning_enemy.max_hp = 100
	burning_enemy.apply_burn(runtime_player)
	burning_enemy.burn_tick = 0.0
	burning_enemy._physics_process(0.01)
	if int(burning_enemy.hp) != 89:
		failures.append("Greek Fire burn tick should add 10 percent current enemy HP damage to base burn damage")

	_reset_enemy_pool(main)
	runtime_player.remove_upgrade(greek_fire)
	runtime_player.remove_upgrade(ice_cube)
	if int(runtime_player.get("elemental_vulnerability_sources")) != before_vulnerability_sources:
		failures.append("Removing Ice Cube should restore elemental vulnerability source count")
	if int(runtime_player.get("burn_current_hp_bonus_sources")) != before_burn_sources:
		failures.append("Removing Greek Fire should restore burn current-HP source count")
	if not is_equal_approx(float(runtime_player.get("nightmare_fog_visibility_percent")), before_fog):
		failures.append("Removing Greek Fire should restore nightmare fog visibility")

func _check_catalog_snake_burn_spread():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Snake check: " + str(errors))
		return
	var snake = _find_by_source_id(data.get_shop_pool(false), "snake")
	if snake.is_empty():
		failures.append("Runtime shop pool should include Snake burn-spread modifier")
		return
	if not _has_weapon_special_rule(snake.get("effects", []), "burn_spread"):
		failures.append("Snake shop entry should preserve burn-spread special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Snake burn-spread check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Snake burn-spread check")
		return
	if runtime_player.get("burn_spread_sources") == null:
		failures.append("Player should expose burn_spread_sources for Snake")
		return

	var before_sources = int(runtime_player.get("burn_spread_sources"))
	runtime_player.apply_upgrade(snake)
	if int(runtime_player.get("burn_spread_sources")) != before_sources + 1:
		failures.append("Applying Snake should enable one burn-spread source")

	_reset_enemy_pool(main)
	var burned_enemy = main.get_enemy()
	burned_enemy.setup("normal", 1)
	burned_enemy.max_hp = 20
	burned_enemy.hp = 20
	burned_enemy.position = runtime_player.position + Vector2(80, 0)
	var spread_enemy = main.get_enemy()
	spread_enemy.setup("normal", 1)
	spread_enemy.max_hp = 20
	spread_enemy.hp = 20
	spread_enemy.position = burned_enemy.position + Vector2(120, 0)
	runtime_player.burn_on_hit_chance = 1.0
	runtime_player.burn_spread_sources = before_sources + 1
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 1, false)
	bullet._on_body_entered(burned_enemy)
	await process_frame
	if not (float(burned_enemy.get("burn_timer")) > 0.0):
		failures.append("Guaranteed Scared Sausage should burn the first enemy before Snake spreads")
	if not (float(spread_enemy.get("burn_timer")) > 0.0):
		failures.append("Snake should spread burn to a nearby enemy")
	if is_instance_valid(burned_enemy):
		main.recycle_enemy(burned_enemy)
	if is_instance_valid(spread_enemy):
		main.recycle_enemy(spread_enemy)

	runtime_player.burn_spread_sources = before_sources + 1
	runtime_player.remove_upgrade(snake)
	if int(runtime_player.get("burn_spread_sources")) != before_sources:
		failures.append("Removing Snake should restore burn-spread sources")

func _check_catalog_adrenaline_dodge_heal():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Adrenaline check: " + str(errors))
		return
	var adrenaline = _find_by_source_id(data.get_shop_pool(false), "adrenaline")
	if adrenaline.is_empty():
		failures.append("Runtime shop pool should include Adrenaline dodge-heal modifier")
		return
	if not _has_weapon_special_rule(adrenaline.get("effects", []), "heal_5_hp_on_dodge_chance_50_percent"):
		failures.append("Adrenaline shop entry should preserve dodge-heal special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Adrenaline dodge-heal check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Adrenaline dodge-heal check")
		return
	if runtime_player.get("dodge_heal_chance") == null:
		failures.append("Player should expose dodge_heal_chance for Adrenaline")
		return
	if runtime_player.get("dodge_heal_amount") == null:
		failures.append("Player should expose dodge_heal_amount for Adrenaline")
		return

	var before_dodge = float(runtime_player.dodge_chance)
	var before_heal_chance = float(runtime_player.get("dodge_heal_chance"))
	var before_heal_amount = int(runtime_player.get("dodge_heal_amount"))
	runtime_player.apply_upgrade(adrenaline)
	if not is_equal_approx(float(runtime_player.dodge_chance), before_dodge + 0.05):
		failures.append("Applying Adrenaline should add 5 percent dodge")
	if not is_equal_approx(float(runtime_player.get("dodge_heal_chance")), before_heal_chance + 0.50):
		failures.append("Applying Adrenaline should add 50 percent dodge-heal chance")
	if int(runtime_player.get("dodge_heal_amount")) != before_heal_amount + 5:
		failures.append("Applying Adrenaline should add 5 HP dodge-heal amount")

	runtime_player.max_hp = 10
	runtime_player.hp = 3
	runtime_player.invincible_timer = 0.0
	runtime_player.dodge_chance = 1.0
	runtime_player.dodge_heal_chance = 1.0
	runtime_player.dodge_heal_amount = 5
	runtime_player.take_damage(4)
	if int(runtime_player.hp) != 8:
		failures.append("Guaranteed Adrenaline dodge-heal should heal 5 HP while dodging damage")

	runtime_player.dodge_chance = before_dodge + 0.05
	runtime_player.dodge_heal_chance = before_heal_chance + 0.50
	runtime_player.dodge_heal_amount = before_heal_amount + 5
	runtime_player.remove_upgrade(adrenaline)
	if not is_equal_approx(float(runtime_player.dodge_chance), before_dodge):
		failures.append("Removing Adrenaline should restore dodge")
	if not is_equal_approx(float(runtime_player.get("dodge_heal_chance")), before_heal_chance):
		failures.append("Removing Adrenaline should restore dodge-heal chance")
	if int(runtime_player.get("dodge_heal_amount")) != before_heal_amount:
		failures.append("Removing Adrenaline should restore dodge-heal amount")

func _check_catalog_riposte_dodge_damage():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Riposte check: " + str(errors))
		return
	var riposte = _find_by_source_id(data.get_shop_pool(false), "riposte")
	if riposte.is_empty():
		failures.append("Runtime shop pool should include Riposte dodge-damage modifier")
		return
	if not _has_weapon_special_rule(riposte.get("effects", []), "deal_melee_damage_on_dodge"):
		failures.append("Riposte shop entry should preserve dodge-damage special rule")
		return
	if not _has_weapon_special_rule_chance(riposte.get("effects", []), "deal_melee_damage_on_dodge", 1.0):
		failures.append("Riposte shop entry should preserve guaranteed dodge-damage chance")
	if not _has_stat_delta(riposte.get("effects", []), "melee_damage", 2.0):
		failures.append("Riposte shop entry should preserve melee damage bonus")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Riposte dodge-damage check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Riposte dodge-damage check")
		return
	if runtime_player.get("dodge_damage_chance") == null:
		failures.append("Player should expose dodge_damage_chance for Riposte")
		return
	if runtime_player.get("dodge_damage_base") == null:
		failures.append("Player should expose dodge_damage_base for Riposte")
		return
	if runtime_player.get("dodge_damage_melee_coefficient") == null:
		failures.append("Player should expose dodge_damage_melee_coefficient for Riposte")
		return

	var before_melee = int(runtime_player.melee_damage_bonus)
	var before_chance = float(runtime_player.get("dodge_damage_chance"))
	var before_base = float(runtime_player.get("dodge_damage_base"))
	var before_coefficient = float(runtime_player.get("dodge_damage_melee_coefficient"))
	runtime_player.apply_upgrade(riposte)
	if int(runtime_player.melee_damage_bonus) != before_melee + 2:
		failures.append("Applying Riposte should add 2 melee damage")
	if not is_equal_approx(float(runtime_player.get("dodge_damage_chance")), before_chance + 1.0):
		failures.append("Applying Riposte should add guaranteed dodge-damage chance")
	if not is_equal_approx(float(runtime_player.get("dodge_damage_base")), before_base + 1.0):
		failures.append("Applying Riposte should add dodge-damage base")
	if not is_equal_approx(float(runtime_player.get("dodge_damage_melee_coefficient")), before_coefficient + 3.0):
		failures.append("Applying Riposte should add melee damage scaling")

	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.max_hp = 20
	enemy.hp = 20
	enemy.position = runtime_player.position + Vector2(80, 0)
	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.invincible_timer = 0.0
	runtime_player.dodge_chance = 1.0
	runtime_player.dodge_heal_chance = 0.0
	runtime_player.dodge_damage_chance = 1.0
	runtime_player.dodge_damage_base = 1.0
	runtime_player.dodge_damage_melee_coefficient = 3.0
	runtime_player.melee_damage_bonus = 4
	runtime_player.take_damage(4)
	if int(runtime_player.hp) != 20:
		failures.append("Guaranteed Riposte dodge should avoid incoming damage")
	if int(enemy.hp) != 7:
		failures.append("Guaranteed Riposte should deal 1 plus 300 percent melee damage on dodge")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	runtime_player.melee_damage_bonus = before_melee + 2
	runtime_player.dodge_damage_chance = before_chance + 1.0
	runtime_player.dodge_damage_base = before_base + 1.0
	runtime_player.dodge_damage_melee_coefficient = before_coefficient + 3.0
	runtime_player.remove_upgrade(riposte)
	if int(runtime_player.melee_damage_bonus) != before_melee:
		failures.append("Removing Riposte should restore melee damage")
	if not is_equal_approx(float(runtime_player.get("dodge_damage_chance")), before_chance):
		failures.append("Removing Riposte should restore dodge-damage chance")
	if not is_equal_approx(float(runtime_player.get("dodge_damage_base")), before_base):
		failures.append("Removing Riposte should restore dodge-damage base")
	if not is_equal_approx(float(runtime_player.get("dodge_damage_melee_coefficient")), before_coefficient):
		failures.append("Removing Riposte should restore melee damage scaling")

func _check_catalog_regeneration_potion_low_health_regen():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Regeneration Potion check: " + str(errors))
		return
	var regeneration_potion = _find_by_source_id(data.get_shop_pool(false), "regeneration_potion")
	if regeneration_potion.is_empty():
		failures.append("Runtime shop pool should include Regeneration Potion low-health regen modifier")
		return
	if not _has_weapon_special_rule(regeneration_potion.get("effects", []), "hp_regeneration_doubled_below_50_percent_health"):
		failures.append("Regeneration Potion shop entry should preserve low-health regen double special rule")
	if not _has_stat_delta(regeneration_potion.get("effects", []), "hp_regeneration", 3.0):
		failures.append("Regeneration Potion shop entry should preserve HP regeneration bonus")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Regeneration Potion low-health regen check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Regeneration Potion low-health regen check")
		return
	if runtime_player.get("low_health_regen_double_sources") == null:
		failures.append("Player should expose low_health_regen_double_sources for Regeneration Potion")
		return

	var before_regen = int(runtime_player.hp_regen)
	var before_sources = int(runtime_player.get("low_health_regen_double_sources"))
	runtime_player.apply_upgrade(regeneration_potion)
	if int(runtime_player.hp_regen) != before_regen + 3:
		failures.append("Applying Regeneration Potion should add 3 HP regeneration")
	if int(runtime_player.get("low_health_regen_double_sources")) != before_sources + 1:
		failures.append("Applying Regeneration Potion should enable low-health regen doubling")

	runtime_player.max_hp = 10
	runtime_player.hp = 6
	runtime_player.wave_regen()
	if int(runtime_player.hp) != 9:
		failures.append("Regeneration Potion should not double regen above 50 percent health")
	runtime_player.hp = 4
	runtime_player.wave_regen()
	if int(runtime_player.hp) != 10:
		failures.append("Regeneration Potion should double regen below 50 percent health")

	runtime_player.hp_regen = before_regen + 3
	runtime_player.low_health_regen_double_sources = before_sources + 1
	runtime_player.remove_upgrade(regeneration_potion)
	if int(runtime_player.hp_regen) != before_regen:
		failures.append("Removing Regeneration Potion should restore HP regeneration")
	if int(runtime_player.get("low_health_regen_double_sources")) != before_sources:
		failures.append("Removing Regeneration Potion should clear low-health regen doubling")

func _check_catalog_torture_fixed_healing():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Torture check: " + str(errors))
		return
	var torture = _find_by_source_id(data.get_shop_pool(false), "torture")
	if torture.is_empty():
		failures.append("Runtime shop pool should include Torture fixed healing modifier")
		return
	if not _has_stat_delta(torture.get("effects", []), "max_hp", 15.0):
		failures.append("Torture should preserve Max HP bonus")
	if not _has_weapon_special_rule(torture.get("effects", []), "restore_5_hp_per_second_cannot_heal_other_way"):
		failures.append("Torture should preserve fixed-healing lockout rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Torture fixed healing check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Torture fixed healing check")
		return
	for required_property in [
		"torture_healing_sources",
		"torture_heal_timer",
		"torture_heal_per_second",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Torture" % required_property)
			return
	if not runtime_player.has_method("process_torture_healing"):
		failures.append("Player should expose process_torture_healing for Torture")
		return

	var before_max_hp = int(runtime_player.max_hp)
	runtime_player.apply_upgrade(torture)
	if int(runtime_player.max_hp) != before_max_hp + 15:
		failures.append("Applying Torture should add 15 Max HP")
	if int(runtime_player.get("torture_healing_sources")) != 1:
		failures.append("Applying Torture should enable fixed healing")
	if int(runtime_player.get("torture_heal_per_second")) != 5:
		failures.append("Torture should restore 5 HP per second")

	runtime_player.hp = 1
	runtime_player.heal(10)
	if int(runtime_player.hp) != 1:
		failures.append("Torture should block regular Player.heal")
	runtime_player.core.heal(10)
	if int(runtime_player.hp) != 1:
		failures.append("Torture should block direct PlayerCore.heal")
	runtime_player.process_torture_healing(0.9)
	if int(runtime_player.hp) != 1:
		failures.append("Torture should not heal before one full second")
	runtime_player.process_torture_healing(0.1)
	if int(runtime_player.hp) != 6:
		failures.append("Torture should restore 5 HP after one second")
	runtime_player.process_torture_healing(2.0)
	if int(runtime_player.hp) != min(runtime_player.max_hp, 16):
		failures.append("Torture should restore 5 HP per elapsed second")

	runtime_player.remove_upgrade(torture)
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Removing Torture should restore Max HP")
	if int(runtime_player.get("torture_healing_sources")) != 0:
		failures.append("Removing Torture should clear fixed-healing sources")
	if not is_equal_approx(float(runtime_player.get("torture_heal_timer")), 0.0):
		failures.append("Removing Torture should clear fixed-healing timer")
	runtime_player.hp = 1
	runtime_player.heal(3)
	if int(runtime_player.hp) != 4:
		failures.append("Removing Torture should restore regular healing")

func _check_catalog_ghost_outfit_dodge_cap():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Ghost Outfit check: " + str(errors))
		return
	var ghost_outfit = _find_by_source_id(data.get_shop_pool(false), "ghost_outfit")
	if ghost_outfit.is_empty():
		failures.append("Runtime shop pool should include Ghost Outfit dodge-cap modifier")
		return
	if not _has_weapon_special_rule(ghost_outfit.get("effects", []), "dodge_cap_70_percent"):
		failures.append("Ghost Outfit shop entry should preserve dodge-cap special rule")
		return
	if not _has_stat_delta(ghost_outfit.get("effects", []), "dodge", 0.10):
		failures.append("Ghost Outfit shop entry should preserve dodge bonus")
	if not _has_stat_delta(ghost_outfit.get("effects", []), "speed_percent", -0.05):
		failures.append("Ghost Outfit shop entry should preserve speed penalty")
	if not _has_stat_delta(ghost_outfit.get("effects", []), "armor", -3.0):
		failures.append("Ghost Outfit shop entry should preserve armor penalty")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Ghost Outfit dodge-cap check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Ghost Outfit dodge-cap check")
		return
	if runtime_player.get("dodge_cap") == null:
		failures.append("Player should expose dodge_cap for Ghost Outfit")
		return

	runtime_player.dodge_chance = 0.50
	var before_dodge = float(runtime_player.dodge_chance)
	var before_cap = float(runtime_player.get("dodge_cap"))
	var before_speed = float(runtime_player.speed)
	var before_base_speed = float(runtime_player.base_speed)
	var before_armor = int(runtime_player.armor)
	runtime_player.apply_upgrade(ghost_outfit)
	if not is_equal_approx(float(runtime_player.get("dodge_cap")), 0.70):
		failures.append("Applying Ghost Outfit should lower dodge cap to 70 percent")
	if not is_equal_approx(float(runtime_player.dodge_chance), before_dodge + 0.10):
		failures.append("Applying Ghost Outfit should add 10 percent dodge under the cap")
	if not is_equal_approx(float(runtime_player.speed), before_speed - 15.0):
		failures.append("Applying Ghost Outfit should apply its 5 percent speed penalty")
	if not is_equal_approx(float(runtime_player.base_speed), before_base_speed - 15.0):
		failures.append("Applying Ghost Outfit should apply its base speed penalty")
	if int(runtime_player.armor) != before_armor - 3:
		failures.append("Applying Ghost Outfit should apply its armor penalty")

	var synthetic_dodge = {
		"type": "catalog_item",
		"effects": [
			{"effect": "stat_delta", "stat": "dodge", "value": 0.10}
		]
	}
	runtime_player.dodge_chance = 0.69
	runtime_player.apply_upgrade(synthetic_dodge)
	if not is_equal_approx(float(runtime_player.dodge_chance), 0.70):
		failures.append("Ghost Outfit should cap later dodge gains at 70 percent")
	runtime_player.remove_upgrade(synthetic_dodge)

	runtime_player.dodge_chance = before_dodge + 0.10
	runtime_player.remove_upgrade(ghost_outfit)
	if not is_equal_approx(float(runtime_player.get("dodge_cap")), before_cap):
		failures.append("Removing Ghost Outfit should restore dodge cap")
	if not is_equal_approx(float(runtime_player.dodge_chance), before_dodge):
		failures.append("Removing Ghost Outfit should restore dodge")
	if not is_equal_approx(float(runtime_player.speed), before_speed):
		failures.append("Removing Ghost Outfit should restore speed")
	if not is_equal_approx(float(runtime_player.base_speed), before_base_speed):
		failures.append("Removing Ghost Outfit should restore base speed")
	if int(runtime_player.armor) != before_armor:
		failures.append("Removing Ghost Outfit should restore armor")

func _check_catalog_tardigrade_hit_nullify():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Tardigrade check: " + str(errors))
		return
	var tardigrade = _find_by_source_id(data.get_shop_pool(false), "tardigrade")
	if tardigrade.is_empty():
		failures.append("Runtime shop pool should include Tardigrade hit-nullify modifier")
		return
	if not _has_weapon_special_rule(tardigrade.get("effects", []), "nullify_one_hit_taken_per_wave"):
		failures.append("Tardigrade shop entry should preserve hit-nullify special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Tardigrade hit-nullify check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Tardigrade hit-nullify check")
		return
	if runtime_player.get("nullify_hits_per_wave") == null:
		failures.append("Player should expose nullify_hits_per_wave for Tardigrade")
		return
	if runtime_player.get("nullify_hits_remaining") == null:
		failures.append("Player should expose nullify_hits_remaining for Tardigrade")
		return

	var before_per_wave = int(runtime_player.get("nullify_hits_per_wave"))
	var before_remaining = int(runtime_player.get("nullify_hits_remaining"))
	runtime_player.apply_upgrade(tardigrade)
	if int(runtime_player.get("nullify_hits_per_wave")) != before_per_wave + 1:
		failures.append("Applying Tardigrade should add one hit nullification per wave")
	if int(runtime_player.get("nullify_hits_remaining")) != before_remaining + 1:
		failures.append("Applying Tardigrade should make one hit nullification immediately available")

	runtime_player.max_hp = 10
	runtime_player.hp = 10
	runtime_player.armor = 0
	runtime_player.shield = 0
	runtime_player.invincible_timer = 0.0
	runtime_player.dodge_chance = 0.0
	runtime_player.ghost_dodge_chance = 0.0
	runtime_player.nullify_hits_remaining = 1
	runtime_player.take_damage(4)
	if int(runtime_player.hp) != 10:
		failures.append("Tardigrade should nullify the next incoming hit without HP loss")
	if int(runtime_player.get("nullify_hits_remaining")) != 0:
		failures.append("Tardigrade nullification should be consumed after blocking a hit")

	runtime_player.invincible_timer = 0.0
	runtime_player.take_damage(4)
	if int(runtime_player.hp) != 6:
		failures.append("After Tardigrade is consumed, the next hit should deal normal damage")

	runtime_player.on_wave_start()
	if int(runtime_player.get("nullify_hits_remaining")) != int(runtime_player.get("nullify_hits_per_wave")):
		failures.append("Tardigrade hit nullification should reset at wave start")

	runtime_player.invincible_timer = 0.0
	runtime_player.remove_upgrade(tardigrade)
	if int(runtime_player.get("nullify_hits_per_wave")) != before_per_wave:
		failures.append("Removing Tardigrade should restore per-wave hit nullification")
	if int(runtime_player.get("nullify_hits_remaining")) != before_remaining:
		failures.append("Removing Tardigrade should restore remaining hit nullification")

func _check_catalog_sad_tomato_wave_start_hp():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Sad Tomato check: " + str(errors))
		return
	var sad_tomato = _find_by_source_id(data.get_shop_pool(false), "sad_tomato")
	if sad_tomato.is_empty():
		failures.append("Runtime shop pool should include Sad Tomato wave-start HP modifier")
		return
	if not _has_stat_delta(sad_tomato.get("effects", []), "hp_regeneration", 8.0):
		failures.append("Sad Tomato shop entry should preserve HP regeneration bonus")
	if not _has_weapon_special_rule(sad_tomato.get("effects", []), "start_wave_with_hp_percent_delta"):
		failures.append("Sad Tomato shop entry should preserve wave-start HP special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Sad Tomato wave-start HP check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Sad Tomato wave-start HP check")
		return
	if runtime_player.get("wave_start_hp_percent_delta") == null:
		failures.append("Player should expose wave_start_hp_percent_delta for Sad Tomato")
		return

	var before_regen = int(runtime_player.hp_regen)
	var before_delta = float(runtime_player.get("wave_start_hp_percent_delta"))
	runtime_player.apply_upgrade(sad_tomato)
	if int(runtime_player.hp_regen) != before_regen + 8:
		failures.append("Applying Sad Tomato should add 8 HP regeneration")
	if not is_equal_approx(float(runtime_player.get("wave_start_hp_percent_delta")), before_delta - 0.50):
		failures.append("Applying Sad Tomato should add the -50 percent wave-start HP modifier")

	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.on_wave_start()
	if int(runtime_player.hp) != 10:
		failures.append("Sad Tomato should start the wave at 50 percent HP")

	runtime_player.remove_upgrade(sad_tomato)
	if int(runtime_player.hp_regen) != before_regen:
		failures.append("Removing Sad Tomato should restore HP regeneration")
	if not is_equal_approx(float(runtime_player.get("wave_start_hp_percent_delta")), before_delta):
		failures.append("Removing Sad Tomato should restore wave-start HP modifier")

func _check_catalog_weird_ghost_wave_start_one_hp():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Weird Ghost check: " + str(errors))
		return
	var weird_ghost = _find_by_source_id(data.get_shop_pool(false), "weird_ghost")
	if weird_ghost.is_empty():
		failures.append("Runtime shop pool should include Weird Ghost wave-start 1 HP modifier")
		return
	if not _has_stat_delta(weird_ghost.get("effects", []), "max_hp", 3.0):
		failures.append("Weird Ghost shop entry should preserve Max HP bonus")
	if not _has_weapon_special_rule(weird_ghost.get("effects", []), "start_next_wave_with_1_hp"):
		failures.append("Weird Ghost shop entry should preserve wave-start 1 HP special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Weird Ghost wave-start HP check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Weird Ghost check")
		return
	if runtime_player.get("start_next_wave_with_one_hp_sources") == null:
		failures.append("Player should expose start_next_wave_with_one_hp_sources for Weird Ghost")
		return

	var before_max_hp = int(runtime_player.max_hp)
	var before_hp = int(runtime_player.hp)
	var before_sources = int(runtime_player.get("start_next_wave_with_one_hp_sources"))
	runtime_player.apply_upgrade(weird_ghost)
	if int(runtime_player.max_hp) != before_max_hp + 3:
		failures.append("Applying Weird Ghost should add 3 Max HP")
	if int(runtime_player.hp) != before_hp + 3:
		failures.append("Applying Weird Ghost Max HP should heal by 3 for runtime compatibility")
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_sources + 1:
		failures.append("Applying Weird Ghost should enable one wave-start 1 HP source")

	runtime_player.hp = runtime_player.max_hp
	runtime_player.on_wave_start()
	if int(runtime_player.hp) != 1:
		failures.append("Weird Ghost should start the next wave with 1 HP")
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_sources:
		failures.append("Weird Ghost should consume its next-wave 1 HP source after triggering")

	runtime_player.remove_upgrade(weird_ghost)
	if int(runtime_player.max_hp) != before_max_hp:
		failures.append("Removing Weird Ghost should restore Max HP")
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_sources:
		failures.append("Removing Weird Ghost should disable wave-start 1 HP source")
	runtime_player.hp = runtime_player.max_hp
	runtime_player.on_wave_start()
	if int(runtime_player.hp) != int(runtime_player.max_hp):
		failures.append("Removing Weird Ghost should stop forcing wave-start HP to 1")

func _check_catalog_restrictive_start_wave_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for restrictive/start-wave item check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var broken_hourglass = _find_by_source_id(pool, "broken_hourglass")
	var handcuffs = _find_by_source_id(pool, "handcuffs")
	var shackles = _find_by_source_id(pool, "shackles")
	var piggy_bank = _find_by_source_id(pool, "piggy_bank")
	var acid = _find_by_source_id(pool, "acid")
	var beanie = _find_by_source_id(pool, "beanie")
	var broken_mouth = _find_by_source_id(pool, "broken_mouth")
	var compass = _find_by_source_id(pool, "compass")
	if broken_hourglass.is_empty():
		failures.append("Runtime shop pool should include Broken Hourglass wave-start 1 HP modifier")
	if handcuffs.is_empty():
		failures.append("Runtime shop pool should include Handcuffs Max HP cap modifier")
	if shackles.is_empty():
		failures.append("Runtime shop pool should include Shackles Speed cap modifier")
	if piggy_bank.is_empty():
		failures.append("Runtime shop pool should include Piggy Bank start-wave material growth modifier")
	if acid.is_empty():
		failures.append("Runtime shop pool should include Acid for Handcuffs cap check")
	if beanie.is_empty():
		failures.append("Runtime shop pool should include Beanie for Shackles cap check")
	if broken_mouth.is_empty():
		failures.append("Runtime shop pool should include Broken Mouth for pre-Handcuffs Max HP removal check")
	if compass.is_empty():
		failures.append("Runtime shop pool should include Compass for pre-Shackles Speed removal check")
	if broken_hourglass.is_empty() or handcuffs.is_empty() or shackles.is_empty() or piggy_bank.is_empty() or acid.is_empty() or beanie.is_empty() or broken_mouth.is_empty() or compass.is_empty():
		return
	if not _has_weapon_special_rule(broken_hourglass.get("effects", []), "broken_hourglass_start_next_wave_with_1_hp"):
		failures.append("Broken Hourglass shop entry should preserve wave-start 1 HP special rule")
	if not _has_weapon_special_rule(handcuffs.get("effects", []), "max_hp_capped_at_current_value"):
		failures.append("Handcuffs shop entry should preserve Max HP cap special rule")
	if not _has_weapon_special_rule(shackles.get("effects", []), "speed_capped_at_current_value"):
		failures.append("Shackles shop entry should preserve Speed cap special rule")
	if not _has_weapon_special_rule(piggy_bank.get("effects", []), "materials_plus_20_percent_start_wave_until_wave_20"):
		failures.append("Piggy Bank shop entry should preserve start-wave material growth special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for restrictive/start-wave item check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for restrictive/start-wave item check")
		return
	if main.economy == null:
		failures.append("Main scene should expose RunEconomy for Piggy Bank check")
		return
	for required_property in [
		"max_hp_cap_sources",
		"max_hp_cap_value",
		"speed_cap_sources",
		"speed_cap_value",
		"piggy_bank_sources",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for restrictive/start-wave items" % required_property)
			return

	var before_one_hp_sources = int(runtime_player.get("start_next_wave_with_one_hp_sources"))
	runtime_player.apply_upgrade(broken_hourglass)
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_one_hp_sources + 1:
		failures.append("Applying Broken Hourglass should enable one wave-start 1 HP source")
	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.on_wave_start(7)
	if int(runtime_player.hp) != 1:
		failures.append("Broken Hourglass should start the next wave with 1 HP")
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_one_hp_sources:
		failures.append("Broken Hourglass should consume its next-wave 1 HP source after triggering")
	runtime_player.remove_upgrade(broken_hourglass)
	if int(runtime_player.get("start_next_wave_with_one_hp_sources")) != before_one_hp_sources:
		failures.append("Removing consumed Broken Hourglass should not underflow wave-start 1 HP sources")

	runtime_player.max_hp = 20
	runtime_player.hp = 20
	var before_melee = int(runtime_player.melee_damage_bonus)
	var before_ranged = int(runtime_player.ranged_damage_bonus)
	var before_elemental = int(runtime_player.elemental_damage_bonus)
	var before_dodge = float(runtime_player.dodge_chance)
	runtime_player.apply_upgrade(handcuffs)
	if int(runtime_player.melee_damage_bonus) != before_melee + 8:
		failures.append("Applying Handcuffs should add 8 Melee Damage")
	if int(runtime_player.ranged_damage_bonus) != before_ranged + 8:
		failures.append("Applying Handcuffs should add 8 Ranged Damage")
	if int(runtime_player.elemental_damage_bonus) != before_elemental + 8:
		failures.append("Applying Handcuffs should add 8 Elemental Damage")
	if int(runtime_player.get("max_hp_cap_sources")) != 1:
		failures.append("Applying Handcuffs should enable one Max HP cap source")
	if int(runtime_player.get("max_hp_cap_value")) != 20:
		failures.append("Handcuffs should cap Max HP at the current value")
	runtime_player.apply_upgrade(acid)
	if int(runtime_player.max_hp) != 20:
		failures.append("Handcuffs should prevent later positive Max HP gains")
	if int(runtime_player.hp) != 20:
		failures.append("Handcuffs should keep current HP within the capped Max HP")
	if not is_equal_approx(float(runtime_player.dodge_chance), before_dodge - 0.02):
		failures.append("Acid should still apply non-Max HP stats while Handcuffs caps Max HP")
	runtime_player.remove_upgrade(acid)
	if int(runtime_player.max_hp) != 20:
		failures.append("Removing a Max HP item suppressed by Handcuffs should not subtract Max HP")
	if not is_equal_approx(float(runtime_player.dodge_chance), before_dodge):
		failures.append("Removing Acid should restore dodge while Handcuffs remains active")
	runtime_player.remove_upgrade(handcuffs)
	if int(runtime_player.get("max_hp_cap_sources")) != 0:
		failures.append("Removing Handcuffs should disable the Max HP cap")
	if int(runtime_player.get("max_hp_cap_value")) != 0:
		failures.append("Removing Handcuffs should clear the Max HP cap value")
	if int(runtime_player.melee_damage_bonus) != before_melee:
		failures.append("Removing Handcuffs should restore Melee Damage")
	if int(runtime_player.ranged_damage_bonus) != before_ranged:
		failures.append("Removing Handcuffs should restore Ranged Damage")
	if int(runtime_player.elemental_damage_bonus) != before_elemental:
		failures.append("Removing Handcuffs should restore Elemental Damage")
	runtime_player.apply_upgrade(acid)
	if int(runtime_player.max_hp) != 28:
		failures.append("Positive Max HP items should work after Handcuffs is removed")
	runtime_player.remove_upgrade(acid)

	runtime_player.max_hp = 20
	runtime_player.hp = 20
	runtime_player.apply_upgrade(broken_mouth)
	runtime_player.apply_upgrade(handcuffs)
	runtime_player.apply_upgrade(acid)
	runtime_player.remove_upgrade(broken_mouth)
	if int(runtime_player.max_hp) != 20:
		failures.append("Removing a pre-Handcuffs Max HP item should not consume another item's suppressed Max HP")
	runtime_player.remove_upgrade(acid)
	runtime_player.remove_upgrade(handcuffs)

	runtime_player.speed = 300.0
	runtime_player.base_speed = 300.0
	var before_hp_regen = int(runtime_player.hp_regen)
	var before_engineering = int(runtime_player.engineering_bonus)
	var before_range = float(runtime_player.range_bonus)
	runtime_player.apply_upgrade(shackles)
	if int(runtime_player.hp_regen) != before_hp_regen + 8:
		failures.append("Applying Shackles should add 8 HP Regeneration")
	if int(runtime_player.engineering_bonus) != before_engineering + 8:
		failures.append("Applying Shackles should add 8 Engineering")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range + 80.0):
		failures.append("Applying Shackles should add 80 Range")
	if int(runtime_player.get("speed_cap_sources")) != 1:
		failures.append("Applying Shackles should enable one Speed cap source")
	if not is_equal_approx(float(runtime_player.get("speed_cap_value")), 300.0):
		failures.append("Shackles should cap Speed at the current value")
	runtime_player.apply_upgrade(beanie)
	if not is_equal_approx(float(runtime_player.base_speed), 300.0):
		failures.append("Shackles should prevent later positive Speed gains")
	if not is_equal_approx(float(runtime_player.speed), 300.0):
		failures.append("Shackles should keep runtime Speed at the capped value")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range + 74.0):
		failures.append("Beanie should still apply non-Speed stats while Shackles caps Speed")
	runtime_player.remove_upgrade(beanie)
	if not is_equal_approx(float(runtime_player.base_speed), 300.0):
		failures.append("Removing a Speed item suppressed by Shackles should not subtract Speed")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range + 80.0):
		failures.append("Removing Beanie should restore Range while Shackles remains active")
	runtime_player.remove_upgrade(shackles)
	if int(runtime_player.get("speed_cap_sources")) != 0:
		failures.append("Removing Shackles should disable the Speed cap")
	if not is_equal_approx(float(runtime_player.get("speed_cap_value")), 0.0):
		failures.append("Removing Shackles should clear the Speed cap value")
	if int(runtime_player.hp_regen) != before_hp_regen:
		failures.append("Removing Shackles should restore HP Regeneration")
	if int(runtime_player.engineering_bonus) != before_engineering:
		failures.append("Removing Shackles should restore Engineering")
	if not is_equal_approx(float(runtime_player.range_bonus), before_range):
		failures.append("Removing Shackles should restore Range")
	runtime_player.apply_upgrade(beanie)
	if not is_equal_approx(float(runtime_player.base_speed), 312.0):
		failures.append("Positive Speed items should work after Shackles is removed")
	runtime_player.remove_upgrade(beanie)

	runtime_player.speed = 300.0
	runtime_player.base_speed = 300.0
	runtime_player.apply_upgrade(compass)
	runtime_player.apply_upgrade(shackles)
	runtime_player.apply_upgrade(beanie)
	runtime_player.remove_upgrade(compass)
	if not is_equal_approx(float(runtime_player.base_speed), 300.0):
		failures.append("Removing a pre-Shackles Speed item should not consume another item's suppressed Speed")
	runtime_player.remove_upgrade(beanie)
	runtime_player.remove_upgrade(shackles)

	main.economy.reset(100)
	runtime_player.gold = 100
	var before_piggy_sources = int(runtime_player.get("piggy_bank_sources"))
	runtime_player.apply_upgrade(piggy_bank)
	if int(runtime_player.get("piggy_bank_sources")) != before_piggy_sources + 1:
		failures.append("Applying Piggy Bank should enable one start-wave material growth source")
	runtime_player.on_wave_start(1)
	if main.economy.materials != 120 or runtime_player.gold != 120:
		failures.append("Piggy Bank should add 20 percent materials at wave start before wave 20")
	runtime_player.on_wave_start(20)
	if main.economy.materials != 144 or runtime_player.gold != 144:
		failures.append("Piggy Bank should still add 20 percent materials at wave 20")
	runtime_player.on_wave_start(21)
	if main.economy.materials != 144 or runtime_player.gold != 144:
		failures.append("Piggy Bank should stop adding start-wave materials after wave 20")
	runtime_player.remove_upgrade(piggy_bank)
	if int(runtime_player.get("piggy_bank_sources")) != before_piggy_sources:
		failures.append("Removing Piggy Bank should disable start-wave material growth")
	runtime_player.on_wave_start(10)
	if main.economy.materials != 144 or runtime_player.gold != 144:
		failures.append("Removed Piggy Bank should not add start-wave materials")

func _check_catalog_tentacle_crit_kill_heal():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Tentacle check: " + str(errors))
		return
	var tentacle = _find_by_source_id(data.get_shop_pool(false), "tentacle")
	if tentacle.is_empty():
		failures.append("Runtime shop pool should include Tentacle critical-kill heal modifier")
		return
	if not _has_weapon_special_rule(tentacle.get("effects", []), "crit_kill_chance_to_heal_1_hp"):
		failures.append("Tentacle shop entry should preserve critical-kill heal special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Tentacle critical-kill heal check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Tentacle critical-kill heal check")
		return
	if runtime_player.get("crit_kill_heal_chance") == null:
		failures.append("Player should expose crit_kill_heal_chance for Tentacle")
		return

	var before_chance = float(runtime_player.get("crit_kill_heal_chance"))
	runtime_player.apply_upgrade(tentacle)
	if not is_equal_approx(float(runtime_player.get("crit_kill_heal_chance")), before_chance + 0.20):
		failures.append("Applying Tentacle should add 20 percent critical-kill heal chance")

	runtime_player.crit_kill_heal_chance = 1.0
	runtime_player.max_hp = 10
	runtime_player.hp = 5
	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.hp = 1
	enemy.max_hp = 1
	enemy.xp_drop = 0
	enemy.position = runtime_player.position + Vector2(80, 0)
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 5, true)
	bullet._on_body_entered(enemy)
	await process_frame
	if int(runtime_player.hp) != 6:
		failures.append("Critical kill with guaranteed Tentacle chance should heal 1 HP")
	runtime_player.crit_kill_heal_chance = before_chance + 0.20
	runtime_player.remove_upgrade(tentacle)
	if not is_equal_approx(float(runtime_player.get("crit_kill_heal_chance")), before_chance):
		failures.append("Removing Tentacle should restore critical-kill heal chance")

func _check_catalog_hunting_trophy_crit_kill_material():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Hunting Trophy check: " + str(errors))
		return
	var hunting_trophy = _find_by_source_id(data.get_shop_pool(false), "hunting_trophy")
	if hunting_trophy.is_empty():
		failures.append("Runtime shop pool should include Hunting Trophy critical-kill material modifier")
		return
	if not _has_weapon_special_rule(hunting_trophy.get("effects", []), "gain_1_material_on_critical_kill_chance"):
		failures.append("Hunting Trophy shop entry should preserve critical-kill material special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Hunting Trophy critical-kill material check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Hunting Trophy critical-kill material check")
		return
	if runtime_player.get("crit_kill_material_chance") == null:
		failures.append("Player should expose crit_kill_material_chance for Hunting Trophy")
		return

	var before_chance = float(runtime_player.get("crit_kill_material_chance"))
	runtime_player.apply_upgrade(hunting_trophy)
	if not is_equal_approx(float(runtime_player.get("crit_kill_material_chance")), before_chance + 0.33):
		failures.append("Applying Hunting Trophy should add 33 percent critical-kill material chance")

	runtime_player.crit_kill_material_chance = 1.0
	main.wave_manager.current_modifier = main.wave_manager.WAVE_MODIFIERS[0]
	var before_materials = int(main.economy.materials)
	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.hp = 1
	enemy.max_hp = 1
	enemy.xp_drop = 0
	enemy.position = runtime_player.position + Vector2(80, 0)
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 5, true)
	bullet._on_body_entered(enemy)
	var after_materials = int(main.economy.materials)
	if after_materials != before_materials + 1:
		failures.append("Critical kill with guaranteed Hunting Trophy chance should grant 1 material, modifier=%s before=%d after=%d" % [str(main.wave_manager.current_modifier.get("id", "")), before_materials, after_materials])
	_reset_enemy_pool(main)
	await process_frame
	runtime_player.crit_kill_material_chance = before_chance + 0.33
	runtime_player.remove_upgrade(hunting_trophy)
	if not is_equal_approx(float(runtime_player.get("crit_kill_material_chance")), before_chance):
		failures.append("Removing Hunting Trophy should restore critical-kill material chance")

func _check_catalog_baby_gecko_material_drop_attract():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Baby Gecko check: " + str(errors))
		return
	var baby_gecko = _find_by_source_id(data.get_shop_pool(false), "baby_gecko")
	if baby_gecko.is_empty():
		failures.append("Runtime shop pool should include Baby Gecko instant material attraction modifier")
		return
	if not _has_stat_delta(baby_gecko.get("effects", []), "range", 10.0):
		failures.append("Baby Gecko shop entry should preserve range bonus")
	if not _has_weapon_special_rule(baby_gecko.get("effects", []), "material_drop_instant_attract_chance"):
		failures.append("Baby Gecko shop entry should preserve material-drop attraction special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Baby Gecko material drop check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Baby Gecko material drop check")
		return
	if runtime_player.get("material_drop_instant_attract_chance") == null:
		failures.append("Player should expose material_drop_instant_attract_chance for Baby Gecko")
		return

	_reset_xp_orb_pool(main)
	var before_range = float(runtime_player.range_bonus)
	var before_chance = float(runtime_player.get("material_drop_instant_attract_chance"))
	runtime_player.apply_upgrade(baby_gecko)
	if not is_equal_approx(float(runtime_player.range_bonus), before_range + 10.0):
		failures.append("Applying Baby Gecko should add 10 range")
	if not is_equal_approx(float(runtime_player.get("material_drop_instant_attract_chance")), before_chance + 0.25):
		failures.append("Applying Baby Gecko should add 25 percent instant material attraction chance")

	runtime_player.material_drop_instant_attract_chance = 1.0
	runtime_player.double_material_pickup_chance = 0.0
	runtime_player.material_pickup_heal_chance = 0.0
	runtime_player.xp = 0
	runtime_player.xp_to_next = 1000
	runtime_player.xp_boost = 1.0
	var before_materials = int(main.economy.materials)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.xp_drop = 4
	enemy.position = runtime_player.position + Vector2(500, 0)
	enemy._drop_xp()
	await process_frame
	if int(main.economy.materials) != before_materials + 4:
		failures.append("Guaranteed Baby Gecko should instantly attract dropped material into player materials")
	if int(runtime_player.xp) != 4:
		failures.append("Guaranteed Baby Gecko instant attraction should also grant material XP")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	runtime_player.material_drop_instant_attract_chance = before_chance + 0.25
	runtime_player.remove_upgrade(baby_gecko)
	if not is_equal_approx(float(runtime_player.range_bonus), before_range):
		failures.append("Removing Baby Gecko should restore range")
	if not is_equal_approx(float(runtime_player.get("material_drop_instant_attract_chance")), before_chance):
		failures.append("Removing Baby Gecko should restore instant material attraction chance")

func _check_catalog_baby_elephant_material_pickup_damage():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Baby Elephant check: " + str(errors))
		return
	var baby_elephant = _find_by_source_id(data.get_shop_pool(false), "baby_elephant")
	if baby_elephant.is_empty():
		failures.append("Runtime shop pool should include Baby Elephant material-pickup luck damage modifier")
		return
	if not _has_weapon_special_rule(baby_elephant.get("effects", []), "material_pickup_luck_damage_chance"):
		failures.append("Baby Elephant shop entry should preserve material-pickup luck damage special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Baby Elephant material pickup damage check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Baby Elephant material pickup damage check")
		return
	if runtime_player.get("material_pickup_luck_damage_chance") == null:
		failures.append("Player should expose material_pickup_luck_damage_chance for Baby Elephant")
		return
	if runtime_player.get("material_pickup_luck_damage_base") == null:
		failures.append("Player should expose material_pickup_luck_damage_base for Baby Elephant")
		return
	if runtime_player.get("material_pickup_luck_damage_coefficient") == null:
		failures.append("Player should expose material_pickup_luck_damage_coefficient for Baby Elephant")
		return

	var before_chance = float(runtime_player.get("material_pickup_luck_damage_chance"))
	var before_base = float(runtime_player.get("material_pickup_luck_damage_base"))
	var before_coefficient = float(runtime_player.get("material_pickup_luck_damage_coefficient"))
	runtime_player.apply_upgrade(baby_elephant)
	if not is_equal_approx(float(runtime_player.get("material_pickup_luck_damage_chance")), before_chance + 0.25):
		failures.append("Applying Baby Elephant should add 25 percent material-pickup damage chance")
	if not is_equal_approx(float(runtime_player.get("material_pickup_luck_damage_base")), before_base + 1.0):
		failures.append("Applying Baby Elephant should add material-pickup damage base")
	if not is_equal_approx(float(runtime_player.get("material_pickup_luck_damage_coefficient")), before_coefficient + 0.25):
		failures.append("Applying Baby Elephant should add Luck damage coefficient")

	_reset_enemy_pool(main)
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.max_hp = 20
	enemy.hp = 20
	enemy.position = runtime_player.position + Vector2(120, 0)
	runtime_player.material_pickup_luck_damage_chance = 1.0
	runtime_player.material_pickup_luck_damage_base = 1.0
	runtime_player.material_pickup_luck_damage_coefficient = 0.25
	runtime_player.luck = 20
	runtime_player.double_material_pickup_chance = 0.0
	runtime_player.material_pickup_heal_chance = 0.0
	var orb = main.get_xp_orb()
	orb.activate(runtime_player.position, 1)
	orb.collect(runtime_player)
	await process_frame
	if int(enemy.hp) != 14:
		failures.append("Guaranteed Baby Elephant should damage an enemy for 1 plus 25 percent Luck on material pickup")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	runtime_player.material_pickup_luck_damage_chance = before_chance + 0.25
	runtime_player.material_pickup_luck_damage_base = before_base + 1.0
	runtime_player.material_pickup_luck_damage_coefficient = before_coefficient + 0.25
	runtime_player.remove_upgrade(baby_elephant)
	if not is_equal_approx(float(runtime_player.get("material_pickup_luck_damage_chance")), before_chance):
		failures.append("Removing Baby Elephant should restore material-pickup damage chance")
	if not is_equal_approx(float(runtime_player.get("material_pickup_luck_damage_base")), before_base):
		failures.append("Removing Baby Elephant should restore material-pickup damage base")
	if not is_equal_approx(float(runtime_player.get("material_pickup_luck_damage_coefficient")), before_coefficient):
		failures.append("Removing Baby Elephant should restore material-pickup damage coefficient")

func _check_catalog_cyberball_enemy_death_damage():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Cyberball check: " + str(errors))
		return
	var cyberball = _find_by_source_id(data.get_shop_pool(false), "cyberball")
	if cyberball.is_empty():
		failures.append("Runtime shop pool should include Cyberball enemy-death luck damage modifier")
		return
	if not _has_weapon_special_rule(cyberball.get("effects", []), "enemy_death_luck_damage_chance"):
		failures.append("Cyberball shop entry should preserve enemy-death luck damage special rule")
		return

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Cyberball enemy-death damage check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Cyberball enemy-death damage check")
		return
	if runtime_player.get("enemy_death_luck_damage_chance") == null:
		failures.append("Player should expose enemy_death_luck_damage_chance for Cyberball")
		return
	if runtime_player.get("enemy_death_luck_damage_base") == null:
		failures.append("Player should expose enemy_death_luck_damage_base for Cyberball")
		return
	if runtime_player.get("enemy_death_luck_damage_coefficient") == null:
		failures.append("Player should expose enemy_death_luck_damage_coefficient for Cyberball")
		return

	var before_chance = float(runtime_player.get("enemy_death_luck_damage_chance"))
	var before_base = float(runtime_player.get("enemy_death_luck_damage_base"))
	var before_coefficient = float(runtime_player.get("enemy_death_luck_damage_coefficient"))
	runtime_player.apply_upgrade(cyberball)
	if not is_equal_approx(float(runtime_player.get("enemy_death_luck_damage_chance")), before_chance + 0.25):
		failures.append("Applying Cyberball should add 25 percent enemy-death damage chance")
	if not is_equal_approx(float(runtime_player.get("enemy_death_luck_damage_base")), before_base + 1.0):
		failures.append("Applying Cyberball should add enemy-death damage base")
	if not is_equal_approx(float(runtime_player.get("enemy_death_luck_damage_coefficient")), before_coefficient + 0.25):
		failures.append("Applying Cyberball should add enemy-death Luck damage coefficient")

	_reset_enemy_pool(main)
	var target_enemy = main.get_enemy()
	target_enemy.setup("normal", 1)
	target_enemy.max_hp = 20
	target_enemy.hp = 20
	target_enemy.position = runtime_player.position + Vector2(120, 0)
	var killed_enemy = main.get_enemy()
	killed_enemy.setup("normal", 1)
	killed_enemy.max_hp = 1
	killed_enemy.hp = 1
	killed_enemy.xp_drop = 0
	killed_enemy.position = runtime_player.position + Vector2(80, 0)
	if not killed_enemy.died.is_connected(main._on_enemy_died.bind(killed_enemy)):
		killed_enemy.died.connect(main._on_enemy_died.bind(killed_enemy))
	runtime_player.enemy_death_luck_damage_chance = 1.0
	runtime_player.enemy_death_luck_damage_base = 1.0
	runtime_player.enemy_death_luck_damage_coefficient = 0.25
	runtime_player.luck = 20
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 5, false)
	bullet._on_body_entered(killed_enemy)
	await process_frame
	if int(target_enemy.hp) != 14:
		failures.append("Guaranteed Cyberball should damage an enemy for 1 plus 25 percent Luck when another enemy dies")
	if is_instance_valid(target_enemy):
		main.recycle_enemy(target_enemy)
	if is_instance_valid(killed_enemy):
		main.recycle_enemy(killed_enemy)

	runtime_player.enemy_death_luck_damage_chance = before_chance + 0.25
	runtime_player.enemy_death_luck_damage_base = before_base + 1.0
	runtime_player.enemy_death_luck_damage_coefficient = before_coefficient + 0.25
	runtime_player.remove_upgrade(cyberball)
	if not is_equal_approx(float(runtime_player.get("enemy_death_luck_damage_chance")), before_chance):
		failures.append("Removing Cyberball should restore enemy-death damage chance")
	if not is_equal_approx(float(runtime_player.get("enemy_death_luck_damage_base")), before_base):
		failures.append("Removing Cyberball should restore enemy-death damage base")
	if not is_equal_approx(float(runtime_player.get("enemy_death_luck_damage_coefficient")), before_coefficient):
		failures.append("Removing Cyberball should restore enemy-death damage coefficient")

func _check_catalog_black_flag_and_will_o_wisp_kill_items():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Black Flag/Will-o'-Wisp check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var black_flag = _find_by_source_id(pool, "black_flag")
	var will_o_wisp = _find_by_source_id(pool, "will_o_wisp")
	if black_flag.is_empty():
		failures.append("Runtime shop pool should include Black Flag cursed-kill material item")
	if will_o_wisp.is_empty():
		failures.append("Runtime shop pool should include Will-o'-Wisp burning-kill elemental item")
	if black_flag.is_empty() or will_o_wisp.is_empty():
		return
	if not _has_weapon_special_rule(black_flag.get("effects", []), "gain_1_material_when_killing_cursed_enemy"):
		failures.append("Black Flag should preserve cursed-enemy material special rule")
	if not _has_stat_delta(black_flag.get("effects", []), "curse", 5.0):
		failures.append("Black Flag should preserve +5 Curse")
	if not _has_stat_delta(black_flag.get("effects", []), "enemies_percent", 0.10):
		failures.append("Black Flag should preserve +10 percent Enemies")
	if not _has_weapon_special_rule(will_o_wisp.get("effects", []), "elemental_damage_plus_1_per_30_burning_kills_max_4_per_wave"):
		failures.append("Will-o'-Wisp should preserve burning-kill Elemental Damage rule")
	if not _has_stat_delta(will_o_wisp.get("effects", []), "attack_speed_percent", -0.07):
		failures.append("Will-o'-Wisp should preserve -7 percent Attack Speed")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Black Flag/Will-o'-Wisp check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Black Flag/Will-o'-Wisp check")
		return
	for required_property in [
		"cursed_enemy_material_bonus_sources",
		"burning_kill_elemental_damage_sources",
		"burning_kill_elemental_kill_counter",
		"burning_kill_elemental_gained_this_wave",
	]:
		if runtime_player.get(required_property) == null:
			failures.append("Player should expose %s for Black Flag/Will-o'-Wisp" % required_property)
			return
	for required_method in [
		"is_catalog_cursed_enemy",
		"record_burning_enemy_kill",
		"reset_burning_kill_elemental_damage_wave_bonus",
	]:
		if not runtime_player.has_method(required_method):
			failures.append("Player should expose %s for Black Flag/Will-o'-Wisp" % required_method)
			return

	var before_cursed_sources = int(runtime_player.get("cursed_enemy_material_bonus_sources"))
	var before_burning_sources = int(runtime_player.get("burning_kill_elemental_damage_sources"))
	var before_curse = int(runtime_player.curse)
	var before_enemy_count = float(runtime_player.enemies_percent)
	var before_enemy_health = float(runtime_player.enemy_health_percent)
	var before_enemy_damage = float(runtime_player.enemy_damage_percent)
	var before_fire_rate = float(runtime_player.fire_rate_multiplier)
	var before_elemental = int(runtime_player.elemental_damage_bonus)
	runtime_player.apply_upgrade(black_flag)
	runtime_player.apply_upgrade(will_o_wisp)
	if int(runtime_player.get("cursed_enemy_material_bonus_sources")) != before_cursed_sources + 1:
		failures.append("Applying Black Flag should enable cursed-enemy material rewards")
	if int(runtime_player.get("burning_kill_elemental_damage_sources")) != before_burning_sources + 1:
		failures.append("Applying Will-o'-Wisp should enable burning-kill Elemental Damage growth")
	if int(runtime_player.curse) != before_curse + 5:
		failures.append("Applying Black Flag should add 5 Curse")
	if not is_equal_approx(float(runtime_player.enemies_percent), before_enemy_count + 0.10):
		failures.append("Applying Black Flag should add 10 percent Enemies")
	if not is_equal_approx(float(runtime_player.enemy_health_percent), before_enemy_health + 0.10):
		failures.append("Applying Black Flag should add 10 percent enemy health")
	if not is_equal_approx(float(runtime_player.enemy_damage_percent), before_enemy_damage + 0.10):
		failures.append("Applying Black Flag should add 10 percent enemy damage")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_fire_rate - 0.07):
		failures.append("Applying Will-o'-Wisp should subtract 7 percent Attack Speed")

	_reset_enemy_pool(main)
	runtime_player.gold = 10
	if main.economy != null:
		main.economy.reset(10)
	var cursed_enemy = main.get_enemy()
	cursed_enemy.setup("normal", 1)
	cursed_enemy.set_meta("catalog_cursed", true)
	runtime_player.on_enemy_died(cursed_enemy)
	if int(runtime_player.gold) != 11:
		failures.append("Black Flag should grant 1 material when a cursed enemy dies")
	cursed_enemy.remove_meta("catalog_cursed")
	if is_instance_valid(cursed_enemy):
		main.recycle_enemy(cursed_enemy)

	runtime_player.burning_kill_elemental_kill_counter = 0
	runtime_player.burning_kill_elemental_gained_this_wave = 0
	for i in range(120):
		var burning_enemy = main.get_enemy()
		burning_enemy.setup("normal", 1)
		burning_enemy.apply_burn(runtime_player)
		burning_enemy.hp = 0
		runtime_player.on_enemy_died(burning_enemy)
		if is_instance_valid(burning_enemy):
			main.recycle_enemy(burning_enemy)
	if int(runtime_player.elemental_damage_bonus) != before_elemental + 4:
		failures.append("Will-o'-Wisp should grant max +4 Elemental Damage per wave from burning kills")
	if int(runtime_player.get("burning_kill_elemental_gained_this_wave")) != 4:
		failures.append("Will-o'-Wisp should track four Elemental Damage gains this wave")
	for i in range(30):
		var capped_enemy = main.get_enemy()
		capped_enemy.setup("normal", 1)
		capped_enemy.apply_burn(runtime_player)
		capped_enemy.hp = 0
		runtime_player.on_enemy_died(capped_enemy)
		if is_instance_valid(capped_enemy):
			main.recycle_enemy(capped_enemy)
	if int(runtime_player.elemental_damage_bonus) != before_elemental + 4:
		failures.append("Will-o'-Wisp should not exceed +4 Elemental Damage in one wave")
	runtime_player.on_wave_start(2)
	if int(runtime_player.get("burning_kill_elemental_kill_counter")) != 0 or int(runtime_player.get("burning_kill_elemental_gained_this_wave")) != 0:
		failures.append("Will-o'-Wisp should reset burning-kill counters on wave start")

	runtime_player.remove_upgrade(will_o_wisp)
	runtime_player.remove_upgrade(black_flag)
	if int(runtime_player.get("cursed_enemy_material_bonus_sources")) != before_cursed_sources:
		failures.append("Removing Black Flag should restore cursed-enemy material reward sources")
	if int(runtime_player.get("burning_kill_elemental_damage_sources")) != before_burning_sources:
		failures.append("Removing Will-o'-Wisp should restore burning-kill Elemental Damage sources")
	if int(runtime_player.curse) != before_curse:
		failures.append("Removing Black Flag should restore Curse")
	if not is_equal_approx(float(runtime_player.enemies_percent), before_enemy_count):
		failures.append("Removing Black Flag should restore Enemies percent")
	if not is_equal_approx(float(runtime_player.enemy_health_percent), before_enemy_health):
		failures.append("Removing Black Flag should restore enemy health percent")
	if not is_equal_approx(float(runtime_player.enemy_damage_percent), before_enemy_damage):
		failures.append("Removing Black Flag should restore enemy damage percent")
	if not is_equal_approx(float(runtime_player.fire_rate_multiplier), before_fire_rate):
		failures.append("Removing Will-o'-Wisp should restore Attack Speed")
	runtime_player.elemental_damage_bonus = before_elemental

func _check_catalog_goblet_enemy_kill_heal():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Goblet check: " + str(errors))
		return
	var goblet = _find_by_source_id(data.get_shop_pool(false), "goblet")
	if goblet.is_empty():
		failures.append("Runtime shop pool should include Goblet enemy-kill heal modifier")
		return
	if not _has_weapon_special_rule(goblet.get("effects", []), "heal_1_hp_on_enemy_kill_chance"):
		failures.append("Goblet shop entry should preserve enemy-kill heal special rule")
		return
	if not _has_stat_delta(goblet.get("effects", []), "hp_regeneration", -3.0):
		failures.append("Goblet shop entry should preserve HP regeneration penalty")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Goblet enemy-kill heal check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Goblet enemy-kill heal check")
		return
	if runtime_player.get("enemy_kill_heal_chance") == null:
		failures.append("Player should expose enemy_kill_heal_chance for Goblet")
		return

	var before_regen = int(runtime_player.hp_regen)
	var before_chance = float(runtime_player.get("enemy_kill_heal_chance"))
	runtime_player.apply_upgrade(goblet)
	if int(runtime_player.hp_regen) != before_regen - 3:
		failures.append("Applying Goblet should apply its HP regeneration penalty")
	if not is_equal_approx(float(runtime_player.get("enemy_kill_heal_chance")), before_chance + 0.15):
		failures.append("Applying Goblet should add 15 percent enemy-kill heal chance")

	_reset_enemy_pool(main)
	runtime_player.enemy_kill_heal_chance = 1.0
	runtime_player.max_hp = 10
	runtime_player.hp = 5
	var enemy = main.get_enemy()
	enemy.setup("normal", 1)
	enemy.max_hp = 1
	enemy.hp = 1
	enemy.xp_drop = 0
	enemy.position = runtime_player.position + Vector2(80, 0)
	if not enemy.died.is_connected(main._on_enemy_died.bind(enemy)):
		enemy.died.connect(main._on_enemy_died.bind(enemy))
	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 5, false)
	bullet._on_body_entered(enemy)
	await process_frame
	if int(runtime_player.hp) != 6:
		failures.append("Guaranteed Goblet enemy-kill heal should heal 1 HP when an enemy dies")
	if is_instance_valid(enemy):
		main.recycle_enemy(enemy)

	runtime_player.enemy_kill_heal_chance = before_chance + 0.15
	runtime_player.remove_upgrade(goblet)
	if int(runtime_player.hp_regen) != before_regen:
		failures.append("Removing Goblet should restore HP regeneration")
	if not is_equal_approx(float(runtime_player.get("enemy_kill_heal_chance")), before_chance):
		failures.append("Removing Goblet should restore enemy-kill heal chance")

func _check_catalog_rip_and_tear_enemy_death_explosion():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for Rip and Tear check: " + str(errors))
		return
	var rip_and_tear = _find_by_source_id(data.get_shop_pool(false), "rip_and_tear")
	if rip_and_tear.is_empty():
		failures.append("Runtime shop pool should include Rip and Tear enemy-death explosion modifier")
		return
	if not _has_weapon_special_rule(rip_and_tear.get("effects", []), "enemy_death_explosion_chance"):
		failures.append("Rip and Tear shop entry should preserve enemy-death explosion special rule")
		return
	if not _has_weapon_special_rule_chance(rip_and_tear.get("effects", []), "enemy_death_explosion_chance", 0.20):
		failures.append("Rip and Tear shop entry should preserve 20 percent explosion chance")
	if not _has_stat_delta(rip_and_tear.get("effects", []), "crit_chance", -0.05):
		failures.append("Rip and Tear shop entry should preserve crit chance penalty")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for Rip and Tear enemy-death explosion check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Rip and Tear enemy-death explosion check")
		return
	if runtime_player.get("enemy_death_explosion_chance") == null:
		failures.append("Player should expose enemy_death_explosion_chance for Rip and Tear")
		return
	if runtime_player.get("enemy_death_explosion_base") == null:
		failures.append("Player should expose enemy_death_explosion_base for Rip and Tear")
		return
	if runtime_player.get("enemy_death_explosion_melee_coefficient") == null:
		failures.append("Player should expose enemy_death_explosion_melee_coefficient for Rip and Tear")
		return

	var before_chance = float(runtime_player.get("enemy_death_explosion_chance"))
	var before_base = float(runtime_player.get("enemy_death_explosion_base"))
	var before_coefficient = float(runtime_player.get("enemy_death_explosion_melee_coefficient"))
	var before_crit = float(runtime_player.crit_chance)
	runtime_player.apply_upgrade(rip_and_tear)
	if not is_equal_approx(float(runtime_player.get("enemy_death_explosion_chance")), before_chance + 0.20):
		failures.append("Applying Rip and Tear should add 20 percent enemy-death explosion chance")
	if not is_equal_approx(float(runtime_player.get("enemy_death_explosion_base")), before_base + 10.0):
		failures.append("Applying Rip and Tear should add enemy-death explosion base damage")
	if not is_equal_approx(float(runtime_player.get("enemy_death_explosion_melee_coefficient")), before_coefficient + 0.50):
		failures.append("Applying Rip and Tear should add melee damage scaling")
	if not is_equal_approx(float(runtime_player.crit_chance), before_crit - 0.05):
		failures.append("Applying Rip and Tear should apply its crit chance penalty")

	_reset_enemy_pool(main)
	var target_enemy = main.get_enemy()
	target_enemy.setup("normal", 1)
	target_enemy.max_hp = 20
	target_enemy.hp = 20
	target_enemy.position = runtime_player.position + Vector2(120, 0)
	var far_enemy = main.get_enemy()
	far_enemy.setup("normal", 1)
	far_enemy.max_hp = 20
	far_enemy.hp = 20
	far_enemy.position = runtime_player.position + Vector2(600, 0)
	var killed_enemy = main.get_enemy()
	killed_enemy.setup("normal", 1)
	killed_enemy.max_hp = 1
	killed_enemy.hp = 1
	killed_enemy.xp_drop = 0
	killed_enemy.position = runtime_player.position + Vector2(80, 0)
	if not killed_enemy.died.is_connected(main._on_enemy_died.bind(killed_enemy)):
		killed_enemy.died.connect(main._on_enemy_died.bind(killed_enemy))
	runtime_player.enemy_death_explosion_chance = 1.0
	runtime_player.enemy_death_explosion_base = 10.0
	runtime_player.enemy_death_explosion_melee_coefficient = 0.50
	runtime_player.melee_damage_bonus = 4
	runtime_player.enemy_death_luck_damage_chance = 0.0
	# ── 隔离：这次测量只关心「爆炸会不会波及半径外的敌人」 ──
	# 场面是活的：玩家会自动开火，而且这个巨型测试跑到这一步已经给玩家挂了几百件道具，
	# 其中不少带击杀/命中触发的效果。它们会在同一帧里对 far_enemy 造成伤害，
	# 于是这条断言间歇性失败（实测 2/10，掉 3 点）。
	# 改动前稳定通过只是运气 —— 它一直差一个副作用就会翻。
	# 因此测量期间冻结世界，让这一帧里只剩「手动这一发击杀」引发的同步效果。
	var main_was_processing: bool = main.is_processing()
	var player_was_physics: bool = runtime_player.is_physics_processing()
	main.set_process(false)
	runtime_player.set_physics_process(false)

	# 还要清掉**在场子弹**：这三只敌人与玩家都摆在同一 y 线上，
	# 之前几帧打出去的子弹会沿着这条线飞很远，可能在测量这一帧正好命中 far_enemy
	# （实测掉 3 点 = 一发手枪；命中后立即回收，所以断言时看到的 bullets 是 0）。
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()
	for b in main.enemy_bullet_pool:
		if is_instance_valid(b) and b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()

	var bullet = main.get_bullet()
	bullet.activate(runtime_player.position, Vector2.RIGHT, 500.0, Color(1, 1, 1), runtime_player, 5, false)
	bullet._on_body_entered(killed_enemy)
	await process_frame

	runtime_player.set_physics_process(player_was_physics)
	main.set_process(main_was_processing)

	if int(target_enemy.hp) != 8:
		failures.append("Guaranteed Rip and Tear should damage nearby enemies for 10 plus 50 percent melee damage")
	if int(far_enemy.hp) != 20:
		failures.append("Rip and Tear should not damage enemies outside the explosion radius")
	if is_instance_valid(target_enemy):
		main.recycle_enemy(target_enemy)
	if is_instance_valid(far_enemy):
		main.recycle_enemy(far_enemy)
	if is_instance_valid(killed_enemy):
		main.recycle_enemy(killed_enemy)

	runtime_player.enemy_death_explosion_chance = before_chance + 0.20
	runtime_player.enemy_death_explosion_base = before_base + 10.0
	runtime_player.enemy_death_explosion_melee_coefficient = before_coefficient + 0.50
	runtime_player.remove_upgrade(rip_and_tear)
	if not is_equal_approx(float(runtime_player.get("enemy_death_explosion_chance")), before_chance):
		failures.append("Removing Rip and Tear should restore enemy-death explosion chance")
	if not is_equal_approx(float(runtime_player.get("enemy_death_explosion_base")), before_base):
		failures.append("Removing Rip and Tear should restore enemy-death explosion base damage")
	if not is_equal_approx(float(runtime_player.get("enemy_death_explosion_melee_coefficient")), before_coefficient):
		failures.append("Removing Rip and Tear should restore melee damage scaling")
	if not is_equal_approx(float(runtime_player.crit_chance), before_crit):
		failures.append("Removing Rip and Tear should restore crit chance")

func _check_catalog_material_pickup_specials():
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("BrotatoData failed to load catalog for material pickup special check: " + str(errors))
		return
	var pool = data.get_shop_pool(false)
	var cute_monkey = _find_by_source_id(pool, "cute_monkey")
	var metal_detector = _find_by_source_id(pool, "metal_detector")
	if cute_monkey.is_empty():
		failures.append("Runtime shop pool should include Cute Monkey material pickup heal modifier")
	if metal_detector.is_empty():
		failures.append("Runtime shop pool should include Metal Detector material pickup double modifier")
	if cute_monkey.is_empty() or metal_detector.is_empty():
		return
	if not _has_weapon_special_rule(cute_monkey.get("effects", []), "heal_1_hp_on_material_pickup_chance"):
		failures.append("Cute Monkey shop entry should preserve material-pickup heal special rule")
	if not _has_weapon_special_rule(metal_detector.get("effects", []), "double_picked_material_value_chance"):
		failures.append("Metal Detector shop entry should preserve material-pickup double special rule")

	if not is_instance_valid(main):
		var packed_main = load("res://scenes/Main.tscn")
		if packed_main == null:
			failures.append("Main scene missing for material pickup special check")
			return
		main = packed_main.instantiate()
		root.add_child(main)
		await process_frame
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for material pickup special check")
		return
	if runtime_player.get("material_pickup_heal_chance") == null:
		failures.append("Player should expose material_pickup_heal_chance for Cute Monkey")
		return
	if runtime_player.get("double_material_pickup_chance") == null:
		failures.append("Player should expose double_material_pickup_chance for Metal Detector")
		return

	_reset_xp_orb_pool(main)
	var before_heal_chance = float(runtime_player.get("material_pickup_heal_chance"))
	var before_double_chance = float(runtime_player.get("double_material_pickup_chance"))
	runtime_player.apply_upgrade(cute_monkey)
	runtime_player.apply_upgrade(metal_detector)
	if not is_equal_approx(float(runtime_player.get("material_pickup_heal_chance")), before_heal_chance + 0.08):
		failures.append("Applying Cute Monkey should add material-pickup heal chance")
	if not is_equal_approx(float(runtime_player.get("double_material_pickup_chance")), before_double_chance + 0.05):
		failures.append("Applying Metal Detector should add material-pickup double chance")

	runtime_player.material_pickup_heal_chance = 1.0
	runtime_player.double_material_pickup_chance = 1.0
	runtime_player.max_hp = 10
	runtime_player.hp = 5
	var before_materials = int(main.economy.materials)
	var before_xp = int(runtime_player.xp)
	var orb = main.get_xp_orb()
	orb.activate(runtime_player.position, 4)
	orb._on_body_entered(runtime_player)
	await process_frame
	if int(main.economy.materials) != before_materials + 8:
		failures.append("Guaranteed Metal Detector should double picked material value")
	if int(runtime_player.xp) != before_xp + 8:
		failures.append("Doubled material pickup value should also feed the material XP value")
	if int(runtime_player.hp) != 6:
		failures.append("Guaranteed Cute Monkey should heal 1 HP on material pickup")

	runtime_player.material_pickup_heal_chance = before_heal_chance + 0.08
	runtime_player.double_material_pickup_chance = before_double_chance + 0.05
	runtime_player.remove_upgrade(metal_detector)
	runtime_player.remove_upgrade(cute_monkey)
	if not is_equal_approx(float(runtime_player.get("material_pickup_heal_chance")), before_heal_chance):
		failures.append("Removing Cute Monkey should restore material-pickup heal chance")
	if not is_equal_approx(float(runtime_player.get("double_material_pickup_chance")), before_double_chance):
		failures.append("Removing Metal Detector should restore material-pickup double chance")

func _reset_xp_orb_pool(main_node):
	if main_node == null or not is_instance_valid(main_node):
		return
	if not ("xp_orb_pool" in main_node):
		return
	for orb in main_node.xp_orb_pool:
		if is_instance_valid(orb) and orb.has_method("_return_to_pool"):
			orb._return_to_pool()

func _reset_bullet_pool(main_node):
	if main_node == null or not is_instance_valid(main_node):
		return
	if not ("bullet_pool" in main_node):
		return
	for bullet in main_node.bullet_pool:
		if is_instance_valid(bullet) and bullet.has_method("_return_to_pool"):
			bullet._return_to_pool()

func _reset_enemy_pool(main_node):
	if main_node == null or not is_instance_valid(main_node):
		return
	if "xp_orb_pool" in main_node:
		for orb in main_node.xp_orb_pool:
			if is_instance_valid(orb) and orb.has_method("_return_to_pool"):
				orb._return_to_pool()
	for orb in main_node.get_tree().get_nodes_in_group("xp_orbs"):
		if is_instance_valid(orb) and orb.has_method("_return_to_pool"):
			orb._return_to_pool()
	for enemy in main_node.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if main_node.has_method("recycle_enemy") and enemy.get_parent() == main_node:
				main_node.recycle_enemy(enemy)
			elif enemy.has_method("recycle"):
				enemy.recycle()
	for tree_node in main_node.get_tree().get_nodes_in_group("neutral_trees"):
		if is_instance_valid(tree_node):
			if main_node.has_method("recycle_enemy") and tree_node.get_parent() == main_node:
				main_node.recycle_enemy(tree_node)
			elif tree_node.has_method("recycle"):
				tree_node.recycle()

func _find_by_source_id(items: Array, source_id: String) -> Dictionary:
	for item in items:
		if item.get("source_id", "") == source_id:
			return item
	return {}

func _find_visible_bullet(main_node) -> Node:
	for bullet in main_node.bullet_pool:
		if bullet.visible:
			return bullet
	for child in main_node.get_children():
		if child.is_in_group("bullets") and child.visible:
			return child
	return null

func _count_visible_bullets(main_node) -> int:
	var count = 0
	for bullet in main_node.bullet_pool:
		if is_instance_valid(bullet) and bullet.visible:
			count += 1
	for child in main_node.get_children():
		if child.is_in_group("bullets") and child.visible and not (child in main_node.bullet_pool):
			count += 1
	return count

func _count_visible_enemies_of_type(main_node, enemy_type: String) -> int:
	var count = 0
	for enemy in main_node.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.visible and str(enemy.get("enemy_type")) == enemy_type:
			count += 1
	return count

func _find_visible_xp_orb(main_node) -> Node:
	for orb in main_node.xp_orb_pool:
		if orb.visible:
			return orb
	for child in main_node.get_children():
		if child.is_in_group("xp_orbs") and child.visible:
			return child
	return null

func _has_stat_delta(effects: Array, stat: String, expected_value: float) -> bool:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		if effect.get("effect", "") != "stat_delta":
			continue
		if effect.get("stat", "") == stat and is_equal_approx(float(effect.get("value", 0.0)), expected_value):
			return true
	return false

func _has_weapon_special_rule(effects: Array, rule: String) -> bool:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		if effect.get("effect", "") == "weapon_special" and effect.get("rule", "") == rule:
			return true
	return false

func _has_weapon_special_rule_chance(effects: Array, rule: String, expected_chance: float) -> bool:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		if effect.get("effect", "") != "weapon_special" or effect.get("rule", "") != rule:
			continue
		if is_equal_approx(float(effect.get("chance", 0.0)), expected_chance):
			return true
	return false

func _has_weapon_special_rule_number(effects: Array, rule: String, key: String, expected_value: float) -> bool:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		if effect.get("effect", "") != "weapon_special" or effect.get("rule", "") != rule:
			continue
		if is_equal_approx(float(effect.get(key, 0.0)), expected_value):
			return true
	return false

func _find_structure_by_variant(structures: Array, variant: String):
	for structure in structures:
		if structure != null and is_instance_valid(structure) and str(structure.get_meta("variant", "")) == variant:
			return structure
	return null
