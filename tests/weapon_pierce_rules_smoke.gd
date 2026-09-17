extends SceneTree

# 穿透（pierce）数值化冒烟测试
#
# 背景：`weapons.json` 的 tier 行里 `pierce` 是 `{count, damage_multiplier}`，
# 但 `_fire_ranged` 过去把它当布尔用（`bool(dict)` 恒为真），
# 于是 `count` 与 `damage_multiplier` **被所有武器忽略**，一律按 3 次命中、无衰减处理。
# 2026-09-15 起：
#   - `count` = 额外穿透数 → 可命中敌人总数 = count + 1（Bullet.pierce_hit_limit 的语义）；
#   - `damage_multiplier` = 第 n 个后续命中按 multiplier^n 衰减。
#
# 附带成立的一条规则：Flamethrower 的 `damage_multiplier: 0` 会落到 Bullet 里
# `max(1, …)` 的下界，即后续命中固定 1 点 —— `pierce_99_for_one_damage` 无需特判。
#
# 本测试固定：
#   A. 目录 count/倍率正确传导到子弹的 pierce_hit_limit / pierce_damage_multiplier；
#   B. 衰减行为：第 2、3 个命中按倍率的幂次递减；
#   C. Flamethrower 的后续命中固定 1 点；
#   D. 无穿透武器只能命中 1 个目标。

const PASS_TAG := "WEAPON_PIERCE_RULES_SMOKE_PASS"
const FAIL_TAG := "WEAPON_PIERCE_RULES_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 15

# 武器 id, tier, 期望的可命中总数, 期望的衰减倍率（-1 表示目录未给出）
const CAPACITY_CASES := [
	["pistol", 1, 2, 0.5],
	["double_barrel_shotgun", 4, 4, 0.7],
	["harpoon_gun", 4, 6, 0.75],
	["javelin", 1, 3, 0.75],
	["flamethrower", 2, 100, 0.0],
	["minigun", 4, 3, 0.5],
	["laser_gun", 1, 2, 0.75],
	["obliterator", 3, 999, 1.0],
	["smg", 1, 1, -1.0],
]

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

	_check_pierce_capacity()
	_check_pierce_damage_falloff()
	_check_flamethrower_one_damage_per_hit()
	_check_no_pierce_single_target()

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
	# 冻结刷怪，避免测试期间的敌人干扰命中序列
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
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()


func _fire_and_grab_bullet(weapon_id: String, tier: int):
	_clear_weapons()
	_return_all_bullets()
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


func _check_pierce_capacity():
	for case in CAPACITY_CASES:
		var weapon_id = str(case[0])
		var tier = int(case[1])
		var expected_limit = int(case[2])
		var expected_mult = float(case[3])
		var bullet = _fire_and_grab_bullet(weapon_id, tier)
		if bullet == null:
			continue
		if int(bullet.pierce_hit_limit) != expected_limit:
			failures.append("%s T%d 的可命中总数应为 %d，实际 %d" % [
				weapon_id, tier, expected_limit, int(bullet.pierce_hit_limit)
			])
		var actual_mult = float(bullet.pierce_damage_multiplier)
		if expected_mult < 0.0:
			if actual_mult >= 0.0:
				failures.append("%s T%d 目录未给 damage_multiplier，实际却为 %.3f" % [
					weapon_id, tier, actual_mult
				])
		elif not is_equal_approx(actual_mult, expected_mult):
			failures.append("%s T%d 的衰减倍率应为 %.2f，实际 %.3f" % [
				weapon_id, tier, expected_mult, actual_mult
			])
		_return_all_bullets()


func _check_pierce_damage_falloff():
	# double_barrel_shotgun T4：目录 count=3（可命中 4 个）、damage_multiplier=0.7
	var bullet = _fire_and_grab_bullet("double_barrel_shotgun", 4)
	if bullet == null:
		return
	var base_damage = int(bullet.damage)
	var mult = float(bullet.pierce_damage_multiplier)
	var enemies: Array = []
	for i in range(4):
		enemies.append(_make_enemy(Vector2(200 + i * 40, 0)))

	var dealt: Array = []
	for enemy in enemies:
		var before = int(enemy.hp)
		bullet._on_body_entered(enemy)
		dealt.append(before - int(enemy.hp))

	if dealt[0] != base_damage:
		failures.append("首个命中的伤害应为子弹基础伤害 %d，实际 %d" % [base_damage, dealt[0]])
	for i in range(1, 3):
		var expected = max(1, int(round(float(base_damage) * pow(mult, float(i)))))
		if int(dealt[i]) != expected:
			failures.append("第 %d 个命中的伤害应为 %d（%d × %.2f^%d），实际 %d" % [
				i + 1, expected, base_damage, mult, i, int(dealt[i])
			])
	if bullet.visible:
		failures.append("命中数达到目录上限后子弹应归还池中")

	_free_enemies(enemies)
	_return_all_bullets()


func _check_flamethrower_one_damage_per_hit():
	# Flamethrower：damage_multiplier = 0 → 后续命中落到 max(1, …) 下界，固定 1 点
	var bullet = _fire_and_grab_bullet("flamethrower", 2)
	if bullet == null:
		return
	if not is_equal_approx(float(bullet.pierce_damage_multiplier), 0.0):
		failures.append("Flamethrower 的衰减倍率应为 0，实际 %.3f" % float(bullet.pierce_damage_multiplier))
	var enemies: Array = []
	for i in range(3):
		enemies.append(_make_enemy(Vector2(200 + i * 40, 0)))
	var dealt: Array = []
	for enemy in enemies:
		var before = int(enemy.hp)
		bullet._on_body_entered(enemy)
		dealt.append(before - int(enemy.hp))
	for i in range(1, 3):
		if int(dealt[i]) != 1:
			failures.append("Flamethrower 第 %d 个命中应为固定 1 点伤害，实际 %d" % [i + 1, int(dealt[i])])
	_free_enemies(enemies)
	_return_all_bullets()


func _check_no_pierce_single_target():
	var bullet = _fire_and_grab_bullet("smg", 1)
	if bullet == null:
		return
	var enemies: Array = []
	for i in range(2):
		enemies.append(_make_enemy(Vector2(200 + i * 40, 0)))
	bullet._on_body_entered(enemies[0])
	var first_hurt = int(enemies[0].hp) < 999999
	bullet._on_body_entered(enemies[1])
	var second_hurt = int(enemies[1].hp) < 999999
	if not first_hurt:
		failures.append("无穿透武器未对首个目标造成伤害")
	if second_hurt:
		failures.append("无穿透武器不应命中第二个目标")
	_free_enemies(enemies)
	_return_all_bullets()
