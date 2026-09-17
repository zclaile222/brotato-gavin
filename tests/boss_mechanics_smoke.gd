extends SceneTree

# 元素 Boss 独特机制冒烟测试（P4-5 的 P2）
#
# 依据 docs/boss-variants-design.md 的第 4/5/6 条优先级：
#   火焰 — 火焰冲锋 + 燃烧区域（BurnZone）+ 烈焰光环
#   冰霜 — 冰甲循环 + 冻结脉冲（1s 蓄力预警）
#   雷电 — 闪现传送 + 链式闪电 + 雷暴领域
#
# 本测试的写法约定（SKILL §5/§7⑦/§8.3.1）：
#   * 每条机制既有**正向断言**（它确实发生了），也有**反向断言**
#     （不该发生的时候确实没发生）—— 只有正向断言的测试可能恒真；
#   * 周期/间隔类机制一律带「不到间隔不应触发」的反向断言，
#     否则间隔参数是否生效根本没被验到；
#   * 写「不应发生」之前先确认该对象在正确实现下确实不该发生
#     （例如普通子弹的 chain_remaining 恒为 0）。
#
# 注意：这些机制都跑在 Boss 的 _physics_process 里，测试手动调用它
# （先把 Boss 的 set_physics_process(false)），因此**计时器**的 delta 完全可控。
# ⚠ 但**位移**不受传入 delta 控制：move_and_slide() 内部用的是引擎固定步长
# （1/tick），所以「同步推 N 步」只推进 N × velocity / 60 的位移，与传入的
# 0.05 无关。这条正是「冲锋余量」的来源，见 DASH_MARGIN_MIN_RATIO 与
# _assert_dash_margin()：余量必须显式断言，否则退化时会变成随机红。

const PASS_TAG := "BOSS_MECHANICS_SMOKE_PASS"
const FAIL_TAG := "BOSS_MECHANICS_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

# 冲锋余量下限倍率：一次冲锋的总位移必须 ≥ BURN_ZONE_SPACING × 本值。
# 实测 20/20 次完全一致：位移 = 冲锋速度(456) × 引擎固定 tick 步长(1/60) × 9 步
# = 68.4px，而间距阈值 40px ⇒ 真实余量 1.71×。取 1.2 作下限（留 ~42% 抖动余量）：
# 一旦物理推进退化到吃进危险区，红灯落在「余量自检」这条明确断言上，
# 而不是让「冲锋路径应生成燃烧区域」变成一条读不出原因的随机红。
const DASH_MARGIN_MIN_RATIO := 1.2

# 与 Enemy.gd 的常量保持一致（这里只做断言用的期望值，取值来源是设计文档）
const FROST_ARMOR_REDUCTION := 30
const FREEZE_PULSE_STUN := 1.5
const STORM_DAMAGE := 3
const STORM_DELAY := 0.8
const BLINK_MIN_DIST := 100.0
const BLINK_MAX_DIST := 200.0
const BLINK_SPIRAL_P1 := 8
const CHAIN_BOUNCES_P1 := 2
const CHAIN_BOUNCES_P2 := 3

var failures: Array[String] = []
var main = null
var player = null
var wave_manager = null
var _spawned: Array = []


func _init():
	call_deferred("_run")


func _run():
	seed(20260916)
	var game_state = root.get_node("/root/GameState")
	game_state.selected_character = "normal"
	game_state.difficulty = 1
	game_state.endless_mode = false
	# ⚠ headless --script 模式下 root window 是 64×64（不是 project.godot 里的 1280×720）。
	# 项目里多处按 get_viewport_rect().size 做边界钳制（玩家移动、雷电 Boss 的闪现落点），
	# 在这个退化视口下钳制会把所有东西压到 64×64 的角落里，
	# 于是「玩家站在 (640,360) 的燃烧区域里」这类位置相关的断言全部假失败。
	# 显式把窗口尺寸置回设计分辨率，让测试跑在真实几何里。
	root.size = Vector2i(1280, 720)
	await process_frame
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
	if player.get("status") == null:
		failures.append("player 缺少 status 模块")
		_report()
		return
	_freeze_wave_spawning()

	await _check_fire_boss()
	_check_fire_boss_aura()
	_check_burn_zone_duration_and_radius()
	await _check_burn_zone_ignites_player()
	_check_frost_armor_cycle()
	_check_freeze_pulse()
	_check_lightning_blink()
	_check_chain_lightning()
	_check_storm_field()
	_check_no_cross_type_leak()

	_cleanup()
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


