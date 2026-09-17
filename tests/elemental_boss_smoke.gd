extends SceneTree

# 元素 Boss 冒烟测试（P4-5 的 P0 + P1）
#
# 依据 docs/boss-variants-design.md。这一片落了设计文档的三级优先级里的前两级：
#   P0 — 数据定义：ENEMY_TYPES 加入 boss_fire / boss_frost / boss_lightning
#   P1 — 元素子弹：EnemyBullet 带 element，命中玩家时施加状态
#   P1 — 阶段差异化：_on_phase_change 按类型取速度倍率
# 文档里的 P2（火焰冲锋 / 冰甲+冻结脉冲 / 闪现+链式闪电）**尚未实现**，本测试不覆盖。
#
# 一个前置事实：实现之前，玩家侧**完全没有状态效果系统**（burn / slow / stun 都不存在），
# 所以设计文档里那句「Player 命中时 apply_burn()」需要先建 PlayerStatus 模块。
# 本测试固定：
#   A. 数据与判据：三种变体的数值取自设计文档；Boss 判据收敛后覆盖新类型；
#   B. 弹幕元素：类型 → 元素 → 子弹染色 → 池化复用不串味；
#   C. 阶段差异化：三种变体的阶段速度倍率确实不同，且接线到 base_speed；
#   D. 命中效果：三种元素各自生效，且**只在伤害真正落地后**施加
#      （无敌帧 / 闪避挡下的命中不得附带 debuff）；
#   E. 状态语义：燃烧不叠伤害、减速不叠成「动不了」、眩晕带冷却；
#   F. 眩晕定量门：模拟雷电 Boss 连续弹幕，失控时间占比必须低于上限（防弹幕锁死）；
#   G. 波末清理：状态不带进下一波。

const PASS_TAG := "ELEMENTAL_BOSS_SMOKE_PASS"
const FAIL_TAG := "ELEMENTAL_BOSS_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

# 设计文档「P0 — 数据定义」的取值：(spd, hp_m, sc, dmg, xp, gold)
const VARIANT_STATS := {
	"boss_fire":      {"spd": 55, "hp_m": 9.0,  "sc": 2.4, "dmg": 2, "xp": 22, "gold": 32},
	"boss_frost":     {"spd": 40, "hp_m": 12.0, "sc": 2.6, "dmg": 2, "xp": 24, "gold": 35},
	"boss_lightning": {"spd": 65, "hp_m": 8.0,  "sc": 2.2, "dmg": 3, "xp": 25, "gold": 35},
}
const VARIANT_ELEMENTS := {
	"boss_fire": "fire",
	"boss_frost": "frost",
	"boss_lightning": "lightning",
}
# 期望的 Boss 波次轮换（波号 → Boss 类型），与 enemy_waves.json 对齐
const EXPECTED_BOSS_ROTATION := {5: "boss_frost", 10: "boss_fire", 15: "boss_lightning"}

# 雷电 Boss 的失控上限：连续弹幕下，处于眩晕的时间占比不得超过这个值。
# 取值来自「玩家不该被弹幕锁死」这条设计底线（详见 PlayerStatus 的注释）。
const MAX_STUN_UPTIME := 0.40

var failures: Array[String] = []
var main = null
var player = null
var wave_manager = null
var enemy_types: Dictionary = {}


func _init():
	call_deferred("_run")


