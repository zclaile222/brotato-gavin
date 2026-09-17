extends SceneTree

# 敌人缓存「构建之后才被释放」的崩溃回归测试（2026-09-17）
#
# ── 现场 ──
# 玩家反馈「打 Boss 战的时候闪退了」。godot.log 里是一条**运行时**错误（不是语法错误）：
#   SCRIPT ERROR: Invalid access to property or key 'position' on a base object of type 'previously freed'.
#      at: PlayerCombat.fire_weapon (res://scripts/PlayerCombat.gd:576)
#      GDScript backtrace:
#          [0] fire_weapon (PlayerCombat.gd:576)
#          [1] process_weapons (PlayerCombat.gd:475)
#          [2] _physics_process (Player.gd:556)
#
# ── 根因：两条既有机制叠加 ──
#   ① `_refresh_enemy_cache()` 开头有 0.1s 节流 —— 缓存是**快照**，不是实时视图。
#      构建时确实做了 is_instance_valid 过滤，但那只能保证「构建那一刻有效」。
#   ② `Enemy.die()` 按类型分叉（Enemy.gd:776-785）：
#         Boss/miniboss → queue_free()   ← 帧末**真释放**，引用随之失效
#         普通敌人      → recycle()      ← 回收到池，引用永远有效
# 于是：打死 Boss → 缓存里那份引用下一帧变成 "previously freed" → 下次开火读 .position 即崩。
#
# ⚠️ **这正是「为什么只有 Boss 战会崩」的解释**：普通敌人走池化、永远不会被释放，
#    所以普通战斗怎么打都复现不了。设计回归测试时必须走 Boss 路径，否则测不到。
#
# ── 本套件固定四件事 ──
#   ① 走**真实死亡路径**（Boss take_damage → die → queue_free）造出「缓存握着已释放引用」
#   ② 此时开火不再中断函数，且失效引用被就地剪掉
#   ③ 反向：有效敌人**不能**被连坐剪掉，且仍要能开火（防止过滤过头导致「玩家不开火」）
#   ④ 缓存里全是失效引用时提前返回、不开火
#
# ── 关于「不崩」怎么断言 ──
# Godot 的脚本错误**不可捕获**（不抛异常），所以无法 `try/catch`。
# 但它的后果是可观测的：属性访问失败会**中断 fire_weapon**，于是剪枝根本不会发生。
# 因此核心断言落在「调用后缓存里的失效引用数量」上 ——
# 修复前该断言必然失败，且失败报文会指向输出里那条 SCRIPT ERROR。

const PASS_TAG := "COMBAT_STALE_ENEMY_REFERENCE_SMOKE_PASS"
const FAIL_TAG := "COMBAT_STALE_ENEMY_REFERENCE_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

var failures: Array[String] = []
var main = null
var player = null


func _init():
	call_deferred("_run")


func _run():
	seed(20260917)
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
	await physics_frame

	player = main.get("player")
	if player == null or not is_instance_valid(player):
		failures.append("Main 未解析出 player")
		_report()
		return
	_freeze_wave_spawning()

	await _check_boss_death_then_fire()
	await _check_valid_enemy_survives_pruning()
	_check_all_stale_returns_early()
	_check_helper_only_prunes_invalid()

	_cleanup()
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
	var wm = main.get("wave_manager")
	if wm == null:
		return
	wm.spawn_timer = 9999.0
	wm.tree_spawn_timer = 9999.0
	wm.landmine_spawn_timer = 9999.0
	wm.wave_timer = 9999.0


func _make_enemy(type_name: String, at: Vector2):
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	main.add_child(enemy)
	enemy.setup(type_name, 1)
	enemy.global_position = at
	enemy.set_physics_process(false)
	enemy.set_process(false)
	return enemy


func _cached_enemies() -> Array:
	return player.combat.get("_cached_enemies")


# 传一个大于节流阈值(0.1s)的 delta 强制重建缓存
func _force_cache_refresh():
	player.combat._refresh_enemy_cache(1.0)


# 等敌人真的进入探测缓存。
# ⚠ 不要「固定等 2 帧」：DetectArea 的物理重叠要若干帧才稳定，帧数在 headless 下不稳定，
#   固定帧数会让前置条件偶发失败、把测试变成 flaky（本项目在 §10.2 栽过一次同类问题）。
#   改用轮询 —— 成功即返回，失败时由调用方打印现场。
func _await_in_cache(enemy, max_frames: int = 30) -> bool:
	for i in range(max_frames):
		await physics_frame
		_force_cache_refresh()
		if _cached_enemies().has(enemy):
			return true
	return false