# ─── 火焰 Boss ───

func _check_fire_boss():
	var boss = _make_boss("boss_fire")
	boss.position = Vector2(200, 360)
	# 玩家必须先在物理服务器里就位，否则 Boss 的 move_and_slide 会撞在
	# 「玩家出生点 (427,325) 的旧实体」上，冲锋一步都走不动（详见 _place_player）
	await _place_player(Vector2(1000, 360))
	boss._fire_charge_timer = 0.0

	# 反向①：阶段0 不该有火焰冲锋（设计文档把它列为阶段1 的新机制）
	boss.phase = 0
	boss._physics_process(0.05)
	if boss._dash_timer > 0.0:
		failures.append("火焰 Boss 阶段0 不应冲锋，实际 _dash_timer=%.2f" % float(boss._dash_timer))
	if _count_burn_zones() > 0:
		failures.append("火焰 Boss 阶段0 不应生成燃烧区域")

	# 反向②：不到冲锋间隔不该冲锋（间隔参数是否生效的唯一证据）
	boss.phase = 1
	boss._fire_charge_timer = boss.FIRE_CHARGE_INTERVAL_P1
	boss._physics_process(0.1)
	if boss._dash_timer > 0.0:
		failures.append("不到冲锋间隔（%.1fs）不应冲锋" % float(boss.FIRE_CHARGE_INTERVAL_P1))
	if _count_burn_zones() > 0:
		failures.append("不到冲锋间隔不应生成燃烧区域，实际 %d 个" % _count_burn_zones())

	# 正向①：间隔到点后开始冲锋
	boss._fire_charge_timer = 0.0
	boss._physics_process(0.02)
	if boss._dash_timer <= 0.0:
		failures.append("阶段1 冲锋计时到点后应开始冲锋")
		return

	# 正向②：冲锋路径上按间距留下燃烧区域
	var steps := 0
	var last_hits := ""
	var pos_before_dash: Vector2 = boss.position
	while boss._dash_timer > 0.0 and steps < 20:
		boss._physics_process(0.05)
		last_hits = ""
		for i in range(boss.get_slide_collision_count()):
			var c = boss.get_slide_collision(i)
			last_hits += "%s@%s " % [c.get_collider().name, str(c.get_position())]
		steps += 1
	_assert_dash_margin(boss, "阶段1", pos_before_dash, steps)
	if _count_burn_zones() == 0:
		failures.append("火焰冲锋路径上应生成燃烧区域，实际 0 个（冲锋步数 %d，起点 %s，玩家 %s，速度 %s，方向 %s，基础速度 %.1f，减速 %.2f，眩晕 %.2f，冻结 %.2f，行进 %.1f，碰撞 %s）" % [
			steps, str(boss.position), str(player.position), str(boss.velocity), str(boss._dash_dir),
			float(boss.base_speed), float(boss._slow_factor), float(boss._stun_timer),
			float(boss.freeze_timer), float(boss._dash_travel), last_hits
		])
	else:
		var zone = _first_burn_zone()
		if zone != null and not is_equal_approx(float(zone.life_timer), float(boss.BURN_ZONE_DURATION_P1)):
			failures.append("阶段1 燃烧区域应持续 %.1fs，实际 %.2fs" % [
				float(boss.BURN_ZONE_DURATION_P1), float(zone.life_timer)
			])

	# 正向③：阶段2 的燃烧区域持续更久（间隔也更短）
	_clear_burn_zones()
	boss.phase = 2
	boss._dash_timer = 0.0
	boss._fire_charge_timer = 0.0
	boss._physics_process(0.02)
	steps = 0
	var pos_before_dash2: Vector2 = boss.position
	while boss._dash_timer > 0.0 and steps < 20:
		boss._physics_process(0.05)
		steps += 1
	_assert_dash_margin(boss, "阶段2", pos_before_dash2, steps)
	var zone2 = _first_burn_zone()
	if zone2 == null:
		failures.append("阶段2 冲锋路径上应生成燃烧区域，实际 0 个")
	elif not is_equal_approx(float(zone2.life_timer), float(boss.BURN_ZONE_DURATION_P2)):
		failures.append("阶段2 燃烧区域应持续 %.1fs，实际 %.2fs" % [
			float(boss.BURN_ZONE_DURATION_P2), float(zone2.life_timer)
		])
	_free_boss(boss)
	_clear_burn_zones()
	_clear_active_bullets()


