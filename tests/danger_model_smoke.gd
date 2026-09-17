extends SceneTree

# Danger 0-5 难度模型冒烟测试（P4-3）
#
# 改造前只有三档（0=简单 0.7 / 1=普通 1.0 / 2=困难 1.4），难度经由
# `GameState.get_difficulty_multiplier()` 一个标量同时影响敌人强度与刷怪间隔。
# 本次升级为 Danger 0-5，每档三个维度：
#   ① 敌人强度倍率  DIFFICULTY_MULTIPLIERS   （HP / 接触伤害 / 移速）
#   ② 刷怪密度倍率  DANGER_SPAWN_MULTIPLIERS（越大越密）
#   ③ 额外精英概率  DANGER_ELITE_CHANCES    （叠加在波次表权重与玩家道具之上）
#
# 数值来源：Brotato Wiki《Danger Levels》
#   https://brotato.wiki.spellsandguns.com/index.php?title=Danger_Levels
#     D0/D1/D2 = 无属性强化；D3 = +12%；D4 = +26%；D5 = +40%（该档**总量**，非逐级叠加）
#   精英轴（wiki 按**轮次**描述，是阶梯）：D2/D3 = 1 轮、D4/D5 = 3 轮。
#     「轮次 → 概率」是本作的换算口径（1 轮/20 波 = 0.05、3 轮/20 波 = 0.15），
#     不是原版直给的数；换来的是 D2==D3、D4==D5 这个**相等关系**必须与来源一致。
#
# 本测试固定的不变量（六级**全档**覆盖，不做抽样）：
#   A. 模型形状：三张档位表都恰好覆盖 0..5，一个不多一个不少；
#   B. 逐档数值：与写死的期望表逐项相等，且与推导式自洽
#      （密度 = 1+(强度-1)×0.5；精英率 = 阶梯，见 C2）；
#   C. 权威锚点：D3/D4/D5 必须是原版 wiki 的 1.12/1.26/1.40，且 D1 与 D2 必须相等；
#   C2. 精英轴是**阶梯**：D2==D3（原版 1 轮）、D4==D5（原版 3 轮），并反向断言
#       「不得是每档 +5 个百分点的直线」（这是本项目踩过的「在真实值之间插中值」）；
#   D. 单调性：档位递增 ⇒ 敌人强度/密度/精英率 单调不减、刷怪间隔单调不增；
#   E. 消费端（读真实数值，不读表）：倍率真的落到敌人 HP/移速上、真的缩短刷怪间隔
#      （含 process_wave 的端到端回读）、真的抬高精英抽取门槛；
#   F. 反向断言：非法档位（-1/7/99）不崩且回退安全默认；难度不得改写波次表的精英权重；
#      Danger 1 必须是完全中性；
#   G. 兼容：旧三档→新档位的映射与其强度倍率一致；存档里没有难度字段。

const PASS_TAG := "DANGER_MODEL_SMOKE_PASS"
const FAIL_TAG := "DANGER_MODEL_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

const LEVELS := [0, 1, 2, 3, 4, 5]

# 期望值表：**独立于 GameState 写死**（不引用被测实现），这样模型被改坏时测试才会红。
const EXPECTED_ENEMY_MULT = { 0: 0.70, 1: 1.00, 2: 1.00, 3: 1.12, 4: 1.26, 5: 1.40 }
const EXPECTED_SPAWN_MULT = { 0: 0.85, 1: 1.00, 2: 1.00, 3: 1.06, 4: 1.13, 5: 1.20 }
# 精英轴是阶梯（原版按轮次：D2/D3 = 1 轮、D4/D5 = 3 轮），不是逐档递增的直线。
const EXPECTED_ELITE_CHANCE = { 0: 0.00, 1: 0.00, 2: 0.05, 3: 0.05, 4: 0.15, 5: 0.15 }
# 精英轴「每档 +5 个百分点」的直线假设（错误形态的快照）。
# 只用于反向断言：这两个值一旦出现就说明有人在真实值之间插了中值。
const LINEAR_ELITE_PROBES := [[3, 0.10], [5, 0.20]]

# 改造**前**那张三档表的原值（0=简单 0.7 / 1=普通 1.0 / 2=困难 1.4）。
# 这是旧实现的事实快照，用来校验 LEGACY_DIFFICULTY_TO_DANGER 是按**强度倍率**
# 而不是按档位序号做映射的（注意旧「困难」= 1.40，与新表 Danger 2 的 1.00 无关）。
const LEGACY_ENEMY_MULT = { 0: 0.70, 1: 1.00, 2: 1.40 }

# 必须**严格**缩短间隔的相邻档位对。
# 1→2 不在其中：原版 D0-D2 无属性强化 ⇒ 强度与密度都相同 ⇒ 间隔必须相等（单独断言）。
const STRICT_INTERVAL_PAIRS := [[0, 1], [2, 3], [3, 4], [4, 5]]

