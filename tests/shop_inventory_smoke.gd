extends SceneTree

# shop_inventory_smoke — A6 / A4' / B3 的契约冒烟测试
#
# 覆盖四组：
#   A. 玩家侧权威「已获得道具」清单的记账正确性（条目数、字段、来源、实付价）
#   B. **属性精确撤回** —— 买入 catalog_item → 记属性 → 出售 → 断言回到买入前
#   C. 武器按 tier 精确移除（含反向断言）
#   D. `get_weapon_info()` 的 `slot_index` 与下标严格一致
#
# ── 为什么 B 是这轮的核心 ──
# 商店自己那份 `purchased_items` 是私有副本，卖的时候把副本丢回 player，
# 副本里的 value/effect 是「标价签」而非「实际施加量」。catalog_item 尤其严重：
# 效果是多规则数组，撤回靠把同一份 effects 用 -1.0 反跑一遍 —— 而
# `_apply_catalog_stat_delta` 里到处是 clamp / max(0,…) / min(…, cap)，
# 「减回去」在触到边界时**不是**「加回来」的逆运算。
#
# 本测试断言的是**最终数值**，不是「remove_upgrade 被调用过」。
# 因此它能抓住「调用成功但属性没回到原位」这类静默错误。
#
# ── 写法注意（踩过的坑）──
#   * `--script` 模式下 root 视口默认 64×64，不是 1280×720。别依赖尺寸。
#   * 同步清理用 `free()`，不是 `queue_free()`。
#   * 不 `const preload()` 自动加载脚本，改用运行时 `load()`。
#   * 每条关键断言前先做**前置自检**：确认被测对象真的处于会触发的状态，
#     否则「没装上 / 没记上」会被误判成「撤对了」，测试空转。

const PASS_TAG := "SHOP_INVENTORY_SMOKE_PASS"
const FAIL_TAG := "SHOP_INVENTORY_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 25

# 同类型多分阶样本。smg 在 weapons.json 里 4 个分阶俱全。
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
	_preload_script_classes()

	var packed = load("res://scenes/Player.tscn")
	if packed == null:
		failures.append("Player 场景缺失，测试无法继续")
		_report()
		return
	player = packed.instantiate()
	root.add_child(player)
	await process_frame

	_check_inventory_records_on_apply()
	_check_catalog_item_precise_revert()
	_check_catalog_item_revert_is_additive_not_clamp()
	_check_inventory_remove_is_idempotent()
	_check_multi_purchase_count()
	_check_weapon_removal_by_tier_both_directions()
	_check_weapon_removal_slot_index_roundtrip()
	_check_weapon_info_slot_index_matches_position()
	_check_weapon_info_tooltip_fields()
	_check_non_catalog_revert_via_ledger()
	_check_weapon_ledger_slot_after_equip()

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


func _preload_script_classes():
	# ⚠ 用运行时 load()，不用 const preload()。
	# preload 在**解析期**就把自动加载脚本拉起来，此时 autoload 尚未注册 → 解析失败，
	# 而且失败结果会写进全局脚本缓存，连带把后面加载的实例一起弄坏。
	for path in [
		"res://scripts/BrotatoData.gd",
		"res://scripts/WeaponData.gd",
		"res://scripts/WeaponDatabase.gd",
		"res://scripts/ShopRules.gd",
		"res://scripts/PlayerCore.gd",
		"res://scripts/PlayerCombat.gd",
		"res://scripts/PlayerUpgrades.gd",
		"res://scripts/PlayerBuffs.gd",
		"res://scripts/PlayerStats.gd",
		"res://scripts/HUDCore.gd",
	]:
		if load(path) == null:
			failures.append("预加载脚本失败: " + path)


# ─── 辅助 ───

func _ok(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)


func _find_by_source_id(pool: Array, source_id: String) -> Dictionary:
	for entry in pool:
		if entry is Dictionary and str(entry.get("source_id", "")) == source_id:
			return entry
	return {}


func _make_upgrade(up_type: String, value) -> Dictionary:
	return {"type": up_type, "name": "测试_%s" % up_type, "desc": "测试用", "value": value}


# 造一条走 `_apply_catalog_stat_delta` 通道的目录道具。
# 用于探测那些**只在目录通道里存在**的属性（harvesting / xp_gain_percent / ...）——
# `apply_upgrade` 的 legacy match 分支根本不认它们。
func _make_catalog_item(stat: String, value: float, item_id: String = "") -> Dictionary:
	var sid := item_id if item_id != "" else "test_%s" % stat
	return {
		"type": "catalog_item",
		"name": "测试_%s" % stat,
		"desc": "测试用目录道具",
		"source_id": sid,
		"price": 10,
		"effects": [{"effect": "stat_delta", "stat": stat, "value": value}],
	}


