# Collision System Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all manual `distance_to` collision checks with Godot's Area2D signal-driven collision system for better performance.

**Architecture:** Add Area2D child nodes to Player and Enemy scenes for detection zones. Convert Bullet's `_process` enemy iteration to `body_entered` signal. Convert pickup/turret/undead runtime nodes to use Area2D collision. Collision layers are already partially configured in .tscn files but unused by code.

**Tech Stack:** Godot 4.x, GDScript, Area2D/CollisionShape2D

---

### Task 1: Bullet.gd — Signal-driven enemy hit detection

**Files:**
- Modify: `scripts/Bullet.gd`

The Bullet scene (Bullet.tscn) already has: Area2D root with collision_layer=4, collision_mask=2, and CircleShape2D radius=6. The Enemy scene has CharacterBody2D with collision_layer=2. So Bullet can already detect Enemy bodies via `body_entered` — the code just doesn't use it.

- [ ] **Step 1: Add signal connection and pool monitoring toggle**

In `_ready()`, connect `body_entered` signal. In `activate()` and `_return_to_pool()`, toggle `monitoring`:

```gdscript
# In _ready(), after existing code:
func _ready():
	add_to_group("bullets")
	visible = false
	set_process(false)
	monitoring = false
	body_entered.connect(_on_body_entered)

# In activate(), add at end after "set_process(true)":
	set_deferred("monitoring", true)

# In _return_to_pool(), add at start:
	set_deferred("monitoring", false)
```

- [ ] **Step 2: Create `_on_body_entered` handler with all hit logic**

Move the hit logic from `_process` into a signal callback. This function handles: damage, lifesteal, status effects, elemental ammo, splash, chain lightning, and pierce.

```gdscript
func _on_body_entered(body):
	if not visible:
		return
	if not body.is_in_group("enemies"):
		return
	if body in hit_enemies:
		return

	hit_enemies.append(body)
	Effects.hit_spark(position, bullet_color)
	body.take_damage(damage)
	if shooter and is_instance_valid(shooter):
		shooter.total_damage_dealt += damage
		if shooter.lifesteal > 0:
			shooter.heal(damage * shooter.lifesteal)
	# 触发状态效果
	if shooter and is_instance_valid(shooter) and is_instance_valid(body):
		if shooter.get("burn_chance") and randf() < shooter.burn_chance:
			if body.has_method("apply_burn"):
				body.apply_burn()
		if shooter.get("freeze_chance") and randf() < shooter.freeze_chance:
			if body.has_method("apply_freeze"):
				body.apply_freeze()
	# 元素弹药效果
	if ammo_type != "" and is_instance_valid(body):
		if ammo_type == "fire" and body.has_method("apply_burn"):
			body.apply_burn()
		elif ammo_type == "ice" and body.has_method("apply_slow"):
			body.apply_slow(0.3, 2.0)
		elif ammo_type == "lightning" and randf() < 0.2:
			if body.has_method("apply_stun"):
				body.apply_stun(1.0)
	# 溅射：对范围内其他敌人造成50%伤害
	if splash and splash_radius > 0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != body and is_instance_valid(e) and position.distance_to(e.position) <= splash_radius:
				e.take_damage(max(1, int(damage * 0.5)))
				Effects.hit_spark(e.position, bullet_color)
	# 链式闪电：命中后跳跃至附近敌人造成50%伤害
	var has_chain = chain_lightning or (shooter and is_instance_valid(shooter) and shooter.get("chain_lightning"))
	if has_chain:
		var chain_dmg = max(1, int(damage * 0.5))
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != body and is_instance_valid(e) and position.distance_to(e.position) <= 200.0:
				e.take_damage(chain_dmg)
				Effects.hit_spark(e.position, Color(0.3, 0.6, 1.0))
				if shooter and is_instance_valid(shooter):
					shooter.total_damage_dealt += chain_dmg
				break
	# 穿透：命中后不消失，最多穿透3个
	if pierce:
		pierce_count += 1
		if pierce_count >= 3:
			_return_to_pool()
	else:
		_return_to_pool()
```

- [ ] **Step 3: Remove manual enemy iteration from `_process`**

Delete lines 111-166 (the entire `# 手动距离检测` block) from `_process()`. The `_process` function should end after the screen bounds check at line 109.

The final `_process` should be:

```gdscript
func _process(delta):
	_lifetime += delta
	if _lifetime >= 3.0:
		_return_to_pool()
		return

	# 回旋镖逻辑
	if returns:
		if not returning:
			return_timer -= delta
			if return_timer <= 0:
				returning = true
		if returning and shooter and is_instance_valid(shooter):
			var to_player = (shooter.position - position).normalized()
			direction = direction.lerp(to_player, 8.0 * delta).normalized()
			if position.distance_to(shooter.position) < 30:
				_return_to_pool()
				return

	# 重力弹道
	if gravity_fall:
		gravity_vel += 400.0 * delta
		position.y += gravity_vel * delta

	position += direction * bullet_speed * delta
	var screen = get_viewport_rect().size
	if position.x < -50 or position.x > screen.x + 50 or position.y < -50 or position.y > screen.y + 50:
		_return_to_pool()
		return
```

Note: `position.distance_to(shooter.position) < 30` for boomerang return is kept — it's a single-target check with negligible cost.

- [ ] **Step 4: Verify in Godot editor**

Open the project in Godot, run a game, verify:
- Bullets hit enemies and deal damage
- Splash damage works on nearby enemies
- Chain lightning jumps to a nearby enemy
- Piercing bullets pass through up to 3 enemies
- Boomerang weapons return correctly
- Elemental ammo applies status effects
- Pool recycling works (bullets deactivate and reactivate properly)

---

### Task 2: Enemy.tscn — Add ContactArea and SeparationArea

**Files:**
- Modify: `scenes/Enemy.tscn`

Add two Area2D child nodes to the Enemy scene for contact damage detection and separation force.

- [ ] **Step 1: Add ContactArea and SeparationArea to Enemy.tscn**

Replace the entire file content:

```tscn
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/Enemy.gd" id="1"]

[sub_resource type="CircleShape2D" id="1"]
radius = 18.0

[sub_resource type="CircleShape2D" id="2"]
radius = 35.0

[sub_resource type="CircleShape2D" id="3"]
radius = 50.0

[node name="Enemy" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 1
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)
color = Color(0.9, 0.2, 0.2, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("1")

[node name="ContactArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 1
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="ContactArea"]
shape = SubResource("2")

[node name="SeparationArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="SeparationArea"]
shape = SubResource("3")
```

Key details:
- `ContactArea`: collision_mask=1 (detects Player body on layer 1), radius 35 matches current `35.0 * scale.x` at scale 1.0. Auto-scales with parent Enemy node.
- `SeparationArea`: collision_mask=2 (detects other Enemy bodies on layer 2), radius 50 matches max separation check range.
- Both set `monitorable = false` since nothing needs to detect them — they only detect others.

---

### Task 3: Enemy.gd — Use ContactArea for contact damage

**Files:**
- Modify: `scripts/Enemy.gd`

Replace all manual `dist < 35.0 * scale.x` and `dist < 55.0` contact damage checks with signal-driven overlap detection.

- [ ] **Step 1: Add contact tracking variable and signal connection**

Add a variable to track whether player is in contact range, and connect signals in `_ready()`:

```gdscript
# Add after existing vars (after "var healer_timer = 0.0" line):
var _player_in_contact = false  # ContactArea overlap tracking

# In _ready(), add at end:
func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	$ContactArea.body_entered.connect(_on_contact_entered)
	$ContactArea.body_exited.connect(_on_contact_exited)
```

- [ ] **Step 2: Add contact signal callbacks**

```gdscript
func _on_contact_entered(body):
	if body.is_in_group("player"):
		_player_in_contact = true

func _on_contact_exited(body):
	if body.is_in_group("player"):
		_player_in_contact = false
```

- [ ] **Step 3: Replace contact damage checks in `_physics_process`**

In the boss/miniboss block (currently around line 240-251), replace:

```gdscript
		# 接触伤害：距离检测 + 碰撞检测双重保险
		contact_timer -= delta
		if contact_timer <= 0:
			var touched = dist < 55.0
			if not touched:
				for i in get_slide_collision_count():
					if get_slide_collision(i).get_collider() == player:
						touched = true
						break
			if touched:
				player.take_damage(contact_damage)
				contact_timer = 1.0
```

With:

```gdscript
		# 接触伤害：Area2D信号驱动
		contact_timer -= delta
		if contact_timer <= 0 and _player_in_contact:
			player.take_damage(contact_damage)
			contact_timer = 1.0
```