var failures: Array[String] = []
var game_state = null
var main = null
var wave_manager = null
var enemy_types: Dictionary = {}


func _init():
	call_deferred("_run")


func _run():
	seed(20260916)
	game_state = root.get_node("/root/GameState")
	game_state.selected_character = "normal"
	game_state.difficulty = 1
	game_state.endless_mode = false
	var audio_manager = root.get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		root.remove_child(audio_manager)
		audio_manager.queue_free()

	var packed = load("res://scenes/Main.tscn")
	if packed == null:
		_fail("Main 场景缺失")
		_report()
		return
	main = packed.instantiate()
	root.add_child(main)
	await process_frame

	wave_manager = main.get("wave_manager")
	if wave_manager == null:
		_fail("Main 应创建 WaveManager")
		_report()
		return
	_freeze_wave_spawning()
	enemy_types = wave_manager.call("enemy_types")
	if enemy_types.is_empty():
		_fail("取不到 Enemy.ENEMY_TYPES，消费端断言无法进行")

	_check_model_shape()
	_check_table_values()
	_check_authoritative_anchors()
	_check_elite_ladder()
	_check_monotonicity()
	_check_consumer_enemy_stats()
	_check_process_wave_uses_density()
	_check_consumer_elite_roll()
	_check_consumer_spawn_interval()
	_check_invalid_danger_fallback()
	_check_wave_table_untouched()
	_check_legacy_mapping_and_save()
	await _check_character_select_ui()

	game_state.difficulty = 1
	if is_instance_valid(main):
		main.queue_free()
	main = null
	for i in range(3):
		await process_frame
	_report()


func _fail(message: String):
	failures.append(message)


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
	# 让测试确定性：冻结波次计时/刷怪/树木/地雷，避免游戏自己的节奏干扰断言。
	wave_manager.spawn_timer = 9999.0
	wave_manager.tree_spawn_timer = 9999.0
	wave_manager.landmine_spawn_timer = 9999.0
	wave_manager.wave_timer = 9999.0


func _profile(danger: int) -> Dictionary:
	return game_state.call("get_danger_profile", danger)


# ─── A. 模型形状 ───

func _check_model_shape():
	var count := int(game_state.call("get_danger_level_count"))
	if count != LEVELS.size():
		_fail("档位数应为 %d（Danger 0-5），实际 %d" % [LEVELS.size(), count])
	_check_table_keys("DIFFICULTY_MULTIPLIERS", game_state.DIFFICULTY_MULTIPLIERS)
	_check_table_keys("DANGER_SPAWN_MULTIPLIERS", game_state.DANGER_SPAWN_MULTIPLIERS)
	_check_table_keys("DANGER_ELITE_CHANCES", game_state.DANGER_ELITE_CHANCES)
	for d in LEVELS:
		if not bool(_profile(d).get("is_valid", false)):
			_fail("Danger %d 应被判为合法档位" % d)
	if bool(_profile(LEVELS.size()).get("is_valid", true)):
		_fail("Danger %d 已越界，不应被判为合法档位" % LEVELS.size())


func _check_table_keys(table_name: String, table):
	if not (table is Dictionary):
		_fail("GameState.%s 应是字典，实际 %s" % [table_name, str(typeof(table))])
		return
	var keys: Array = table.keys()
	keys.sort()
	if keys != LEVELS:
		_fail("%s 的档位集合应为 %s，实际 %s" % [table_name, str(LEVELS), str(keys)])


# ─── B. 逐档数值 ───