func _reset_inventory():
	player.upgrades.clear_inventory()


# ─── A. 记账 ───

func _check_inventory_records_on_apply():
	var context := "A 施加即记账"
	_reset_inventory()
	_ok(player.get_owned_item_count() == 0, "%s：清空后应为 0 条，实际 %d 条" % [
		context, player.get_owned_item_count()])

	player.apply_upgrade(_make_upgrade("armor", 3))

	var items = player.get_owned_items()
	_ok(items.size() == 1, "%s：施加 1 次后应有 1 条记录，实际 %d 条" % [context, items.size()])
	if items.is_empty():
		return
	var entry: Dictionary = items[0]
	_ok(str(entry.get("type", "")) == "armor", "%s：type 应为 armor，实际 %s" % [
		context, str(entry.get("type", ""))])
	_ok(int(entry.get("id", -1)) > 0, "%s：id 应为正数，实际 %s" % [
		context, str(entry.get("id", -1))])
	_ok(entry.has("effects") and entry.has("paid_price") and entry.has("source") and entry.has("weapon_slot"),
		"%s：记录必须含 effects/paid_price/source/weapon_slot，实际键 %s" % [
			context, str(entry.keys())])
	# 非武器条目的 weapon_slot 必须是 -1（约定）
	_ok(int(entry.get("weapon_slot", 0)) == -1, "%s：非武器条目 weapon_slot 应为 -1，实际 %s" % [
		context, str(entry.get("weapon_slot", "缺失"))])

	# heal 是消耗品，不该进持有清单（与原版及 Shop.gd:397 的排除一致）
	_reset_inventory()
	player.apply_upgrade(_make_upgrade("heal", 5))
	_ok(player.get_owned_item_count() == 0, "%s：heal 不应进持有清单，实际 %d 条" % [
		context, player.get_owned_item_count()])


# ─── B. catalog_item 属性精确撤回（本轮核心）───

func _check_catalog_item_precise_revert():
	var context := "B catalog_item 精确撤回"

	var data = load("res://scripts/BrotatoData.gd").new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("%s：道具目录加载失败 %s" % [context, str(errors)])
		return

	# 找一条**纯 stat_delta、无特殊规则**的 max_hp 道具：效果可读、可断言。
	# acid 给 max_hp+8 / dodge-0.02 / knockback —— 三条都是 stat_delta，很适合。
	var item = _find_by_source_id(data.get_shop_pool(false), "acid")
	if item.is_empty():
		failures.append("%s：目录里找不到 acid，无法验证精确撤回" % context)
		return
	_ok(not item.get("effects", []).is_empty(), "%s：前置自检 —— acid 必须带 effects，否则测不到东西" % context)
	if item.get("effects", []).is_empty():
		return

	_reset_inventory()

	# 记录买入前的全部相关属性
	var before_max_hp := int(player.max_hp)
	var before_armor := int(player.armor)
	var before_dodge := float(player.dodge_chance)
	var before_luck := int(player.luck)

	player.apply_upgrade(item)

	# **前置自检**：确认属性真的动了。没动就说明施加路径变了，后面的「撤回」断言毫无意义。
	var applied_max_hp := int(player.max_hp)
	_ok(applied_max_hp == before_max_hp + 8,
		"%s：前置自检 —— 施加 acid 后 max_hp 应为 %d，实际 %d（施加路径可能变了）" % [
			context, before_max_hp + 8, applied_max_hp])
	if applied_max_hp == before_max_hp:
		return

	_ok(player.get_owned_item_count() == 1, "%s：买入后应有 1 条持有记录，实际 %d 条" % [
		context, player.get_owned_item_count()])

	# 出售
	var item_id: int = player.get_last_owned_item_id()
	_ok(item_id > 0, "%s：取最近一条记录 id 应 > 0，实际 %d" % [context, item_id])
	var removed: bool = player.remove_owned_item(item_id)
	_ok(removed, "%s：remove_owned_item(%d) 应返回 true" % [context, item_id])

	# ── 核心断言：属性回到买入前 ──
	var after_max_hp := int(player.max_hp)
	var after_armor := int(player.armor)
	var after_dodge := float(player.dodge_chance)
	var after_luck := int(player.luck)

	_ok(after_max_hp == before_max_hp,
		"%s：撤回后 max_hp 应回到买入前的 %d，实际 %d（买入后是 %d）" % [
			context, before_max_hp, after_max_hp, applied_max_hp])
	_ok(after_armor == before_armor,
		"%s：撤回后 armor 应回到买入前的 %d，实际 %d" % [context, before_armor, after_armor])
	_ok(is_equal_approx(after_dodge, before_dodge),
		"%s：撤回后 dodge 应回到买入前的 %.4f，实际 %.4f" % [context, before_dodge, after_dodge])
	_ok(after_luck == before_luck,
		"%s：撤回后 luck 应回到买入前的 %d，实际 %d" % [context, before_luck, after_luck])

	# 撤回后持有清单必须清空
	_ok(player.get_owned_item_count() == 0, "%s：撤回后持有清单应为 0 条，实际 %d 条" % [
		context, player.get_owned_item_count()])

	# ownership 计数也要一起回退（否则后续限购判断会错）
	_ok(player.get_catalog_item_owned_count("acid") == 0,
		"%s：撤回后 acid 的 ownership 计数应为 0，实际 %d" % [
			context, player.get_catalog_item_owned_count("acid")])


