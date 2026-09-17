extends SceneTree

# 出售/移除武器的定位契约冒烟测试
#
# 背景（修的真实缺陷）：PlayerUpgrades.remove_upgrade() 的武器分支过去只比较 type：
#
#     for i in range(p.equipped_weapons.size()):
#         if p.equipped_weapons[i].type == upgrade.get("weapon_type", ""):
#             p.equipped_weapons.remove_at(i)
#             ...
#
# 玩家同时持有同类型的多把不同分阶武器时（SMG T1 + SMG T2，合成后的常规状态），
# 卖 T2 会移除先遍历到的那把 —— 也就是 T1。数量对得上，所以只看数量的断言发现不了。
#
# 本测试固定：
#   A. 同时持有 SMG T1 + T2，出售**带 tier 的** T2 条目 → 留下的是 T1（验 tier，不验数量）；
#   B. 反向：出售 T1 → 留下 T2；
#   C. 带 slot_index 的出售精确命中该格子；越界/错指的索引安全降级，不崩；
#   D. 不带 tier / slot_index 的旧式条目仍按「第一个同类型」移除（向后兼容）；
#   E. T4（满阶、金色）武器同样能被正确移除。
#
# 断言前一律先做前置自检：确认武器真的装上去了、tier 真的如预期，再断言移除结果。
# 否则「没装上」会被误判成「删对了」，测试空转。

const PASS_TAG := "WEAPON_REMOVE_BY_TIER_SMOKE_PASS"
const FAIL_TAG := "WEAPON_REMOVE_BY_TIER_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

# SMG 在 weapons.json 里 4 个分阶俱全，是天然的同类型多分阶样本。
const SAMPLE_WEAPON := "smg"

var failures: Array[String] = []
var checks: int = 0
var player = null


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

	if player.get_max_weapon_slots() < 2:
		failures.append("前置条件不成立：get_max_weapon_slots()=%d，本测试需要 >=2 个格子" % player.get_max_weapon_slots())
		_report()
		return

	_check_remove_t2_keeps_t1()
	_check_remove_t1_keeps_t2()
	_check_slot_index_removal()
	_check_out_of_range_slot_falls_back()
	_check_legacy_type_only_still_works()
	_check_tier4_removal()
	_check_tier4_color_not_shared()

	if is_instance_valid(player):
		player.queue_free()
	player = null

	_report()


func _report():
	if failures.is_empty():
		print("%s（%d 项断言）" % [PASS_TAG, checks])
		quit(0)
		return
	print("%s: %d 项断言失败（共执行 %d 项）" % [FAIL_TAG, failures.size(), checks])
	for i in range(min(failures.size(), MAX_PRINTED_FAILURES)):
		print("  - %s" % failures[i])
	if failures.size() > MAX_PRINTED_FAILURES:
		print("  ... 其余 %d 项同类失败已省略" % (failures.size() - MAX_PRINTED_FAILURES))
	push_error("%s: %d failures" % [FAIL_TAG, failures.size()])
	quit(1)


# ─── 辅助 ───

func _ok(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)


func _clear_weapons():
	player.equipped_weapons.clear()
	player.combat.emit_weapons_changed()


# 装备一组 (weapon_id, tier)，返回实际装上的分阶数组；任何一件没装上都会记失败。
# 这是「断言前置自检」的核心：装不上就不该继续往下断言移除行为。
func _equip_many(pairs: Array, context: String) -> Array:
	_clear_weapons()
	var before = player.equipped_weapons.size()
	for pair in pairs:
		if not player.equip_or_combine_weapon(str(pair[0]), int(pair[1])):
			failures.append("%s：前置装备失败（%s T%d），后续断言不可信" % [context, pair[0], pair[1]])
			return []
	var expected = before + pairs.size()
	if player.equipped_weapons.size() != expected:
		failures.append("%s：前置自检失败，期望装上 %d 把，实际 %d 把" % [context, expected, player.equipped_weapons.size()])
		return []
	return _tiers()


func _tiers() -> Array:
	var out: Array = []
	for w in player.equipped_weapons:
		out.append(int(w.get("tier", w.get("level", 1))))
	return out


func _types() -> Array:
	var out: Array = []
	for w in player.equipped_weapons:
		out.append(str(w.type))
	return out


func _make_sell_entry(weapon_type: String, extra: Dictionary = {}) -> Dictionary:
	var entry := {"name": "test weapon", "type": "weapon", "weapon_type": weapon_type}
	for key in extra:
		entry[key] = extra[key]
	return entry


# ─── A. 同类型多分阶：卖 T2 必须留下 T1 ───

func _check_remove_t2_keeps_t1():
	var context := "A 卖 T2 留下 T1"
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [1, 2], "%s：前置分阶期望 [1, 2]，实际 %s" % [context, str(tiers)])
	if tiers != [1, 2]:
		return

	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 2}))

	var after = _tiers()
	_ok(after.size() == 1, "%s：移除前 %d 把 %s，移除后应为 1 把，实际 %d 把 %s" % [
		context, tiers.size(), str(tiers), after.size(), str(after)])
	_ok(after == [1], "%s：期望留下 T1，实际留下 %s（移除前分阶 %s，类型 %s）" % [
		context, str(after), str(tiers), str(_types())])


