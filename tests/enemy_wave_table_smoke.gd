extends SceneTree

# 波次表（data/brotato/enemy_waves.json）冒烟测试
#
# 背景：改造前波次构成完全硬编码在 `WaveManager._pick_enemy_type()` 里，有三个问题：
#   1. 权重用「累积 append + 等概率抽取」表达 —— 所有已登场类型权重相同，
#      实际配比不可读、不可调；
#   2. 第 12 波之后池子不再变化，**13-20 波实际是同一波**；
#   3. 刷怪间隔是 `(2.0 - wave * 0.1)`，第 20 波正好减到 0、被 `max(0.2, …)` 兜住，
#      于是 18 波之后的曲线是算出来的、不是设计出来的。
# 现在这些全部改成目录驱动。本测试固定五组不变量：
#   A. 目录结构：1..total 波连续、主题非空、时长/间隔为正、boss 与 boss_count 自洽；
#   B. 跨文件一致性门：池内类型与 Boss 类型都必须存在于 `Enemy.ENEMY_TYPES`
#      —— `Enemy.setup()` 会做 `ENEMY_TYPES[type]` 直查，未知类型是运行时硬错误，
#      所以这条门必须存在（BrotatoData 看不到 Enemy 的类型表，只能在测试里守）；
#   C. 威胁阶梯：敌种数单调不减、填充型权重占比下降、专业型上升、
#      且相邻波次（尤其 12→13）的池子不能完全相同；
#   D. 间隔曲线：1..total 单调不增，且尾段不被下界抹平；
#   E. 消费端：抽取分布符合权重、未知类型被剔除并回落兜底池、
#      `get_spawn_interval` 仍随 enemies_percent / 难度倍率单调（保持原有契约）。

const PASS_TAG := "ENEMY_WAVE_TABLE_SMOKE_PASS"
const FAIL_TAG := "ENEMY_WAVE_TABLE_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

# 敌人类型表经 WaveManager.enemy_types() 取（内部是运行时 load），
# 不在测试里 const preload()：Enemy.gd 引用 GameState 自动加载，
# 在 `--script` 形式的测试里解析期拉它会在自动加载注册前编译失败，
# 并把失败结果写进全局脚本缓存，连带弄坏后续加载的敌人实例。

# 常规池里不允许出现的类型：它们有专用生成路径（树 / 战利品外星人 / Boss），
# 混进来会破坏波次节奏。
const RESERVED_TYPES := ["tree", "loot_alien", "boss", "miniboss"]

# 「靠数量施压」与「靠质量施压」两组类型，用于验证数量→质量的替换。
const FILLER_TYPES := ["normal", "fast", "swarm", "healer"]
const SPECIALIST_TYPES := ["armored", "charger", "shooter_spread", "summoner", "elite"]

const SAMPLE_COUNT := 8000

# 「平台期」上限：连续几波可以共用同一套敌人构成。
# 被修掉的缺陷是连续 8 波同构（12→20 波冻结），不是「相邻必须不同」。
const MAX_POOL_PLATEAU := 2

var failures: Array[String] = []
var main = null
var wave_manager = null
var table: Dictionary = {}
var total_waves := 0
var enemy_types: Dictionary = {}


func has_enemy_type(type_name: String) -> bool:
	return enemy_types.has(type_name)


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

	wave_manager = main.get("wave_manager")
	if wave_manager == null:
		failures.append("Main 应创建 WaveManager")
		_report()
		return
	_freeze_wave_spawning()

	# 用 WaveManager 的懒解析入口取类型表，避免测试自己再造一份判据
	enemy_types = wave_manager.call("enemy_types")
	if enemy_types.is_empty():
		failures.append("取不到 Enemy.ENEMY_TYPES，跨文件一致性门无法生效")

	table = wave_manager.get("_wave_table")
	total_waves = int(wave_manager.call("total_waves"))
	if not bool(wave_manager.call("has_wave_table")):
		failures.append("WaveManager 未从目录加载波次表，后续断言只会验证兜底值")

	_check_structure()
	_check_cross_file_consistency()
	_check_threat_ladder()
	_check_interval_curve()
	_check_consumer_contract()
	_check_weighted_pick()
	_check_unknown_type_fallback()
	_check_boss_wiring()
	await _check_dual_boss_spawn()

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
	# 本测试只调用纯查询方法，冻结刷怪以免 Main 的波次逻辑干扰
	wave_manager.spawn_timer = 9999.0
	wave_manager.tree_spawn_timer = 9999.0
	wave_manager.landmine_spawn_timer = 9999.0
	wave_manager.wave_timer = 9999.0


