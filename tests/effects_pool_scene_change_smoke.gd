extends SceneTree

var failures: Array[String] = []

func _init():
	call_deferred("_run")

func _run():
	var effects_script = load("res://scripts/Effects.gd")
	if effects_script == null:
		failures.append("Effects script failed to load")
		_finish()
		return

	var old_scene = Node2D.new()
	old_scene.name = "OldScene"
	root.add_child(old_scene)
	current_scene = old_scene

	var effects = effects_script.new()
	effects.name = "EffectsUnderTest"
	root.add_child(effects)
	await process_frame

	if effects._burst_pool.is_empty():
		failures.append("Effects did not initialize burst pool")
	if effects._label_pool.is_empty():
		failures.append("Effects did not initialize label pool")

	old_scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame

	var new_scene = Node2D.new()
	new_scene.name = "NewScene"
	root.add_child(new_scene)
	current_scene = new_scene

	var burst_root = effects._get_burst_root()
	if not is_instance_valid(burst_root):
		failures.append("Burst pool returned a freed node after scene change")
	elif not burst_root.is_inside_tree():
		failures.append("Burst pool returned a node outside the scene tree")

	var label = effects._get_label()
	if not is_instance_valid(label):
		failures.append("Label pool returned a freed node after scene change")
	elif not label.is_inside_tree():
		failures.append("Label pool returned a node outside the scene tree")

	effects.hit_spark(Vector2(100, 100), Color(1, 0.2, 0.1))
	effects.damage_number(Vector2(120, 120), 7)
	await process_frame

	effects.queue_free()
	new_scene.queue_free()
	current_scene = null
	await process_frame

	_finish()

func _finish():
	if failures.is_empty():
		print("EFFECTS_POOL_SCENE_CHANGE_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
