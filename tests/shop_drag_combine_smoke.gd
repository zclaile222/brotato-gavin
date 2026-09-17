extends SceneTree

# 商店武器卡「拖拽合成 / 出售 / 锁定跨波次」冒烟测试
#
# 覆盖 4 项（对应任务书 A1-A5）：
#   1. 拖拽合成正向：两把同名同阶 → 走 _get_drag_data / _drop_data → 数量 -1 且剩者 tier +1；
#   2. 拖拽合成反向：两把不同名 → 不合成、数量不变（防止「拖了就合」的过度实现）；
#   3. 出售武器：卖出后武器从 equipped_weapons 消失，且删的是**指定那一把**（压 R2）；
#   4. 锁定跨波次：open() → 锁槽 0 → _on_start_wave_pressed() → 再 open() → 槽 0 仍是原商品、价格未变。
#
# 写法约定（本项目测试硬约定）：
#   - --headless 下直接调回调，不需要真实鼠标事件；拖放用
#     drag_node._get_drag_data(pos) / _can_drop_data(pos, data) / _drop_data(pos, data) 手工驱动；
#   - --script 模式 root 视口只有 64x64，控件实际尺寸可能为 0 —— 所有拖放调用都传 (0, 0)
#     位置，回调本身不依赖坐标，只依赖 payload；
#   - 同步清理用 free()，不用 queue_free()（队列释放要等一帧，断言会读到脏数据）；
#   - 每条断言都带期望值/实际值，并先做前置自检，避免「没装上」被误判成「删对了」的空转。

const PASS_TAG := "SHOP_DRAG_COMBINE_SMOKE_PASS"
const FAIL_TAG := "SHOP_DRAG_COMBINE_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 20

# smg 在 weapons.json 里 4 个分阶俱全，是天然的同类型多分阶样本。
const SAMPLE_WEAPON := "smg"
# 与 smg 不同的武器，用于反向断言（不同名不得合成）。
const OTHER_WEAPON := "pistol"

var failures: Array[String] = []
var checks: int = 0

var player = null
var shop = null
var host: Node = null


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

	var player_scene = load("res://scenes/Player.tscn")
	if player_scene == null:
		failures.append("Player 场景缺失")
		_report()
		return
	player = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	if player.get_max_weapon_slots() < 2:
		failures.append("前置条件不成立：get_max_weapon_slots()=%d，本测试需要 >=2 个格子" % player.get_max_weapon_slots())
		_report()
		return

	shop = _make_shop_host()
	if shop == null:
		_report()
		return

	_check_drag_combine_forward()
	_check_drag_no_combine_on_different_weapons()
	_check_bought_weapon_entry_does_not_carry_card_slot()
	_check_weapon_sell_targets_exact_slot()
	_check_lock_survives_wave_cycle_with_frozen_price()

	_cleanup()
	_report()


# ─── 宿主搭建 ───

# Shop 是 CanvasLayer，需要挂在场景树里才能用 $Panel/... 与 create_tween。
# Shop.gd 的 _ready() 会连 $Panel/ButtonRow/* 按钮并建出售/提示/升级三块区域，
# 所以宿主必须提供同名节点，否则 _ready 直接崩。
func _make_shop_host() -> CanvasLayer:
	var shop_script = load("res://scripts/Shop.gd")
	if shop_script == null:
		failures.append("Shop.gd 加载失败")
		return null

	host = Node.new()
	host.name = "ShopSmokeHost"
	root.add_child(host)

	var shop_instance = CanvasLayer.new()
	shop_instance.name = "Shop"
	shop_instance.set_script(shop_script)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	shop_instance.add_child(panel)

	var title := Label.new()
	title.name = "Title"
	panel.add_child(title)

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	panel.add_child(gold_label)

	# _build_item_cards 会把卡片加到 $Panel/ItemRow。
	var item_row := HBoxContainer.new()
	item_row.name = "ItemRow"
	panel.add_child(item_row)

	var button_row := HBoxContainer.new()
	button_row.name = "ButtonRow"
	panel.add_child(button_row)

	var reroll_btn := Button.new()
	reroll_btn.name = "RerollButton"
	button_row.add_child(reroll_btn)

	var start_btn := Button.new()
	start_btn.name = "StartWaveButton"
	button_row.add_child(start_btn)

	host.add_child(shop_instance)
	# 手动触发 _ready（headless 下 add_child 已触发，但显式调用可保证顺序可控）。
	if not shop_instance.is_node_ready():
		shop_instance._ready()
	if shop_instance.get("ITEM_POOL") == null or shop_instance.ITEM_POOL.is_empty():
		failures.append("前置条件不成立：Shop.ITEM_POOL 为空，商店无法掷出商品")
		return null
	return shop_instance


