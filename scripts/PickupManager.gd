# PickupManager.gd — 战利品拾取物系统
class_name PickupManager
extends Node

const PICKUP_TYPES = {
	"fruit": {"name": "水果", "color": Color(0.25, 1.0, 0.35), "heal_amount": 3, "crate_tier": 0},
	"crate": {"name": "战利品箱", "color": Color(0.75, 0.45, 0.18), "heal_amount": 3, "crate_tier": 1},
	"legendary_crate": {"name": "传奇箱", "color": Color(1.0, 0.82, 0.18), "heal_amount": 100, "crate_tier": 4},
}

const LEGACY_BUFF_PICKUP_TYPES = {
	"speed_boost": {"name": "速度提升", "color": Color(0.2, 0.8, 1.0), "duration": 10.0},
	"damage_boost": {"name": "伤害提升", "color": Color(1.0, 0.3, 0.2), "duration": 10.0},
	"rapid_fire": {"name": "急速射击", "color": Color(1.0, 0.8, 0.0), "duration": 8.0},
	"shield": {"name": "护盾", "color": Color(0.3, 0.5, 1.0), "duration": 0.0},
	"vampire_fang": {"name": "吸血之牙", "color": Color(0.8, 0.1, 0.3), "duration": 15.0},
}

var active_pickup_nodes = []

# 对象池
const POOL_SIZE = 20
var _pool_available = []
var _pool_polygon = {}  # pickup -> Polygon2D
var _pool_shape = {}    # pickup -> CollisionShape2D

var main: Node2D
var loot_rules = preload("res://scripts/LootRules.gd").new()
var crates_dropped_this_wave = 0

func setup(p_main: Node2D):
	main = p_main
	_init_pool()

func _init_pool():
	for i in POOL_SIZE:
		var pickup = Area2D.new()
		pickup.collision_layer = 0
		pickup.collision_mask = 1
		pickup.monitorable = false
		pickup.visible = false
		var shape = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 80.0
		shape.shape = circle_shape
		pickup.add_child(shape)
		var circle = Polygon2D.new()
		var points = PackedVector2Array()
		for j in range(16):
			var angle = j * TAU / 16.0
			points.append(Vector2(cos(angle), sin(angle)) * 10.0)
		circle.polygon = points
		pickup.add_child(circle)
		main.add_child(pickup)
		_pool_available.append(pickup)
		_pool_polygon[pickup] = circle
		_pool_shape[pickup] = shape

func _try_spawn_pickup(enemy):
	var etype = enemy.get("enemy_type") if enemy.get("enemy_type") else "normal"
	var luck = main.player.luck if main and main.player and is_instance_valid(main.player) else 0
	var fruit_drop_bonus = 0.0
	if main and main.player and is_instance_valid(main.player) and main.player.get("fruit_drop_chance_bonus") != null:
		fruit_drop_bonus = float(main.player.get("fruit_drop_chance_bonus"))
	var drop = loot_rules.roll_pickup_kind(etype, luck, crates_dropped_this_wave, fruit_drop_bonus)
	if drop.is_empty():
		return
	var kind = drop.get("kind", "fruit")
	if kind in ["crate", "legendary_crate"]:
		crates_dropped_this_wave += 1
	_spawn_pickup(enemy.position, kind)

func begin_wave():
	crates_dropped_this_wave = 0

func _spawn_pickup(pos: Vector2, ptype: String):
	var data = PICKUP_TYPES[ptype]
	var pickup = _get_pooled_pickup()
	pickup.position = pos
	pickup.modulate = Color(1, 1, 1, 1)
	pickup.set_meta("pickup_type", ptype)
	pickup.set_meta("pickup_kind", ptype)
	pickup.set_meta("heal_amount", int(data.get("heal_amount", 0)))
	pickup.set_meta("crate_tier", int(data.get("crate_tier", 0)))
	pickup.visible = true

	# 更新视觉颜色
	if _pool_polygon.has(pickup):
		_pool_polygon[pickup].color = data.color

	# 断开旧连接（ptype 可能不同），重新连接
	var old_callable = _get_pickup_callable(pickup)
	if old_callable and pickup.body_entered.is_connected(old_callable):
		pickup.body_entered.disconnect(old_callable)
	pickup.body_entered.connect(_on_pickup_collected.bind(pickup, ptype))
	pickup.set_meta("collected_callable", _on_pickup_collected.bind(pickup, ptype))

	# 浮动动画
	var tw = main.create_tween().set_loops()
	tw.tween_property(pickup, "position:y", pos.y - 8, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pickup, "position:y", pos.y + 8, 0.5).set_trans(Tween.TRANS_SINE)
	pickup.set_meta("float_tween", tw)

	active_pickup_nodes.append(pickup)

	# 淡出并回收
	var fade_tw = main.create_tween()
	fade_tw.tween_interval(12.0)
	fade_tw.tween_property(pickup, "modulate:a", 0.0, 3.0)
	fade_tw.tween_callback(func():
		if is_instance_valid(pickup):
			_recycle_pickup(pickup)
	)
	pickup.set_meta("fade_tween", fade_tw)

