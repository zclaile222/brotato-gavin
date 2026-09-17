extends SceneTree

# 角色属性单位约定冒烟测试
#
# 背景（2026-09-15 修）：`characters.json` 里 brawler / crazy 的 `dodge` 被写成了**百分点**
# （15 / -30），而全项目其它地方都是**分数**（0.15 表示 15%）。当时靠
# `PlayerUpgrades._normalize_character_stat_delta()` 里一个静默的
# `abs(value) > 1.0 → /100` 兜住，所以**玩法侥幸是对的**；
# 但角色描述的渲染走的是另一条路径（`_character_desc()` 里直接 ×100），
# 于是角色选择界面显示成「闪避: 1500%」「闪避: -3000%」。
#
# 根因不是某一条数据写错，而是**同一份数据有两条单位转换路径，其中一条漏了**。
# 修法：把静默容忍换成加载期报错（`BrotatoData._validate_character_dodge_unit`），
# 并删掉那条容忍分支 —— 数据只有一种单位，就不存在两条路径不一致的可能。
#
# 本测试固定：
#   A. 全量单位门：所有角色的 dodge（base_stats 与 rules 两处）都必须是分数；
#   B. 描述与数据一致：desc 里的闪避百分比必须等于 int(dodge × 100)；
#   C. 门确实有牙：注入一个百分点写法后 validate() 必须报错，恢复后必须不报错；
#   D. 玩法等价：修复后 dodge 的落点与修复前完全相同（原意图的百分比没变）。

const PASS_TAG := "CHARACTER_STAT_UNIT_SMOKE_PASS"
const FAIL_TAG := "CHARACTER_STAT_UNIT_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

# 修复前 brawler / crazy 写的是百分点，这里记录「原意图的百分比」，
# 用来证明修复只改了表示法、没改数值。
const EXPECTED_DODGE_PERCENT := {
	"brawler": 15.0,
	"crazy": -30.0,
	"ghost": 30.0,
	"vagabond": -5.0,
	"dwarf": -20.0,
}

var failures: Array[String] = []
var data = null


func _init():
	call_deferred("_run")


func _run():
	var game_state = root.get_node("/root/GameState")
	data = game_state.get_brotato_data()
	if data == null:
		failures.append("取不到 BrotatoData 实例")
		_report()
		return
	if data.characters.is_empty():
		failures.append("角色目录为空，测试会退化为空转")
		_report()
		return

	_check_dodge_unit_all_characters()
	_check_description_matches_data()
	_check_gate_has_teeth()
	_check_values_preserved()

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


# ─── A. 全量单位门 ───

func _check_dodge_unit_all_characters():
	for id in data.characters:
		var row: Dictionary = data.characters[id]
		var base_stats: Dictionary = row.get("base_stats", {})
		if base_stats.has("dodge"):
			var base_dodge = float(base_stats.get("dodge"))
			if absf(base_dodge) > 1.0:
				failures.append("%s.base_stats.dodge 不是分数: %s" % [id, str(base_dodge)])
		for rule in row.get("rules", []):
			if not (rule is Dictionary):
				continue
			if str(rule.get("stat", "")) != "dodge":
				continue
			var value = float(rule.get("value", 0.0))
			if absf(value) > 1.0:
				failures.append("%s.rules 的 dodge 不是分数: %s" % [id, str(value)])


# ─── B. 描述与数据一致 ───
# 这是本次缺陷的直接症状：数据里 15（=15%）渲染成了 1500%。

func _check_description_matches_data():
	var checked := 0
	for id in data.characters:
		var converted: Dictionary = data.to_game_state_character(id)
		if converted.is_empty():
			continue
		var desc := str(converted.get("desc", ""))
		var row: Dictionary = data.characters[id]
		var base_stats: Dictionary = row.get("base_stats", {})
		if not base_stats.has("dodge"):
			continue
		checked += 1
		var expected := "%d%%" % int(round(float(base_stats.get("dodge")) * 100.0))
		if not desc.contains(expected):
			failures.append("%s 的描述里找不到「闪避: %s」，实际 desc=%s" % [
				id, expected, desc.replace("\n", " / ")
			])
		# 反向断言：不得出现荒谬的百分比（|值| 超过 100% 的闪避不可能是有意设计）
		for token in desc.split("\n"):
			if not str(token).begins_with("闪避"):
				continue
			var digits := ""
			for ch in str(token):
				if (ch >= "0" and ch <= "9") or ch == "-":
					digits += ch
			if digits != "" and absf(float(digits)) > 100.0:
				failures.append("%s 的闪避百分比不合理: 「%s」" % [id, str(token)])
	if checked == 0:
		failures.append("没有任何角色带 dodge，描述一致性断言空转")


# ─── C. 门有牙 ───

func _check_gate_has_teeth():
	# 先确认干净数据下不报错
	var clean_errors := _dodge_errors(data.validate())
	if not clean_errors.is_empty():
		failures.append("干净数据下 dodge 校验不应报错，实际: %s" % "; ".join(clean_errors))

	# 注入一个百分点写法，校验必须报错
	var row: Dictionary = data.characters.get("brawler", {})
	if row.is_empty():
		failures.append("找不到 brawler，无法验证校验门")
		return
	var base_stats: Dictionary = row.get("base_stats", {})
	var backup = base_stats.get("dodge")
	base_stats["dodge"] = 15
	var dirty_errors := _dodge_errors(data.validate())
	base_stats["dodge"] = backup

	if dirty_errors.is_empty():
		failures.append("把 dodge 写成百分点（15）后校验竟然没报错 —— 单位门失效")
	if not dirty_errors.is_empty() and not dirty_errors[0].contains("base_stats.dodge"):
		failures.append("校验报错信息没有指明 base_stats.dodge: %s" % dirty_errors[0])

	# 恢复后必须回到干净
	var restored_errors := _dodge_errors(data.validate())
	if not restored_errors.is_empty():
		failures.append("注入后未正确还原: %s" % "; ".join(restored_errors))


func _dodge_errors(errors: Array) -> Array:
	var matched: Array = []
	for e in errors:
		if str(e).contains("dodge"):
			matched.append(str(e))
	return matched


# ─── D. 玩法等价 ───

func _check_values_preserved():
	for id in EXPECTED_DODGE_PERCENT:
		var row: Dictionary = data.characters.get(id, {})
		if row.is_empty():
			failures.append("找不到角色 %s" % id)
			continue
		var expected_percent = float(EXPECTED_DODGE_PERCENT[id])
		var converted: Dictionary = data.to_game_state_character(id)
		var desc := str(converted.get("desc", ""))
		if not desc.contains("%d%%" % int(round(expected_percent))):
			failures.append("%s 的 dodge 意图应为 %d%%（原意图），desc 里找不到" % [
				id, int(round(expected_percent))
			])
	# 说明性断言：容忍分支的触发条件是 abs(value) > 1.0；
	# A 已保证没有数据满足它，因此删掉那条分支不会改变任何角色的落点。
	# 这里把它写成一条可执行的断言，避免以后有人「顺手」把数据改回百分点。
	for id in data.characters:
		var row: Dictionary = data.characters[id]
		for rule in row.get("rules", []):
			if rule is Dictionary and str(rule.get("stat", "")) == "dodge":
				if absf(float(rule.get("value", 0.0))) > 1.0:
					failures.append("%s 的 dodge 又变成百分点写法了，静默容忍已移除，玩法会出错" % id)