# 驱动一次「拖 slot a 落到 slot b」的完整回调链，返回 payload。
# 走真实的 _get_drag_data / _can_drop_data / _drop_data，只有鼠标事件被替换成直接调用。
func _drag_weapon(from_slot: int, to_slot: int, context: String):
	var from_node: Node = _drag_node_of(from_slot)
	var to_node: Node = _drag_node_of(to_slot)
	if from_node == null:
		failures.append("%s：前置自检失败，槽 %d 没有拖拽节点" % [context, from_slot])
		return null
	if to_node == null:
		failures.append("%s：前置自检失败，槽 %d 没有拖拽节点" % [context, to_slot])
		return null

	var payload = from_node._get_drag_data(Vector2.ZERO)
	if payload == null:
		failures.append("%s：拖拽源槽 %d 的 _get_drag_data 返回 null，拖拽根本没起来" % [context, from_slot])
		return null

	if not to_node._can_drop_data(Vector2.ZERO, payload):
		# 不一定是失败 —— 反向用例就期望 false。由调用方决定。
		return payload

	to_node._drop_data(Vector2.ZERO, payload)
	return payload


# 取升级区第 slot 张卡上的拖拽承载节点。
# _refresh_upgrade_area 往 upgrade_hbox 里先塞标题 Label，再依次塞武器卡，
# 所以第 slot 张武器卡 = upgrade_hbox 的第 (slot + 1) 个子节点。
func _drag_node_of(slot: int):
	if shop == null or shop.upgrade_hbox == null:
		return null
	var hbox = shop.upgrade_hbox
	var card_index := slot + 1
	if card_index >= hbox.get_child_count():
		return null
	var card = hbox.get_child(card_index)
	if card == null:
		return null
	return card.get_node_or_null("DragNode")


# ─── 辅助 ───

func _ok(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)


func _clear_weapons():
	player.equipped_weapons.clear()
	player.combat.emit_weapons_changed()


# 把一组武器**原样摆进** equipped_weapons，不走 equip_or_combine_weapon。
#
# 为什么不能走 equip_or_combine_weapon 做前置：它内部会 _find_combine_partner，
# 装第二把同名同阶时**自动就合成了** —— 前置一装完就变成 [T2]，测试永远测不到拖拽。
# 所以这里直接构造武器对象塞进数组，把两头 T1 的原始状态精确摆出来。
func _equip_many(pairs: Array, context: String) -> Array:
	_clear_weapons()
	for pair in pairs:
		var weapon_type := str(pair[0])
		var tier := int(pair[1])
		var weapon = player.combat._make_weapon(weapon_type, tier)
		if weapon == null:
			failures.append("%s：前置构造武器失败（%s T%d），后续断言不可信" % [context, weapon_type, tier])
			return []
		player.equipped_weapons.append(weapon)
	player.combat.emit_weapons_changed()
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


func _shop_weapon_types() -> Array:
	var out: Array = []
	for w in player.equipped_weapons:
		out.append(str(w.data.name))
	return out


# 让商店进入「已开、金币充足」的状态。
func _open_shop(gold: int, context: String) -> bool:
	if shop == null:
		failures.append("%s：shop 为空" % context)
		return false
	player.earn_gold(gold)
	shop.open(1, player.gold, player.luck, player)
	if shop.current_items.size() != 4:
		failures.append("%s：前置自检失败，商店应掷出 4 件商品，实际 %d 件" % [context, shop.current_items.size()])
		return false
	shop._refresh_upgrade_area()
	return true


