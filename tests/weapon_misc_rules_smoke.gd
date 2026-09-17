extends SceneTree

# 杂项武器规则冒烟测试（P1-8 第六批）
#
# 覆盖 4 条此前在 weapons.json 里存在但运行时完全不生效的规则：
#   damage_penalty_while_standing_still         (Jousting Lance) 目录 standing_still_damage_penalty
#   instant_kill_chance_by_tier                 (Vorpal Sword)   目录 instant_kill_chance
#   spawn_lightning_projectile_on_hit           (Lightning Shiv) 目录 lightning_damage / lightning_bounces
#   explosion_damage_growth_per_explosion_this_wave (DEX-troyer) 目录 explosion_damage_growth_per_explosion
#
# 本测试固定：
#   A. 站定惩罚只在该武器站定时生效（移动时不生效）；
#   B. 斩杀概率确实按目录命中，且命中即为即死；
#   C. 命中射出的闪电弹携带正确的伤害与弹跳余量；
#   D. 爆炸伤害逐次递增，且波次开始后回到基线。

const PASS_TAG := "WEAPON_MISC_RULES_SMOKE_PASS"
const FAIL_TAG := "WEAPON_MISC_RULES_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 15
const INSTANT_KILL_TRIALS := 1000

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

	_check_standing_still_damage_penalty()
	_check_instant_kill_chance()
	_check_spawn_lightning_projectile()
	_check_explosion_damage_growth()

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


func _make_enemy(pos: Vector2, hp: int = 999999):
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	# ⚠ 先入树再关处理（进树前 set_physics_process 会被忽略）
	root.add_child(enemy)
	enemy.setup("normal", 1)
	enemy.position = pos
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.set_physics_process(false)
	return enemy


func _free_enemies(enemies: Array):
	# 用 free() 而非 queue_free()：延迟释放的节点仍在 enemies 组里，会污染同步断言
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.free()


func _check_standing_still_damage_penalty():
	var weapon = _equip_only("jousting_lance", 4)
	if weapon == null:
		return
	var penalty = float(weapon.data.get("standing_still_damage_penalty", 0.0))
	if penalty >= 0.0:
		failures.append("Jousting Lance T4 应带负的 standing_still_damage_penalty")
		return

	main.player.velocity = Vector2(120, 0)
	var moving = main.player.combat._damage_for_weapon(weapon, null)
	main.player.velocity = Vector2.ZERO
	var still = main.player.combat._damage_for_weapon(weapon, null)
	main.player.velocity = Vector2(120, 0)

	if moving <= 0:
		failures.append("Jousting Lance 移动时伤害应大于 0")
		return
	var expected_still = max(1, int(round(float(moving) * (1.0 + penalty))))
	if still != expected_still:
		failures.append("站定伤害应为 %d（移动 %d × %.2f），实际 %d" % [expected_still, moving, 1.0 + penalty, still])
	if still >= moving:
		failures.append("站定惩罚应让伤害下降：移动 %d，站定 %d" % [moving, still])


func _check_instant_kill_chance():
	seed(20260915)
	var weapon = _equip_only("vorpal_sword", 4)
	if weapon == null:
		return
	var chance = float(weapon.data.get("instant_kill_chance", 0.0))
	if chance <= 0.0:
		failures.append("Vorpal Sword T4 应带 instant_kill_chance 数据")
		return
	var enemy = _make_enemy(Vector2(30, 0), 999999)
	var kills = 0
	for i in range(INSTANT_KILL_TRIALS):
		if not is_instance_valid(enemy):
			break
		if not enemy.visible or int(enemy.hp) <= 0:
			# 上一次试炼把它斩了，恢复后继续
			enemy.visible = true
			enemy.hp = 999999
			enemy.max_hp = 999999
		var before = int(enemy.hp)
		main.player.combat._apply_weapon_hit_effects(weapon, enemy, 1, false)
		if int(enemy.hp) <= 0 or int(enemy.hp) < before / 2:
			kills += 1

	# 3% 概率、1000 次试炼 → 期望 30 次，落空概率可忽略
	if kills <= 0:
		failures.append("Vorpal Sword 在 %d 次试炼中一次都没触发斩杀（chance=%.3f）" % [INSTANT_KILL_TRIALS, chance])
	elif kills > INSTANT_KILL_TRIALS / 3:
		failures.append("Vorpal Sword 斩杀触发 %d/%d 次，远超目录概率 %.3f" % [kills, INSTANT_KILL_TRIALS, chance])

	_free_enemies([enemy])


func _check_spawn_lightning_projectile():
	var weapon = _equip_only("lightning_shiv", 4)
	if weapon == null:
		return
	var expected_damage = int(weapon.data.get("lightning_damage", 0))
	var expected_bounces = int(weapon.data.get("lightning_bounces", 0))
	if expected_damage <= 0:
		failures.append("Lightning Shiv T4 应带 lightning_damage 数据")
		return
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()

	var enemy = _make_enemy(Vector2(30, 0))
	main.player.combat._apply_weapon_hit_effects(weapon, enemy, 3, false)

	var spawned = null
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			spawned = b
			break
	if spawned == null:
		failures.append("Lightning Shiv 命中后未生成闪电弹")
	else:
		if int(spawned.damage) != expected_damage:
			failures.append("闪电弹伤害应为 %d，实际 %d" % [expected_damage, int(spawned.damage)])
		if int(spawned.bounce_remaining) != expected_bounces:
			failures.append("闪电弹弹跳余量应为 %d，实际 %d" % [expected_bounces, int(spawned.bounce_remaining)])
		spawned._return_to_pool()

	_free_enemies([enemy])


func _check_explosion_damage_growth():
	var weapon = _equip_only("dex_troyer", 4)
	if weapon == null:
		return
	var growth = float(weapon.data.get("explosion_damage_growth_per_explosion", 0.0))
	if growth <= 0.0:
		failures.append("DEX-troyer T4 应带 explosion_damage_growth_per_explosion 数据")
		return

	# 三次爆炸：第 1 次不吃加成，第 2、3 次分别 +growth、+2×growth
	var dealt: Array = []
	for i in range(3):
		var enemy = _make_enemy(Vector2(400, 400), 999999)
		var before = int(enemy.hp)
		main.player.deal_catalog_explosion(Vector2(400, 400), 100, 200.0)
		dealt.append(before - int(enemy.hp))
		_free_enemies([enemy])

	var base = dealt[0]
	if base <= 0:
		failures.append("爆炸未对范围内敌人造成伤害，无法验证成长")
		return
	for i in range(1, 3):
		var expected = int(round(100.0 * (1.0 + growth * float(i))))
		if int(dealt[i]) != expected:
			failures.append("第 %d 次爆炸伤害应为 %d（100 × (1 + %.2f × %d)），实际 %d" % [
				i + 1, expected, growth, i, int(dealt[i])
			])

	# 波次开始后计数归零 → 回到基线
	main.player.combat.on_wave_start()
	var enemy = _make_enemy(Vector2(400, 400), 999999)
	var before = int(enemy.hp)
	main.player.deal_catalog_explosion(Vector2(400, 400), 100, 200.0)
	var after_reset = before - int(enemy.hp)
	_free_enemies([enemy])
	if after_reset != base:
		failures.append("波次开始后爆炸伤害应回到基线 %d，实际 %d" % [base, after_reset])
