# HUDPanels.gd — 暂停菜单、结算面板、成就通知、事件面板、新手引导
class_name HUDPanels
extends RefCounted

var hud: CanvasLayer

func init(p_hud: CanvasLayer):
	hud = p_hud

# ─── 暂停菜单 ───

func show_pause_menu(p_player = null):
	if p_player and is_instance_valid(p_player):
		var crit_pct = "%.0f%%" % (p_player.crit_chance * 100)
		var stats_text = (
			"生命: %d/%d  速度: %.0f  伤害: +%d\n" % [p_player.hp, p_player.max_hp, p_player.speed, p_player.damage_bonus] +
			"暴击: %s  护甲: %d" % [crit_pct, p_player.armor]
		)
		hud.pause_stats_label.text = stats_text
	else:
		hud.pause_stats_label.text = ""
	var master_idx = AudioServer.get_bus_index("Master")
	hud.volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	hud.pause_overlay.visible = true
	hud.pause_panel.visible = true

func hide_pause_menu():
	hud.pause_overlay.visible = false
	hud.pause_panel.visible = false
	if hud.confirm_panel:
		hud.confirm_panel.visible = false

func on_pause_resume():
	hud.get_tree().paused = false
	hide_pause_menu()

func on_pause_restart():
	hud.confirm_label.text = "确定重新开始？"
	hud._confirm_action = "restart"
	hud.confirm_panel.visible = true

func on_pause_main_menu():
	hud.confirm_label.text = "确定返回主菜单？"
	hud._confirm_action = "main_menu"
	hud.confirm_panel.visible = true

func on_confirm_yes():
	hud.confirm_panel.visible = false
	if hud._confirm_action == "restart":
		hud.get_tree().paused = false
		hide_pause_menu()
		hud.get_tree().reload_current_scene()
	elif hud._confirm_action == "main_menu":
		hud.get_tree().paused = false
		hide_pause_menu()
		hud.get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	hud._confirm_action = ""

func on_confirm_no():
	hud.confirm_panel.visible = false
	hud._confirm_action = ""

func on_volume_changed(value: float):
	if hud.has_node("/root/AudioManager"):
		hud.get_node("/root/AudioManager").set_master_volume(value)

# ─── 结算面板 ───

func _build_end_stats(p_player) -> String:
	if not p_player or not is_instance_valid(p_player):
		return ""
	var mins = int(p_player.game_time / 60)
	var secs = int(fmod(p_player.game_time, 60))
	var weapon_names = p_player.equipped_weapons.map(func(w): return w.data.name)
	return "\n\n--- 详细统计 ---\n游戏时长: %d:%02d\n总伤害输出: %d\n总承受伤害: %d\n最高连击: %dx\n武器: %s" % [
		mins, secs,
		p_player.total_damage_dealt,
		p_player.total_damage_taken,
		hud.max_combo,
		", ".join(weapon_names)
	]

func show_game_over(kills, wave, p_player = null):
	var text = "波次: %d    击败敌人: %d" % [wave, kills]
	var ss = hud.get_node_or_null("/root/SaveSystem")
	if ss:
		var data = ss.get_data()
		var best_wave = data.get("best_wave", 0)
		var best_kills = data.get("best_kills", 0)
		text += "\n\n最高波次: %d    最高击杀: %d" % [best_wave, best_kills]
		if wave > best_wave or kills > best_kills:
			text += "\n新记录！"
	text += _build_end_stats(p_player)
	hud.get_node("GameOverPanel/StatsLabel").text = text
	hud.game_over_panel.visible = true

func show_victory(kills, wave, p_player = null):
	var text = "波次: %d / 20    击败敌人: %d" % [wave, kills]
	var ss = hud.get_node_or_null("/root/SaveSystem")
	if ss:
		var data = ss.get_data()
		var best_wave = data.get("best_wave", 0)
		var best_kills = data.get("best_kills", 0)
		text += "\n\n最高波次: %d    最高击杀: %d" % [best_wave, best_kills]
		if wave > best_wave or kills > best_kills:
			text += "\n新记录！"
	text += _build_end_stats(p_player)
	hud.get_node("VictoryPanel/StatsLabel").text = text
	hud.victory_panel.visible = true

func show_wave_summary(p_wave: int, p_kills: int, p_gold: int, p_xp: int, p_is_boss: bool = false):
	# Boss 波次由调用方告知：判据的唯一来源是 data/brotato/enemy_waves.json，
	# 这里硬编码波次列表的话，改数据后会静默失效。
	hud.wave_summary_title.text = "第 %d 波完成！" % p_wave
	if p_is_boss:
		hud.wave_summary_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		hud.wave_summary_title.add_theme_color_override("font_color", Color(1, 1, 1))
	hud.wave_summary_stats.text = "击杀: %d    材料: +%d    XP: +%d" % [p_kills, p_gold, p_xp]
	hud.wave_summary_panel.visible = true
	await hud.get_tree().create_timer(2.0).timeout
	if is_instance_valid(hud.wave_summary_panel):
		hud.wave_summary_panel.visible = false

