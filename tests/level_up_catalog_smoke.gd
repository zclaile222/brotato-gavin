extends SceneTree

# 波末四选一目录冒烟测试（P2-2）
#
# 背景：四选一原先由 UpgradeChoiceRules.CHOICE_POOL 硬编码 8 种属性、无 tier、
# level/luck 参数被忽略，而 data/brotato/upgrades.json 只有 3 条且无任何调用方。
# 2026-09-15 起四选一改为目录驱动（25 属性 × 4 tier，按波次分档）。
#
# 本测试固定：
#   A. 目录形状：25 属性 × 4 tier，属性名均受运行时支持，无空转项；
#   B. 波次分档：低阶随波次退场、高阶随波次解锁；
#   C. generate_choices：恒返回 4 项、属性互不重复、字段完整、且不违反波次门槛；
#   D. 幸运把权重推向高阶；
#   E. 目录里每个属性都能真正落到某个 Player 属性上。

const PASS_TAG := "LEVEL_UP_CATALOG_SMOKE_PASS"
const FAIL_TAG := "LEVEL_UP_CATALOG_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 15
const EXPECTED_STAT_COUNT := 25
const TIERS_PER_STAT := 4

# 目录属性 → 应用后应当发生变化的 Player 属性。
# 若目录新增了属性而这里没跟上，本测试会直接失败，强制补齐映射。
const STAT_PROPERTY_MAP := {
	"max_hp": "max_hp",
	"hp_regeneration": "hp_regen",
	"armor": "armor",
	"speed_percent": "speed",
	"attack_speed_percent": "fire_rate_multiplier",
	"damage_percent": "damage_percent_bonus",
	"melee_damage": "melee_damage_bonus",
	"ranged_damage": "ranged_damage_bonus",
	"elemental_damage": "elemental_damage_bonus",
	"engineering": "engineering_bonus",
	"crit_chance": "crit_chance",
	"lifesteal": "lifesteal",
	"luck": "luck",
	"dodge": "dodge_chance",
	"harvesting": "gold_per_wave",
	"range": "range_bonus",
	"knockback": "knockback_bonus",
	"consumable_heal": "consumable_heal_bonus",
	"xp_gain_percent": "xp_boost",
	"pickup_range_percent": "magnet_range",
	"item_price_percent": "item_price_percent",
	"reroll_price_percent": "reroll_price_percent",
	"recycling_materials_percent": "recycling_materials_percent",
	"boss_elite_damage_percent": "boss_elite_damage_percent",
	"materials_dropped_percent": "materials_dropped_percent",
}

var failures: Array[String] = []
var _data = null
var _rules = null


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

	_data = load("res://scripts/BrotatoData.gd").new()
	var errors = _data.load_catalog()
	if not errors.is_empty():
		failures.append("Brotato 目录加载失败: " + str(errors))
		_report()
		return
	_rules = load("res://scripts/UpgradeChoiceRules.gd").new()

	_check_catalog_shape()
	_check_wave_gating()
	_check_generate_choices()
	_check_luck_bias()
	await _check_every_stat_applies()
	await _check_end_to_end_level_up()

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


func _check_catalog_shape():
	var validation_errors = _data.validate()
	for error in validation_errors:
		failures.append("目录校验未通过: " + str(error))

	var all_entries = _data.get_level_up_choices(0)
	if all_entries.is_empty():
		failures.append("升级目录为空（get_level_up_choices 返回空）")
		return
	if all_entries.size() != EXPECTED_STAT_COUNT * TIERS_PER_STAT:
		failures.append("升级目录应为 %d 条（%d 属性 × %d tier），实际 %d" % [
			EXPECTED_STAT_COUNT * TIERS_PER_STAT, EXPECTED_STAT_COUNT, TIERS_PER_STAT, all_entries.size()
		])

	var by_stat := {}
	for entry in all_entries:
		by_stat[entry.stat] = int(by_stat.get(entry.stat, 0)) + 1
	if by_stat.size() != EXPECTED_STAT_COUNT:
		failures.append("升级目录应覆盖 %d 种属性，实际 %d" % [EXPECTED_STAT_COUNT, by_stat.size()])
	for stat in by_stat:
		if int(by_stat[stat]) != TIERS_PER_STAT:
			failures.append("属性 %s 的 tier 数应为 %d，实际 %d" % [stat, TIERS_PER_STAT, by_stat[stat]])

	for entry in all_entries:
		var stat = str(entry.stat)
		if stat not in _data.RUNTIME_ITEM_STATS:
			failures.append("属性 %s 不受运行时支持（不在 RUNTIME_ITEM_STATS）" % stat)
		if not STAT_PROPERTY_MAP.has(stat):
			failures.append("属性 %s 缺少测试映射，请补 STAT_PROPERTY_MAP" % stat)
		if str(entry.get("name", "")).is_empty() or str(entry.get("desc", "")).is_empty():
			failures.append("条目 %s 缺少 name/desc，HUD 无法渲染" % str(entry.get("id", "?")))
		if float(entry.get("weight", 0.0)) <= 0.0:
			failures.append("条目 %s 的权重应大于 0" % str(entry.get("id", "?")))
		if float(entry.get("value", 0.0)) == 0.0:
			failures.append("条目 %s 的数值为 0，应用后不会产生任何变化" % str(entry.get("id", "?")))