# ─── B. 反向：卖 T1 必须留下 T2 ───

func _check_remove_t1_keeps_t2():
	var context := "B 卖 T1 留下 T2"
	var tiers := _equip_many([[SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [2, 1], "%s：前置分阶期望 [2, 1]（乱序装备，防止靠遍历顺序蒙对），实际 %s" % [context, str(tiers)])
	if tiers != [2, 1]:
		return

	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 1}))

	var after = _tiers()
	_ok(after.size() == 1, "%s：移除前 %d 把 %s，移除后应为 1 把，实际 %d 把 %s" % [
		context, tiers.size(), str(tiers), after.size(), str(after)])
	_ok(after == [2], "%s：期望留下 T2，实际留下 %s（移除前分阶 %s）" % [
		context, str(after), str(tiers)])


# ─── C. slot_index 精确命中 ───

func _check_slot_index_removal():
	var context := "C 按 slot_index 移除"
	# 装 3 把同类型不同分阶，按索引删中间那把，结果必须能唯一确定。
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 3]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [1, 2, 3], "%s：前置分阶期望 [1, 2, 3]，实际 %s" % [context, str(tiers)])
	if tiers != [1, 2, 3]:
		return

	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 2, "slot_index": 1}))

	var after = _tiers()
	_ok(after == [1, 3], "%s：按 slot_index=1 移除后期望 [1, 3]，实际 %s（移除前 %s）" % [
		context, str(after), str(tiers)])

	# slot_index 指向别的类型时不能误伤 —— 应降级为按 type 找，而不是删掉那个格子。
	var context2 := "C2 slot_index 指向其他类型"
	_clear_weapons()
	if not player.equip_or_combine_weapon(SAMPLE_WEAPON, 1):
		failures.append("%s：前置装备 %s T1 失败" % [context2, SAMPLE_WEAPON])
		return
	if not player.equip_or_combine_weapon("pistol", 1):
		failures.append("%s：前置装备 pistol T1 失败" % [context2])
		return
	_ok(str(player.equipped_weapons[1].type) == "pistol", "%s：前置自检，slot 1 应为 pistol，实际 %s" % [
		context2, str(player.equipped_weapons[1].type)])
	# 声称 slot_index=1 但说是 smg —— 索引与类型不符，必须降级，且不能把 pistol 删掉。
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 1, "slot_index": 1}))
	var types_after = _types()
	_ok(types_after.size() == 1, "%s：期望移除后剩 1 把，实际 %d 把 %s" % [context2, types_after.size(), str(types_after)])
	_ok(types_after == ["pistol"], "%s：期望留下 pistol，实际 %s（slot_index 与类型不符时应降级而非误删）" % [
		context2, str(types_after)])


# ─── C3. 越界索引安全降级 ───

func _check_out_of_range_slot_falls_back():
	var context := "C3 越界 slot_index 安全降级"
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [1, 2], "%s：前置分阶期望 [1, 2]，实际 %s" % [context, str(tiers)])
	if tiers != [1, 2]:
		return

	# 索引远超数组长度：必须不崩，并按 type+tier 降级，精确删掉 T2。
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 2, "slot_index": 99}))
	var after = _tiers()
	_ok(after == [1], "%s：越界索引应降级为 type+tier 匹配并删掉 T2，实际剩下 %s（移除前 %s）" % [
		context, str(after), str(tiers)])

	# 负数索引同样要降级，不能触发 remove_at(-1) 这种危险操作。
	var context2 := "C4 负数 slot_index 安全降级"
	var tiers2 := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2]], context2)
	if tiers2.is_empty():
		return
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 1, "slot_index": -5}))
	var after2 = _tiers()
	_ok(after2 == [2], "%s：负数索引应降级并删掉 T1，实际剩下 %s（移除前 %s）" % [
		context2, str(after2), str(tiers2)])


# ─── D. 向后兼容：不带 tier / slot_index ───

func _check_legacy_type_only_still_works():
	var context := "D 旧式条目（仅 type）"
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [1, 2], "%s：前置分阶期望 [1, 2]，实际 %s" % [context, str(tiers)])
	if tiers != [1, 2]:
		return

	# 旧式条目（Shop 早期行为：只有 type + weapon_type）必须仍然能删掉「第一个同类型」。
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON))
	var after = _tiers()
	_ok(after == [2], "%s：不带 tier 时应移除第一个同类型（T1），实际剩下 %s（移除前 %s）" % [
		context, str(after), str(tiers)])

	# 只给 type 且武器不存在于背包时，必须什么都不做（不崩、不多删）。
	var context2 := "D2 旧式条目找不到目标"
	var tiers2 := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2]], context2)
	if tiers2.is_empty():
		return
	player.remove_upgrade(_make_sell_entry("not_a_real_weapon"))
	var after2 = _tiers()
	_ok(after2 == tiers2, "%s：目标不存在时不应改变背包，期望 %s，实际 %s" % [
		context2, str(tiers2), str(after2)])


