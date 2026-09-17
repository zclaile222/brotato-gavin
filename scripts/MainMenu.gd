extends Control

const SETTINGS_PATH = "user://settings.json"

var settings = {"sfx_vol": 0.8, "bgm_vol": 0.6, "fullscreen": false, "resolution": 0}

const RESOLUTIONS = [
	{"label": "1280 × 720  (720p)",  "size": Vector2i(1280, 720)},
	{"label": "1920 × 1080  (1080p)", "size": Vector2i(1920, 1080)},
]

# 设置面板 UI
var settings_overlay: ColorRect = null
var settings_panel: PanelContainer = null
var sfx_slider: HSlider = null
var bgm_slider: HSlider = null
var fullscreen_check: CheckButton = null
var res_option_btn: OptionButton = null
var sfx_val_label: Label = null
var bgm_val_label: Label = null

# ─── 视觉 ───
# 主菜单是玩家的第一印象，原本是一整块纯色 + 一行黄字 + 三个默认灰按钮，
# 1920×1080 上大片空白。这里全部用**已有资产**与程序化手段补齐，不引入新图片：
#   ① 渐变背景（GradientTexture2D，代码生成）
#   ② 底部一排「围观」的单位精灵（复用 sprites/units/*.png），缓慢浮动
#   ③ 标题 + 副标题、按钮塑形、页脚
# 目标是让它和游戏内是同一套语言 —— 单位可爱，菜单就不该还是个占位符。
const MENU_DECOR := ["player", "boss", "armored", "ghost", "exploder", "summoner", "ranged"]
const ACCENT := Color(0.45, 0.9, 1.0)
const TITLE_COLOR := Color(1.0, 0.85, 0.25)
const SUBTITLE_COLOR := Color(0.62, 0.68, 0.8)
const FOOTER_COLOR := Color(0.42, 0.46, 0.56)

func _ready():
	$VBox/StartButton.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")
	)
	$VBox/QuitButton.pressed.connect(func():
		get_tree().quit()
	)
	_build_settings_button()
	_build_settings_panel()
	_build_menu_visuals()
	_load_settings()
	_apply_settings()


func _build_menu_visuals():
	var bg = $Background
	if bg is ColorRect:
		bg.color = Color(0.055, 0.06, 0.09, 1.0)
		# 渐变盖在纯色之上：上深下稍亮，给画面一个"光从下面来"的层次
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.10, 0.11, 0.165, 1.0))
		gradient.set_color(1, Color(0.055, 0.06, 0.09, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill_from = Vector2(0.5, 1.0)
		tex.fill_to = Vector2(0.5, 0.25)
		var glow := TextureRect.new()
		glow.texture = tex
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(glow)

	_build_menu_decor()

	var vbox = $VBox
	var title = vbox.get_node_or_null("Title")
	if title is Label:
		title.add_theme_font_size_override("font_size", 68)
		title.add_theme_color_override("font_color", TITLE_COLOR)
		var subtitle := Label.new()
		subtitle.name = "Subtitle"
		subtitle.text = "自动射击 · 20 波生存 · 62 个角色"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 18)
		subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
		vbox.add_child(subtitle)
		vbox.move_child(subtitle, title.get_index() + 1)

	for child in vbox.get_children():
		if child is Button:
			_style_menu_button(child, child.name == "StartButton")

	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "WASD 移动 · 自动射击 · 波间进商店消费材料"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", FOOTER_COLOR)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -46.0
	footer.offset_bottom = -20.0
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)


