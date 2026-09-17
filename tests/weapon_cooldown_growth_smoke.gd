extends SceneTree

# 冷却节奏与击杀成长冒烟测试（P1-8 第五批）
#
# 覆盖 4 条此前在 weapons.json 里存在但运行时完全不生效的规则：
#   cooldown_every_100_shots              (Chain Gun)       目录 cooldown_every_shots / reload_cooldown
#   material_pickup_resets_cooldown       (Blunderbuss)     由规则名确定（拾取材料即重置）
#   attack_speed_growth_per_kills_this_wave (Ghost Flint)   目录 击杀间隔 / 每档攻速增量
#   max_hp_growth_per_kills_this_wave     (Ghost Scepter)   目录 击杀间隔 / 每档生命增量
#
# 本测试固定：
#   A. 打满 N 发后冷却被追加一次 reload_cooldown，未打满则不受影响；
#   B. 拾取材料把武器冷却清零；
#   C. 击杀成长的档数按「击杀数 / 间隔」向下取整，未满一档不发；
#   D. 攻速成长与最大生命值成长都只在本波内生效 —— 波次开始时被清空/扣回。

const PASS_TAG := "WEAPON_COOLDOWN_GROWTH_SMOKE_PASS"
const FAIL_TAG := "WEAPON_COOLDOWN_GROWTH_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 15

var failures: Array[String] = []
var main = null


func _init():
	call_deferred("_run")


func _run():
	var game_state = root.get_node("/root/GameState")
	game_state.selected_character = "normal"
	game_state.difficulty = 1
	game_state.endless_mode = false
	var audio_manager = root.get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		root.remove_child(audio_manager)
		audio_manager.queue_free()

	var packed = load("res://scenes/Main.tscn")
	if packed == null:
		failures.append("Main 场景缺失")
		_report()
		return
	main = packed.instantiate()
	root.add_child(main)
	await process_frame
	if main.player == null or not is_instance_valid(main.player):
		failures.append("Main 未解析出 player")
		_report()
		return
	_freeze_wave_spawning()

	_check_cooldown_every_n_shots()
	_check_material_pickup_resets_cooldown()
	_check_attack_speed_growth_per_kills()
	_check_max_hp_growth_per_kills()

	if is_instance_valid(main):
		main.queue_free()
	main = null
	for i in range(3):
		await process_frame

	_report()


func _report():
	if failures.is_empty():
		print(PASS_TAG)
		quit(0)
		return
	print("%s: %d 项断言失败" % [FAIL_TAG, failures.size()])
	for i in range(min(failures.size(), MAX_PRINTED_FAILURES)):
		print("  - %s" % failures[i])
	if failures.size() > MAX_PRINTED_FAILURES:
		print("  ... 其余 %d 项同类失败已省略" % (failures.size() - MAX_PRINTED_FAILURES))
	push_error("%s: %d failures" % [FAIL_TAG, failures.size()])
	quit(1)


func _freeze_wave_spawning():
	var wave_manager = main.get("wave_manager")
	if wave_manager == null:
		failures.append("Main 应创建 WaveManager")
		return
	wave_manager.spawn_timer = 9999.0
	wave_manager.tree_spawn_timer = 9999.0
	wave_manager.landmine_spawn_timer = 9999.0
	wave_manager.wave_timer = 9999.0


func _equip_only(weapon_id: String, tier: int):
	main.player.equipped_weapons.clear()
	main.player.combat.emit_weapons_changed()
	if not main.player.equip_or_combine_weapon(weapon_id, tier):
		failures.append("装备失败：%s T%d" % [weapon_id, tier])
		return null
	return main.player.equipped_weapons[0]


func _state_of(weapon: Dictionary) -> Dictionary:
	return main.player.combat._get_weapon_state(weapon)


func _check_cooldown_every_n_shots():
	var weapon = _equip_only("chain_gun", 4)
	if weapon == null:
		return
	var interval = int(weapon.data.get("cooldown_every_shots", 0))
	var penalty = float(weapon.data.get("reload_cooldown", 0.0))
	if interval <= 0 or penalty <= 0.0:
		failures.append("Chain Gun 应带 cooldown_every_shots / reload_cooldown 数据")
		return
	var state = _state_of(weapon)

	# 第 interval 发之前的冷却（shots=interval-2 → 即将打出 interval-1 发）
	state["shots_fired"] = interval - 2
	var normal = main.player.combat._cooldown_for_weapon(weapon)
	# 即将打出第 interval 发（shots 已是 interval-1，加 1 命中判断）
	state["shots_fired"] = interval - 1
	var penalized = main.player.combat._cooldown_for_weapon(weapon)
	var gained = penalized - normal
	if absf(gained - penalty) > 0.001:
		failures.append("打满 %d 发时应追加 %.2f 秒冷却，实际追加 %.4f" % [interval, penalty, gained])

	# 下一发（shots 已跨过 interval）应恢复正常
	state["shots_fired"] = interval
	var after = main.player.combat._cooldown_for_weapon(weapon)
	if absf(after - normal) > 0.001:
		failures.append("跨过第 %d 发后冷却应恢复，期望 %.4f，实际 %.4f" % [interval, normal, after])


