# TurretManager.gd — 工程师炮塔系统 + 死灵法师亡灵系统
class_name TurretManager
extends Node

var active_turrets = []
var active_undeads = []
var active_gardens = []
var active_landmines = []
var active_wandering_bots = []

var main: Node2D

func setup(p_main: Node2D):
	main = p_main

# ──── 工程师炮塔系统 ────

func on_request_turret(pos: Vector2):
	var turret = Node2D.new()
	turret.position = pos
	turret.set_meta("shoot_timer", 0.0)
	turret.set_meta("lifetime", 20.0)
	turret.set_meta("damage", 3)
	turret.set_meta("base_damage", 3.0)
	turret.set_meta("engineering_damage_coefficient", 0.0)
	turret.set_meta("attack_interval", 2.0)
	turret.add_to_group("structures")

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
	])
	body.color = Color(0.3, 0.9, 0.3)
	body.name = "Body"
	turret.add_child(body)

	var barrel = Polygon2D.new()
	barrel.polygon = PackedVector2Array([
		Vector2(-2, -15), Vector2(2, -15), Vector2(2, 0), Vector2(-2, 0)
	])
	barrel.color = Color(0.2, 0.7, 0.2)
	barrel.name = "Barrel"
	turret.add_child(barrel)

	var detect = Area2D.new()
	detect.name = "DetectArea"
	detect.collision_layer = 0
	detect.collision_mask = 2
	detect.monitorable = false
	var det_shape = CollisionShape2D.new()
	var det_circle = CircleShape2D.new()
	det_circle.radius = 300.0
	det_shape.shape = det_circle
	detect.add_child(det_shape)
	turret.add_child(detect)

	main.add_child(turret)
	active_turrets.append(turret)
	Effects.hit_spark(pos, Color(0.3, 0.9, 0.3))
	main.hud.show_notification("炮塔已部署！", Color(0.3, 0.9, 0.3))

func process_turrets(delta):
	var expired = []
	for turret in active_turrets:
		if not is_instance_valid(turret):
			expired.append(turret)
			continue
		var lifetime = float(turret.get_meta("lifetime", -1.0))
		if lifetime > 0.0:
			lifetime -= delta
			turret.set_meta("lifetime", lifetime)
			if lifetime <= 0:
				expired.append(turret)
				continue
			if lifetime <= 3.0:
				turret.modulate.a = 0.5 + 0.5 * sin(lifetime * 8.0)

		var shoot_timer = turret.get_meta("shoot_timer") - delta
		if shoot_timer <= 0:
			shoot_timer = _get_turret_attack_interval(float(turret.get_meta("attack_interval", 2.0)))
			if bool(turret.get_meta("is_medical_turret", false)):
				_process_medical_turret_action(turret)
			else:
				_process_damage_turret_action(turret)
		turret.set_meta("shoot_timer", shoot_timer)
	for t in expired:
		active_turrets.erase(t)
		if is_instance_valid(t):
			t.queue_free()

# ──── 死灵法师亡灵系统 ────

func _get_turret_attack_interval(base_interval: float) -> float:
	if main and main.player and is_instance_valid(main.player) and main.player.has_method("get_structure_attack_interval"):
		return main.player.get_structure_attack_interval(base_interval)
	return base_interval

func calculate_structure_damage(structure, critical_roll: float = -1.0) -> int:
	if structure == null or not is_instance_valid(structure):
		return 0
	var base_damage = float(structure.get_meta("base_damage", structure.get_meta("damage", 1)))
	var coefficient = float(structure.get_meta("engineering_damage_coefficient", 0.0))
	var elemental_coefficient = float(structure.get_meta("elemental_damage_coefficient", 0.0))
	var engineering = 0.0
	var elemental = 0.0
	if main and main.player and is_instance_valid(main.player):
		engineering = float(main.player.get("engineering_bonus")) if main.player.get("engineering_bonus") != null else 0.0
		elemental = float(main.player.get("elemental_damage_bonus")) if main.player.get("elemental_damage_bonus") != null else 0.0
	var amount = max(1, int(round(base_damage + engineering * coefficient + elemental * elemental_coefficient)))
	amount = _apply_structure_critical_damage(amount, critical_roll)
	if bool(structure.get_meta("uses_explosion_modifiers", false)) and main and main.player and is_instance_valid(main.player):
		amount = max(1, int(round(float(amount) * max(0.0, 1.0 + float(main.player.get("explosion_damage_percent"))))))
	return amount