func _check_fire_boss_aura():
	var boss = _make_boss("boss_fire")
	player.position = Vector2(640, 360)
	# 反向：阶段1 不该有烈焰光环
	boss.phase = 1
	boss.position = player.position + Vector2(40, 0)
	boss._aura_timer = 0.0
	_reset_player_status()
	boss._physics_process(0.016)
	if player.status.is_burning():
		failures.append("烈焰光环只属于阶段2，阶段1 近身不应点燃玩家")

	# 反向：阶段2 但距离超出光环半径，不该点燃
	boss.phase = 2
	boss.position = player.position + Vector2(300, 0)
	boss._aura_timer = 0.0
	_reset_player_status()
	boss._physics_process(0.016)
	if player.status.is_burning():
		failures.append("阶段2 距离 %.0fpx（> 光环半径 %.0f）不应点燃玩家" % [
			300.0, float(boss.FIRE_AURA_RADIUS)
		])

	# 正向：阶段2 近身持续点燃
	boss.position = player.position + Vector2(40, 0)
	boss._aura_timer = 0.0
	_reset_player_status()
	boss._physics_process(0.016)
	if not player.status.is_burning():
		failures.append("阶段2 近身（40px < %.0f）应点燃玩家" % float(boss.FIRE_AURA_RADIUS))
	_free_boss(boss)
	_clear_active_bullets()
	_reset_player_status()


# ─── 燃烧区域本身 ───

func _check_burn_zone_duration_and_radius():
	var zone = load("res://scenes/BurnZone.tscn").instantiate()
	main.add_child(zone)
	zone.activate(Vector2(200, 600), 1.0, 45.0)

	# 半径必须落到碰撞体与视觉上（改了半径但圈还是原来那么大 = 判定/显示脱节）
	var shape = zone.get_node("CollisionShape2D").shape
	if not is_equal_approx(float(shape.radius), 45.0):
		failures.append("燃烧区域半径应为 45，实际 %.1f" % float(shape.radius))
	if zone.get_node("Body").polygon.size() == 0:
		failures.append("燃烧区域视觉多边形不应为空")

	# 反向：不到持续时间不该消失
	zone._process(0.5)
	if zone.is_queued_for_deletion():
		failures.append("燃烧区域在 0.5s 时就消失了（持续时间 1.0s 未生效）")
	# 正向：超过持续时间应消失
	zone._process(0.6)
	if not zone.is_queued_for_deletion():
		failures.append("燃烧区域超过持续时间 1.0s 后应消失，但仍在场")
		if is_instance_valid(zone):
			zone.free()


# 用真实物理帧验证「玩家进入范围被点燃」，而不是直接调私有函数。
func _check_burn_zone_ignites_player():
	# 前面几段测试可能留下在飞的敌方子弹：它们命中玩家会附带燃烧/减速，
	# 会把这里的「是否燃烧」判据污染成假阳性。
	_clear_active_bullets()
	var zone = load("res://scenes/BurnZone.tscn").instantiate()
	main.add_child(zone)
	zone.activate(Vector2(640, 360), 60.0, 60.0)
	player.position = Vector2(640, 360)
	_reset_player_status()
	for i in range(4):
		await physics_frame
	if not player.status.is_burning():
		failures.append("玩家站在燃烧区域内（重叠）应被点燃，实际未燃烧")
	# 燃烧区域若提前消失，后面的重叠检查会直接报「previously freed」把测试打断，
	# 那就看不到真正的失败原因了 —— 先自己判一次，并说清是持续时间没生效。
	if not is_instance_valid(zone) or zone.is_queued_for_deletion():
		failures.append("燃烧区域在玩家站位期间就消失了（activate 的持续时间未生效）")
		return
	if zone.get_overlapping_bodies().size() == 0:
		failures.append("测试构造问题：玩家在 (640,360) 与燃烧区域重叠，但物理上报告 0 个重叠体")

	# 反向：玩家离开范围后不再被点燃。
	# ⚠ 两个前提缺一不可：
	#   ① 等物理步把「玩家已经离开」这件事同步给物理服务器 ——
	#      直接接着断言的话重叠列表还是旧的（残留重叠会把玩家又点着）；
	#   ② 清掉重新施加的节流计时，否则「没被点燃」只是节流挡住的假象，测不到东西。
	player.position = Vector2(300, 640)
	for i in range(3):
		await physics_frame
	if zone.get_overlapping_bodies().size() != 0:
		failures.append("测试构造问题：玩家已离开(300,640)，燃烧区域仍报告 %d 个重叠体" % zone.get_overlapping_bodies().size())
	_reset_player_status()
	zone._apply_timer = 0.0
	for i in range(3):
		await physics_frame
	if player.status.is_burning():
		failures.append("玩家离开燃烧区域（距离 %.0f > 半径 %.0f）后不应再被点燃" % [
			player.position.distance_to(zone.position), float(zone.radius)
		])
	zone._apply_timer = 0.0
	if is_instance_valid(zone) and not zone.is_queued_for_deletion():
		zone.free()