func _check_table_values():
	for d in LEVELS:
		var profile := _profile(d)
		var enemy := float(profile["enemy_multiplier"])
		var spawn := float(profile["spawn_multiplier"])
		var elite := float(profile["elite_chance"])
		if not is_equal_approx(enemy, float(EXPECTED_ENEMY_MULT[d])):
			_fail("Danger %d 敌人强度倍率：期望 %.4f，实际 %.4f" % [d, float(EXPECTED_ENEMY_MULT[d]), enemy])
		if not is_equal_approx(spawn, float(EXPECTED_SPAWN_MULT[d])):
			_fail("Danger %d 刷怪密度倍率：期望 %.4f，实际 %.4f" % [d, float(EXPECTED_SPAWN_MULT[d]), spawn])
		if not is_equal_approx(elite, float(EXPECTED_ELITE_CHANCE[d])):
			_fail("Danger %d 额外精英概率：期望 %.4f，实际 %.4f" % [d, float(EXPECTED_ELITE_CHANCE[d]), elite])
		# 区间门：任一档跑出这个范围都说明推导被改坏了
		if enemy < 0.60 or enemy > 1.50:
			_fail("Danger %d 敌人强度倍率 %.4f 越出合理区间 [0.60, 1.50]" % [d, enemy])
		if spawn < 0.70 or spawn > 1.30:
			_fail("Danger %d 刷怪密度倍率 %.4f 越出合理区间 [0.70, 1.30]" % [d, spawn])
		if elite < 0.0 or elite > 0.25:
			_fail("Danger %d 额外精英概率 %.4f 越出合理区间 [0.00, 0.25]" % [d, elite])
		# 推导式自洽：与上面的字面量表互为校验，只改一处就会在这里露出来
		var derived_spawn: float = 1.0 + (enemy - 1.0) * 0.5
		if not is_equal_approx(spawn, derived_spawn):
			_fail("Danger %d 密度应满足 1+(强度-1)*0.5 = %.4f，实际 %.4f" % [d, derived_spawn, spawn])
		var derived_elite := _derived_elite_chance(d)
		if not is_equal_approx(elite, derived_elite):
			_fail("Danger %d 精英率应满足阶梯口径 = %.4f，实际 %.4f" % [d, derived_elite, elite])


# 本作对精英轴的换算口径（**阶梯**，非直线）：
#   原版轮次（Brotato Wiki）：D2/D3 = 1 轮、D4/D5 = 3 轮；D0/D1 无精英机制。
#   按 20 波折算：1 轮 → 0.05、3 轮 → 0.15。
# 故意写成与 GameState 不同的形状（这里用 if 分支直白表达「台阶」），
# 这样有人把它改成 0.05*(d-1) 的直线时，B 项与 C2 项会同时变红。
func _derived_elite_chance(danger: int) -> float:
	if danger <= 1:
		return 0.0
	if danger <= 3:
		return 0.05
	return 0.15


# ─── C. 权威锚点（原版 wiki） ───

func _check_authoritative_anchors():
	var wiki_enemy := {1: 1.00, 2: 1.00, 3: 1.12, 4: 1.26, 5: 1.40}
	for d in wiki_enemy:
		var enemy := float(_profile(d)["enemy_multiplier"])
		if not is_equal_approx(enemy, float(wiki_enemy[d])):
			_fail("原版锚点：Danger %d 敌人强度应为 %.2f（Brotato Wiki《Danger Levels》），实际 %.4f" % [
				d, float(wiki_enemy[d]), enemy
			])
	# D1 == D2 是原版设计（D0-D2 无属性强化），不是漏填。显式断言「相等」，
	# 免得后人把它当 bug「修」成递增。
	var d1 := float(_profile(1)["enemy_multiplier"])
	var d2 := float(_profile(2)["enemy_multiplier"])
	if not is_equal_approx(d1, d2):
		_fail("原版 D0-D2 无属性强化 ⇒ D1 与 D2 的强度倍率必须相等，实际 %.4f vs %.4f" % [d1, d2])
	# 界面档位表必须齐备：CharacterSelect 建卡片时会按档位直查 DANGER_INFO，
	# 少一项就是运行时取空。这里用 get_script_constant_map() 读脚本常量
	# （脚本资源本身不支持 `script.CONST` 那种实例式取法）。
	var char_select_script = load("res://scripts/CharacterSelect.gd")
	if char_select_script == null:
		_fail("取不到 CharacterSelect.gd，无法验证界面档位表覆盖")
	else:
		var constants: Dictionary = char_select_script.get_script_constant_map()
		var danger_info = constants.get("DANGER_INFO", {})
		if not (danger_info is Dictionary) or danger_info.size() != LEVELS.size():
			_fail("CharacterSelect.DANGER_INFO 应覆盖 %d 档，实际 %s" % [
				LEVELS.size(), str(danger_info.keys()) if danger_info is Dictionary else str(danger_info)
			])
		else:
			for d in LEVELS:
				if not danger_info.has(d):
					_fail("CharacterSelect.DANGER_INFO 缺少 Danger %d 的展示条目" % d)


# ─── C2. 精英轴是阶梯（正向相等关系 + 反向「不是直线」） ───

