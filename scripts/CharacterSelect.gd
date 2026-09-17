extends Control

var selected_key = "normal"
var buttons = {}
var danger_tiles = {}
var danger_name_labels = {}
var danger_hint_labels = {}
var lock_info_label: Label = null
var endless_btn: Button = null

# 卡片样式：把「选中 / 未选中 / 锁定」表达在**边框与底色**上，
# 而不是靠 modulate 把整张卡（含文字）乘暗。
const CARD_BG := Color(0.11, 0.12, 0.16, 0.94)
const CARD_BORDER := Color(0.24, 0.27, 0.35)
const CARD_BG_LOCKED := Color(0.085, 0.09, 0.115, 0.94)
const CARD_BORDER_LOCKED := Color(0.22, 0.23, 0.28)
const CARD_RADIUS := 10
# 62：特征件会伸到 1.6r（最大 ±27），留 62 才不会顶到卡片边框
const EMBLEM_BOX := 62.0

const TEXT_NAME := Color(0.95, 0.96, 1.0)
const TEXT_NAME_LOCKED := Color(0.58, 0.6, 0.68)
const TEXT_DESC := Color(0.66, 0.7, 0.8)
const TEXT_DESC_LOCKED := Color(0.48, 0.5, 0.58)
const EMBLEM_LOCKED := Color(0.33, 0.34, 0.4)

var card_styles: Dictionary = {}
var card_emblem_bodies: Dictionary = {}
var danger_styles: Dictionary = {}

const DEFAULT_CATALOG_SELECTED_KEY := "well_rounded"

# Danger 0-5 的档位名与配色（**纯展示**）。
# 数值一律经 GameState.get_danger_profile() 现取，不在这里存第二份 ——
# 否则改了模型却忘了改界面，玩家看到的就是上一版的数字（本项目在「单位约定」上踩过同类坑）。
const DANGER_INFO = {
	0: {"name": "轻松",   "color": Color(0.40, 0.86, 0.46)},
	1: {"name": "常规",   "color": Color(0.86, 0.88, 0.36)},
	2: {"name": "危险",   "color": Color(0.96, 0.72, 0.26)},
	3: {"name": "危险+",  "color": Color(0.96, 0.52, 0.20)},
	4: {"name": "高难",   "color": Color(0.93, 0.34, 0.28)},
	5: {"name": "噩梦",   "color": Color(0.82, 0.22, 0.58)},
}

# 难度卡片样式常量 —— 与角色卡同一套原则：选中/未选中只改**边框 / 底色 / 字体色**，
# 绝不用 modulate（它是乘算且作用于整棵子树，会把名称与提示文字一起压暗，
# 角色选择界面曾因此把 62 张卡的文字压到看不见）。
const DANGER_TILE_BG := Color(0.10, 0.11, 0.15, 0.94)
const DANGER_TILE_BORDER := Color(0.24, 0.27, 0.35)
const DANGER_TEXT_NAME := Color(0.95, 0.96, 1.0)
const DANGER_TEXT_NAME_IDLE := Color(0.74, 0.77, 0.86)
const DANGER_TEXT_HINT := Color(0.64, 0.68, 0.78)