func _run():
	seed(20260915)
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

	player = main.get("player")
	wave_manager = main.get("wave_manager")
	if player == null or not is_instance_valid(player):
		failures.append("Main 未解析出 player")
		_report()
		return
	if wave_manager == null:
		failures.append("Main 应创建 WaveManager")
		_report()
		return
	enemy_types = wave_manager.call("enemy_types")
	if enemy_types.is_empty():
		failures.append("取不到 Enemy.ENEMY_TYPES")
	_freeze_wave_spawning()

	_check_variant_stats()
	_check_boss_type_judgement()
	_check_wave_table_rotation()
	_check_bullet_element_and_color()
	_check_pool_reuse_does_not_leak_element()
	await _check_boss_volley_carries_element()
	_check_phase_speed_differentiation()
	_check_element_landing_gate()
	_check_status_semantics()
	_check_stun_uptime_bound()
	_check_wave_reset_clears_status()
	_check_movement_hook_wired()

	_cleanup_enemies()
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
	wave_manager.spawn_timer = 9999.0
	wave_manager.tree_spawn_timer = 9999.0
	wave_manager.landmine_spawn_timer = 9999.0
	wave_manager.wave_timer = 9999.0


# ─── A. 数据与判据 ───

func _check_variant_stats():
	for type_name in VARIANT_STATS:
		if not enemy_types.has(type_name):
			failures.append("ENEMY_TYPES 缺少变体: %s" % type_name)
			continue
		var row: Dictionary = enemy_types[type_name]
		var expected: Dictionary = VARIANT_STATS[type_name]
		for key in expected:
			var actual = row.get(key)
			if actual == null:
				failures.append("%s 缺少字段 %s" % [type_name, key])
				continue
			if not is_equal_approx(float(actual), float(expected[key])):
				failures.append("%s 的 %s 应为 %s，实际 %s" % [
					type_name, key, str(expected[key]), str(actual)
				])


func _check_boss_type_judgement():
	for type_name in VARIANT_STATS:
		if not _judge(type_name, "is_boss_type"):
			failures.append("%s 应被判为 Boss 类型" % type_name)
		if not _judge(type_name, "uses_boss_behavior"):
			failures.append("%s 应使用 Boss 行为（阶段 / 血条 / 不回池）" % type_name)
	# 基础 Boss 仍要覆盖
	if not _judge("boss", "is_boss_type"):
		failures.append("基础 boss 应被判为 Boss 类型")
	# 小 Boss 使用 Boss 行为但不属于 Boss 类型（它有自己的池化与血条路径）
	if _judge("miniboss", "is_boss_type"):
		failures.append("miniboss 不应被判为 Boss 类型")
	if not _judge("miniboss", "uses_boss_behavior"):
		failures.append("miniboss 应使用 Boss 行为")
	for type_name in ["normal", "elite", "tank"]:
		if _judge(type_name, "is_boss_type") or _judge(type_name, "uses_boss_behavior"):
			failures.append("%s 不应被卷入 Boss 判据" % type_name)
	# 元素映射：只有变体带元素，基础 Boss / 小 Boss 不带
	for type_name in VARIANT_ELEMENTS:
		if _judge_element(type_name) != VARIANT_ELEMENTS[type_name]:
			failures.append("%s 的弹幕元素应为 %s，实际「%s」" % [
				type_name, VARIANT_ELEMENTS[type_name], _judge_element(type_name)
			])
	for type_name in ["boss", "miniboss"]:
		if _judge_element(type_name) != "":
			failures.append("%s 不应携带弹幕元素，实际「%s」" % [type_name, _judge_element(type_name)])


func _check_wave_table_rotation():
	for wave_num in EXPECTED_BOSS_ROTATION:
		var expected := str(EXPECTED_BOSS_ROTATION[wave_num])
		var actual := str(wave_manager.call("get_boss_type", wave_num))
		if actual != expected:
			failures.append("第 %d 波的 Boss 应为 %s，实际 %s" % [wave_num, expected, actual])
		if not enemy_types.has(actual):
			failures.append("第 %d 波的 Boss %s 在 ENEMY_TYPES 中不存在" % [wave_num, actual])
	# 三个 Boss 波必须各不相同（否则「轮换」形同虚设）
	var seen: Dictionary = {}
	for wave_num in EXPECTED_BOSS_ROTATION:
		var boss := str(wave_manager.call("get_boss_type", wave_num))
		if seen.has(boss):
			failures.append("第 %d 波与第 %d 波使用了同一个 Boss: %s" % [wave_num, int(seen[boss]), boss])
		seen[boss] = wave_num
	# 终局双 Boss 仍是基础 Boss（均衡型）—— 与数据文件的说明保持一致
	var final_boss := str(wave_manager.call("get_boss_type", 20))
	if final_boss != "boss":
		failures.append("第 20 波应为均衡型基础 boss，实际 %s" % final_boss)


