extends CanvasLayer

var ITEM_POOL = []

# Rarity colors: name color and panel tint
const RARITY_NAME_COLORS = [
	Color(1.0, 1.0, 1.0, 1.0),       # 0 white
	Color(0.3, 1.0, 0.4, 1.0),       # 1 green
	Color(0.35, 0.65, 1.0, 1.0),     # 2 blue
	Color(0.75, 0.3, 1.0, 1.0),      # 3 purple
]
const RARITY_PANEL_COLORS = [
	Color(0.15, 0.15, 0.18, 1.0),    # 0 white — dark gray
	Color(0.08, 0.20, 0.10, 1.0),    # 1 green — dark green
	Color(0.08, 0.12, 0.28, 1.0),    # 2 blue  — dark blue
	Color(0.18, 0.06, 0.28, 1.0),    # 3 purple — dark purple
]
const RARITY_NAMES = ["普通", "精良", "稀有", "传说"]
const RARITY_PRICE_MULT = [1.0, 1.5, 2.5, 4.0]

# 锁定/未锁定按钮的文字色。禁止用 modulate 表达状态，颜色只落在 font_color 上。
const LOCKED_COLOR := Color(1.0, 0.85, 0.2, 1.0)
const UNLOCKED_COLOR := Color(1.0, 1.0, 1.0, 0.5)

var current_items = []
var player_gold = 0
var player_luck = 0
var reroll_cost = 5
var reroll_index = 0
var wave_num = 1
var item_cards = []            # Array of card UI nodes
var purchased_items = []       # 记录所有已购买的可出售升级
var player_ref = null          # 玩家引用（出售时用）
var locked_indices: Array[int] = []  # 锁定的卡槽，刷新时保留
var shop_rules := ShopRules.new()

# 锁定商品的原价快照，key = 卡槽索引。跨波次保留时价格冻结用。
#
# 选型理由（为什么不是把 locked_indices 改成 {slot: item}）：
#   1. phase1_main_scene_smoke 直接对 locked_indices 做 clear()/append(0)/in 检查，
#      改类型会破坏既有测试与任何外部调用方；
#   2. 价格是「每波次现算」的（_make_card 里 get_price(..., wave_num, ...)），
#      真正需要冻结的是**算出来的价格**，不是「算价格的输入」。
#      道具/武器条目的价格基数还取决于 rolled_rarity，快照 dict 能一次性锁死结果；
#   3. 合成/购买会改变 player_ref 的 item_price_percent，快照价格免疫这类中途变动。
# 生命周期：与 locked_indices 严格同步 —— 只随 _on_start_wave_pressed()（按下「开始战斗」
# 离开本商店）一起清空，**不在 open() 里清**。open() 是下一波商店的入口，
# 必须能读到上一波留下的锁定，这正是原缺陷（open() 里 clear() 导致跨波次锁定失效）的根源。
var locked_prices: Dictionary = {}  # slot(int) -> 该商品锁定时算出的价格(int)

# --- 武器卡拖拽状态 ---
# 拖拽进行中的源栏位；-1 表示没有拖拽。必须存在 Shop 上（不是被 queue_free 的卡片上），
# 只用于自检与已删除行数的统计，_drop_data 不依赖它做决策。
var _drag_source_slot: int = -1
# _drop_data 执行前 equipped_weapons 的数量，用于**实测**本次操作是否真的删掉了一把武器，
# 比读任何信号/返回值都可靠（信号 emit 只代表函数跑过，不代表数组真的变了）。
var _pre_drop_weapon_count: int = -1

# 武器卡上承载拖放回调的自定义 Control 脚本。所有 UI 都是代码构建的，没有 .tscn 内嵌脚本，
# 所以用 GDScript.new() + set_source_code() 运行时编译一个带 _get_drag_data / _can_drop_data /
# _drop_data 的 Control，再赋给 Control.set_script()。回调经 call() 转调回 Shop，
# 拖拽状态始终留在 Shop 的成员变量里。
var _drag_card_script: GDScript = _make_drag_card_script()


func _make_drag_card_script() -> GDScript:
	var src := """
extends Control

var shop = null
var slot_index: int = -1

func _get_drag_data(at_position: Vector2):
	if shop == null:
		return null
	return shop._weapon_drag_begin(slot_index, self)

func _can_drop_data(at_position: Vector2, data) -> bool:
	if shop == null:
		return false
	return shop._weapon_drag_can_drop(slot_index, data)

func _drop_data(at_position: Vector2, data):
	if shop == null:
		return
	shop._weapon_drag_drop(slot_index, data)
"""
	var script := GDScript.new()
	script.source_code = src
	var err = script.reload()
	if err != OK:
		push_error("Shop 拖拽卡片脚本编译失败: %s" % str(err))
	return script

# 已购买区域 UI
var sell_scroll: ScrollContainer = null
var sell_vbox: VBoxContainer = null

# Tooltip UI
var tooltip_panel: PanelContainer = null
var tooltip_label: Label = null
var tooltip_visible = false

# 武器升级区域
var upgrade_scroll: ScrollContainer = null
var upgrade_hbox: HBoxContainer = null

signal item_purchased(upgrade)
signal item_sold(upgrade)
signal wave_started

func _ready():
	var _db := load("res://data/weapons.tres") as WeaponDatabase
	var weapon_entries = WeaponDatabase.catalog_shop_entries(false)
	if _db:
		weapon_entries = _merge_weapon_entries(weapon_entries, _db.to_shop_entries())
	ITEM_POOL = weapon_entries + _catalog_item_entries()
	$Panel/ButtonRow/RerollButton.pressed.connect(_on_reroll_pressed)
	$Panel/ButtonRow/StartWaveButton.pressed.connect(_on_start_wave_pressed)
	_build_sell_area()
	_build_tooltip()
	_build_upgrade_area()