# ─── B2. 撤回是「可加性」而非「夹到边界」───
#
# 这条是区分「真撤回」和「看起来撤回」的关键。
# 先叠一层同属性道具，再撤掉后买的那个 —— 前一个的贡献**必须原封不动**。
# 如果实现是「无脑减到 0 / 夹到某个下限」而不是按记录的量做减法，这里会失败。
func _check_catalog_item_revert_is_additive_not_clamp():
	var context := "B2 撤回可加性"

	var data = load("res://scripts/BrotatoData.gd").new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		failures.append("%s：道具目录加载失败 %s" % [context, str(errors)])
		return
	var acid = _find_by_source_id(data.get_shop_pool(false), "acid")
	if acid.is_empty():
		failures.append("%s：找不到 acid" % context)
		return

	_reset_inventory()
	# 垫一层「别人的贡献」，再叠 acid，撤掉 acid 后前一层必须原封不动。
	#
	# ⚠ 这里全程走 **catalog_item 通道**（`_apply_catalog_stat_delta`），不走
	# `apply_upgrade` 的 legacy match 分支 —— 因为 legacy 分支根本不认
	# `harvesting`/`xp_gain_percent` 这些目录属性（见 apply_upgrade 的 match 列表）。
	# 一开始我用 `_make_upgrade("harvesting", 7)` 走 legacy 通道，
	# 断言「应从 8 增加 7」直接失败（增量 0，因为没这个分支）——
	# 那不是 bug，是我把两条通道搞混了。
	#
	# ⚠ 也刻意**不用** `armor`/`max_hp` 做探针：两者都被 `tank_build`
	# （钢铁堡垒：min_armor 4 + min_max_hp 15 → 护甲+3）这个协同盯着。
	# acid 的 max_hp+8 会把 max_hp 推过 15、**合理地**触发 +3 护甲。
	# `harvesting` 没有任何协同的 requires 读它，是干净的可加性探针。
	var probe_item := _make_catalog_item("harvesting", 7.0)
	var base_harvesting := int(player.gold_per_wave)
	player.apply_upgrade(probe_item)
	var mid_harvesting := int(player.gold_per_wave)
	_ok(mid_harvesting - base_harvesting == 7,
		"%s：前置自检 —— harvesting 应从 %d 增加 7，实际变为 %d（增量 %d）" % [
			context, base_harvesting, mid_harvesting, mid_harvesting - base_harvesting])
	if mid_harvesting - base_harvesting != 7:
		return

	var before_acid_harvesting := int(player.gold_per_wave)
	var before_acid_count: int = player.get_owned_item_count()
	player.apply_upgrade(acid)
	# acid 的 knockback/dodge/max_hp 三条都不该碰 harvesting
	_ok(int(player.gold_per_wave) == before_acid_harvesting,
		"%s：acid 不该动 harvesting，实际从 %d 变成 %d" % [
			context, before_acid_harvesting, int(player.gold_per_wave)])

	# 撤掉 acid
	player.remove_owned_item(player.get_last_owned_item_id())

	# **「别人的贡献」必须还在**（这才是「可加性」的断言：减法只减自己那一份）
	_ok(int(player.gold_per_wave) == before_acid_harvesting,
		"%s：撤回 acid 后 harvesting 应保持 %d（前一个道具的贡献不能被吞掉），实际 %d" % [
			context, before_acid_harvesting, int(player.gold_per_wave)])
	# 之前那些道具仍在清单里（用进入本用例时的条数做基准，不写死数字）
	_ok(player.get_owned_item_count() == before_acid_count,
		"%s：撤掉 acid 后应剩 %d 条记录，实际 %d 条" % [
			context, before_acid_count, player.get_owned_item_count()])