func _judge(type_name: String, method_name: String) -> bool:
	var enemy = _make_enemy(type_name)
	if enemy == null:
		return false
	var result := bool(enemy.call(method_name))
	enemy.free()
	return result


func _judge_element(type_name: String) -> String:
	var enemy = _make_enemy(type_name)
	if enemy == null:
		return "<造不出敌人>"
	var result := str(enemy.call("bullet_element"))
	enemy.free()
	return result


# ─── B. 弹幕元素 ───

func _check_bullet_element_and_color():
	var scene = load("res://scenes/EnemyBullet.tscn")
	for element in VARIANT_ELEMENTS.values():
		var bullet = scene.instantiate()
		root.add_child(bullet)
		bullet.activate(Vector2.ZERO, Vector2.RIGHT, str(element))
		if str(bullet.element) != str(element):
			failures.append("activate(element=%s) 后 bullet.element 为「%s」" % [
				str(element), str(bullet.element)
			])
		var expected_color = bullet.ELEMENT_COLORS.get(str(element))
		if bullet.get_node("Body").color != expected_color:
			failures.append("元素 %s 的子弹颜色应为 %s，实际 %s" % [
				str(element), str(expected_color), str(bullet.get_node("Body").color)
			])
		bullet.free()


func _check_pool_reuse_does_not_leak_element():
	# 池化对象不能把上一轮的元素带出去（本项目被池内残留状态坑过）
	var bullet = load("res://scenes/EnemyBullet.tscn").instantiate()
	root.add_child(bullet)
	bullet.activate(Vector2.ZERO, Vector2.RIGHT, "fire")
	bullet._return_to_pool()
	if str(bullet.element) != "":
		failures.append("归还池后仍残留元素「%s」" % str(bullet.element))
	bullet.activate(Vector2.ZERO, Vector2.RIGHT)
	if str(bullet.element) != "":
		failures.append("无元素激活后 bullet.element 应为空，实际「%s」" % str(bullet.element))
	if bullet.get_node("Body").color != bullet.DEFAULT_ELEMENT_COLOR:
		failures.append("无元素子弹应回到默认颜色，实际 %s" % str(bullet.get_node("Body").color))
	bullet.free()


func _check_boss_volley_carries_element():
	# 走真实射击路径（不直接调 _shoot_spread 传参，否则等于在验证我自己传的参数）
	var boss = wave_manager.call("spawn_boss", "boss_fire", Vector2.ZERO)
	if boss == null or not is_instance_valid(boss):
		failures.append("spawn_boss 未能生成 boss_fire")
		return
	# ⚠ 必须摆在屏幕内、且必须在同一个物理帧里检查：
	# EnemyBullet 跑出屏幕边界会立刻归还池（visible = false），
	# 若把 Boss 放到屏幕外再 await 一帧，子弹会在第一次 _process 就被回收 ——
	# 症状是「报告没开火」，其实是开火了又被自己回收了。
	boss.position = Vector2(640, 120)
	boss.shoot_timer = 0.0
	boss.contact_timer = 9999.0
	boss._physics_process(0.016)

	var fired: Array = []
	for bullet in main.enemy_bullet_pool:
		if is_instance_valid(bullet) and bullet.visible:
			fired.append(bullet)
	if fired.is_empty():
		failures.append("boss_fire 开火后没有可见的敌方子弹")
	else:
		for bullet in fired:
			if str(bullet.element) != "fire":
				failures.append("boss_fire 的弹幕元素应为 fire，实际「%s」" % str(bullet.element))
				break
		for bullet in fired:
			bullet._return_to_pool()
	if is_instance_valid(boss):
		boss.free()
	await process_frame