# ─── 冰霜 Boss ───

func _check_frost_armor_cycle():
	var boss = _make_boss("boss_frost")
	boss.phase = 1
	boss._on_element_phase_change()
	if int(boss.armor_value) != FROST_ARMOR_REDUCTION:
		failures.append("冰霜 Boss 阶段1 应获得冰甲（armor_value=%d），实际 %d" % [
			FROST_ARMOR_REDUCTION, int(boss.armor_value)
		])

	# 正向：冰甲生效时 10 点伤害只掉 7 点
	var hp_before := int(boss.hp)
	boss.take_damage(10)
	var taken := hp_before - int(boss.hp)
	if taken != 7:
		failures.append("冰甲 -%d%% 下 10 点伤害应只掉 7 点，实际 %d" % [FROST_ARMOR_REDUCTION, taken])

	# 反向：冰甲未激活时不应有任何减免（10 点伤害全额落地）
	boss._set_frost_armor(false)
	if int(boss.armor_value) != 0:
		failures.append("冰甲关闭后 armor_value 应为 0，实际 %d" % int(boss.armor_value))
	hp_before = int(boss.hp)
	boss.take_damage(10)
	taken = hp_before - int(boss.hp)
	if taken != 10:
		failures.append("冰甲未激活时 10 点伤害应全额，实际只掉 %d" % taken)

	# 循环：5s 开 → 4s 关
	boss._set_frost_armor(true)
	boss._process_frost_boss(4.0)
	if not boss._frost_armor_on:
		failures.append("冰甲应在获得后 %.1fs 内保持，4.0s 就没了" % float(boss.FROST_ARMOR_ON_TIME))
	boss._process_frost_boss(1.0)
	if boss._frost_armor_on:
		failures.append("冰甲应在 %.1fs 后消失" % float(boss.FROST_ARMOR_ON_TIME))
	if int(boss.armor_value) != 0:
		failures.append("冰甲消失后 armor_value 应为 0，实际 %d" % int(boss.armor_value))
	boss._process_frost_boss(3.9)
	if boss._frost_armor_on:
		failures.append("冰甲不应在 %.1fs 之前重新获得" % float(boss.FROST_ARMOR_OFF_TIME))
	boss._process_frost_boss(0.2)
	if not boss._frost_armor_on:
		failures.append("冰甲应在 %.1fs 后重新获得" % float(boss.FROST_ARMOR_OFF_TIME))

	# 阶段2：冰甲常驻
	boss.phase = 2
	boss._set_frost_armor(false)
	boss._process_frost_boss(20.0)
	if int(boss.armor_value) != FROST_ARMOR_REDUCTION:
		failures.append("冰霜 Boss 阶段2 冰甲应常驻，实际 armor_value=%d" % int(boss.armor_value))
	_free_boss(boss)