# ─── 1. 拖拽合成正向 ───

func _check_drag_combine_forward():
	var context := "1 拖拽合成正向"
	# 用 [T1, T2, T1] 而不是 [T1, T1]：这样「拖 0 落到 2」和「拖 2 落到 0」是同一件事，
	# 但 combine_weapon(0) 与 combine_weapon(2) 结果**不可互换** —— 若实现忽略拖拽源、
	# 永远拿固定槽去合，分阶序列会明显不同。纯 [T1, T1] 的用例对这类变异是盲的。
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [1, 2, 1], "%s：前置分阶期望 [1, 2, 1]，实际 %s" % [context, str(tiers)])
	if tiers != [1, 2, 1]:
		return

	if not _open_shop(500, context):
		return

	# 前置自检：slot 0（T1）与 slot 2（T1）必须可合，slot 1（T2）不可合（无同阶伙伴）。
	_ok(player.can_combine_weapon(0), "%s：前置自检，slot 0 应可合成，实际 %s" % [
		context, str(player.can_combine_weapon(0))])
	_ok(not player.can_combine_weapon(1), "%s：前置自检，slot 1（T2）不可合成，实际 %s" % [
		context, str(player.can_combine_weapon(1))])
	_ok(shop._weapon_drag_can_drop(2, {"source": "shop_weapon_card", "slot_index": 0, "weapon_type": SAMPLE_WEAPON, "tier": 1}),
		"%s：前置自检，_can_drop_data(slot 2) 应为 true" % context)

	var before_count: int = player.equipped_weapons.size()
	var payload = _drag_weapon(0, 2, context)
	if payload == null:
		return

	var after_tiers := _tiers()
	_ok(player.equipped_weapons.size() == before_count - 1,
		"%s：合成后武器数应为 %d（原 %d 把 - 1），实际 %d 把，分阶 %s" % [
			context, before_count - 1, before_count, player.equipped_weapons.size(), str(after_tiers)])
	# keep_index = min(0, 2) = 0 → T1+T1 合成后落在槽 0，槽 1 的 T2 原样保留。
	_ok(after_tiers == [2, 2],
		"%s：期望 [2, 2]（槽 0 的 T1 与槽 2 的 T1 合成升为 T2，槽 1 的 T2 不动），实际 %s（合成前 %s）" % [
			context, str(after_tiers), str(tiers)])
	# 拖拽状态必须收干净，否则下一次拖拽会带着陈旧的源栏位。
	_ok(shop._drag_source_slot == -1,
		"%s：拖拽结束后 _drag_source_slot 应复位为 -1，实际 %d" % [context, shop._drag_source_slot])

	# 反向：拖 slot 2 落到 slot 0，结果必须等价（证明合成看的是「哪两把同阶」，
	# 而不是「拖拽方向」或某个写死的槽位）。
	var context2 := "1b 反方向拖拽等价"
	var tiers2 := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context2)
	if tiers2.is_empty():
		return
	if not _open_shop(500, context2):
		return
	_drag_weapon(2, 0, context2)
	var after2 := _tiers()
	_ok(after2 == [2, 2],
		"%s：反向拖拽（2→0）应与正向（0→2）同结果 [2, 2]，实际 %s（合成前 %s）" % [
			context2, str(after2), str(tiers2)])

	# 1c：**目标槽必须被校验**。往一个不可合成的槽（slot 1 是 T2，没有同阶伙伴）上放，
	# 必须什么都不发生。这条能抓住「忽略目标槽、拿固定槽去合」的实现变体：
	# 如果实现无视 target_slot 而永远合 slot 0，这里 slot 0/2 的 T1 会被合并，断言就会红。
	var context3 := "1c 落到不可合成槽不得生效"
	var tiers3 := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context3)
	if tiers3.is_empty():
		return
	if not _open_shop(500, context3):
		return
	_ok(not shop._weapon_drag_can_drop(1, {"source": "shop_weapon_card", "slot_index": 0, "weapon_type": SAMPLE_WEAPON, "tier": 1}),
		"%s：前置自检，落到 slot 1（T2，无同阶伙伴）应判为不可放置" % context3)

	_drag_weapon(0, 1, context3)
	var after3 := _tiers()
	_ok(after3 == [1, 2, 1],
		"%s：落到不可合成槽后分阶应保持 [1, 2, 1]，实际 %s（若实现无视目标槽去合 slot 0，这里会变成 [2, 2]）" % [
			context3, str(after3)])

	# 1d：同样是「目标槽必须被校验」，但换成跳过 _can_drop_data 直接硬调 _drop_data，
	# 证明 _drop_data 内部有独立校验，不依赖 Godot 先调 _can_drop_data。
	var context4 := "1d 硬调 _drop_data 到非法槽"
	var tiers4 := _equip_many([[SAMPLE_WEAPON, 1], [SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context4)
	if tiers4.is_empty():
		return
	if not _open_shop(500, context4):
		return
	var payload4 := {"source": "shop_weapon_card", "slot_index": 2, "weapon_type": SAMPLE_WEAPON, "tier": 1}
	shop._weapon_drag_drop(1, payload4)
	var after4 := _tiers()
	_ok(after4 == [1, 2, 1],
		"%s：硬调 _drop_data 到非法槽后分阶应保持 [1, 2, 1]，实际 %s（_drop_data 必须自查 _can_drop_data）" % [
			context4, str(after4)])


# ─── 2. 不同名武器不得合成 ───

func _check_drag_no_combine_on_different_weapons():
	var context := "2 不同名不合成"
	var tiers := _equip_many([[SAMPLE_WEAPON, 1], [OTHER_WEAPON, 1]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [1, 1], "%s：前置分阶期望 [1, 1]，实际 %s" % [context, str(tiers)])
	if tiers != [1, 1]:
		return

	if not _open_shop(500, context):
		return

	var before_count: int = player.equipped_weapons.size()
	var before_types := _types()

	# 前置自检：不同名的两把武器必须**不可**合成，这是本用例成立的前提。
	_ok(not player.can_combine_weapon(1),
		"%s：前置自检，slot 1 不应可合成，实际 can_combine_weapon(1)=%s" % [context, str(player.can_combine_weapon(1))])

	var payload = _drag_weapon(0, 1, context)
	if payload == null:
		return

	var can_drop = shop._weapon_drag_can_drop(1, payload)
	_ok(not can_drop, "%s：不同名武器 _can_drop_data 应为 false，实际 %s" % [context, str(can_drop)])

	# 即便硬调 _drop_data 也不能改变任何东西（防止实现漏判 _can_drop_data）。
	shop._weapon_drag_drop(1, payload)
	_ok(player.equipped_weapons.size() == before_count,
		"%s：硬调 drop 后武器数应保持 %d，实际 %d（分阶 %s，类型 %s）" % [
			context, before_count, player.equipped_weapons.size(), str(_tiers()), str(_types())])
	_ok(_types() == before_types,
		"%s：武器类型顺序应保持 %s，实际 %s" % [context, str(before_types), str(_types())])
	_ok(_tiers() == [1, 1],
		"%s：分阶不应被改动，期望 [1, 1]，实际 %s" % [context, str(_tiers())])


# ─── 3.5 购买记录不得把「商店卡槽号」当成「装备位号」───
#
# 这是 weapon-remove 交叉评审时发现的真缺陷（我已复现并修）：
# _on_buy_pressed 的 index 是 **current_items（商店卡槽）** 的下标，
# 而 PlayerUpgrades._find_weapon_slot_to_remove 把 slot_index 解释为
# **equipped_weapons（装备位）** 的下标。两个编号空间无关。
#
# 后果：装备位 2 是 smg T2，玩家从商店卡槽 2 买一把 smg T1，
# 之后卖这把 T1 -> slot_index=2 命中装备位 2 的类型校验（都是 smg）
# -> 直接删掉装备位 2 的 T2，不降级、不比 tier。
#
# 修法：购买记录**不写** slot_index，只留 weapon_type + tier，
# 让 _find_weapon_slot_to_remove 走第 2 优先级（type + tier）匹配。
# 这样「买来的 T1」和「装备里的 T2」靠 tier 就能分开，不会误删。
func _check_bought_weapon_entry_does_not_carry_card_slot():
	var context := "3.5 购买记录不带商店卡槽号"
	var tiers := _equip_many([[SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 2]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [2, 2, 2], "%s：前置分阶期望 [2, 2, 2]，实际 %s" % [context, str(tiers)])
	if tiers != [2, 2, 2]:
		return

	if not _open_shop(500, context):
		return

	# 把商店卡槽 2 摆成一把同类型的 T1，然后走真实的购买路径。
	# 这样 _on_buy_pressed 里的 index 就是 2 —— 与装备位 2 撞号。
	var bought_item := {
		"name": str(player.combat.WEAPON_DATA[SAMPLE_WEAPON].get("name", SAMPLE_WEAPON)),
		"type": "weapon",
		"weapon_type": SAMPLE_WEAPON,
		"tier": 1,
		"price": 10,
		"rarity": 0,
	}
	shop.current_items[2] = bought_item
	shop.current_items[1] = bought_item.duplicate()
	shop.current_items[0] = bought_item.duplicate()
	shop.current_items[3] = bought_item.duplicate()
	shop._build_item_cards()
	shop.player_gold = 500
	player.earn_gold(500)

	var before_count: int = player.equipped_weapons.size()
	shop._on_buy_pressed(2, Button.new(), Label.new())

	# 前置自检：这次购买真的被记录下来了吗？没记下来说明买的不是武器/被 heal 过滤，
	# 后续断言会读不到条目而空转。
	var bought_entry: Dictionary = {}
	for entry in shop.purchased_items:
		if str(entry.get("type", "")) == "weapon":
			bought_entry = entry
			break
	if bought_entry.is_empty():
		failures.append("%s：前置自检失败，购买记录里没有武器条目，后续断言不可信" % context)
		return

	# 核心断言：购买记录里**不得**出现 slot_index。
	# 一旦出现，就是「卡槽号冒充装备位号」，指向的装备位完全可能是另一把武器。
	_ok(not bought_entry.has("slot_index"),
		"%s：购买记录不得带 slot_index（那是商店卡槽号，会被 PlayerUpgrades 当成装备位号），实际 %s" % [
			context, str(bought_entry)])
	_ok(str(bought_entry.get("weapon_type", "")) == SAMPLE_WEAPON,
		"%s：购买记录应带 weapon_type=%s，实际 %s" % [context, SAMPLE_WEAPON, str(bought_entry.get("weapon_type", ""))])
	_ok(int(bought_entry.get("tier", -1)) == 1,
		"%s：购买记录应带 tier=1，实际 %s" % [context, str(bought_entry.get("tier", -1))])

	# 行为断言：卖掉这把买来的 T1，装备里的三把 T2 必须一把不少。
	# 若购买记录带了 slot_index=2，这里会误删装备位 2。
	var entry_index: int = shop.purchased_items.find(bought_entry)
	shop._on_sell_pressed(entry_index)

	var after_tiers := _tiers()
	_ok(player.equipped_weapons.size() == before_count,
		"%s：卖掉买来的 T1 后装备位数量应保持 %d，实际 %d（分阶 %s）——少了就是误删了同类型的装备武器" % [
			context, before_count, player.equipped_weapons.size(), str(after_tiers)])
	_ok(after_tiers == [2, 2, 2],
		"%s：装备里的三把 T2 必须一把不少，实际 %s" % [context, str(after_tiers)])


# ─── 3. 出售武器必须精确命中指定那一把（压 R2）───

func _check_weapon_sell_targets_exact_slot():
	var context := "3 出售指定那一把"
	# 同类型不同分阶，且**故意乱序**装备：出售槽 1 必须留下 T1，而不是靠遍历顺序蒙对。
	var tiers := _equip_many([[SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context)
	if tiers.is_empty():
		return
	_ok(tiers == [2, 1], "%s：前置分阶期望 [2, 1]（乱序装备，防遍历顺序蒙对），实际 %s" % [
		context, str(tiers)])
	if tiers != [2, 1]:
		return

	if not _open_shop(500, context):
		return

	# 前置自检：出售入口真的渲染出来了，且槽 1 确实是 T1。
	var sell_btn := _find_weapon_sell_button(1)
	if sell_btn == null:
		failures.append("%s：前置自检失败，出售区没有槽 1 的武器出售按钮（A4 未生效）" % context)
		return
	_ok(_weapon_tier_at(1) == 1, "%s：前置自检，槽 1 应为 T1，实际 T%d" % [context, _weapon_tier_at(1)])

	var gold_before: int = player.gold
	shop._on_weapon_sell_pressed(1)

	var after_tiers := _tiers()
	_ok(player.equipped_weapons.size() == 1,
		"%s：卖出 1 把后应剩 1 把，实际 %d 把 %s" % [context, player.equipped_weapons.size(), str(after_tiers)])
	_ok(after_tiers == [2],
		"%s：卖出槽 1（T1）后应留下 T2（槽 0），实际留下 %s（卖出前 %s）" % [
			context, str(after_tiers), str(tiers)])
	_ok(_types() == [SAMPLE_WEAPON],
		"%s：剩下的应是 %s，实际 %s" % [context, SAMPLE_WEAPON, str(_types())])
	_ok(player.gold > gold_before,
		"%s：出售后玩家金币应增加，期望 > %d，实际 %d" % [context, gold_before, player.gold])

	# 反向再压一次：卖槽 0（T2）必须留下 T1，证明不是「永远删最后一把」。
	var context2 := "3b 反向卖 slot 0"
	var tiers2 := _equip_many([[SAMPLE_WEAPON, 2], [SAMPLE_WEAPON, 1]], context2)
	if tiers2.is_empty():
		return
	if not _open_shop(500, context2):
		return
	shop._on_weapon_sell_pressed(0)
	var after2 := _tiers()
	_ok(after2 == [1],
		"%s：卖出槽 0（T2）后应留下 T1，实际 %s（卖出前 %s）" % [context2, str(after2), str(tiers2)])

	# 3c：**tier 歧义**场景 —— 这是唯一能验证 slot_index 不可替代的用例。
	# 装两把完全同类型同分阶的武器 [T1, T1]，卖槽 1。
	# 此时 weapon_type + tier 根本分不出是哪一把（两把都符合），
	# 只有 slot_index 能定位；若实现不带 slot_index，底层会删掉先遍历到的槽 0。
	# 用两把「同名同阶但可区分」的方式验证：靠 slot_index 定位后，
	# 保留的那把必须仍是槽 0 的那**同一个对象**（比对象身份，不比属性）。
	var context3 := "3c tier 歧义下靠 slot_index 定位"
	_clear_weapons()
	var w0 = player.combat._make_weapon(SAMPLE_WEAPON, 1)
	var w1 = player.combat._make_weapon(SAMPLE_WEAPON, 1)
	if w0 == null or w1 == null:
		failures.append("%s：前置构造武器失败" % context3)
		return
	# 打标记以便区分两个同属性对象（只用于测试内身份判定）。
	w0.data["__test_marker"] = "keep_me"
	w1.data["__test_marker"] = "sell_me"
	player.equipped_weapons.append(w0)
	player.equipped_weapons.append(w1)
	player.combat.emit_weapons_changed()

	_ok(player.equipped_weapons.size() == 2, "%s：前置自检期望 2 把，实际 %d 把" % [
		context3, player.equipped_weapons.size()])
	if player.equipped_weapons.size() != 2:
		return

	if not _open_shop(500, context3):
		return

	shop._on_weapon_sell_pressed(1)

	var remaining = player.equipped_weapons
	_ok(remaining.size() == 1, "%s：卖出 1 把后应剩 1 把，实际 %d 把" % [context3, remaining.size()])
	if remaining.size() == 1:
		_ok(str(remaining[0].data.get("__test_marker", "")) == "keep_me",
			"%s：卖槽 1 后留下的必须是槽 0 那把（keep_me），实际留下 %s" % [
				context3, str(remaining[0].data.get("__test_marker", "<无标记>"))])


func _find_weapon_sell_button(slot: int) -> Button:
	if shop == null or shop.sell_vbox == null:
		return null
	var seen := 0
	for child in shop.sell_vbox.get_children():
		var buttons := _collect_weapon_sell_buttons(child)
		for btn in buttons:
			if seen == slot:
				return btn
			seen += 1
	return null


func _collect_weapon_sell_buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button and node.has_meta("_is_weapon_sell_button"):
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_weapon_sell_buttons(child))
	return out


func _weapon_tier_at(slot: int) -> int:
	if player == null or slot < 0 or slot >= player.equipped_weapons.size():
		return 1
	var w = player.equipped_weapons[slot]
	return int(w.get("tier", w.get("level", 1)))


# ─── 4. 锁定必须跨波次保留，且价格冻结 ───
#
# 真实生命周期（读 Main.gd 得到，不是推测）：
#   波 N 战斗结束 → _on_wave_ended() → 奖励结算 → shop.open(wave=N)   ← 商店为第 N 波开
#              → 玩家锁定商品 / 重掷 / 购买
#              → 玩家按「开始战斗」_on_start_wave_pressed() → 进入第 N+1 波
#              → 第 N+1 波结束 → shop.open(wave=N+1)
#
# 关键结论：**锁定的存活区只跨到下一次 open() 之前**，而两次 open() 之间**没有**
# _on_start_wave_pressed 之外的清空点。所以：
#   - open() 清锁定 = 跨波次锁定必然失效（这就是要修的原缺陷）；
#   - _on_start_wave_pressed() 清锁定 = 正确，玩家已经离开这个商店去打下一波了。
# 因此本用例的驱动顺序是 open → lock → open，**不能**在中间插 _on_start_wave_pressed，
# 否则测的是「按了开始战斗之后锁定还在不在」——那是另一个问题，且答案应为「不在」。
func _check_lock_survives_wave_cycle_with_frozen_price():
	var context := "4 锁定跨波次 + 价格冻结"
	_clear_weapons()

	if shop == null:
		failures.append("%s：shop 为空" % context)
		return

	# 第一波：开启商店并锁定槽 0。
	player.earn_gold(500)
	shop.open(1, player.gold, player.luck, player)
	if shop.current_items.size() != 4:
		failures.append("%s：前置自检失败，商店应掷出 4 件商品，实际 %d 件" % [context, shop.current_items.size()])
		return
	shop._refresh_upgrade_area()

	var locked_item = shop.current_items[0]
	var locked_name = str(locked_item.name)
	shop._on_lock_pressed(0, Button.new())

	_ok(0 in shop.locked_indices, "%s：前置自检，按下锁定后 locked_indices 应含 0，实际 %s" % [
		context, str(shop.locked_indices)])
	_ok(shop.locked_prices.has(0), "%s：前置自检，锁定时应写入价格快照 locked_prices[0]，实际 %s" % [
		context, str(shop.locked_prices)])

	var price_before: int = int(shop.locked_prices.get(0, -1))
	var rarity_before = locked_item.get("rolled_rarity", locked_item.get("rarity", 0))
	var expected_before: int = shop.shop_rules.get_price(locked_item.price, rarity_before, 1, shop._get_item_price_modifier())
	_ok(price_before == expected_before,
		"%s：波次 1 锁定价期望 %d，实际 %d" % [context, expected_before, price_before])

	# 跨波次：同一商店阶段重掷一帧，再进到下一波的 open()。
	# （真实流程里 open(N) 与 open(N+1) 之间隔着整场第 N 波战斗，这里直接跳到 open。）
	shop.open(2, player.gold, player.luck, player)
	if shop.current_items.size() != 4:
		failures.append("%s：第二波商店应掷出 4 件商品，实际 %d 件" % [context, shop.current_items.size()])
		return

	_ok(0 in shop.locked_indices,
		"%s：跨波次后 locked_indices 仍应含 0，实际 %s（open() 里的 clear() 把锁定冲掉了）" % [
			context, str(shop.locked_indices)])
	_ok(str(shop.current_items[0].name) == locked_name,
		"%s：跨波次后槽 0 应仍是 %s，实际 %s" % [context, locked_name, str(shop.current_items[0].name)])
	_ok(shop.locked_prices.has(0),
		"%s：跨波次后价格快照 locked_prices[0] 应仍在，实际 %s" % [context, str(shop.locked_prices)])

	var price_after: int = int(shop.locked_prices.get(0, -1))
	_ok(price_after == price_before,
		"%s：跨波次后锁定价应冻结在 %d，实际 %d" % [context, price_before, price_after])

	# 关键：卡片上**实际显示和结算用**的价格也必须还是冻结价，
	# 而不是被 wave_num 抬高后的现算价。这是本用例真正的考点。
	var frozen_price: int = shop._price_for_slot(shop.current_items[0], 0,
		shop.current_items[0].get("rolled_rarity", shop.current_items[0].get("rarity", 0)))
	_ok(frozen_price == price_before,
		"%s：第 2 波槽 0 的成交价应冻结为 %d，实际 %d（现算价会是通胀后的更高值）" % [
			context, price_before, frozen_price])

	# 反证：不锁的槽位在第 2 波必须按通胀后的新价算，证明快照确实在起作用，
	# 而不是 _price_for_slot 恒等于某个值（防测试空转）。
	var unlocked_rarity = shop.current_items[1].get("rolled_rarity", shop.current_items[1].get("rarity", 0))
	var unlocked_price: int = shop._price_for_slot(shop.current_items[1], 1, unlocked_rarity)
	var unlocked_wave2: int = shop.shop_rules.get_price(shop.current_items[1].price, unlocked_rarity, 2, shop._get_item_price_modifier())
	_ok(unlocked_price == unlocked_wave2,
		"%s：未锁定槽位的价格不该被冻结，期望按第 2 波现算 %d，实际 %d" % [
			context, unlocked_wave2, unlocked_price])

	# 防空转自检：若同一商品两波现算价相同，「冻结」断言就无从体现。
	var same_item_wave1_price: int = shop.shop_rules.get_price(locked_item.price, rarity_before, 1, shop._get_item_price_modifier())
	var same_item_wave2_price: int = shop.shop_rules.get_price(locked_item.price, rarity_before, 2, shop._get_item_price_modifier())
	_ok(same_item_wave2_price > same_item_wave1_price,
		"%s：防空转自检，同一商品第 2 波现算价(%d)应高于第 1 波(%d)，否则价格冻结无从体现" % [
			context, same_item_wave2_price, same_item_wave1_price])

	# 锁定买断后必须解绑，避免重掷时把已购商品原样留住。
	shop._on_buy_pressed(0, Button.new(), Label.new())
	_ok(not (0 in shop.locked_indices),
		"%s：买下槽 0 后应解除该槽锁定，实际 locked_indices=%s" % [context, str(shop.locked_indices)])
	_ok(not shop.locked_prices.has(0),
		"%s：买下槽 0 后应清掉该槽价格快照，实际 %s" % [context, str(shop.locked_prices)])

	# 最后：按「开始战斗」必须把锁定消费干净（这是正确行为，别被上面的修复带偏）。
	shop._on_start_wave_pressed()
	_ok(shop.locked_indices.is_empty(),
		"%s：开始下一波后 locked_indices 应清空，实际 %s" % [context, str(shop.locked_indices)])
	_ok(shop.locked_prices.is_empty(),
		"%s：开始下一波后 locked_prices 应清空，实际 %s" % [context, str(shop.locked_prices)])


# ─── 收尾与报告 ───

func _cleanup():
	if shop != null and is_instance_valid(shop):
		shop.queue_free()
	if host != null and is_instance_valid(host):
		host.queue_free()
	if player != null and is_instance_valid(player):
		player.free()
	player = null


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
