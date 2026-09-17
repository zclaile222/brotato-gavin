extends SceneTree

# 战斗目标有效性冒烟测试（BUG1 / BUG2 / BUG3 / BUG5）
#
# 这四条其实互相咬在一起，根因集中在两处：
#   ① `DetectArea.get_overlapping_bodies()` 报的是**物理重叠**，与 `enemies` 分组无关，
#      而 `Enemy.recycle()` 只把池实例移出分组、**没关碰撞层** ——
#      于是池里的隐形实例照样被扫到：玩家会朝隐形尸体开火（看起来像「移动时无法射击」），
#      近战还能把 hp<=0 的池实例再打死一次、凭空掉经验。
#   ② 碰撞体半径原本是场景里写死的 18（正好等于旧视觉 32×32 方块的等面积圆半径），
#      换成精灵后视觉尺寸改为按贴图计算，两者脱节。
#
# 固定：
#   A. 池实例（隐形 / 已死 / 不在 enemies 组）既不能被瞄准，也不能被子弹伤害；
#   B. 活着且在组里的敌人必须能被扫到（反向断言，防止「过滤过头」）；
#   C. 非战斗阶段不开火，且波末会回收战场上的子弹；
#   D. 子弹能伤害中立材料树，但树不吃「敌人专属」副作用（击杀回调 / 吸血 / 总伤害）；
#   E. 碰撞半径由视觉反推，且每个实例持有自己的 Shape2D（不能共享 SubResource）。

const PASS_TAG := "COMBAT_TARGET_VALIDITY_SMOKE_PASS"
const FAIL_TAG := "COMBAT_TARGET_VALIDITY_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

var failures: Array[String] = []
var main = null
var player = null
var wave_manager = null


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
	await physics_frame

	player = main.get("player")
	wave_manager = main.get("wave_manager")
	if player == null or not is_instance_valid(player):
		failures.append("Main 未解析出 player")
		_report()
		return
	_freeze_wave_spawning()

	await _check_pooled_instances_are_not_targetable()
	await _check_live_enemy_is_targetable()
	_check_bullet_damages_tree()
	_check_tree_gets_no_enemy_side_effects()
	await _check_no_fire_outside_combat()
	_check_collision_matches_visual()
	_check_melee_reach_indicator()

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
	wave_manager.spawn_timer = 9999.0
	wave_manager.tree_spawn_timer = 9999.0
	wave_manager.landmine_spawn_timer = 9999.0
	wave_manager.wave_timer = 9999.0


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


func _force_cache_refresh():
	# 传一个大于阈值(0.1s)的 delta 强制刷新
	player.combat._refresh_enemy_cache(1.0)


# ─── A / B. 池实例不可被瞄准与伤害；活敌必须能被瞄准 ───

func _check_pooled_instances_are_not_targetable():
	var enemy = _make_enemy("normal", player.global_position)
	await physics_frame
	await physics_frame

	_force_cache_refresh()
	if not _cached_enemies().has(enemy):
		failures.append("活着且在 enemies 组里的敌人应当被探测到（否则后续断言会假通过）")

	# 回收 → 变成池里的隐形实例
	main.recycle_enemy(enemy)
	await physics_frame
	_force_cache_refresh()
	if _cached_enemies().has(enemy):
		failures.append("回收后的池实例仍然出现在战斗目标缓存里（会朝隐形尸体开火）")
	if enemy.is_in_group("enemies"):
		failures.append("回收后仍留在 enemies 组里")

	# 池实例也不能被子弹伤害
	var hp_before := int(enemy.hp)
	var bullet = _make_bullet()
	bullet._on_body_entered(enemy)
	if int(enemy.hp) != hp_before:
		failures.append("子弹打到了回收后的池实例（可见性/分组过滤失效）")

	# 已经 hp<=0 的实例同样不能再被「打死一次」——这正是凭空掉经验的来源
	enemy.visible = true
	enemy.hp = 0
	var hp_zero := int(enemy.hp)
	bullet._on_body_entered(enemy)
	if int(enemy.hp) != hp_zero:
		failures.append("子弹再次命中了 hp<=0 的实例（会重复触发死亡并掉落经验）")

	bullet.free()
	if is_instance_valid(enemy):
		enemy.free()