func _check_material_pickup_resets_cooldown():
	var weapon = _equip_only("blunderbuss", 2)
	if weapon == null:
		return
	weapon.timer = 99.0
	main.player.on_material_picked_up(1)
	if not is_equal_approx(float(weapon.timer), 0.0):
		failures.append("Blunderbuss 拾取材料后冷却应清零，实际 %.2f" % float(weapon.timer))

	# 没有该规则的武器不应被影响
	var other = _equip_only("smg", 1)
	if other != null:
		other.timer = 7.0
		main.player.on_material_picked_up(1)
		if not is_equal_approx(float(other.timer), 7.0):
			failures.append("不持有该规则的武器冷却不应被材料拾取影响，实际 %.2f" % float(other.timer))


func _check_attack_speed_growth_per_kills():
	var weapon = _equip_only("ghost_flint", 1)
	if weapon == null:
		return
	var interval = int(weapon.data.get("attack_speed_growth_kill_interval", 0))
	var per_step = float(weapon.data.get("attack_speed_growth", 0.0))
	if interval <= 0 or per_step <= 0.0:
		failures.append("Ghost Flint 应带 attack_speed_growth_kill_interval / attack_speed_growth 数据")
		return
	var state = _state_of(weapon)

	state["kills_this_wave"] = 0
	var base = main.player.combat._cooldown_for_weapon(weapon)

	# 未满一档：不应变化
	state["kills_this_wave"] = interval - 1
	var almost = main.player.combat._cooldown_for_weapon(weapon)
	if absf(almost - base) > 0.0001:
		failures.append("击杀 %d 次（未满 %d 一档）时冷却不应变化，期望 %.4f，实际 %.4f" % [
			interval - 1, interval, base, almost
		])

	# 满一档：冷却应变为 base / (1 + per_step)
	state["kills_this_wave"] = interval
	var one_step = main.player.combat._cooldown_for_weapon(weapon)
	var expected_one = base / (1.0 + per_step)
	if absf(one_step - expected_one) > 0.0001:
		failures.append("满一档击杀后冷却应为 %.4f，实际 %.4f" % [expected_one, one_step])

	# 满两档
	state["kills_this_wave"] = interval * 2
	var two_steps = main.player.combat._cooldown_for_weapon(weapon)
	var expected_two = base / (1.0 + per_step * 2.0)
	if absf(two_steps - expected_two) > 0.0001:
		failures.append("满两档击杀后冷却应为 %.4f，实际 %.4f" % [expected_two, two_steps])

	# 波次开始后归零
	main.player.combat.on_wave_start()
	if not is_equal_approx(int(_state_of(weapon).get("kills_this_wave", -1)), 0):
		failures.append("波次开始时 kills_this_wave 应归零")
	var after_reset = main.player.combat._cooldown_for_weapon(weapon)
	if absf(after_reset - base) > 0.0001:
		failures.append("波次开始后攻速成长应消失，期望 %.4f，实际 %.4f" % [base, after_reset])


func _check_max_hp_growth_per_kills():
	var weapon = _equip_only("ghost_scepter", 1)
	if weapon == null:
		return
	var interval = int(weapon.data.get("max_hp_growth_kill_interval", 0))
	var per_step = int(weapon.data.get("max_hp_growth", 0))
	if interval <= 0 or per_step <= 0:
		failures.append("Ghost Scepter 应带 max_hp_growth_kill_interval / max_hp_growth 数据")
		return
	var base_max_hp = int(main.player.max_hp)

	# 未满一档不发
	for i in range(interval - 1):
		main.player.combat.on_enemy_killed(null)
	if int(main.player.max_hp) != base_max_hp:
		failures.append("击杀 %d 次（未满 %d 一档）不应提升最大生命值，实际 %d → %d" % [
			interval - 1, interval, base_max_hp, int(main.player.max_hp)
		])

	# 补到满一档
	main.player.combat.on_enemy_killed(null)
	if int(main.player.max_hp) != base_max_hp + per_step:
		failures.append("击杀满 %d 次应提升 %d 点最大生命值，实际 %d → %d" % [
			interval, per_step, base_max_hp, int(main.player.max_hp)
		])

	# 再满一档
	for i in range(interval):
		main.player.combat.on_enemy_killed(null)
	if int(main.player.max_hp) != base_max_hp + per_step * 2:
		failures.append("击杀满 %d 次应累计提升 %d 点最大生命值，实际 %d" % [
			interval * 2, per_step * 2, int(main.player.max_hp)
		])

	# 波次开始 → 加成被扣回
	main.player.combat.on_wave_start()
	if int(main.player.max_hp) != base_max_hp:
		failures.append("波次开始时最大生命值加成应被扣回 %d，实际 %d" % [base_max_hp, int(main.player.max_hp)])
	if int(_state_of(weapon).get("max_hp_growth_applied", -1)) != 0:
		failures.append("波次开始时 max_hp_growth_applied 应归零")