# ─── C. 阶段差异化 ───

func _check_phase_speed_differentiation():
	var mults: Dictionary = {}
	for type_name in VARIANT_STATS:
		var enemy = _make_enemy(type_name)
		if enemy == null:
			continue
		# 直接验证接线：把 phase 设为目标值后触发阶段切换，观察 base_speed 的倍数
		var before := float(enemy.base_speed)
		enemy.phase = 1
		enemy._on_phase_change()
		var after := float(enemy.base_speed)
		var ratio := after / before if before > 0.0 else 0.0
		mults[type_name] = ratio
		var expected := float(enemy.PHASE1_SPEED_MULT[type_name])
		if not is_equal_approx(ratio, expected):
			failures.append("%s 的阶段1速度倍率应为 %.2f，实际 %.3f" % [type_name, expected, ratio])
		# 阶段2 在阶段1 之上再乘一次
		var before2 := float(enemy.base_speed)
		enemy.phase = 2
		enemy._on_phase_change()
		var ratio2 := float(enemy.base_speed) / before2 if before2 > 0.0 else 0.0
		var expected2 := float(enemy.PHASE2_SPEED_MULT[type_name])
		if not is_equal_approx(ratio2, expected2):
			failures.append("%s 的阶段2速度倍率应为 %.2f，实际 %.3f" % [type_name, expected2, ratio2])
		enemy.free()
	# 三种变体的倍率必须互不相同，否则「差异化」只是个字段
	var distinct: Dictionary = {}
	for type_name in mults:
		distinct[snappedf(float(mults[type_name]), 0.001)] = true
	if distinct.size() != mults.size():
		failures.append("三个元素 Boss 的阶段速度倍率完全相同，阶段差异化没有实际效果")
	# 雷电最快、冰霜最慢（与设计文档的定位一致）
	if mults.has("boss_lightning") and mults.has("boss_frost"):
		if not (float(mults["boss_lightning"]) > float(mults["boss_frost"])):
			failures.append("雷电 Boss 的阶段加速应高于冰霜 Boss")


# ─── D. 命中效果与「只在伤害落地后施加」 ───

func _check_element_landing_gate():
	var status = player.status
	if status == null:
		failures.append("player 缺少 status 模块")
		return

	# 1) 无敌帧挡下的命中不得附带 debuff
	_reset_player_state()
	player.take_damage(1, "fire")
	if not status.is_burning():
		failures.append("第一发 fire 命中后应处于燃烧状态")
	else:
		player.invincible_timer = player.INVINCIBLE_TIME
		player.take_damage(1, "frost")
		if status.is_slowed():
			failures.append("无敌帧内的命中不应附加减速")

	# 2) 闪避掉的命中不得附带 debuff
	_reset_player_state()
	player.invincible_timer = 0.0
	player.dodge_chance = 1.0
	player.take_damage(1, "lightning")
	if status.is_stunned():
		failures.append("被闪避的命中不应附加眩晕")
	player.dodge_chance = 0.0

	# 3) 免伤（nullify）挡下的命中不得附带 debuff
	_reset_player_state()
	player.invincible_timer = 0.0
	player.nullify_hits_remaining = 1
	player.take_damage(1, "frost")
	if status.is_slowed():
		failures.append("被免伤挡下的命中不应附加减速")
	player.nullify_hits_remaining = 0

	_reset_player_state()