func _check_live_enemy_is_targetable():
	# 反向断言：过滤不能过头 —— 正常敌人必须仍可被扫到并被打伤
	var enemy = _make_enemy("normal", player.global_position)
	await physics_frame
	await physics_frame
	_force_cache_refresh()
	if not _cached_enemies().has(enemy):
		failures.append("正常敌人未被探测到 —— 过滤条件过严")

	var hp_before := int(enemy.hp)
	var bullet = _make_bullet()
	bullet._on_body_entered(enemy)
	if int(enemy.hp) >= hp_before:
		failures.append("子弹应当能打伤正常敌人（前 %d，后 %d）" % [hp_before, int(enemy.hp)])
	bullet.free()
	if is_instance_valid(enemy):
		enemy.free()


# ─── C. 非战斗阶段不开火 + 波末回收子弹 ───

func _check_no_fire_outside_combat():
	# 放一个敌人在玩家身边，保证「有目标」
	var enemy = _make_enemy("normal", player.global_position + Vector2(40, 0))
	await physics_frame

	# 先确认战斗中会开火（否则这条测试是空转）
	var fired_in_combat := await _count_bullets_fired_over(90)
	if fired_in_combat <= 0:
		# 把现场打出来，而不是只说「失败了」——否则这条断言无法自己解释原因
		failures.append("战斗阶段没有开火，无法验证「非战斗阶段不开火」（测试会空转）｜现场: %s" % _combat_state_summary())

	# 显式造两发「在场」子弹。只靠开火留下的子弹是不够的 ——
	# 它们可能在波末前就已经命中/飞出屏幕被回收，于是「波末回收子弹」这条断言会空转
	# （第一版就是这样漏掉了「没回收」的破坏）。
	var live_bullet = main.get_bullet()
	live_bullet.activate(player.global_position, Vector2.RIGHT, 400.0, Color(1, 1, 0.3), player, 1)
	var live_enemy_bullet = main.get_enemy_bullet()
	live_enemy_bullet.activate(player.global_position + Vector2(0, 60), Vector2.DOWN)
	if not live_bullet.visible or not live_enemy_bullet.visible:
		failures.append("造在场子弹失败，波末回收断言会空转")

	# 进入波末（走真实路径，顺带验证子弹回收）
	main._on_wave_ended()
	await process_frame
	if main.is_combat_phase():
		failures.append("波末之后不应仍处于战斗阶段")

	for b in main.bullet_pool:
		if is_instance_valid(b) and b.visible:
			failures.append("波末后仍有存活的玩家子弹未回收")
			break
	for b in main.enemy_bullet_pool:
		if is_instance_valid(b) and b.visible:
			failures.append("波末后仍有存活的敌方子弹未回收（会在商店阶段打到玩家）")
			break

	var fired_after := await _count_bullets_fired_over(90)
	if fired_after > 0:
		failures.append("非战斗阶段仍然开了 %d 发（波次结束后还在射击）" % fired_after)

	if is_instance_valid(enemy):
		enemy.free()


# 用武器自己的 `shots_fired` 计数，而不是「可见子弹数量差」——
# 后者会把基线里已经飞在空中、以及被回收的子弹算进去，
# 差值为 0 时无法区分「没开火」和「开了一发但上一发刚被回收」（我第一版就栽在这）。
func _shots_fired_total() -> int:
	# ⚠ 武器状态不在 weapon 字典里，而在 PlayerCombat._weapon_state（按 runtime_id 索引）——
	# 第一版读 weapon["state"] 永远得 0，于是「没开火」的断言假报。
	var states = player.combat.get("_weapon_state")
	if not (states is Dictionary):
		return 0
	var total := 0
	for key in states:
		var state = states[key]
		if state is Dictionary:
			total += int(state.get("shots_fired", 0))
	return total


func _combat_state_summary() -> String:
	var parts: Array[String] = []
	parts.append("combat_phase=%s" % str(main.is_combat_phase()))
	parts.append("weapons=%d" % player.equipped_weapons.size())
	parts.append("cache=%d" % _cached_enemies().size())
	var timers: Array[String] = []
	for weapon in player.equipped_weapons:
		timers.append("%s:t=%.2f range=%s" % [
			str(weapon.data.get("type", "?")),
			float(weapon.get("timer", 0.0)),
			str(weapon.data.get("range", "-")),
		])
	parts.append("[" + ", ".join(timers) + "]")
	return " ".join(parts)


func _count_bullets_fired_over(frames: int) -> int:
	var baseline := _shots_fired_total()
	for i in range(frames):
		await physics_frame
	return maxi(0, _shots_fired_total() - baseline)


# ─── D. 树可被伤害，但不吃敌人专属副作用 ───

