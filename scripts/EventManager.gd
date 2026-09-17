# EventManager.gd — 特殊事件系统
class_name EventManager
extends Node

const SPECIAL_EVENTS = [
	{
		"id": "healing_fountain",
		"name": "治愈之泉",
		"desc": "消耗 15 材料，恢复全部生命值。",
		"color": Color(0.2, 1, 0.4),
		"cost": 15
	},
	{
		"id": "treasure_chest",
		"name": "宝箱",
		"desc": "本波击杀 10 个敌人后获得 30 材料奖励！",
		"color": Color(1, 0.85, 0.2),
		"kill_target": 10,
		"reward_gold": 30
	},
	{
		"id": "ambush",
		"name": "伏击！",
		"desc": "本波敌人数量翻倍，但击杀材料 +3。",
		"color": Color(1, 0.3, 0.3)
	},
	{
		"id": "blessing",
		"name": "祝福",
		"desc": "本波伤害 +30%，速度 +20%。",
		"color": Color(0.6, 0.8, 1)
	},
	{
		"id": "curse",
		"name": "诅咒",
		"desc": "本波敌人生命值 +50%，但经验获得 x2。",
		"color": Color(0.7, 0.2, 0.8)
	},
]

var current_event = null
var event_active = false
var event_kill_count = 0
var event_treasure_rewarded = false

var main: Node2D

func setup(p_main: Node2D):
	main = p_main

func try_trigger_event():
	if main.wave % 5 != 0 or main.wave_manager.is_boss_wave() or randf() > 0.4:
		return
	var evt = SPECIAL_EVENTS[randi() % SPECIAL_EVENTS.size()]
	current_event = evt
	main.hud.show_event_panel(evt.name, evt.desc, evt.color)

func on_event_accepted():
	if current_event == null:
		return
	_apply_event(current_event)
	main.hud.show_notification("事件已接受: " + current_event.name, current_event.color)

func on_event_rejected():
	if current_event != null:
		main.hud.show_notification("事件已拒绝: " + current_event.name, Color(0.6, 0.6, 0.6))
	current_event = null
	event_active = false

func _apply_event(evt: Dictionary):
	event_active = true
	event_kill_count = 0
	event_treasure_rewarded = false
	match evt.id:
		"healing_fountain":
			if main.player and is_instance_valid(main.player):
				if not main.player.spend_materials(evt.cost):
					main.hud.show_notification("材料不足！需要 %d 材料" % evt.cost, Color(1, 0.3, 0.3))
					event_active = false
					current_event = null
					return
				main.player.hp = main.player.max_hp
				main.player.hp_changed.emit(main.player.hp, main.player.max_hp)
				main.hud.show_notification("生命已完全恢复！", Color(0.2, 1, 0.4))
			event_active = false
			current_event = null
		"treasure_chest":
			pass
		"ambush":
			var extra = 6 + main.wave
			for i in range(extra):
				main.wave_manager._spawn_single_enemy(main.wave_manager._pick_enemy_type())
		"blessing":
			if main.player and is_instance_valid(main.player):
				var dmg_add = int(main.player.damage_bonus * 0.3) + 1
				main.player.damage_bonus += dmg_add
				main.player.speed *= 1.2
				main.player.set_meta("blessing_dmg_added", dmg_add)
				main.player.set_meta("blessing_speed_mult", 1.2)
		"curse":
			if main.player and is_instance_valid(main.player):
				main.player.xp_boost *= 2.0
				main.player.set_meta("curse_xp_active", true)

func clear_event_effects():
	if not event_active and current_event == null:
		return
	if main.player and is_instance_valid(main.player):
		if current_event and current_event.id == "blessing":
			var dmg_added = main.player.get_meta("blessing_dmg_added", 0)
			main.player.damage_bonus -= dmg_added
			main.player.speed /= main.player.get_meta("blessing_speed_mult", 1.0)
			main.player.remove_meta("blessing_dmg_added")
			main.player.remove_meta("blessing_speed_mult")
		if current_event and current_event.id == "curse":
			if main.player.get_meta("curse_xp_active", false):
				main.player.xp_boost /= 2.0
				main.player.remove_meta("curse_xp_active")
	current_event = null
	event_active = false
	event_kill_count = 0
	event_treasure_rewarded = false

# 击杀时调用，处理宝箱/伏击事件
func on_enemy_died(enemy):
	if not event_active or current_event == null:
		return
	match current_event.id:
		"treasure_chest":
			event_kill_count += 1
			if event_kill_count >= current_event.kill_target and not event_treasure_rewarded:
				event_treasure_rewarded = true
				if main.player and is_instance_valid(main.player):
					main.player.earn_gold(current_event.reward_gold)
				main.hud.show_notification("宝箱已开启！+%d 材料！" % current_event.reward_gold, Color(1, 0.85, 0.2))
		"ambush":
			if main.player and is_instance_valid(main.player):
				main.player.earn_gold(3)
