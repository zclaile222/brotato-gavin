# PlayerCore.gd — 移动、HP管理、无敌帧、被动初始化、等级成长
class_name PlayerCore
extends RefCounted

var p: CharacterBody2D

func init(player: CharacterBody2D):
	p = player

func init_character_passive():
	match p.character_passive:
		"normal":
			pass
		"warrior":
			p.passive_active = false
			p.passive_timer = 0.0
		"hunter":
			pass
		"gunner":
			if p.equipped_weapons.size() >= 2:
				p.fire_rate_multiplier += 0.15
		"berserker":
			pass
		"engineer":
			p.turret_timer = p.turret_cd
		"ninja":
			p.dodge_chance = 0.2
		"wizard":
			pass
		"knight":
			p.damage_cap = max(1, int(p.max_hp * 0.3))
		"archer":
			pass
		"merchant":
			p.gold_per_wave = 5
		"berserker2":
			pass
		"ghost":
			p.ghost_dodge_chance = 0.25
		"necromancer":
			p.necro_summon_chance = 0.1

# ─── 移动 ───

func process_movement(delta):
	var direction = Vector2.ZERO
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): direction.x += 1
	if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A): direction.x -= 1
	if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S): direction.y += 1
	if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W): direction.y -= 1

	var effective_speed = p.speed
	if p.adrenaline and p.max_hp > 0:
		effective_speed = p.speed * (1.0 + (1.0 - float(p.hp) / float(p.max_hp)) * 0.4)
	# 元素状态（减速 / 眩晕）在消费点折算，不写 p.speed ——
	# 因此状态到期不需要回滚，也不会和临时增益的加减速互相污染。
	if p.has_method("status_speed_multiplier"):
		effective_speed *= p.status_speed_multiplier()

	p.velocity = direction.normalized() * effective_speed
	p.move_and_slide()

	# 玩家边界 = **场地**边界，不是屏幕边界。改造前这里用视口尺寸，
	# 于是相机一旦跟随，玩家会被永远锁在出生点那一屏里（走不出去）。
	var arena := Arena.get_active()
	if arena != null:
		p.position = arena.clamp_player_position(p.position)
	else:
		# 无场地（纯逻辑单测 / 特效基准场景）：保留改造前的视口钳位，
		# 而不是「不钳位」—— 后者会让既有的越界断言反向失效。
		var screen = p.get_viewport_rect().size
		p.position.x = clamp(p.position.x, 20, screen.x - 20)
		p.position.y = clamp(p.position.y, 20, screen.y - 20)

# ─── 无敌帧 ───

func process_invincibility(delta):
	if p.invincible_timer > 0:
		p.invincible_timer -= delta
		p.modulate.a = 0.4 if fmod(p.invincible_timer, 0.2) > 0.1 else 1.0
	else:
		p.modulate.a = 1.0

# ─── 被动计时器（战士/工程师/幽灵/狂战士） ───

func process_passive_timers(delta):
	# 战士被动计时器
	if p.passive_active and p.passive_timer > 0:
		p.passive_timer -= delta
		if p.passive_timer <= 0:
			p.passive_active = false

	# 工程师炮塔冷却
	if p.character_passive == "engineer":
		p.turret_timer -= delta
		if p.turret_timer <= 0:
			p.turret_timer = p.turret_cd
			p.request_turret.emit(p.position)

	# 幽灵闪避闪烁恢复
	if p.ghost_flicker_timer > 0:
		p.ghost_flicker_timer -= delta
		p.modulate.a = 0.3
		if p.ghost_flicker_timer <= 0:
			p.modulate.a = 1.0

	# 狂暴者HP阈值加伤计算
	if p.character_passive == "berserker":
		var new_bonus = 0
		if p.max_hp > 0:
			var hp_pct = float(p.hp) / float(p.max_hp)
			if hp_pct <= 0.75:
				new_bonus += 3
			if hp_pct <= 0.50:
				new_bonus += 3
			if hp_pct <= 0.25:
				new_bonus += 3
		p.berserker_hp_bonus = new_bonus

# ─── HP管理 ───