# 前置条件失败时把现场打出来 —— 否则「未进缓存」这句话无法自己解释原因
func _cache_scene() -> String:
	var parts: Array[String] = []
	parts.append("cache=%d" % _cached_enemies().size())
	parts.append("player=%s" % str(player.global_position))
	parts.append("combat=%s" % str(main.is_combat_phase()))
	var det = player.get_node_or_null("DetectArea")
	if det != null:
		parts.append("detect_pos=%s" % str(det.global_position))
		parts.append("detect_monitoring=%s" % str(det.monitoring))
		var shape = det.get_node_or_null("CollisionShape2D")
		if shape != null and shape.shape is CircleShape2D:
			parts.append("detect_radius=%.0f" % shape.shape.radius)
	parts.append("enemies_in_group=%d" % get_nodes_in_group("enemies").size())
	return " ".join(parts)


func _first_weapon():
	if player.equipped_weapons.is_empty():
		return null
	return player.equipped_weapons[0]


# 用武器自己的 shots_fired 计数判断「是否真的走到了开火」。
# 它自增的位置在 `nearest == null` 早退之后、近战/远程分叉之前，
# 所以对两类武器都成立（见 PlayerCombat.fire_weapon）。
func _shots_fired_total() -> int:
	var states = player.combat.get("_weapon_state")
	if not (states is Dictionary):
		return 0
	var total: int = 0
	for key in states:
		var state = states[key]
		if state is Dictionary:
			total += int(state.get("shots_fired", 0))
	return total


# ─── ① 走真实 Boss 死亡路径：打死 Boss 之后开火 ───

func _check_boss_death_then_fire():
	var weapon = _first_weapon()
	if weapon == null:
		failures.append("玩家没有武器，无法验证开火（测试会空转）")
		return

	var boss = _make_enemy("boss", player.global_position + Vector2(60, 0))
	if not await _await_in_cache(boss):
		failures.append("前置失败：Boss 未被探测进缓存，本检查会空转｜现场: %s" % _cache_scene())
		if is_instance_valid(boss):
			boss.free()
		return
	if not boss.uses_boss_behavior():
		failures.append("前置失败：boss 未走 Boss 行为分支 —— 它不会被 queue_free，复现不了原缺陷")
		if is_instance_valid(boss):
			boss.free()
		return

	var n_before: int = _cached_enemies().size()

	# 走真实死亡路径：hp 归零 → die() → uses_boss_behavior() → queue_free()
	boss.hp = 1
	boss.take_damage(9999)
	# queue_free 在帧末落地，必须真的等一帧，否则 is_instance_valid 仍为 true
	await process_frame

	if is_instance_valid(boss):
		failures.append("前置失败：queue_free 之后实例仍有效，造不出「构建之后才被释放」的状态")
		return

	var n_after_death: int = _cached_enemies().size()
	if n_after_death != n_before:
		# 缓存若在此期间被重建，本检查就退化成「测了个空」
		failures.append("前置失败：Boss 死后缓存已被重建（节流未生效），复现不了原缺陷（%d → %d）" % [
			n_before, n_after_death
		])
		return

	# ⬇ 修复前：这里读 .position 会抛 previously freed 并**中断 fire_weapon**
	var shots_before: int = _shots_fired_total()
	player.combat.fire_weapon(weapon)

	var n_after_fire: int = _cached_enemies().size()
	if n_after_fire != n_before - 1:
		failures.append(
			"开火后缓存里仍留着已释放的引用（%d → %d，期望 %d）。"
			% [n_before, n_after_fire, n_before - 1]
			+ "很可能是 fire_weapon 在读 .position 时抛了 previously freed 并中断了函数 —— "
			+ "请检查本测试输出里是否有 SCRIPT ERROR。"
		)
	# 剪枝发生在函数最开头，即便随后因为没有有效目标而早退，计数也应已更新
	if _shots_fired_total() < shots_before:
		failures.append("shots_fired 不应回退（%d → %d）" % [shots_before, _shots_fired_total()])


# ─── ② 反向断言：有效敌人不能被连坐剪掉 ───

