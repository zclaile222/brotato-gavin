# PlayerBuffs.gd — 临时增益、元素弹药、on_kill、波次回调
class_name PlayerBuffs
extends RefCounted

var p: CharacterBody2D

func init(player: CharacterBody2D):
	p = player

# ─── 临时增益拾取物 ───

func apply_temp_buff(buff_type: String, duration: float):
	if p.active_pickups.has(buff_type):
		_remove_temp_buff(buff_type)
	var original = {}
	match buff_type:
		"speed_boost":
			original["speed"] = p.speed
			p.speed += 100
		"damage_boost":
			original["damage_bonus"] = p.damage_bonus
			p.damage_bonus += 8
		"rapid_fire":
			original["fire_rate_multiplier"] = p.fire_rate_multiplier
			p.fire_rate_multiplier *= 1.8
		"shield":
			p.shield += 2
			p.max_shield = max(p.max_shield, p.shield)
			p.shield_changed.emit(p.shield, p.max_shield)
			p.buff_changed.emit(p.active_pickups)
			return
		"vampire_fang":
			original["lifesteal"] = p.lifesteal
			p.lifesteal += 0.2
			if p.has_method("recalculate_lifesteal_scaling_damage"):
				p.recalculate_lifesteal_scaling_damage()
	p.active_pickups[buff_type] = {"timer": duration, "original": original}
	p.buff_changed.emit(p.active_pickups)

func _remove_temp_buff(buff_type: String):
	if not p.active_pickups.has(buff_type):
		return
	var original = p.active_pickups[buff_type].original
	match buff_type:
		"speed_boost":
			p.speed = original.get("speed", p.speed)
		"damage_boost":
			p.damage_bonus = original.get("damage_bonus", p.damage_bonus)
		"rapid_fire":
			p.fire_rate_multiplier = original.get("fire_rate_multiplier", p.fire_rate_multiplier)
		"vampire_fang":
			p.lifesteal = original.get("lifesteal", p.lifesteal)
			if p.has_method("recalculate_lifesteal_scaling_damage"):
				p.recalculate_lifesteal_scaling_damage()
	p.active_pickups.erase(buff_type)

func process_buff_timers(delta):
	if not p.active_pickups.is_empty():
		var expired = []
		for buff_type in p.active_pickups:
			p.active_pickups[buff_type].timer -= delta
			if p.active_pickups[buff_type].timer <= 0:
				expired.append(buff_type)
		for buff_type in expired:
			_remove_temp_buff(buff_type)
		if not expired.is_empty():
			p.buff_changed.emit(p.active_pickups)

# ─── 击杀回调 ───

func on_kill():
	if p.war_machine_enabled:
		if p.war_machine_stacks < 20:
			p.war_machine_stacks += 1
			p.fire_rate_multiplier += 0.03
	# 工程师被动：击杀15%概率掉落额外材料
	if p.character_passive == "engineer" and randf() < 0.15:
		p.core.earn_gold(1)
	# 暴徒被动：击杀10%概率回1HP
	if p.character_passive == "berserker2" and randf() < 0.1:
		p.core.heal(1)
	# 死灵法师被动：击杀10%概率召唤亡灵
	if p.character_passive == "necromancer" and p.necro_summon_chance > 0 and randf() < p.necro_summon_chance:
		p.request_undead.emit(p.position)

# ─── 波次回调 ───

func wave_regen():
	if p.hp_regen > 0:
		var amount = p.hp_regen
		if int(p.get("low_health_regen_double_sources")) > 0 and p.hp < float(p.max_hp) * 0.5:
			amount *= 2
		p.core.heal(amount)
	# 猎手被动：每波开始速度+20%持续本波
	if p.character_passive == "hunter":
		p.speed = p.base_speed * 1.2

func on_wave_start():
	# 商人被动：每波开始获得额外材料
	if p.gold_per_wave > 0:
		p.core.earn_gold(p.gold_per_wave)
	# 骑士被动：更新伤害上限
	if p.character_passive == "knight":
		p.damage_cap = max(1, int(p.max_hp * 0.3))
