extends SceneTree

# camera_arena_smoke.gd — 相机跟随 + 3×3 屏大地图
#
# 这个套件要证明的不是「Arena.gd 里的算术对」，而是：
#   ① 相机真的跟着玩家走，且在世界边缘**钳位**（不露出地图外的空白）
#   ② 玩家能在超过一屏的范围里活动（改造前被视口锁死在一屏内）
#   ③ 世界是 3×3 屏，且背景铺满整个世界（不是只铺一屏）
#   ④ 刷怪用的是「相机外圈」而不是「世界外圈」—— 否则相机在场地中央时
#      敌人会刷在 3840px 之外，玩家等到天荒地老也见不到一个敌人
#   ⑤ 子弹按「离开视野」回收，按「离开世界」判的话全图弹道会堆积
#
# 关于视口尺寸：`--script` 模式下根视口是 64×64（见 docs §10.2），
# 而 Arena 的场地尺寸是「视口 × 3」并保底 1280×720，所以测试里只要把
# root.size 设回工程声明的 1280×720，世界就正好是 3840×2160。
# 这个尺寸在断言里是**显式期望值**，不是从被测对象反推的（防空转）。

const EXPECTED_WORLD := Vector2(3840.0, 2160.0)
const EXPECTED_VIEW := Vector2(1280.0, 720.0)

var failures: Array[String] = []
var main = null
var arena: Arena = null
var player = null


func _init():
	call_deferred("_run")