func _catalog_item_entries() -> Array:
	var script = load("res://scripts/BrotatoData.gd")
	if script == null:
		return []
	var data = script.new()
	var errors = data.load_catalog()
	if not errors.is_empty():
		push_warning("Brotato 道具目录加载失败，商店无法使用: " + str(errors))
		return []
	return data.get_shop_pool(false)

func _merge_weapon_entries(primary: Array, fallback: Array) -> Array:
	if not primary.is_empty():
		return primary.duplicate(true)
	# Fallback only when the JSON catalog is unavailable or empty.
	var result := primary.duplicate(true)
	var seen: Dictionary = {}
	for item in result:
		seen[item.get("weapon_type", "")] = true
	for item in fallback:
		var weapon_type = item.get("weapon_type", "")
		if weapon_type == "" or seen.has(weapon_type):
			continue
		result.append(item)
		seen[weapon_type] = true
	return result

func open(p_wave_num: int, p_gold: int, p_luck: int = 0, p_player = null):
	wave_num = p_wave_num
	player_gold = p_gold
	player_luck = p_luck
	player_ref = p_player
	reroll_index = 0
	reroll_cost = shop_rules.get_reroll_cost(reroll_index, _get_reroll_price_modifier())
	# A5：这里**故意不再**清 locked_indices / locked_prices。
	# 原版行为是「锁定跨波次保留，且价格冻结」，所以 open() 必须把上一波的锁定带进来。
	# 清空的职责只归 _on_start_wave_pressed()（玩家真的开下一波时才算消费掉锁定）。
	# 注意：locked_prices 的 key 是商店**卡槽号**，跨波次开新商店时槽位含义会变；
	# 但 roll_offers 会按同一个 slot 号把锁定商品原样放回同一格，
	# 所以槽号 -> 商品 的对应关系是连续的，价格快照不会串到别的商品上。
	$Panel/Title.text = "第 %d 波完成！  商店" % wave_num
	$Panel/GoldLabel.text = "材料: %d" % player_gold
	_update_reroll_button()
	_roll_items(false)
	_notify_player_shop_opened()
	_refresh_sell_area()
	_refresh_upgrade_area()
	visible = true

func update_gold(gold: int):
	player_gold = gold
	$Panel/GoldLabel.text = "材料: %d" % player_gold
	_refresh_buy_buttons()

func _roll_items(is_reroll: bool = false):
	var preserved: Dictionary = {}
	for i in locked_indices:
		if i < current_items.size():
			preserved[i] = current_items[i]
	current_items = shop_rules.roll_offers(ITEM_POOL, wave_num, player_luck, preserved, current_items)
	if is_reroll:
		_apply_next_reroll_tier_bonus(preserved)
		apply_locked_shop_entry_curse_chance()
	_build_item_cards()

func _consume_next_reroll_tier_bonus() -> int:
	if player_ref == null or not is_instance_valid(player_ref):
		return 0
	if player_ref.get("shop_next_reroll_tier_bonus_pending") == null:
		return 0
	var bonus = max(0, int(player_ref.get("shop_next_reroll_tier_bonus_pending")))
	if bonus > 0:
		player_ref.shop_next_reroll_tier_bonus_pending = 0
	return bonus

func _apply_next_reroll_tier_bonus(preserved: Dictionary):
	var bonus = _consume_next_reroll_tier_bonus()
	if bonus <= 0:
		return
	for i in range(current_items.size()):
		if preserved.has(i):
			continue
		var item: Dictionary = current_items[i]
		var rarity = clamp(int(item.get("rolled_rarity", item.get("rarity", 0))) + bonus, 0, 3)
		item["rolled_rarity"] = rarity
		if str(item.get("type", "")) == "weapon":
			var minimum_tier = int(item.get("minimum_tier", 1))
			item["tier"] = clamp(max(minimum_tier, rarity + 1), 1, 4)

func apply_locked_shop_entry_curse_chance(forced_rolls: Dictionary = {}) -> int:
	if player_ref == null or not is_instance_valid(player_ref):
		return 0
	if player_ref.get("locked_shop_entry_curse_chance") == null:
		return 0
	var chance = clamp(float(player_ref.get("locked_shop_entry_curse_chance")), 0.0, 1.0)
	if chance <= 0.0:
		return 0
	var changed = 0
	for index in locked_indices:
		var slot = int(index)
		if slot < 0 or slot >= current_items.size():
			continue
		var item: Dictionary = current_items[slot]
		if _is_cursed_shop_entry(item):
			continue
		var roll = float(forced_rolls[slot]) if forced_rolls.has(slot) else randf()
		if roll >= chance:
			continue
		var cursed_item = item.duplicate(true)
		cursed_item["catalog_cursed"] = true
		cursed_item["is_cursed"] = true
		cursed_item["cursed"] = true
		current_items[slot] = cursed_item
		changed += 1
	return changed

func _is_cursed_shop_entry(item) -> bool:
	if not (item is Dictionary):
		return false
	return bool(item.get("catalog_cursed", false)) or bool(item.get("is_cursed", false)) or bool(item.get("cursed", false))

func _build_item_cards():
	# Clear old cards
	for card in item_cards:
		if is_instance_valid(card):
			card.queue_free()
	item_cards.clear()

	var item_row = $Panel/ItemRow
	# Remove any lingering children not tracked
	for child in item_row.get_children():
		child.queue_free()

	for i in range(current_items.size()):
		var item = current_items[i]
		var card = _make_card(item, i)
		item_row.add_child(card)
		item_cards.append(card)