func _entry(wave_num: int) -> Dictionary:
	return table.get(str(wave_num), {})


func _pool(wave_num: int) -> Array:
	var pool = _entry(wave_num).get("pool", [])
	if not (pool is Array):
		return []
	return pool


func _weight(wave_num: int, type_name: String) -> float:
	for entry in _pool(wave_num):
		if entry is Dictionary and str(entry.get("type", "")) == type_name:
			return float(entry.get("weight", 0.0))
	return 0.0


func _share(wave_num: int, types: Array) -> float:
	var total := 0.0
	var part := 0.0
	for entry in _pool(wave_num):
		if not (entry is Dictionary):
			continue
		var w := float(entry.get("weight", 0.0))
		total += w
		if str(entry.get("type", "")) in types:
			part += w
	if total <= 0.0:
		failures.append("第 %d 波的权重总和为 0" % wave_num)
		return 0.0
	return part / total


func _pool_signature(wave_num: int) -> String:
	# 与顺序无关的池子指纹：类型按名字排序后带上权重
	var parts: Array[String] = []
	for entry in _pool(wave_num):
		if entry is Dictionary:
			parts.append("%s=%.4f" % [str(entry.get("type", "")), float(entry.get("weight", 0.0))])
	parts.sort()
	return "|".join(parts)


# ─── A. 目录结构 ───

func _check_structure():
	if total_waves != 20:
		failures.append("total_waves 应为 20，实际 %d" % total_waves)
	for w in range(1, total_waves + 1):
		var entry = _entry(w)
		var label := "第 %d 波" % w
		if entry.is_empty():
			failures.append("%s 缺少波次定义" % label)
			continue
		if str(entry.get("theme", "")).strip_edges().is_empty():
			failures.append("%s 的 theme 为空（每波必须有可命名主题）" % label)
		if float(entry.get("duration", 0.0)) <= 0.0:
			failures.append("%s 的 duration 非正：%s" % [label, str(entry.get("duration"))])
		if float(entry.get("spawn_interval", 0.0)) <= 0.0:
			failures.append("%s 的 spawn_interval 非正：%s" % [label, str(entry.get("spawn_interval"))])
		if _pool(w).is_empty():
			failures.append("%s 的 pool 为空" % label)
		var boss := str(entry.get("boss", ""))
		var boss_count := int(entry.get("boss_count", 0))
		if boss.is_empty() and boss_count != 0:
			failures.append("%s 未指定 boss，boss_count 却为 %d" % [label, boss_count])
		if not boss.is_empty() and boss_count < 1:
			failures.append("%s 指定了 boss=%s，boss_count 却为 %d" % [label, boss, boss_count])
	for id in table:
		if int(id) > total_waves:
			failures.append("enemy_waves.%s 超出了 total_waves=%d" % [id, total_waves])


# ─── B. 跨文件一致性门 ───

func _check_cross_file_consistency():
	for w in range(1, total_waves + 1):
		for entry in _pool(w):
			if not (entry is Dictionary):
				failures.append("第 %d 波的 pool 里有非对象条目" % w)
				continue
			var type_name := str(entry.get("type", ""))
			if not has_enemy_type(type_name):
				failures.append("第 %d 波引用了未定义的敌人类型: %s" % [w, type_name])
			if type_name in RESERVED_TYPES:
				failures.append("第 %d 波的常规池不应包含 %s（它由专用路径生成）" % [w, type_name])
		var boss := str(_entry(w).get("boss", ""))
		if not boss.is_empty() and not has_enemy_type(boss):
			failures.append("第 %d 波的 Boss 类型未定义: %s" % [w, boss])