func _apply_structure_critical_damage(amount: int, critical_roll: float = -1.0) -> int:
	if main == null or main.player == null or not is_instance_valid(main.player):
		return amount
	if main.player.get("structures_can_crit_sources") == null or int(main.player.get("structures_can_crit_sources")) <= 0:
		return amount
	var crit_chance = float(main.player.get("crit_chance")) if main.player.get("crit_chance") != null else 0.0
	if crit_chance <= 0.0:
		return amount
	var roll = randf() if critical_roll < 0.0 else critical_roll
	if roll >= crit_chance:
		return amount
	var crit_damage = float(main.player.get("crit_damage")) if main.player.get("crit_damage") != null else 2.0
	return max(1, int(round(float(amount) * max(1.0, crit_damage))))

func calculate_structure_healing(structure) -> int:
	if structure == null or not is_instance_valid(structure):
		return 0
	var base_healing = float(structure.get_meta("base_healing", 1.0))
	var coefficient = float(structure.get_meta("engineering_heal_coefficient", 0.0))
	var engineering = 0.0
	if main and main.player and is_instance_valid(main.player):
		engineering = float(main.player.get("engineering_bonus")) if main.player.get("engineering_bonus") != null else 0.0
	return max(1, int(round(base_healing + engineering * coefficient)))

func _process_damage_turret_action(turret):
	var nearest = _find_nearest_turret_target(turret)
	if nearest == null:
		return
	var dmg = calculate_structure_damage(turret)
	if bool(turret.get_meta("uses_explosion_modifiers", false)):
		_deal_structure_explosion(turret, nearest.position, dmg)
	else:
		_apply_structure_damage_to_enemy(nearest, dmg, Color(0.3, 0.9, 0.3))
	if bool(turret.get_meta("applies_burn", false)) and nearest.has_method("apply_burn"):
		nearest.apply_burn(main.player if main and main.player and is_instance_valid(main.player) else null)
		if main and main.player and is_instance_valid(main.player) and main.player.has_method("on_enemy_burn_applied"):
			main.player.on_enemy_burn_applied(nearest)
	_rotate_turret_barrel(turret, nearest.position)

func _process_medical_turret_action(turret):
	if main == null or main.player == null or not is_instance_valid(main.player):
		return
	var radius = float(turret.get_meta("heal_radius", 250.0))
	if turret.position.distance_to(main.player.position) > radius:
		return
	if int(main.player.get("hp")) >= int(main.player.get("max_hp")):
		return
	var healing = calculate_structure_healing(turret)
	if main.player.has_method("heal"):
		main.player.heal(healing)
		Effects.hit_spark(main.player.position, Color(0.35, 1.0, 0.72))
		_rotate_turret_barrel(turret, main.player.position)

