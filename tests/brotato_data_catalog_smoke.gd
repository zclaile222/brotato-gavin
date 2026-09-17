extends SceneTree

var failures: Array[String] = []

func _init():
	call_deferred("_run")

func _run():
	var script = load("res://scripts/BrotatoData.gd")
	if script == null:
		print("EXPECTED_FAIL_BROTATO_DATA_MISSING")
		quit(1)
		return

	var data = script.new()
	var load_errors = data.load_catalog()
	if not load_errors.is_empty():
		for error in load_errors:
			failures.append("Load error: " + error)

	var validation_errors = data.validate()
	if not validation_errors.is_empty():
		for error in validation_errors:
			failures.append("Validation error: " + error)

	_check_manifest(data)
	_check_default_characters(data)
	_check_character_catalog_expansion(data)
	_check_second_character_catalog_expansion(data)
	_check_third_character_catalog_expansion(data)
	_check_fourth_character_catalog_expansion(data)
	_check_fifth_character_catalog_expansion(data)
	_check_sixth_character_catalog_expansion(data)
	_check_seventh_character_catalog_expansion(data)
	_check_complete_character_catalog(data)
	_check_foundational_item_catalog_batch(data)
	_check_second_foundational_item_catalog_batch(data)
	_check_third_foundational_item_catalog_batch(data)
	_check_fourth_foundational_item_catalog_batch(data)
	_check_fifth_foundational_item_catalog_batch(data)
	_check_sixth_foundational_item_catalog_batch(data)
	_check_seventh_foundational_item_catalog_batch(data)
	_check_eighth_foundational_item_catalog_batch(data)
	_check_ninth_foundational_item_catalog_batch(data)
	_check_dlc_item_catalog_batch(data)
	_check_item_catalog_has_no_implemented_field(data)
	_check_gun_catalog(data)
	_check_runtime_conversions(data)
	await _check_main_scene_still_boots()

	if failures.is_empty():
		print("BROTATO_DATA_CATALOG_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_manifest(data):
	if data.manifest.get("reference_version", "") != "1.1.10.9":
		failures.append("Manifest reference version mismatch")
	var counts: Dictionary = data.manifest.get("expected_counts", {})
	if int(counts.get("characters", 0)) != 62:
		failures.append("Manifest expected character count must stay at 62")
	# 2026-09-15：items_total 由 237 更正为 235。用 wiki 的 MediaWiki API
	# （list=embeddedin on Template:Infobox Item）核实：wiki 上恰好 235 个物品页，
	# 与目录 235 条逐名 1:1 吻合。原先的 237 是**错数字**，不是「没达成的目标」。
	if int(counts.get("items_total", 0)) != 235:
		failures.append("Manifest expected total item count must stay at 235")
	# 目录规模必须与 manifest 声明的数量一致（这个不变量曾因 237 的错数字而长期失衡）
	var catalog_item_count = data.get_items(true).size()
	if catalog_item_count != int(counts.get("items_total", 0)):
		failures.append("Item catalog size must match the manifest expected total: %d vs %d" % [
			catalog_item_count, int(counts.get("items_total", 0))
		])

func _check_default_characters(data):
	var default_ids = data.get_default_character_ids()
	var expected := ["well_rounded", "brawler", "crazy", "ranger", "mage"]
	if default_ids != expected:
		failures.append("Default Brotato character seed mismatch: %s" % [default_ids])
	var ranger = data.get_character("ranger")
	if ranger.is_empty():
		failures.append("Missing ranger seed character")
		return
	if ranger.get("starting_weapons", [])[0] != "pistol":
		failures.append("Ranger should start with pistol")
	if not data.character_can_equip_weapon("ranger", "pistol"):
		failures.append("Ranger should be able to equip pistol")
	if data.character_can_equip_weapon("ranger", "knife"):
		failures.append("Ranger should not be able to equip melee weapons")
	var legacy_normal = data.to_game_state_character("well_rounded")
	if legacy_normal.get("weapon", "") != "pistol":
		failures.append("Well Rounded legacy conversion should start with pistol")

func _check_character_catalog_expansion(data):
	var characters = data.get_characters(true)
	if characters.size() < 11:
		failures.append("Character catalog should include first post-default expansion batch")
	for character_id in ["chunky", "old", "mutant", "generalist", "loud", "multitasker"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing expanded character row: " + character_id)

	var chunky = data.get_character("chunky")
	if not chunky.is_empty():
		if chunky.get("unlock", {}).get("condition", "") != "die_once":
			failures.append("Chunky unlock condition mismatch")
		if "potato_thrower" != chunky.get("unlocks", [])[0].get("id", ""):
			failures.append("Chunky unlock reward mismatch")
		if "spiky_shield" not in chunky.get("starting_weapon_options", []):
			failures.append("Chunky should offer Spiky Shield")

	var old = data.get_character("old")
	if not old.is_empty():
		if int(old.get("base_stats", {}).get("harvesting", 0)) != 10:
			failures.append("Old harvesting stat mismatch")
		if not old.get("rules", []).has({"effect": "stat_delta", "stat": "enemy_speed_percent", "value": -0.25}):
			failures.append("Old enemy speed rule mismatch")
		if "sickle" not in old.get("starting_weapon_options", []):
			failures.append("Old should offer Sickle")

	var mutant = data.get_character("mutant")
	if not mutant.is_empty():
		if mutant.get("unlock", {}).get("condition", "") != "kill_2000_enemies":
			failures.append("Mutant unlock condition mismatch")
		if not mutant.get("rules", []).has({"effect": "stat_modifications_multiplier", "stat": "xp_required", "multiplier": 0.34}):
			failures.append("Mutant XP required rule mismatch")

	var generalist = data.get_character("generalist")
	if not generalist.is_empty():
		if not generalist.get("rules", []).has({"effect": "weapon_special", "rule": "max_3_melee_and_3_ranged_weapons"}):
			failures.append("Generalist weapon limit rule mismatch")
		if "ghost_scepter" not in generalist.get("starting_weapon_options", []):
			failures.append("Generalist should offer Ghost Scepter")

	var loud = data.get_character("loud")
	if not loud.is_empty():
		if int(round(float(loud.get("base_stats", {}).get("damage_percent", 0.0)) * 100.0)) != 30:
			failures.append("Loud damage stat mismatch")
		if not loud.get("rules", []).has({"effect": "stat_delta", "stat": "enemies_percent", "value": 0.50}):
			failures.append("Loud enemy count rule mismatch")

	var multitasker = data.get_character("multitasker")
	if not multitasker.is_empty():
		if not multitasker.get("rules", []).has({"effect": "weapon_special", "rule": "max_12_weapons_damage_penalty_per_weapon"}):
			failures.append("Multitasker weapon capacity rule mismatch")
		if "hiking_pole" not in multitasker.get("starting_weapon_options", []):
			failures.append("Multitasker should offer Hiking Pole")

func _check_second_character_catalog_expansion(data):
	var characters = data.get_characters(true)
	if characters.size() < 17:
		failures.append("Character catalog should include second base expansion batch")
	for character_id in ["wildling", "gladiator", "sick", "farmer", "ghost", "speedy"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing second-batch character row: " + character_id)

	var wildling = data.get_character("wildling")
	if not wildling.is_empty():
		if wildling.get("unlock", {}).get("condition", "") != "kill_10000_enemies":
			failures.append("Wildling unlock condition mismatch")
		if wildling.get("fixed_starting_weapons", []) != ["stick"]:
			failures.append("Wildling should always start with Stick")
		if not wildling.get("rules", []).has({"effect": "weapon_special", "rule": "cannot_equip_weapons_above_tier_2"}):
			failures.append("Wildling tier limit rule mismatch")

	var gladiator = data.get_character("gladiator")
	if not gladiator.is_empty():
		if not data.character_can_equip_weapon("gladiator", "knife"):
			failures.append("Gladiator should be able to equip melee weapons")
		if data.character_can_equip_weapon("gladiator", "pistol"):
			failures.append("Gladiator should not be able to equip ranged weapons")
		if not gladiator.get("rules", []).has({"effect": "weapon_special", "rule": "attack_speed_plus_20_per_distinct_weapon"}):
			failures.append("Gladiator distinct weapon attack speed rule mismatch")

	var sick = data.get_character("sick")
	if not sick.is_empty():
		if int(sick.get("base_stats", {}).get("max_hp", 0)) != 12:
			failures.append("Sick max HP stat mismatch")
		if not sick.get("rules", []).has({"effect": "weapon_special", "rule": "take_1_damage_per_second_no_iframes"}):
			failures.append("Sick self-damage rule mismatch")
		if "medical_gun" not in sick.get("starting_weapon_options", []):
			failures.append("Sick should offer Medical Gun")

	var farmer = data.get_character("farmer")
	if not farmer.is_empty():
		if int(farmer.get("base_stats", {}).get("harvesting", 0)) != 20:
			failures.append("Farmer harvesting stat mismatch")
		if not farmer.get("rules", []).has({"effect": "stat_delta", "stat": "materials_dropped_percent", "value": -0.50}):
			failures.append("Farmer material drop rule mismatch")
		if "potato_thrower" not in farmer.get("starting_weapon_options", []):
			failures.append("Farmer should offer Potato Thrower")

	var ghost = data.get_character("ghost")
	if not ghost.is_empty():
		if int(ghost.get("base_stats", {}).get("armor", 0)) != -100:
			failures.append("Ghost armor stat mismatch")
		if not ghost.get("rules", []).has({"effect": "weapon_special", "rule": "dodge_cap_90_percent"}):
			failures.append("Ghost dodge cap rule mismatch")
		if ghost.get("starting_weapon_options", []) != ["ghost_flint", "ghost_axe", "ghost_scepter"]:
			failures.append("Ghost starting weapon options mismatch")

	var speedy = data.get_character("speedy")
	if not speedy.is_empty():
		if int(round(float(speedy.get("base_stats", {}).get("speed_percent", 0.0)) * 100.0)) != 30:
			failures.append("Speedy speed stat mismatch")
		if not speedy.get("rules", []).has({"effect": "weapon_special", "rule": "melee_damage_plus_1_per_2_speed_percent"}):
			failures.append("Speedy speed-to-melee rule mismatch")
		if "javelin" not in speedy.get("starting_weapon_options", []):
			failures.append("Speedy should offer Javelin")

func _check_third_character_catalog_expansion(data):
	var characters = data.get_characters(true)
	if characters.size() < 23:
		failures.append("Character catalog should include third base expansion batch")
	for character_id in ["lucky", "pacifist", "saver", "entrepreneur", "engineer", "explorer"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing third-batch character row: " + character_id)

	var lucky = data.get_character("lucky")
	if not lucky.is_empty():
		if int(lucky.get("base_stats", {}).get("luck", 0)) != 100:
			failures.append("Lucky luck stat mismatch")
		if "flute" not in lucky.get("starting_weapon_options", []):
			failures.append("Lucky should offer Flute")
		if not _has_weapon_special_rule(lucky, "material_pickup_luck_damage"):
			failures.append("Lucky pickup damage rule mismatch")

	var pacifist = data.get_character("pacifist")
	if not pacifist.is_empty():
		if pacifist.get("fixed_starting_items", []) != ["lumberjack_shirt"]:
			failures.append("Pacifist should start with Lumberjack Shirt")
		if int(pacifist.get("base_stats", {}).get("engineering", 0)) != -100:
			failures.append("Pacifist engineering stat mismatch")
		if not _has_weapon_special_rule(pacifist, "gain_0_65_material_and_xp_per_living_enemy_end_wave"):
			failures.append("Pacifist living-enemy reward rule mismatch")

	var saver = data.get_character("saver")
	if not saver.is_empty():
		if saver.get("fixed_starting_items", []) != ["piggy_bank"]:
			failures.append("Saver should start with Piggy Bank")
		if int(saver.get("base_stats", {}).get("harvesting", 0)) != 15:
			failures.append("Saver harvesting stat mismatch")
		if not saver.get("rules", []).has({"effect": "weapon_special", "rule": "damage_percent_plus_1_per_25_materials"}):
			failures.append("Saver materials-to-damage rule mismatch")

	var entrepreneur = data.get_character("entrepreneur")
	if not entrepreneur.is_empty():
		if int(round(float(entrepreneur.get("base_stats", {}).get("item_price_percent", 0.0)) * 100.0)) != -25:
			failures.append("Entrepreneur item price stat mismatch")
		if "economy" not in entrepreneur.get("wanted_tags", []):
			failures.append("Entrepreneur should want Economy items")
		if "hiking_pole" not in entrepreneur.get("starting_weapon_options", []):
			failures.append("Entrepreneur should offer Hiking Pole")

	var engineer = data.get_character("engineer")
	if not engineer.is_empty():
		if engineer.get("fixed_starting_weapons", []) != ["wrench"]:
			failures.append("Engineer should always start with Wrench")
		if "hammer" not in engineer.get("starting_weapon_options", []):
			failures.append("Engineer should offer Hammer")
		if not engineer.get("rules", []).has({"effect": "weapon_special", "rule": "structures_spawn_close_to_each_other"}):
			failures.append("Engineer structure placement rule mismatch")

	var explorer = data.get_character("explorer")
	if not explorer.is_empty():
		if explorer.get("fixed_starting_items", []) != ["lumberjack_shirt"]:
			failures.append("Explorer should start with Lumberjack Shirt")
		if int(round(float(explorer.get("base_stats", {}).get("map_size_percent", 0.0)) * 100.0)) != 33:
			failures.append("Explorer map size stat mismatch")
		if "spoon" not in explorer.get("starting_weapon_options", []):
			failures.append("Explorer should offer Spoon")

	if data.get_weapon("flute").is_empty():
		failures.append("Missing Lucky starting weapon catalog row: flute")
	var items = data.get_items(true)
	if not items.has("lumberjack_shirt"):
		failures.append("Missing fixed starting item row: lumberjack_shirt")
	if not items.has("piggy_bank"):
		failures.append("Missing fixed starting item row: piggy_bank")

func _has_weapon_special_rule(character: Dictionary, rule_name: String) -> bool:
	for rule in character.get("rules", []):
		if rule is Dictionary and rule.get("effect", "") == "weapon_special" and rule.get("rule", "") == rule_name:
			return true
	return false

func _check_fourth_character_catalog_expansion(data):
	var characters = data.get_characters(true)
	if characters.size() < 29:
		failures.append("Character catalog should include fourth base expansion batch")
	for character_id in ["doctor", "hunter", "artificer", "arms_dealer", "streamer", "cyborg"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing fourth-batch character row: " + character_id)

	var doctor = data.get_character("doctor")
	if not doctor.is_empty():
		if int(doctor.get("base_stats", {}).get("hp_regeneration", 0)) != 5:
			failures.append("Doctor HP regeneration stat mismatch")
		if not _has_weapon_special_rule(doctor, "medical_weapons_attack_speed_plus_200"):
			failures.append("Doctor medical attack speed rule mismatch")
		if doctor.get("starting_weapon_options", []) != ["scissors", "medical_gun"]:
			failures.append("Doctor starting weapon options mismatch")

	var hunter = data.get_character("hunter")
	if not hunter.is_empty():
		if int(hunter.get("base_stats", {}).get("range", 0)) != 100:
			failures.append("Hunter range stat mismatch")
		if not _has_weapon_special_rule(hunter, "damage_percent_plus_1_per_10_range"):
			failures.append("Hunter range-to-damage rule mismatch")
		if "javelin" not in hunter.get("starting_weapon_options", []):
			failures.append("Hunter should offer Javelin")

	var artificer = data.get_character("artificer")
	if not artificer.is_empty():
		if int(round(float(artificer.get("base_stats", {}).get("explosion_damage_percent", 0.0)) * 100.0)) != 175:
			failures.append("Artificer explosion damage stat mismatch")
		if not _has_weapon_special_rule(artificer, "explosion_size_plus_4_percent_per_elemental_damage"):
			failures.append("Artificer elemental-to-explosion-size rule mismatch")
		if "shredder" not in artificer.get("starting_weapon_options", []):
			failures.append("Artificer should offer Shredder")

	var arms_dealer = data.get_character("arms_dealer")
	if not arms_dealer.is_empty():
		if arms_dealer.get("fixed_starting_items", []) != ["dangerous_bunny"]:
			failures.append("Arms Dealer should start with Dangerous Bunny")
		if not _has_weapon_special_rule(arms_dealer, "destroy_weapons_entering_shop"):
			failures.append("Arms Dealer weapon destruction rule mismatch")
		if int(round(float(arms_dealer.get("base_stats", {}).get("weapon_price_percent", 0.0)) * 100.0)) != -95:
			failures.append("Arms Dealer weapon price stat mismatch")

	var streamer = data.get_character("streamer")
	if not streamer.is_empty():
		if not _has_weapon_special_rule(streamer, "materials_per_second_while_standing_still"):
			failures.append("Streamer standing-still material rule mismatch")
		if not _has_weapon_special_rule(streamer, "armor_plus_2_per_structure"):
			failures.append("Streamer structure armor rule mismatch")
		if "ghost_scepter" not in streamer.get("starting_weapon_options", []):
			failures.append("Streamer should offer Ghost Scepter")

	var cyborg = data.get_character("cyborg")
	if not cyborg.is_empty():
		if cyborg.get("fixed_starting_weapons", []) != ["minigun"]:
			failures.append("Cyborg should start with Minigun")
		if not _has_weapon_special_rule(cyborg, "convert_ranged_damage_to_engineering_halfway_wave"):
			failures.append("Cyborg halfway conversion rule mismatch")
		if "brick" not in cyborg.get("starting_weapon_options", []):
			failures.append("Cyborg should offer Brick")

	var items = data.get_items(true)
	if not items.has("dangerous_bunny"):
		failures.append("Missing fixed starting item row: dangerous_bunny")

func _check_fifth_character_catalog_expansion(data):
	var characters = data.get_characters(true)
	if characters.size() < 35:
		failures.append("Character catalog should include fifth base expansion batch")
	for character_id in ["glutton", "jack", "lich", "apprentice", "cryptid", "fisherman"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing fifth-batch character row: " + character_id)

	var glutton = data.get_character("glutton")
	if not glutton.is_empty():
		if int(glutton.get("base_stats", {}).get("luck", 0)) != 50:
			failures.append("Glutton luck stat mismatch")
		if not _has_weapon_special_rule(glutton, "consumables_explode_on_pickup_full_health"):
			failures.append("Glutton consumable explosion rule mismatch")
		if "flute" not in glutton.get("starting_weapon_options", []):
			failures.append("Glutton should offer Flute")

	var jack = data.get_character("jack")
	if not jack.is_empty():
		if int(round(float(jack.get("base_stats", {}).get("enemy_health_percent", 0.0)) * 100.0)) != 175:
			failures.append("Jack enemy health stat mismatch")
		if not _has_weapon_special_rule(jack, "damage_plus_125_percent_against_bosses_and_elites"):
			failures.append("Jack boss/elite damage rule mismatch")
		if "spiky_shield" not in jack.get("starting_weapon_options", []):
			failures.append("Jack should offer Spiky Shield")

	var lich = data.get_character("lich")
	if not lich.is_empty():
		if int(lich.get("base_stats", {}).get("hp_regeneration", 0)) != 10:
			failures.append("Lich HP regeneration stat mismatch")
		if not _has_weapon_special_rule(lich, "deal_max_hp_damage_when_healing"):
			failures.append("Lich healing damage rule mismatch")
		if "medical_gun" not in lich.get("starting_weapon_options", []):
			failures.append("Lich should offer Medical Gun")

	var apprentice = data.get_character("apprentice")
	if not apprentice.is_empty():
		if not _has_weapon_special_rule(apprentice, "gain_stats_on_level_up"):
			failures.append("Apprentice level-up stat rule mismatch")
		if not apprentice.get("rules", []).has({"effect": "stat_delta", "stat": "xp_gain_percent", "value": -0.25}):
			failures.append("Apprentice XP gain stat mismatch")
		if "brick" not in apprentice.get("starting_weapon_options", []):
			failures.append("Apprentice should offer Brick")

	var cryptid = data.get_character("cryptid")
	if not cryptid.is_empty():
		if int(cryptid.get("base_stats", {}).get("range", 0)) != -100:
			failures.append("Cryptid range stat mismatch")
		if not _has_weapon_special_rule(cryptid, "gain_12_material_and_xp_per_living_tree_end_wave"):
			failures.append("Cryptid living-tree reward rule mismatch")
		if "sickle" not in cryptid.get("starting_weapon_options", []):
			failures.append("Cryptid should offer Sickle")

	var fisherman = data.get_character("fisherman")
	if not fisherman.is_empty():
		if int(fisherman.get("base_stats", {}).get("harvesting", 0)) != 20:
			failures.append("Fisherman harvesting stat mismatch")
		if not _has_weapon_special_rule(fisherman, "shops_always_sell_bait"):
			failures.append("Fisherman bait shop rule mismatch")
		if "javelin" not in fisherman.get("starting_weapon_options", []):
			failures.append("Fisherman should offer Javelin")

	var items = data.get_items(true)
	if not items.has("bait"):
		failures.append("Missing Fisherman core item row: bait")
	if not items.has("spicy_sauce"):
		failures.append("Missing Glutton unlock item row: spicy_sauce")

func _check_sixth_character_catalog_expansion(data):
	var characters = data.get_characters(true)
	if characters.size() < 41:
		failures.append("Character catalog should include sixth base expansion batch")
	for character_id in ["golem", "king", "renegade", "one_armed", "bull", "soldier"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing sixth-batch character row: " + character_id)

	var golem = data.get_character("golem")
	if not golem.is_empty():
		if int(golem.get("base_stats", {}).get("max_hp", 0)) != 20:
			failures.append("Golem max HP stat mismatch")
		if not _has_weapon_special_rule(golem, "cannot_heal_in_any_way"):
			failures.append("Golem no-healing rule mismatch")
		if "spiky_shield" not in golem.get("starting_weapon_options", []):
			failures.append("Golem should offer Spiky Shield")

	var king = data.get_character("king")
	if not king.is_empty():
		if int(king.get("base_stats", {}).get("luck", 0)) != 50:
			failures.append("King luck stat mismatch")
		if not _has_weapon_special_rule(king, "starting_weapon_tier_2"):
			failures.append("King tier-2 starting weapon rule mismatch")
		if "grenade_launcher" not in king.get("starting_weapon_options", []):
			failures.append("King should offer Grenade Launcher")

	var renegade = data.get_character("renegade")
	if not renegade.is_empty():
		if int(renegade.get("base_stats", {}).get("projectiles", 0)) != 2:
			failures.append("Renegade projectile stat mismatch")
		if data.character_can_equip_weapon("renegade", "knife"):
			failures.append("Renegade should not be able to equip melee weapons")
		if not data.character_can_equip_weapon("renegade", "pistol"):
			failures.append("Renegade should be able to equip ranged weapons")

	var one_armed = data.get_character("one_armed")
	if not one_armed.is_empty():
		if int(one_armed.get("base_stats", {}).get("attack_speed_percent", 0)) != 200:
			failures.append("One Armed attack speed stat mismatch")
		if not _has_weapon_special_rule(one_armed, "max_1_weapon"):
			failures.append("One Armed weapon limit rule mismatch")
		if "javelin" not in one_armed.get("starting_weapon_options", []):
			failures.append("One Armed should offer Javelin")

	var bull = data.get_character("bull")
	if not bull.is_empty():
		if not bull.get("starting_weapon_options", []).is_empty():
			failures.append("Bull should not offer starting weapons")
		if not _has_weapon_special_rule(bull, "explode_when_taking_damage"):
			failures.append("Bull damage explosion rule mismatch")
		if not bull.get("rules", []).has({"effect": "forbid_weapon_group", "group": "melee"}):
			failures.append("Bull melee weapon restriction mismatch")
		if not bull.get("rules", []).has({"effect": "forbid_weapon_group", "group": "ranged"}):
			failures.append("Bull ranged weapon restriction mismatch")

	var soldier = data.get_character("soldier")
	if not soldier.is_empty():
		if int(round(float(soldier.get("base_stats", {}).get("pickup_range_percent", 0.0)) * 100.0)) != 200:
			failures.append("Soldier pickup range stat mismatch")
		if not _has_weapon_special_rule(soldier, "cannot_attack_while_moving"):
			failures.append("Soldier movement attack rule mismatch")
		if "nuclear_launcher" != soldier.get("unlocks", [])[0].get("id", ""):
			failures.append("Soldier unlock reward mismatch")

func _check_seventh_character_catalog_expansion(data):
	var characters = data.get_characters(true)
	if characters.size() < 47:
		failures.append("Character catalog should include seventh base expansion batch")
	for character_id in ["masochist", "knight", "demon", "baby", "vagabond", "technomage"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing seventh-batch character row: " + character_id)

	var masochist = data.get_character("masochist")
	if not masochist.is_empty():
		if int(masochist.get("base_stats", {}).get("max_hp", 0)) != 10:
			failures.append("Masochist max HP stat mismatch")
		if int(masochist.get("base_stats", {}).get("hp_regeneration", 0)) != 20:
			failures.append("Masochist HP regeneration stat mismatch")
		if int(masochist.get("base_stats", {}).get("armor", 0)) != 8:
			failures.append("Masochist armor stat mismatch")
		if not _has_weapon_special_rule(masochist, "damage_percent_plus_5_until_wave_end_when_taking_damage"):
			failures.append("Masochist damage-on-hit rule mismatch")
		if "spiky_shield" not in masochist.get("starting_weapon_options", []):
			failures.append("Masochist should offer Spiky Shield")

	var knight = data.get_character("knight")
	if not knight.is_empty():
		if int(knight.get("base_stats", {}).get("armor", 0)) != 3:
			failures.append("Knight armor stat mismatch")
		if data.character_can_equip_weapon("knight", "pistol"):
			failures.append("Knight should not be able to equip ranged weapons")
		if data.character_can_equip_weapon("knight", "crossbow"):
			failures.append("Knight should not be able to equip non-gun ranged weapons")
		if not data.character_can_equip_weapon("knight", "sword"):
			failures.append("Knight should be able to equip Sword")
		if not _has_weapon_special_rule(knight, "melee_damage_plus_2_per_1_armor"):
			failures.append("Knight armor-to-melee-damage rule mismatch")
		if not _has_weapon_special_rule(knight, "can_only_equip_tier_2_weapons_or_above"):
			failures.append("Knight tier-2-or-above weapon rule mismatch")

	var demon = data.get_character("demon")
	if not demon.is_empty():
		if not _has_weapon_special_rule(demon, "buy_items_with_max_hp"):
			failures.append("Demon max-HP shop currency rule mismatch")
		if not _has_weapon_special_rule(demon, "convert_half_materials_to_max_hp_end_wave"):
			failures.append("Demon end-wave materials conversion rule mismatch")
		if demon.get("unlocks", []).is_empty() or demon.get("unlocks", [])[0].get("id", "") != "obliterator":
			failures.append("Demon unlock reward mismatch")

	var baby = data.get_character("baby")
	if not baby.is_empty():
		if int(baby.get("base_stats", {}).get("harvesting", 0)) != 12:
			failures.append("Baby harvesting stat mismatch")
		if int(round(float(baby.get("base_stats", {}).get("item_price_percent", 0.0)) * 100.0)) != -20:
			failures.append("Baby item price stat mismatch")
		if int(round(float(baby.get("base_stats", {}).get("xp_required_multiplier", 0.0)) * 100.0)) != 230:
			failures.append("Baby XP required stat mismatch")
		if not _has_weapon_special_rule(baby, "gain_weapon_slot_on_level_up_instead_of_stat_upgrade"):
			failures.append("Baby level-up weapon-slot rule mismatch")
		if not _has_weapon_special_rule(baby, "shops_always_sell_at_least_1_weapon"):
			failures.append("Baby guaranteed weapon shop rule mismatch")
		if baby.get("unlocks", []).is_empty() or baby.get("unlocks", [])[0].get("id", "") != "celery_tea":
			failures.append("Baby unlock reward mismatch")

	var vagabond = data.get_character("vagabond")
	if not vagabond.is_empty():
		if int(vagabond.get("base_stats", {}).get("armor", 0)) != -5:
			failures.append("Vagabond armor stat mismatch")
		if int(round(float(vagabond.get("base_stats", {}).get("dodge", 0.0)) * 100.0)) != -5:
			failures.append("Vagabond dodge stat mismatch")
		if not _has_weapon_special_rule(vagabond, "weapons_contribute_to_other_weapon_class_bonuses"):
			failures.append("Vagabond weapon class contribution rule mismatch")
		if not _has_weapon_special_rule(vagabond, "cannot_equip_duplicate_weapons"):
			failures.append("Vagabond duplicate weapon restriction mismatch")
		if not _has_weapon_special_rule(vagabond, "hide_lower_tier_owned_weapons_in_shop"):
			failures.append("Vagabond lower-tier shop filter rule mismatch")
		if "lute" not in vagabond.get("starting_weapon_options", []):
			failures.append("Vagabond should offer Lute")
		if vagabond.get("unlocks", []).is_empty() or vagabond.get("unlocks", [])[0].get("id", "") != "jelly":
			failures.append("Vagabond unlock reward mismatch")

	var technomage = data.get_character("technomage")
	if not technomage.is_empty():
		if technomage.get("fixed_starting_items", []) != ["turret", "turret"]:
			failures.append("Technomage should start with two Turrets")
		if int(round(float(technomage.get("base_stats", {}).get("xp_required_multiplier", 0.0)) * 100.0)) != 175:
			failures.append("Technomage XP required stat mismatch")
		if not _has_weapon_special_rule(technomage, "structure_attack_speed_plus_5_percent_per_permanent_elemental_damage"):
			failures.append("Technomage structure attack speed rule mismatch")
		if not _has_weapon_special_rule(technomage, "elemental_damage_plus_2_per_structure"):
			failures.append("Technomage structure-to-elemental rule mismatch")
		if technomage.get("unlocks", []).is_empty() or technomage.get("unlocks", [])[0].get("id", "") != "particle_accelerator":
			failures.append("Technomage unlock reward mismatch")

	var items = data.get_items(true)
	if not items.has("turret"):
		failures.append("Missing Technomage starting item row: turret")
	if not items.has("celery_tea"):
		failures.append("Missing Baby unlock item row: celery_tea")
	if not items.has("jelly"):
		failures.append("Missing Vagabond unlock item row: jelly")
	if data.get_weapon("particle_accelerator").is_empty():
		failures.append("Missing Technomage unlock weapon row: particle_accelerator")

func _check_complete_character_catalog(data):
	var characters = data.get_characters(true)
	if characters.size() < 62:
		failures.append("Character catalog should include all 62 reference rows")
	for character_id in ["vampire", "sailor", "curious", "builder", "captain", "creature", "chef", "druid", "dwarf", "gangster", "diver", "hiker", "buccaneer", "ogre", "romantic"]:
		if data.get_character(character_id).is_empty():
			failures.append("Missing final character row: " + character_id)

	var vampire = data.get_character("vampire")
	if not vampire.is_empty():
		if int(round(float(vampire.get("base_stats", {}).get("damage_percent", 0.0)) * 100.0)) != -60:
			failures.append("Vampire damage stat mismatch")
		if int(vampire.get("base_stats", {}).get("hp_regeneration", 0)) != -100:
			failures.append("Vampire HP regeneration stat mismatch")
		if not _has_weapon_special_rule(vampire, "damage_percent_plus_2_per_missing_health_percent"):
			failures.append("Vampire missing-health damage rule mismatch")

	var sailor = data.get_character("sailor")
	if not sailor.is_empty():
		if int(sailor.get("base_stats", {}).get("curse", 0)) != 25:
			failures.append("Sailor curse stat mismatch")
		if not _has_weapon_special_rule(sailor, "naval_weapons_damage_plus_200_percent_against_cursed_enemies"):
			failures.append("Sailor cursed naval damage rule mismatch")
		if "anchor" not in sailor.get("starting_weapon_options", []):
			failures.append("Sailor should offer Anchor")

	var curious = data.get_character("curious")
	if not curious.is_empty():
		if curious.get("fixed_starting_items", []) != ["spyglass"]:
			failures.append("Curious should start with Spyglass")
		if int(round(float(curious.get("base_stats", {}).get("enemy_health_percent", 0.0)) * 100.0)) != 25:
			failures.append("Curious enemy health stat mismatch")
		if not _has_weapon_special_rule(curious, "two_additional_loot_aliens_every_wave"):
			failures.append("Curious loot alien rule mismatch")

	var builder = data.get_character("builder")
	if not builder.is_empty():
		if builder.get("fixed_starting_items", []) != ["builders_turret"]:
			failures.append("Builder should start with Builder's Turret")
		if int(builder.get("base_stats", {}).get("harvesting", 0)) != 20:
			failures.append("Builder harvesting stat mismatch")
		if not _has_weapon_special_rule(builder, "uncollected_materials_convert_to_structure_stats_end_wave"):
			failures.append("Builder uncollected-material conversion rule mismatch")

	var captain = data.get_character("captain")
	if not captain.is_empty():
		if int(round(float(captain.get("base_stats", {}).get("xp_required_multiplier", 0.0)) * 100.0)) != 300:
			failures.append("Captain XP required stat mismatch")
		if not _has_weapon_special_rule(captain, "xp_gain_plus_60_percent_per_free_weapon_slot"):
			failures.append("Captain free weapon slot XP rule mismatch")
		if captain.get("unlocks", []).is_empty() or captain.get("unlocks", [])[0].get("id", "") != "captains_sword":
			failures.append("Captain unlock reward mismatch")

	var creature = data.get_character("creature")
	if not creature.is_empty():
		if creature.get("fixed_starting_items", []) != ["fish_hook"]:
			failures.append("Creature should start with cursed Fish Hook")
		if not _has_weapon_special_rule(creature, "weapon_damage_additionally_scales_with_35_percent_curse"):
			failures.append("Creature curse damage scaling rule mismatch")
		if int(creature.get("base_stats", {}).get("range_end_wave_delta", 0)) != -10:
			failures.append("Creature end-wave range stat mismatch")

	var chef = data.get_character("chef")
	if not chef.is_empty():
		if chef.get("fixed_starting_items", []) != ["scared_sausage"]:
			failures.append("Chef should start with Scared Sausage")
		if int(chef.get("base_stats", {}).get("luck", 0)) != 35:
			failures.append("Chef luck stat mismatch")
		if not _has_weapon_special_rule(chef, "non_elemental_damage_plus_200_percent_against_burning_targets"):
			failures.append("Chef burning target damage rule mismatch")

	var druid = data.get_character("druid")
	if not druid.is_empty():
		if int(druid.get("base_stats", {}).get("max_hp", 0)) != 5:
			failures.append("Druid max HP stat mismatch")
		if int(druid.get("base_stats", {}).get("luck", 0)) != 15:
			failures.append("Druid luck stat mismatch")
		if not _has_weapon_special_rule(druid, "fruit_drop_extra_chance_3_percent"):
			failures.append("Druid fruit drop rule mismatch")

	var dwarf = data.get_character("dwarf")
	if not dwarf.is_empty():
		if data.character_can_equip_weapon("dwarf", "crossbow"):
			failures.append("Dwarf should not be able to equip ranged weapons")
		if not _has_weapon_special_rule(dwarf, "engineering_plus_1_on_6_direct_melee_kills"):
			failures.append("Dwarf direct melee kill engineering rule mismatch")
		if "hammer" not in dwarf.get("starting_weapon_options", []):
			failures.append("Dwarf should offer Hammer")

	var gangster = data.get_character("gangster")
	if not gangster.is_empty():
		if int(round(float(gangster.get("base_stats", {}).get("item_price_percent", 0.0)) * 100.0)) != 20:
			failures.append("Gangster item price stat mismatch")
		if not _has_weapon_special_rule(gangster, "can_steal_1_item_per_shop"):
			failures.append("Gangster steal rule mismatch")
		if not _has_weapon_special_rule(gangster, "cannot_lock_items"):
			failures.append("Gangster lock restriction mismatch")

	var diver = data.get_character("diver")
	if not diver.is_empty():
		if diver.get("fixed_starting_weapons", []) != ["harpoon_gun"]:
			failures.append("Diver should start with Harpoon Gun")
		if int(diver.get("base_stats", {}).get("ranged_damage", 0)) != -100:
			failures.append("Diver ranged damage stat mismatch")
		if not _has_weapon_special_rule(diver, "precise_weapons_crit_damage_plus_200_percent"):
			failures.append("Diver precise crit damage rule mismatch")

	var hiker = data.get_character("hiker")
	if not hiker.is_empty():
		if int(round(float(hiker.get("base_stats", {}).get("speed_percent", 0.0)) * 100.0)) != -5:
			failures.append("Hiker speed stat mismatch")
		if not _has_weapon_special_rule(hiker, "gain_5_materials_per_10_steps_during_wave"):
			failures.append("Hiker step material rule mismatch")
		if "hiking_pole" not in hiker.get("starting_weapon_options", []):
			failures.append("Hiker should offer Hiking Pole")

	var buccaneer = data.get_character("buccaneer")
	if not buccaneer.is_empty():
		if int(buccaneer.get("base_stats", {}).get("attack_speed_percent", 0)) != -100:
			failures.append("Buccaneer attack speed stat mismatch")
		if not _has_weapon_special_rule(buccaneer, "picked_up_materials_have_double_value"):
			failures.append("Buccaneer double material value rule mismatch")
		if "flute" not in buccaneer.get("starting_weapon_options", []):
			failures.append("Buccaneer should offer Flute")

	var ogre = data.get_character("ogre")
	if not ogre.is_empty():
		if int(ogre.get("base_stats", {}).get("melee_damage", 0)) != 10:
			failures.append("Ogre melee damage stat mismatch")
		if data.character_can_equip_weapon("ogre", "crossbow"):
			failures.append("Ogre should not be able to equip ranged weapons")
		if not _has_weapon_special_rule(ogre, "overkill_damage_explodes_enemy"):
			failures.append("Ogre overkill explosion rule mismatch")

	var romantic = data.get_character("romantic")
	if not romantic.is_empty():
		if int(romantic.get("base_stats", {}).get("melee_weapon_range", 0)) != 50:
			failures.append("Romantic melee weapon range stat mismatch")
		if not _has_weapon_special_rule(romantic, "low_health_hit_charm_chance"):
			failures.append("Romantic charm rule mismatch")
		if "flute" not in romantic.get("starting_weapon_options", []):
			failures.append("Romantic should offer Flute")

	var items = data.get_items(true)
	for item_id in ["decomposing_flesh", "treasure_map", "pearl", "spyglass", "builders_turret", "lighthouse", "fish_hook", "barnacle", "cauldron", "starfish", "scarf", "eyepatch"]:
		if not items.has(item_id):
			failures.append("Missing final character item row: " + item_id)
	if not data.item_tags.has("curse"):
		failures.append("Missing Curse item tag")

func _check_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 37:
		failures.append("Item catalog should include the first foundational stat batch")
	for item_id in ["acid", "alien_baby", "alien_magic", "alien_worm", "bag", "bat", "beanie", "big_arms", "broken_mouth", "cake", "coffee", "coupon", "fertilizer", "fin"]:
		if not items.has(item_id):
			failures.append("Missing foundational item row: " + item_id)
	if not data.item_tags.has("knockback"):
		failures.append("Missing Knockback item tag")

	var acid: Dictionary = items.get("acid", {})
	if not acid.is_empty():
		if int(acid.get("tier", 0)) != 2 or int(acid.get("base_price", 0)) != 65:
			failures.append("Acid tier/price mismatch")
		if not _has_stat_delta(acid.get("effects", []), "max_hp", 8.0):
			failures.append("Acid max HP effect mismatch")
		if "knockback" not in acid.get("tags", []):
			failures.append("Acid should carry Knockback tag")

	var big_arms: Dictionary = items.get("big_arms", {})
	if not big_arms.is_empty():
		if big_arms.get("unlocked_by", {}).get("condition", "") != "win_with_generalist":
			failures.append("Big Arms unlock condition mismatch")
		if not _has_stat_delta(big_arms.get("effects", []), "melee_damage", 12.0):
			failures.append("Big Arms melee damage effect mismatch")
		if not _has_stat_delta(big_arms.get("effects", []), "ranged_damage", 6.0):
			failures.append("Big Arms ranged damage effect mismatch")

	var coupon: Dictionary = items.get("coupon", {})
	if not coupon.is_empty():
		if int(coupon.get("limit", 0)) != 5:
			failures.append("Coupon limit mismatch")
		if not _has_stat_delta(coupon.get("effects", []), "item_price_percent", -0.05):
			failures.append("Coupon item price effect mismatch")

func _has_stat_delta(effects: Array, stat: String, expected_value: float) -> bool:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		if effect.get("effect", "") != "stat_delta":
			continue
		if effect.get("stat", "") != stat:
			continue
		if abs(float(effect.get("value", 0.0)) - expected_value) < 0.001:
			return true
	return false

func _check_second_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 53:
		failures.append("Item catalog should include the second foundational stat batch")
	for item_id in ["butterfly", "charcoal", "clover", "compass", "cyclops_worm", "defective_steroids", "diploma", "duct_tape", "dynamite", "energy_bracelet", "exoskeleton", "explosive_shells", "glasses", "goat_skull", "hedgehog", "helmet"]:
		if not items.has(item_id):
			failures.append("Missing second foundational item row: " + item_id)

	var compass: Dictionary = items.get("compass", {})
	if not compass.is_empty():
		if compass.get("unlocked_by", {}).get("condition", "") != "win_with_explorer":
			failures.append("Compass unlock condition mismatch")
		if not _has_stat_delta(compass.get("effects", []), "engineering", 3.0):
			failures.append("Compass engineering effect mismatch")

	var explosive_shells: Dictionary = items.get("explosive_shells", {})
	if not explosive_shells.is_empty():
		if explosive_shells.get("unlocked_by", {}).get("condition", "") != "win_with_artificer":
			failures.append("Explosive Shells unlock condition mismatch")
		if not _has_stat_delta(explosive_shells.get("effects", []), "explosion_damage_percent", 0.60):
			failures.append("Explosive Shells damage effect mismatch")
		if not _has_stat_delta(explosive_shells.get("effects", []), "explosion_size_percent", 0.15):
			failures.append("Explosive Shells size effect mismatch")

	var exoskeleton: Dictionary = items.get("exoskeleton", {})
	if not exoskeleton.is_empty():
		if not _has_stat_delta(exoskeleton.get("effects", []), "armor", 3.0):
			failures.append("Exoskeleton armor effect mismatch")
		if not _has_stat_delta(exoskeleton.get("effects", []), "speed_percent", 0.05):
			failures.append("Exoskeleton speed effect mismatch")

func _check_third_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 70:
		failures.append("Item catalog should include the third foundational stat batch")
	for item_id in ["injection", "leather_vest", "lens", "little_muscley_dude", "lost_duck", "medal", "mushroom", "plant", "pencil", "propeller_hat", "scar", "scope", "shady_potion", "snail", "sunglasses", "toxic_sludge", "weird_food"]:
		if not items.has(item_id):
			failures.append("Missing third foundational item row: " + item_id)

	var snail: Dictionary = items.get("snail", {})
	if not snail.is_empty():
		if int(snail.get("limit", 0)) != 1:
			failures.append("Snail limit mismatch")
		if snail.get("unlocked_by", {}).get("condition", "") != "win_with_old":
			failures.append("Snail unlock condition mismatch")
		if not _has_stat_delta(snail.get("effects", []), "enemy_speed_percent", -0.08):
			failures.append("Snail enemy speed effect mismatch")

	var scope: Dictionary = items.get("scope", {})
	if not scope.is_empty():
		if not _has_stat_delta(scope.get("effects", []), "ranged_damage", 2.0):
			failures.append("Scope ranged damage effect mismatch")
		if not _has_stat_delta(scope.get("effects", []), "range", 25.0):
			failures.append("Scope range effect mismatch")

	var weird_food: Dictionary = items.get("weird_food", {})
	if not weird_food.is_empty():
		if not _has_stat_delta(weird_food.get("effects", []), "consumable_heal", 2.0):
			failures.append("Weird Food consumable heal effect mismatch")
		if not _has_stat_delta(weird_food.get("effects", []), "dodge", -0.02):
			failures.append("Weird Food dodge effect mismatch")

func _check_fourth_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 81:
		failures.append("Item catalog should include the fourth foundational stat batch")
	for item_id in ["wheelbarrow", "white_flag", "wings", "whetstone", "ritual", "sharp_bullet", "small_magazine", "tentacle", "toolbox", "triangle_of_power", "ugly tooth"]:
		var normalized_id = str(item_id).replace(" ", "_")
		if not items.has(normalized_id):
			failures.append("Missing fourth foundational item row: " + normalized_id)

	var scared_sausage: Dictionary = items.get("scared_sausage", {})
	if not scared_sausage.is_empty():
		if int(scared_sausage.get("base_price", 0)) != 25:
			failures.append("Scared Sausage base price should match reference data")
		var sausage_limit = scared_sausage.get("limit", null)
		if sausage_limit == null or int(sausage_limit) != 4:
			failures.append("Scared Sausage limit should match reference data")

	var sharp_bullet: Dictionary = items.get("sharp_bullet", {})
	if not sharp_bullet.is_empty():
		if int(sharp_bullet.get("limit", 0)) != 1:
			failures.append("Sharp Bullet limit mismatch")
		if not _has_stat_delta(sharp_bullet.get("effects", []), "damage_percent", -0.05):
			failures.append("Sharp Bullet damage penalty mismatch")
		if not _has_stat_delta(sharp_bullet.get("effects", []), "knockback", -3.0):
			failures.append("Sharp Bullet knockback penalty mismatch")

	var tentacle: Dictionary = items.get("tentacle", {})
	if not tentacle.is_empty():
		if tentacle.get("unlocked_by", {}).get("condition", "") != "win_with_lich":
			failures.append("Tentacle unlock condition mismatch")
		if int(tentacle.get("limit", 0)) != 5:
			failures.append("Tentacle limit mismatch")

func _check_fifth_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 103:
		failures.append("Item catalog should include the fifth foundational stat batch")
	for item_id in ["alloy", "bean_teacher", "black_belt", "blindfold", "blood_leech", "book", "bowler_hat", "boxing_glove", "cape", "claw_tree", "cog", "gentle_alien", "gnome", "lemonade", "lucky_charm", "mastery", "missile", "night_goggles", "octopus", "peaceful_bee", "plastic_explosive", "warrior_helmet"]:
		if not items.has(item_id):
			failures.append("Missing fifth foundational item row: " + item_id)

	var alloy: Dictionary = items.get("alloy", {})
	if not alloy.is_empty():
		if not _has_stat_delta(alloy.get("effects", []), "engineering", 3.0):
			failures.append("Alloy engineering effect mismatch")
		if not _has_stat_delta(alloy.get("effects", []), "crit_chance", 0.05):
			failures.append("Alloy crit chance effect mismatch")

	var bowler_hat: Dictionary = items.get("bowler_hat", {})
	if not bowler_hat.is_empty():
		if bowler_hat.get("unlocked_by", {}).get("condition", "") != "win_with_entrepreneur":
			failures.append("Bowler Hat unlock condition mismatch")
		if not _has_stat_delta(bowler_hat.get("effects", []), "harvesting", 18.0):
			failures.append("Bowler Hat harvesting effect mismatch")

	var night_goggles: Dictionary = items.get("night_goggles", {})
	if not night_goggles.is_empty():
		if night_goggles.get("unlocked_by", {}).get("condition", "") != "win_with_ranger":
			failures.append("Night Goggles unlock condition mismatch")
		if not _has_stat_delta(night_goggles.get("effects", []), "crit_chance", 0.15):
			failures.append("Night Goggles crit chance effect mismatch")

	var gnome: Dictionary = items.get("gnome", {})
	if not gnome.is_empty():
		if gnome.get("unlocked_by", {}).get("condition", "") != "win_with_bull":
			failures.append("Gnome unlock condition mismatch")
		if not _has_stat_delta(gnome.get("effects", []), "pickup_range_percent", -0.20):
			failures.append("Gnome pickup range penalty mismatch")

func _check_sixth_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 125:
		failures.append("Item catalog should include the sixth foundational stat batch")
	for item_id in ["banner", "boiling_water", "campfire", "candle", "clockwork_wasp", "fresh_meat", "fuel_tank", "gambling_token", "glass_cannon", "gummy_berserker", "head_injury", "heavy_bullets", "insanity", "jet_pack", "little_frog", "mammoth", "metal_plate", "mouse", "mutation", "panda", "poisonous_tonic", "reinforced_steel"]:
		if not items.has(item_id):
			failures.append("Missing sixth foundational item row: " + item_id)

	var banner: Dictionary = items.get("banner", {})
	if not banner.is_empty():
		if not _has_stat_delta(banner.get("effects", []), "attack_speed_percent", 0.10):
			failures.append("Banner attack speed effect mismatch")
		if not _has_stat_delta(banner.get("effects", []), "knockback", -5.0):
			failures.append("Banner knockback effect mismatch")

	var candle: Dictionary = items.get("candle", {})
	if not candle.is_empty():
		if int(candle.get("limit", 0)) != 1:
			failures.append("Candle limit mismatch")
		if not _has_stat_delta(candle.get("effects", []), "enemies_percent", -0.10):
			failures.append("Candle enemies effect mismatch")

	var clockwork_wasp: Dictionary = items.get("clockwork_wasp", {})
	if not clockwork_wasp.is_empty():
		if not _has_stat_delta(clockwork_wasp.get("effects", []), "structure_attack_speed_percent", 0.10):
			failures.append("Clockwork Wasp structure attack speed effect mismatch")

	var heavy_bullets: Dictionary = items.get("heavy_bullets", {})
	if not heavy_bullets.is_empty():
		if not _has_stat_delta(heavy_bullets.get("effects", []), "ranged_damage", 5.0):
			failures.append("Heavy Bullets ranged damage effect mismatch")
		if not _has_stat_delta(heavy_bullets.get("effects", []), "crit_chance", -0.05):
			failures.append("Heavy Bullets crit chance effect mismatch")

	var mouse: Dictionary = items.get("mouse", {})
	if not mouse.is_empty():
		if int(mouse.get("limit", 0)) != 5:
			failures.append("Mouse limit mismatch")
		if not _has_stat_delta(mouse.get("effects", []), "enemies_percent", 0.10):
			failures.append("Mouse enemies effect mismatch")

	var poisonous_tonic: Dictionary = items.get("poisonous_tonic", {})
	if not poisonous_tonic.is_empty():
		if not _has_stat_delta(poisonous_tonic.get("effects", []), "attack_speed_percent", 0.10):
			failures.append("Poisonous Tonic attack speed effect mismatch")
		if not _has_stat_delta(poisonous_tonic.get("effects", []), "crit_chance", 0.05):
			failures.append("Poisonous Tonic crit chance effect mismatch")

	var reinforced_steel: Dictionary = items.get("reinforced_steel", {})
	if not reinforced_steel.is_empty():
		if not _has_stat_delta(reinforced_steel.get("effects", []), "engineering", 3.0):
			failures.append("Reinforced Steel engineering effect mismatch")

func _check_seventh_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 147:
		failures.append("Item catalog should include the seventh foundational stat batch")
	for item_id in ["adrenaline", "alien_eyes", "baby_elephant", "baby_gecko", "baby_with_a_beard", "bandana", "barricade", "blood_donation", "crown", "cute_monkey", "hunting_trophy", "landmines", "metal_detector", "pumpkin", "recycling_machine", "sad_tomato", "shmoop", "statue", "tardigrade", "terrified_onion", "tractor", "wheat"]:
		if not items.has(item_id):
			failures.append("Missing seventh foundational item row: " + item_id)

	var adrenaline: Dictionary = items.get("adrenaline", {})
	if not adrenaline.is_empty():
		if int(adrenaline.get("limit", 0)) != 1:
			failures.append("Adrenaline limit mismatch")
		if not _has_stat_delta(adrenaline.get("effects", []), "dodge", 0.05):
			failures.append("Adrenaline dodge effect mismatch")

	var baby_gecko: Dictionary = items.get("baby_gecko", {})
	if not baby_gecko.is_empty():
		if int(baby_gecko.get("limit", 0)) != 4:
			failures.append("Baby Gecko limit mismatch")
		if not _has_stat_delta(baby_gecko.get("effects", []), "range", 10.0):
			failures.append("Baby Gecko range effect mismatch")

	var hunting_trophy: Dictionary = items.get("hunting_trophy", {})
	if not hunting_trophy.is_empty():
		if int(hunting_trophy.get("limit", 0)) != 3:
			failures.append("Hunting Trophy limit mismatch")
		if hunting_trophy.get("unlocked_by", {}).get("condition", "") != "win_with_crazy":
			failures.append("Hunting Trophy unlock condition mismatch")

	var metal_detector: Dictionary = items.get("metal_detector", {})
	if not metal_detector.is_empty():
		if int(metal_detector.get("limit", 0)) != 20:
			failures.append("Metal Detector limit mismatch")
		if not _has_stat_delta(metal_detector.get("effects", []), "luck", 6.0):
			failures.append("Metal Detector luck effect mismatch")
		if not _has_stat_delta(metal_detector.get("effects", []), "engineering", 2.0):
			failures.append("Metal Detector engineering effect mismatch")

	var sad_tomato: Dictionary = items.get("sad_tomato", {})
	if not sad_tomato.is_empty():
		if int(sad_tomato.get("limit", 0)) != 1:
			failures.append("Sad Tomato limit mismatch")
		if not _has_stat_delta(sad_tomato.get("effects", []), "hp_regeneration", 8.0):
			failures.append("Sad Tomato HP regeneration effect mismatch")

	var wheat: Dictionary = items.get("wheat", {})
	if not wheat.is_empty():
		if wheat.get("unlocked_by", {}).get("condition", "") != "win_with_farmer":
			failures.append("Wheat unlock condition mismatch")
		if not _has_stat_delta(wheat.get("effects", []), "harvesting", 10.0):
			failures.append("Wheat harvesting effect mismatch")

func _check_eighth_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 169:
		failures.append("Item catalog should include the eighth foundational stat batch")
	for item_id in ["chameleon", "coil", "cyberball", "fruit_basket", "garden", "ghost_outfit", "medikit", "peacock", "padding", "power_generator", "regeneration_potion", "rip_and_tear", "riposte", "silver_bullet", "snowball", "spider", "tree", "vigilante_ring", "wandering_bot", "weird_ghost", "wisdom", "wolf_helmet"]:
		if not items.has(item_id):
			failures.append("Missing eighth foundational item row: " + item_id)

	var coil: Dictionary = items.get("coil", {})
	if not coil.is_empty():
		if int(coil.get("limit", 0)) != 3:
			failures.append("Coil limit mismatch")
		if not _has_stat_delta(coil.get("effects", []), "knockback", 5.0):
			failures.append("Coil knockback effect mismatch")

	var ghost_outfit: Dictionary = items.get("ghost_outfit", {})
	if not ghost_outfit.is_empty():
		if int(ghost_outfit.get("limit", 0)) != 1:
			failures.append("Ghost Outfit limit mismatch")
		if not _has_stat_delta(ghost_outfit.get("effects", []), "dodge", 0.10):
			failures.append("Ghost Outfit dodge effect mismatch")

	var medikit: Dictionary = items.get("medikit", {})
	if not medikit.is_empty():
		if medikit.get("unlocked_by", {}).get("condition", "") != "win_with_doctor":
			failures.append("Medikit unlock condition mismatch")
		if not _has_stat_delta(medikit.get("effects", []), "hp_regeneration", 10.0):
			failures.append("Medikit HP regeneration effect mismatch")

	var padding: Dictionary = items.get("padding", {})
	if not padding.is_empty():
		if padding.get("unlocked_by", {}).get("condition", "") != "win_with_saver":
			failures.append("Padding unlock condition mismatch")
		if not _has_stat_delta(padding.get("effects", []), "max_hp", 3.0):
			failures.append("Padding max HP effect mismatch")

	var rip_and_tear: Dictionary = items.get("rip_and_tear", {})
	if not rip_and_tear.is_empty():
		if int(rip_and_tear.get("limit", 0)) != 5:
			failures.append("Rip and Tear limit mismatch")
		if rip_and_tear.get("unlocked_by", {}).get("condition", "") != "win_with_loud":
			failures.append("Rip and Tear unlock condition mismatch")
		if not _has_stat_delta(rip_and_tear.get("effects", []), "crit_chance", -0.05):
			failures.append("Rip and Tear crit chance effect mismatch")

	var spider: Dictionary = items.get("spider", {})
	if not spider.is_empty():
		if spider.get("unlocked_by", {}).get("condition", "") != "win_with_gladiator":
			failures.append("Spider unlock condition mismatch")
		if not _has_stat_delta(spider.get("effects", []), "damage_percent", 0.12):
			failures.append("Spider damage effect mismatch")

	var wisdom: Dictionary = items.get("wisdom", {})
	if not wisdom.is_empty():
		if int(wisdom.get("limit", 0)) != 1:
			failures.append("Wisdom limit mismatch")
		if not _has_stat_delta(wisdom.get("effects", []), "damage_percent", -0.15):
			failures.append("Wisdom damage penalty mismatch")

func _check_ninth_foundational_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 213:
		failures.append("Item catalog should include the ninth foundational stat batch")
	for item_id in ["anvil", "ball_and_chain", "bloody_hand", "broken_hourglass", "broken_mirror", "candy_bag", "community_support", "esty_s_couch", "explosive_turret", "extra_stomach", "eyes_surgery", "fairy", "focus", "fried_rice", "frozen_heart", "giant_belt", "gobbler_s_hat", "greek_fire", "grind_s_magical_leaf", "handcuffs", "honey", "hourglass", "ice_cube", "improved_tools", "incendiary_turret", "laser_turret", "lucky_coin", "lure", "medical_turret", "nail", "pile_of_books", "pocket_factory", "potato", "resting_goldfish", "retromation_s_hoodie", "ricochet", "robot_arm", "shackles", "sifd_s_relic", "stone_skin", "strange_book", "torture", "tyler", "will_o_wisp"]:
		if not items.has(item_id):
			failures.append("Missing ninth foundational item row: " + item_id)

	var anvil: Dictionary = items.get("anvil", {})
	if not anvil.is_empty():
		if anvil.get("unlocked_by", {}).get("condition", "") != "win_with_arms_dealer":
			failures.append("Anvil unlock condition mismatch")
		if int(anvil.get("limit", 0)) != 1:
			failures.append("Anvil limit mismatch")

	var ball_and_chain: Dictionary = items.get("ball_and_chain", {})
	if not ball_and_chain.is_empty():
		if int(ball_and_chain.get("limit", 0)) != 1:
			failures.append("Ball and Chain limit mismatch")
		if not _has_stat_delta(ball_and_chain.get("effects", []), "armor", 3.0):
			failures.append("Ball and Chain armor effect mismatch")

	var candy_bag: Dictionary = items.get("candy_bag", {})
	if not candy_bag.is_empty():
		if candy_bag.get("unlocked_by", {}).get("condition", "") != "win_without_locking_shop_items":
			failures.append("Candy Bag unlock condition mismatch")
		if int(candy_bag.get("limit", 0)) != 1:
			failures.append("Candy Bag limit mismatch")

	var focus: Dictionary = items.get("focus", {})
	if not focus.is_empty():
		if focus.get("unlocked_by", {}).get("condition", "") != "win_with_one_armed":
			failures.append("Focus unlock condition mismatch")
		if not _has_stat_delta(focus.get("effects", []), "damage_percent", 0.30):
			failures.append("Focus damage effect mismatch")

	var improved_tools: Dictionary = items.get("improved_tools", {})
	if not improved_tools.is_empty():
		if improved_tools.get("unlocked_by", {}).get("condition", "") != "win_with_cyborg":
			failures.append("Improved Tools unlock condition mismatch")
		if not _has_stat_delta(improved_tools.get("effects", []), "attack_speed_percent", 0.10):
			failures.append("Improved Tools attack speed effect mismatch")

	var potato: Dictionary = items.get("potato", {})
	if not potato.is_empty():
		if potato.get("unlocked_by", {}).get("condition", "") != "win_with_well_rounded":
			failures.append("Potato unlock condition mismatch")
		if not _has_stat_delta(potato.get("effects", []), "armor", 1.0):
			failures.append("Potato armor effect mismatch")

	var ricochet: Dictionary = items.get("ricochet", {})
	if not ricochet.is_empty():
		if not _has_stat_delta(ricochet.get("effects", []), "damage_percent", -0.25):
			failures.append("Ricochet damage penalty mismatch")

	var will_o_wisp: Dictionary = items.get("will_o_wisp", {})
	if not will_o_wisp.is_empty():
		if will_o_wisp.get("unlocked_by", {}).get("condition", "") != "kill_30_burning_enemies_in_single_wave":
			failures.append("Will-o'-Wisp unlock condition mismatch")
		if not _has_stat_delta(will_o_wisp.get("effects", []), "attack_speed_percent", -0.07):
			failures.append("Will-o'-Wisp attack speed penalty mismatch")

func _check_dlc_item_catalog_batch(data):
	var items = data.get_items(true)
	if items.size() < 235:
		failures.append("Item catalog should include the remaining DLC table rows")
	for item_id in ["ashes", "axolotl", "baby_squid", "black_flag", "bone_dice", "coral", "corrupted_shard", "crystal", "feather", "goblet", "goldfish", "jerky", "knot", "kraken_s_eye", "lantern", "mirror", "penguin", "saltwater", "seashell", "small_fish", "sunken_bell", "whistle"]:
		if not items.has(item_id):
			failures.append("Missing DLC item row: " + item_id)

	var ashes: Dictionary = items.get("ashes", {})
	if not ashes.is_empty():
		if not bool(ashes.get("is_dlc", false)):
			failures.append("Ashes should be marked as DLC")
		if not _has_stat_delta(ashes.get("effects", []), "damage_percent", 0.20):
			failures.append("Ashes damage effect mismatch")
		if not _has_stat_delta(ashes.get("effects", []), "range", 100.0):
			failures.append("Ashes range effect mismatch")

	var black_flag: Dictionary = items.get("black_flag", {})
	if not black_flag.is_empty():
		if int(black_flag.get("limit", 0)) != 1:
			failures.append("Black Flag limit mismatch")
		if not _has_stat_delta(black_flag.get("effects", []), "curse", 5.0):
			failures.append("Black Flag curse effect mismatch")

	var bone_dice: Dictionary = items.get("bone_dice", {})
	if not bone_dice.is_empty():
		if int(bone_dice.get("limit", 0)) != 2:
			failures.append("Bone Dice limit mismatch")

	var crystal: Dictionary = items.get("crystal", {})
	if not crystal.is_empty():
		if not _has_stat_delta(crystal.get("effects", []), "attack_speed_percent", 0.05):
			failures.append("Crystal attack speed effect mismatch")
		if not _has_stat_delta(crystal.get("effects", []), "engineering", -2.0):
			failures.append("Crystal engineering penalty mismatch")

	var saltwater: Dictionary = items.get("saltwater", {})
	if not saltwater.is_empty():
		if int(saltwater.get("limit", 0)) != 1:
			failures.append("Saltwater limit mismatch")
		if not _has_stat_delta(saltwater.get("effects", []), "melee_damage", 2.0):
			failures.append("Saltwater melee damage effect mismatch")

	var seashell: Dictionary = items.get("seashell", {})
	if not seashell.is_empty():
		if int(seashell.get("limit", 0)) != 1:
			failures.append("Seashell limit mismatch")
		if not _has_stat_delta(seashell.get("effects", []), "damage_percent", -0.10):
			failures.append("Seashell damage penalty mismatch")

	var whistle: Dictionary = items.get("whistle", {})
	if not whistle.is_empty():
		if int(whistle.get("limit", 0)) != 1:
			failures.append("Whistle limit mismatch")

func _check_item_catalog_has_no_implemented_field(data):
	# 2026-09-15 字段卫生：六个目录里的 `implemented` 全部删除。它曾与实际可用性脱节 ——
	# 例如 items 235 条全为 false 却照常被商店刷出、weapons 78 条只有 5 条 true、
	# characters 62 条只有 1 条 true、upgrades 100 条全为 true（等于没有筛选作用）。
	# 现在每个目录各用一条真实判据：items → _item_has_runtime_effects()，
	# weapons → _weapon_has_runtime_tier()，其余目录全部可用（无过滤）。
	var catalogs := {
		"items": data.get_items(true),
		"weapons": data.get_weapons(true),
		"characters": data.get_characters(true),
		"upgrades": data.get_level_up_choices(0),
	}
	for name in catalogs:
		var rows = catalogs[name]
		var entries = rows if rows is Array else rows.values()
		for row in entries:
			if row is Dictionary and row.has("implemented"):
				failures.append("%s 目录中仍有已删除的 implemented 字段: %s" % [name, str(row.get("id", "?"))])

	# 判据一致性：items 的 get_items(false) 必须与商店用同一判据
	var runtime_supported = data.get_items(false)
	var shop_pool = data.get_shop_pool(false)
	if runtime_supported.is_empty():
		failures.append("get_items(false) should return the runtime-supported subset, got 0")
	if runtime_supported.size() != shop_pool.size():
		failures.append("get_items(false) should use the same predicate as get_shop_pool(false): %d vs %d" % [
			runtime_supported.size(), shop_pool.size()
		])

	# 判据不得误伤：全部武器/角色都真实可获得，传 false 也不能丢数据
	if data.get_weapons(false).size() != data.get_weapons(true).size():
		failures.append("get_weapons(false) dropped weapons: %d vs %d" % [
			data.get_weapons(false).size(), data.get_weapons(true).size()
		])
	if data.get_characters(false).size() != data.get_characters(true).size():
		failures.append("get_characters(false) dropped characters: %d vs %d" % [
			data.get_characters(false).size(), data.get_characters(true).size()
		])
	# get_combat_dict 的默认参数是 false；历史上会因 implemented 全为 false 而返回空表
	if data.get_combat_dict().size() != data.get_combat_dict(true).size():
		failures.append("get_combat_dict() default arg dropped weapons: %d vs %d" % [
			data.get_combat_dict().size(), data.get_combat_dict(true).size()
		])

func _check_gun_catalog(data):
	var gun_class = data.get_weapon_class("gun")
	if gun_class.is_empty():
		failures.append("Missing Gun weapon class")
	else:
		var thresholds: Dictionary = gun_class.get("thresholds", {})
		if int(thresholds.get("6", [])[0].get("value", 0)) != 50:
			failures.append("Gun 6-piece range bonus should be 50")

	var expected_weapons := [
		"double_barrel_shotgun",
		"laser_gun",
		"medical_gun",
		"pistol",
		"railgun",
		"revolver",
		"shredder",
		"smg",
		"minigun",
		"obliterator",
		"sniper_gun",
		"chain_gun",
		"blunderbuss",
		"harpoon_gun",
	]
	var gun_ids = data.get_weapon_ids_by_class("gun")
	for weapon_id in expected_weapons:
		if weapon_id not in gun_ids:
			failures.append("Missing Gun weapon catalog row: " + weapon_id)

	var pistol = data.get_weapon("pistol")
	var pistol_tiers: Dictionary = pistol.get("tiers", {})
	if int(pistol_tiers.get("1", {}).get("damage", {}).get("base", 0)) != 12:
		failures.append("Pistol tier 1 damage mismatch")
	if int(pistol_tiers.get("4", {}).get("damage", {}).get("base", 0)) != 50:
		failures.append("Pistol tier 4 damage mismatch")
	var smg = data.get_weapon("smg")
	if int(smg.get("tiers", {}).get("1", {}).get("damage", {}).get("base", 0)) != 3:
		failures.append("SMG tier 1 damage mismatch")
	var minigun = data.get_weapon("minigun")
	if int(minigun.get("minimum_tier", 0)) != 3:
		failures.append("Minigun should start at tier 3")
	if minigun.get("tiers", {}).has("1") or minigun.get("tiers", {}).has("2"):
		failures.append("Minigun should not expose tier 1/2 rows")
	var obliterator = data.get_weapon("obliterator")
	if int(obliterator.get("minimum_tier", 0)) != 3:
		failures.append("Obliterator should start at tier 3")
	if obliterator.get("tiers", {}).has("1") or obliterator.get("tiers", {}).has("2"):
		failures.append("Obliterator should not expose tier 1/2 rows")
	if obliterator.get("unlocked_by", {}).get("condition", "") != "win_with_demon":
		failures.append("Obliterator unlock condition mismatch")
	var sniper_gun = data.get_weapon("sniper_gun")
	if int(sniper_gun.get("minimum_tier", 0)) != 3:
		failures.append("Sniper Gun should start at tier 3")
	if sniper_gun.get("tiers", {}).has("1") or sniper_gun.get("tiers", {}).has("2"):
		failures.append("Sniper Gun should not expose tier 1/2 rows")
	if int(sniper_gun.get("tiers", {}).get("4", {}).get("spawned_projectiles_on_hit", 0)) != 8:
		failures.append("Sniper Gun tier 4 spawned projectile count mismatch")
	var chain_gun = data.get_weapon("chain_gun")
	if int(chain_gun.get("minimum_tier", 0)) != 4:
		failures.append("Chain Gun should start at tier 4")
	if chain_gun.get("tiers", {}).has("1") or chain_gun.get("tiers", {}).has("2") or chain_gun.get("tiers", {}).has("3"):
		failures.append("Chain Gun should only expose tier 4 row")
	if int(chain_gun.get("tiers", {}).get("4", {}).get("cooldown_every_shots", 0)) != 100:
		failures.append("Chain Gun special cooldown interval mismatch")

func _check_runtime_conversions(data):
	var combat = data.weapon_tier_to_combat_entry("pistol", 1)
	if combat.is_empty():
		failures.append("Pistol tier 1 did not convert to combat entry")
		return
	if int(combat.get("damage", 0)) != 12:
		failures.append("Pistol combat damage mismatch")
	if float(combat.get("fire_rate", 0.0)) <= 0.0:
		failures.append("Pistol combat fire rate must be positive")
	var shop_entries = data.get_weapon_shop_entries(false)
	if shop_entries.is_empty():
		failures.append("Expected implemented weapon shop entries")

func _check_main_scene_still_boots():
	var game_state = root.get_node("/root/GameState")
	game_state.selected_character = "normal"
	game_state.difficulty = 1
	game_state.endless_mode = false
	var packed = load("res://scenes/Main.tscn")
	if packed == null:
		failures.append("Main scene failed to load")
		return
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	if main.get_script() == null:
		failures.append("Main scene script did not load after adding BrotatoData")
	if main.get("player") == null:
		failures.append("Main scene did not resolve player after adding BrotatoData")
	main.queue_free()
	for i in range(5):
		await process_frame