# ─── C. 威胁阶梯 ───

func _check_threat_ladder():
	var prev_distinct := -1
	for w in range(1, total_waves + 1):
		var distinct := _pool(w).size()
		if distinct < prev_distinct:
			failures.append("第 %d 波的敌种数（%d）少于第 %d 波（%d），威胁应单调升级" % [
				w, distinct, w - 1, prev_distinct
			])
		prev_distinct = distinct

	var early_filler := _share(2, FILLER_TYPES)
	var late_filler := _share(total_waves, FILLER_TYPES)
	if late_filler >= early_filler:
		failures.append("填充型权重占比应随波次下降：第 2 波 %.3f → 第 %d 波 %.3f" % [
			early_filler, total_waves, late_filler
		])
	var early_specialist := _share(2, SPECIALIST_TYPES)
	var late_specialist := _share(total_waves, SPECIALIST_TYPES)
	if late_specialist <= early_specialist:
		failures.append("专业型权重占比应随波次上升：第 2 波 %.3f → 第 %d 波 %.3f" % [
			early_specialist, total_waves, late_specialist
		])
	if _weight(12, "elite") <= 0.0:
		failures.append("第 12 波起应出现精英，实际权重 %.3f" % _weight(12, "elite"))

	# 回归门：修掉「12 波之后池子冻结」。
	# 判据不是「相邻必须不同」—— 连续两波同构是合理设计（平台期，例如第 1-2 波）；
	# 被修掉的那个缺陷是「连续 8 波完全同构」，所以这里限制平台期长度。
	var longest_run := 1
	var longest_start := 1
	var run_start := 1
	var run_len := 1
	for w in range(2, total_waves + 1):
		if _pool_signature(w) == _pool_signature(w - 1):
			run_len += 1
		else:
			run_start = w
			run_len = 1
		if run_len > longest_run:
			longest_run = run_len
			longest_start = run_start
	if longest_run > MAX_POOL_PLATEAU:
		failures.append("第 %d-%d 波连续 %d 波池子完全同构，超过平台期上限 %d 波（波次构成被冻结）" % [
			longest_start, longest_start + longest_run - 1, longest_run, MAX_POOL_PLATEAU
		])


# ─── D. 间隔曲线 ───

func _check_interval_curve():
	var prev := INF
	var at_floor: Array[String] = []
	var floor_value := float(wave_manager.MIN_SPAWN_INTERVAL)
	for w in range(1, total_waves + 1):
		var iv := float(_entry(w).get("spawn_interval", -1.0))
		if iv <= 0.0:
			continue
		if iv > prev:
			failures.append("第 %d 波的刷怪间隔（%.3f）长于第 %d 波（%.3f），威胁应单调升级" % [
				w, iv, w - 1, prev
			])
		prev = iv
		if iv <= floor_value + 0.0001:
			at_floor.append("第 %d 波" % w)

	# 尾段不能被下界抹平：改造前 18/19/20 波都被 max(0.2, …) 兜到同一个值，
	# 曲线形状是算出来的而不是设计出来的。现在最多只允许一波贴到下界。
	if at_floor.size() > 1:
		failures.append("有 %d 个波次的间隔贴在下界 %.2f（%s），曲线尾段被下界抹平了" % [
			at_floor.size(), floor_value, ", ".join(at_floor)
		])

	var mid := float(_entry(10).get("spawn_interval", 0.0))
	var last := float(_entry(total_waves).get("spawn_interval", 0.0))
	if not (last < mid):
		failures.append("末波间隔（%.3f）应严格小于第 10 波（%.3f）" % [last, mid])


# ─── E. 消费端契约 ───

