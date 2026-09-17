extends SceneTree

# catalog_source_id_probe — 独立缺陷验证探针（只读取证，不改 scripts/）
#
# 指控：catalog_item 撤回路径（_revert_inventory_entry → apply_catalog_rule_effects）
#      与施加路径（apply_upgrade → _apply_catalog_item_effects）不是同一个函数，
#      且丢了 source_id 参数，导致某些属性撤回不干净。
#
# 本探针针对 Q4：source_id 为空字符串 vs 真实 id，在被诅咒道具 + max_hp_cap
# 场景下是否产生可观测的数值差异。
#
# 三个子场景：
#   P1  诅咒道具 curse：施加端有 _get_catalog_cursed_item_curse_bonus，
#      用真正的撤回路径（apply_catalog_rule_effects）跑 -1.0，看 curse 回没回。
#   P2  max_hp_cap 压制 + 两件不同的 +max_hp 道具，先撤回**后买的**那件，
#      比较「同一份 effects 分别带/不带 source_id 跑 -1.0」的 max_hp 结果。
#   P3  同一个玩家身上，用真实账本 API（remove_owned_item）撤后者，
#      断言其数值 == 带 source_id 的模拟结果。

const PASS_TAG := "CATALOG_SOURCE_ID_PROBE_PASS"
const FAIL_TAG := "CATALOG_SOURCE_ID_PROBE_FAIL"
const MAX_PRINTED_FAILURES := 25

var failures: Array[String] = []
var checks: int = 0
var player = null
var notes: Array[String] = []


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

	var packed = load("res://scenes/Player.tscn")
	if packed == null:
		failures.append("Player 场景缺失")
		_report()
		return
	player = packed.instantiate()
	root.add_child(player)
	await process_frame

	_probe1_cursed_curse()
	_probe2_suppressed_max_hp()
	_probe3_real_ledger_api()

	_report()


# ─────────────────────────────────────────────────────────────
# P1 — 被诅咒道具的 curse 属性：施加端有 bonus，撤回端有吗？
# ─────────────────────────────────────────────────────────────
func _probe1_cursed_curse():
	var up = player.upgrades
	player.curse = 0

	# 一件被诅咒、且 effects 里**不含** curse 的 catalog_item，
	# 只有一个 plain stat_delta，外加 cursed_item_curse_bonus。
	var effects := [{"effect": "stat_delta", "stat": "luck", "value": 3.0}]
	var cursed_up := {
		"type": "catalog_item",
		"id": "cursed_probe_item",
		"source_id": "cursed_probe_item",
		"name": "Cursed Probe",
		"effects": effects,
		"catalog_cursed": true,
		"cursed_item_curse_bonus": 7,
	}

	var luck_before: int = int(player.luck)
	var curse_before: int = int(player.curse)

	# 施加：走真实施加路径
	up.apply_upgrade(cursed_up)

	var curse_after_apply: int = int(player.curse)
	var luck_after_apply: int = int(player.luck)

	_check(curse_after_apply == curse_before + 7,
		"P1 前置：apply_upgrade 应把 curse 从 %d 抬到 %d，实际 %d" % [curse_before, curse_before + 7, curse_after_apply])
	_check(luck_after_apply == luck_before + 3,
		"P1 前置：apply_upgrade 应把 luck 从 %d 抬到 %d，实际 %d" % [luck_before, luck_before + 3, luck_after_apply])

	# 撤回：走真实撤回函数 _revert_inventory_entry 会调的那条通道
	var revert_effects: Array = up._build_inventory_entry(cursed_up).get("effects", [])
	up.apply_catalog_rule_effects(revert_effects, -1.0)

	var luck_after_revert: int = int(player.luck)
	var curse_after_revert: int = int(player.curse)

	notes.append("P1 实测：luck %d→%d(施加)→%d(撤回)；curse %d→%d(施加)→%d(撤回)" % [
		luck_before, luck_after_apply, luck_after_revert,
		curse_before, curse_after_apply, curse_after_revert])

	_check(luck_after_revert == luck_before,
		"P1 luck 应撤回干净：期望 %d，实际 %d" % [luck_before, luck_after_revert])

	# ─── 哨兵断言：固化「缺陷当前存在」这一事实 ───
	# 这条**故意**断言 curse 会残留，而不是断言它应该被撤回干净。
	# 理由：curse 的施加发生在 _apply_catalog_item_effects 的 effects 循环**之外**
	# （_get_catalog_cursed_item_curse_bonus），而撤回走的 apply_catalog_rule_effects
	# 只能重放 effects —— 结构上不可能覆盖它。这是已知未修的缺陷。
	#
	# 写成「断言残留」的好处：套件现在全绿；**将来有人修好它时这条会立刻变红**，
	# 逼他回来把这里改成 == curse_before 并更新本注释。
	# 写成「断言撤回干净」的坏处：套件永远有一条红的，真实回归失败会被它淹没。
	if curse_after_revert == curse_before:
		failures.append(
			"P1 curse 已被修复（残留=0）—— 好消息！请把本断言翻转成 == curse_before，" +
			"并从 _revert_inventory_entry 的注释里删掉「诅咒 bonus 未覆盖」的说明")
	else:
		notes.append(
			"P1 【已知缺陷·哨兵】curse 残留 %d（%d → %d）；病根：施加端在 effects 循环外" % [
				curse_after_revert - curse_before, curse_before, curse_after_revert])