func _find_nearest_turret_target(turret):
	if turret == null or not is_instance_valid(turret) or not turret.has_node("DetectArea"):
		return null
	var nearest = null
	var nearest_dist = 300.0
	var shape_node = turret.get_node_or_null("DetectArea/CollisionShape2D")
	if shape_node != null and shape_node.shape is CircleShape2D:
		nearest_dist = float(shape_node.shape.radius)
	for enemy in turret.get_node("DetectArea").get_overlapping_bodies():
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		var d = turret.position.distance_to(enemy.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest

func _apply_structure_damage_to_enemy(enemy, amount: int, spark_color: Color):
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
	enemy.take_damage(amount)
	Effects.hit_spark(enemy.position, spark_color)
	if main and main.player and is_instance_valid(main.player):
		main.player.total_damage_dealt += amount

func _deal_structure_explosion(structure, center: Vector2, amount: int):
	var radius = float(structure.get_meta("explosion_radius", 80.0))
	if main and main.player and is_instance_valid(main.player) and main.player.get("explosion_size_percent") != null:
		radius = max(1.0, radius * max(0.0, 1.0 + float(main.player.get("explosion_size_percent"))))
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		if center.distance_to(enemy.position) <= radius:
			_apply_structure_damage_to_enemy(enemy, amount, Color(1.0, 0.55, 0.18))

func _rotate_turret_barrel(turret, target_position: Vector2):
	if turret == null or not is_instance_valid(turret) or not turret.has_node("Barrel"):
		return
	var dir = (target_position - turret.position).angle()
	turret.get_node("Barrel").rotation = dir + PI / 2.0

func spawn_catalog_turret(pos: Vector2, base_damage: float = 10.0, engineering_coefficient: float = 0.80, range: float = 300.0, cooldown: float = 0.73):
	var turret = Node2D.new()
	turret.position = pos
	turret.set_meta("shoot_timer", 0.0)
	turret.set_meta("lifetime", -1.0)
	turret.set_meta("damage", max(1, int(round(base_damage))))
	turret.set_meta("base_damage", base_damage)
	turret.set_meta("engineering_damage_coefficient", engineering_coefficient)
	turret.set_meta("attack_interval", max(0.05, cooldown))
	turret.add_to_group("structures")
	turret.add_to_group("catalog_turrets")

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
	])
	body.color = Color(0.35, 0.75, 0.95)
	body.name = "Body"
	turret.add_child(body)

	var barrel = Polygon2D.new()
	barrel.polygon = PackedVector2Array([
		Vector2(-2, -16), Vector2(2, -16), Vector2(2, 0), Vector2(-2, 0)
	])
	barrel.color = Color(0.24, 0.56, 0.82)
	barrel.name = "Barrel"
	turret.add_child(barrel)

	var detect = Area2D.new()
	detect.name = "DetectArea"
	detect.collision_layer = 0
	detect.collision_mask = 2
	detect.monitorable = false
	var det_shape = CollisionShape2D.new()
	var det_circle = CircleShape2D.new()
	det_circle.radius = max(1.0, range)
	det_shape.shape = det_circle
	detect.add_child(det_shape)
	turret.add_child(detect)

	main.add_child(turret)
	active_turrets.append(turret)
	Effects.hit_spark(pos, Color(0.35, 0.75, 0.95))
	return turret

func spawn_damage_turret_variant(pos: Vector2, variant: String, base_damage: float, engineering_coefficient: float, range: float = 300.0, cooldown: float = 1.0, options: Dictionary = {}):
	var turret = spawn_catalog_turret(pos, base_damage, engineering_coefficient, range, cooldown)
	turret.set_meta("variant", variant)
	turret.set_meta("uses_explosion_modifiers", bool(options.get("uses_explosion_modifiers", false)))
	turret.set_meta("explosion_radius", float(options.get("explosion_radius", 80.0)))
	turret.set_meta("ammo_type", str(options.get("ammo_type", "")))
	turret.set_meta("applies_burn", bool(options.get("applies_burn", false)))
	turret.set_meta("hit_count", int(options.get("hit_count", 1)))
	turret.add_to_group("turret_variants")
	turret.add_to_group(variant)
	if turret.has_node("Body"):
		turret.get_node("Body").color = options.get("body_color", Color(0.35, 0.75, 0.95))
	if turret.has_node("Barrel"):
		turret.get_node("Barrel").color = options.get("barrel_color", Color(0.24, 0.56, 0.82))
	return turret

func spawn_medical_turret(pos: Vector2, base_healing: float = 3.0, engineering_heal_coefficient: float = 0.05, range: float = 250.0, cooldown: float = 2.0):
	var turret = spawn_catalog_turret(pos, 1.0, 0.0, range, cooldown)
	turret.set_meta("variant", "medical_turret")
	turret.set_meta("is_medical_turret", true)
	turret.set_meta("base_healing", base_healing)
	turret.set_meta("engineering_heal_coefficient", engineering_heal_coefficient)
	turret.set_meta("heal_radius", max(1.0, range))
	turret.add_to_group("turret_variants")
	turret.add_to_group("medical_turrets")
	if turret.has_node("Body"):
		turret.get_node("Body").color = Color(0.24, 0.86, 0.58)
	if turret.has_node("Barrel"):
		turret.get_node("Barrel").color = Color(0.66, 1.0, 0.78)
	return turret