func _check_consumer_contract():
	# 时长直接来自目录
	var expected_duration := float(_entry(10).get("duration", 0.0))
	var actual_duration := float(wave_manager.call("get_wave_duration", 10, false))
	if not is_equal_approx(actual_duration, expected_duration):
		failures.append("第 10 波时长应取自目录 %.3f，实际 %.3f" % [expected_duration, actual_duration])
	# 目录没有的波次（无尽）应回落到兜底值而不是 0
	var endless_duration := float(wave_manager.call("get_wave_duration", 99, true))
	if endless_duration <= 0.0:
		failures.append("无尽波次的时长应回落到兜底值，实际 %.3f" % endless_duration)
	# 主题可直接取用
	for w in range(1, total_waves + 1):
		if str(wave_manager.call("get_wave_theme", w)).strip_edges().is_empty():
			failures.append("第 %d 波取不到主题" % w)

	# 间隔仍随 enemies_percent / 难度倍率单调（保持改造前的契约）
	var base_iv := float(wave_manager.call("get_spawn_interval", 5, 1.0, 1.0, 0.0))
	var expected_base := float(_entry(5).get("spawn_interval", 0.0))
	if not is_equal_approx(base_iv, expected_base):
		failures.append("第 5 波基础间隔应为目录值 %.3f，实际 %.3f" % [expected_base, base_iv])
	var more := float(wave_manager.call("get_spawn_interval", 5, 1.0, 1.0, 0.5))
	var fewer := float(wave_manager.call("get_spawn_interval", 5, 1.0, 1.0, -0.5))
	if not (more < base_iv and base_iv < fewer):
		failures.append("enemies_percent 应单调缩短间隔：+50%%=%.3f  0=%.3f  -50%%=%.3f" % [
			more, base_iv, fewer
		])
	var harder := float(wave_manager.call("get_spawn_interval", 5, 1.4, 1.0, 0.0))
	if not (harder < base_iv):
		failures.append("难度倍率提高应缩短间隔：1.4 → %.3f，基准 %.3f" % [harder, base_iv])


func _check_weighted_pick():
	var weights: Dictionary = {}
	var total := 0.0
	for entry in _pool(total_waves):
		if not (entry is Dictionary):
			continue
		var type_name := str(entry.get("type", ""))
		weights[type_name] = float(entry.get("weight", 0.0))
		total += float(entry.get("weight", 0.0))
	if weights.is_empty() or total <= 0.0:
		failures.append("第 %d 波的池子不可用于抽样" % total_waves)
		return

	var counts: Dictionary = {}
	for i in range(SAMPLE_COUNT):
		var picked := str(wave_manager.call("pick_enemy_type_for_wave", total_waves))
		counts[picked] = int(counts.get(picked, 0)) + 1

	# 每个池内类型都应出现（权重最低的约 2%，8000 次抽样必现）
	for type_name in weights:
		if int(counts.get(type_name, 0)) == 0:
			failures.append("第 %d 波抽样 %d 次，权重 %.3f 的 %s 一次都没出现" % [
				total_waves, SAMPLE_COUNT, float(weights[type_name]), type_name
			])
	# 抽样频率贴近权重比例。容差只抓「权重被忽略」这个量级的错误：
	# 若按等概率抽取，elite 会落在 1/13≈0.077 而期望 0.170，必然越界。
	for type_name in weights:
		var expected := float(weights[type_name]) / total
		var observed := float(int(counts.get(type_name, 0))) / float(SAMPLE_COUNT)
		# max() 是变参全局函数，返回 Variant，这里必须显式标注类型
		var tolerance: float = max(0.02, expected * 0.35)
		if abs(observed - expected) > tolerance:
			failures.append("第 %d 波 %s 的抽样频率 %.3f 偏离权重比例 %.3f 超过容差 %.3f" % [
				total_waves, type_name, observed, expected, tolerance
			])
	# 不得抽出池外类型
	for picked in counts:
		if not weights.has(picked):
			failures.append("抽出了池外类型: %s" % picked)


func _check_unknown_type_fallback():
	# 目录被写错（引用了不存在的敌人类型）时，消费端必须剔除该类型并回落兜底池，
	# 而不是把未知类型交给 Enemy.setup() 去做 ENEMY_TYPES[type] 直查。
	var entry = table.get(str(total_waves), {})
	if entry.is_empty():
		return
	var original = entry.get("pool", []).duplicate(true)
	entry["pool"] = [{"type": "definitely_not_a_real_enemy", "weight": 1.0}]

	var bad_pick := false
	var undefined_pick := ""
	for i in range(64):
		var picked := str(wave_manager.call("pick_enemy_type_for_wave", total_waves))
		if picked == "definitely_not_a_real_enemy":
			bad_pick = true
			break
		if not has_enemy_type(picked):
			undefined_pick = picked
			break
	entry["pool"] = original

	if bad_pick:
		failures.append("未定义的敌人类型不应被抽出")
	if not undefined_pick.is_empty():
		failures.append("回落后的类型仍未定义: %s" % undefined_pick)
	if _pool(total_waves).size() != original.size():
		failures.append("测试未正确还原第 %d 波的池子" % total_waves)