func _make_card(item: Dictionary, index: int) -> Control:
	var rarity = item.get("rolled_rarity", item.get("rarity", 0))
	if item.get("type", "") == "weapon":
		item["tier"] = int(item.get("tier", rarity + 1))
	var panel_color = RARITY_PANEL_COLORS[rarity]
	var name_color = RARITY_NAME_COLORS[rarity]
	var is_cursed = _is_cursed_shop_entry(item)
	if is_cursed:
		panel_color = panel_color.lerp(Color(0.26, 0.08, 0.32, 1.0), 0.45)
		name_color = Color(0.95, 0.58, 1.0, 1.0)

	# Outer container with minimum size
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 340)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style the panel background
	var style = StyleBoxFlat.new()
	style.bg_color = panel_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = name_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	# Padding via a MarginContainer
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	margin.add_child(vbox)

	# 锁定按钮（顶部右对齐）。状态走 font_color，不用 modulate。
	var lock_btn = Button.new()
	var is_locked = index in locked_indices
	lock_btn.text = "🔒" if is_locked else "🔓"
	lock_btn.add_theme_color_override("font_color", LOCKED_COLOR if is_locked else UNLOCKED_COLOR)
	lock_btn.add_theme_font_size_override("font_size", 14)
	lock_btn.set_meta("_is_shop_lock_button", true)
	lock_btn.custom_minimum_size = Vector2(0, 24)
	lock_btn.pressed.connect(_on_lock_pressed.bind(index, lock_btn))
	vbox.add_child(lock_btn)

	# Rarity label
	var rarity_label = Label.new()
	rarity_label.text = RARITY_NAMES[rarity]
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", name_color * 0.8)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_label)

	# Name label
	var name_label = Label.new()
	name_label.text = ("诅咒 " if is_cursed else "") + str(item.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", name_color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	# Rarity indicator spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer1)

	# Desc label
	var desc_label = Label.new()
	desc_label.text = item.get("desc", "")
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer2)

	# Price label (with rarity multiplier). 锁定过的槽位走价格快照（跨波次冻结）。
	var actual_price: int = _price_for_slot(item, index, rarity)
	var price_label = Label.new()
	price_label.text = "%d 材料" % actual_price
	price_label.add_theme_font_size_override("font_size", 17)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price_label)

	# Buy button
	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(0, 44)
	buy_btn.add_theme_font_size_override("font_size", 18)
	buy_btn.set_meta("_is_shop_buy_button", true)
	buy_btn.pressed.connect(_on_buy_pressed.bind(index, buy_btn, price_label))
	_set_buy_button_state(buy_btn, actual_price, player_gold, item)
	vbox.add_child(buy_btn)

	# 传说道具金色呼吸效果。
	# 原来用 modulate 循环补间表达 —— 违反「禁止 modulate 表达状态」的硬约定，
	# 且 set_loops() 的补间在卡片被 queue_free 后仍持有引用。
	# 改成在 StyleBoxFlat 的 border_color 上做**有限次数**脉冲：颜色语义不变，
	# 且补间自然结束（不 set_loops），卡片释放后不再有动画残留。
	if rarity == 3:
		var base_border: Color = name_color
		var glow_border := Color(
			min(1.0, name_color.r * 1.25 + 0.1),
			min(1.0, name_color.g * 1.1 + 0.05),
			max(0.0, name_color.b * 0.6),
			1.0)
		var glow_tween = card.create_tween()
		for _i in range(6):
			glow_tween.tween_property(style, "border_color", glow_border, 0.8)
			glow_tween.tween_property(style, "border_color", base_border, 0.8)

	# Tooltip 悬停
	card.mouse_entered.connect(_on_card_mouse_entered.bind(item))
	card.mouse_exited.connect(_on_card_mouse_exited)

	return card

func _set_buy_button_state(btn: Button, price: int, gold: int, item: Dictionary = {}):
	if btn.text == "已购买":
		btn.disabled = true
		return
	btn.text = "购买"
	# 禁止用 modulate 表达状态：样式一律落在 border_color / bg_color / disabled 上。
	btn.remove_theme_color_override("font_color")
	if not item.is_empty() and not _can_purchase_item(item):
		btn.disabled = true
		btn.text = "无法合成"
		btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
		return
	if gold >= price:
		btn.disabled = false
	else:
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))

func _refresh_buy_buttons():
	for i in range(item_cards.size()):
		if not is_instance_valid(item_cards[i]):
			continue
		if i >= current_items.size():
			continue
		var item = current_items[i]
		# 不硬编码「购买按钮是 vbox 最后一个子节点」的路径：
		# 改成递归找卡片里第一个带 _is_shop_buy_button 标记的 Button。
		# 这样 _make_card 里增删任何控件都不会把购买按钮指错。
		var btn = _find_buy_button(item_cards[i])
		if btn is Button:
			var r = item.get("rolled_rarity", item.get("rarity", 0))
			_set_buy_button_state(btn, _price_for_slot(item, i, r), player_gold, item)

func _find_buy_button(node: Node) -> Button:
	if node is Button and node.has_meta("_is_shop_buy_button"):
		return node
	for child in node.get_children():
		var found := _find_buy_button(child)
		if found != null:
			return found
	return null

func _find_lock_button(node: Node) -> Button:
	if node is Button and node.has_meta("_is_shop_lock_button"):
		return node
	if node == null:
		return null
	for child in node.get_children():
		var found := _find_lock_button(child)
		if found != null:
			return found
	return null