func _check_elite_ladder():
	# 原版按**轮次**描述，是阶梯：D2/D3 = 1 轮、D4/D5 = 3 轮。
	# 显式钉住这两组相等关系 —— 与强度轴的 D1==D2 同一种写法，
	# 免得后人把它当 bug「修」成逐档递增。
	for pair in [[2, 3], [4, 5]]:
		var low_danger := int(pair[0])
		var high_danger := int(pair[1])
		var low := float(_profile(low_danger)["elite_chance"])
		var high := float(_profile(high_danger)["elite_chance"])
		if not is_equal_approx(low, high):
			_fail("原版精英轴是阶梯（同为 1 轮 / 同为 3 轮）：Danger %d 与 %d 的额外精英率必须相等，实际 %.4f vs %.4f" % [
				low_danger, high_danger, low, high
			])
	# 台阶本身必须存在：D2 引入精英、D4 加码精英（原版原文的「1 轮 → 3 轮」）
	if not (float(_profile(2)["elite_chance"]) > float(_profile(1)["elite_chance"])):
		_fail("Danger 2 起应引入额外精英（原版「精英/虫群登场」）：%.4f vs Danger 1 的 %.4f" % [
			float(_profile(2)["elite_chance"]), float(_profile(1)["elite_chance"])
		])
	if not (float(_profile(4)["elite_chance"]) > float(_profile(3)["elite_chance"])):
		_fail("Danger 4 起应加码额外精英（原版「更多精英/虫群」）：%.4f vs Danger 3 的 %.4f" % [
			float(_profile(4)["elite_chance"]), float(_profile(3)["elite_chance"])
		])
	# 反向断言：**不得**是「每档 +5 个百分点」的直线。直线会把 D3 算成 0.10、D5 算成 0.20 ——
	# 这两个值是原版数据里不存在的，一旦出现就是「在真实值之间插中值」。
	for probe in LINEAR_ELITE_PROBES:
		var danger := int(probe[0])
		var linear_value := float(probe[1])
		var actual := float(_profile(danger)["elite_chance"])
		if is_equal_approx(actual, linear_value):
			_fail("Danger %d 的额外精英率不应是线性插值/外推值 %.2f（原版是阶梯：D2==D3=1 轮、D4==D5=3 轮），实际 %.4f" % [
				danger, linear_value, actual
			])


# ─── D. 单调性 ───

func _check_monotonicity():
	var prev_enemy := -1.0
	var prev_spawn := -1.0
	var prev_elite := -1.0
	for d in LEVELS:
		var profile := _profile(d)
		var enemy := float(profile["enemy_multiplier"])
		var spawn := float(profile["spawn_multiplier"])
		var elite := float(profile["elite_chance"])
		if enemy < prev_enemy - 0.000001:
			_fail("敌人强度应随档位单调不减：Danger %d 的 %.4f < 上一档 %.4f" % [d, enemy, prev_enemy])
		if spawn < prev_spawn - 0.000001:
			_fail("刷怪密度应随档位单调不减：Danger %d 的 %.4f < 上一档 %.4f" % [d, spawn, prev_spawn])
		if elite < prev_elite - 0.000001:
			_fail("额外精英率应随档位单调不减：Danger %d 的 %.4f < 上一档 %.4f" % [d, elite, prev_elite])
		prev_enemy = enemy
		prev_spawn = spawn
		prev_elite = elite


# ─── E. 消费端 ───

func _check_consumer_enemy_stats():
	# 读的是**敌人实例上的真实数值**，不是模型表 —— 验的是「倍率真的走到了 Enemy.setup」。
	if enemy_types.is_empty():
		return
	var probe_wave := 20
	var probe_type := "normal"
	if not enemy_types.has(probe_type):
		_fail("敌人类型表缺少 %s，消费端断言无法进行" % probe_type)
		return
	var data: Dictionary = enemy_types[probe_type]
	var hp_m := float(data["hp_m"])
	var base_spd := float(data["spd"])
	var measured: Dictionary = {}
	for d in LEVELS:
		game_state.difficulty = d
		var enemy = main.get_enemy()
		if enemy == null:
			_fail("Danger %d 取不到敌人实例" % d)
			continue
		enemy.setup(probe_type, probe_wave)
		measured[d] = {
			"hp": int(enemy.hp),
			"max_hp": int(enemy.max_hp),
			"speed": float(enemy.base_speed),
			"damage": int(enemy.contact_damage),
		}
		main.recycle_enemy(enemy)
	if measured.size() != LEVELS.size():
		return
	for d in LEVELS:
		var expected_hp := int((2 + probe_wave) * hp_m * float(EXPECTED_ENEMY_MULT[d]))
		var expected_speed := (base_spd + probe_wave * 2.0) * float(EXPECTED_ENEMY_MULT[d])
		var actual_hp := int(measured[d]["hp"])
		var actual_speed := float(measured[d]["speed"])
		if actual_hp != expected_hp:
			_fail("Danger %d 敌人 HP 应随倍率缩放：期望 %d（= int((2+%d)×%.1f×%.2f)），实际 %d" % [
				d, expected_hp, probe_wave, hp_m, float(EXPECTED_ENEMY_MULT[d]), actual_hp
			])
		if int(measured[d]["max_hp"]) != actual_hp:
			_fail("Danger %d 敌人 max_hp 应与 hp 同步，实际 hp=%d max_hp=%d" % [
				d, actual_hp, int(measured[d]["max_hp"])
			])
		if not is_equal_approx(actual_speed, expected_speed):
			_fail("Danger %d 敌人移速应随倍率缩放：期望 %.3f（= (%.1f+%d×2)×%.2f），实际 %.3f" % [
				d, expected_speed, base_spd, probe_wave, float(EXPECTED_ENEMY_MULT[d]), actual_speed
			])
	# 实例数值的单调性（HP / 接触伤害都不得随档位下降）
	for i in range(1, LEVELS.size()):
		var prev: int = LEVELS[i - 1]
		var cur: int = LEVELS[i]
		if int(measured[cur]["hp"]) < int(measured[prev]["hp"]):
			_fail("敌人 HP 应随档位单调不减：Danger %d 的 %d < Danger %d 的 %d" % [
				cur, int(measured[cur]["hp"]), prev, int(measured[prev]["hp"])
			])
		if float(measured[cur]["speed"]) < float(measured[prev]["speed"]) - 0.000001:
			_fail("敌人移速应随档位单调不减：Danger %d 的 %.3f < Danger %d 的 %.3f" % [
				cur, float(measured[cur]["speed"]), prev, float(measured[prev]["speed"])
			])
		if int(measured[cur]["damage"]) < int(measured[prev]["damage"]):
			_fail("敌人接触伤害应随档位单调不减：Danger %d 的 %d < Danger %d 的 %d" % [
				cur, int(measured[cur]["damage"]), prev, int(measured[prev]["damage"])
			])