func spawn_tyler(pos: Vector2, projectiles: int = 10, base_damage: float = 12.0, engineering_coefficient: float = 0.90, elemental_coefficient: float = 0.90, range: float = 360.0, cooldown: float = 1.0):
	var tyler = spawn_damage_turret_variant(
		pos,
		"tyler",
		base_damage,
		engineering_coefficient,
		range,
		cooldown,
		{
			"body_color": Color(0.62, 0.38, 0.95),
			"barrel_color": Color(0.95, 0.78, 1.0),
			"hit_count": max(1, projectiles),
		}
	)
	tyler.set_meta("projectiles", max(1, projectiles))
	tyler.set_meta("elemental_damage_coefficient", elemental_coefficient)
	tyler.add_to_group("tylers")
	return tyler

func spawn_builders_turret(pos: Vector2):
	var profile = _get_builders_turret_profile()
	var turret = spawn_damage_turret_variant(
		pos,
		"builders_turret",
		float(profile.get("damage", 10.0)),
		1.0,
		float(profile.get("range", 300.0)),
		float(profile.get("cooldown", 0.73)),
		{
			"body_color": Color(0.94, 0.74, 0.30),
			"barrel_color": Color(0.36, 0.26, 0.18),
			"hit_count": int(profile.get("projectiles", 1)),
		}
	)
	turret.set_meta("builder_weapon_type", str(profile.get("weapon_type", "")))
	turret.set_meta("projectiles", int(profile.get("projectiles", 1)))
	turret.add_to_group("builders_turrets")
	return turret

func _get_builders_turret_profile() -> Dictionary:
	var profile := {
		"weapon_type": "",
		"damage": 10.0,
		"fire_rate": 1.0 / 0.73,
		"range": 300.0,
		"projectiles": 1,
	}
	var best_score = -1.0
	if main == null or main.player == null or not is_instance_valid(main.player):
		profile["cooldown"] = 0.73
		return profile
	for weapon in main.player.equipped_weapons:
		if not (weapon is Dictionary):
			continue
		var weapon_data: Dictionary = weapon.get("data", {})
		if weapon_data.is_empty() or bool(weapon_data.get("melee", false)):
			continue
		var damage = max(1.0, float(weapon_data.get("damage", 1.0)))
		var fire_rate = max(0.01, float(weapon_data.get("fire_rate", 1.0)))
		var projectiles = max(1, int(weapon_data.get("count", weapon_data.get("projectiles", 1))))
		var score = damage * fire_rate * float(projectiles)
		if score <= best_score:
			continue
		best_score = score
		profile["weapon_type"] = str(weapon.get("type", ""))
		profile["damage"] = damage
		profile["fire_rate"] = fire_rate
		profile["range"] = max(1.0, float(weapon_data.get("range", 300.0)))
		profile["projectiles"] = projectiles
	profile["cooldown"] = 1.0 / max(0.01, float(profile.get("fire_rate", 1.0)))
	return profile

func spawn_wandering_bot(pos: Vector2, slow_percent: float = 0.30, slow_duration: float = 0.5, radius: float = 180.0):
	var bot = Node2D.new()
	bot.position = pos
	bot.set_meta("slow_percent", clamp(slow_percent, 0.0, 0.9))
	bot.set_meta("slow_duration", max(0.05, slow_duration))
	bot.set_meta("slow_radius", max(1.0, radius))
	bot.add_to_group("structures")
	bot.add_to_group("wandering_bots")

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -11), Vector2(10, -2), Vector2(7, 10), Vector2(-7, 10), Vector2(-10, -2)
	])
	body.color = Color(0.35, 0.82, 0.95)
	body.name = "Body"
	bot.add_child(body)

	var aura = Polygon2D.new()
	aura.polygon = PackedVector2Array([
		Vector2(-16, -4), Vector2(16, -4), Vector2(16, 4), Vector2(-16, 4)
	])
	aura.color = Color(0.25, 0.62, 1.0, 0.35)
	aura.name = "Aura"
	bot.add_child(aura)

	main.add_child(bot)
	active_wandering_bots.append(bot)
	Effects.hit_spark(pos, Color(0.35, 0.82, 0.95))
	return bot