# 商品价格：锁定过的卡槽一律复用锁定时算出的价格（跨波次价格冻结）。
#
# 为什么需要它：_make_card 里价格是 get_price(..., wave_num, ...) **现算**的，
# 而 get_price 含 wave_mult = 1.0 + max(0, wave-1)*0.06，wave_num 一涨价格就涨。
# 锁定商品会在 roll_offers 里被原样保留（连同 rolled_rarity），但价格是每帧重算的，
# 所以跨波次保留必须另存价格快照。
#
# 行号不能当判据：_build_item_cards 会重建卡片，index 与 locked_indices 的槽位号是同源的，
# 但 item 自身没有槽位字段，所以这里必须由调用方把 index 传进来。
func _price_for_slot(item: Dictionary, index: int, rarity: int) -> int:
	if index >= 0 and locked_prices.has(index):
		return int(locked_prices[index])
	return shop_rules.get_price(item.price, rarity, wave_num, _get_item_price_modifier())

func _can_purchase_item(item: Dictionary) -> bool:
	if item.get("type", "") != "weapon":
		return true
	if player_ref == null or not is_instance_valid(player_ref):
		return false
	var tier = int(item.get("tier", item.get("rolled_rarity", item.get("rarity", 0)) + 1))
	if player_ref.has_method("can_equip_or_combine_weapon"):
		return player_ref.can_equip_or_combine_weapon(item.get("weapon_type", ""), tier)
	return player_ref.equipped_weapons.size() < player_ref.MAX_WEAPONS

func _on_buy_pressed(index: int, btn: Button, price_label: Label):
	if index >= current_items.size():
		return
	var item = current_items[index]
	var rarity = item.get("rolled_rarity", item.get("rarity", 0))
	var actual_price: int = _price_for_slot(item, index, rarity)
	if player_gold < actual_price:
		return

	if not _can_purchase_item(item):
		btn.text = "无法合成"
		btn.disabled = true
		return

	if player_ref and player_ref.has_method("spend_materials"):
		if not player_ref.spend_materials(actual_price):
			return
		player_gold = player_ref.gold
	else:
		player_gold -= actual_price
	$Panel/GoldLabel.text = "材料: %d" % player_gold

	# 购买音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_buy()

	# Mark button as purchased
	btn.text = "已购买"
	btn.disabled = true
	btn.remove_theme_color_override("font_color")

	# 该槽已被买走：锁定状态与价格快照一起失效，否则重掷时会把已购商品原样留住。
	locked_indices.erase(index)
	locked_prices.erase(index)
	var fresh_lock_btn := _find_lock_button(item_cards[index] if index < item_cards.size() else null)
	if fresh_lock_btn != null:
		fresh_lock_btn.text = "🔓"
		fresh_lock_btn.add_theme_color_override("font_color", UNLOCKED_COLOR)

	# Refresh other buy buttons
	_refresh_buy_buttons()

	# 追踪已购买的可出售物品（heal 不可出售）
	if item.type != "heal":
		var bought = item.duplicate()
		bought["paid_price"] = actual_price
		# A4：记录购买来源，供精确出售。
		#   1. slot_index —— 购买时所在商店卡槽。注意**只在当前这一波商店内有效**：
		#      跨波次后开新商店会重掷，槽位含义完全不同，所以要配合 tier/weapon_type 兜底；
		#   2. tier —— 武器分阶，配合 weapon_type 唯一确定「同类型不同阶」中的哪一把。
		# PlayerUpgrades._find_weapon_slot_to_remove 的判据优先级是
		# slot_index → type(+tier) → 第一个同类型，并且会在 slot_index 指向别的武器时安全降级。
		bought["slot_index"] = index
		if item.type == "weapon":
			bought["weapon_type"] = item.get("weapon_type", "")
			bought["tier"] = int(item.get("tier", rarity + 1))
		purchased_items.append(bought)
		_refresh_sell_area()

	# Emit the upgrade signal
	item_purchased.emit(item)

	# 新装备武器后刷新升级区
	if item.type == "weapon":
		_refresh_upgrade_area()

func _on_lock_pressed(index: int, btn: Button):
	if index in locked_indices:
		locked_indices.erase(index)
		locked_prices.erase(index)
		btn.text = "🔓"
		btn.add_theme_color_override("font_color", UNLOCKED_COLOR)
	else:
		locked_indices.append(index)
		# 立刻把当前算出的价格冻结成快照。
		# 锁定是「以当前看到的这个价买下未来」的承诺，所以快照必须在按下这一刻取，
		# 而不是等下次 open() 再取 —— 否则中途 item_price_percent 变了就冻错价。
		_snapshot_locked_price(index)
		btn.text = "🔒"
		btn.add_theme_color_override("font_color", LOCKED_COLOR)

func _snapshot_locked_price(index: int):
	if index < 0 or index >= current_items.size():
		locked_prices.erase(index)
		return
	var item = current_items[index]
	var rarity = item.get("rolled_rarity", item.get("rarity", 0))
	locked_prices[index] = shop_rules.get_price(item.price, rarity, wave_num, _get_item_price_modifier())

func _on_reroll_pressed():
	var used_free_reroll := false
	if player_ref != null and is_instance_valid(player_ref) and player_ref.get("free_shop_rerolls") != null and int(player_ref.get("free_shop_rerolls")) > 0:
		player_ref.free_shop_rerolls = max(0, int(player_ref.free_shop_rerolls) - 1)
		used_free_reroll = true
	if not used_free_reroll and player_gold < reroll_cost:
		return
	if used_free_reroll:
		player_gold = player_ref.gold
	elif player_ref and player_ref.has_method("spend_materials"):
		if not player_ref.spend_materials(reroll_cost):
			return
		player_gold = player_ref.gold
	else:
		player_gold -= reroll_cost
	$Panel/GoldLabel.text = "材料: %d" % player_gold
	reroll_index += 1
	reroll_cost = shop_rules.get_reroll_cost(reroll_index, _get_reroll_price_modifier())
	_update_reroll_button()
	_roll_items(true)
	_notify_player_shop_rerolled()
	_refresh_buy_buttons()