# ─── E. T4 满阶可移除 ───

func _check_tier4_removal():
	var context := "E 移除 T4"
	var tiers := _equip_many([[SAMPLE_WEAPON, 4], [SAMPLE_WEAPON, 1]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [4, 1], "%s：前置分阶期望 [4, 1]，实际 %s" % [context, str(tiers)])
	if tiers != [4, 1]:
		return

	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 4}))
	var after = _tiers()
	_ok(after == [1], "%s：指定 tier=4 移除后期望留下 [1]，实际 %s（移除前 %s）" % [
		context, str(after), str(tiers)])

	# T4 是最高阶，不存在 T5 可合成；再删一次同 tier 只能删掉剩下那把 T4。
	var context2 := "E2 两把 T4 中删一把"
	var tiers2 := _equip_many([[SAMPLE_WEAPON, 4], [SAMPLE_WEAPON, 4]], context2)
	if tiers2.is_empty():
		return
	_ok(tiers2 == [4, 4], "%s：前置分阶期望 [4, 4]（注意合成规则可能把两把 T4 合并，需自检），实际 %s" % [
		context2, str(tiers2)])
	if tiers2 != [4, 4]:
		return
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 4, "slot_index": 0}))
	var after2 = _tiers()
	_ok(after2 == [4], "%s：移除 slot 0 后应剩 1 把 T4，实际 %s" % [context2, str(after2)])


# ─── F. T4 颜色不得污染其他武器（独立于形状的「按引用/按值」探针）───
#
# 实测结论（本机跑出，非推测）：目录武器（含 smg）走 _make_weapon 的 catalog_tiers 分支，
# data 来自 catalog_tiers[str(tier)].duplicate(true)，每把武器从一开始就是独立深拷贝。
#
# 更正（2026-09-17）：一度认为 _apply_tier_stats() 的 else 分支是死代码（依据是 weapons.json
# 的 78 个武器 catalog_tiers 全覆盖），删除后 phase2_loot_weapon_smoke 立刻 5/5 失败。
# 真实原因是**有两条数据来源**：catalog 路径（weapons.json）覆盖完整，但 legacy 路径
# （weapons.tres）不生成 catalog_tiers —— boomerang 只存在于 weapons.tres，其档位为空，
# 必须走 _apply_tier_stats()。该分支已回滚保留。
#
# 写这个断言还有一个更普遍的用处：它验证「改一把武器的 data 不会影响同类型另一把」这一
# 底层契约。原先 _apply_tier_stats 里的 `data.color = ...` 若真作用在共享字典上，会失败。
const T4_COLOR := Color(1.0, 0.75, 0.2)  # BrotatoData._tier_color(4)

func _check_tier4_color_not_shared():
	var context := "F T4 数据不共享"
	_clear_weapons()
	if not player.equip_or_combine_weapon(SAMPLE_WEAPON, 1):
		failures.append("%s：前置装备 %s T1 失败" % [context, SAMPLE_WEAPON])
		return
	var t1_color = player.equipped_weapons[0].data.color

	# 再装一把 T4：两把同类型武器必须各自独立。
	if not player.equip_or_combine_weapon(SAMPLE_WEAPON, 4):
		failures.append("%s：前置装备 %s T4 失败" % [context, SAMPLE_WEAPON])
		return
	_ok(player.equipped_weapons.size() == 2, "%s：前置自检期望 2 把，实际 %d 把（分阶 %s）" % [
		context, player.equipped_weapons.size(), str(_tiers())])
	if player.equipped_weapons.size() != 2:
		return

	var t4_color = player.equipped_weapons[1].data.color
	_ok(t4_color.is_equal_approx(T4_COLOR), "%s：T4 颜色应为 %s，实际 %s" % [
		context, str(T4_COLOR), str(t4_color)])
	_ok(not t1_color.is_equal_approx(T4_COLOR), "%s：T1 颜色不应被同类型 T4 污染，实际 %s" % [
		context, str(t1_color)])

	# 直接改 T4 的 data，T1 的 data 必须纹丝不动（同类型不同实例的独立性）。
	player.equipped_weapons[1].data["color"] = Color(0.123, 0.456, 0.789)
	_ok(player.equipped_weapons[0].data.color.is_equal_approx(t1_color),
		"%s：修改 T4 的 data 后 T1 颜色应保持 %s，实际 %s" % [
			context, str(t1_color), str(player.equipped_weapons[0].data.color)])

	# 删除 T4 后 T1 依旧完好。
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 4}))
	var after = _tiers()
	_ok(after == [1], "%s：移除 T4 后期望剩 [1]，实际 %s" % [context, str(after)])
	if after == [1]:
		var color_after = player.equipped_weapons[0].data.color
		_ok(color_after.is_equal_approx(t1_color),
			"%s：移除 T4 后 T1 颜色应保持 %s，实际 %s" % [context, str(t1_color), str(color_after)])
