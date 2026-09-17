# HUDCombat.gd — 连击系统、Boss血条、伤害闪烁、小地图、敌人箭头
class_name HUDCombat
extends RefCounted

var hud: CanvasLayer

func init(p_hud: CanvasLayer):
	hud = p_hud

# ─── 连击系统 ───

func add_combo_kill():
	hud.combo_count += 1
	hud.combo_timer = 1.5
	if hud.combo_count > hud.max_combo:
		hud.max_combo = hud.combo_count
	if hud.combo_count >= 2:
		hud.combo_label.visible = true
		hud.combo_label.text = str(hud.combo_count) + "x 连击！"
		var ratio = min(float(hud.combo_count) / 10.0, 1.0)
		hud.combo_label.add_theme_color_override("font_color", Color(1.0, 1.0 - ratio * 0.8, 0.0))
		hud.combo_label.scale = Vector2(1.3, 1.3)
		var tw = hud.create_tween()
		tw.tween_property(hud.combo_label, "scale", Vector2(1.0, 1.0), 0.15)
	if hud.combo_count in [5, 10, 15, 20]:
		_flash_combo_gold()
		hud.combo_milestone.emit(hud.combo_count)

func _flash_combo_gold():
	hud.combo_label.add_theme_color_override("font_color", Color(1, 0.85, 0.0))
	hud.combo_label.scale = Vector2(1.6, 1.6)
	var tw = hud.create_tween()
	tw.tween_property(hud.combo_label, "scale", Vector2(1.0, 1.0), 0.2)
	for i in range(3):
		tw.tween_property(hud.combo_label, "modulate", Color(1, 0.85, 0.0, 1), 0.1)
		tw.tween_property(hud.combo_label, "modulate", Color(1, 1, 1, 1), 0.1)

func process_combo(delta):
	if hud.combo_timer > 0:
		hud.combo_timer -= delta
		if hud.combo_timer <= 0:
			hud.combo_count = 0
			hud.combo_label.visible = false

# ─── Boss 血条 ───

func show_boss_bar(hp, max_hp):
	hud.boss_hp_bar.max_value = max_hp
	hud.boss_hp_bar.value = hp
	hud.boss_bar_root.visible = true

func update_boss_bar(hp, max_hp):
	hud.boss_hp_bar.max_value = max_hp
	hud.boss_hp_bar.value = hp

func hide_boss_bar():
	hud.boss_bar_root.visible = false

func update_boss_phase(p_phase: int):
	var fill_style = StyleBoxFlat.new()
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	match p_phase:
		0:
			fill_style.bg_color = Color(0.2, 0.9, 0.2)
		1:
			fill_style.bg_color = Color(1.0, 0.6, 0.1)
		2:
			fill_style.bg_color = Color(1.0, 0.15, 0.1)
	hud.boss_hp_bar.add_theme_stylebox_override("fill", fill_style)

# ─── 伤害闪烁 ───

func flash_damage():
	hud.damage_flash.color = Color(1, 0, 0, 0.35)
	hud.damage_flash.visible = true
	var tw = hud.create_tween()
	tw.tween_property(hud.damage_flash, "color", Color(1, 0, 0, 0), 0.35)
	tw.tween_callback(hud.damage_flash.hide)

# ─── 低血量暗角 ───

func update_danger_vignette(hp: int, max_hp_val: int):
	if hud.danger_vignette == null or max_hp_val <= 0:
		return
	var ratio = float(hp) / float(max_hp_val)
	if ratio <= 0.3 and hp > 0:
		hud.danger_vignette.visible = true
		var danger_intensity = (0.3 - ratio) / 0.3
		var alpha = lerp(0.1, 0.5, danger_intensity)
		hud.danger_vignette.color = Color(0.8, 0.0, 0.0, alpha)
		hud.danger_pulse_time = 0.0
	else:
		hud.danger_vignette.visible = false
		hud.danger_vignette.color.a = 0.0

func process_danger_vignette(delta):
	if hud.danger_vignette and hud.danger_vignette.visible:
		hud.danger_pulse_time += delta
		var base_alpha = hud.danger_vignette.color.a
		if base_alpha > 0.25:
			var pulse = (sin(hud.danger_pulse_time * TAU * 1.5) + 1.0) * 0.5
			hud.danger_vignette.color.a = lerp(base_alpha * 0.6, base_alpha, pulse)