func _check_process_wave_uses_density():
	# 端到端：判断 WaveManager.process_wave 是否真的把「密度倍率」用上了。
	# 判据不看代码 —— 只把它写回 spawn_timer 的值读出来比对。
	var wave := 1
	var measured: Dictionary = {}
	for d in [1, 5]:
		game_state.difficulty = d
		wave_manager.spawn_timer = 0.0
		wave_manager.process_wave(0.001)
		measured[d] = float(wave_manager.spawn_timer)
		wave_manager.spawn_timer = 9999.0
		var diff_mult: float = float(EXPECTED_ENEMY_MULT[d]) * float(EXPECTED_SPAWN_MULT[d])
		var expected := float(wave_manager.call("get_spawn_interval", wave, diff_mult, 1.0, 0.0))
		if not is_equal_approx(float(measured[d]), expected):
			_fail("Danger %d 下 process_wave 写回的刷怪间隔应含密度倍率：期望 %.4f，实际 %.4f" % [
				d, expected, float(measured[d])
			])
	if not (float(measured[5]) < float(measured[1]) - 0.000001):
		_fail("Danger 5 的实际刷怪间隔应短于 Danger 1：%.4f vs %.4f" % [
			float(measured[5]), float(measured[1])
		])
	game_state.difficulty = 1


func _check_consumer_elite_roll():
	if main.player == null or not is_instance_valid(main.player):
		_fail("Main 应暴露 player，精英抽取断言无法进行")
		return
	# 下面用固定 roll 值比对门槛，前提是「普通人」不带 additional_elite_chance。
	# 若不是，说明起始道具改了 —— 显式报出来，而不是让边界断言悄悄失效。
	var item_chance := float(main.player.get("additional_elite_chance"))
	if not is_equal_approx(item_chance, 0.0):
		_fail("本测试假定「普通人」的 additional_elite_chance 为 0（用于定位抽取门槛），实际 %.4f" % item_chance)
		return
	# 基准档必须完全中性：任何 roll 都不额外刷精英
	game_state.difficulty = 1
	if int(wave_manager.call("roll_additional_elite_spawn_count", 0.0)) != 0:
		_fail("Danger 1 的额外精英率应为 0：roll=0.00 却刷出了精英")
	# 逐档门槛（读真实抽取入口，不读模型的表，期望值取本测试自己的快照）
	for d in [2, 3, 4, 5]:
		game_state.difficulty = d
		var threshold := float(EXPECTED_ELITE_CHANCE[d])
		if int(wave_manager.call("roll_additional_elite_spawn_count", threshold - 0.01)) != 1:
			_fail("Danger %d 额外精英门槛应为 %.2f：roll=%.2f 应命中" % [d, threshold, threshold - 0.01])
		if int(wave_manager.call("roll_additional_elite_spawn_count", threshold + 0.01)) != 0:
			_fail("Danger %d 额外精英门槛应为 %.2f：roll=%.2f 不应命中" % [d, threshold, threshold + 0.01])
	# 台阶在**消费端**也必须成立：D2/D3、D4/D5 在同一 roll 下行为必须逐点一致。
	# 上面那圈只证明了两档各自的门槛值，这一圈证明它们真的是同一级台阶。
	for pair in [[2, 3], [4, 5]]:
		var low_danger := int(pair[0])
		var high_danger := int(pair[1])
		for roll in [0.01, 0.04, 0.06, 0.12, 0.16, 0.30]:
			game_state.difficulty = low_danger
			var low_result := int(wave_manager.call("roll_additional_elite_spawn_count", roll))
			game_state.difficulty = high_danger
			var high_result := int(wave_manager.call("roll_additional_elite_spawn_count", roll))
			if low_result != high_result:
				_fail("精英轴是阶梯：Danger %d 与 %d 在 roll=%.2f 下的抽取结果应一致，实际 %d vs %d" % [
					low_danger, high_danger, roll, low_result, high_result
				])
	# 既有契约：Danger 1 下精英率只由玩家道具决定（Candy Bag +10% ⇒ 门槛 0.10）
	game_state.difficulty = 1
	main.player.additional_elite_chance = 0.10
	if int(wave_manager.call("roll_additional_elite_spawn_count", 0.09)) != 1:
		_fail("Danger 1 下 Candy Bag(+10%) 的门槛应为 0.10：roll=0.09 应命中")
	if int(wave_manager.call("roll_additional_elite_spawn_count", 0.11)) != 0:
		_fail("Danger 1 下 Candy Bag(+10%) 的门槛应为 0.10：roll=0.11 不应命中")
	main.player.additional_elite_chance = 0.0