func _notify_player_shop_rerolled():
	if player_ref != null and is_instance_valid(player_ref) and player_ref.has_method("on_shop_rerolled"):
		player_ref.on_shop_rerolled()

func _notify_player_shop_opened():
	if player_ref != null and is_instance_valid(player_ref) and player_ref.has_method("on_shop_opened"):
		player_ref.on_shop_opened()

func _get_item_price_modifier() -> float:
	if player_ref != null and is_instance_valid(player_ref):
		return float(player_ref.get("item_price_percent"))
	return 0.0

func _get_reroll_price_modifier() -> float:
	if player_ref != null and is_instance_valid(player_ref):
		return float(player_ref.get("reroll_price_percent"))
	return 0.0

func _get_recycling_materials_modifier() -> float:
	if player_ref != null and is_instance_valid(player_ref):
		return float(player_ref.get("recycling_materials_percent"))
	return 0.0

func _update_reroll_button():
	var btn: Button = $Panel/ButtonRow/RerollButton
	btn.text = "重新刷新 (%d材料)" % reroll_cost
	# 状态走 font_color，不用 modulate。
	btn.remove_theme_color_override("font_color")
	if player_gold >= reroll_cost:
		btn.disabled = false
	else:
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))

func _on_start_wave_pressed():
	locked_indices.clear()
	locked_prices.clear()
	visible = false
	tooltip_visible = false
	if tooltip_panel:
		tooltip_panel.visible = false
	wave_started.emit()

# --- 已购买物品出售区域 ---

func _build_sell_area():
	sell_scroll = ScrollContainer.new()
	sell_scroll.name = "SellScroll"
	sell_scroll.custom_minimum_size = Vector2(0, 100)
	sell_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 放在面板底部（ButtonRow 之后）
	$Panel.add_child(sell_scroll)

	sell_vbox = VBoxContainer.new()
	sell_vbox.add_theme_constant_override("separation", 4)
	sell_scroll.add_child(sell_vbox)

	# 标题
	var title = Label.new()
	title.name = "SellTitle"
	title.text = "已购买（点击出售返还50%材料）"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	sell_vbox.add_child(title)

