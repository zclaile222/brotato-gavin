extends SceneTree

# 远程武器命中上下文 + spawn_projectiles_on_hit 冒烟测试
#
# 背景：近战命中能直接拿到 weapon（`_fire_melee` 里就有），但远程命中是
# `Bullet._on_body_entered` → `Player.on_enemy_hit_by_attack(enemy, context)`，
# 而 context 里原本只有 is_crit / damage —— **不知道是哪把武器开的火**，
# 于是任何「按武器差异化的远程命中效果」都实现不了。
# 2026-09-15 起：子弹携带 source_weapon_runtime_id，命中时放入 context，
# 由 PlayerCombat.apply_ranged_weapon_hit_effects() 反查当前武器并分发。
#
# 本测试固定：
#   A. 武器身份确实随子弹传递；
#   B. 身份能被反查到武器并分发到正确的规则；
#   C. spawn_projectiles_on_hit 按目录数量生成弹片、弹片伤害取自目录；
#   D. 弹片不再携带武器身份 → 不会递归触发；
#   E. 武器已消失（id 找不到）时静默跳过，不崩不生成；
#   F. 远程分发器**不**处理 burn/slow（那两条归 Bullet 自己的通道）—— 防止重复施加。

const PASS_TAG := "RANGED_WEAPON_CONTEXT_SMOKE_PASS"
const FAIL_TAG := "RANGED_WEAPON_CONTEXT_SMOKE_FAIL"
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

	_check_weapon_identity_travels_with_bullet()
	_check_spawn_projectiles_on_hit()
	_check_shards_do_not_recurse()
	_check_missing_weapon_is_skipped()
	_check_ranged_weapon_burn_applies()
	_check_dispatcher_does_not_apply_burn()

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


func _return_all_bullets():
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()


func _count_visible_bullets() -> int:
	var count = 0
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			count += 1
	return count


func _visible_bullets() -> Array:
	var result: Array = []
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			result.append(b)
	return result


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


func _equip_only(weapon_id: String, tier: int):
	main.player.equipped_weapons.clear()
	main.player.combat.emit_weapons_changed()
	if not main.player.equip_or_combine_weapon(weapon_id, tier):
		failures.append("装备失败：%s T%d" % [weapon_id, tier])
		return null
	return main.player.equipped_weapons[0]


func _fire_and_grab(weapon: Dictionary):
	_return_all_bullets()
	var target = _make_enemy(Vector2(200, 0))
	main.player.combat._fire_ranged(weapon, target, [target])
	_free_enemies([target])
	var bullets = _visible_bullets()
	return bullets[0] if not bullets.is_empty() else null


func _check_weapon_identity_travels_with_bullet():
	var weapon = _equip_only("sniper_gun", 3)
	if weapon == null:
		return
	var bullet = _fire_and_grab(weapon)
	if bullet == null:
		failures.append("Sniper Gun 开火后未取到可见子弹")
		return
	var expected = int(weapon.get("runtime_id", 0))
	if expected == 0:
		failures.append("武器应带 runtime_id，实际为 0")
	if int(bullet.source_weapon_runtime_id) != expected:
		failures.append("子弹应携带武器身份 %d，实际 %d" % [expected, int(bullet.source_weapon_runtime_id)])
	_return_all_bullets()


func _check_spawn_projectiles_on_hit():
	var weapon = _equip_only("sniper_gun", 4)
	if weapon == null:
		return
	var expected_shards = int(weapon.data.get("spawned_projectiles_on_hit", 0))
	var expected_damage = int(weapon.data.get("spawned_projectile_damage_base", 0))
	if expected_shards <= 0 or expected_damage <= 0:
		failures.append("Sniper Gun T4 应带 spawned_projectiles_on_hit / spawned_projectile_damage_base 数据")
		return

	var bullet = _fire_and_grab(weapon)
	if bullet == null:
		failures.append("Sniper Gun 开火后未取到可见子弹")
		return

	# 注意：不要在这里调用 _return_all_bullets() —— 那会把待用的这颗子弹也归还（visible=false），
	# 之后的 _on_body_entered 会直接早退。Sniper Gun 无穿透，命中后它自己会归还池中，
	# 所以此时可见的就只剩弹片。
	var enemy = _make_enemy(Vector2(300, 300))
	bullet._on_body_entered(enemy)
	var shards = _visible_bullets()
	if shards.size() != expected_shards:
		failures.append("命中后应生成 %d 个弹片，实际 %d" % [expected_shards, shards.size()])
	for shard in shards:
		if int(shard.damage) != expected_damage:
			failures.append("弹片伤害应为 %d，实际 %d" % [expected_damage, int(shard.damage)])
			break
	_free_enemies([enemy])
	_return_all_bullets()