# ─── B3. 移除是幂等的 ───

func _check_inventory_remove_is_idempotent():
	var context := "B3 移除幂等"
	_reset_inventory()
	player.apply_upgrade(_make_upgrade("armor", 1))
	var item_id: int = player.get_last_owned_item_id()
	var first: bool = player.remove_owned_item(item_id)
	var second: bool = player.remove_owned_item(item_id)
	_ok(first, "%s：第一次移除应返回 true" % context)
	_ok(not second, "%s：第二次移除同一 id 应返回 false（幂等），实际 %s" % [context, str(second)])
	_ok(player.get_owned_item_count() == 0, "%s：重复移除后清单仍应为 0 条，实际 %d 条" % [
		context, player.get_owned_item_count()])
	# 不存在的 id 不应炸
	var bogus: bool = player.remove_owned_item(999999)
	_ok(not bogus, "%s：不存在的 id 应返回 false，实际 %s" % [context, str(bogus)])


# ─── A2. 多次购买后条目数正确 ───

func _check_multi_purchase_count():
	var context := "A2 多次购买条目数"
	_reset_inventory()
	var expected := 0
	for i in range(5):
		player.apply_upgrade(_make_upgrade("armor", 1))
		expected += 1
		_ok(player.get_owned_item_count() == expected,
			"%s：第 %d 次施加后应有 %d 条记录，实际 %d 条" % [
				context, i + 1, expected, player.get_owned_item_count()])
	# id 必须互不相同 —— 否则按 id 移除会命中错的那条
	var ids := {}
	var all_items = player.get_owned_items()
	for entry in all_items:
		ids[int(entry.get("id", -1))] = true
	_ok(ids.size() == expected,
		"%s：%d 条记录的 id 必须互不相同，实际只有 %d 个不同 id" % [
			context, expected, ids.size()])

	# 逐个移除，计数应线性下降
	for i in range(expected):
		var remaining := expected - i
		var before_count: int = player.get_owned_item_count()
		_ok(before_count == remaining, "%s：移除前应有 %d 条，实际 %d 条" % [
			context, remaining, before_count])
		player.remove_owned_item(player.get_last_owned_item_id())
	_ok(player.get_owned_item_count() == 0, "%s：全部移除后应为 0 条，实际 %d 条" % [
		context, player.get_owned_item_count()])


# ─── C. 武器按 tier 精确移除（含反向断言）───

func _clear_weapons():
	player.equipped_weapons.clear()
	player.combat.emit_weapons_changed()


func _tiers() -> Array:
	var out: Array = []
	for w in player.equipped_weapons:
		out.append(int(w.get("tier", w.get("level", 1))))
	return out


func _make_sell_entry(weapon_type: String, extra: Dictionary = {}) -> Dictionary:
	var entry := {"name": "test weapon", "type": "weapon", "weapon_type": weapon_type}
	for key in extra:
		entry[key] = extra[key]
	return entry


func _equip_many(pairs: Array, context: String) -> Array:
	_clear_weapons()
	for pair in pairs:
		if not player.equip_or_combine_weapon(str(pair[0]), int(pair[1])):
			failures.append("%s：前置装备失败（%s T%d），后续断言不可信" % [context, pair[0], pair[1]])
			return []
	var after := _tiers()
	if after.size() != pairs.size():
		# 合成规则可能把同型武器合并掉，导致「装上 2 把实际只有 1 把」
		failures.append("%s：前置自检失败，期望装上 %d 把，实际 %d 把 %s" % [
			context, pairs.size(), after.size(), str(after)])
		return []
	return after


