extends SceneTree

func _init():
	var failures: Array[String] = []
	_check_run_economy(failures)
	_check_wave_duration_source(failures)
	_check_shop_rules(failures)
	_check_upgrade_rules(failures)
	if failures.is_empty():
		print("PHASE1_RULE_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_run_economy(failures: Array[String]):
	var script = load("res://scripts/RunEconomy.gd")
	var economy = script.new()
	economy.reset(5)
	if economy.materials != 5:
		failures.append("RunEconomy.reset did not set starting materials")
	economy.gain_materials(3)
	if economy.materials != 8:
		failures.append("RunEconomy.gain_materials did not add materials")
	if not economy.spend_materials(6):
		failures.append("RunEconomy.spend_materials rejected affordable cost")
	if economy.materials != 2:
		failures.append("RunEconomy.spend_materials did not subtract cost")
	if economy.spend_materials(3):
		failures.append("RunEconomy.spend_materials accepted unaffordable cost")
	economy.add_to_bag(4)
	if economy.consume_bag_for_drop(2) != 6:
		failures.append("RunEconomy.consume_bag_for_drop did not merge bag value")
	if economy.material_bag != 0:
		failures.append("RunEconomy.consume_bag_for_drop did not clear bag")
	economy.free()

func _check_wave_duration_source(failures: Array[String]):
	# 波次时长自 2026-09-15 起由 data/brotato/enemy_waves.json 提供，
	# WaveManager 只负责取用（见 tests/enemy_wave_table_smoke.gd）。
	# 这里锁定的是「数据究竟住在哪」这件事本身。
	var path := "res://data/brotato/enemy_waves.json"
	if not FileAccess.file_exists(path):
		failures.append("波次表缺失: " + path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		failures.append("波次表不是合法的 JSON 对象")
		return
	var waves: Dictionary = {}
	for entry in parsed.get("waves", []):
		if entry is Dictionary:
			waves[str(entry.get("id", ""))] = entry
	for case in [["1", 20.0], ["2", 25.0], ["20", 90.0]]:
		var wave_id := str(case[0])
		var row = waves.get(wave_id, {})
		if row.is_empty():
			failures.append("波次表缺少第 %s 波" % wave_id)
			continue
		if not is_equal_approx(float(row.get("duration", -1.0)), float(case[1])):
			failures.append("第 %s 波时长应为 %.1f，实际 %s" % [
				wave_id, float(case[1]), str(row.get("duration"))
			])
	# 时长不得再回退到 WaveManager 里硬编码
	var wm_file = FileAccess.open("res://scripts/WaveManager.gd", FileAccess.READ)
	var wm_text = wm_file.get_as_text()
	wm_file.close()
	if wm_text.contains("const WAVE_DURATION_TABLE"):
		failures.append("WaveManager 里仍存在硬编码的 WAVE_DURATION_TABLE")
	if wm_text.contains("const WAVE_DURATION = 20.0"):
		failures.append("Fixed WAVE_DURATION constant still exists")

func _check_shop_rules(failures: Array[String]):
	var script = load("res://scripts/ShopRules.gd")
	var rules = script.new()
	if rules.get_reroll_cost(0) != 5 or rules.get_reroll_cost(2) != 15:
		failures.append("ShopRules reroll cost formula mismatch")
	if rules.get_price(10, 1, 1) != 15:
		failures.append("ShopRules rarity pricing mismatch")
	if rules.get_price(10, 0, 2) != 11:
		failures.append("ShopRules wave pricing mismatch")

func _check_upgrade_rules(failures: Array[String]):
	var script = load("res://scripts/UpgradeChoiceRules.gd")
	var rules = script.new()
	# 签名自 2026-09-15 起为 generate_choices(luck, count, wave)
	var choices = rules.generate_choices(0, 4, 2)
	if choices.size() != 4:
		failures.append("UpgradeChoiceRules did not generate four choices")
	var seen: Dictionary = {}
	for choice in choices:
		if not choice.has("id") or not choice.has("name") or not choice.has("value"):
			failures.append("UpgradeChoiceRules generated malformed choice")
		if seen.has(choice.id):
			failures.append("UpgradeChoiceRules generated duplicate choice: " + choice.id)
		seen[choice.id] = true