func _check_consumer_spawn_interval():
	# 逐档间隔：与独立推导的期望值逐项相等 + 单调不增 + 指定档位对严格缩短。
	# 第 5 波基础间隔 1.5，远高于 MIN_SPAWN_INTERVAL，不会被下界掩盖曲线。
	_check_interval_curve(5, true)
	# 第 20 波基础间隔已贴在下界附近，只要求「不增 + 不破下界」，
	# 避免把下界钳制误判成缺陷。
	_check_interval_curve(20, false)


func _check_interval_curve(wave: int, require_strict_steps: bool):
	var floor_value := float(wave_manager.MIN_SPAWN_INTERVAL)
	var base_interval := float(wave_manager.call("get_spawn_interval", wave, 1.0, 1.0, 0.0))
	if base_interval <= 0.0:
		_fail("第 %d 波的基础间隔应为正值，实际 %.4f" % [wave, base_interval])
		return
	var intervals: Dictionary = {}
	var prev := INF
	var prev_danger := -1
	for d in LEVELS:
		var diff_mult: float = float(EXPECTED_ENEMY_MULT[d]) * float(EXPECTED_SPAWN_MULT[d])
		var expected: float = max(floor_value, base_interval / diff_mult)
		var actual := float(wave_manager.call("get_spawn_interval", wave, diff_mult, 1.0, 0.0))
		intervals[d] = actual
		if not is_equal_approx(actual, expected):
			_fail("第 %d 波 Danger %d 的刷怪间隔：期望 %.4f，实际 %.4f" % [wave, d, expected, actual])
		if actual > prev + 0.000001:
			_fail("刷怪间隔应随档位单调不增：第 %d 波 Danger %d 的 %.4f > Danger %d 的 %.4f" % [
				wave, d, actual, prev_danger, prev
			])
		prev = actual
		prev_danger = d
	# 原版 D0-D2 无属性强化 ⇒ D1 与 D2 的间隔必须相等
	if not is_equal_approx(float(intervals[1]), float(intervals[2])):
		_fail("第 %d 波 Danger 1 与 Danger 2 的间隔应相等（原版 D0-D2 无强化）：%.4f vs %.4f" % [
			wave, float(intervals[1]), float(intervals[2])
		])
	if require_strict_steps:
		for pair in STRICT_INTERVAL_PAIRS:
			var low := float(intervals[int(pair[0])])
			var high := float(intervals[int(pair[1])])
			if not (high < low - 0.000001):
				_fail("第 %d 波 Danger %d→%d 的刷怪间隔应严格缩短：%.4f → %.4f" % [
					wave, int(pair[0]), int(pair[1]), low, high
				])


# ─── F. 反向断言 ───