Do the same replacement in the charger block (currently around line 292-302) and the default block (currently around line 310-320). All three contact damage blocks use the same replacement pattern.

- [ ] **Step 4: Remove `dist` variable usage for movement decisions**

The `dist` variable at line 180 (`var dist = position.distance_to(player.position)`) is still needed for ranged enemy AI (line 208 `dist < preferred_dist - 40`), boss shooting logic, and charger rush direction. Keep it, but it is no longer used for contact damage.

- [ ] **Step 5: Verify in Godot editor**

Run a game and verify:
- Normal enemies deal contact damage on touch
- Boss/miniboss deal contact damage on touch
- Charger deals contact damage during rush
- Contact damage cooldown (1 second) still works
- Different enemy scales still trigger correctly (large bosses with scale 2.4)

---

### Task 4: Enemy.gd — Use SeparationArea for separation force

**Files:**
- Modify: `scripts/Enemy.gd`

Replace the O(n) full enemy iteration in `_get_separation_force()` with Area2D overlap query.

- [ ] **Step 1: Replace `_get_separation_force` implementation**

Replace the existing function:

```gdscript
func _get_separation_force() -> Vector2:
	var sep = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		var dist = position.distance_to(other.position)
		var min_dist = 30.0 * (scale.x + other.scale.x) * 0.5
		if dist < min_dist and dist > 0.1:
			sep += (position - other.position).normalized() * (min_dist - dist) / min_dist
	return sep * 60.0
```

With:

```gdscript
func _get_separation_force() -> Vector2:
	var sep = Vector2.ZERO
	for other in $SeparationArea.get_overlapping_bodies():
		if other == self:
			continue
		var dist = position.distance_to(other.position)
		var min_dist = 30.0 * (scale.x + other.scale.x) * 0.5
		if dist < min_dist and dist > 0.1:
			sep += (position - other.position).normalized() * (min_dist - dist) / min_dist
	return sep * 60.0
```

The only change: `get_tree().get_nodes_in_group("enemies")` → `$SeparationArea.get_overlapping_bodies()`. The distance calculation is still needed for force direction/magnitude, but the iteration is now limited to nearby enemies only.

- [ ] **Step 2: Replace `_heal_nearby_enemies` implementation**

Replace:

```gdscript
func _heal_nearby_enemies():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not is_instance_valid(enemy):
			continue
		if position.distance_to(enemy.position) <= 50.0:
			var heal_amount = max(1, int(enemy.max_hp * 0.1))
			enemy.hp = min(enemy.hp + heal_amount, enemy.max_hp)
```

With:

```gdscript
func _heal_nearby_enemies():
	for enemy in $SeparationArea.get_overlapping_bodies():
		if enemy == self:
			continue
		var heal_amount = max(1, int(enemy.max_hp * 0.1))
		enemy.hp = min(enemy.hp + heal_amount, enemy.max_hp)
```

The SeparationArea has radius 50, which matches the heal range exactly. No distance check needed.

- [ ] **Step 3: Verify in Godot editor**

Run a game and verify:
- Enemies don't stack on top of each other (separation force works)
- Healer enemies heal nearby allies (spawn healer wave or wait for one)
- Performance feels the same or better with many enemies on screen

---

### Task 5: Player.tscn + Player.gd — Add DetectArea for melee/targeting

**Files:**
- Modify: `scenes/Player.tscn`
- Modify: `scripts/Player.gd`

Add a DetectArea to Player for melee weapon hits, nearest enemy targeting, and thorns.

- [ ] **Step 1: Add DetectArea to Player.tscn**

Replace the file:

```tscn
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/Player.gd" id="1"]

[sub_resource type="CircleShape2D" id="1"]
radius = 20.0

[sub_resource type="CircleShape2D" id="2"]
radius = 160.0

[node name="Player" type="CharacterBody2D"]
collision_layer = 1
collision_mask = 0
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
polygon = PackedVector2Array(-18, -18, 18, -18, 18, 18, -18, 18)
color = Color(0.2, 0.85, 0.3, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("1")

[node name="DetectArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2
monitorable = false

[node name="CollisionShape2D" type="CollisionShape2D" parent="DetectArea"]
shape = SubResource("2")
```

Key details:
- Player CharacterBody2D now has `collision_layer = 1` (so enemies/bullets can detect it)
- `DetectArea`: collision_mask=2 (detects Enemy bodies on layer 2), radius 160 covers magnet range and most weapon ranges
- `monitorable = false` — nothing needs to detect this area