# 底部一排半没入画面外的单位精灵，缓慢上下浮动 —— 既是装饰也是"这是什么游戏"的说明。
# 用各自独立的相位，避免整齐划一地一起动（那看起来像故障）。
func _build_menu_decor():
	var view := get_viewport_rect().size
	var row := HBoxContainer.new()
	row.name = "Decor"
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -238.0
	row.offset_bottom = -120.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 44)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for i in range(MENU_DECOR.size()):
		var type_name := str(MENU_DECOR[i])
		var path := "res://sprites/units/%s.png" % type_name
		if not ResourceLoader.exists(path):
			continue
		# ⚠ TextureRect 的最小尺寸 = 贴图尺寸，`custom_minimum_size` 只是**下限**，
		# 所以直接放进 HBox 会被撑到原图 450px。必须用固定尺寸的 Control 包一层，
		# 再让 TextureRect 铺满它（EXPAND_IGNORE_SIZE 才会忽略贴图自身尺寸）。
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(84, 84)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		# 浮动动画要作用在**不被容器托管**的节点上：容器会在重排时改写直接子节点的 position。
		# 所以再套一层 bob（holder 的子节点，容器管不到），动它的 position。
		var bob := Control.new()
		bob.name = "Bob"
		bob.custom_minimum_size = Vector2(84, 84)
		bob.size = Vector2(84, 84)
		bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(bob)
		var sprite := TextureRect.new()
		sprite.texture = load(path)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.modulate = Color(1, 1, 1, 0.34)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bob.add_child(sprite)
		var tween := create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var phase := float(i) * 0.37
		tween.tween_property(bob, "position:y", -9.0, 1.6 + phase).from(9.0)
		tween.tween_property(bob, "position:y", 9.0, 1.6 + phase)


func _style_menu_button(btn: Button, primary: bool):
	var fill := Color(0.16, 0.30, 0.38, 0.95) if primary else Color(0.13, 0.14, 0.19, 0.95)
	var border := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.65) if primary else Color(0.28, 0.31, 0.4)
	btn.custom_minimum_size = Vector2(300, 52)
	btn.add_theme_font_size_override("font_size", 22 if primary else 19)
	btn.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_stylebox_override("normal", _menu_style(fill, border, 2))
	btn.add_theme_stylebox_override("hover", _menu_style(fill.lightened(0.12), border.lightened(0.2), 2))
	btn.add_theme_stylebox_override("pressed", _menu_style(fill.darkened(0.15), border, 2))
	btn.add_theme_stylebox_override("focus", _menu_style(Color(0, 0, 0, 0), border.lightened(0.25), 2))


func _menu_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(width)
	style.border_color = border
	style.set_corner_radius_all(10)
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

# --- 设置按钮 ---

func _build_settings_button():
	var btn = Button.new()
	btn.text = "设置"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_settings_pressed)
	# 插入到开始游戏按钮和退出按钮之间
	var vbox = $VBox
	var quit_idx = $VBox/QuitButton.get_index()
	vbox.add_child(btn)
	vbox.move_child(btn, quit_idx)

# --- 设置面板 ---