# ─── 成就通知 ───

func show_notification(text: String, color: Color = Color.WHITE):
	hud.notify_queue.append({"text": text, "color": color})
	if not hud.notify_showing:
		_show_next_notification()

func _show_next_notification():
	if hud.notify_queue.is_empty():
		hud.notify_showing = false
		return
	hud.notify_showing = true
	var notif = hud.notify_queue.pop_front()
	var label = hud.notify_panel.get_node("NotifyLabel")
	label.text = notif.text
	label.add_theme_color_override("font_color", notif.color)
	hud.notify_panel.visible = true
	var screen_w = hud.get_viewport().get_visible_rect().size.x
	hud.notify_panel.position.x = screen_w
	var tween = hud.create_tween()
	tween.tween_property(hud.notify_panel, "position:x", screen_w - 310, 0.3)
	tween.tween_interval(3.0)
	tween.tween_property(hud.notify_panel, "position:x", screen_w, 0.3)
	tween.tween_callback(func():
		hud.notify_panel.visible = false
		_show_next_notification()
	)

func show_achievement_unlock(title: String, desc: String):
	hud.achievement_queue.append({"title": title, "desc": desc})
	if not hud.achievement_showing:
		_show_next_achievement()

func _show_next_achievement():
	if hud.achievement_queue.is_empty():
		hud.achievement_showing = false
		return
	hud.achievement_showing = true
	var ach = hud.achievement_queue.pop_front()
	var vbox = hud.achievement_panel.get_node("AchVBox")
	vbox.get_node("AchTitle").text = "成就解锁: " + ach.title
	vbox.get_node("AchDesc").text = ach.desc
	hud.achievement_panel.visible = true
	var screen_w = hud.get_viewport().get_visible_rect().size.x
	hud.achievement_panel.position.x = screen_w
	var tween = hud.create_tween()
	tween.tween_property(hud.achievement_panel, "position:x", screen_w - 300, 0.3)
	tween.tween_interval(3.0)
	tween.tween_property(hud.achievement_panel, "position:x", screen_w, 0.3)
	tween.tween_callback(func():
		hud.achievement_panel.visible = false
		_show_next_achievement()
	)

func show_achievements_summary(new_unlocks: Array):
	if new_unlocks.is_empty():
		return
	var ss = hud.get_node_or_null("/root/SaveSystem")
	if ss == null:
		return
	var text = "\n新解锁成就："
	for id in new_unlocks:
		var info = ss.ACHIEVEMENTS.get(id, {"name": id, "desc": ""})
		text += "\n  ★ %s — %s" % [info.name, info.desc]
	if hud.game_over_panel.visible:
		var stats_lbl = hud.game_over_panel.get_node_or_null("StatsLabel")
		if stats_lbl:
			stats_lbl.text += text
	elif hud.victory_panel.visible:
		var stats_lbl = hud.victory_panel.get_node_or_null("StatsLabel")
		if stats_lbl:
			stats_lbl.text += text

# ─── 事件面板 ───

func show_event_panel(title: String, desc: String, color: Color = Color(1, 0.85, 0.2)):
	hud.event_title_label.text = title
	hud.event_title_label.add_theme_color_override("font_color", color)
	hud.event_desc_label.text = desc
	hud.event_timer_countdown = 3.0
	hud.event_timer_label.text = "剩余时间: 3 秒"
	hud.event_panel.visible = true
	hud.get_tree().paused = true

func on_event_accept():
	hud.event_panel.visible = false
	hud.event_timer_countdown = 0.0
	hud.get_tree().paused = false
	hud.event_accepted.emit()

func on_event_reject():
	hud.event_panel.visible = false
	hud.event_timer_countdown = 0.0
	hud.get_tree().paused = false
	hud.event_rejected.emit()

func process_event_timer(delta):
	if hud.event_timer_countdown > 0 and hud.event_panel.visible:
		hud.event_timer_countdown -= delta
		hud.event_timer_label.text = "剩余时间: %d 秒" % ceil(hud.event_timer_countdown)
		if hud.event_timer_countdown <= 0:
			on_event_reject()

# ─── 新手引导 ───

func show_tutorial_hint():
	hud.tutorial_panel.visible = true
	hud.tutorial_panel.modulate = Color(1, 1, 1, 1)
	var tween = hud.create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(hud.tutorial_panel, "modulate", Color(1, 1, 1, 0), 1.0)
	tween.tween_callback(func():
		hud.tutorial_panel.visible = false
	)
