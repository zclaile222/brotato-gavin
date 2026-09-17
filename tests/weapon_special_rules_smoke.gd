extends SceneTree

# Weapon Special Rules Runtime Smoke Test
# Verifies that catalog weapon special rules are passed into combat entries
# and that the dispatcher recognizes key rules.

const PASS_TAG = "WEAPON_SPECIAL_RULES_SMOKE_PASS"
const FAIL_TAG = "WEAPON_SPECIAL_RULES_SMOKE_FAIL"

var failures: Array[String] = []

func _fail(msg: String):
	failures.append(msg)
	print("FAIL: " + msg)

func _assert_eq(actual, expected, msg: String):
	if actual != expected:
		_fail(msg + " (expected %s, got %s)" % [str(expected), str(actual)])

func _assert_true(value: bool, msg: String):
	if not value:
		_fail(msg)

func _assert_has_rule(combat_entry: Dictionary, rule: String, msg: String):
	var rules: Array = combat_entry.get("special_rules", [])
	var found = false
	for r in rules:
		if r is Dictionary and r.get("rule", "") == rule:
			found = true
			break
	if not found:
		_fail(msg + " (missing rule: %s)" % rule)

func _assert_field_positive(combat_entry: Dictionary, field: String, msg: String):
	var v = combat_entry.get(field, 0)
	if v == 0:
		_fail(msg + " (%s missing or zero)" % field)

func _init():
	var BrotatoData = load("res://scripts/BrotatoData.gd")
	var data = BrotatoData.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		_fail("catalog load failed: " + ", ".join(errors))
		_finish()
		return

	# Verify combat dict includes special_rules and tier fields
	var torch = data.weapon_tier_to_combat_entry("torch", 1)
	_assert_has_rule(torch, "burn", "Torch should have burn rule")
	_assert_field_positive(torch, "burn_damage", "Torch tier 1 should have burn_damage")
	_assert_field_positive(torch, "burn_instances", "Torch tier 1 should have burn_instances")
	_assert_has_rule(torch, "burn_spread_by_tier", "Torch should have burn_spread_by_tier")

	var db_shotgun = data.weapon_tier_to_combat_entry("double_barrel_shotgun", 1)
	_assert_has_rule(db_shotgun, "pierce_falloff", "Double Barrel Shotgun should have pierce_falloff")

	var revolver = data.weapon_tier_to_combat_entry("revolver", 1)
	_assert_has_rule(revolver, "sixth_shot_longer_cooldown", "Revolver should have sixth_shot_longer_cooldown")

	var quarterstaff = data.weapon_tier_to_combat_entry("quarterstaff", 1)
	_assert_has_rule(quarterstaff, "alternate_thrust_and_sweep", "Quarterstaff should have alternate_thrust_and_sweep")

	var particle = data.weapon_tier_to_combat_entry("particle_accelerator", 3)
	_assert_has_rule(particle, "full_pierce", "Particle Accelerator should have full_pierce")

	var rocket = data.weapon_tier_to_combat_entry("rocket_launcher", 2)
	_assert_has_rule(rocket, "projectile_explosion_on_hit", "Rocket Launcher should have projectile_explosion_on_hit")

	var javelin = data.weapon_tier_to_combat_entry("javelin", 1)
	_assert_has_rule(javelin, "every_nth_projectile_guaranteed_crit", "Javelin should have every_nth_projectile_guaranteed_crit")
	_assert_field_positive(javelin, "critical_projectile_interval", "Javelin should have critical_projectile_interval")

	var sickle = data.weapon_tier_to_combat_entry("sickle", 1)
	_assert_has_rule(sickle, "bonus_damage_against_low_health", "Sickle should have bonus_damage_against_low_health")

	var chainsaw = data.weapon_tier_to_combat_entry("chainsaw", 3)
	_assert_has_rule(chainsaw, "reload_every_n_attacks_by_tier", "Chainsaw should have reload_every_n_attacks_by_tier")
	_assert_has_rule(chainsaw, "current_health_bonus_damage", "Chainsaw should have current_health_bonus_damage")

	var drill = data.weapon_tier_to_combat_entry("drill", 4)
	_assert_has_rule(drill, "material_on_critical_kill", "Drill should have material_on_critical_kill")
	_assert_has_rule(drill, "attack_speed_growth_over_wave", "Drill should have attack_speed_growth_over_wave")

	var railgun = data.weapon_tier_to_combat_entry("railgun", 1)
	_assert_has_rule(railgun, "damage_charges_until_hit", "Railgun should have damage_charges_until_hit")

	# Verify full combat dict exposes catalog_tiers with special_rules
	var combat_dict = data.get_combat_dict(true)
	_assert_true(combat_dict.has("torch"), "Combat dict should include torch")
	var torch_entry = combat_dict["torch"]
	_assert_true(torch_entry.has("catalog_tiers"), "Torch combat entry should have catalog_tiers")
	_assert_true(torch_entry.has("special_rules"), "Torch combat entry should have special_rules")

	_finish()

func _finish():
	if failures.is_empty():
		print(PASS_TAG)
	else:
		print(FAIL_TAG)
		for f in failures:
			print("  - " + f)
	quit()
