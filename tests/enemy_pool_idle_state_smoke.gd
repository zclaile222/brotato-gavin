extends SceneTree

# 敌人对象池「空闲态」回归测试
#
# 背景（2026-09-15 定位）：
# Main._init_pools() 原本在 add_child() 之前调用 set_physics_process(false)/set_process(false)。
# Godot 的 Node.set_physics_process() 在内部标记已等于目标值时会直接早退，而节点进入场景树时
# 又会因为脚本定义了 _physics_process 而重新启用处理 —— 于是这两行完全无效。后果：
#   1. 预建的 30 个敌人每物理帧运行完整 AI：朝玩家移动、造成接触伤害，
#      这正是「敌人不可见却会挨打」的成因（提交 9aeff45 的可见性安全网即是在给这层症状打补丁）；
#   2. Enemy._ensure_visible() 每物理帧把这些空闲实例的 visible 拨回 true，
#      而 Main.get_enemy() 正是用 `if not e.visible` 判定实例是否空闲，
#      于是池永远命中不到空闲实例，每次刷怪都新建节点 —— 对象池形同虚设。
#
# 本测试固定的不变量：
#   A. 预建池必须留有真正空闲（invisible）的实例；
#   B. 空闲实例不得运行物理处理，且不得留在 enemies 组（炮台/地雷/小地图/AoE 以该组为扫描范围）；
#   C. get_enemy() 必须复用池内实例，而不是新建节点；
#   D. recycle() 之后的实例必须回到空闲态（含退出 enemies 组）。

const PASS_TAG = "ENEMY_POOL_IDLE_STATE_SMOKE_PASS"
const FAIL_TAG = "ENEMY_POOL_IDLE_STATE_SMOKE_FAIL"
const MAX_PRINTED_FAILURES = 15
const FROZEN_TIMER = 9999.0

var failures: Array[String] = []
var main = null
var _checked_out = null
var _idle_snapshot: Array = []


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
	main = packed.instantiate()
	root.add_child(main)
	await process_frame
	# 必须真的跑过物理帧，缺陷才会显形（旧实现是被 _physics_process 里的安全网唤醒的）
	for i in range(3):
		await physics_frame

	_check_pre_warm_and_idle_invariant()
	_freeze_wave_spawning()
	_take_idle_snapshot()
	_check_pool_reuse_prefers_idle_instances()
	await _check_idle_snapshot_survives_physics_frames()
	_check_recycled_enemy_returns_to_idle()

	if is_instance_valid(main):
		main.queue_free()
	main = null
	for i in range(3):
		await process_frame

	if failures.is_empty():
		print(PASS_TAG)
		quit(0)
	else:
		print("%s: %d 项断言失败" % [FAIL_TAG, failures.size()])
		for i in range(min(failures.size(), MAX_PRINTED_FAILURES)):
			print("  - %s" % failures[i])
		if failures.size() > MAX_PRINTED_FAILURES:
			print("  ... 其余 %d 项同类失败已省略" % (failures.size() - MAX_PRINTED_FAILURES))
		push_error("%s: %d failures" % [FAIL_TAG, failures.size()])
		quit(1)


func _idle_pool() -> Array:
	if main == null:
		return []
	var pool = main.get("_enemy_pool")
	if pool == null:
		return []
	return pool


func _is_idle(enemy) -> bool:
	# visible 是本项目里「实例是否在用」的权威标记：
	# get_enemy() 取用时置 true，recycle() 归还时置 false。
	return not enemy.visible


func _freeze_wave_spawning():
	# 让测试确定性：冻结刷怪与波次计时，避免测试期间游戏自己的合法取用干扰空闲态判定
	var wave_manager = main.get("wave_manager")
	if wave_manager == null:
		failures.append("Main 应创建 WaveManager")
		return
	wave_manager.spawn_timer = FROZEN_TIMER
	wave_manager.tree_spawn_timer = FROZEN_TIMER
	wave_manager.landmine_spawn_timer = FROZEN_TIMER
	wave_manager.wave_timer = FROZEN_TIMER


func _take_idle_snapshot():
	_idle_snapshot.clear()
	for enemy in _idle_pool():
		if _is_idle(enemy):
			_idle_snapshot.append(enemy)


func _check_pre_warm_and_idle_invariant():
	var pool = _idle_pool()
	if pool.size() < int(main.ENEMY_POOL_INITIAL):
		failures.append("敌人池未完成预热：期望至少 %d 个实例，实际 %d" % [
			int(main.ENEMY_POOL_INITIAL), pool.size()
		])
		return

	var idle_count = 0
	for enemy in pool:
		if _is_idle(enemy):
			idle_count += 1
			if enemy.is_physics_processing():
				failures.append("空闲池敌人仍在运行物理处理（应休眠）")
			if enemy.is_processing():
				failures.append("空闲池敌人仍在运行空闲处理（应休眠）")
			if enemy.is_in_group("enemies"):
				failures.append("空闲池敌人仍留在 enemies 组（会被炮台/地雷/小地图/AoE 当成活敌人）")
		elif not enemy.is_physics_processing():
			failures.append("已取用的敌人未启用物理处理")

	if idle_count < 1:
		failures.append("启动后敌人池没有任何空闲实例（池已失效，每次刷怪都会新建节点）")


func _check_pool_reuse_prefers_idle_instances():
	var pool = _idle_pool()
	if pool.is_empty():
		return
	var size_before = pool.size()
	_checked_out = main.get_enemy()
	if _checked_out == null:
		failures.append("get_enemy() 应返回一个敌人实例")
		return
	if not pool.has(_checked_out):
		failures.append("get_enemy() 未复用池内实例，而是新建了节点")
	if pool.size() != size_before:
		failures.append("get_enemy() 在存在空闲实例时不应扩张敌人池（%d → %d）" % [
			size_before, pool.size()
		])
	_checked_out.setup("normal", 1)
	if not _checked_out.visible:
		failures.append("取用后的敌人应为可见")
	if not _checked_out.is_physics_processing():
		failures.append("取用后的敌人应启用物理处理")
	if not _checked_out.is_in_group("enemies"):
		failures.append("取用后的敌人应加入 enemies 组")


func _check_idle_snapshot_survives_physics_frames():
	# 核心断言：物理帧不得把空闲实例唤醒（旧实现中 _ensure_visible 每帧续命）
	if _idle_snapshot.is_empty():
		failures.append("启动后没有可用于观察的空闲实例")
		return
	for i in range(5):
		await physics_frame
	for enemy in _idle_snapshot:
		if enemy == _checked_out:
			continue
		if not _is_idle(enemy):
			failures.append("空闲敌人跨越物理帧后被唤醒为可见（安全网误修）")
		if enemy.is_physics_processing():
			failures.append("空闲敌人跨越物理帧后仍在运行物理处理")


func _check_recycled_enemy_returns_to_idle():
	if _checked_out == null or not is_instance_valid(_checked_out):
		return
	main.recycle_enemy(_checked_out)
	if _checked_out.visible:
		failures.append("归还后的敌人应变为不可见")
	if _checked_out.is_physics_processing():
		failures.append("归还后的敌人应停止物理处理")
	if _checked_out.is_processing():
		failures.append("归还后的敌人应停止空闲处理")
	if _checked_out.is_in_group("enemies"):
		failures.append("归还后的敌人应退出 enemies 组")