func _check_wave_gating():
	# 门槛定义：tier1 w1-6、tier2 w1-12、tier3 w4+、tier4 w8+
	# 因此各边界波次的档位组合如下（每个边界都断言到）
	_assert_wave_tiers(1, [1, 2])    # 开局：只有前两阶
	_assert_wave_tiers(4, [1, 2, 3])  # tier3 解锁
	_assert_wave_tiers(6, [1, 2, 3])  # tier1 的最后可用波次
	_assert_wave_tiers(7, [2, 3])     # tier1 退场
	_assert_wave_tiers(8, [2, 3, 4])  # tier4 解锁
	_assert_wave_tiers(12, [2, 3, 4])  # tier2 的最后可用波次
	_assert_wave_tiers(13, [3, 4])    # tier2 退场，只剩高阶
	_assert_wave_tiers(20, [3, 4])


func _assert_wave_tiers(wave: int, expected: Array):
	var entries = _data.get_level_up_choices(wave)
	if entries.is_empty():
		failures.append("第 %d 波没有任何升级选项" % wave)
		return
	var seen := {}
	for entry in entries:
		seen[int(entry.tier)] = true
	var actual = seen.keys()
	actual.sort()
	if actual != expected:
		failures.append("第 %d 波的 tier 档位应为 %s，实际 %s" % [wave, str(expected), str(actual)])


func _check_generate_choices():
	seed(20260915)
	for wave in [1, 7, 20]:
		var allowed = _data.get_level_up_choices(wave)
		var allowed_ids := {}
		for entry in allowed:
			allowed_ids[str(entry.id)] = true
		for draw in range(60):
			var choices = _rules.generate_choices(0, 4, wave)
			if choices.size() != 4:
				failures.append("第 %d 波的四选一应返回 4 项，实际 %d" % [wave, choices.size()])
				continue
			var seen := {}
			for choice in choices:
				var cid = str(choice.get("id", ""))
				var stat = str(choice.get("stat", ""))
				for key in ["id", "stat", "value", "name", "desc", "tier"]:
					if not choice.has(key):
						failures.append("选项 %s 缺少字段 %s" % [cid, key])
				if seen.has(stat):
					failures.append("第 %d 波四选一出现重复属性: %s" % [wave, stat])
				seen[stat] = true
				if not allowed_ids.has(cid):
					failures.append("选项 %s 超出第 %d 波的波次门槛" % [cid, wave])


func _check_luck_bias():
	seed(20260915)
	var low = _average_tier(-100, 200)
	var high = _average_tier(100, 200)
	if not (high > low + 0.3):
		failures.append("幸运应把权重推向高阶：luck=-100 平均 tier %.3f，luck=+100 平均 tier %.3f" % [low, high])


func _average_tier(luck: int, draws: int) -> float:
	var total = 0.0
	var picks = 0
	for i in range(draws):
		for choice in _rules.generate_choices(luck, 4, 5):
			total += float(choice.get("tier", 1))
			picks += 1
	return total / max(1.0, float(picks))


func _make_player():
	var packed = load("res://scenes/Player.tscn")
	if packed == null:
		failures.append("Player 场景缺失")
		return null
	var player = packed.instantiate()
	root.add_child(player)
	return player


func _check_every_stat_applies():
	var player = _make_player()
	if player == null:
		return
	await process_frame

	# 每个属性取 tier 2 条目应用一次，验证目录里的 stat 名确实接到了真实属性上
	var tier2_by_stat := {}
	for entry in _data.get_level_up_choices(0):
		if int(entry.tier) == 2:
			tier2_by_stat[str(entry.stat)] = entry

	for stat in STAT_PROPERTY_MAP:
		var entry = tier2_by_stat.get(stat)
		if entry == null:
			failures.append("目录缺少 %s 的 tier 2 条目" % stat)
			continue
		var prop = str(STAT_PROPERTY_MAP[stat])
		var before = player.get(prop)
		if before == null:
			failures.append("Player 不存在属性 %s（供 %s 使用）" % [prop, stat])
			continue
		_rules.apply_choice(player, entry)
		var after = player.get(prop)
		if is_equal_approx(float(before), float(after)):
			failures.append("应用 %s 后 %s 未发生变化（%s → %s）" % [stat, prop, str(before), str(after)])

	if is_instance_valid(player):
		player.queue_free()


func _check_end_to_end_level_up():
	var player = _make_player()
	if player == null:
		return
	await process_frame

	player.pending_level_ups = 1
	var choices = player.pop_upgrade_choices()
	if choices.size() != 4:
		failures.append("pop_upgrade_choices 应返回 4 项，实际 %d" % choices.size())
	player.apply_upgrade_choice(0)
	if player.pending_level_ups != 0:
		failures.append("apply_upgrade_choice 未消费待选升级次数")
	if not player.current_upgrade_choices.is_empty():
		failures.append("apply_upgrade_choice 后应清空当前选项")

	if is_instance_valid(player):
		player.queue_free()
