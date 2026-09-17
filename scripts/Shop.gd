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
	locked_indices.clear()
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

	# 锁定按钮（顶部右对齐）
	var lock_btn = Button.new()
	lock_btn.text = "🔒" if index in locked_indices else "🔓"
	lock_btn.modulate = Color(1.0, 0.85, 0.2) if index in locked_indices else Color(1, 1, 1, 0.5)
	lock_btn.add_theme_font_size_override("font_size", 14)
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

	# Price label (with rarity multiplier)
	var actual_price = shop_rules.get_price(item.price, rarity, wave_num, _get_item_price_modifier())
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
	buy_btn.pressed.connect(_on_buy_pressed.bind(index, buy_btn, price_label))
	_set_buy_button_state(buy_btn, actual_price, player_gold, item)
	vbox.add_child(buy_btn)

	# 传说道具金色发光效果
	if rarity == 3:
		card.modulate = Color(1.0, 0.95, 0.7, 1.0)
		var glow_tween = card.create_tween().set_loops()
		glow_tween.tween_property(card, "modulate", Color(1.2, 1.05, 0.6, 1.0), 0.8)
		glow_tween.tween_property(card, "modulate", Color(1.0, 0.95, 0.7, 1.0), 0.8)

	# Tooltip 悬停
	card.mouse_entered.connect(_on_card_mouse_entered.bind(item))
	card.mouse_exited.connect(_on_card_mouse_exited)

	return card

func _set_buy_button_state(btn: Button, price: int, gold: int, item: Dictionary = {}):
	if btn.text == "已购买":
		btn.disabled = true
		return
	btn.text = "购买"
	if not item.is_empty() and not _can_purchase_item(item):
		btn.disabled = true
		btn.text = "无法合成"
		btn.modulate = Color(1.0, 0.45, 0.45, 1.0)
		return
	if gold >= price:
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1)
	else:
		btn.disabled = true
		btn.modulate = Color(1.0, 0.45, 0.45, 1.0)

func _refresh_buy_buttons():
	for i in range(item_cards.size()):
		if not is_instance_valid(item_cards[i]):
			continue
		if i >= current_items.size():
			continue
		var item = current_items[i]
		# Navigate: PanelContainer > MarginContainer > VBoxContainer > children
		var margin = item_cards[i].get_child(0)
		if margin == null:
			continue
		var vbox = margin.get_child(0)
		if vbox == null:
			continue
		# Buy button is last child of vbox
		var btn = vbox.get_child(vbox.get_child_count() - 1)
		if btn is Button:
			var r = item.get("rolled_rarity", item.get("rarity", 0))
			_set_buy_button_state(btn, shop_rules.get_price(item.price, r, wave_num, _get_item_price_modifier()), player_gold, item)

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
	var actual_price = shop_rules.get_price(item.price, rarity, wave_num, _get_item_price_modifier())
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
	btn.modulate = Color(1, 1, 1, 1)

	# Refresh other buy buttons
	_refresh_buy_buttons()

	# 追踪已购买的可出售物品（heal 不可出售）
	if item.type != "heal":
		var bought = item.duplicate()
		bought["paid_price"] = actual_price
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
		btn.text = "🔓"
		btn.modulate = Color(1, 1, 1, 0.5)
	else:
		locked_indices.append(index)
		btn.text = "🔒"
		btn.modulate = Color(1.0, 0.85, 0.2)

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
	$Panel/ButtonRow/RerollButton.text = "重新刷新 (%d材料)" % reroll_cost
	if player_gold >= reroll_cost:
		$Panel/ButtonRow/RerollButton.disabled = false
		$Panel/ButtonRow/RerollButton.modulate = Color(1, 1, 1, 1)
	else:
		$Panel/ButtonRow/RerollButton.disabled = true
		$Panel/ButtonRow/RerollButton.modulate = Color(1.0, 0.45, 0.45, 1.0)

func _on_start_wave_pressed():
	locked_indices.clear()
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
				up_btn.modulate = Color(1.0, 0.45, 0.45, 1.0)
			up_btn.pressed.connect(_on_upgrade_pressed.bind(i))
			vbox.add_child(up_btn)

		upgrade_hbox.add_child(card)

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