func _check_freeze_pulse():
	var boss = _make_boss("boss_frost")
	boss.position = Vector2(100, 100)
	player.position = Vector2(640, 360)
	boss.phase = 1
	# 反向：冻结脉冲只属于阶段2
	boss._freeze_pulse_timer = 0.0
	_reset_player_status()
	boss._physics_process(0.016)
	if player.status.is_stunned():
		failures.append("冰霜 Boss 阶段1 不应释放冻结脉冲")

	boss.phase = 2
	boss._freeze_pulse_timer = 0.0
	_reset_player_status()
	boss._physics_process(0.016)
	if float(boss._freeze_charge) <= 0.0:
		failures.append("阶段2 冻结脉冲计时到点后应进入蓄力状态")
		_free_boss(boss)
		return
	# ⚠ 反向断言的核心：蓄力（预警）期间绝不能施加冻结
	if player.status.is_stunned():
		failures.append("冻结脉冲蓄力期间不应施加冻结（玩家没有反应窗口了）")

	boss._physics_process(0.5)
	if not (float(boss._freeze_charge) > 0.0):
		failures.append("蓄力应在 %.1fs 后才结束，0.516s 就结束了" % float(boss.FREEZE_PULSE_CHARGE))
	if player.status.is_stunned():
		failures.append("蓄力未结束（剩余 %.2fs）时不应施加冻结" % float(boss._freeze_charge))

	# 正向：蓄力结束后爆发
	boss._physics_process(0.6)
	if not player.status.is_stunned():
		failures.append("冻结脉冲蓄力结束后应冻结（apply_stun）玩家")
	elif not is_equal_approx(float(player.status.stun_timer), FREEZE_PULSE_STUN):
		failures.append("冻结应持续 %.1fs，实际 %.2fs" % [FREEZE_PULSE_STUN, float(player.status.stun_timer)])

	# 反向：不到脉冲间隔不应有第二次
	player.status.clear()
	boss._physics_process(0.5)
	if player.status.is_stunned():
		failures.append("不到冻结脉冲间隔（%.1fs）不应再次冻结" % float(boss.FREEZE_PULSE_INTERVAL))
	_free_boss(boss)
	_clear_active_bullets()
	_reset_player_status()


# ─── 雷电 Boss ───

func _check_lightning_blink():
	var boss = _make_boss("boss_lightning")
	boss.position = Vector2(100, 100)
	player.position = Vector2(640, 360)
	boss.phase = 1
	boss._on_element_phase_change()
	_isolate_periodic_fire(boss)
	boss._blink_timer = boss.BLINK_INTERVAL_P1
	var dist_before: float = boss.position.distance_to(player.position)

	# 反向：不到闪现间隔不该瞬移（位置只会因追踪缓慢变化）
	boss._physics_process(0.1)
	var dist_after: float = boss.position.distance_to(player.position)
	if dist_after < 300.0:
		failures.append("不到闪现间隔（%.1fs）不该瞬移到玩家身边：距离 %.1f → %.1f" % [
			float(boss.BLINK_INTERVAL_P1), dist_before, dist_after
		])

	# 正向：间隔到点后瞬移到玩家周围 100–200px，并释放一圈雷弹
	boss._blink_timer = 0.0
	var bullets_before := _active_bullet_count()
	boss._physics_process(0.02)
	var blink_dist: float = boss.position.distance_to(player.position)
	if blink_dist < BLINK_MIN_DIST - 1.0 or blink_dist > BLINK_MAX_DIST + 1.0:
		failures.append("闪现落点应在 %.0f–%.0fpx，实际 %.1fpx" % [
			BLINK_MIN_DIST, BLINK_MAX_DIST, blink_dist
		])
	var spawned := _active_bullet_count() - bullets_before
	if spawned != BLINK_SPIRAL_P1:
		failures.append("阶段1 闪现应释放 %d 方向雷弹，实际新增 %d 发" % [BLINK_SPIRAL_P1, spawned])

	# 阶段2 闪现更密、雷弹更多
	boss.phase = 2
	_clear_active_bullets()
	boss._blink_timer = 0.0
	bullets_before = _active_bullet_count()
	boss._physics_process(0.02)
	spawned = _active_bullet_count() - bullets_before
	if spawned != int(boss.BLINK_SPIRAL_P2):
		failures.append("阶段2 闪现应释放 %d 方向雷弹，实际新增 %d 发" % [
			int(boss.BLINK_SPIRAL_P2), spawned
		])
	_free_boss(boss)