func _refresh_sell_area():
	if sell_vbox == null:
		return
	# 清除旧条目（保留标题）
	for i in range(sell_vbox.get_child_count() - 1, 0, -1):
		sell_vbox.get_child(i).queue_free()

	for i in range(purchased_items.size()):
		var item = purchased_items[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl = Label.new()
		name_lbl.text = item.name
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var paid = item.get("paid_price", item.price)
		var price_lbl = Label.new()
		price_lbl.text = "原价:%d" % paid
		price_lbl.add_theme_font_size_override("font_size", 13)
		price_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(price_lbl)

		var sell_price = max(1, int(floor(float(paid) * 0.5 * max(0.0, 1.0 + _get_recycling_materials_modifier()))))
		var sell_btn = Button.new()
		sell_btn.text = "出售(+%d材料)" % sell_price
		sell_btn.add_theme_font_size_override("font_size", 13)
		sell_btn.custom_minimum_size = Vector2(100, 28)
		sell_btn.pressed.connect(_on_sell_pressed.bind(i))
		row.add_child(sell_btn)

		sell_vbox.add_child(row)

	# A4：已装备的武器同样要有出售入口（原先只有道具能卖）。
	_append_weapon_sell_rows()

# A4：按栏位列出已装备武器，复用与道具完全相同的出售按钮样式。
#
# 关键点 —— 出售意图必须带 slot_index，且 tier 兜底：
#   PlayerUpgrades.remove_upgrade() 对武器分支走 _find_weapon_slot_to_remove()，
#   判据优先级是 slot_index → type(+tier) → 第一个同类型。
#   商店侧唯一的权威身份就是「栏位」（equipped_weapons 的 index），所以 slot_index 必传；
#   再用 weapon_type 让底层能校验索引是否还指向同一把（合成会让索引漂移），
#   用 tier 让「同类型不同阶」中具体那一把能唯一确定。
#   这里传的 tier 是**当前实时**读出来的，不是购买时记的 —— 武器可能已被合成升阶，
#   快照 tier 会和实际不符，反而会误导底层匹配。
func _append_weapon_sell_rows():
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if not player_ref.has_method("get_weapon_info"):
		return

	var weapons = player_ref.get_weapon_info()
	if weapons.is_empty():
		return

	var header = Label.new()
	header.text = "已装备武器（点击出售返还50%材料）"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	sell_vbox.add_child(header)

	for i in range(weapons.size()):
		var w = weapons[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl = Label.new()
		name_lbl.text = "%s  T%d" % [str(w.get("name", "")), int(w.get("tier", 1))]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# 武器没有「原价」概念（来源可能是掉落或合成），用当前栏位价值做回收基数。
		var sell_price := _weapon_sell_price(i)
		var sell_btn = Button.new()
		sell_btn.text = "出售(+%d材料)" % sell_price
		sell_btn.add_theme_font_size_override("font_size", 13)
		sell_btn.custom_minimum_size = Vector2(100, 28)
		sell_btn.set_meta("_is_weapon_sell_button", true)
		sell_btn.pressed.connect(_on_weapon_sell_pressed.bind(i))
		row.add_child(sell_btn)

		sell_vbox.add_child(row)

# 武器回收价：沿用道具的 50% × 回收加成公式（不改任何数值公式），
# 基数取「按当前分阶重算的道具价格」——武器分阶越高，回收越多。
func _weapon_sell_price(slot_index: int) -> int:
	var base := 10
	if player_ref != null and is_instance_valid(player_ref):
		if slot_index >= 0 and slot_index < player_ref.equipped_weapons.size():
			var weapon = player_ref.equipped_weapons[slot_index]
			var data = weapon.data
			base = int(data.get("price", 10))
			base += (_weapon_tier_at(slot_index) - 1) * max(1, base / 2)
	return max(1, int(floor(float(base) * 0.5 * max(0.0, 1.0 + _get_recycling_materials_modifier()))))

# 出售指定栏位的武器。
func _on_weapon_sell_pressed(slot_index: int):
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if slot_index < 0 or slot_index >= player_ref.equipped_weapons.size():
		return
	if not player_ref.has_method("remove_upgrade"):
		return

	# 传意图：slot_index 精确定位 + weapon_type 校验 + tier 兜底。
	# tier 用**实时**分阶（见 _append_weapon_sell_rows 的说明）。
	var weapon = player_ref.equipped_weapons[slot_index]
	var entry := {
		"name": str(weapon.data.name),
		"type": "weapon",
		"weapon_type": str(weapon.type),
		"tier": _weapon_tier_at(slot_index),
		"slot_index": slot_index,
	}

	# 回收价必须在**移除之前**算好：remove_upgrade 会让后面的武器整体前移，
	# 之后再按 slot_index 取价会取到「下一把」的价格。
	var sell_price := _weapon_sell_price(slot_index)

	var before_count: int = player_ref.equipped_weapons.size()
	player_ref.remove_upgrade(entry)
	var removed: int = before_count - player_ref.equipped_weapons.size()
	if removed <= 0:
		# 底层没找到目标：不发材料、不刷 UI，避免「没卖出去却加了钱」。
		return

	player_gold += sell_price
	$Panel/GoldLabel.text = "材料: %d" % player_gold
	if player_ref.has_method("earn_gold"):
		player_ref.earn_gold(sell_price)

	_refresh_sell_area()
	_refresh_upgrade_area()
	_refresh_buy_buttons()
	_update_reroll_button()

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_buy()

func _on_sell_pressed(index: int):
	if index >= purchased_items.size():
		return
	var item = purchased_items[index]
	var paid = item.get("paid_price", item.price)
	var sell_price = max(1, int(floor(float(paid) * 0.5 * max(0.0, 1.0 + _get_recycling_materials_modifier()))))

	# 返还材料
	player_gold += sell_price
	$Panel/GoldLabel.text = "材料: %d" % player_gold

	# 移除玩家属性
	if player_ref and is_instance_valid(player_ref):
		player_ref.remove_upgrade(item)
		player_ref.earn_gold(sell_price)

	# 从已购列表移除
	purchased_items.remove_at(index)
	_refresh_sell_area()
	_refresh_buy_buttons()
	_update_reroll_button()

	# 出售音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_buy()

	item_sold.emit(item)

# --- Tooltip 系统 ---

func _build_tooltip():
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "Tooltip"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.5, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	tooltip_panel.add_theme_stylebox_override("panel", style)

	tooltip_label = Label.new()
	tooltip_label.add_theme_font_size_override("font_size", 14)
	tooltip_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size = Vector2(200, 0)
	tooltip_panel.add_child(tooltip_label)

	add_child(tooltip_panel)

func _process(_delta):
	if tooltip_visible and tooltip_panel and tooltip_panel.visible:
		tooltip_panel.position = get_viewport().get_mouse_position() + Vector2(12, 12)

func _on_card_mouse_entered(item: Dictionary):
	if tooltip_panel == null:
		return
	tooltip_label.text = _get_tooltip_text(item)
	tooltip_panel.visible = true
	tooltip_visible = true

func _on_card_mouse_exited():
	if tooltip_panel == null:
		return
	tooltip_panel.visible = false
	tooltip_visible = false

func _get_tooltip_text(item: Dictionary) -> String:
	var name_str = item.get("name", "")
	var desc = item.get("desc", "")
	var effect_str = ""

	var item_type = item.get("type", "")
	var value = item.get("value", 0)
	var effect = item.get("effect", "")

	match item_type:
		"weapon":
			effect_str = "武器 Tier %d" % int(item.get("tier", item.get("rolled_rarity", item.get("rarity", 0)) + 1))
		"speed":
			effect_str = "速度 +%d" % value
		"fire_rate":
			effect_str = "射速 +%d%%" % int(value * 100)
		"damage":
			effect_str = "伤害 +%d" % value
		"hp":
			effect_str = "最大HP +%d" % value
		"heal":
			effect_str = "恢复 %dHP" % value
		"magnet":
			effect_str = "磁铁范围 +%d" % value
		"armor":
			effect_str = "护甲 +%d" % value
		"crit_chance":
			effect_str = "暴击率 +%d%%" % int(value * 100)
		"crit_damage":
			effect_str = "暴击伤害 +%.1fx" % value
		"lifesteal":
			effect_str = "生命偷取 +%d%%" % int(value * 100)
		"hp_regen":
			effect_str = "每波回复 +%d HP" % value
		"luck":
			effect_str = "幸运 +%d" % value
		"hp_armor":
			effect_str = "护甲 +%d  最大HP +%d" % [item.get("armor_val", 0), item.get("hp_val", 0)]
		"passive":
			match effect:
				"burn_chance":       effect_str = "燃烧概率 +%d%%" % int(value * 100)
				"freeze_chance":     effect_str = "冻结概率 +%d%%" % int(value * 100)
				"shield":            effect_str = "护盾 +%d" % int(value)
				"xp_boost":          effect_str = "经验加成 +%d%%" % int(value * 100)
				"gold_interest":     effect_str = "材料利息 +%d%%" % int(value * 100)
				"thorns":            effect_str = "荆棘反伤 +%d%%" % int(value * 100)
				"adrenaline":        effect_str = "HP越低速度越快"
				"revenge":           effect_str = "HP<30%伤害+50%"
				"iron_will":         effect_str = "30%概率免死"
				"war_machine":       effect_str = "连续击杀+射速"
				"chain_lightning":   effect_str = "闪电链弹射"
				"auto_repair":       effect_str = "每秒恢复 %.1fHP" % value
				_:                   effect_str = desc
		"catalog_item":
			effect_str = item.get("effect_text", desc)

	if effect_str == "":
		return "%s\n%s" % [name_str, desc]
	return "%s\n%s\n效果: %s" % [name_str, desc, effect_str]

# --- 武器升级区域 ---

func _build_upgrade_area():
	upgrade_scroll = ScrollContainer.new()
	upgrade_scroll.name = "UpgradeScroll"
	upgrade_scroll.custom_minimum_size = Vector2(0, 110)
	upgrade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$Panel.add_child(upgrade_scroll)

	upgrade_hbox = HBoxContainer.new()
	upgrade_hbox.add_theme_constant_override("separation", 8)
	upgrade_scroll.add_child(upgrade_hbox)

func _refresh_upgrade_area():
	if upgrade_hbox == null or player_ref == null or not is_instance_valid(player_ref):
		return
	# 清除旧条目
	for child in upgrade_hbox.get_children():
		child.queue_free()

	if not player_ref.has_method("get_weapon_info"):
		return
	var weapons = player_ref.get_weapon_info()
	if weapons.is_empty():
		return

	# 标题
	var title = Label.new()
	title.text = "武器合成"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	upgrade_hbox.add_child(title)

	for i in range(weapons.size()):
		var w = weapons[i]
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(160, 90)

		var style = StyleBoxFlat.new()
		if w.max_level:
			style.bg_color = Color(0.2, 0.18, 0.05, 1.0)
			style.border_color = Color(1.0, 0.85, 0.0)
		else:
			style.bg_color = Color(0.12, 0.12, 0.18, 1.0)
			style.border_color = Color(0.4, 0.4, 0.6)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", style)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vbox)

		# 武器名 + 阶级
		var name_lbl = Label.new()
		var prefix = "★" if w.max_level else ""
		name_lbl.text = "%s%s  T%d" % [prefix, w.name, w.tier]
		name_lbl.add_theme_font_size_override("font_size", 14)
		var name_col = Color(1.0, 0.85, 0.0) if w.max_level else Color(0.9, 0.9, 0.9)
		name_lbl.add_theme_color_override("font_color", name_col)
		vbox.add_child(name_lbl)

		# 属性
		var stats_lbl = Label.new()
		stats_lbl.text = "伤害:%d  射速:%.1f" % [w.damage, w.fire_rate]
		stats_lbl.add_theme_font_size_override("font_size", 12)
		stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		vbox.add_child(stats_lbl)

		# 合成按钮
		if w.max_level:
			var max_lbl = Label.new()
			max_lbl.text = "已满阶"
			max_lbl.add_theme_font_size_override("font_size", 13)
			max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(max_lbl)
		else:
			var up_btn = Button.new()
			up_btn.text = "合成"
			up_btn.add_theme_font_size_override("font_size", 13)
			up_btn.custom_minimum_size = Vector2(0, 30)
			if w.get("can_combine", false):
				up_btn.disabled = false
			else:
				up_btn.disabled = true
				# 状态走 font_color，不用 modulate。
				up_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
			up_btn.pressed.connect(_on_upgrade_pressed.bind(i))
			vbox.add_child(up_btn)

		# 拖拽承载节点：必须最后加，才会盖在按钮上层接住鼠标，
		# 否则把卡拖起来时会被合成按钮抢走事件。
		# 用 MOUSE_FILTER_PASS：既接住拖放，又让 mouse_entered 继续冒泡。
		var drag_node := Control.new()
		drag_node.name = "DragNode"
		drag_node.mouse_filter = Control.MOUSE_FILTER_PASS
		drag_node.anchors_preset = Control.PRESET_FULL_RECT
		if _drag_card_script != null:
			drag_node.set_script(_drag_card_script)
			drag_node.set("shop", self)
			drag_node.set("slot_index", i)
		card.add_child(drag_node)
		# 卡片按子节点算尺寸，add_child 时尺寸还是 0，拖拽节点的可点击区域会跟着是 0。
		# FULL_RECT 锚点 + 等布局稳定后再同步一次尺寸；用 set_deferred 避免在
		# 布局回调里直接改尺寸触发「anchors 覆盖 size」的警告。
		card.resized.connect(_stretch_drag_node.bind(card, drag_node))

		upgrade_hbox.add_child(card)

func _stretch_drag_node(card: Control, drag_node: Control):
	if not is_instance_valid(drag_node):
		return
	if card.size.x <= 0.0:
		return
	# FULL_RECT 锚点下 size 由父级布局决定，这里只做兜底同步（延迟执行，避开布局期）。
	drag_node.set_deferred("size", card.size)

# =====================================================================
# A1 拖拽框架：商店武器卡之间拖放
# =====================================================================
#
# Godot 4 的 Control 拖放是**目标**在驱动：
#   源  _get_drag_data(at_position)  -> 返回 data，并顺带 set_drag_preview(control)
#   靶  _can_drop_data(at_position, data) -> bool，决定鼠标是否显示「可放置」
#   靶  _drop_data(at_position, data)     -> 真正执行
# 源和靶可以是同一个回调集 —— 每个武器卡既当源又当靶。
#
# 所有 UI 都是代码构建的（_refresh_upgrade_area 里 new 出来的 PanelContainer），
# 没有 .tscn 给它们挂脚本，所以这里给每张卡加一个 Control 子节点、
# 用运行时编译的 _drag_card_script 承载回调，再转调回下面这几个方法。
# 拖拽源真相存在 Shop 的成员变量里（_drag_source_slot），卡片被 queue_free 也不影响。

# 武器卡拖拽开始：返回 payload，并设置拖拽预览。
# 返回 null 表示这个槽不允许拖（越界/没有武器），Godot 会中止拖拽。
func _weapon_drag_begin(slot_index: int, source: Control):
	if player_ref == null or not is_instance_valid(player_ref):
		return null
	if not player_ref.has_method("get_weapon_info"):
		return null
	if slot_index < 0 or slot_index >= player_ref.equipped_weapons.size():
		return null

	_drag_source_slot = slot_index
	_set_drag_preview(source, slot_index)

	return {
		"source": "shop_weapon_card",
		"slot_index": slot_index,
		"weapon_type": str(player_ref.equipped_weapons[slot_index].type),
		"tier": _weapon_tier_at(slot_index),
	}

# 拖拽预览：按硬约定不用美术资源，用「一个方框 + 文字」表达。
func _set_drag_preview(source: Control, slot_index: int):
	var preview := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.border_color = Color(1.0, 0.85, 0.2)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	preview.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	var weapons = player_ref.equipped_weapons
	var w_name := str(weapons[slot_index].data.name)
	label.text = "%s T%d" % [w_name, _weapon_tier_at(slot_index)]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	preview.add_child(label)

	# 预览不能被鼠标事件命中，否则会在拖拽途中挡住靶卡片。
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.set_drag_preview(preview)

# 是否允许把拖拽源放到这个槽上。
# 判据完全复用 PlayerCombat.can_combine_weapon(slot) —— 它内部走
# _find_combine_partner(同 type 且同 tier 且非自己)，是合成可行性的唯一权威。
# 这里不自己重写一遍规则，避免商店和战斗算出的「可合成」不一致（合成按钮用的就是它）。
func _weapon_drag_can_drop(target_slot: int, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("source", "") != "shop_weapon_card":
		return false
	var source_slot: int = int(data.get("slot_index", -1))
	if source_slot < 0 or source_slot == target_slot:
		return false
	if player_ref == null or not is_instance_valid(player_ref):
		return false
	if not player_ref.has_method("can_combine_weapon"):
		return false
	return player_ref.can_combine_weapon(target_slot)

# 执行放置。只做合成（见文件末尾 A3 说明）。
func _weapon_drag_drop(target_slot: int, data):
	if typeof(data) != TYPE_DICTIONARY:
		return
	var source_slot: int = int(data.get("slot_index", -1))
	if not _weapon_drag_can_drop(target_slot, data):
		_finish_drag()
		return

	# 记录操作前的数量，用来**实测**这次 drop 到底有没有真的删掉一把武器。
	_pre_drop_weapon_count = player_ref.equipped_weapons.size()

	# 复用既有合成入口。combine_weapon 内部会 _make_weapon(tier+1)、remove_at、
	# emit_weapons_changed()，是武器属性贡献的唯一收敛点，不重复实现。
	if not player_ref.has_method("combine_weapon"):
		_finish_drag()
		return

	var before_count: int = player_ref.equipped_weapons.size()
	var success: bool = player_ref.combine_weapon(target_slot)
	_after_weapon_change(success, before_count, source_slot, target_slot)

func _after_weapon_change(success: bool, before_count: int, source_slot: int, target_slot: int):
	var after_count: int = player_ref.equipped_weapons.size() if (player_ref != null and is_instance_valid(player_ref)) else before_count
	var removed := before_count - after_count
	if success and removed == 1:
		# 合成成功且**实测**数组少了一把 —— 两个条件都满足才刷新 UI 播声音，
		# 避免 combine_weapon 返回 true 但数组没变的假成功。
		player_gold = player_ref.gold
		$Panel/GoldLabel.text = "材料: %d" % player_gold
		_refresh_upgrade_area()
		_refresh_buy_buttons()
		_update_reroll_button()
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_buy()
	_finish_drag()

func _finish_drag():
	_drag_source_slot = -1

# 取某槽武器的分阶。与 PlayerCombat 既有写法（weapon.get("tier", weapon.get("level", 1))）保持一致。
func _weapon_tier_at(slot_index: int) -> int:
	if player_ref == null or not is_instance_valid(player_ref):
		return 1
	if slot_index < 0 or slot_index >= player_ref.equipped_weapons.size():
		return 1
	var weapon = player_ref.equipped_weapons[slot_index]
	return int(weapon.get("tier", weapon.get("level", 1)))

func _on_upgrade_pressed(slot_index: int):
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if not player_ref.has_method("combine_weapon"):
		return
	var success = player_ref.combine_weapon(slot_index)
	if success:
		player_gold = player_ref.gold
		$Panel/GoldLabel.text = "材料: %d" % player_gold
		_refresh_upgrade_area()
		_refresh_buy_buttons()
		_update_reroll_button()
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_buy()