func process_wandering_bots(delta: float):
	var expired = []
	for bot in active_wandering_bots:
		if not is_instance_valid(bot):
			expired.append(bot)
			continue
		if main and main.player and is_instance_valid(main.player):
			var to_player = main.player.position - bot.position
			if to_player.length() > 120.0:
				bot.position += to_player.normalized() * 80.0 * delta
		var radius = float(bot.get_meta("slow_radius", 180.0))
		var slow_percent = float(bot.get_meta("slow_percent", 0.30))
		var slow_duration = float(bot.get_meta("slow_duration", 0.5))
		for enemy in main.get_tree().get_nodes_in_group("enemies"):
			if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("apply_slow"):
				continue
			if bot.position.distance_to(enemy.position) <= radius:
				enemy.apply_slow(slow_percent, slow_duration)
	for bot in expired:
		active_wandering_bots.erase(bot)

func on_request_undead(pos: Vector2):
	if active_undeads.size() >= 5:
		return
	var undead = Node2D.new()
	undead.position = pos
	undead.set_meta("lifetime", 15.0)
	undead.set_meta("attack_timer", 0.0)
	undead.set_meta("damage", 2)
	undead.set_meta("speed", 120.0)
	undead.add_to_group("undeads")

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(10, 10), Vector2(-10, 10)
	])
	body.color = Color(0.6, 0.2, 0.8)
	body.name = "Body"
	undead.add_child(body)

	var detect = Area2D.new()
	detect.name = "DetectArea"
	detect.collision_layer = 0
	detect.collision_mask = 2
	detect.monitorable = false
	var det_shape = CollisionShape2D.new()
	var det_circle = CircleShape2D.new()
	det_circle.radius = 200.0
	det_shape.shape = det_circle
	detect.add_child(det_shape)
	undead.add_child(detect)

	main.add_child(undead)
	active_undeads.append(undead)
	Effects.hit_spark(pos, Color(0.6, 0.2, 0.8))

func process_undeads(delta):
	var expired = []
	for undead in active_undeads:
		if not is_instance_valid(undead):
			expired.append(undead)
			continue
		var lifetime = undead.get_meta("lifetime") - delta
		undead.set_meta("lifetime", lifetime)
		if lifetime <= 0:
			expired.append(undead)
			continue

		if lifetime <= 3.0:
			undead.modulate.a = 0.5 + 0.5 * sin(lifetime * 8.0)

		var nearest = null
		var nearest_dist = INF
		for enemy in undead.get_node("DetectArea").get_overlapping_bodies():
			var d = undead.position.distance_to(enemy.position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy

		if nearest:
			var spd = undead.get_meta("speed")
			var dir = (nearest.position - undead.position).normalized()
			undead.position += dir * spd * delta
			undead.rotation = dir.angle() + PI / 2.0

			var attack_timer = undead.get_meta("attack_timer") - delta
			if nearest_dist < 30.0 and attack_timer <= 0:
				attack_timer = 1.0
				var dmg = undead.get_meta("damage")
				nearest.take_damage(dmg)
				Effects.hit_spark(nearest.position, Color(0.6, 0.2, 0.8))
				if main.player and is_instance_valid(main.player):
					main.player.total_damage_dealt += dmg
			undead.set_meta("attack_timer", attack_timer)
		else:
			if main.player and is_instance_valid(main.player):
				var to_player = (main.player.position - undead.position)
				if to_player.length() > 60:
					undead.position += to_player.normalized() * undead.get_meta("speed") * delta

	for u in expired:
		active_undeads.erase(u)
		if is_instance_valid(u):
			u.queue_free()

# Garden consumable structures

func spawn_garden(pos: Vector2, base_interval: float = 15.0):
	var garden = Node2D.new()
	garden.position = pos
	garden.set_meta("base_interval", max(0.05, base_interval))
	garden.set_meta("fruit_timer", _get_garden_interval(garden))
	garden.add_to_group("gardens")
	garden.add_to_group("structures")

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8), Vector2(12, 8), Vector2(-12, 8)
	])
	body.color = Color(0.24, 0.55, 0.22)
	body.name = "Body"
	garden.add_child(body)

	var fruit_marker = Polygon2D.new()
	fruit_marker.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(7, 2), Vector2(0, 9), Vector2(-7, 2)
	])
	fruit_marker.color = Color(0.4, 1.0, 0.35)
	fruit_marker.name = "FruitMarker"
	garden.add_child(fruit_marker)

	main.add_child(garden)
	active_gardens.append(garden)
	_spawn_garden_fruit(garden)
	return garden