func _check_chain_lightning():
	var boss = _make_boss("boss_lightning")
	boss.position = Vector2(100, 100)
	player.position = Vector2(640, 360)
	boss.phase = 1
	_isolate_periodic_fire(boss)
	_clear_active_bullets()
	player.max_hp = 500
	player.hp = 500

	# 正向：阶段1 的链式闪电带 CHAIN_BOUNCES_P1 次弹射
	boss._chain_timer = 0.0
	boss._physics_process(0.02)
	var chained = _find_bullet_with_chain(CHAIN_BOUNCES_P1)
	if chained == null:
		failures.append("阶段1 应发射 1 发 chain_remaining=%d 的链式闪电" % CHAIN_BOUNCES_P1)

	# 反向：普通子弹（chain_remaining 恒为 0）命中后不弹射
	var plain = main.get_enemy_bullet()
	plain.activate(Vector2(600, 360), Vector2.RIGHT, "lightning")
	# 反向断言的前提：普通子弹的 chain_remaining 在正确实现下确实是 0
	if int(plain.chain_remaining) != 0:
		failures.append("未标记链式的子弹 chain_remaining 应为 0，实际 %d" % int(plain.chain_remaining))
	var before := _active_bullet_count()
	_reset_player_status()
	plain._on_body_entered(player)
	var after := _active_bullet_count()
	if after != before - 1:
		failures.append("普通子弹（chain=0）命中后不应弹射：可见子弹 %d → %d" % [before, after])

	if chained != null:
		# 正向：链会一跳一跳地打完，次数恰好等于 chain_remaining
		var hops := 0
		var guard := 0
		while guard < 10:
			guard += 1
			var hop = _find_bullet_with_chain_gt(0)
			if hop == null:
				break
			var remaining := int(hop.chain_remaining)
			_reset_player_status()
			player.invincible_timer = 0.0
			hop._on_body_entered(player)
			hops += 1
			if remaining - 1 > 0 and _find_bullet_with_chain_gt(0) == null:
				failures.append("chain=%d 的闪电命中后应还有下一跳，但没有生成" % remaining)
		if hops != CHAIN_BOUNCES_P1:
			failures.append("chain=%d 的闪电应共弹射 %d 次，实际 %d 次" % [
				CHAIN_BOUNCES_P1, CHAIN_BOUNCES_P1, hops
			])
		if _find_bullet_with_chain_gt(0) != null:
			failures.append("链应已终止，但场上仍有待弹射的闪电")

	# 阶段2 的弹射次数更多（阶段差异化）
	boss.phase = 2
	_clear_active_bullets()
	boss._chain_timer = 0.0
	boss._physics_process(0.02)
	if _find_bullet_with_chain(CHAIN_BOUNCES_P2) == null:
		failures.append("阶段2 的链式闪电应为 chain_remaining=%d" % CHAIN_BOUNCES_P2)

	_clear_active_bullets()
	_free_boss(boss)
	player.max_hp = 5
	player.hp = min(int(player.hp), 5)