func _ready():
	var grid = $Margin/VBox/ScrollContainer/Grid
	var character_entries = GameState.get_character_select_entries()
	if selected_key not in character_entries and character_entries.has(DEFAULT_CATALOG_SELECTED_KEY):
		selected_key = DEFAULT_CATALOG_SELECTED_KEY
	elif selected_key not in character_entries and not character_entries.is_empty():
		selected_key = character_entries.keys()[0]
	for key in character_entries:
		var data = character_entries[key]
		var unlocked = SaveSystem.is_character_unlocked(key)
		# ⚠ 旧实现是 `btn.modulate = 角色色`（未选中再乘 0.45）—— 用 modulate 表达「角色配色」
		# 会把**整张卡连同文字一起**乘暗：未选中的文字被压到近黑（62 个格子看着像空框），
		# 选中的则整片染色（绿字绿底）。改成「深色卡 + 角色色强调边 + 独立文字色」。
		var card := _build_card(key, data, unlocked)
		card.gui_input.connect(_on_card_input.bind(key))
		grid.add_child(card)
		buttons[key] = card

	_refresh_highlight()

	# 解锁提示标签
	lock_info_label = Label.new()
	lock_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_info_label.add_theme_font_size_override("font_size", 18)
	lock_info_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	lock_info_label.text = ""
	var vbox = $Margin/VBox
	vbox.add_child(lock_info_label)
	vbox.move_child(lock_info_label, $Margin/VBox/ScrollContainer.get_index() + 1)

	# 难度选择区域（Danger 0-5）— 插入到 StartButton 上方。
	# 档位数取自 GameState（不写死 6），加档时界面自动跟上。
	# 非法残留值（调试/旧构建留下的越界数）先归一化到基准档：界面是难度的唯一入口，
	# 让它带着非法值进来会导致六个格子全不高亮，玩家看不出当前档位。
	if not GameState.is_valid_danger(GameState.difficulty):
		GameState.difficulty = GameState.BASELINE_DANGER
	var danger_box = VBoxContainer.new()
	danger_box.add_theme_constant_override("separation", 4)

	var danger_label = Label.new()
	danger_label.text = "难度（Danger）"
	danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger_label.add_theme_font_size_override("font_size", 18)
	danger_box.add_child(danger_label)

	var danger_row = HBoxContainer.new()
	danger_row.alignment = BoxContainer.ALIGNMENT_CENTER
	danger_row.add_theme_constant_override("separation", 8)
	danger_box.add_child(danger_row)

	for danger_id in range(GameState.get_danger_level_count()):
		var tile := _build_danger_tile(danger_id)
		tile.gui_input.connect(_on_danger_tile_input.bind(danger_id))
		danger_row.add_child(tile)
		danger_tiles[danger_id] = tile

	# 将难度容器插入到 StartButton 之前
	vbox.add_child(danger_box)
	vbox.move_child(danger_box, $Margin/VBox/StartButton.get_index())

	# 无尽模式切换按钮
	var mode_container = HBoxContainer.new()
	mode_container.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_container.add_theme_constant_override("separation", 16)

	var mode_label = Label.new()
	mode_label.text = "模式："
	mode_label.add_theme_font_size_override("font_size", 20)
	mode_container.add_child(mode_label)

	endless_btn = Button.new()
	endless_btn.custom_minimum_size = Vector2(160, 40)
	endless_btn.add_theme_font_size_override("font_size", 18)
	endless_btn.pressed.connect(_on_endless_toggled)
	mode_container.add_child(endless_btn)

	vbox.add_child(mode_container)
	vbox.move_child(mode_container, $Margin/VBox/StartButton.get_index())

	_refresh_endless()
	_refresh_danger()

	$Margin/VBox/StartButton.pressed.connect(func():
		if not SaveSystem.is_character_unlocked(selected_key):
			var cond = GameState.get_character_select_entries()[selected_key].get("unlock_condition", "")
			lock_info_label.text = "未解锁！条件：" + cond
			return
		GameState.selected_character = selected_key
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	$Margin/VBox/BackButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)

# 一张角色卡：左侧徽章（形状语言派生，零资产）+ 右侧名称与数值。
# 文字层级刻意拉开（名称 16 / 数值 12 且更暗），旧版全部同号居中，读起来是一团。
func _build_card(key: String, data: Dictionary, unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(216, 106)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG if unlocked else CARD_BG_LOCKED
	style.set_border_width_all(2)
	style.border_color = CARD_BORDER if unlocked else CARD_BORDER_LOCKED
	style.set_corner_radius_all(CARD_RADIUS)
	style.set_content_margin_all(8.0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	card.add_theme_stylebox_override("panel", style)
	card_styles[key] = style

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var emblem := CharacterEmblem.build(row, key, data.color if unlocked else EMBLEM_LOCKED, EMBLEM_BOX)
	card_emblem_bodies[key] = emblem.body

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)

	var name_label := Label.new()
	name_label.text = str(data.name) if unlocked else ("[未解锁] " + str(data.name))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT_NAME if unlocked else TEXT_NAME_LOCKED)
	name_label.clip_text = true
	col.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = str(data.desc) if unlocked else str(data.get("unlock_condition", "尚未解锁"))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", TEXT_DESC if unlocked else TEXT_DESC_LOCKED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 3
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc_label)

	return card