func _on_pickup_collected(body, pickup, ptype):
	if not body.is_in_group("player"):
		return
	if not is_instance_valid(pickup) or not pickup.visible:
		return
	var pdata = PICKUP_TYPES.get(ptype, PICKUP_TYPES["fruit"])
	var heal_amount = int(pdata.get("heal_amount", 0))
	var was_full_health = false
	if ptype == "fruit" and body.get("hp") != null and body.get("max_hp") != null:
		was_full_health = int(body.get("hp")) >= int(body.get("max_hp"))
	if ptype in ["fruit", "crate", "legendary_crate"] and body.has_method("on_consumable_pickup"):
		body.on_consumable_pickup(ptype, was_full_health, pickup.position)
	if heal_amount > 0 and body.get("consumable_heal_bonus") != null:
		heal_amount = max(0, heal_amount + int(body.get("consumable_heal_bonus")))
	if heal_amount > 0:
		if body.has_method("apply_consumable_heal"):
			body.apply_consumable_heal(heal_amount)
		elif body.has_method("heal"):
			body.heal(heal_amount)
	var crate_tier = int(pdata.get("crate_tier", 0))
	if crate_tier > 0:
		var crate_material_bonus = int(body.get("crate_material_bonus")) if body.get("crate_material_bonus") != null else 0
		if crate_material_bonus > 0 and body.has_method("earn_gold"):
			body.earn_gold(crate_material_bonus)
		if main and main.has_method("enqueue_crate_reward"):
			main.enqueue_crate_reward(crate_tier)
	Effects.material_pickup(pickup.position, 1, pdata.color)
	if main and main.hud:
		main.hud.show_notification(pdata.name + "!", pdata.color)
	_recycle_pickup(pickup)

func _get_pickup_callable(pickup):
	if pickup.has_meta("collected_callable"):
		return pickup.get_meta("collected_callable")
	return null

func _get_pooled_pickup():
	if _pool_available.size() > 0:
		return _pool_available.pop_back()
	# 池耗尽，创建新的
	var pickup = Area2D.new()
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	pickup.monitorable = false
	var shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 80.0
	shape.shape = circle_shape
	pickup.add_child(shape)
	var circle = Polygon2D.new()
	var points = PackedVector2Array()
	for j in range(16):
		var angle = j * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	circle.polygon = points
	pickup.add_child(circle)
	main.add_child(pickup)
	_pool_polygon[pickup] = circle
	_pool_shape[pickup] = shape
	return pickup

func _recycle_pickup(pickup):
	if not is_instance_valid(pickup):
		return
	# 杀死关联的 Tween
	if pickup.has_meta("float_tween"):
		var tw = pickup.get_meta("float_tween")
		if tw and tw.is_valid():
			tw.kill()
		pickup.remove_meta("float_tween")
	if pickup.has_meta("fade_tween"):
		var tw = pickup.get_meta("fade_tween")
		if tw and tw.is_valid():
			tw.kill()
		pickup.remove_meta("fade_tween")
	pickup.visible = false
	pickup.modulate = Color(1, 1, 1, 1)
	active_pickup_nodes.erase(pickup)
	_pool_available.append(pickup)

func collect_all_active_for_wave_end(player):
	var pickups = active_pickup_nodes.duplicate()
	for pickup in pickups:
		if is_instance_valid(pickup) and pickup.visible:
			var ptype = pickup.get_meta("pickup_type", "fruit")
			_on_pickup_collected(player, pickup, ptype)

func cleanup():
	for pickup in active_pickup_nodes:
		if is_instance_valid(pickup):
			_recycle_pickup(pickup)
	active_pickup_nodes.clear()
