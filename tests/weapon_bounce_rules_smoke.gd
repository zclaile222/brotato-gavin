extends SceneTree

# 投射物弹跳与工程减速冒烟测试（P1-8 第四批）
#
# 覆盖 5 条此前在 weapons.json 里存在但运行时完全不生效的规则：
#   bounce_by_tier               (Slingshot)           目录 bounces 1/2/3/4
#   bounce_once                  (Grenade Launcher)    由规则名确定 = 1
#   critical_hit_bounce          (Shuriken)            目录 crit_bounces，仅暴击时生效
#   cannot_bounce                (Particle Accelerator) 由规则名确定 = 禁止（并压过玩家加成）
#   engineering_based_slow       (Particle Accelerator) 目录 engineering_slow_per_point × 工程点数
#
# 本测试固定：
#   A. 各武器的弹跳次数正确传导到子弹；
#   B. critical_hit_bounce 只在暴击时给弹跳；
#   C. cannot_bounce 压过玩家的 projectile_bounce_bonus；
#   D. 工程减速量随工程点数线性增长；
#   E. 行为层：有弹跳时子弹命中后不回收并转向下一个敌人，无弹跳时立刻回收。

const PASS_TAG := "WEAPON_BOUNCE_RULES_SMOKE_PASS"
const FAIL_TAG := "WEAPON_BOUNCE_RULES_SMOKE_FAIL"
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
	_clear_weapons()

	_check_bounce_by_tier()
	_check_bounce_once()
	_check_critical_hit_bounce()
	_check_cannot_bounce()
	_check_engineering_based_slow()
	_check_bounce_behaviour()

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


func _clear_weapons():
	main.player.equipped_weapons.clear()
	main.player.combat.emit_weapons_changed()


func _return_all_bullets():
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()


func _make_enemy(pos: Vector2):
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	# ⚠ 先入树再关处理（进树前 set_physics_process 会被忽略）
	root.add_child(enemy)
	enemy.setup("normal", 1)
	enemy.position = pos
	enemy.hp = 999999
	enemy.max_hp = enemy.hp
	enemy.set_physics_process(false)
	return enemy


func _free_enemies(enemies: Array):
	# ⚠ 必须用 free() 而不是 queue_free()：queue_free 是延迟释放，测试内紧接着做同步断言时，
	# 被释放的节点仍留在场景树与 "enemies" 组里，会被 _try_bounce_to_next_target 当成
	# 「最近的敌人」选中（距离 0 → normalized() 得到零向量），污染弹跳方向断言。
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.free()


func _fire_and_grab(weapon_id: String, tier: int):
	_clear_weapons()
	_return_all_bullets()
	main.player.projectile_bounce_bonus = 0
	if not main.player.equip_or_combine_weapon(weapon_id, tier):
		failures.append("装备失败：%s T%d" % [weapon_id, tier])
		return null
	var weapon = main.player.equipped_weapons[0]
	var target = _make_enemy(Vector2(200, 0))
	main.player.combat._fire_ranged(weapon, target, [target])
	_free_enemies([target])
	var bullet = null
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			bullet = b
			break
	if bullet == null:
		failures.append("%s T%d 开火后未取到可见子弹" % [weapon_id, tier])
	return bullet


func _check_bounce_by_tier():
	for case in [["slingshot", 1, 1], ["slingshot", 4, 4]]:
		var bullet = _fire_and_grab(str(case[0]), int(case[1]))
		if bullet == null:
			continue
		if int(bullet.bounce_remaining) != int(case[2]):
			failures.append("Slingshot T%d 的弹跳次数应为 %d，实际 %d" % [
				int(case[1]), int(case[2]), int(bullet.bounce_remaining)
			])
		_return_all_bullets()


func _check_bounce_once():
	var bullet = _fire_and_grab("grenade_launcher", 2)
	if bullet == null:
		return
	if int(bullet.bounce_remaining) != 1:
		failures.append("Grenade Launcher 的 bounce_once 应给出 1 次弹跳，实际 %d" % int(bullet.bounce_remaining))
	_return_all_bullets()