func _check_status_semantics():
	var status = player.status
	if status == null:
		return

	# 燃烧：刷新时长，不叠伤害
	_reset_player_state()
	status.apply_burn(2.0, 1.0, 1)
	status.apply_burn(2.0, 1.0, 1)
	if int(status.burn_tick_damage) != 1:
		failures.append("重复燃烧不应叠加伤害，实际每跳 %d" % int(status.burn_tick_damage))
	if float(status.burn_timer) > 2.0 + 0.001:
		failures.append("重复燃烧不应叠加时长，实际 %.2f" % float(status.burn_timer))

	# 燃烧伤害确实会掉血
	_reset_player_state()
	var hp_before := int(player.hp)
	status.apply_burn(2.0, 0.25, 1)
	var elapsed := 0.0
	while elapsed < 1.0:
		status.process(0.05)
		elapsed += 0.05
	if int(player.hp) >= hp_before:
		failures.append("燃烧在 1 秒内应至少造成 1 点伤害（前 %d，后 %d）" % [hp_before, int(player.hp)])

	# 减速：取更强者，不叠成「动不了」
	_reset_player_state()
	status.apply_slow(0.3, 2.0)
	var once := float(status.slow_factor)
	status.apply_slow(0.3, 2.0)
	if not is_equal_approx(float(status.slow_factor), once):
		failures.append("重复减速不应叠加，%.3f → %.3f" % [once, float(status.slow_factor)])
	if float(status.slow_factor) <= 0.0:
		failures.append("减速不应把移动速度压到 0（那等于眩晕）")

	# 眩晕：带冷却，冷却期内不再被眩晕
	_reset_player_state()
	if not status.apply_stun(0.3):
		failures.append("首次眩晕应生效")
	var t := 0.0
	while t < 0.4:
		status.process(0.05)
		t += 0.05
	if float(status.stun_timer) > 0.0:
		failures.append("眩晕应在 0.3 秒后结束，实际剩余 %.2f" % float(status.stun_timer))
	if float(status.stun_cooldown) <= 0.0:
		failures.append("眩晕结束后应进入冷却")
	if status.apply_stun(0.3):
		failures.append("冷却期内的眩晕应被拒绝")

	# 移动乘数：眩晕必须为 0，减速必须小于 1
	_reset_player_state()
	status.apply_slow(0.3, 2.0)
	if not (float(status.speed_multiplier()) < 1.0):
		failures.append("减速状态下移动乘数应小于 1，实际 %.3f" % float(status.speed_multiplier()))
	_reset_player_state()
	status.apply_stun(0.3)
	if not is_equal_approx(float(status.speed_multiplier()), 0.0):
		failures.append("眩晕状态下移动乘数应为 0，实际 %.3f" % float(status.speed_multiplier()))

	_reset_player_state()


# ─── F. 眩晕定量门 ───