func take_damage(amount, element: String = ""):
	if p.invincible_timer > 0:
		return
	# 忍者闪避
	if p.dodge_chance > 0 and randf() < p.dodge_chance:
		Effects.hit_spark(p.position, Color(0.5, 0.5, 1.0))
		p.total_dodges += 1
		if p.has_method("on_damage_dodged"):
			p.on_damage_dodged()
		return
	# 幽灵完全闪避
	if p.ghost_dodge_chance > 0 and randf() < p.ghost_dodge_chance:
		Effects.hit_spark(p.position, Color(0.6, 0.7, 1.0))
		p.ghost_flicker_timer = 0.3
		p.total_dodges += 1
		if p.has_method("on_damage_dodged"):
			p.on_damage_dodged()
		return
	if p.nullify_hits_remaining > 0:
		p.nullify_hits_remaining -= 1
		Effects.hit_spark(p.position, Color(0.9, 0.9, 0.4))
		return
	var reduced = max(1, amount - p.armor)
	# 骑士单次伤害上限
	if p.damage_cap > 0 and reduced > p.damage_cap:
		reduced = p.damage_cap

	# 护盾优先扣除
	if p.shield > 0:
		if p.shield >= reduced:
			p.shield -= reduced
			reduced = 0
		else:
			reduced -= p.shield
			p.shield = 0
		p.shield_changed.emit(p.shield, p.max_shield)

	p.hp -= reduced
	p.total_damage_taken += reduced
	p.damage_events.append(Time.get_ticks_msec() / 1000.0)
	if reduced > 0 and p.has_method("on_damage_taken"):
		p.on_damage_taken(reduced)
	if reduced > 0 and p.get("combat") != null:
		p.combat.on_player_damaged(reduced)
	p.invincible_timer = p.INVINCIBLE_TIME

	# 元素状态只在**伤害真正落地之后**才施加：
	# 被无敌帧 / 闪避 / 免伤挡下的命中不该附带 debuff。
	# 这个位置也顺带保证了同一轮弹幕里只有第一发能上状态（其余打在无敌帧上）——
	# 这是抑制「雷电 Boss 弹幕把玩家眩晕锁死」的第一道闸，第二道在 PlayerStatus 里。
	if not element.is_empty():
		var status = p.get("status")
		if status != null and status.has_method("apply_element"):
			status.apply_element(element)

	if p.has_node("/root/AudioManager"):
		p.get_node("/root/AudioManager").play_player_hurt()

	# 荆棘反伤
	if p.thorns > 0 and reduced > 0:
		var thorn_dmg = max(1, int(reduced * p.thorns))
		var closest = null
		var closest_dist = INF
		for enemy in p.get_node("DetectArea").get_overlapping_bodies():
			var d = p.position.distance_to(enemy.position)
			if d < closest_dist:
				closest_dist = d
				closest = enemy
		if closest != null:
			closest.take_damage(thorn_dmg)

	# 战士被动：受伤后5秒内伤害+30%
	if p.character_passive == "warrior":
		p.passive_active = true
		p.passive_timer = 5.0

	p.hurt.emit()
	p.hp_changed.emit(p.hp, p.max_hp)
	update_heartbeat()
	if p.hp <= 0:
		# 钢铁意志：30%概率免死（一次性）
		if p.steel_will and randf() < 0.3:
			p.hp = 1
			p.steel_will = false
			p.hp_changed.emit(p.hp, p.max_hp)
			update_heartbeat()
			return
		p.died.emit()
		p.queue_free()

func heal(amount: float, force: bool = false):
	if not force and p.get("torture_healing_sources") != null and int(p.get("torture_healing_sources")) > 0:
		return
	p.hp = min(p.hp + int(ceil(amount)), p.max_hp)
	p.hp_changed.emit(p.hp, p.max_hp)
	update_heartbeat()

# ─── 心跳音效 ───

func update_heartbeat():
	if not p.has_node("/root/AudioManager"):
		return
	var audio = p.get_node("/root/AudioManager")
	if p.max_hp <= 0:
		return
	var ratio = float(p.hp) / float(p.max_hp)
	if ratio <= 0.3 and p.hp > 0:
		var intensity = (0.3 - ratio) / 0.3
		audio.play_heartbeat(lerp(0.3, 1.0, intensity))
	else:
		audio.stop_heartbeat()

# ─── XP与等级 ───

func gain_xp(amount):
	p.xp += int(amount * p.xp_boost)
	while p.xp >= p.xp_to_next:
		p.xp -= p.xp_to_next
		p.level += 1
		p.pending_level_ups += 1
		p.xp_to_next = int(p.xp_to_next * 1.4)
		if p.has_method("on_level_up"):
			p.on_level_up(p.level)
		if p.has_node("/root/AudioManager"):
			p.get_node("/root/AudioManager").play_level_up()
		p.level_up.emit(p.level)
		if not p.get_meta("suppress_level_up_effects", false):
			Effects.level_up_burst(p.position)
	p.xp_changed.emit(p.xp, p.xp_to_next)

# Transitional legacy function. Phase 1 queues post-wave upgrade choices instead of calling this.
func _apply_level_bonus():
	match (p.level - 1) % 5:
		0: p.speed       += 10
		1: p.fire_rate_multiplier += 0.1
		2: heal(1)
		3: p.damage_bonus += 1
		4: p.crit_chance = min(p.crit_chance + 0.03, 0.8)
	# 巫师被动：每次升级额外+2伤害
	if p.character_passive == "wizard":
		p.passive_bonus_damage += 2

# ─── 材料（Phase 1 兼容旧 gold API） ───

func earn_gold(amount):
	var gained = max(0, int(amount))
	if p.economy != null:
		p.economy.gain_materials(gained)
		p.gold = p.economy.materials
	else:
		p.gold += gained
	p.gold_changed.emit(p.gold)

func spend_materials(amount: int) -> bool:
	var cost = max(0, amount)
	if p.economy != null:
		var ok = p.economy.spend_materials(cost)
		p.gold = p.economy.materials
		p.gold_changed.emit(p.gold)
		return ok
	if p.gold < cost:
		return false
	p.gold -= cost
	p.gold_changed.emit(p.gold)
	return true