func _check_invalid_danger_fallback():
	for bad in [-1, 7, 99]:
		var profile := _profile(bad)
		if bool(profile.get("is_valid", true)):
			_fail("非法档位 %d 不应被判为合法" % bad)
		if not is_equal_approx(float(profile["enemy_multiplier"]), 1.0):
			_fail("非法档位 %d 的敌人强度应回退中性值 1.0，实际 %.4f" % [bad, float(profile["enemy_multiplier"])])
		if not is_equal_approx(float(profile["spawn_multiplier"]), 1.0):
			_fail("非法档位 %d 的密度应回退 1.0（不改节奏），实际 %.4f" % [bad, float(profile["spawn_multiplier"])])
		if not is_equal_approx(float(profile["elite_chance"]), 0.0):
			_fail("非法档位 %d 的精英率应回退 0.0（不额外刷精英），实际 %.4f" % [bad, float(profile["elite_chance"])])
	var saved := int(game_state.difficulty)
	for bad in [-1, 7]:
		game_state.difficulty = bad
		# 与改造前 `.get(difficulty, 1.0)` 的语义逐字一致：越界回退中性值，
		# 而不是悄悄夹到最近的合法档（那会让「非法值」变成一档真实难度）。
		if not is_equal_approx(float(game_state.call("get_difficulty_multiplier")), 1.0):
			_fail("非法难度 %d 下 get_difficulty_multiplier() 应回退 1.0，实际 %.4f" % [
				bad, float(game_state.call("get_difficulty_multiplier"))
			])
		if not is_equal_approx(float(game_state.call("get_danger_spawn_multiplier")), 1.0):
			_fail("非法难度 %d 下 get_danger_spawn_multiplier() 应回退 1.0，实际 %.4f" % [
				bad, float(game_state.call("get_danger_spawn_multiplier"))
			])
		if not is_equal_approx(float(game_state.call("get_danger_elite_chance")), 0.0):
			_fail("非法难度 %d 下 get_danger_elite_chance() 应回退 0.0，实际 %.4f" % [
				bad, float(game_state.call("get_danger_elite_chance"))
			])
		# 消费端不得崩：非法档位下仍应算出有限、正的刷怪间隔
		var diff_mult: float = float(game_state.call("get_difficulty_multiplier")) * float(game_state.call("get_danger_spawn_multiplier"))
		var interval := float(wave_manager.call("get_spawn_interval", 5, diff_mult, 1.0, 0.0))
		if not is_finite(interval) or interval <= 0.0:
			_fail("非法难度 %d 下刷怪间隔应仍为有限正值，实际 %s" % [bad, str(interval)])
	game_state.difficulty = saved


func _check_wave_table_untouched():
	# 反向断言：难度层只许在波次表之外做加法，不得改写精英权重。
	# （第 12 波 7% → 第 20 波 16% 是 P4-1 的成果。）
	if not bool(wave_manager.call("has_wave_table")):
		_fail("WaveManager 未加载波次表，无法验证「难度不改写波次表」")
		return
	game_state.difficulty = 1
	var w12: Dictionary = wave_manager.call("wave_pool_weights", 12)
	var w20: Dictionary = wave_manager.call("wave_pool_weights", 20)
	var baseline_12 := float(w12.get("elite", 0.0))
	var baseline_20 := float(w20.get("elite", 0.0))
	if baseline_12 <= 0.0:
		_fail("第 12 波应已有精英权重（P4-1 的成果），实际 %.3f —— 下面的比对会失去意义" % baseline_12)
	if baseline_20 <= baseline_12:
		_fail("第 20 波的精英权重应高于第 12 波：%.3f vs %.3f" % [baseline_20, baseline_12])
	for d in LEVELS:
		game_state.difficulty = d
		var cur12: Dictionary = wave_manager.call("wave_pool_weights", 12)
		var cur20: Dictionary = wave_manager.call("wave_pool_weights", 20)
		if not is_equal_approx(float(cur12.get("elite", 0.0)), baseline_12):
			_fail("难度 %d 改写了第 12 波的精英权重：%.4f → %.4f" % [
				d, baseline_12, float(cur12.get("elite", 0.0))
			])
		if not is_equal_approx(float(cur20.get("elite", 0.0)), baseline_20):
			_fail("难度 %d 改写了第 20 波的精英权重：%.4f → %.4f" % [
				d, baseline_20, float(cur20.get("elite", 0.0))
			])
	game_state.difficulty = 1


# ─── G. 兼容 ───