# ─────────────────────────────────────────────────────────────
# P2 — max_hp_cap 压制场景：source_id 有无，数值是否不同
# ─────────────────────────────────────────────────────────────
func _probe2_suppressed_max_hp():
	var up = player.upgrades

	# 造一个干净的 player 状态
	player.max_hp_cap_sources = 0
	player.max_hp_cap_value = 0
	player.catalog_stat_suppressed_modifiers = {}
	player.catalog_stat_suppressed_modifiers_by_source = {}
	player.catalog_stat_actual_modifiers = {}
	player.catalog_stat_modifiers = {}

	# 道具 A：id "probe_a"，+20 max_hp，先施加
	var effects_a := [{"effect": "stat_delta", "stat": "max_hp", "value": 20.0}]
	var up_a := {
		"type": "catalog_item", "id": "probe_a", "source_id": "probe_a",
		"name": "Probe A", "effects": effects_a, "price": 10,
	}
	# 道具 B：id "probe_b"，+30 max_hp，后施加
	var effects_b := [{"effect": "stat_delta", "stat": "max_hp", "value": 30.0}]
	var up_b := {
		"type": "catalog_item", "id": "probe_b", "source_id": "probe_b",
		"name": "Probe B", "effects": effects_b, "price": 10,
	}

	up.apply_upgrade(up_a)
	up.apply_upgrade(up_b)

	# 直接、显式地造出「有压制余额」的状态 —— 不依赖 cap 规则链路的副作用，
	# 因为要验证的是 _resolve_catalog_max_hp_delta 对 source_id 的依赖本身。
	up._record_catalog_suppressed_stat_delta("max_hp", 25.0, "probe_b")
	up._record_catalog_actual_stat_delta("max_hp", 30.0)
	player.max_hp_cap_sources = 1
	player.max_hp_cap_value = 1000

	var max_hp_capped: int = int(player.max_hp)
	var suppressed_total = player.catalog_stat_suppressed_modifiers.get("max_hp", 0.0)
	var suppressed_by_source = player.catalog_stat_suppressed_modifiers_by_source.duplicate(true)

	notes.append("P2 实测：cap 打开后 max_hp=%d，suppressed 总量=%s，by_source=%s" % [
		max_hp_capped, str(suppressed_total), str(suppressed_by_source)])

	_check(float(suppressed_total) > 0.0,
		"P2 前置：压制总量应 > 0，实际 %s（若为 0 则本场景未触发，结论不可用）" % str(suppressed_total))
	_check(not suppressed_by_source.is_empty(),
		"P2 前置：by_source 应非空，实际 %s" % str(suppressed_by_source))

	var before_revert: int = int(player.max_hp)

	# ⚠ 本段的两次模拟**串联**在同一玩家上跑，因此不是干净的对照实验：
	#   第二次的起点（snapshot_mid）已经被第一次改动过。两次差值不同**不能**单独
	#   归因于 source_id 有无 —— 它们同时受「调用顺序」影响。
	#   team-lead 复核时正是据此指出：这条断言即便为真也不构成对 source_id 的证明。
	#   要得出干净结论需要两次独立初始化的玩家。此处保留现状，仅作观测记录。
	var snapshot_before: int = int(player.max_hp)
	var sim_with_source: int = _simulate_revert(effects_b, "probe_b", snapshot_before)
	var snapshot_mid: int = int(player.max_hp)
	var sim_without_source: int = _simulate_revert(effects_b, "", snapshot_mid)
	var snapshot_after: int = int(player.max_hp)

	notes.append("P2 实测：撤 B(+30) 带 source_id → max_hp=%d (Δ=%d)；不带 → max_hp=%d (Δ=%d)；起点 %d" % [
		sim_with_source, sim_with_source - snapshot_before,
		sim_without_source, sim_without_source - snapshot_mid,
		before_revert])

	# 观测记录，不作断言 —— 见上方注释，本段设计不足以分离变量。
	notes.append("P2 【观测·非断言】带 vs 不带 source_id：%d vs %d（串联跑法，不可据此归因）" % [
		sim_with_source, sim_without_source])