# ─── 屏幕边缘敌人方向箭头 ───

func update_enemy_arrows():
	var enemies = hud.get_tree().get_nodes_in_group("enemies")
	var screen = hud.get_viewport().get_visible_rect().size
	var player_pos = Vector2(screen.x / 2.0, screen.y / 2.0)
	var players = hud.get_tree().get_nodes_in_group("player")
	if not players.is_empty() and is_instance_valid(players[0]):
		player_pos = players[0].position

	for arrow in hud.arrow_pool:
		arrow.visible = false

	var arrow_idx = 0
	for enemy in enemies:
		if arrow_idx >= hud.arrow_pool.size():
			break
		if not is_instance_valid(enemy):
			continue
		var epos = enemy.position
		if epos.x >= -20 and epos.x <= screen.x + 20 and epos.y >= -20 and epos.y <= screen.y + 20:
			continue

		var dir = (epos - player_pos).normalized()
		var angle = dir.angle()
		var arrow_pos = _clamp_to_screen_edge(player_pos, dir, screen, hud.arrow_margin)

		var arrow = hud.arrow_pool[arrow_idx]
		arrow.position = arrow_pos
		arrow.rotation = angle
		var etype = enemy.get("enemy_type") if enemy.get("enemy_type") else "normal"
		if etype in ["boss", "miniboss"]:
			arrow.scale = Vector2(1.8, 1.8)
			arrow.color = Color(1.0, 0.8, 0.0, 0.9)
		else:
			arrow.scale = Vector2(1.0, 1.0)
			arrow.color = Color(1, 0.2, 0.2, 0.85)
		arrow.visible = true
		arrow_idx += 1

func _clamp_to_screen_edge(origin: Vector2, dir: Vector2, screen: Vector2, margin: float) -> Vector2:
	var t_vals = []
	if dir.x > 0.001:  t_vals.append((screen.x - margin - origin.x) / dir.x)
	if dir.x < -0.001: t_vals.append((margin - origin.x) / dir.x)
	if dir.y > 0.001:  t_vals.append((screen.y - margin - origin.y) / dir.y)
	if dir.y < -0.001: t_vals.append((margin - origin.y) / dir.y)
	if t_vals.is_empty():
		return origin
	var t_min = INF
	for tv in t_vals:
		if tv > 0:
			t_min = min(t_min, tv)
	if t_min == INF:
		return origin
	var result = origin + dir * t_min
	result.x = clamp(result.x, margin, screen.x - margin)
	result.y = clamp(result.y, margin, screen.y - margin)
	return result

# ─── 小地图 ───

func update_minimap(player_pos: Vector2, enemies: Array, pickups: Array):
	if hud.minimap_canvas == null:
		return
	for child in hud.minimap_canvas.get_children():
		child.queue_free()

	var half = hud.MINIMAP_SIZE / 2.0
	var map_center = Vector2(half, half)

	hud._add_minimap_dot(map_center, Color.WHITE, 4.0)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var offset = (enemy.position - player_pos) / hud.MINIMAP_RANGE * half
		var dot_pos = map_center + offset
		if dot_pos.distance_to(map_center) > half - 2:
			dot_pos = map_center + (dot_pos - map_center).normalized() * (half - 2)
		var etype = enemy.get("enemy_type") if enemy.get("enemy_type") else "normal"
		if etype in ["boss", "miniboss"]:
			var alpha = 0.6 + sin(Time.get_ticks_msec() * 0.008) * 0.4
			hud._add_minimap_dot(dot_pos, Color(1, 0.2, 0.1, alpha), 6.0)
		else:
			hud._add_minimap_dot(dot_pos, Color(1, 0.2, 0.2, 0.85), 3.0)

	for pickup in pickups:
		if not is_instance_valid(pickup):
			continue
		var offset = (pickup.position - player_pos) / hud.MINIMAP_RANGE * half
		var dot_pos = map_center + offset
		if dot_pos.distance_to(map_center) > half - 2:
			dot_pos = map_center + (dot_pos - map_center).normalized() * (half - 2)
		var ptype = pickup.get_meta("pickup_type") if pickup.has_meta("pickup_type") else ""
		var dot_color = HUDCore.BUFF_COLORS.get(ptype, Color(0.5, 1, 0.5))
		hud._add_minimap_dot(dot_pos, dot_color, 2.0)