func _run():
	_restore_viewport()
	_prepare_game_state()

	# 不 preload 全部脚本类：本套件只关心场地/相机，额外加载会和
	# 「Arena 未注册」这类真问题混在一起，反而看不清。
	var packed = load("res://scenes/Main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	await process_frame

	arena = main.get("arena")
	player = main.get("player")

	# ── 前置自检：被测对象必须真的在树上、且真的被驱动着 ──
	# 没有这一段，后面所有断言都可能因为「根本没建起来」而变成空转通过。
	if not _preflight():
		_finish()
		return

	await _check_camera_follows_player()
	await _check_camera_clamps_at_world_edges()
	await _check_player_can_leave_first_screen()
	_check_world_is_three_by_three_screens()
	_check_background_covers_world()
	_check_spawn_ring_tracks_camera()
	await _check_bullet_reaped_by_camera_not_world()

	_finish()


# ─── 场地/视口的建立 ───

func _restore_viewport():
	# 从 project.godot 读，不写死 1280×720 —— 工程改了声明这里要跟着走。
	# （字符串参数重载在 4.x 是合法的，但本参数是常量的，直接写字面量更稳。）
	var viewport_w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var viewport_h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	root.size = Vector2i(viewport_w, viewport_h)
	if Vector2(root.size) != EXPECTED_VIEW:
		failures.append("视口未还原成工程声明尺寸：期望 %s，实际 %s（后续断言全部不可信）" % [
			str(EXPECTED_VIEW), str(Vector2(root.size))
		])


func _prepare_game_state():
	var game_state = root.get_node("/root/GameState")
	game_state.selected_character = "normal"
	game_state.difficulty = 1
	game_state.endless_mode = false
	var audio_manager = root.get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		root.remove_child(audio_manager)
		audio_manager.queue_free()


func _preflight() -> bool:
	if main == null or not is_instance_valid(main):
		failures.append("Main 场景没有实例化出来")
		return false
	if arena == null or not is_instance_valid(arena):
		failures.append("Main 没有创建 Arena 节点（arena 字段为空或无效）")
		return false
	if not arena.is_inside_tree():
		failures.append("Arena 不在场景树上")
		return false
	if Arena.get_active() != arena:
		failures.append("Arena.get_active() 没有返回 Main 创建的场地 —— 全部边界调用都会走到兜底分支")
		return false
	if player == null or not is_instance_valid(player):
		failures.append("Main 没有解析出玩家")
		return false
	var cam = main.get("camera")
	if cam == null or not is_instance_valid(cam):
		failures.append("Main 没有创建相机")
		return false
	if not cam.enabled:
		failures.append("相机没有启用（`main.camera.enabled == false`）")
	if not cam.get_meta("__arena_follow", false):
		failures.append("相机缺少 Arena 跟随标记 `__arena_follow` —— Main._process 不会驱动它")
	# 世界必须真的是 3×3 屏，否则后面「钳位在 640」这类期望值就是错的
	var world := arena.world_rect()
	if not world.size.is_equal_approx(EXPECTED_WORLD):
		failures.append("世界尺寸不对：期望 %s（3×3 屏），实际 %s（视口 %s）" % [
			str(EXPECTED_WORLD), str(world.size), str(Vector2(root.size))
		])
		return false
	return true


# ─── ① 相机跟随 + 钳位 ───

func _check_camera_follows_player():
	var cam = main.camera
	# 场地中心：两侧都有足够的活动余量，钳位不应该生效
	var center := arena.world_rect().get_center()

	await _place_player_and_settle(center)
	if not cam.position.is_equal_approx(center):
		failures.append("相机没有对准场地中心的玩家：期望 %s，实际 %s" % [str(center), str(cam.position)])

	# 从中心向左上移动 400px：仍在中部，相机应当**逐点跟随**（差值 = 位移量）
	var moved := center - Vector2(400.0, 400.0)
	await _place_player_and_settle(moved)
	if not cam.position.is_equal_approx(moved):
		failures.append("相机没有跟随玩家移动：玩家 %s，相机 %s（期望与玩家重合）" % [
			str(moved), str(cam.position)
		])

	# 相机可视矩形的中心应当就是相机中心 —— 证明视图矩形与相机是同一个真相
	var view := arena.camera_view_rect()
	if not view.get_center().is_equal_approx(cam.get_screen_center_position()):
		failures.append("camera_view_rect() 中心 %s 与相机屏幕中心 %s 不一致" % [
			str(view.get_center()), str(cam.get_screen_center_position())
		])
	if not view.size.is_equal_approx(EXPECTED_VIEW):
		failures.append("相机可视矩形不是一屏：期望 %s，实际 %s" % [str(EXPECTED_VIEW), str(view.size)])


func _check_camera_clamps_at_world_edges():
	var cam = main.camera
	var world := arena.world_rect()
	var half := EXPECTED_VIEW * 0.5

	# 左上角：玩家在 (20,20)，相机应停在 (半屏宽, 半屏高) = (640,360)
	var top_left := world.position + Vector2(Arena.PLAYER_MARGIN, Arena.PLAYER_MARGIN)
	await _place_player_and_settle(top_left)
	var expected_tl := world.position + half
	if not cam.position.is_equal_approx(expected_tl):
		failures.append("相机在左上角没有钳位：玩家 %s，期望相机 %s，实际 %s" % [
			str(top_left), str(expected_tl), str(cam.position)
		])

	# 右下角：相机应停在 (世界宽-半屏宽, 世界高-半屏高) = (3200,1800)
	var bottom_right := world.end - Vector2(Arena.PLAYER_MARGIN, Arena.PLAYER_MARGIN)
	await _place_player_and_settle(bottom_right)
	var expected_br := world.end - half
	if not cam.position.is_equal_approx(expected_br):
		failures.append("相机在右下角没有钳位：玩家 %s，期望相机 %s，实际 %s" % [
			str(bottom_right), str(expected_br), str(cam.position)
		])

	# 钳位的意义：可视矩形必须刚好贴着场地边，不能露到场地外
	var view := arena.camera_view_rect()
	if view.position.x < world.position.x - 0.5 or view.position.y < world.position.y - 0.5:
		failures.append("钳位后相机露到场地左上之外：可视矩形 %s，场地 %s" % [str(view), str(world)])
	if view.end.x > world.end.x + 0.5 or view.end.y > world.end.y + 0.5:
		failures.append("钳位后相机露到场地右下之外：可视矩形 %s，场地 %s" % [str(view), str(world)])

	# 反向自检：如果这里有 bug（相机跑到玩家身上），上一次的贴边检查也会红 ——
	# 说明这一对断言是真的在互相约束，而不是恒真。
	var naive := bottom_right  # 未钳位时的相机位置
	if naive.is_equal_approx(cam.position):
		failures.append("钳位没有生效：相机位置与未钳位的玩家位置相同（%s）" % str(naive))


# ─── ② 玩家能走出第一屏 ───

func _check_player_can_leave_first_screen():
	# 这一条直接对着用户报的缺陷：改造前玩家被锁在 (20, 1260)×(20,700) 内。
	var target := Vector2(3000.0, 1800.0)
	await _place_player_and_settle(target)
	var pos: Vector2 = player.position
	if not pos.is_equal_approx(target):
		failures.append("玩家无法移动到第一屏之外：期望 %s，实际 %s（场地 %s）" % [
			str(target), str(pos), str(arena.world_rect())
		])
	if pos.x <= EXPECTED_VIEW.x or pos.y <= EXPECTED_VIEW.y:
		failures.append("玩家仍被限制在首屏范围内：位置 %s，首屏 %s" % [str(pos), str(EXPECTED_VIEW)])

	# 场地边界仍然要挡得住
	var beyond := Vector2(99999.0, 99999.0)
	await _place_player_and_settle(beyond)
	var clamped: Vector2 = player.position
	var expected: Vector2 = arena.world_rect().end - Vector2(Arena.PLAYER_MARGIN, Arena.PLAYER_MARGIN)
	if not clamped.is_equal_approx(expected):
		failures.append("玩家越界没有被场地边界挡住：期望 %s，实际 %s" % [str(expected), str(clamped)])


# ─── ③ 世界与背景 ───

func _check_world_is_three_by_three_screens():
	var world := arena.world_rect()
	# 3×3 屏：3*1280 = 3840，3*720 = 2160
	if not world.position.is_equal_approx(Vector2.ZERO):
		failures.append("场地原点应当从 (0,0) 起算：实际 %s" % str(world.position))
	# ArenaBackground 的绘制缓存必须跟着场地走，而不是跟着视口
	var bg = main.get_node_or_null("ArenaBackground")
	if bg == null:
		failures.append("Main 场景里找不到 ArenaBackground")
		return
	var cached: Vector2 = bg._world_size
	if not cached.is_equal_approx(world.size):
		failures.append("背景缓存的场地尺寸与 Arena 不一致：背景 %s，Arena %s（背景仍会只铺一屏）" % [
			str(cached), str(world.size)
		])
	var floor: Rect2 = bg._floor
	if floor.size.x < world.size.x or floor.size.y < world.size.y:
		failures.append("背景地面没有铺满场地：地面 %s（尺寸 %s），场地 %s" % [
			str(floor), str(floor.size), str(world.size)
		])


func _check_background_covers_world():
	# 场地中心必须落在地面矩形里 —— 否则「走到地图中央是一片虚空」。
	var bg = main.get_node_or_null("ArenaBackground")
	if bg == null:
		return
	var floor: Rect2 = bg._floor
	var world := arena.world_rect()
	if not floor.has_point(world.get_center()):
		failures.append("场地中心 %s 不在地面内：地面 %s" % [str(world.get_center()), str(floor)])
	if not floor.has_point(world.position + Vector2(4.0, 4.0)):
		failures.append("场地左上角不在背景地面内：地面 %s" % str(floor))
	if not floor.has_point(world.end - Vector2(4.0, 4.0)):
		failures.append("场地右下角不在背景地面内：地面 %s" % str(floor))


# ─── ④ 刷怪圈跟着相机 ───

func _check_spawn_ring_tracks_camera():
	# 把玩家放到场地中心（相机也在中心），取一批刷怪点，它们必须都落在
	# 「相机矩形外扩 SPAWN_MARGIN」之外 —— 也就是玩家看不见的地方。
	# 若刷怪仍按**世界**边缘算，这些点会跑到 3840px 外，环带断言会直接红。
	var center := arena.world_rect().get_center()
	await _place_player_and_settle(center)

	var view := arena.camera_view_rect()
	var ring := arena.spawn_margin_rect()
	var wave_manager = main.get("wave_manager")
	if wave_manager == null:
		failures.append("Main 没有 WaveManager，无法验证刷怪点")
		return

	var checked := 0
	var outside_view := 0
	for i in range(200):
		var p: Vector2 = wave_manager._get_random_screen_edge()
		checked += 1
		if not view.has_point(p):
			outside_view += 1
		# 刷怪点必须落在相机外扩圈内 —— 超出说明还在按世界边缘刷怪
		if not ring.grow(40.0).has_point(p):
			failures.append("刷怪点跑到相机外扩圈之外：点 %s，相机矩形 %s，外扩矩形 %s" % [
				str(p), str(view), str(ring)
			])
			break
	if checked == 0:
		failures.append("没有取到任何刷怪点（前置条件不成立，断言为空转）")
		return
	if outside_view != checked:
		failures.append("有 %d/%d 个刷怪点落在玩家视野内（应当全部在视野外）" % [checked - outside_view, checked])

	# 反面对照：站在场地中心时，相机矩形**不等于**世界矩形。
	# 如果两者相等（相机没跟随 / 拿的还是世界），上面的断言就退化成恒真。
	if view.get_center().is_equal_approx(arena.world_rect().get_center()) and view.size.is_equal_approx(arena.world_rect().size):
		failures.append("相机矩形等于世界矩形，本组断言无法区分「按相机刷怪」与「按世界刷怪」")


# ─── ⑤ 子弹按视野回收 ───

func _check_bullet_reaped_by_camera_not_world():
	# 玩家与相机都在场地中心。在相机右缘外 200px 放一颗子弹：
	#   · 按「离开视野」判定 → 立即回收
	#   · 按「离开场地」判定 → 距离世界右缘还有 1300+px，绝不该回收
	# 后者会让全图弹道持续堆积，所以这两条必须区分开。
	var center := arena.world_rect().get_center()
	await _place_player_and_settle(center)

	if not main.has_method("get_bullet"):
		failures.append("Main 没有 get_bullet()")
		return
	var bullet = main.get_bullet()
	if bullet == null or not is_instance_valid(bullet):
		failures.append("子弹池没有返回有效实例")
		return

	var view := arena.camera_view_rect()
	var spawn_pos: Vector2 = Vector2(view.end.x + 200.0, view.get_center().y)
	if spawn_pos.x >= arena.world_rect().end.x:
		failures.append("测试布置有误：取点 %s 已经出了场地右缘 %s，无法区分两种判据" % [
			str(spawn_pos), str(arena.world_rect().end.x)
		])
		return

	bullet.activate(spawn_pos, Vector2.ZERO, 0.0, Color.WHITE, player, 1)
	if not bullet.visible:
		failures.append("子弹激活后应可见，前置条件不成立（断言会空转）")
		return
	# 速度 0，子弹停在原地；只要 _process 走一次出界检查就会回收
	await process_frame
	if bullet.visible:
		failures.append("停在视野外的子弹没有被回收：位置 %s，相机矩形 %s（仍在场地 %s 内）" % [
			str(spawn_pos), str(view), str(arena.world_rect())
		])
	if bullet.has_method("_return_to_pool"):
		bullet._return_to_pool()

	# 反面对照：同一位置若按**场地**判则不该回收 —— 证明上一条测的是视野而不是场地。
	if arena.is_outside_viewport(spawn_pos, 50.0) == false:
		failures.append("布置点 %s 按视野判定不在界外，本组断言测错了对象" % str(spawn_pos))


# ─── 工具 ───

# 摆好玩家位置，并等到 Main._process 真的跑过一轮相机跟随。
# 玩家有 PlayerCore 的钳位，所以位置是「按场地边界钳过的」——
# 调用方拿期望值时必须用 Arena.PLAYER_MARGIN 一起钳，不能直接比原始点。
func _place_player_and_settle(pos: Vector2):
	player.position = arena.clamp_player_position(pos)
	# 物理帧让 PlayerCore 的钳位自己跑一次，保证我们不是靠「_process 还没跑」取胜
	await physics_frame
	await process_frame
	# 相机跟随在 Main._process 里；再等一帧确保它已经按最新位置更新
	await process_frame


func _finish():
	if is_instance_valid(main):
		main.queue_free()
	main = null
	arena = null
	player = null
	if failures.is_empty():
		print("CAMERA_ARENA_SMOKE_PASS world=%s camera_follow=ok clamp=ok spawn_ring=ok" % str(EXPECTED_WORLD))
		quit(0)
	else:
		for failure in failures:
			print("  - " + failure)
		print("CAMERA_ARENA_SMOKE_FAIL failures=%d" % failures.size())
		quit(1)