- [ ] **Step 2: Replace `_fire_weapon` nearest enemy search**

In `_fire_weapon()`, replace the manual iteration (around line 357-368):

```gdscript
func _fire_weapon(weapon):
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var nearest = null
	var nearest_dist = INF
	for enemy in enemies:
		var d = position.distance_to(enemy.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest == null:
		return
```

With:

```gdscript
func _fire_weapon(weapon):
	var nearby = $DetectArea.get_overlapping_bodies()
	if nearby.is_empty():
		return
	var nearest = null
	var nearest_dist = INF
	for enemy in nearby:
		var d = position.distance_to(enemy.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest == null:
		return
```

- [ ] **Step 3: Replace melee weapon enemy iteration**

In the melee section of `_fire_weapon()` (around line 385-395), replace:

```gdscript
		for enemy in enemies:
			if position.distance_to(enemy.position) <= melee_r:
```

With:

```gdscript
		for enemy in nearby:
			if position.distance_to(enemy.position) <= melee_r:
```

This works because `nearby` is already defined at the top of the function from step 2.

- [ ] **Step 4: Replace thorns nearest enemy search**

In `take_damage()` (around line 501-513), replace:

```gdscript
	if thorns > 0 and reduced > 0:
		var thorn_dmg = max(1, int(reduced * thorns))
		var enemies = get_tree().get_nodes_in_group("enemies")
		var closest = null
		var closest_dist = INF
		for enemy in enemies:
			if is_instance_valid(enemy):
				var d = position.distance_to(enemy.position)
				if d < closest_dist:
					closest_dist = d
					closest = enemy
		if closest != null:
			closest.take_damage(thorn_dmg)
```

With:

```gdscript
	if thorns > 0 and reduced > 0:
		var thorn_dmg = max(1, int(reduced * thorns))
		var closest = null
		var closest_dist = INF
		for enemy in $DetectArea.get_overlapping_bodies():
			var d = position.distance_to(enemy.position)
			if d < closest_dist:
				closest_dist = d
				closest = enemy
		if closest != null:
			closest.take_damage(thorn_dmg)
```

- [ ] **Step 5: Verify in Godot editor**

Run a game and verify:
- Auto-aim targets nearest enemy correctly
- Melee weapons hit enemies in range
- Ranged weapons fire at nearby enemies
- Thorns reflects damage to nearby enemy when hit
- Weapons with range limit (flamethrower) still respect their range

---

### Task 6: Main.gd — Convert pickups to Area2D with signal

**Files:**
- Modify: `scripts/Main.gd`

Convert pickup nodes from plain Node2D to Area2D for signal-driven collection, and remove the manual distance loop from `_process`.

- [ ] **Step 1: Modify `_spawn_pickup` to create Area2D with collision**

Replace the `_spawn_pickup` function:

```gdscript
func _spawn_pickup(pos: Vector2, ptype: String):
	var data = PICKUP_TYPES[ptype]
	var pickup = Node2D.new()
	pickup.position = pos
	pickup.set_meta("pickup_type", ptype)

	# 圆形外观
	var circle = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	circle.polygon = points
	circle.color = data.color
	pickup.add_child(circle)

	# 上下浮动动画
	var tw = create_tween().set_loops()
	tw.tween_property(pickup, "position:y", pos.y - 8, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pickup, "position:y", pos.y + 8, 0.5).set_trans(Tween.TRANS_SINE)

	add_child(pickup)
	active_pickup_nodes.append(pickup)

	# 15秒后自动消失
	var fade_tw = create_tween()
	fade_tw.tween_interval(12.0)
	fade_tw.tween_property(pickup, "modulate:a", 0.0, 3.0)
	fade_tw.tween_callback(func():
		if is_instance_valid(pickup):
			active_pickup_nodes.erase(pickup)
			pickup.queue_free()
	)
```

With:

```gdscript
func _spawn_pickup(pos: Vector2, ptype: String):
	var data = PICKUP_TYPES[ptype]
	var pickup = Area2D.new()
	pickup.position = pos
	pickup.set_meta("pickup_type", ptype)
	pickup.collision_layer = 0
	pickup.collision_mask = 1  # detect player body
	pickup.monitorable = false

	# 碰撞形状：半径80（拾取范围）
	var shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 80.0
	shape.shape = circle_shape
	pickup.add_child(shape)

	# 圆形外观
	var circle = Polygon2D.new()
	var points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	circle.polygon = points
	circle.color = data.color
	pickup.add_child(circle)

	pickup.body_entered.connect(_on_pickup_collected.bind(pickup, ptype))

	# 上下浮动动画
	var tw = create_tween().set_loops()
	tw.tween_property(pickup, "position:y", pos.y - 8, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pickup, "position:y", pos.y + 8, 0.5).set_trans(Tween.TRANS_SINE)

	add_child(pickup)
	active_pickup_nodes.append(pickup)

	# 15秒后自动消失
	var fade_tw = create_tween()
	fade_tw.tween_interval(12.0)
	fade_tw.tween_property(pickup, "modulate:a", 0.0, 3.0)
	fade_tw.tween_callback(func():
		if is_instance_valid(pickup):
			active_pickup_nodes.erase(pickup)
			pickup.queue_free()
	)
```

- [ ] **Step 2: Add pickup collection callback**

Add this new function:

```gdscript
func _on_pickup_collected(body, pickup, ptype):
	if not body.is_in_group("player"):
		return
	if not is_instance_valid(pickup):
		return
	var pdata = PICKUP_TYPES[ptype]
	body.apply_temp_buff(ptype, pdata.duration)
	Effects.hit_spark(pickup.position, pdata.color)
	hud.show_notification(pdata.name + "!", pdata.color)
	active_pickup_nodes.erase(pickup)
	pickup.queue_free()
```

- [ ] **Step 3: Remove manual pickup distance loop from `_process`**

In `_process()`, delete the pickup detection block (around line 287-300):

```gdscript
		# 拾取物检测：玩家80px内自动拾取
		if player and is_instance_valid(player):
			for i in range(active_pickup_nodes.size() - 1, -1, -1):
				var pickup = active_pickup_nodes[i]
				if not is_instance_valid(pickup):
					active_pickup_nodes.remove_at(i)
					continue
				if player.position.distance_to(pickup.position) < 80.0:
					var ptype = pickup.get_meta("pickup_type")
					var pdata = PICKUP_TYPES[ptype]
					player.apply_temp_buff(ptype, pdata.duration)
					Effects.hit_spark(pickup.position, pdata.color)
					hud.show_notification(pdata.name + "!", pdata.color)
					pickup.queue_free()
					active_pickup_nodes.remove_at(i)
```

- [ ] **Step 4: Verify in Godot editor**

Run a game, kill enemies that drop pickups, and verify:
- Walking near a pickup (within 80px) auto-collects it
- Buff notification appears
- Pickup is removed from scene
- Fade-out timer still works for uncollected pickups

---

### Task 7: Main.gd — Convert turrets to use Area2D targeting

**Files:**
- Modify: `scripts/Main.gd`

Add Area2D to turret nodes for enemy detection within range.

- [ ] **Step 1: Add Area2D to turret in `_on_request_turret`**

In `_on_request_turret()`, add a detection area to the turret. After the existing turret setup code (the `add_child(barrel)` line, before `add_child(turret)`), add:

```gdscript
	# 射程检测区域
	var detect = Area2D.new()
	detect.name = "DetectArea"
	detect.collision_layer = 0
	detect.collision_mask = 2  # detect enemies
	detect.monitorable = false
	var det_shape = CollisionShape2D.new()
	var det_circle = CircleShape2D.new()
	det_circle.radius = 300.0  # turret range
	det_shape.shape = det_circle
	detect.add_child(det_shape)
	turret.add_child(detect)
```

- [ ] **Step 2: Replace turret targeting in `_process_turrets`**

In `_process_turrets()`, replace the enemy search block:

```gdscript
			# 寻找最近敌人并射击
			var enemies = get_tree().get_nodes_in_group("enemies")
			var nearest = null
			var nearest_dist = 300.0  # 炮塔射程
			for enemy in enemies:
				if is_instance_valid(enemy):
					var d = turret.position.distance_to(enemy.position)
					if d < nearest_dist:
						nearest_dist = d
						nearest = enemy
```

With:

```gdscript
			# 寻找最近敌人并射击
			var nearest = null
			var nearest_dist = 300.0
			for enemy in turret.get_node("DetectArea").get_overlapping_bodies():
				var d = turret.position.distance_to(enemy.position)
				if d < nearest_dist:
					nearest_dist = d
					nearest = enemy
```

