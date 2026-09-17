extends SceneTree

# 近战「命中/挥击附加效果 + 武器自持结构」冒烟测试（P1-8 第三批）
#
# 覆盖 6 条此前在 weapons.json 里存在但运行时完全不生效的规则：
#   damage_taken_debuff_on_hit              (Lute)      命中叠加受击易伤，按目录上限封顶
#   break_and_drop_materials_on_hit         (Brick)     命中几率碎出材料
#   shoot_thorns                            (Cacti Club) 每次挥击向四周发射荆棘弹
#   reset_offensive_turret_cooldowns_on_attack (War Hammer) 挥击重置进攻型建筑冷却
#   spawn_landmine_by_tier                  (Screwdriver) 按目录间隔周期埋雷
#   spawn_fruit_garden                      (Pruner)     按目录间隔周期结出花园
#
# 本测试固定：
#   A. 易伤按步叠加并封顶；
#   B. 碎材料确实进入玩家材料数，且是 break_materials 的整数倍；
#   C. 荆棘弹数量等于目录的 thorn_projectiles；
#   D. 挥击把进攻型建筑冷却归零，但不动医疗炮台；
#   E. 自持结构的生成严格按目录间隔（含「不到间隔不生成」）。

const PASS_TAG := "WEAPON_ON_HIT_EFFECTS_SMOKE_PASS"
const FAIL_TAG := "WEAPON_ON_HIT_EFFECTS_SMOKE_FAIL"
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

	_check_damage_taken_debuff()
	_check_break_and_drop_materials()
	_check_shoot_thorns()
	_check_reset_turret_cooldowns()
	_check_spawn_landmine()
	_check_spawn_fruit_garden()

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


func _count_visible_bullets() -> int:
	var count = 0
	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			count += 1
	return count


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


func _equip_only(weapon_id: String, tier: int):
	_clear_weapons()
	if not main.player.equip_or_combine_weapon(weapon_id, tier):
		failures.append("装备失败：%s T%d" % [weapon_id, tier])
		return null
	return main.player.equipped_weapons[0]


func _check_damage_taken_debuff():
	# Lute T1：damage_taken_bonus=0.1，damage_taken_cap=0.3
	var weapon = _equip_only("lute", 1)
	if weapon == null:
		return
	var step = float(weapon.data.get("damage_taken_bonus", 0.0))
	var cap = float(weapon.data.get("damage_taken_cap", 0.0))
	if step <= 0.0 or cap <= 0.0:
		failures.append("Lute T1 应带 damage_taken_bonus / damage_taken_cap 数据")
		return
	var enemy = _make_enemy(Vector2(30, 0))

	main.player.combat._apply_weapon_hit_effects(weapon, enemy, 4, false)
	var after_one = float(enemy.get("damage_taken_percent_bonus"))
	if not is_equal_approx(after_one, step):
		failures.append("Lute 命中一次后易伤应为 %.2f，实际 %.2f" % [step, after_one])

	# 叠加到超过上限，应被 cap 截住
	for i in range(10):
		main.player.combat._apply_weapon_hit_effects(weapon, enemy, 4, false)
	var after_many = float(enemy.get("damage_taken_percent_bonus"))
	if not is_equal_approx(after_many, cap):
		failures.append("Lute 反复命中后易伤应封顶在 %.2f，实际 %.2f" % [cap, after_many])

	_free_enemies([enemy])
	_clear_weapons()


func _check_break_and_drop_materials():
	# Brick T4：break_chance=0.01，break_materials=120
	seed(20260915)
	var weapon = _equip_only("brick", 4)
	if weapon == null:
		return
	var materials = int(weapon.data.get("break_materials", 0))
	var chance = float(weapon.data.get("break_chance", 0.0))
	if materials <= 0 or chance <= 0.0:
		failures.append("Brick T4 应带 break_chance / break_materials 数据")
		return
	var enemy = _make_enemy(Vector2(30, 0))
	var before = int(main.player.gold)
	# 1% 概率 → 跑足够多次让「一次都不触发」的概率可忽略
	for i in range(3000):
		main.player.combat._apply_weapon_hit_effects(weapon, enemy, 120, false)
	var gained = int(main.player.gold) - before
	if gained <= 0:
		failures.append("Brick 命中 3000 次后未碎出任何材料（break_chance=%.3f）" % chance)
	elif gained % materials != 0:
		failures.append("Brick 碎出的材料应为 %d 的整数倍，实际 %d" % [materials, gained])

	_free_enemies([enemy])
	_clear_weapons()