func _check_storm_field():
	var boss = _make_boss("boss_lightning")
	boss.position = Vector2(100, 100)
	player.position = Vector2(640, 360)
	boss.phase = 1
	# 反向：雷暴领域只属于阶段2
	boss._storm_timer = 0.0
	boss._physics_process(0.02)
	if not boss._storm_pending.is_empty():
		failures.append("雷电 Boss 阶段1 不应安排雷暴领域落雷")

	boss.phase = 2
	boss._on_element_phase_change()
	_isolate_periodic_fire(boss)
	player.max_hp = 500
	player.hp = 500
	_reset_player_status()

	# 正向：计时到点后先在玩家当前位置排一次（延迟 0.8s）的落雷
	boss._storm_timer = 0.0
	# ⚠ 血量快照必须在「排入落雷」之前取：否则预警期第一帧就落伤的实现
	# 会被这一次快照吃掉，反向断言形同虚设。
	var hp_before := int(player.hp)
	boss._physics_process(0.01)
	if boss._storm_pending.size() != 1:
		failures.append("阶段2 雷暴领域应排入 1 次落雷，实际 %d 次" % boss._storm_pending.size())
		_free_boss(boss)
		return
	var strike: Dictionary = boss._storm_pending[0]
	var strike_pos: Vector2 = strike["position"]
	if strike_pos.distance_to(player.position) > 1.0:
		failures.append("落雷应瞄准玩家当前位置 %s，实际 %s" % [
			str(player.position), str(strike_pos)
		])

	# ⚠ 反向断言：预警期内（0.8s）不得造成伤害或眩晕
	boss._physics_process(0.5)
	if int(player.hp) != hp_before:
		failures.append("落雷预警期内不应造成伤害（%d → %d）" % [hp_before, int(player.hp)])
	if player.status.is_stunned():
		failures.append("落雷预警期内不应施加眩晕")
	if boss._storm_pending.is_empty():
		failures.append("预警 %.1fs 未到时落雷不应被消费掉" % STORM_DELAY)

	# 正向：0.8s 后落地 —— 伤害 + 眩晕，并且重新按 4s 计间隔
	boss._physics_process(0.4)
	if int(player.hp) >= hp_before:
		failures.append("落雷落地应造成伤害，实际 HP 仍为 %d" % int(player.hp))
	elif hp_before - int(player.hp) != STORM_DAMAGE:
		failures.append("落雷应造成 %d 点伤害，实际 %d" % [STORM_DAMAGE, hp_before - int(player.hp)])
	if not player.status.is_stunned():
		failures.append("落雷落地应施加眩晕")
	if not boss._storm_pending.is_empty():
		failures.append("落雷落地后不应仍留在待落雷列表里")
	if float(boss._storm_timer) < float(boss.STORM_INTERVAL) - 1.0:
		failures.append("落雷后应重新按 %.1fs 计间隔，实际剩余 %.2fs" % [
			float(boss.STORM_INTERVAL), float(boss._storm_timer)
		])

	# 反向：不到雷暴间隔不应有第二次落雷
	player.status.clear()
	var hp_before2 := int(player.hp)
	boss._physics_process(1.0)
	if player.status.is_stunned():
		failures.append("不到雷暴间隔（%.1fs）不应再次眩晕" % float(boss.STORM_INTERVAL))
	if not boss._storm_pending.is_empty():
		failures.append("不到雷暴间隔不应再次安排落雷")
	if int(player.hp) != hp_before2:
		failures.append("不到雷暴间隔不应再次造成伤害")

	# 反向：预警圈内的玩家跑出去就不吃伤害（落雷只看预警圈，不追踪）
	player.status.clear()
	boss._storm_timer = 0.0
	boss._physics_process(0.01)
	player.position = Vector2(640, 360) + Vector2(400, 0)
	hp_before = int(player.hp)
	boss._physics_process(1.0)
	if int(player.hp) != hp_before:
		failures.append("预警期内跑出落雷范围（距离 400 > 半径 %.0f）不应受伤" % float(boss.STORM_RADIUS))
	if player.status.is_stunned():
		failures.append("跑出落雷范围不应被眩晕")

	_free_boss(boss)
	player.max_hp = 5
	player.hp = min(int(player.hp), 5)
	player.position = Vector2(640, 360)
	_reset_player_status()


# ─── 串味检查 ───

# 每个 Boss 只应触发自己的机制：火焰 Boss 不该有冰甲 / 落雷，冰霜 Boss 不该冲锋 / 落雷。
func _check_no_cross_type_leak():
	for type_name in ["boss_fire", "boss_frost", "boss_lightning"]:
		_clear_active_bullets()
		_clear_burn_zones()
		var boss = _make_boss(type_name)
		boss.position = Vector2(100, 100)
		player.position = Vector2(640, 360)
		boss.phase = 2
		boss._on_element_phase_change()
		_isolate_periodic_fire(boss)
		boss._physics_process(0.02)
		if type_name != "boss_lightning" and not boss._storm_pending.is_empty():
			failures.append("%s 不应有雷暴领域落雷" % type_name)
		if type_name != "boss_frost" and int(boss.armor_value) != 0:
			failures.append("%s 不应获得冰甲，实际 armor_value=%d" % [type_name, int(boss.armor_value)])
		if type_name != "boss_fire" and _count_burn_zones() > 0:
			failures.append("%s 不应生成燃烧区域" % type_name)
		_free_boss(boss)
		_clear_active_bullets()
		_clear_burn_zones()
	_reset_player_status()


# ─── 工具 ───

