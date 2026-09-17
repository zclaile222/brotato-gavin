# PlayerStats.gd — 统计数据、动态难度采样
class_name PlayerStats
extends RefCounted

var p: CharacterBody2D
var _last_cleanup_time: float = 0.0

func init(player: CharacterBody2D):
	p = player

func update_game_time(delta):
	p.game_time += delta
	if p.has_method("process_wisdom_damage"):
		p.process_wisdom_damage(delta)
	if p.has_method("process_medikit_hp_regen"):
		p.process_medikit_hp_regen(delta)
	if p.has_method("process_crystal_attack_speed"):
		p.process_crystal_attack_speed(delta)
	# 每10秒主动清理过期 damage_events
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_cleanup_time >= 10.0:
		_last_cleanup_time = now
		_cleanup_old_damage_events()

func _cleanup_old_damage_events():
	var now = Time.get_ticks_msec() / 1000.0
	while p.damage_events.size() > 0 and now - p.damage_events[0] > 10.0:
		p.damage_events.pop_front()

func get_recent_damage_count(window: float) -> int:
	var now = Time.get_ticks_msec() / 1000.0
	var count = 0
	for t in p.damage_events:
		if now - t <= window:
			count += 1
	# 清理过期记录
	while p.damage_events.size() > 0 and now - p.damage_events[0] > window:
		p.damage_events.pop_front()
	return count
