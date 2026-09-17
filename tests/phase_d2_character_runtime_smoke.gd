extends SceneTree

var failures: Array[String] = []

func _init():
	call_deferred("_run")

func _run():
	var game_state = root.get_node("/root/GameState")
	game_state.difficulty = 1
	game_state.endless_mode = false
	var audio_manager = root.get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		root.remove_child(audio_manager)
		audio_manager.queue_free()

	await _check_character_select_runtime_entries(game_state)
	await _check_character_select_scene_uses_catalog_entries(game_state)
	await _check_mage_catalog_starting_items(game_state)
	await _check_mage_catalog_stat_modification_multipliers(game_state)
	await _check_apprentice_catalog_level_up_stats(game_state)
	await _check_one_armed_catalog_weapon_slot_limit(game_state)
	await _check_ranger_catalog_stat_delta(game_state)
	await _check_sailor_catalog_stat_delta(game_state)
	await _check_creature_cursed_fish_hook_starting_item(game_state)
	game_state.selected_character = "normal"

	if failures.is_empty():
		print("PHASE_D2_CHARACTER_RUNTIME_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_character_select_runtime_entries(game_state):
	var data = game_state.get_brotato_data()
	if data == null:
		failures.append("GameState should expose Brotato catalog data for character select")
		return
	var catalog_characters = data.get_characters(true)
	var entries = game_state.get_character_select_entries()
	if entries.size() != catalog_characters.size():
		failures.append("Character select should expose all catalog characters, expected %d got %d" % [catalog_characters.size(), entries.size()])
	for character_id in ["well_rounded", "brawler", "ranger", "mage", "one_armed", "hunter", "romantic"]:
		if not entries.has(character_id):
			failures.append("Character select missing catalog character: " + character_id)
	if entries.has("romantic") and "finish_run_with_0_curse" not in str(entries["romantic"].get("unlock_condition", "")):
		failures.append("Character select should expose catalog unlock conditions for locked characters")
	if entries.has("normal"):
		failures.append("Character select should use canonical catalog IDs instead of legacy normal alias")
	if not game_state.has_method("get_character_display_name"):
		failures.append("GameState should expose catalog-aware character display names for UI notifications")
	else:
		# 期望值直接取自目录，避免断言随 i18n 改文案而失效（2026-07-20 中文名落地后曾因此误报）
		var romantic = data.get_character("romantic")
		var expected_name = str(romantic.get("display_name", romantic.get("source_name", "")))
		if expected_name.is_empty():
			failures.append("Character catalog should expose a display name for romantic")
		elif game_state.get_character_display_name("romantic") != expected_name:
			failures.append("GameState should resolve catalog display names for UI notifications (expected '%s', got '%s')" % [
				expected_name, game_state.get_character_display_name("romantic")
			])
	game_state.selected_character = "hunter"
	var hunter = game_state.get_character()
	if str(hunter.get("catalog_id", "")) != "hunter":
		failures.append("GameState should prefer catalog Hunter over legacy hardcoded Hunter")
	game_state.selected_character = "normal"
	var normal = game_state.get_character()
	if str(normal.get("catalog_id", "")) != "well_rounded":
		failures.append("Legacy normal selected character should resolve to catalog Well Rounded")
	game_state.selected_character = "missing_character"
	var fallback = game_state.get_character()
	if str(fallback.get("catalog_id", "")) != "well_rounded":
		failures.append("Invalid selected character should fall back to catalog Well Rounded")
	if not game_state.has_method("get_character_ids_for_unlock_condition"):
		failures.append("GameState should expose catalog unlock condition lookup for UI unlock flow")
	else:
		var level_20_unlocks = game_state.get_character_ids_for_unlock_condition("reach_level_20")
		if "apprentice" not in level_20_unlocks:
			failures.append("Catalog unlock lookup should resolve reach_level_20 to Apprentice")
		if "wizard" in level_20_unlocks:
			failures.append("Catalog unlock lookup should not return hidden legacy Wizard")

func _check_character_select_scene_uses_catalog_entries(game_state):
	var scene = load("res://scenes/CharacterSelect.tscn")
	if scene == null:
		failures.append("CharacterSelect scene should load")
		return
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	var entries = game_state.get_character_select_entries()
	var buttons = node.get("buttons")
	if not (buttons is Dictionary):
		failures.append("CharacterSelect should expose button map for catalog entries")
	elif buttons.size() != entries.size():
		failures.append("CharacterSelect scene should create one button per catalog character, expected %d got %d" % [entries.size(), buttons.size()])
	if str(node.get("selected_key")) != "well_rounded":
		failures.append("CharacterSelect should default legacy normal selection to catalog Well Rounded")
	root.remove_child(node)
	node.queue_free()

func _check_mage_catalog_starting_items(game_state):
	game_state.selected_character = "mage"
	var character = game_state.get_character()
	if character.get("starting_items", []).size() < 2:
		failures.append("Catalog Mage should expose Snake and Scared Sausage starting items")
		return
	var main = await _spawn_main()
	if main == null:
		failures.append("Main scene missing for Mage character runtime check")
		return
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Mage character runtime check")
		await _free_main(main)
		return
	if runtime_player.get("burn_spread_sources") == null or runtime_player.get("burn_on_hit_chance") == null:
		failures.append("Player should expose burn starting-item fields for Mage")
	elif int(runtime_player.get("burn_spread_sources")) < 1:
		failures.append("Mage should start with Snake's burn-spread item effect")
	elif not is_equal_approx(float(runtime_player.get("burn_on_hit_chance")), 0.25):
		failures.append("Mage should start with Scared Sausage's 25 percent burn-on-hit effect")
	await _free_main(main)

func _check_mage_catalog_stat_modification_multipliers(game_state):
	game_state.selected_character = "mage"
	var main = await _spawn_main()
	if main == null:
		failures.append("Main scene missing for Mage stat multiplier runtime check")
		return
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Mage stat multiplier runtime check")
		await _free_main(main)
		return
	var multipliers = runtime_player.get("catalog_stat_modification_multipliers")
	if not (multipliers is Dictionary):
		failures.append("Player should expose catalog stat modification multipliers")
	else:
		if not is_equal_approx(float(multipliers.get("ranged_damage", 1.0)), 0.0):
			failures.append("Mage should block Ranged Damage stat gains")
		if not is_equal_approx(float(multipliers.get("elemental_damage", 1.0)), 1.25):
			failures.append("Mage should increase Elemental Damage stat gains by 25 percent")
		if not is_equal_approx(float(multipliers.get("engineering", 1.0)), 0.5):
			failures.append("Mage should halve Engineering stat gains")
	var before_ranged = int(runtime_player.ranged_damage_bonus)
	var before_elemental = int(runtime_player.elemental_damage_bonus)
	var before_engineering = int(runtime_player.engineering_bonus)
	runtime_player.apply_upgrade({
		"name": "Mage Multiplier Probe",
		"type": "catalog_item",
		"source_id": "mage_multiplier_probe",
		"effects": [
			{"effect": "stat_delta", "stat": "ranged_damage", "value": 5},
			{"effect": "stat_delta", "stat": "elemental_damage", "value": 4},
			{"effect": "stat_delta", "stat": "engineering", "value": 4},
		],
	})
	if int(runtime_player.ranged_damage_bonus) != before_ranged:
		failures.append("Mage should apply 0x Ranged Damage gains from catalog stat_delta")
	if int(runtime_player.elemental_damage_bonus) != before_elemental + 5:
		failures.append("Mage should apply 1.25x Elemental Damage gains from catalog stat_delta")
	if int(runtime_player.engineering_bonus) != before_engineering + 2:
		failures.append("Mage should apply 0.5x Engineering gains from catalog stat_delta")
	await _free_main(main)

func _check_apprentice_catalog_level_up_stats(game_state):
	game_state.selected_character = "apprentice"
	var main = await _spawn_main()
	if main == null:
		failures.append("Main scene missing for Apprentice level-up stat runtime check")
		return
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Apprentice level-up stat runtime check")
		await _free_main(main)
		return
	var level_up_deltas = runtime_player.get("level_up_catalog_stat_deltas")
	if not (level_up_deltas is Dictionary):
		failures.append("Player should expose catalog level-up stat deltas")
	else:
		if int(level_up_deltas.get("melee_damage", 0)) != 2:
			failures.append("Apprentice should gain +2 Melee Damage on level up")
		if int(level_up_deltas.get("ranged_damage", 0)) != 1:
			failures.append("Apprentice should gain +1 Ranged Damage on level up")
		if int(level_up_deltas.get("elemental_damage", 0)) != 1:
			failures.append("Apprentice should gain +1 Elemental Damage on level up")
		if int(level_up_deltas.get("engineering", 0)) != 1:
			failures.append("Apprentice should gain +1 Engineering on level up")
		if int(level_up_deltas.get("max_hp", 0)) != -2:
			failures.append("Apprentice should lose 2 Max HP on level up")
	var before_melee = int(runtime_player.melee_damage_bonus)
	var before_ranged = int(runtime_player.ranged_damage_bonus)
	var before_elemental = int(runtime_player.elemental_damage_bonus)
	var before_engineering = int(runtime_player.engineering_bonus)
	var before_max_hp = int(runtime_player.max_hp)
	runtime_player.on_level_up(runtime_player.level + 1)
	if int(runtime_player.melee_damage_bonus) != before_melee + 2:
		failures.append("Apprentice level-up should add Melee Damage")
	if int(runtime_player.ranged_damage_bonus) != before_ranged + 1:
		failures.append("Apprentice level-up should add Ranged Damage")
	if int(runtime_player.elemental_damage_bonus) != before_elemental + 1:
		failures.append("Apprentice level-up should add Elemental Damage")
	if int(runtime_player.engineering_bonus) != before_engineering + 1:
		failures.append("Apprentice level-up should add Engineering")
	if int(runtime_player.max_hp) != before_max_hp - 2:
		failures.append("Apprentice level-up should subtract Max HP")
	await _free_main(main)

func _check_one_armed_catalog_weapon_slot_limit(game_state):
	game_state.selected_character = "one_armed"
	var main = await _spawn_main()
	if main == null:
		failures.append("Main scene missing for One Armed weapon slot runtime check")
		return
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for One Armed weapon slot runtime check")
		await _free_main(main)
		return
	if not runtime_player.has_method("get_max_weapon_slots"):
		failures.append("Player should expose runtime max weapon slot lookup")
	elif int(runtime_player.get_max_weapon_slots()) != 1:
		failures.append("One Armed should cap runtime weapon slots at 1")
	if runtime_player.equipped_weapons.size() != 1:
		failures.append("One Armed should start with exactly one weapon")
	if runtime_player.can_equip_or_combine_weapon("pistol", 1):
		failures.append("One Armed should not be able to equip a second different weapon")
	var before_count = runtime_player.equipped_weapons.size()
	if runtime_player.equip_or_combine_weapon("pistol", 1):
		failures.append("One Armed equip_or_combine_weapon should reject a second different weapon")
	if runtime_player.equipped_weapons.size() != before_count:
		failures.append("One Armed rejected weapon should not change equipped weapon count")
	await _free_main(main)

func _check_ranger_catalog_stat_delta(game_state):
	game_state.selected_character = "ranger"
	var character = game_state.get_character()
	if str(character.get("catalog_id", "")) != "ranger":
		failures.append("Ranger should resolve through the catalog character path")
		return
	var main = await _spawn_main()
	if main == null:
		failures.append("Main scene missing for Ranger stat runtime check")
		return
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Ranger stat runtime check")
		await _free_main(main)
		return
	if not is_equal_approx(float(runtime_player.range_bonus), 50.0):
		failures.append("Ranger should apply catalog Range +50 through stat_delta")
	await _free_main(main)

func _check_sailor_catalog_stat_delta(game_state):
	game_state.selected_character = "sailor"
	var character = game_state.get_character()
	if str(character.get("catalog_id", "")) != "sailor":
		failures.append("Sailor should resolve through the catalog character path")
		return
	var main = await _spawn_main()
	if main == null:
		failures.append("Main scene missing for Sailor stat runtime check")
		return
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Sailor stat runtime check")
		await _free_main(main)
		return
	if int(runtime_player.curse) != 25:
		failures.append("Sailor should apply catalog Curse +25 exactly once")
	if not is_equal_approx(float(runtime_player.damage_percent_bonus), -0.25):
		failures.append("Sailor should apply catalog Damage -25 percent through stat_delta")
	if not is_equal_approx(float(runtime_player.dodge_cap), 0.20):
		failures.append("Sailor should apply catalog Dodge cap 20 percent")
	await _free_main(main)

func _check_creature_cursed_fish_hook_starting_item(game_state):
	game_state.selected_character = "creature"
	var character = game_state.get_character()
	var starting_items: Array = character.get("starting_items", [])
	var has_cursed_fish_hook = false
	for item in starting_items:
		if item is Dictionary and str(item.get("item_id", "")) == "fish_hook" and bool(item.get("cursed", false)):
			has_cursed_fish_hook = true
	if not has_cursed_fish_hook:
		failures.append("Catalog Creature should expose a cursed Fish Hook starting item")
		return
	var main = await _spawn_main()
	if main == null:
		failures.append("Main scene missing for Creature character runtime check")
		return
	var runtime_player = main.player
	if not is_instance_valid(runtime_player):
		failures.append("Main scene should expose a player for Creature character runtime check")
		await _free_main(main)
		return
	if runtime_player.get("locked_shop_entry_curse_chance") == null:
		failures.append("Player should expose Fish Hook lock-to-curse state for Creature")
	elif int(runtime_player.curse) < 26:
		failures.append("Creature should include cursed Fish Hook's Curse surcharge plus +1 Curse")
	elif not is_equal_approx(float(runtime_player.get("locked_shop_entry_curse_chance")), 0.20):
		failures.append("Creature should start with Fish Hook's 20 percent locked-shop curse chance")
	_check_creature_catalog_special_rules(runtime_player)
	await _free_main(main)

func _check_creature_catalog_special_rules(runtime_player):
	if runtime_player.get("curse_weapon_damage_scaling_coefficient") == null:
		failures.append("Player should expose Creature's curse weapon damage scaling field")
	elif not is_equal_approx(float(runtime_player.get("curse_weapon_damage_scaling_coefficient")), 0.35):
		failures.append("Creature should add 35 percent Curse scaling to weapon damage")
	if runtime_player.get("level_up_curse_gain_sources") == null:
		failures.append("Player should expose Creature level-up Curse gain state")
	elif int(runtime_player.get("level_up_curse_gain_sources")) < 1:
		failures.append("Creature should gain +1 Curse on level up")
	var before_curse = int(runtime_player.curse)
	runtime_player.on_level_up(runtime_player.level + 1)
	if int(runtime_player.curse) != before_curse + 1:
		failures.append("Creature should apply +1 Curse when leveling up")
	if runtime_player.get("end_wave_range_delta") == null:
		failures.append("Player should expose Creature end-wave Range decay state")
	elif int(runtime_player.get("end_wave_range_delta")) != -10:
		failures.append("Creature should lose 10 Range at wave end")
	if not is_equal_approx(float(runtime_player.get("end_wave_xp_gain_percent")), -0.05):
		failures.append("Creature should lose 5 percent XP Gain at wave end")
	var before_range = float(runtime_player.range_bonus)
	var before_xp = float(runtime_player.xp_boost)
	runtime_player.on_wave_end()
	if not is_equal_approx(float(runtime_player.range_bonus), before_range - 10.0):
		failures.append("Creature should apply end-wave Range decay through on_wave_end")
	if not is_equal_approx(float(runtime_player.xp_boost), max(0.0, before_xp - 0.05)):
		failures.append("Creature should apply end-wave XP Gain decay through on_wave_end")

func _spawn_main():
	var packed_main = load("res://scenes/Main.tscn")
	if packed_main == null:
		return null
	var main = packed_main.instantiate()
	root.add_child(main)
	await process_frame
	return main

func _free_main(main):
	if is_instance_valid(main):
		main.queue_free()
	for i in range(3):
		await process_frame