func _check_legacy_mapping_and_save():
	var legacy = game_state.LEGACY_DIFFICULTY_TO_DANGER
	if not (legacy is Dictionary):
		_fail("GameState 应暴露 LEGACY_DIFFICULTY_TO_DANGER")
	else:
		for old in [0, 1, 2]:
			if not legacy.has(old):
				_fail("旧难度 %d 缺少新档位映射" % old)
				continue
			var new_danger := int(legacy[old])
			if not bool(game_state.call("is_valid_danger", new_danger)):
				_fail("旧难度 %d 映射到了非法新档位 %d" % [old, new_danger])
				continue
			# 映射判据是**敌人强度倍率**：旧值 n 与新值 m 的强度必须相等，
			# 否则 Main.gd 里按旧档位写死的判据换算之后语义就变了。
			# 比的是「改造前那张三档表的原值」，不是新表里同序号的值。
			var old_mult := float(LEGACY_ENEMY_MULT[old])
			var new_mult := float(_profile(new_danger)["enemy_multiplier"])
			if not is_equal_approx(old_mult, new_mult):
				_fail("旧难度 %d（强度 %.2f）映射到 Danger %d（强度 %.2f），强度不一致" % [
					old, old_mult, new_danger, new_mult
				])
		if int(legacy.get(2, -1)) != int(game_state.LEGACY_HARD_DANGER):
			_fail("旧「困难」的落点 %d 应与 LEGACY_HARD_DANGER=%d 一致" % [
				int(legacy.get(2, -1)), int(game_state.LEGACY_HARD_DANGER)
			])
	# 存档兼容：难度值不落存档 ⇒ 旧 0/1/2 无需迁移（这是核实结论，不是假设）。
	var save_system = root.get_node_or_null("/root/SaveSystem")
	if save_system == null:
		_fail("应存在 SaveSystem，便于核实难度是否落存档")
	else:
		var saved_data: Dictionary = save_system.call("get_data")
		if saved_data.has("difficulty"):
			_fail("SaveSystem 落了 difficulty 字段（%s）；旧 0/1/2 需要迁移映射，请补迁移逻辑" % str(saved_data["difficulty"]))


# ─── 界面（题目要求：3 个按钮 → 6 个，且要显示每档的关键差异） ───

func _check_character_select_ui():
	var scene = load("res://scenes/CharacterSelect.tscn")
	if scene == null:
		_fail("CharacterSelect 场景缺失")
		return
	var select = scene.instantiate()
	root.add_child(select)
	await process_frame

	var tiles = select.get("danger_tiles")
	if not (tiles is Dictionary):
		_fail("CharacterSelect 应暴露 danger_tiles 映射")
		tiles = {}
	elif tiles.size() != LEVELS.size():
		_fail("难度卡应有 %d 张（Danger 0-5），实际 %d" % [LEVELS.size(), tiles.size()])
	for d in LEVELS:
		if not tiles.has(d):
			_fail("难度卡缺少 Danger %d" % d)

	var hints = select.get("danger_hint_labels")
	if not (hints is Dictionary) or hints.size() != LEVELS.size():
		_fail("每档都应有差异提示标签（期望 %d 个），实际 %d" % [
			LEVELS.size(), hints.size() if hints is Dictionary else -1
		])
	else:
		for d in LEVELS:
			var hint_label: Label = hints[d]
			var text := str(hint_label.text)
			if text.strip_edges().is_empty():
				_fail("Danger %d 的提示为空（只写「Danger N」信息量为零）" % d)
			# 提示必须同时讲清三个维度，缺一项就等于玩家无法据此决策
			for token in ["敌人", "精英", "密度"]:
				if not text.contains(token):
					_fail("Danger %d 的提示缺少「%s」：%s" % [d, token, text.replace("\n", " / ")])

	# 选中态必须表达在**边框 + 底色 + 字体色**上，且不得用 modulate
	# （modulate 是乘算且作用于整棵子树，会把名称与提示文字一起压暗 —— 本项目踩过）。
	var saved := int(game_state.difficulty)
	game_state.difficulty = 3
	select.call("_refresh_danger")
	var styles = select.get("danger_styles")
	if not (styles is Dictionary) or not styles.has(3) or not styles.has(1):
		_fail("特性未导出难度卡样式，无法验证选中态表达")
	else:
		var selected_style: StyleBoxFlat = styles[3]
		var idle_style: StyleBoxFlat = styles[1]
		if selected_style.border_width_top <= idle_style.border_width_top:
			_fail("选中的难度卡边框应更粗：选中 %d vs 未选中 %d" % [
				selected_style.border_width_top, idle_style.border_width_top
			])
		if selected_style.border_color == idle_style.border_color:
			_fail("选中的难度卡边框色应与未选中不同（否则选中态看不出来）")
		if selected_style.bg_color == idle_style.bg_color:
			_fail("选中的难度卡底色应与未选中不同")
	for d in tiles:
		var tile: Control = tiles[d]
		if tile.modulate != Color.WHITE:
			_fail("难度卡 Danger %d 用了 modulate 表达状态（会把文字一起压暗）：%s" % [d, str(tile.modulate)])

	# 非法档位不得被界面接受；合法档位必须被接受并即时刷新
	var before := int(game_state.difficulty)
	select.call("_on_danger_selected", LEVELS.size())
	if int(game_state.difficulty) != before:
		_fail("界面应拒绝非法档位：期望仍为 %d，实际 %d" % [before, int(game_state.difficulty)])
	select.call("_on_danger_selected", 4)
	if int(game_state.difficulty) != 4:
		_fail("界面应接受合法档位 Danger 4，实际 %d" % int(game_state.difficulty))
	game_state.difficulty = saved

	root.remove_child(select)
	select.free()