func _check_weapon_removal_by_tier_both_directions():
	var context := "C 武器按 tier 精确移除"
	if player.get_max_weapon_slots() < 2:
		failures.append("%s：前置条件不成立 —— 武器槽 %d < 2" % [
			context, player.get_max_weapon_slots()])
		return

	# 正向：卖 T2 → 留下 T1
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [1, 2], "%s：前置分阶期望 [1, 2]，实际 %s" % [context, str(tiers)])
	if tiers != [1, 2]:
		return
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 2}))
	var after = _tiers()
	_ok(after == [1], "%s：卖 T2 后应留 T1，实际 %s（移除前 %s）" % [
		context, str(after), str(tiers)])

	# ── 反向断言：卖 T1 → 留下 T2 ──
	# 乱序装备是刻意的：防止实现靠遍历顺序蒙对。
	var context2 := "C2 反向 —— 卖 T1 留 T2"
	var tiers2 := _equip_many([[SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context2)
	if tiers2.is_empty():
		return
	_ok(tiers2 == [2, 1], "%s：前置分阶期望 [2, 1]（乱序装备），实际 %s" % [context2, str(tiers2)])
	if tiers2 != [2, 1]:
		return
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 1}))
	var after2 = _tiers()
	_ok(after2 == [2], "%s：卖 T1 后应留 T2，实际 %s（移除前 %s）" % [
		context2, str(after2), str(tiers2)])


func _check_weapon_removal_slot_index_roundtrip():
	var context := "C3 slot_index 往返"
	# 3 把同类型不同分阶，按下标删中间那把 —— 只有 slot_index 能唯一确定。
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

	# slot_index 指向别的类型时必须降级而非误删
	var context2 := "C4 slot_index 类型不符时降级"
	_clear_weapons()
	if not player.equip_or_combine_weapon(SAMPLE_WEAPON, 1):
		failures.append("%s：前置装备 %s T1 失败" % [context2, SAMPLE_WEAPON])
		return
	if not player.equip_or_combine_weapon("pistol", 1):
		failures.append("%s：前置装备 pistol T1 失败" % [context2])
		return
	_ok(str(player.equipped_weapons[1].type) == "pistol",
		"%s：前置自检 —— slot 1 应为 pistol，实际 %s" % [context2, str(player.equipped_weapons[1].type)])
	if str(player.equipped_weapons[1].type) != "pistol":
		return
	player.remove_upgrade(_make_sell_entry(SAMPLE_WEAPON, {"tier": 1, "slot_index": 1}))
	var types_after: Array = []
	for w in player.equipped_weapons:
		types_after.append(str(w.type))
	_ok(types_after == ["pistol"],
		"%s：索引与类型不符时应降级删 smg、留下 pistol，实际 %s" % [context2, str(types_after)])


# ─── D. get_weapon_info 的 slot_index 与下标一致 ───

func _check_weapon_info_slot_index_matches_position():
	var context := "D slot_index 一致性"
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2]], context)
	if tiers.is_empty():
		return

	var info: Array = player.get_weapon_info()
	_ok(info.size() == player.equipped_weapons.size(),
		"%s：get_weapon_info 条数(%d)必须等于 equipped_weapons 条数(%d) —— 少一条就会让下标错位" % [
			context, info.size(), player.equipped_weapons.size()])
	if info.size() != player.equipped_weapons.size():
		return

	for i in range(info.size()):
		var entry = info[i]
		_ok(entry is Dictionary and entry.has("slot_index"),
			"%s：第 %d 条必须带 slot_index 字段，实际键 %s" % [
				context, i, str(entry.keys() if entry is Dictionary else entry)])
		if not (entry is Dictionary and entry.has("slot_index")):
			continue
		_ok(int(entry.get("slot_index", -99)) == i,
			"%s：第 %d 条的 slot_index 应为 %d，实际 %s" % [
				context, i, i, str(entry.get("slot_index", "缺失"))])
		# 交叉校验：info 第 i 条描述的就是 equipped_weapons[i]
		_ok(str(entry.get("type", "")) == str(player.equipped_weapons[i].type),
			"%s：第 %d 条 type 应为 %s，实际 %s（下标错位）" % [
				context, i, str(player.equipped_weapons[i].type), str(entry.get("type", ""))])

	# 空武器时不能报错，且返回空数组
	_clear_weapons()
	var empty_info: Array = player.get_weapon_info()
	_ok(empty_info.is_empty(), "%s：无武器时应返回空数组，实际 %d 条" % [context, empty_info.size()])


# ─── B3. tooltip 字段齐备 ───