func _check_critical_hit_bounce():
	# 先保证不暴击 → 无弹跳
	main.player.crit_chance = 0.0
	var plain = _fire_and_grab("shuriken", 4)
	if plain != null:
		if int(plain.bounce_remaining) != 0:
			failures.append("Shuriken 非暴击时不应有弹跳，实际 %d" % int(plain.bounce_remaining))
		_return_all_bullets()
	# 再强制必暴击 → 取目录 crit_bounces（T4 = 4）
	main.player.crit_chance = 1.0
	var crit = _fire_and_grab("shuriken", 4)
	if crit != null:
		if int(crit.bounce_remaining) != 4:
			failures.append("Shuriken 暴击时的弹跳次数应为 4，实际 %d" % int(crit.bounce_remaining))
		_return_all_bullets()
	main.player.crit_chance = 0.0


func _check_cannot_bounce():
	var bullet = _fire_and_grab("particle_accelerator", 3)
	if bullet == null:
		return
	# 给玩家一堆弹跳加成，cannot_bounce 也必须压过它
	main.player.projectile_bounce_bonus = 5
	_return_all_bullets()
	var weapon = main.player.equipped_weapons[0]
	var target = _make_enemy(Vector2(200, 0))
	main.player.combat._fire_ranged(weapon, target, [target])
	_free_enemies([target])
	var forced = null
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			forced = b
			break
	if forced != null and int(forced.bounce_remaining) != 0:
		failures.append("cannot_bounce 应压过玩家的弹跳加成，实际弹跳 %d" % int(forced.bounce_remaining))
	main.player.projectile_bounce_bonus = 0
	_return_all_bullets()


func _check_engineering_based_slow():
	var bullet = _fire_and_grab("particle_accelerator", 4)
	if bullet == null:
		return
	var per_point = float(main.player.equipped_weapons[0].data.get("engineering_slow_per_point", 0.0))
	if per_point <= 0.0:
		failures.append("Particle Accelerator T4 应带 engineering_slow_per_point 数据")
		_return_all_bullets()
		return

	main.player.engineering_bonus = 20
	_return_all_bullets()
	var weapon = main.player.equipped_weapons[0]
	var target = _make_enemy(Vector2(200, 0))
	main.player.combat._fire_ranged(weapon, target, [target])
	_free_enemies([target])
	var slowed = null
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			slowed = b
			break
	if slowed == null:
		failures.append("工程减速检查：未取到子弹")
		_return_all_bullets()
		return
	var expected = clamp(20.0 * per_point, 0.0, 0.9)
	if not bool(slowed.slow_on_hit):
		failures.append("Particle Accelerator 应开启命中减速")
	if not is_equal_approx(float(slowed.slow_factor), expected):
		failures.append("工程 20 点、每点 %.3f 时减速量应为 %.3f，实际 %.3f" % [
			per_point, expected, float(slowed.slow_factor)
		])
	main.player.engineering_bonus = 0
	_return_all_bullets()


func _check_bounce_behaviour():
	# 有弹跳：命中后不回收，且转向下一个敌人；无弹跳：立刻回收
	var bullet = _fire_and_grab("slingshot", 4)
	if bullet == null:
		return
	var first = _make_enemy(Vector2(200, 0))
	var second = _make_enemy(Vector2(200, 120))
	bullet.position = Vector2(200, 0)
	bullet._on_body_entered(first)
	if not bullet.visible:
		failures.append("Slingshot 子弹命中后仍有余量，不应立刻回收")
	elif int(bullet.bounce_remaining) != 3:
		failures.append("命中一次后弹跳余量应为 3，实际 %d" % int(bullet.bounce_remaining))
	var to_second = (second.position - bullet.position).normalized()
	if bullet.direction.dot(to_second) < 0.9:
		failures.append("弹跳后子弹应朝下一个敌人转向：方向 %s，期望约 %s" % [
			str(bullet.direction), str(to_second)
		])
	_free_enemies([first, second])
	_return_all_bullets()

	# 既无弹跳也无穿透的武器（SMG T1）命中即回收。
	# 注意不能用 pistol：它有 1 次穿透，首击后本来就该继续飞。
	var no_bounce = _fire_and_grab("smg", 1)
	if no_bounce == null:
		return
	var lone = _make_enemy(Vector2(200, 0))
	no_bounce.position = Vector2(200, 0)
	no_bounce._on_body_entered(lone)
	if no_bounce.visible:
		failures.append("无弹跳子弹命中后应立刻回收")
	_free_enemies([lone])
	_return_all_bullets()