func _on_card_input(event: InputEvent, key: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_char_selected(key)


func _on_char_selected(key):
	selected_key = key
	_refresh_highlight()
	# 显示锁定提示
	if not SaveSystem.is_character_unlocked(key):
		var cond = GameState.get_character_select_entries()[key].get("unlock_condition", "")
		lock_info_label.text = "解锁条件：" + cond
	else:
		lock_info_label.text = ""

func _refresh_highlight():
	var character_entries = GameState.get_character_select_entries()
	for key in buttons:
		var unlocked = SaveSystem.is_character_unlocked(key)
		var col: Color = character_entries[key].color
		var is_selected: bool = key == selected_key
		var style: StyleBoxFlat = card_styles[key]
		if not unlocked:
			style.bg_color = CARD_BG_LOCKED
			style.border_color = Color(0.45, 0.46, 0.52) if is_selected else CARD_BORDER_LOCKED
			style.set_border_width_all(3 if is_selected else 2)
		elif is_selected:
			# 用**角色色描边 + 底色轻染**表达选中：文字与徽章保持原样，可读性不受影响
			style.bg_color = CARD_BG.lerp(col, 0.14)
			style.border_color = col
			style.set_border_width_all(3)
		else:
			style.bg_color = CARD_BG
			style.border_color = CARD_BORDER
			style.set_border_width_all(2)
		# 徽章始终是角色本色（未解锁才置灰）—— 形象本身就是识别度，不该被选中状态压暗
		var body = card_emblem_bodies.get(key)
		if body != null and is_instance_valid(body):
			body.color = col if unlocked else EMBLEM_LOCKED

# 一张难度卡：档位名 + 关键差异（敌人强度 / 额外精英率 / 刷怪密度）。
# 只写「Danger 3」信息量为零 —— 玩家得知道选它意味着什么才谈得上选择。
# 三行数字全部现取 GameState，界面不存副本。
func _build_danger_tile(danger_id: int) -> PanelContainer:
	var info = DANGER_INFO[danger_id]
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(176, 74)
	var style := StyleBoxFlat.new()
	style.bg_color = DANGER_TILE_BG
	style.set_border_width_all(2)
	style.border_color = DANGER_TILE_BORDER
	style.set_corner_radius_all(CARD_RADIUS)
	style.set_content_margin_all(6.0)
	tile.add_theme_stylebox_override("panel", style)
	danger_styles[danger_id] = style

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	tile.add_child(col)

	var name_label := Label.new()
	name_label.text = "Danger %d · %s" % [danger_id, str(info.name)]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	col.add_child(name_label)

	var hint_label := Label.new()
	hint_label.text = _danger_hint(danger_id)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint_label)

	danger_name_labels[danger_id] = name_label
	danger_hint_labels[danger_id] = hint_label
	return tile

# 档位差异文本。三项都是相对**基准档（Danger 1）**的百分比，精英率是绝对概率
# （原版 D0/D1 就是 0% 精英，说「相对基准 +0%」反而绕）。
func _danger_hint(danger_id: int) -> String:
	var profile: Dictionary = GameState.get_danger_profile(danger_id)
	var baseline: Dictionary = GameState.get_danger_profile(GameState.BASELINE_DANGER)
	var enemy_pct := (float(profile["enemy_multiplier"]) / float(baseline["enemy_multiplier"]) - 1.0) * 100.0
	var spawn_pct := (float(profile["spawn_multiplier"]) / float(baseline["spawn_multiplier"]) - 1.0) * 100.0
	var elite_pct := float(profile["elite_chance"]) * 100.0
	return "敌人 %s\n精英 %.0f%% · 密度 %s" % [
		_format_percent_delta(enemy_pct), elite_pct, _format_percent_delta(spawn_pct)
	]

func _format_percent_delta(percent: float) -> String:
	if absf(percent) < 0.5:
		return "基准"
	return "%s%.0f%%" % ["+" if percent > 0.0 else "", percent]

func _on_danger_tile_input(event: InputEvent, danger_id: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_danger_selected(danger_id)

func _on_danger_selected(danger_id: int):
	# 界面是难度的入口，非法档直接拒绝并保持原档（不回退、不静默夹取）。
	if not GameState.is_valid_danger(danger_id):
		return
	GameState.difficulty = danger_id
	_refresh_danger()

func _refresh_danger():
	for danger_id in danger_tiles:
		var accent: Color = DANGER_INFO[danger_id].color
		var selected: bool = danger_id == GameState.difficulty
		var style: StyleBoxFlat = danger_styles[danger_id]
		# 选中/未选中表达在边框 + 底色 + 字体色上，不用 modulate（见文件头的常量注释）。
		if selected:
			style.bg_color = DANGER_TILE_BG.lerp(accent, 0.16)
			style.border_color = accent
			style.set_border_width_all(3)
		else:
			style.bg_color = DANGER_TILE_BG
			style.border_color = DANGER_TILE_BORDER
			style.set_border_width_all(2)
		var name_label: Label = danger_name_labels[danger_id]
		name_label.add_theme_color_override("font_color",
			DANGER_TEXT_NAME if selected else DANGER_TEXT_NAME_IDLE)
		var hint_label: Label = danger_hint_labels[danger_id]
		hint_label.add_theme_color_override("font_color",
			accent if selected else DANGER_TEXT_HINT)

func _on_endless_toggled():
	GameState.endless_mode = not GameState.endless_mode
	_refresh_endless()

func _refresh_endless():
	endless_btn.modulate = Color.WHITE
	if GameState.endless_mode:
		endless_btn.text = "无尽模式"
		endless_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	else:
		endless_btn.text = "普通模式"
		endless_btn.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