func _check_boss_wiring():
	# Boss 判据的唯一来源是目录的 boss 字段
	var expected_boss_waves := [5, 10, 15, 20]
	for w in range(1, total_waves + 1):
		main.wave = w
		var is_boss := bool(wave_manager.call("is_boss_wave"))
		if (w in expected_boss_waves) != is_boss:
			failures.append("第 %d 波的 is_boss_wave 应为 %s，实际 %s" % [
				w, str(w in expected_boss_waves), str(is_boss)
			])
		if is_boss and str(wave_manager.call("get_boss_type", w)).is_empty():
			failures.append("第 %d 波判为 Boss 波却取不到 Boss 类型" % w)
		if not is_boss and int(wave_manager.call("get_boss_count", w)) != 0:
			failures.append("第 %d 波非 Boss 波却给了 boss_count=%d" % [w, int(wave_manager.call("get_boss_count", w))])
	main.wave = 1

	# 终局双 Boss
	var final_count := int(wave_manager.call("get_boss_count", total_waves))
	if final_count != 2:
		failures.append("第 %d 波应为双 Boss，实际 boss_count=%d" % [total_waves, final_count])
	for w in [5, 10, 15]:
		if int(wave_manager.call("get_boss_count", w)) != 1:
			failures.append("第 %d 波应为单 Boss，实际 boss_count=%d" % [w, int(wave_manager.call("get_boss_count", w))])


# ─── F. 双 Boss 集成检查 ───
# 单元断言只能证明「目录里 boss_count = 2」，证明不了「真的刷出两只、血条交接正确」。
# 这一段真的推进到最后一波并杀掉 Boss，验证 波次表 → 生成 → 血条 的整条链路
# （多 Boss 血条交接是改造时新写的逻辑，属于最该被回归保护的部分）。

func _check_dual_boss_spawn():
	if main == null or not is_instance_valid(main):
		failures.append("双 Boss 检查需要有效的 Main 实例")
		return
	main.wave = total_waves - 1
	wave_manager.call("advance_wave")  # 内部会 +1，落在 total_waves
	_freeze_wave_spawning()
	await process_frame

	var bosses := _live_bosses()
	if bosses.size() != 2:
		failures.append("第 %d 波应刷出 2 只 Boss，实际 %d 只" % [total_waves, bosses.size()])
		return
	if is_equal_approx(bosses[0].position.x, bosses[1].position.x):
		failures.append("双 Boss 出场位置重合：x=%.1f" % bosses[0].position.x)
	if not main.hud.boss_bar_root.visible:
		failures.append("双 Boss 出场后血条应可见")

	# 杀掉一只：血条应交接给幸存者，而不是被隐藏
	bosses[0].take_damage(999999)
	await process_frame
	var survivors := _live_bosses()
	if survivors.size() != 1:
		failures.append("杀掉一只 Boss 后应剩 1 只，实际 %d 只" % survivors.size())
	elif not main.hud.boss_bar_root.visible:
		failures.append("仍有 Boss 存活时血条不应隐藏（多 Boss 血条交接失败）")

	# 杀掉最后一只：血条才隐藏
	if survivors.size() == 1:
		survivors[0].take_damage(999999)
		await process_frame
		if main.hud.boss_bar_root.visible:
			failures.append("所有 Boss 都被击杀后血条应隐藏")
		if not _live_bosses().is_empty():
			failures.append("所有 Boss 击杀后不应还有存活 Boss")


func _live_bosses() -> Array:
	var result: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if str(enemy.enemy_type) == "boss":
			result.append(enemy)
	return result