func _check_shoot_thorns():
	# Cacti Club T4：thorn_projectiles=6
	var weapon = _equip_only("cacti_club", 4)
	if weapon == null:
		return
	var expected = int(weapon.data.get("thorn_projectiles", 0))
	_return_all_bullets()
	var enemy = _make_enemy(Vector2(30, 0))
	main.player.combat._fire_melee(weapon, [enemy])
	var fired = _count_visible_bullets()
	if fired != expected:
		failures.append("Cacti Club T4 每次挥击应发射 %d 发荆棘弹，实际 %d" % [expected, fired])
	_return_all_bullets()
	_free_enemies([enemy])
	_clear_weapons()


func _check_reset_turret_cooldowns():
	# War Hammer（规则自 T3 起）：挥击把进攻型建筑冷却归零，医疗炮台不动
	var weapon = _equip_only("war_hammer", 3)
	if weapon == null:
		return
	var manager = main.turret_manager
	var offensive = manager.spawn_catalog_turret(Vector2(300, 300))
	var medical = manager.spawn_catalog_turret(Vector2(340, 300))
	medical.set_meta("is_medical_turret", true)
	offensive.set_meta("shoot_timer", 5.0)
	medical.set_meta("shoot_timer", 5.0)

	main.player.combat._apply_melee_attack_effects(weapon)
	if not is_equal_approx(float(offensive.get_meta("shoot_timer")), 0.0):
		failures.append("War Hammer 挥击后进攻型建筑冷却应归零，实际 %.2f" % float(offensive.get_meta("shoot_timer")))
	if not is_equal_approx(float(medical.get_meta("shoot_timer")), 5.0):
		failures.append("War Hammer 挥击不应重置医疗炮台冷却，实际 %.2f" % float(medical.get_meta("shoot_timer")))

	manager.cleanup()
	_clear_weapons()


func _check_spawn_landmine():
	# Screwdriver T4：mine_spawn_interval=3
	var weapon = _equip_only("screwdriver", 4)
	if weapon == null:
		return
	var interval = float(weapon.data.get("mine_spawn_interval", 0.0))
	if interval <= 0.0:
		failures.append("Screwdriver T4 应带 mine_spawn_interval 数据")
		return
	var manager = main.turret_manager
	manager.cleanup()
	var before = manager.active_landmines.size()

	main.player.combat._process_weapon_state(weapon, 0.016)
	var after_first = manager.active_landmines.size()
	if after_first != before + 1:
		failures.append("Screwdriver 装上后首次更新应埋下 1 颗地雷，实际新增 %d" % (after_first - before))

	# 未到间隔不应再生成
	main.player.combat._process_weapon_state(weapon, interval * 0.5)
	var after_half = manager.active_landmines.size()
	if after_half != after_first:
		failures.append("未到 mine_spawn_interval(%.1fs) 不应再埋雷，实际新增 %d" % [interval, after_half - after_first])

	# 跨过间隔应再生成
	main.player.combat._process_weapon_state(weapon, interval)
	var after_full = manager.active_landmines.size()
	if after_full <= after_half:
		failures.append("跨过 mine_spawn_interval(%.1fs) 后应再埋雷，实际未新增" % interval)

	manager.cleanup()
	_clear_weapons()


func _check_spawn_fruit_garden():
	# Pruner T4：garden_fruit_interval=10
	var weapon = _equip_only("pruner", 4)
	if weapon == null:
		return
	var manager = main.turret_manager
	manager.cleanup()
	var before = manager.active_gardens.size()

	main.player.combat._process_weapon_state(weapon, 0.016)
	var after_first = manager.active_gardens.size()
	if after_first != before + 1:
		failures.append("Pruner 装上后首次更新应结出 1 个花园，实际新增 %d" % (after_first - before))

	var garden = manager.active_gardens[manager.active_gardens.size() - 1] if after_first > before else null
	var expected_interval = float(weapon.data.get("garden_fruit_interval", 15.0))
	if garden != null and not is_equal_approx(float(garden.get_meta("base_interval", -1.0)), expected_interval):
		failures.append("花园的 base_interval 应取自目录的 %.1f，实际 %.1f" % [
			expected_interval, float(garden.get_meta("base_interval", -1.0))
		])

	manager.cleanup()
	_clear_weapons()