func _check_weapon_info_tooltip_fields():
	var context := "B3 tooltip 字段"
	var tiers := _equip_many([[SAMPLE_WEAPON, 1]], context)
	if tiers.is_empty():
		return
	var info: Array = player.get_weapon_info()
	if info.is_empty():
		failures.append("%s：前置自检 —— 装上武器后 info 不该为空" % context)
		return
	var entry: Dictionary = info[0]

	# 既有字段必须一个不少（Shop.gd 与其它测试都在读）
	for key in ["name", "type", "level", "tier", "damage", "fire_rate", "can_combine", "max_level"]:
		_ok(entry.has(key), "%s：既有字段 %s 不能丢（Shop.gd 在读它）" % [context, key])

	# 新增 tooltip 字段
	for key in ["slot_index", "melee", "range", "melee_radius", "crit_chance", "crit_damage",
			"cooldown", "projectile_count", "spread", "pierce", "bounces", "special_rules",
			"color", "tier_color"]:
		_ok(entry.has(key), "%s：tooltip 字段 %s 缺失，键集 %s" % [context, key, str(entry.keys())])

	# 结构断言：pierce 必须是 {count, full}，消费端才能统一读
	var pierce = entry.get("pierce", null)
	_ok(pierce is Dictionary and pierce.has("count") and pierce.has("full"),
		"%s：pierce 应为含 count/full 的字典，实际 %s" % [context, str(pierce)])
	var rules = entry.get("special_rules", null)
	_ok(rules is Array, "%s：special_rules 应为数组，实际 %s" % [context, str(rules)])
	# cooldown 必须为正（否则 UI 会显示 0s 秒，玩家以为是 bug）
	_ok(float(entry.get("cooldown", 0.0)) > 0.0,
		"%s：cooldown 应为正数，实际 %s" % [context, str(entry.get("cooldown", 0.0))])


# ─── 非 catalog_item 也走账本撤回 ───

func _check_non_catalog_revert_via_ledger():
	var context := "E 非 catalog_item 经账本撤回"
	_reset_inventory()
	var before_armor := int(player.armor)
	player.apply_upgrade(_make_upgrade("armor", 5))
	var applied_armor := int(player.armor)
	_ok(applied_armor == before_armor + 5,
		"%s：前置自检 —— armor 应为 %d，实际 %d" % [context, before_armor + 5, applied_armor])
	if applied_armor != before_armor + 5:
		return
	_ok(player.get_owned_item_count() == 1, "%s：应有 1 条记录，实际 %d" % [
		context, player.get_owned_item_count()])
	player.remove_owned_item(player.get_last_owned_item_id())
	_ok(int(player.armor) == before_armor,
		"%s：撤回后 armor 应回到 %d，实际 %d" % [context, before_armor, int(player.armor)])
	_ok(player.get_owned_item_count() == 0, "%s：撤回后清单应为 0 条" % context)


# ─── 武器账本记录槽位 ───

func _check_weapon_ledger_slot_after_equip():
	var context := "F 武器账本槽位"
	_reset_inventory()
	_clear_weapons()
	if not player.equip_or_combine_weapon(SAMPLE_WEAPON, 1):
		failures.append("%s：前置装备 %s T1 失败" % [context, SAMPLE_WEAPON])
		return
	# 直接调 combat 不会记账（账本挂在 apply_upgrade 上）——
	# 所以这里走 apply_upgrade 的 weapon 分支模拟购买。
	_reset_inventory()
	player.apply_upgrade({"type": "weapon", "weapon_type": SAMPLE_WEAPON, "tier": 2, "name": "测试武器"})
	var items = player.get_owned_items()
	_ok(items.size() == 1, "%s：施加 weapon 升级后应有 1 条记录，实际 %d 条" % [context, items.size()])
	if items.is_empty():
		return
	var entry: Dictionary = items[0]
	_ok(str(entry.get("weapon_type", "")) == SAMPLE_WEAPON,
		"%s：weapon_type 应为 %s，实际 %s" % [context, SAMPLE_WEAPON, str(entry.get("weapon_type", ""))])
	var slot := int(entry.get("weapon_slot", -2))
	_ok(slot >= 0 and slot < player.equipped_weapons.size(),
		"%s：weapon_slot 应落在 [0, %d)，实际 %d" % [context, player.equipped_weapons.size(), slot])
	if slot >= 0 and slot < player.equipped_weapons.size():
		_ok(str(player.equipped_weapons[slot].type) == SAMPLE_WEAPON,
			"%s：weapon_slot=%d 指向的应是 %s，实际 %s" % [
				context, slot, SAMPLE_WEAPON, str(player.equipped_weapons[slot].type)])