func _check_bullet_damages_tree():
	var tree = _make_enemy("tree", player.global_position + Vector2(200, 0))
	if not tree.is_in_group("neutral_trees"):
		failures.append("材料树应在 neutral_trees 分组里")
	var hp_before := int(tree.hp)
	var bullet = _make_bullet()
	bullet.damage = 1
	bullet._on_body_entered(tree)
	if int(tree.hp) >= hp_before:
		failures.append("子弹应当能伤害材料树（前 %d，后 %d）—— 分组过滤把树挡掉了" % [
			hp_before, int(tree.hp)
		])
	bullet.free()
	if is_instance_valid(tree):
		tree.free()


func _check_tree_gets_no_enemy_side_effects():
	var tree = _make_enemy("tree", player.global_position + Vector2(240, 0))
	var damage_before := float(player.total_damage_dealt)
	var bullet = _make_bullet()
	bullet.shooter = player
	bullet.damage = 1
	bullet._on_body_entered(tree)
	if float(player.total_damage_dealt) > damage_before:
		failures.append("打中立树被计入了「总伤害」统计")
	bullet.free()
	if is_instance_valid(tree):
		tree.free()


# ─── E. 碰撞半径由视觉反推，且各实例独立 ───

func _check_collision_matches_visual():
	var expected := UnitVisual.visual_radius("normal")
	if expected <= 0.0:
		failures.append("normal 的视觉等效半径应大于 0")
	var a = _make_enemy("normal", player.global_position + Vector2(300, 0))
	var b = _make_enemy("normal", player.global_position + Vector2(360, 0))
	var shape_a = a.get_node("CollisionShape2D").shape
	var shape_b = b.get_node("CollisionShape2D").shape
	if shape_a == shape_b:
		failures.append("两个敌人共享了同一个 Shape2D —— 改一个会污染全部（必须实例化自己的）")
	if shape_a is CircleShape2D and absf(shape_a.radius - expected) > 0.01:
		failures.append("normal 的碰撞半径应为视觉等效半径 %.2f，实际 %.2f" % [
			expected, shape_a.radius
		])
	var contact = a.get_node("ContactArea/CollisionShape2D").shape
	if contact is CircleShape2D and contact.radius < expected:
		failures.append("接触伤害范围(%.2f)小于可见身体(%.2f) —— 会出现「看着碰到了却不掉血」" % [
			contact.radius, expected
		])
	# 不同体型的敌人应当得到不同的碰撞半径
	var big = _make_enemy("tank", player.global_position + Vector2(420, 0))
	if big.get_node("CollisionShape2D").shape.radius <= shape_a.radius:
		failures.append("tank 的碰撞半径应大于 normal（体型更大）")
	for e in [a, b, big]:
		if is_instance_valid(e):
			e.free()


# ─── F. 近战范围环 ───

func _check_melee_reach_indicator():
	player.set_melee_reach(0.0)
	if player._melee_reach != null and player._melee_reach.visible:
		failures.append("没有近战武器时范围环应当隐藏")
	player.set_melee_reach(80.0)
	if player._melee_reach == null or not player._melee_reach.visible:
		failures.append("设置近战范围后范围环应当显示")
	elif player._melee_reach.points.size() < 3:
		failures.append("范围环应当是一圈可读的折线")
	else:
		# points[i] 是 Variant，用 := 会被判为无法推断（本项目把该警告当错误）
		var r: float = player._melee_reach.points[0].length()
		if absf(r - 80.0) > 0.5:
			failures.append("范围环半径应为 80，实际 %.1f" % r)
	# 挥击弧：亮起并可见
	player.show_melee_swing(80.0, Color(1, 1, 1), Vector2.RIGHT, false)
	if player._melee_swing == null or not player._melee_swing.visible:
		failures.append("挥击时应当出现挥击弧（否则看不出攻击频率）")
	# 没有近战武器时，指示器更新应能正常执行（返回 void，只看不崩）
	player.combat.call("update_melee_indicator")
	player.set_melee_reach(0.0)


# ─── 工具 ───

# ⚠ 必须 activate()：`_ready()` 里池化初值是 visible = false，
# 而 `_on_body_entered` 第一行就是 `if not visible: return` ——
# 不激活的话下面所有「子弹伤害」断言都会静默通过（空转）。
func _make_bullet(damage: int = 1):
	var bullet = load("res://scenes/Bullet.tscn").instantiate()
	root.add_child(bullet)
	bullet.activate(Vector2.ZERO, Vector2.RIGHT, 400.0, Color(1, 1, 0.3), player, damage)
	return bullet


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