func _build_settings_panel():
	# 全屏遮罩
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0, 0, 0, 0.6)
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	add_child(settings_overlay)

	# 居中面板
	settings_panel = PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(440, 320)
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	settings_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	settings_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	settings_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 音效音量
	var sfx_row = HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	var sfx_label = Label.new()
	sfx_label.text = "音效音量"
	sfx_label.add_theme_font_size_override("font_size", 18)
	sfx_label.custom_minimum_size = Vector2(100, 0)
	sfx_row.add_child(sfx_label)
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = 0.8
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.custom_minimum_size = Vector2(200, 0)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(sfx_slider)
	sfx_val_label = Label.new()
	sfx_val_label.text = "80%"
	sfx_val_label.add_theme_font_size_override("font_size", 16)
	sfx_val_label.custom_minimum_size = Vector2(50, 0)
	sfx_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_row.add_child(sfx_val_label)
	vbox.add_child(sfx_row)

	# BGM 音量
	var bgm_row = HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 10)
	var bgm_label = Label.new()
	bgm_label.text = "音乐音量"
	bgm_label.add_theme_font_size_override("font_size", 18)
	bgm_label.custom_minimum_size = Vector2(100, 0)
	bgm_row.add_child(bgm_label)
	bgm_slider = HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.05
	bgm_slider.value = 0.6
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_slider.custom_minimum_size = Vector2(200, 0)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	bgm_row.add_child(bgm_slider)
	bgm_val_label = Label.new()
	bgm_val_label.text = "60%"
	bgm_val_label.add_theme_font_size_override("font_size", 16)
	bgm_val_label.custom_minimum_size = Vector2(50, 0)
	bgm_val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bgm_row.add_child(bgm_val_label)
	vbox.add_child(bgm_row)

	# 分辨率选择
	var res_row = HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	var res_label = Label.new()
	res_label.text = "分辨率"
	res_label.add_theme_font_size_override("font_size", 18)
	res_label.custom_minimum_size = Vector2(100, 0)
	res_row.add_child(res_label)
	res_option_btn = OptionButton.new()
	res_option_btn.add_theme_font_size_override("font_size", 16)
	res_option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for res in RESOLUTIONS:
		res_option_btn.add_item(res["label"])
	res_option_btn.selected = 0
	res_option_btn.item_selected.connect(_on_resolution_changed)
	res_row.add_child(res_option_btn)
	vbox.add_child(res_row)

	# 全屏切换
	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 10)
	var fs_label = Label.new()
	fs_label.text = "全屏模式"
	fs_label.add_theme_font_size_override("font_size", 18)
	fs_label.custom_minimum_size = Vector2(100, 0)
	fs_row.add_child(fs_label)
	fullscreen_check = CheckButton.new()
	fullscreen_check.button_pressed = false
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(fullscreen_check)
	vbox.add_child(fs_row)

	# 间隔
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 关闭按钮
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_on_settings_close)
	vbox.add_child(close_btn)

	add_child(settings_panel)

# --- 设置交互 ---

func _on_settings_pressed():
	settings_overlay.visible = true
	settings_panel.visible = true

func _on_settings_close():
	settings_overlay.visible = false
	settings_panel.visible = false
	_save_settings()

func _on_sfx_changed(value: float):
	settings.sfx_vol = value
	sfx_val_label.text = "%d%%" % int(value * 100)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_sfx_volume(value)

func _on_bgm_changed(value: float):
	settings.bgm_vol = value
	bgm_val_label.text = "%d%%" % int(value * 100)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_bgm_volume(value)

func _on_resolution_changed(index: int):
	settings.resolution = index
	if not settings.fullscreen:
		DisplayServer.window_set_size(RESOLUTIONS[index]["size"])
		DisplayServer.window_set_position(
			DisplayServer.screen_get_position() +
			(DisplayServer.screen_get_size() - RESOLUTIONS[index]["size"]) / 2
		)

func _on_fullscreen_toggled(pressed: bool):
	settings.fullscreen = pressed
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESOLUTIONS[settings.resolution]["size"])
		DisplayServer.window_set_position(
			DisplayServer.screen_get_position() +
			(DisplayServer.screen_get_size() - RESOLUTIONS[settings.resolution]["size"]) / 2
		)

# --- 持久化 ---

func _save_settings():
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()

func _load_settings():
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK:
		var data = json.data
		if data is Dictionary:
			settings.sfx_vol = data.get("sfx_vol", 0.8)
			settings.bgm_vol = data.get("bgm_vol", 0.6)
			settings.fullscreen = data.get("fullscreen", false)
			settings.resolution = data.get("resolution", 0)

func _apply_settings():
	# 更新 UI
	sfx_slider.value = settings.sfx_vol
	bgm_slider.value = settings.bgm_vol
	fullscreen_check.button_pressed = settings.fullscreen
	res_option_btn.selected = settings.resolution
	sfx_val_label.text = "%d%%" % int(settings.sfx_vol * 100)
	bgm_val_label.text = "%d%%" % int(settings.bgm_vol * 100)

	# 应用音量
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").set_sfx_volume(settings.sfx_vol)
		get_node("/root/AudioManager").set_bgm_volume(settings.bgm_vol)

	# 应用分辨率 & 全屏
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var sz = RESOLUTIONS[settings.resolution]["size"]
		DisplayServer.window_set_size(sz)
		DisplayServer.window_set_position(
			DisplayServer.screen_get_position() +
			(DisplayServer.screen_get_size() - sz) / 2
		)