func _check_stun_uptime_bound():
	var status = player.status

	# 1) 眩晕必须是「刷新」而不是「累加」。
	#    雷电 Boss 一轮 8 发弹幕；若连续命中能延长眩晕，一轮就等于 2.4 秒失控。
	#    （注意：只断言「占比上限」是抓不住这个的 —— 占比由 STUN_DURATION / 命中间隔
	#    决定，累加只有在同一时刻叠满才会推高占比，所以必须单独断言语义。）
	_reset_player_state()
	status.stun_cooldown = 0.0
	status.stun_timer = 0.25
	status.apply_stun(0.3)
	if float(status.stun_timer) > 0.3 + 0.001:
		failures.append("眩晕应刷新而不是累加：剩余 0.25 + 施加 0.3 → %.2f" % float(status.stun_timer))

	# 2) 连续弹幕下的失控占比与最长连续失控时长
	_reset_player_state()
	var dt := 0.05
	var steps := 400            # 20 秒
	var volley_interval := 1.0  # 雷电 Boss 阶段1的射击间隔（比默认 1.8 更密）
	var volley_size := 8        # 阶段1 的扇形弹数量
	var since_volley := 0.0
	var stunned_steps := 0
	var run := 0
	var longest_run := 0
	# 20 秒 × 每秒一轮会打死只有个位数 HP 的玩家；这里测的是失控占比不是生存能力
	var hp_backup := int(player.hp)
	var max_hp_backup := int(player.max_hp)
	player.max_hp = 500
	player.hp = 500
	for i in range(steps):
		# 无敌帧计时必须一起推进，否则一轮里只有第 1 发能落地，测不到真实压力
		player.core.process_invincibility(dt)
		since_volley += dt
		if since_volley >= volley_interval:
			since_volley = 0.0
			for b in range(volley_size):
				player.take_damage(1, "lightning")
		status.process(dt)
		if status.is_stunned():
			stunned_steps += 1
			run += 1
			longest_run = max(longest_run, run)
		else:
			run = 0
	var uptime := float(stunned_steps) / float(steps)
	if uptime > MAX_STUN_UPTIME:
		failures.append("雷电弹幕下眩晕占比 %.1f%% 超过上限 %.0f%%（会被弹幕锁死）" % [
			uptime * 100.0, MAX_STUN_UPTIME * 100.0
		])
	if stunned_steps == 0:
		failures.append("雷电弹幕 20 秒内一次眩晕都没触发，元素效果可能没接上")
	# 最长连续失控不得超过「单次眩晕时长 + 一个 tick」——
	# 一旦有人把眩晕改成可叠加 / 可延长，这条立刻报红
	var longest_seconds := float(longest_run) * dt
	if longest_seconds > float(status.STUN_DURATION) + dt + 0.001:
		failures.append("最长连续失控 %.2fs 超过单次眩晕时长 %.2fs（眩晕被延长了）" % [
			longest_seconds, float(status.STUN_DURATION)
		])
	player.max_hp = max_hp_backup
	player.hp = min(hp_backup, max_hp_backup)
	_reset_player_state()


# ─── G. 波末清理与接线存在性 ───

func _check_wave_reset_clears_status():
	_reset_player_state()
	var status = player.status
	status.apply_burn(3.0, 1.0, 1)
	status.apply_slow(0.3, 3.0)
	status.apply_stun(0.3)
	player.on_wave_start(2)
	if status.is_burning() or status.is_slowed() or status.is_stunned():
		failures.append("波次开始后元素状态应被清空（不应带进下一波）")
	if not is_equal_approx(float(status.speed_multiplier()), 1.0):
		failures.append("清空后移动乘数应回到 1.0，实际 %.3f" % float(status.speed_multiplier()))


func _check_movement_hook_wired():
	# status.speed_multiplier() 只有被移动逻辑真正读取才算生效。
	# 这里没有键盘输入可造，所以退一步做「接线存在性」检查：
	# 一旦有人删掉 process_movement 里的那次调用，本条立刻报红。
	var file = FileAccess.open("res://scripts/PlayerCore.gd", FileAccess.READ)
	if file == null:
		failures.append("读不到 PlayerCore.gd")
		return
	var text = file.get_as_text()
	file.close()
	if not text.contains("status_speed_multiplier()"):
		failures.append("PlayerCore.process_movement 未读取 status_speed_multiplier()（减速/眩晕不会影响移动）")


# ─── 工具 ───

func _make_enemy(type_name: String):
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	# 挂在 Main 下而不是 root：Enemy 的弹幕走 get_parent()，挂 Main 才会命中对象池，
	# 否则每次阶段切换都会往 root 里堆一批不成池的子弹。
	main.add_child(enemy)
	enemy.setup(type_name, 1)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	return enemy


func _reset_player_state():
	player.status.clear()
	player.invincible_timer = 0.0
	player.dodge_chance = 0.0
	player.nullify_hits_remaining = 0
	if int(player.hp) <= 0:
		player.hp = int(player.max_hp)


func _cleanup_enemies():
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.free()
	for bullet in main.enemy_bullet_pool:
		if is_instance_valid(bullet):
			bullet._return_to_pool()