# 冲锋余量自检（见 DASH_MARGIN_MIN_RATIO）。pos_before 取冲锋循环开始前的位置。
# ⚠ 位移必须用 position 差算，不能用 boss._dash_travel：后者每生成一团燃烧区域
# 就扣掉一个 BURN_ZONE_SPACING，读到的是「结余」而不是总位移（实测 68.4px 的
# 总位移会读成 28.4px 结余，看起来像低于阈值，极易误判）。
func _assert_dash_margin(boss, label: String, pos_before: Vector2, steps: int) -> void:
	var spacing := float(boss.BURN_ZONE_SPACING)
	var min_dist := spacing * DASH_MARGIN_MIN_RATIO
	var moved: float = boss.position.distance_to(pos_before)
	if moved < min_dist:
		failures.append("%s 冲锋余量自检：总位移应 ≥ 阈值 %.0fpx 的 %.1f 倍（%.1fpx），实际 %.1fpx（%d 步）—— 位移不足会让燃烧区域偶发为 0，先查物理推进再谈燃烧区域" % [
			label, spacing, DASH_MARGIN_MIN_RATIO, min_dist, moved, steps
		])


func _make_boss(type_name: String):
	var boss = load("res://scenes/Enemy.tscn").instantiate()
	# 必须挂在 Main 下：Enemy 的弹幕走 get_parent() 的对象池
	main.add_child(boss)
	boss.setup(type_name, 1)
	# ⚠ 先进树再关处理（SKILL §3）：反过来的话进树时会被重新启用
	boss.set_physics_process(false)
	boss.set_process(false)
	# 默认把所有周期机制推开：测试只手动打开当前要验的那一个。
	# 否则扇形弹 / 狂暴连发会在后续 await 的帧里飞出去命中玩家，
	# 用元素状态污染后面的断言（假阳性与假阴性都会出现）。
	_isolate_periodic_fire(boss)
	_spawned.append(boss)
	return boss


func _free_boss(boss):
	if is_instance_valid(boss):
		boss.free()
	if boss in _spawned:
		_spawned.erase(boss)


# 关掉当前不需要的周期机制（扇形弹 / 螺旋弹 / 链式 / 闪现 / 雷暴）
func _isolate_periodic_fire(boss):
	boss.shoot_timer = 9999.0
	boss.phase_shoot_timer = 9999.0
	boss._chain_timer = 9999.0
	boss._blink_timer = 9999.0
	boss._storm_timer = 9999.0


func _count_burn_zones() -> int:
	var n := 0
	for zone in get_nodes_in_group("burn_zones"):
		if is_instance_valid(zone) and not zone.is_queued_for_deletion():
			n += 1
	return n


func _first_burn_zone():
	for zone in get_nodes_in_group("burn_zones"):
		if is_instance_valid(zone) and not zone.is_queued_for_deletion():
			return zone
	return null


func _clear_burn_zones():
	for zone in get_nodes_in_group("burn_zones"):
		if is_instance_valid(zone) and not zone.is_queued_for_deletion():
			zone.free()


func _active_bullet_count() -> int:
	var n := 0
	for bullet in main.enemy_bullet_pool:
		if is_instance_valid(bullet) and bullet.visible:
			n += 1
	return n


func _clear_active_bullets():
	for bullet in main.enemy_bullet_pool:
		if is_instance_valid(bullet) and bullet.visible:
			bullet._return_to_pool()


func _find_bullet_with_chain(count: int):
	for bullet in main.enemy_bullet_pool:
		if is_instance_valid(bullet) and bullet.visible and int(bullet.chain_remaining) == count:
			return bullet
	return null


func _find_bullet_with_chain_gt(count: int):
	for bullet in main.enemy_bullet_pool:
		if is_instance_valid(bullet) and bullet.visible and int(bullet.chain_remaining) > count:
			return bullet
	return null


func _reset_player_status():
	player.status.clear()
	player.invincible_timer = 0.0


# ⚠ 给玩家挪位置必须等物理步，不能只改 position 就接着断言。
# Node2D.position 只改节点变换；玩家作为 CharacterBody2D 在物理服务器里的实体
# 要等一次物理步才会更新。不 await 的话：
#   * move_and_slide() 仍会与「玩家旧位置的实体」碰撞 —— 症状是 Boss 冲锋
#     像撞在空气上一样原地不动（燃烧区域一个都生成不出来），
#     slide collision 里能看到 `Player@(427,325)`，那只是 Main.tscn 的出生点；
#   * Area2D 的 get_overlapping_bodies() 也还是旧的重叠关系。
func _place_player(pos: Vector2):
	player.position = pos
	for i in range(2):
		await physics_frame


func _cleanup():
	for boss in _spawned:
		if is_instance_valid(boss):
			boss.free()
	_spawned.clear()
	_clear_burn_zones()
	_clear_active_bullets()
	for enemy in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.free()
