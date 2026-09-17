extends SceneTree

var failures: Array[String] = []

func _init():
	call_deferred("_run")

func _run():
	var data_script = load("res://scripts/BrotatoData.gd")
	if data_script == null:
		failures.append("Missing BrotatoData script")
	else:
		var data = data_script.new()
		var load_errors = data.load_catalog()
		for error in load_errors:
			failures.append("Load error: " + error)
		for error in data.validate():
			failures.append("Validation error: " + error)
		_check_current_starting_weapons_resolve(data)
		_check_manifest_weapon_count(data)
		_check_reference_weapon_expansion(data)
		_check_weapon_groups_match_reference_classes(data)
		_check_runtime_aliases_resolve_to_reference_rows(data)
		_check_runtime_aliases_do_not_shadow_reference_ids(data)
		_check_catalog_combat_dict_has_no_empty_entries()

	_check_shop_pool_has_no_unknown_placeholder()
	_check_catalog_shop_entries_preserve_minimum_tiers()
	_check_catalog_shop_pool_does_not_mix_legacy_only_weapons()

	if failures.is_empty():
		print("PHASE_D1_WEAPON_CATALOG_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_current_starting_weapons_resolve(data):
	var default_ids = data.get_default_character_ids()
	if default_ids.is_empty():
		failures.append("No default catalog characters found")
	for character_id in default_ids:
		var character = data.get_character(character_id)
		if character.is_empty():
			failures.append("Missing default character row: " + character_id)
			continue
		var weapon_ids: Array = []
		weapon_ids.append_array(character.get("starting_weapons", []))
		weapon_ids.append_array(character.get("starting_weapon_options", []))
		weapon_ids.append_array(character.get("fixed_starting_weapons", []))
		for weapon_id in weapon_ids:
			if data.get_weapon(str(weapon_id)).is_empty():
				failures.append("%s references unresolved starting weapon: %s" % [character_id, weapon_id])

func _check_manifest_weapon_count(data):
	var expected_counts: Dictionary = data.manifest.get("expected_counts", {})
	var expected_weapon_count = int(expected_counts.get("weapons_total", 0))
	if expected_weapon_count != 78:
		failures.append("Manifest expected_counts.weapons_total should be 78")
	var weapons = data.get_weapons(true)
	if weapons.size() != expected_weapon_count:
		failures.append("Weapon catalog row count should match manifest: expected %d, got %d" % [expected_weapon_count, weapons.size()])

func _check_shop_pool_has_no_unknown_placeholder():
	var shop_script = load("res://scripts/Shop.gd")
	if shop_script == null:
		failures.append("Shop script failed to load")
		return
	var db = load("res://data/weapons.tres") as WeaponDatabase
	if db == null:
		failures.append("Legacy weapon database failed to load")
		return
	var catalog_entries = WeaponDatabase.catalog_shop_entries(false)
	var shop = shop_script.new()
	var merged_entries = shop._merge_weapon_entries(catalog_entries, db.to_shop_entries())
	if merged_entries.is_empty():
		failures.append("Merged shop weapon entries should not be empty")
	for entry in merged_entries:
		if entry.get("type", "") != "weapon":
			continue
		var weapon_type = str(entry.get("weapon_type", ""))
		if weapon_type == "" or weapon_type.to_lower() == "unknown":
			failures.append("Shop weapon pool leaked placeholder weapon_type: " + weapon_type)

func _check_catalog_shop_entries_preserve_minimum_tiers():
	var entries = WeaponDatabase.catalog_shop_entries(false)
	var by_type: Dictionary = {}
	for entry in entries:
		by_type[str(entry.get("weapon_type", ""))] = entry
	var expected := {
		"minigun": {"rarity": 2, "price": 127},
		"chain_gun": {"rarity": 3, "price": 300},
		"excalibur": {"rarity": 3, "price": 230},
	}
	for weapon_id in expected:
		if not by_type.has(weapon_id):
			failures.append("Catalog shop entries missing high-tier weapon: " + weapon_id)
			continue
		var entry: Dictionary = by_type[weapon_id]
		var spec: Dictionary = expected[weapon_id]
		if int(entry.get("rarity", -1)) != int(spec.get("rarity", -1)):
			failures.append("%s shop rarity should preserve minimum tier" % weapon_id)
		if int(entry.get("price", 0)) != int(spec.get("price", 0)):
			failures.append("%s shop price should use minimum tier base price" % weapon_id)

func _check_reference_weapon_expansion(data):
	var expected_ids := [
		"spear",
		"crossbow",
		"sword",
		"flamethrower",
		"rocket_launcher",
		"plasma_sledge",
		"grenade_launcher",
		"blunderbuss",
		"harpoon_gun",
		"anchor",
		"captains_sword",
		"trident",
		"hammer",
		"mace",
		"nuclear_launcher",
		"particle_accelerator",
		"war_hammer",
		"gatling_laser",
		"thief_dagger",
		"shuriken",
		"drill",
		"icicle",
		"lightning_shiv",
		"plank",
		"torch",
		"fireball",
		"flaming_brass_knuckles",
		"thunder_sword",
		"claw",
		"scissors",
		"circular_saw",
		"hiking_pole",
		"lute",
		"flute",
		"pruner",
		"sickle",
		"potato_thrower",
		"hatchet",
		"javelin",
		"quarterstaff",
		"rock",
		"sharp_tooth",
		"slingshot",
		"power_fist",
		"screwdriver",
		"chainsaw",
		"ghost_axe",
		"ghost_flint",
		"ghost_scepter",
		"scythe",
		"chopper",
		"vorpal_sword",
		"excalibur",
		"jousting_lance",
		"spiky_shield",
		"brick",
		"spoon",
		"dex_troyer",
	]
	for weapon_id in expected_ids:
		if data.get_weapon(weapon_id).is_empty():
			failures.append("Missing expanded reference weapon row: " + weapon_id)

	var unarmed_class = data.get_weapon_class("unarmed")
	if unarmed_class.is_empty():
		failures.append("Missing Unarmed weapon class")
	else:
		var unarmed_thresholds: Dictionary = unarmed_class.get("thresholds", {})
		var unarmed_six: Array = unarmed_thresholds.get("6", [])
		if unarmed_six.is_empty() or int(round(float(unarmed_six[0].get("value", 0.0)) * 100.0)) != 15:
			failures.append("Unarmed 6-piece dodge chance bonus should be 15%")
	var tool_class = data.get_weapon_class("engineering")
	if tool_class.is_empty():
		failures.append("Missing Tool weapon class")
	else:
		if str(tool_class.get("source_name", "")) != "Tool":
			failures.append("Engineering class id should represent Tool source data")
		var tool_thresholds: Dictionary = tool_class.get("thresholds", {})
		var tool_six: Array = tool_thresholds.get("6", [])
		if tool_six.is_empty() or int(tool_six[0].get("value", 0)) != 5:
			failures.append("Tool 6-piece Engineering bonus should be 5")
	var ethereal_class = data.get_weapon_class("ethereal")
	if ethereal_class.is_empty():
		failures.append("Missing Ethereal weapon class")
	else:
		var ethereal_thresholds: Dictionary = ethereal_class.get("thresholds", {})
		var ethereal_six: Array = ethereal_thresholds.get("6", [])
		if ethereal_six.size() < 2:
			failures.append("Ethereal 6-piece should include dodge bonus and armor penalty")
		else:
			if int(round(float(ethereal_six[0].get("value", 0.0)) * 100.0)) != 30:
				failures.append("Ethereal 6-piece dodge chance bonus should be 30%")
			if int(ethereal_six[1].get("value", 0)) != -5:
				failures.append("Ethereal 6-piece armor penalty should be -5")

	var blade_class = data.get_weapon_class("blade")
	if blade_class.is_empty():
		failures.append("Missing Blade weapon class")
	else:
		var blade_thresholds: Dictionary = blade_class.get("thresholds", {})
		var blade_six: Array = blade_thresholds.get("6", [])
		if blade_six.size() < 2:
			failures.append("Blade 6-piece should include melee damage and lifesteal")
		else:
			if int(blade_six[0].get("value", 0)) != 5:
				failures.append("Blade 6-piece melee damage bonus should be 5")
			if int(round(float(blade_six[1].get("value", 0.0)) * 100.0)) != 5:
				failures.append("Blade 6-piece lifesteal bonus should be 5%")
	var medieval_class = data.get_weapon_class("medieval")
	if medieval_class.is_empty():
		failures.append("Missing Medieval weapon class")
	else:
		var medieval_thresholds: Dictionary = medieval_class.get("thresholds", {})
		var medieval_six: Array = medieval_thresholds.get("6", [])
		if medieval_six.size() < 2:
			failures.append("Medieval 6-piece should include armor and dodge")
		else:
			if int(medieval_six[0].get("value", 0)) != 3:
				failures.append("Medieval 6-piece armor bonus should be 3")
			if int(round(float(medieval_six[1].get("value", 0.0)) * 100.0)) != 6:
				failures.append("Medieval 6-piece dodge bonus should be 6%")
	var heavy_class = data.get_weapon_class("heavy")
	if heavy_class.is_empty():
		failures.append("Missing Heavy weapon class")
	else:
		var heavy_thresholds: Dictionary = heavy_class.get("thresholds", {})
		var heavy_six: Array = heavy_thresholds.get("6", [])
		if heavy_six.is_empty() or int(round(float(heavy_six[0].get("value", 0.0)) * 100.0)) != 25:
			failures.append("Heavy 6-piece damage bonus should be 25%")
	var blunt_class = data.get_weapon_class("blunt")
	if blunt_class.is_empty():
		failures.append("Missing Blunt weapon class")
	else:
		var blunt_thresholds: Dictionary = blunt_class.get("thresholds", {})
		var blunt_six: Array = blunt_thresholds.get("6", [])
		if blunt_six.size() < 3:
			failures.append("Blunt 6-piece should include armor, max HP, and speed penalty")
		else:
			if int(blunt_six[0].get("value", 0)) != 3:
				failures.append("Blunt 6-piece armor bonus should be 3")
			if int(blunt_six[1].get("value", 0)) != 6:
				failures.append("Blunt 6-piece max HP bonus should be 6")
			if int(round(float(blunt_six[2].get("value", 0.0)) * 100.0)) != -10:
				failures.append("Blunt 6-piece speed penalty should be -10%")
	var explosive_class = data.get_weapon_class("explosive")
	if explosive_class.is_empty():
		failures.append("Missing Explosive weapon class")
	else:
		var explosive_thresholds: Dictionary = explosive_class.get("thresholds", {})
		var explosive_six: Array = explosive_thresholds.get("6", [])
		if explosive_six.is_empty() or int(round(float(explosive_six[0].get("value", 0.0)) * 100.0)) != 25:
			failures.append("Explosive 6-piece size bonus should be 25%")
	var elemental_class = data.get_weapon_class("elemental")
	if elemental_class.is_empty():
		failures.append("Missing Elemental weapon class")
	else:
		var elemental_thresholds: Dictionary = elemental_class.get("thresholds", {})
		var elemental_six: Array = elemental_thresholds.get("6", [])
		if elemental_six.is_empty() or int(elemental_six[0].get("value", 0)) != 5:
			failures.append("Elemental 6-piece damage bonus should be 5")
	var legendary_class = data.get_weapon_class("legendary")
	if legendary_class.is_empty():
		failures.append("Missing Legendary weapon class")
	else:
		var legendary_thresholds: Dictionary = legendary_class.get("thresholds", {})
		var legendary_six: Array = legendary_thresholds.get("6", [])
		if legendary_six.is_empty() or int(legendary_six[0].get("value", 0)) != -100:
			failures.append("Legendary 6-piece max HP penalty should be -100")
	var precise_class = data.get_weapon_class("precise")
	if precise_class.is_empty():
		failures.append("Missing Precise weapon class")
	else:
		var precise_thresholds: Dictionary = precise_class.get("thresholds", {})
		var precise_six: Array = precise_thresholds.get("6", [])
		if precise_six.is_empty() or int(round(float(precise_six[0].get("value", 0.0)) * 100.0)) != 15:
			failures.append("Precise 6-piece crit chance bonus should be 15%")
	var medical_class = data.get_weapon_class("medical")
	if medical_class.is_empty():
		failures.append("Missing Medical weapon class")
	else:
		var medical_thresholds: Dictionary = medical_class.get("thresholds", {})
		var medical_six: Array = medical_thresholds.get("6", [])
		if medical_six.is_empty() or int(medical_six[0].get("value", 0)) != 5:
			failures.append("Medical 6-piece HP regeneration bonus should be 5")
	var support_class = data.get_weapon_class("support")
	if support_class.is_empty():
		failures.append("Missing Support weapon class")
	else:
		var support_thresholds: Dictionary = support_class.get("thresholds", {})
		var support_six: Array = support_thresholds.get("6", [])
		if support_six.is_empty() or int(support_six[0].get("value", 0)) != 25:
			failures.append("Support 6-piece harvesting bonus should be 25")
	var primitive_class = data.get_weapon_class("primitive")
	if primitive_class.is_empty():
		failures.append("Missing Primitive weapon class")
	else:
		var primitive_thresholds: Dictionary = primitive_class.get("thresholds", {})
		var primitive_six: Array = primitive_thresholds.get("6", [])
		if primitive_six.is_empty() or int(primitive_six[0].get("value", 0)) != 15:
			failures.append("Primitive 6-piece max HP bonus should be 15")
	var musical_class = data.get_weapon_class("musical")
	if musical_class.is_empty():
		failures.append("Missing Musical weapon class")
	else:
		var musical_thresholds: Dictionary = musical_class.get("thresholds", {})
		var musical_six: Array = musical_thresholds.get("6", [])
		if musical_six.is_empty() or int(musical_six[0].get("value", 0)) != 25:
			failures.append("Musical 6-piece luck bonus should be 25")
	var naval_class = data.get_weapon_class("naval")
	if naval_class.is_empty():
		failures.append("Missing Naval weapon class")
	else:
		var naval_thresholds: Dictionary = naval_class.get("thresholds", {})
		if int(naval_thresholds.get("6", [])[0].get("value", 0)) != 5:
			failures.append("Naval 6-piece curse bonus should be 5")

	var spear = data.get_weapon("spear")
	if not spear.is_empty():
		if "primitive" not in spear.get("groups", []):
			failures.append("Spear should be Primitive")
		if int(spear.get("tiers", {}).get("1", {}).get("damage", {}).get("base", 0)) != 15:
			failures.append("Spear tier 1 damage mismatch")
		if int(spear.get("tiers", {}).get("4", {}).get("range", 0)) != 500:
			failures.append("Spear tier 4 range mismatch")

	var crossbow = data.get_weapon("crossbow")
	if not crossbow.is_empty():
		if "precise" not in crossbow.get("groups", []) or "medieval" not in crossbow.get("groups", []):
			failures.append("Crossbow should be Precise and Medieval")
		if int(crossbow.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 18:
			failures.append("Crossbow tier 4 damage mismatch")
		if int(round(float(crossbow.get("tiers", {}).get("4", {}).get("crit_chance", 0.0)) * 100.0)) != 45:
			failures.append("Crossbow tier 4 crit chance mismatch")

	var sword = data.get_weapon("sword")
	if not sword.is_empty():
		if "blade" not in sword.get("groups", []) or "medieval" not in sword.get("groups", []):
			failures.append("Sword should be Blade and Medieval")
		if int(sword.get("tiers", {}).get("2", {}).get("damage", {}).get("base", 0)) != 25:
			failures.append("Sword tier 2 damage mismatch")

	var chopper = data.get_weapon("chopper")
	if not chopper.is_empty():
		if "blade" not in chopper.get("groups", []):
			failures.append("Chopper should be Blade")
		if int(chopper.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 30:
			failures.append("Chopper tier 4 damage mismatch")
		if int(chopper.get("tiers", {}).get("4", {}).get("range", 0)) != 180:
			failures.append("Chopper tier 4 range mismatch")
		if int(chopper.get("tiers", {}).get("4", {}).get("consumable_heal_bonus", 0)) != 2:
			failures.append("Chopper tier 4 consumable heal bonus mismatch")

	var vorpal_sword = data.get_weapon("vorpal_sword")
	if not vorpal_sword.is_empty():
		if "blade" not in vorpal_sword.get("groups", []) or "medieval" not in vorpal_sword.get("groups", []):
			failures.append("Vorpal Sword should be Blade and Medieval")
		if int(vorpal_sword.get("minimum_tier", 0)) != 2:
			failures.append("Vorpal Sword should start at tier 2")
		if int(vorpal_sword.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 55:
			failures.append("Vorpal Sword tier 4 damage mismatch")
		if int(round(float(vorpal_sword.get("tiers", {}).get("4", {}).get("instant_kill_chance", 0.0)) * 100.0)) != 3:
			failures.append("Vorpal Sword tier 4 instant-kill chance mismatch")

	var excalibur = data.get_weapon("excalibur")
	if not excalibur.is_empty():
		if "legendary" not in excalibur.get("groups", []) or "blade" not in excalibur.get("groups", []):
			failures.append("Excalibur should be Legendary and Blade")
		if int(excalibur.get("minimum_tier", 0)) != 4:
			failures.append("Excalibur should start at tier 4")
		if int(excalibur.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 200:
			failures.append("Excalibur tier 4 damage mismatch")
		if int(excalibur.get("tiers", {}).get("4", {}).get("armor_penalty_per_weapon", 0)) != -3:
			failures.append("Excalibur armor penalty mismatch")

	var jousting_lance = data.get_weapon("jousting_lance")
	if not jousting_lance.is_empty():
		if "medieval" not in jousting_lance.get("groups", []):
			failures.append("Jousting Lance should be Medieval")
		if int(jousting_lance.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 50:
			failures.append("Jousting Lance tier 4 damage mismatch")
		if int(round(float(jousting_lance.get("tiers", {}).get("4", {}).get("speed_bonus", 0.0)) * 100.0)) != 5:
			failures.append("Jousting Lance tier 4 speed bonus mismatch")
		if int(round(float(jousting_lance.get("tiers", {}).get("4", {}).get("standing_still_damage_penalty", 0.0)) * 100.0)) != -25:
			failures.append("Jousting Lance tier 4 standing-still penalty mismatch")

	var spiky_shield = data.get_weapon("spiky_shield")
	if not spiky_shield.is_empty():
		if "medieval" not in spiky_shield.get("groups", []) or "blunt" not in spiky_shield.get("groups", []):
			failures.append("Spiky Shield should be Medieval and Blunt")
		if int(spiky_shield.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 30:
			failures.append("Spiky Shield tier 4 damage mismatch")
		if int(round(float(spiky_shield.get("tiers", {}).get("4", {}).get("damage", {}).get("scaling", [])[0].get("coefficient", 0.0)) * 100.0)) != 200:
			failures.append("Spiky Shield tier 4 armor scaling mismatch")
		if int(spiky_shield.get("tiers", {}).get("4", {}).get("knockback", 0)) != 20:
			failures.append("Spiky Shield tier 4 knockback mismatch")

	var brick = data.get_weapon("brick")
	if not brick.is_empty():
		if "blunt" not in brick.get("groups", []):
			failures.append("Brick should be Blunt")
		if not brick.get("is_dlc", false):
			failures.append("Brick should be marked as DLC")
		if int(brick.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 120:
			failures.append("Brick tier 4 damage mismatch")
		if int(brick.get("tiers", {}).get("4", {}).get("break_materials", 0)) != 120:
			failures.append("Brick tier 4 break material reward mismatch")

	var spoon = data.get_weapon("spoon")
	if not spoon.is_empty():
		if "blunt" not in spoon.get("groups", []):
			failures.append("Spoon should be Blunt")
		if not spoon.get("is_dlc", false):
			failures.append("Spoon should be marked as DLC")
		if int(spoon.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 25:
			failures.append("Spoon tier 4 damage mismatch")
		if int(round(float(spoon.get("tiers", {}).get("4", {}).get("crit_multiplier", 0.0)) * 10.0)) != 30:
			failures.append("Spoon tier 4 crit multiplier mismatch")
		if not spoon.get("tiers", {}).get("4", {}).get("always_crits_burning_targets", false):
			failures.append("Spoon should always crit burning targets")

	var flamethrower = data.get_weapon("flamethrower")
	if not flamethrower.is_empty():
		if "elemental" not in flamethrower.get("groups", []) or "heavy" not in flamethrower.get("groups", []):
			failures.append("Flamethrower should be Elemental and Heavy")
		if int(flamethrower.get("tiers", {}).get("4", {}).get("range", 0)) != 400:
			failures.append("Flamethrower tier 4 range mismatch")
		if int(flamethrower.get("tiers", {}).get("4", {}).get("pierce", {}).get("count", 0)) != 99:
			failures.append("Flamethrower tier 4 pierce count mismatch")

	var rocket_launcher = data.get_weapon("rocket_launcher")
	if not rocket_launcher.is_empty():
		if "heavy" not in rocket_launcher.get("groups", []) or "explosive" not in rocket_launcher.get("groups", []):
			failures.append("Rocket Launcher should be Heavy and Explosive")
		if int(rocket_launcher.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 80:
			failures.append("Rocket Launcher tier 4 damage mismatch")

	var plasma_sledge = data.get_weapon("plasma_sledge")
	if not plasma_sledge.is_empty():
		if "elemental" not in plasma_sledge.get("groups", []) or "explosive" not in plasma_sledge.get("groups", []):
			failures.append("Plasma Sledge should be Elemental and Explosive")
		if int(plasma_sledge.get("tiers", {}).get("3", {}).get("damage", {}).get("base", 0)) != 80:
			failures.append("Plasma Sledge tier 3 damage mismatch")
		if int(plasma_sledge.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 120:
			failures.append("Plasma Sledge tier 4 damage mismatch")

	var dex_troyer = data.get_weapon("dex_troyer")
	if not dex_troyer.is_empty():
		if "legendary" not in dex_troyer.get("groups", []) or "explosive" not in dex_troyer.get("groups", []):
			failures.append("DEX-troyer should be Legendary and Explosive")
		if int(dex_troyer.get("minimum_tier", 0)) != 4:
			failures.append("DEX-troyer should start at tier 4")
		var dex_tier_4 = dex_troyer.get("tiers", {}).get("4", {})
		if int(dex_tier_4.get("damage", {}).get("base", 0)) != 100:
			failures.append("DEX-troyer tier 4 damage mismatch")
		if int(round(float(dex_tier_4.get("cooldown", 0.0)) * 100.0)) != 118:
			failures.append("DEX-troyer tier 4 cooldown mismatch")
		if int(dex_tier_4.get("knockback", 0)) != 60:
			failures.append("DEX-troyer tier 4 knockback mismatch")
		if int(round(float(dex_tier_4.get("explosion_damage_growth_per_explosion", 0.0)) * 100.0)) != 3:
			failures.append("DEX-troyer explosion damage growth mismatch")

	var grenade_launcher = data.get_weapon("grenade_launcher")
	if not grenade_launcher.is_empty():
		if not grenade_launcher.get("is_dlc", false):
			failures.append("Grenade Launcher should be marked as DLC")
		if int(grenade_launcher.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 30:
			failures.append("Grenade Launcher tier 4 damage mismatch")

	var blunderbuss = data.get_weapon("blunderbuss")
	if not blunderbuss.is_empty():
		if "naval" not in blunderbuss.get("groups", []) or "gun" not in blunderbuss.get("groups", []):
			failures.append("Blunderbuss should be Naval and Gun")
		if int(blunderbuss.get("minimum_tier", 0)) != 2:
			failures.append("Blunderbuss should start at tier 2")
		if int(blunderbuss.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 80:
			failures.append("Blunderbuss tier 4 damage mismatch")
		if int(blunderbuss.get("tiers", {}).get("4", {}).get("pierce", {}).get("count", 0)) != 2:
			failures.append("Blunderbuss pierce count mismatch")

	var harpoon_gun = data.get_weapon("harpoon_gun")
	if not harpoon_gun.is_empty():
		if "naval" not in harpoon_gun.get("groups", []) or "gun" not in harpoon_gun.get("groups", []):
			failures.append("Harpoon Gun should be Naval and Gun")
		if int(harpoon_gun.get("minimum_tier", 0)) != 2:
			failures.append("Harpoon Gun should start at tier 2")
		if int(harpoon_gun.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 20:
			failures.append("Harpoon Gun tier 4 damage mismatch")
		if int(harpoon_gun.get("tiers", {}).get("4", {}).get("knockback", 0)) != -30:
			failures.append("Harpoon Gun tier 4 knockback mismatch")

	var anchor = data.get_weapon("anchor")
	if not anchor.is_empty():
		if "naval" not in anchor.get("groups", []) or "heavy" not in anchor.get("groups", []):
			failures.append("Anchor should be Naval and Heavy")
		if int(anchor.get("minimum_tier", 0)) != 2:
			failures.append("Anchor should start at tier 2")
		if int(anchor.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 110:
			failures.append("Anchor tier 4 damage mismatch")
		if int(anchor.get("tiers", {}).get("4", {}).get("range", 0)) != 225:
			failures.append("Anchor tier 4 range mismatch")

	var captains_sword = data.get_weapon("captains_sword")
	if not captains_sword.is_empty():
		if "naval" not in captains_sword.get("groups", []) or "blade" not in captains_sword.get("groups", []):
			failures.append("Captain's Sword should be Naval and Blade")
		if int(captains_sword.get("minimum_tier", 0)) != 3:
			failures.append("Captain's Sword should start at tier 3")
		if int(captains_sword.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 80:
			failures.append("Captain's Sword tier 4 damage mismatch")
		if int(captains_sword.get("tiers", {}).get("4", {}).get("damage_per_free_slot", 0)) != 50:
			failures.append("Captain's Sword tier 4 free-slot damage mismatch")

	var trident = data.get_weapon("trident")
	if not trident.is_empty():
		if "naval" not in trident.get("groups", []) or "medieval" not in trident.get("groups", []):
			failures.append("Trident should be Naval and Medieval")
		if int(trident.get("minimum_tier", 0)) != 2:
			failures.append("Trident should start at tier 2")
		if int(trident.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 80:
			failures.append("Trident tier 4 damage mismatch")
		if float(trident.get("tiers", {}).get("4", {}).get("bonus_damage_above_health", 0.0)) < 0.5:
			failures.append("Trident tier 4 high-health bonus mismatch")

	var cacti_club = data.get_weapon("cacti_club")
	if not cacti_club.is_empty():
		if "primitive" not in cacti_club.get("groups", []) or "heavy" not in cacti_club.get("groups", []):
			failures.append("Cacti Club should be Primitive and Heavy")
		if int(cacti_club.get("tiers", {}).get("4", {}).get("range", 0)) != 200:
			failures.append("Cacti Club tier 4 range mismatch")
		if int(round(float(cacti_club.get("tiers", {}).get("4", {}).get("cooldown", 0.0)) * 100.0)) != 136:
			failures.append("Cacti Club tier 4 cooldown mismatch")

	var hammer = data.get_weapon("hammer")
	if not hammer.is_empty():
		if "blunt" not in hammer.get("groups", []) or "heavy" not in hammer.get("groups", []):
			failures.append("Hammer should be Blunt and Heavy")
		if int(hammer.get("minimum_tier", 0)) != 2:
			failures.append("Hammer should start at tier 2")
		if int(hammer.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 110:
			failures.append("Hammer tier 4 damage mismatch")
		if int(hammer.get("tiers", {}).get("4", {}).get("knockback_bonus", 0)) != 6:
			failures.append("Hammer tier 4 knockback bonus mismatch")

	var mace = data.get_weapon("mace")
	if not mace.is_empty():
		if "heavy" not in mace.get("groups", []) or "medieval" not in mace.get("groups", []):
			failures.append("Mace should be Heavy and Medieval")
		if int(mace.get("minimum_tier", 0)) != 2:
			failures.append("Mace should start at tier 2")
		if int(mace.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 100:
			failures.append("Mace tier 4 damage mismatch")
		if int(round(abs(float(mace.get("tiers", {}).get("4", {}).get("attack_speed_delta", 0.0))) * 100.0)) != 10:
			failures.append("Mace tier 4 attack speed penalty mismatch")

	var nuclear_launcher = data.get_weapon("nuclear_launcher")
	if not nuclear_launcher.is_empty():
		if "heavy" not in nuclear_launcher.get("groups", []) or "explosive" not in nuclear_launcher.get("groups", []):
			failures.append("Nuclear Launcher should be Heavy and Explosive")
		if int(nuclear_launcher.get("minimum_tier", 0)) != 3:
			failures.append("Nuclear Launcher should start at tier 3")
		if int(nuclear_launcher.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 120:
			failures.append("Nuclear Launcher tier 4 damage mismatch")
		if int(nuclear_launcher.get("tiers", {}).get("4", {}).get("range", 0)) != 800:
			failures.append("Nuclear Launcher tier 4 range mismatch")

	var particle_accelerator = data.get_weapon("particle_accelerator")
	if not particle_accelerator.is_empty():
		if "heavy" not in particle_accelerator.get("groups", []) or "elemental" not in particle_accelerator.get("groups", []):
			failures.append("Particle Accelerator should be Heavy and Elemental")
		if int(particle_accelerator.get("minimum_tier", 0)) != 3:
			failures.append("Particle Accelerator should start at tier 3")
		if int(particle_accelerator.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 120:
			failures.append("Particle Accelerator tier 4 damage mismatch")
		if int(particle_accelerator.get("tiers", {}).get("4", {}).get("burn_instances", 0)) != 10:
			failures.append("Particle Accelerator tier 4 burn instance mismatch")

	var war_hammer = data.get_weapon("war_hammer")
	if not war_hammer.is_empty():
		if "blunt" not in war_hammer.get("groups", []) or "heavy" not in war_hammer.get("groups", []):
			failures.append("War Hammer should be Blunt and Heavy")
		if int(war_hammer.get("minimum_tier", 0)) != 3:
			failures.append("War Hammer should start at tier 3")
		if int(war_hammer.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 180:
			failures.append("War Hammer tier 4 damage mismatch")
		if int(war_hammer.get("tiers", {}).get("4", {}).get("knockback", 0)) != 25:
			failures.append("War Hammer tier 4 knockback mismatch")

	var gatling_laser = data.get_weapon("gatling_laser")
	if not gatling_laser.is_empty():
		if "legendary" not in gatling_laser.get("groups", []) or "heavy" not in gatling_laser.get("groups", []):
			failures.append("Gatling Laser should be Legendary and Heavy")
		if int(gatling_laser.get("minimum_tier", 0)) != 4:
			failures.append("Gatling Laser should start at tier 4")
		if int(gatling_laser.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 10:
			failures.append("Gatling Laser tier 4 damage mismatch")
		if int(gatling_laser.get("tiers", {}).get("4", {}).get("pierce", {}).get("count", 0)) != 3:
			failures.append("Gatling Laser tier 4 pierce mismatch")

	var knife = data.get_weapon("knife")
	if not knife.is_empty():
		if "precise" not in knife.get("groups", []):
			failures.append("Knife should be Precise")
		if int(knife.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 20:
			failures.append("Knife tier 4 damage mismatch")
		if int(round(float(knife.get("tiers", {}).get("4", {}).get("crit_chance", 0.0)) * 100.0)) != 50:
			failures.append("Knife tier 4 crit chance mismatch")

	var thief_dagger = data.get_weapon("thief_dagger")
	if not thief_dagger.is_empty():
		if "precise" not in thief_dagger.get("groups", []):
			failures.append("Thief Dagger should be Precise")
		if int(thief_dagger.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 30:
			failures.append("Thief Dagger tier 4 damage mismatch")
		if int(round(float(thief_dagger.get("tiers", {}).get("4", {}).get("material_on_crit_kill_chance", 0.0)) * 100.0)) != 80:
			failures.append("Thief Dagger tier 4 material chance mismatch")

	var shuriken = data.get_weapon("shuriken")
	if not shuriken.is_empty():
		if "precise" not in shuriken.get("groups", []):
			failures.append("Shuriken should be Precise")
		if int(shuriken.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 15:
			failures.append("Shuriken tier 4 damage mismatch")
		if int(shuriken.get("tiers", {}).get("4", {}).get("crit_bounces", 0)) != 4:
			failures.append("Shuriken tier 4 crit bounce mismatch")

	var drill = data.get_weapon("drill")
	if not drill.is_empty():
		if "legendary" not in drill.get("groups", []) or "precise" not in drill.get("groups", []):
			failures.append("Drill should be Legendary and Precise")
		if int(drill.get("minimum_tier", 0)) != 4:
			failures.append("Drill should start at tier 4")
		if int(drill.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 10:
			failures.append("Drill tier 4 damage mismatch")
		if int(round(float(drill.get("tiers", {}).get("4", {}).get("crit_chance", 0.0)) * 100.0)) != 50:
			failures.append("Drill tier 4 crit chance mismatch")

	var wand = data.get_weapon("wand")
	if not wand.is_empty():
		if "elemental" not in wand.get("groups", []):
			failures.append("Wand should be Elemental")
		if int(wand.get("tiers", {}).get("4", {}).get("range", 0)) != 425:
			failures.append("Wand tier 4 range mismatch")
		if int(round(float(wand.get("tiers", {}).get("4", {}).get("cooldown", 0.0)) * 100.0)) != 53:
			failures.append("Wand tier 4 cooldown mismatch")

	var taser = data.get_weapon("taser")
	if not taser.is_empty():
		if "elemental" not in taser.get("groups", []) or "support" not in taser.get("groups", []):
			failures.append("Taser should be Elemental and Support")
		if int(taser.get("tiers", {}).get("4", {}).get("projectiles", 0)) != 4:
			failures.append("Taser tier 4 projectile count mismatch")
		if int(taser.get("tiers", {}).get("4", {}).get("range", 0)) != 200:
			failures.append("Taser tier 4 range mismatch")

	var icicle = data.get_weapon("icicle")
	if not icicle.is_empty():
		if "elemental" not in icicle.get("groups", []) or "precise" not in icicle.get("groups", []):
			failures.append("Icicle should be Elemental and Precise")
		if int(icicle.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 40:
			failures.append("Icicle tier 4 damage mismatch")
		if int(round(float(icicle.get("tiers", {}).get("4", {}).get("crit_chance", 0.0)) * 100.0)) != 20:
			failures.append("Icicle tier 4 crit chance mismatch")

	var lightning_shiv = data.get_weapon("lightning_shiv")
	if not lightning_shiv.is_empty():
		if "elemental" not in lightning_shiv.get("groups", []) or "precise" not in lightning_shiv.get("groups", []):
			failures.append("Lightning Shiv should be Elemental and Precise")
		if int(lightning_shiv.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 15:
			failures.append("Lightning Shiv tier 4 damage mismatch")
		if int(lightning_shiv.get("tiers", {}).get("4", {}).get("lightning_bounces", 0)) != 3:
			failures.append("Lightning Shiv tier 4 bounce mismatch")

	var plank = data.get_weapon("plank")
	if not plank.is_empty():
		if "elemental" not in plank.get("groups", []) or "explosive" not in plank.get("groups", []):
			failures.append("Plank should be Elemental and Explosive")
		if int(plank.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 25:
			failures.append("Plank tier 4 damage mismatch")
		if int(round(float(plank.get("tiers", {}).get("4", {}).get("explosion_chance", 0.0)) * 100.0)) != 40:
			failures.append("Plank tier 4 explosion chance mismatch")

	var torch = data.get_weapon("torch")
	if not torch.is_empty():
		if "elemental" not in torch.get("groups", []) or "primitive" not in torch.get("groups", []):
			failures.append("Torch should be Elemental and Primitive")
		if int(torch.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 1:
			failures.append("Torch tier 4 damage mismatch")
		if int(torch.get("tiers", {}).get("4", {}).get("burn_damage", 0)) != 12:
			failures.append("Torch tier 4 burn damage mismatch")

	var fireball = data.get_weapon("fireball")
	if not fireball.is_empty():
		if "elemental" not in fireball.get("groups", []) or "explosive" not in fireball.get("groups", []):
			failures.append("Fireball should be Elemental and Explosive")
		if int(fireball.get("minimum_tier", 0)) != 2:
			failures.append("Fireball should start at tier 2")
		if int(fireball.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 20:
			failures.append("Fireball tier 4 damage mismatch")

	var flaming_brass_knuckles = data.get_weapon("flaming_brass_knuckles")
	if not flaming_brass_knuckles.is_empty():
		if "elemental" not in flaming_brass_knuckles.get("groups", []) or "unarmed" not in flaming_brass_knuckles.get("groups", []):
			failures.append("Flaming Brass Knuckles should be Elemental and Unarmed")
		if int(flaming_brass_knuckles.get("minimum_tier", 0)) != 2:
			failures.append("Flaming Brass Knuckles should start at tier 2")
		if int(flaming_brass_knuckles.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 64:
			failures.append("Flaming Brass Knuckles tier 4 damage mismatch")

	var fist = data.get_weapon("fist")
	if not fist.is_empty():
		if "unarmed" not in fist.get("groups", []):
			failures.append("Fist should be Unarmed")
		if int(fist.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 64:
			failures.append("Fist tier 4 damage mismatch")
		if int(round(float(fist.get("tiers", {}).get("4", {}).get("cooldown", 0.0)) * 100.0)) != 59:
			failures.append("Fist tier 4 cooldown mismatch")
		if int(round(float(fist.get("tiers", {}).get("4", {}).get("crit_multiplier", 0.0)) * 10.0)) != 15:
			failures.append("Fist tier 4 crit multiplier mismatch")

	var claw = data.get_weapon("claw")
	if not claw.is_empty():
		if "unarmed" not in claw.get("groups", []) or "precise" not in claw.get("groups", []):
			failures.append("Claw should be Unarmed and Precise")
		if int(claw.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 25:
			failures.append("Claw tier 4 damage mismatch")
		if int(round(float(claw.get("tiers", {}).get("4", {}).get("damage", {}).get("scaling", [])[0].get("coefficient", 0.0)) * 100.0)) != 30:
			failures.append("Claw tier 4 attack-speed scaling mismatch")
		if int(round(float(claw.get("tiers", {}).get("4", {}).get("crit_chance", 0.0)) * 100.0)) != 25:
			failures.append("Claw tier 4 crit chance mismatch")

	var thunder_sword = data.get_weapon("thunder_sword")
	if not thunder_sword.is_empty():
		if "elemental" not in thunder_sword.get("groups", []) or "blade" not in thunder_sword.get("groups", []):
			failures.append("Thunder Sword should be Elemental and Blade")
		if int(thunder_sword.get("minimum_tier", 0)) != 3:
			failures.append("Thunder Sword should start at tier 3")
		if int(thunder_sword.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 60:
			failures.append("Thunder Sword tier 4 damage mismatch")
		if int(thunder_sword.get("tiers", {}).get("4", {}).get("lightning_bounces", 0)) != 4:
			failures.append("Thunder Sword tier 4 bounce mismatch")

	var scissors = data.get_weapon("scissors")
	if not scissors.is_empty():
		if "medical" not in scissors.get("groups", []) or "precise" not in scissors.get("groups", []):
			failures.append("Scissors should be Medical and Precise")
		if int(scissors.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 20:
			failures.append("Scissors tier 4 damage mismatch")
		if int(round(float(scissors.get("tiers", {}).get("4", {}).get("lifesteal", 0.0)) * 100.0)) != 60:
			failures.append("Scissors tier 4 lifesteal mismatch")

	var circular_saw = data.get_weapon("circular_saw")
	if not circular_saw.is_empty():
		if "medical" not in circular_saw.get("groups", []) or "blade" not in circular_saw.get("groups", []):
			failures.append("Circular Saw should be Medical and Blade")
		if int(circular_saw.get("minimum_tier", 0)) != 2:
			failures.append("Circular Saw should start at tier 2")
		if int(circular_saw.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 25:
			failures.append("Circular Saw tier 4 damage mismatch")
		if int(round(float(circular_saw.get("tiers", {}).get("4", {}).get("lifesteal", 0.0)) * 100.0)) != 60:
			failures.append("Circular Saw tier 4 lifesteal mismatch")

	var hand = data.get_weapon("hand")
	if not hand.is_empty():
		if "support" not in hand.get("groups", []) or "unarmed" not in hand.get("groups", []):
			failures.append("Hand should be Support and Unarmed")
		if int(round(float(hand.get("tiers", {}).get("4", {}).get("cooldown", 0.0)) * 100.0)) != 71:
			failures.append("Hand tier 4 cooldown mismatch")
		if int(hand.get("tiers", {}).get("4", {}).get("harvesting_bonus", 0)) != 18:
			failures.append("Hand tier 4 harvesting bonus mismatch")

	var power_fist = data.get_weapon("power_fist")
	if not power_fist.is_empty():
		if "unarmed" not in power_fist.get("groups", []) or "explosive" not in power_fist.get("groups", []):
			failures.append("Power Fist should be Unarmed and Explosive")
		if int(power_fist.get("minimum_tier", 0)) != 3:
			failures.append("Power Fist should start at tier 3")
		if int(power_fist.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 60:
			failures.append("Power Fist tier 4 damage mismatch")
		if int(round(float(power_fist.get("tiers", {}).get("4", {}).get("explosion_chance", 0.0)) * 100.0)) != 50:
			failures.append("Power Fist tier 4 explosion chance mismatch")

	var screwdriver = data.get_weapon("screwdriver")
	if not screwdriver.is_empty():
		if "engineering" not in screwdriver.get("groups", []):
			failures.append("Screwdriver should be Tool/Engineering")
		if int(screwdriver.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 20:
			failures.append("Screwdriver tier 4 damage mismatch")
		if int(screwdriver.get("tiers", {}).get("4", {}).get("mine_spawn_interval", 0)) != 3:
			failures.append("Screwdriver tier 4 mine interval mismatch")
		if int(round(float(screwdriver.get("tiers", {}).get("4", {}).get("crit_chance", 0.0)) * 100.0)) != 30:
			failures.append("Screwdriver tier 4 crit chance mismatch")

	var wrench = data.get_weapon("wrench")
	if not wrench.is_empty():
		if "engineering" not in wrench.get("groups", []):
			failures.append("Wrench should be Tool/Engineering")
		if int(round(float(wrench.get("tiers", {}).get("4", {}).get("cooldown", 0.0)) * 100.0)) != 149:
			failures.append("Wrench tier 4 cooldown mismatch")
		if int(wrench.get("tiers", {}).get("4", {}).get("base_price", 0)) != 149:
			failures.append("Wrench tier 4 base price mismatch")
		if str(wrench.get("tiers", {}).get("4", {}).get("spawn_structure", "")) != "explosive_turret":
			failures.append("Wrench tier 4 structure spawn mismatch")

	var chainsaw = data.get_weapon("chainsaw")
	if not chainsaw.is_empty():
		if "blade" not in chainsaw.get("groups", []) or "engineering" not in chainsaw.get("groups", []):
			failures.append("Chainsaw should be Blade and Tool/Engineering")
		if not chainsaw.get("is_dlc", false):
			failures.append("Chainsaw should be marked as DLC")
		if int(chainsaw.get("minimum_tier", 0)) != 3:
			failures.append("Chainsaw should start at tier 3")
		if int(chainsaw.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 20:
			failures.append("Chainsaw tier 4 damage mismatch")
		if int(round(float(chainsaw.get("tiers", {}).get("4", {}).get("current_health_bonus_damage", 0.0)) * 100.0)) != 20:
			failures.append("Chainsaw tier 4 current-health bonus mismatch")

	var ghost_axe = data.get_weapon("ghost_axe")
	if not ghost_axe.is_empty():
		if "ethereal" not in ghost_axe.get("groups", []):
			failures.append("Ghost Axe should be Ethereal")
		if int(ghost_axe.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 40:
			failures.append("Ghost Axe tier 4 damage mismatch")
		if int(ghost_axe.get("tiers", {}).get("4", {}).get("damage_growth_kill_interval", 0)) != 12:
			failures.append("Ghost Axe tier 4 kill interval mismatch")

	var ghost_flint = data.get_weapon("ghost_flint")
	if not ghost_flint.is_empty():
		if "ethereal" not in ghost_flint.get("groups", []):
			failures.append("Ghost Flint should be Ethereal")
		if int(ghost_flint.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 18:
			failures.append("Ghost Flint tier 4 damage mismatch")
		if int(ghost_flint.get("tiers", {}).get("4", {}).get("attack_speed_growth_kill_interval", 0)) != 12:
			failures.append("Ghost Flint tier 4 kill interval mismatch")

	var ghost_scepter = data.get_weapon("ghost_scepter")
	if not ghost_scepter.is_empty():
		if "ethereal" not in ghost_scepter.get("groups", []):
			failures.append("Ghost Scepter should be Ethereal")
		if int(ghost_scepter.get("tiers", {}).get("4", {}).get("range", 0)) != 450:
			failures.append("Ghost Scepter tier 4 range mismatch")
		if int(ghost_scepter.get("tiers", {}).get("4", {}).get("max_hp_growth_kill_interval", 0)) != 12:
			failures.append("Ghost Scepter tier 4 kill interval mismatch")

	var scythe = data.get_weapon("scythe")
	if not scythe.is_empty():
		if "legendary" not in scythe.get("groups", []) or "ethereal" not in scythe.get("groups", []):
			failures.append("Scythe should be Legendary and Ethereal")
		if int(scythe.get("minimum_tier", 0)) != 4:
			failures.append("Scythe should start at tier 4")
		if int(scythe.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 150:
			failures.append("Scythe tier 4 damage mismatch")
		if int(round(float(scythe.get("tiers", {}).get("4", {}).get("self_damage_per_second", 0.0)))) != 3:
			failures.append("Scythe self-damage mismatch")

	var hiking_pole = data.get_weapon("hiking_pole")
	if not hiking_pole.is_empty():
		if "support" not in hiking_pole.get("groups", []):
			failures.append("Hiking Pole should be Support")
		if not hiking_pole.get("is_dlc", false):
			failures.append("Hiking Pole should be marked as DLC")
		if int(hiking_pole.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 30:
			failures.append("Hiking Pole tier 4 damage mismatch")
		if int(hiking_pole.get("tiers", {}).get("4", {}).get("range_gain_steps", 0)) != 40:
			failures.append("Hiking Pole tier 4 range-gain step mismatch")

	var lute = data.get_weapon("lute")
	if not lute.is_empty():
		if "support" not in lute.get("groups", []) or "musical" not in lute.get("groups", []):
			failures.append("Lute should be Support and Musical")
		if not lute.get("is_dlc", false):
			failures.append("Lute should be marked as DLC")
		if int(lute.get("tiers", {}).get("4", {}).get("range", 0)) != 225:
			failures.append("Lute tier 4 range mismatch")
		if int(round(float(lute.get("tiers", {}).get("4", {}).get("damage_taken_cap", 0.0)) * 100.0)) != 100:
			failures.append("Lute tier 4 damage-taken cap mismatch")

	var flute = data.get_weapon("flute")
	if not flute.is_empty():
		if "musical" not in flute.get("groups", []):
			failures.append("Flute should be Musical")
		if not flute.get("is_dlc", false):
			failures.append("Flute should be marked as DLC")
		if int(flute.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 15:
			failures.append("Flute tier 4 damage mismatch")
		if int(round(float(flute.get("tiers", {}).get("4", {}).get("charm_chance", 0.0)) * 100.0)) != 25:
			failures.append("Flute tier 4 charm chance mismatch")

	var pruner = data.get_weapon("pruner")
	if not pruner.is_empty():
		if "support" not in pruner.get("groups", []):
			failures.append("Pruner should be Support")
		if int(pruner.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 25:
			failures.append("Pruner tier 4 damage mismatch")
		if int(pruner.get("tiers", {}).get("4", {}).get("garden_fruit_interval", 0)) != 10:
			failures.append("Pruner tier 4 garden interval mismatch")

	var sickle = data.get_weapon("sickle")
	if not sickle.is_empty():
		if "support" not in sickle.get("groups", []):
			failures.append("Sickle should be Support")
		if not sickle.get("is_dlc", false):
			failures.append("Sickle should be marked as DLC")
		if int(sickle.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 15:
			failures.append("Sickle tier 4 damage mismatch")
		if int(round(float(sickle.get("tiers", {}).get("4", {}).get("low_health_damage_bonus", 0.0)) * 100.0)) != 50:
			failures.append("Sickle tier 4 low-health bonus mismatch")

	var potato_thrower = data.get_weapon("potato_thrower")
	if not potato_thrower.is_empty():
		if "support" not in potato_thrower.get("groups", []):
			failures.append("Potato Thrower should be Support")
		if int(potato_thrower.get("minimum_tier", 0)) != 2:
			failures.append("Potato Thrower should start at tier 2")
		if int(round(float(potato_thrower.get("tiers", {}).get("4", {}).get("cooldown", 0.0)) * 100.0)) != 25:
			failures.append("Potato Thrower tier 4 cooldown mismatch")
		if int(potato_thrower.get("tiers", {}).get("4", {}).get("knockback", 0)) != 30:
			failures.append("Potato Thrower tier 4 knockback mismatch")

	var stick = data.get_weapon("stick")
	if not stick.is_empty():
		if "primitive" not in stick.get("groups", []):
			failures.append("Stick should be Primitive")
		if int(stick.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 12:
			failures.append("Stick tier 4 damage mismatch")
		if int(stick.get("tiers", {}).get("4", {}).get("bonus_damage_per_additional_copy", 0)) != 10:
			failures.append("Stick tier 4 duplicate bonus mismatch")

	var hatchet = data.get_weapon("hatchet")
	if not hatchet.is_empty():
		if "primitive" not in hatchet.get("groups", []):
			failures.append("Hatchet should be Primitive")
		if int(hatchet.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 40:
			failures.append("Hatchet tier 4 damage mismatch")
		if int(round(float(hatchet.get("tiers", {}).get("4", {}).get("damage", {}).get("scaling", [])[1].get("coefficient", 0.0)) * 100.0)) != 15:
			failures.append("Hatchet tier 4 attack speed scaling mismatch")

	var javelin = data.get_weapon("javelin")
	if not javelin.is_empty():
		if "primitive" not in javelin.get("groups", []):
			failures.append("Javelin should be Primitive")
		if not javelin.get("is_dlc", false):
			failures.append("Javelin should be marked as DLC")
		if int(javelin.get("tiers", {}).get("4", {}).get("range", 0)) != 425:
			failures.append("Javelin tier 4 range mismatch")
		if int(javelin.get("tiers", {}).get("4", {}).get("pierce", {}).get("count", 0)) != 5:
			failures.append("Javelin tier 4 pierce mismatch")

	var quarterstaff = data.get_weapon("quarterstaff")
	if not quarterstaff.is_empty():
		if "primitive" not in quarterstaff.get("groups", []) or "medieval" not in quarterstaff.get("groups", []):
			failures.append("Quarterstaff should be Primitive and Medieval")
		if int(quarterstaff.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 30:
			failures.append("Quarterstaff tier 4 damage mismatch")
		if int(round(float(quarterstaff.get("tiers", {}).get("4", {}).get("xp_gain", 0.0)) * 100.0)) != 15:
			failures.append("Quarterstaff tier 4 XP gain mismatch")

	var rock = data.get_weapon("rock")
	if not rock.is_empty():
		if "primitive" not in rock.get("groups", []) or "blunt" not in rock.get("groups", []):
			failures.append("Rock should be Primitive and Blunt")
		if int(rock.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 70:
			failures.append("Rock tier 4 damage mismatch")
		if int(rock.get("tiers", {}).get("4", {}).get("armor_bonus", 0)) != 2:
			failures.append("Rock tier 4 armor bonus mismatch")

	var sharp_tooth = data.get_weapon("sharp_tooth")
	if not sharp_tooth.is_empty():
		if "primitive" not in sharp_tooth.get("groups", []) or "precise" not in sharp_tooth.get("groups", []):
			failures.append("Sharp Tooth should be Primitive and Precise")
		if int(sharp_tooth.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 15:
			failures.append("Sharp Tooth tier 4 damage mismatch")
		if int(sharp_tooth.get("tiers", {}).get("4", {}).get("missing_health_lifesteal_step", 0)) != 10:
			failures.append("Sharp Tooth tier 4 missing-health step mismatch")

	var slingshot = data.get_weapon("slingshot")
	if not slingshot.is_empty():
		if "primitive" not in slingshot.get("groups", []):
			failures.append("Slingshot should be Primitive")
		if int(slingshot.get("tiers", {}).get("4", {}).get("damage", {}).get("base", 0)) != 20:
			failures.append("Slingshot tier 4 damage mismatch")
		if int(slingshot.get("tiers", {}).get("4", {}).get("bounces", 0)) != 4:
			failures.append("Slingshot tier 4 bounce mismatch")

func _check_weapon_groups_match_reference_classes(data):
	var expected_class_ids := {
		"blade": true,
		"blunt": true,
		"elemental": true,
		"ethereal": true,
		"explosive": true,
		"gun": true,
		"heavy": true,
		"legendary": true,
		"medical": true,
		"medieval": true,
		"musical": true,
		"naval": true,
		"precise": true,
		"primitive": true,
		"support": true,
		"engineering": true,
		"unarmed": true,
	}
	if not data.get_weapon_class("melee").is_empty():
		failures.append("Melee should be represented by attack_kind, not as a weapon class")
	for class_id in expected_class_ids:
		if data.get_weapon_class(class_id).is_empty():
			failures.append("Missing reference weapon class: " + class_id)
	for weapon_id in data.get_weapons(true):
		var weapon = data.get_weapon(weapon_id)
		for group in weapon.get("groups", []):
			if not expected_class_ids.has(str(group)):
				failures.append("%s references non-reference weapon class group: %s" % [weapon_id, group])

func _check_runtime_aliases_resolve_to_reference_rows(data):
	var expected_alias_targets := {
		"laser": "laser_gun",
		"plasma": "plasma_sledge",
		"grenade": "grenade_launcher",
	}
	for alias in expected_alias_targets:
		var row = data.get_weapon(alias)
		if row.is_empty():
			failures.append("Runtime alias did not resolve: " + alias)
			continue
		var expected_id = expected_alias_targets[alias]
		if row.get("id", "") != expected_id:
			failures.append("Runtime alias %s should resolve to %s, got %s" % [alias, expected_id, row.get("id", "")])

func _check_runtime_aliases_do_not_shadow_reference_ids(data):
	var weapons = data.get_weapons(true)
	for weapon_id in weapons:
		var row: Dictionary = weapons[weapon_id]
		for alias in row.get("runtime_aliases", []):
			if weapons.has(str(alias)):
				failures.append("Runtime alias shadows a real weapon id: %s -> %s" % [alias, weapon_id])

func _check_catalog_combat_dict_has_no_empty_entries():
	var combat = WeaponDatabase.catalog_combat_dict(true)
	for weapon_id in combat:
		if combat[weapon_id].is_empty():
			failures.append("Catalog combat dict exposed empty entry: " + str(weapon_id))

func _check_catalog_shop_pool_does_not_mix_legacy_only_weapons():
	var shop_script = load("res://scripts/Shop.gd")
	if shop_script == null:
		failures.append("Shop script failed to load for catalog-only check")
		return
	var db = load("res://data/weapons.tres") as WeaponDatabase
	if db == null:
		failures.append("Legacy weapon database failed to load for catalog-only check")
		return
	var catalog_entries = WeaponDatabase.catalog_shop_entries(false)
	if catalog_entries.is_empty():
		failures.append("Catalog shop entries should be available before testing fallback behavior")
		return
	var shop = shop_script.new()
	var selected_entries = shop._merge_weapon_entries(catalog_entries, db.to_shop_entries())
	var catalog_types: Dictionary = {}
	for entry in catalog_entries:
		catalog_types[str(entry.get("weapon_type", ""))] = true
	for entry in selected_entries:
		if entry.get("type", "") != "weapon":
			continue
		var weapon_type = str(entry.get("weapon_type", ""))
		if not catalog_types.has(weapon_type):
			failures.append("Catalog-backed shop should not mix legacy-only weapon: " + weapon_type)
