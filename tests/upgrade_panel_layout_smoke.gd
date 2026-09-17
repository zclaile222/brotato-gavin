extends SceneTree

# 波末「选择一项升级」面板的布局冒烟测试
#
# 用户报告：升级选择框右边会超出屏幕、显示不全。
#
# 根因（见 HUD._build_upgrade_choice_panel）：
# `upgrade_panel.set_anchors_preset(Control.PRESET_CENTER)` 是在面板**还没有尺寸**的时候调的
# （`custom_minimum_size` 在下一行才设置，而"最小尺寸"也不会立刻改变实际尺寸）。
# 于是四个 offset 全被算成 0 —— 矩形塌缩成屏幕中心的一个点；
# 之后容器按内容把尺寸撑开，右/下边就**从中心点往右下长**，
# 结果为「偏右 + 右边越界」。它看起来像"居中失败"，其实是"锚点预设调用的时机错了"。
#
# 固定：面板矩形必须完整落在视口内，且水平/垂直都大致居中。
# 用真实路径取选项（player.pop_upgrade_choices），不走假数据 —— 否则测不到真实尺寸。

const PASS_TAG := "UPGRADE_PANEL_LAYOUT_SMOKE_PASS"
const FAIL_TAG := "UPGRADE_PANEL_LAYOUT_SMOKE_FAIL"

var failures: Array[String] = []


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
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var hud = main.get("hud")
	var player = main.get("player")
	if hud == null or player == null:
		failures.append("Main 未解析出 hud / player")
		_report()
		return

	# pop_upgrade_choices() 有前置门 `pending_level_ups <= 0 → 返回空`，
	# 所以要先造出「有未处理的升级」这个状态 —— 也正是 Main 调用它时的状态。
	player.pending_level_ups = 1
	var choices: Array = player.pop_upgrade_choices()
	if choices.is_empty():
		# 空转保护：没有真实选项就测不到面板尺寸
		failures.append("pop_upgrade_choices 返回空 —— 本测试会空转，无法验证布局")
		_report()
		return

	hud.show_upgrade_choices(choices)
	# 布局是在下一帧完成的，必须等
	await process_frame
	await process_frame

	var panel = hud.upgrade_panel
	if panel == null or not is_instance_valid(panel):
		failures.append("找不到 upgrade_panel")
		_report()
		return
	if not panel.visible:
		failures.append("show_upgrade_choices 之后面板应当可见")

	var view: Vector2 = root.get_visible_rect().size
	var rect: Rect2 = panel.get_global_rect()

	# 判据是**居中语义**，不是"绝对不越界"：
	# 居中容器会把子节点放在 max((视口 - 面板) / 2, 0)。
	# 这个断言与视口尺寸无关 —— headless 下视口只有 64×64，面板 760 宽本来就塞不下，
	# 用"绝不越界"去判会得到假失败（我第一版就栽在这，还顺手把 root.size 改坏导致 Main 起不来）。
	#
	# 它照样能抓住原 bug：那时面板 position 等于**视口中心** (32,32)，
	# 而居中语义要求 max((64-760)/2, 0) = 0 → 对不上。
	var expected := Vector2(
		maxf((view.x - rect.size.x) * 0.5, 0.0),
		maxf((view.y - rect.size.y) * 0.5, 0.0)
	)
	if rect.position.distance_to(expected) > 2.0:
		failures.append("面板未按居中语义摆放：position=%s，应为 %s（视口 %s，面板尺寸 %s）" % [
			str(rect.position), str(expected), str(view), str(rect.size)
		])

	# 面板装得下时，才额外要求它真的在视口内
	if rect.size.x <= view.x and rect.end.x > view.x:
		failures.append("面板右边越界：%.1f > 视口宽 %.1f" % [rect.end.x, view.x])
	if rect.size.y <= view.y and rect.end.y > view.y:
		failures.append("面板下边越界：%.1f > 视口高 %.1f" % [rect.end.y, view.y])

	print("PANEL 视口 %s 面板 rect=%s 期望 position=%s" % [
		str(view), str(rect), str(expected)
	])

	if is_instance_valid(main):
		main.queue_free()
	_report()


func _report():
	if failures.is_empty():
		print(PASS_TAG)
		quit(0)
		return
	print("%s: %d 项断言失败" % [FAIL_TAG, failures.size()])
	for f in failures:
		print("  - %s" % f)
	push_error("%s: %d failures" % [FAIL_TAG, failures.size()])
	quit(1)