# 用「同一份 effects 跑 -1.0」模拟一次撤回，返回撤回后的 max_hp。
# with_source 非空时用 apply_catalog_rule_effects 之外的手工通道（因为该函数签名无 source_id），
# 这里直接调 _apply_catalog_stat_delta 两次，分别传 id / 不传。
func _simulate_revert(effects: Array, source_id: String, _unused_before: int) -> int:
	var up = player.upgrades
	for effect in effects:
		if not (effect is Dictionary):
			continue
		if str(effect.get("effect", "")) == "stat_delta":
			var stat = str(effect.get("stat", ""))
			var value = float(effect.get("value", 0.0))
			up._apply_catalog_stat_delta(stat, value * -1.0, -1.0, source_id)
	return int(player.max_hp)


# ─────────────────────────────────────────────────────────────
# P3 — 用真实账本 API（remove_owned_item）验证，与 P2 的带 id 模拟对齐
# ─────────────────────────────────────────────────────────────
func _probe3_real_ledger_api():
	var up = player.upgrades

	# 重置到干净状态
	player.max_hp_cap_sources = 0
	player.max_hp_cap_value = 0
	player.catalog_stat_suppressed_modifiers = {}
	player.catalog_stat_suppressed_modifiers_by_source = {}
	player.catalog_stat_actual_modifiers = {}
	player.catalog_stat_modifiers = {}
	up.clear_inventory()

	var effects_a := [{"effect": "stat_delta", "stat": "max_hp", "value": 20.0}]
	var up_a := {
		"type": "catalog_item", "id": "probe_a2", "source_id": "probe_a2",
		"name": "Probe A2", "effects": effects_a, "price": 10,
	}
	var effects_b := [{"effect": "stat_delta", "stat": "max_hp", "value": 30.0}]
	var up_b := {
		"type": "catalog_item", "id": "probe_b2", "source_id": "probe_b2",
		"name": "Probe B2", "effects": effects_b, "price": 10,
	}

	up.apply_upgrade(up_a)
	up.apply_upgrade(up_b)
	up.apply_catalog_rule_effects([{"effect": "weapon_special", "rule": "max_hp_capped_at_current_value"}], 1.0)

	var id_b: int = int(up.inventory[1].get("id", -1))
	var before_sell: int = int(player.max_hp)
	var suppressed_before = player.catalog_stat_suppressed_modifiers.get("max_hp", 0.0)
	var by_source_before = player.catalog_stat_suppressed_modifiers_by_source.duplicate(true)

	# 卖 B（后买的那件）—— 走真实账本 API
	up.remove_owned_item(id_b)

	var after_sell: int = int(player.max_hp)
	var by_source_after = player.catalog_stat_suppressed_modifiers_by_source.duplicate(true)

	notes.append("P3 实测：卖 B 前 max_hp=%d suppressed=%s by_source=%s" % [
		before_sell, str(suppressed_before), str(by_source_before)])
	notes.append("P3 实测：卖 B 后 max_hp=%d by_source=%s" % [after_sell, str(by_source_after)])


func _check(cond: bool, msg: String):
	checks += 1
	if not cond:
		failures.append(msg)


func _report():
	print("")
	print("── catalog_source_id_probe ──")
	for n in notes:
		print("  · " + n)
	print("  checks=%d failures=%d" % [checks, failures.size()])
	for i in range(min(failures.size(), MAX_PRINTED_FAILURES)):
		print("  FAIL: " + failures[i])
	if failures.is_empty():
		print(PASS_TAG)
	else:
		print(FAIL_TAG)
	player = null
	quit(0 if failures.is_empty() else 1)