func process_gardens(delta: float):
	var expired = []
	for garden in active_gardens:
		if not is_instance_valid(garden):
			expired.append(garden)
			continue
		var timer = float(garden.get_meta("fruit_timer", 15.0)) - delta
		var interval = _get_garden_interval(garden)
		while timer <= 0.0:
			_spawn_garden_fruit(garden)
			timer += interval
		garden.set_meta("fruit_timer", timer)
	for garden in expired:
		active_gardens.erase(garden)

func _spawn_garden_fruit(garden):
	if main == null or main.pickup_manager == null or not is_instance_valid(garden):
		return
	main.pickup_manager._spawn_pickup(garden.position, "fruit")

func _get_garden_interval(garden) -> float:
	var base_interval = float(garden.get_meta("base_interval", 15.0)) if garden != null and is_instance_valid(garden) else 15.0
	if main and main.player and is_instance_valid(main.player) and main.player.has_method("get_structure_attack_interval"):
		return main.player.get_structure_attack_interval(base_interval)
	return max(0.05, base_interval)

# Landmine structures

func spawn_landmine(pos: Vector2, base_damage: float = 10.0, engineering_coefficient: float = 1.0, radius: float = 80.0):
	var mine = Node2D.new()
	mine.position = pos
	mine.set_meta("base_damage", base_damage)
	mine.set_meta("engineering_damage_coefficient", engineering_coefficient)
	mine.set_meta("explosion_radius", max(1.0, radius))
	mine.set_meta("uses_explosion_modifiers", true)
	mine.add_to_group("structures")
	mine.add_to_group("landmines")

	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(9, 0), Vector2(0, 8), Vector2(-9, 0)
	])
	body.color = Color(0.95, 0.62, 0.18)
	body.name = "Body"
	mine.add_child(body)

	main.add_child(mine)
	active_landmines.append(mine)
	return mine

func process_landmines(_delta: float):
	var snapshot = active_landmines.duplicate()
	for mine in snapshot:
		if not is_instance_valid(mine):
			active_landmines.erase(mine)
			continue
		var trigger_radius = max(24.0, float(mine.get_meta("explosion_radius", 80.0)) * 0.5)
		for enemy in main.get_tree().get_nodes_in_group("enemies"):
			if enemy != null and is_instance_valid(enemy) and enemy.visible and mine.position.distance_to(enemy.position) <= trigger_radius:
				trigger_landmine(mine)
				break

func trigger_landmine(mine):
	if mine == null or not is_instance_valid(mine):
		return
	var radius = float(mine.get_meta("explosion_radius", 80.0))
	if main and main.player and is_instance_valid(main.player) and main.player.get("explosion_size_percent") != null:
		radius = max(1.0, radius * max(0.0, 1.0 + float(main.player.get("explosion_size_percent"))))
	var amount = calculate_structure_damage(mine)
	for enemy in main.get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible or not enemy.has_method("take_damage"):
			continue
		if mine.position.distance_to(enemy.position) <= radius:
			enemy.take_damage(amount)
			Effects.hit_spark(enemy.position, Color(1.0, 0.6, 0.2))
			if main.player and is_instance_valid(main.player):
				main.player.total_damage_dealt += amount
	active_landmines.erase(mine)
	mine.queue_free()

func cleanup():
	for turret in active_turrets:
		if is_instance_valid(turret):
			turret.queue_free()
	active_turrets.clear()
	for undead in active_undeads:
		if is_instance_valid(undead):
			undead.queue_free()
	active_undeads.clear()
	for garden in active_gardens:
		if is_instance_valid(garden):
			garden.queue_free()
	active_gardens.clear()
	for mine in active_landmines:
		if is_instance_valid(mine):
			mine.queue_free()
	active_landmines.clear()
	for bot in active_wandering_bots:
		if is_instance_valid(bot):
			bot.queue_free()
	active_wandering_bots.clear()