func _check_valid_enemy_survives_pruning():
	var weapon = _first_weapon()
	if weapon == null:
		return

	var keep = _make_enemy("normal", player.global_position + Vector2(45, 0))
	if not await _await_in_cache(keep):
		failures.append("前置失败：有效敌人未进缓存，反向断言会空转｜现场: %s" % _cache_scene())
		if is_instance_valid(keep):
			keep.free()
		return

	# 再加一个，然后把它真释放掉，制造「一有效 + 一失效」的混合缓存
	var doomed = _make_enemy("normal", player.global_position + Vector2(55, 0))
	if not await _await_in_cache(doomed):
		failures.append("前置失败：第二个敌人未进缓存，混合场景造不出来｜现场: %s" % _cache_scene())
		if is_instance_valid(keep):
			keep.free()
		if is_instance_valid(doomed):
			doomed.free()
		return
	var with_both: int = _cached_enemies().size()
	doomed.free()

	var shots_before: int = _shots_fired_total()
	player.combat.fire_weapon(weapon)

	if _cached_enemies().size() != with_both - 1:
		failures.append("混合缓存里应只剪掉失效那一个（%d → %d，期望 %d）" % [
			with_both, _cached_enemies().size(), with_both - 1
		])
	if not _cached_enemies().has(keep):
		failures.append("有效敌人被连坐剪掉了 —— 过滤过头会让玩家在有敌人时也不开火")
	if _shots_fired_total() <= shots_before:
		failures.append("缓存里有有效敌人却没开火（过滤过头的典型症状）")

	if is_instance_valid(keep):
		keep.free()


# ─── ③ 全是失效引用时不应开火 ───

func _check_all_stale_returns_early():
	var weapon = _first_weapon()
	if weapon == null:
		return

	var only = _make_enemy("normal", player.global_position + Vector2(50, 0))
	if not await _await_in_cache(only):
		failures.append("前置失败：敌人未进缓存，「全失效」检查会空转｜现场: %s" % _cache_scene())
		if is_instance_valid(only):
			only.free()
		return

	# 立即释放（不 await），保证缓存仍是那一份含失效引用的快照
	only.free()
	if is_instance_valid(only):
		failures.append("前置失败：free() 之后实例仍有效")
		return

	var shots_before: int = _shots_fired_total()
	player.combat.fire_weapon(weapon)

	if _shots_fired_total() != shots_before:
		failures.append("缓存里只有已释放引用时不应开火（shots %d → %d）" % [
			shots_before, _shots_fired_total()
		])
	if not _cached_enemies().is_empty():
		failures.append("已释放的引用应被剪掉，缓存应清空（实际还有 %d 项）" % _cached_enemies().size())


# ─── ④ 助手本身：只剪失效、不动有效、且幂等 ───

func _check_helper_only_prunes_invalid():
	var a = _make_enemy("normal", player.global_position + Vector2(300, 0))
	var b = _make_enemy("normal", player.global_position + Vector2(340, 0))
	if not await _await_in_cache(a):
		failures.append("前置失败：敌人 a 未进缓存，助手检查会空转｜现场: %s" % _cache_scene())
		for e in [a, b]:
			if is_instance_valid(e):
				e.free()
		return
	if not await _await_in_cache(b):
		failures.append("前置失败：敌人 b 未进缓存，助手检查会空转｜现场: %s" % _cache_scene())
		for e in [a, b]:
			if is_instance_valid(e):
				e.free()
		return

	var before: int = _cached_enemies().size()
	if _cached_enemies().is_empty():
		failures.append("前置失败：缓存为空，助手检查会空转")
		for e in [a, b]:
			if is_instance_valid(e):
				e.free()
		return

	b.free()
	var live = player.combat._live_enemies()

	if live.size() != before - 1:
		failures.append("_live_enemies 应剪掉 1 项失效引用（%d → %d）" % [before, live.size()])
	if not live.has(a):
		failures.append("_live_enemies 误剪了有效敌人")
	# 幂等：再调一次不应继续变化
	var again = player.combat._live_enemies()
	if again.size() != live.size():
		failures.append("_live_enemies 不幂等（%d → %d）" % [live.size(), again.size()])

	if is_instance_valid(a):
		a.free()


# ─── 工具 ───

func _cleanup():
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.free()
	for enemy in get_nodes_in_group("neutral_trees"):
		if is_instance_valid(enemy):
			enemy.free()
	if is_instance_valid(main):
		main.queue_free()
	main = null