- [ ] **Step 3: Verify in Godot editor**

Play as Engineer character, verify:
- Turret deploys and shoots nearby enemies
- Turret ignores enemies beyond 300px range
- Turret barrel rotates toward target

---

### Task 8: Main.gd — Convert undeads to use Area2D targeting

**Files:**
- Modify: `scripts/Main.gd`

Add Area2D to undead nodes for enemy detection.

- [ ] **Step 1: Add Area2D to undead in `_on_request_undead`**

In `_on_request_undead()`, after the body Polygon2D is added (after `undead.add_child(body)`) and before `add_child(undead)`, add:

```gdscript
	# 敌人检测区域
	var detect = Area2D.new()
	detect.name = "DetectArea"
	detect.collision_layer = 0
	detect.collision_mask = 2  # detect enemies
	detect.monitorable = false
	var det_shape = CollisionShape2D.new()
	var det_circle = CircleShape2D.new()
	det_circle.radius = 200.0  # detection range
	det_shape.shape = det_circle
	detect.add_child(det_shape)
	undead.add_child(detect)
```

- [ ] **Step 2: Replace undead targeting in `_process_undeads`**

In `_process_undeads()`, replace the enemy search block:

```gdscript
		# 寻找最近敌人并移动/攻击
		var enemies = get_tree().get_nodes_in_group("enemies")
		var nearest = null
		var nearest_dist = INF
		for enemy in enemies:
			if is_instance_valid(enemy):
				var d = undead.position.distance_to(enemy.position)
				if d < nearest_dist:
					nearest_dist = d
					nearest = enemy
```

With:

```gdscript
		# 寻找最近敌人并移动/攻击
		var nearest = null
		var nearest_dist = INF
		for enemy in undead.get_node("DetectArea").get_overlapping_bodies():
			var d = undead.position.distance_to(enemy.position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy
```

- [ ] **Step 3: Verify in Godot editor**

Play as Necromancer character, kill enemies to spawn undeads, and verify:
- Undeads chase and attack nearby enemies
- Undeads stop chasing when enemies are out of 200px range
- Attack damage is dealt at close range (30px)

---

### Task 9: Cleanup and final verification

**Files:**
- Modify: `scripts/Main.gd` (minor cleanup)

- [ ] **Step 1: Verify no remaining manual distance checks**

Search all `.gd` files for `distance_to` and confirm each remaining usage is intentional:

Expected remaining uses (all acceptable):
- `Bullet.gd`: boomerang return to player (`position.distance_to(shooter.position) < 30`) — single target
- `Bullet.gd`: splash and chain lightning — event-driven, not per-frame
- `Player.gd`: melee range check and nearest enemy in `_fire_weapon` — now iterates `$DetectArea.get_overlapping_bodies()` instead of all enemies
- `Player.gd`: thorns — now iterates `$DetectArea.get_overlapping_bodies()`
- `Enemy.gd`: separation force — now iterates `$SeparationArea.get_overlapping_bodies()`
- `Enemy.gd`: `dist` for ranged AI distance keeping — single target (player)
- `XPOrb.gd`: magnet pull distance — single target (player), plus already has `body_entered` for collection
- `HUD.gd`: minimap dot clamping — UI only, not gameplay collision
- `Main.gd`: turret/undead nearest from overlapping — small set from Area2D

- [ ] **Step 2: Full playtest**

Run a complete game session verifying:
- All weapon types work (melee, ranged, splash, pierce, boomerang, gravity, chain lightning)
- All enemy types work (normal, fast, tank, ranged, boss, exploder, healer, swarm, ghost, charger, summoner, elite, miniboss, shooter_spread, armored)
- Pickups drop and auto-collect
- XP orbs attract and collect
- Engineer turrets target and fire
- Necromancer undeads chase and attack
- Enemy separation prevents stacking
- Contact damage works for all melee enemy types
- Boss phase transitions work
- No errors in Godot output console

- [ ] **Step 3: Update DEV_REPORT.md technical debt section**

In `DEV_REPORT.md`, update the technical debt table. Replace the row:

```
| 碰撞使用手动 `distance_to` 而非碰撞层 | 中（大量敌人时性能下降） | 迁移至 Area2D 碰撞信号 |
```

With:

```
| ~~碰撞使用手动 `distance_to` 而非碰撞层~~ | ~~已修复~~ | 已迁移至 Area2D 碰撞信号 |
```