func _check_shards_do_not_recurse():
	# 弹片不带武器身份 → 再命中也不应生成新弹片
	var weapon = _equip_only("sniper_gun", 4)
	if weapon == null:
		return
	var bullet = _fire_and_grab(weapon)
	if bullet == null:
		return
	var enemy = _make_enemy(Vector2(300, 300))
	bullet._on_body_entered(enemy)
	var shards = _visible_bullets()
	if shards.is_empty():
		failures.append("未生成弹片，无法验证递归保护")
		_free_enemies([enemy])
		return
	var shard = shards[0]
	if int(shard.source_weapon_runtime_id) != 0:
		failures.append("弹片不应携带武器身份，实际 %d" % int(shard.source_weapon_runtime_id))
	var before = _count_visible_bullets()
	shard._on_body_entered(enemy)
	var after = _count_visible_bullets()
	if after > before:
		failures.append("弹片命中后不应再生出新弹片（前 %d，后 %d）" % [before, after])
	_free_enemies([enemy])
	_return_all_bullets()


func _check_missing_weapon_is_skipped():
	# 武器在子弹飞行途中被移除 → 反查不到 → 静默跳过，不崩也不生成
	var weapon = _equip_only("sniper_gun", 4)
	if weapon == null:
		return
	_return_all_bullets()
	var enemy = _make_enemy(Vector2(300, 300))
	var before = _count_visible_bullets()
	main.player.combat.apply_ranged_weapon_hit_effects(999999, enemy, 1, false)
	if _count_visible_bullets() != before:
		failures.append("武器身份找不到时不应生成任何弹片")
	_free_enemies([enemy])
	_return_all_bullets()


func _check_ranged_weapon_burn_applies():
	# 远程武器**自带** burn 值时，命中必须真的点燃。
	# 此前子弹只认玩家的 burn_chance（仅来自 fire_master 协同/物品），
	# 于是 particle_accelerator / wand / fireball 三把远程武器的 burn 数据完全失效。
	var weapon = _equip_only("wand", 1)
	if weapon == null:
		return
	if int(weapon.data.get("burn_damage", 0)) <= 0:
		failures.append("Wand 应带 burn_damage 数据")
		return
	main.player.burn_chance = 0.0	# 明确不依赖玩家协同

	var bullet = _fire_and_grab(weapon)
	if bullet == null:
		failures.append("Wand 开火后未取到可见子弹")
		return
	var enemy = _make_enemy(Vector2(200, 0))
	bullet._on_body_entered(enemy)
	if float(enemy.get("burn_timer")) <= 0.0:
		failures.append("远程武器自带 burn 值时命中应点燃，实际 burn_timer=%.2f" % float(enemy.get("burn_timer")))
	_free_enemies([enemy])
	_return_all_bullets()

	# 反向：不带 burn 值的武器在 burn_chance=0 时不应点燃
	var plain = _equip_only("sniper_gun", 3)
	if plain == null:
		return
	main.player.burn_chance = 0.0
	var plain_bullet = _fire_and_grab(plain)
	if plain_bullet == null:
		return
	var plain_enemy = _make_enemy(Vector2(200, 0))
	plain_bullet._on_body_entered(plain_enemy)
	if float(plain_enemy.get("burn_timer")) > 0.0:
		failures.append("不带 burn 值的远程武器在 burn_chance=0 时不应点燃")
	_free_enemies([plain_enemy])
	_return_all_bullets()


func _check_dispatcher_does_not_apply_burn():
	# 设计契约：远程分发器**不**处理 burn —— 那归 Bullet 的 burn_damage 通道，
	# 放这里会让同一发子弹对同一敌人重复施加燃烧。
	var weapon = _equip_only("rocket_launcher", 2)
	if weapon == null:
		return
	var enemy = _make_enemy(Vector2(300, 300))
	main.player.combat._apply_ranged_weapon_hit_effects(weapon, enemy, 10, false)
	if float(enemy.get("burn_timer")) > 0.0:
		failures.append("远程分发器不应施加燃烧（burn 归 Bullet 通道），实际 burn_timer=%.2f" % float(enemy.get("burn_timer")))
	_free_enemies([enemy])
