extends CanvasLayer

@onready var hp_label       = $HPLabel
@onready var kills_label    = $KillsLabel
@onready var level_label    = $LevelLabel
@onready var gold_label     = $GoldLabel
@onready var wave_label     = $WaveLabel
@onready var timer_label    = $TimerLabel
@onready var level_up_label = $LevelUpLabel
@onready var weapons_label  = $WeaponsLabel
@onready var xp_bar         = $XPBar
@onready var damage_flash   = $DamageFlash
@onready var boss_bar_root  = $BossBarRoot
@onready var boss_hp_bar    = $BossBarRoot/BossHPBar
@onready var game_over_panel = $GameOverPanel
@onready var victory_panel  = $VictoryPanel

# 暂停菜单（动态创建）
var pause_panel: PanelContainer = null
var pause_stats_label: Label = null
var pause_overlay: ColorRect = null
var volume_slider: HSlider = null
var confirm_panel: PanelContainer = null
var confirm_label: Label = null
var _confirm_action: String = ""

# 护盾标签
var shield_label: Label = null

# 波次结算面板
var wave_summary_panel: PanelContainer = null
var wave_summary_title: Label = null
var wave_summary_stats: Label = null

# 升级选择面板
var upgrade_panel: PanelContainer = null
# 升级面板的居中容器（居中由它负责，见 _build_upgrade_choice_panel 里的说明）
var upgrade_center: CenterContainer = null
var upgrade_choice_buttons: Array = []
var crate_reward_panel: PanelContainer = null
var crate_reward_title: Label = null
var crate_reward_desc: Label = null
var crate_reward_recycle_button: Button = null

# 击杀连击计数
var combo_count = 0
var combo_timer = 0.0
var combo_label: Label
var max_combo = 0

# 成就通知系统
var notify_queue = []
var notify_showing = false
var notify_panel: PanelContainer

# 新手引导
var tutorial_panel: PanelContainer = null

# 波次修饰词显示
var modifier_label: Label = null

# 特殊事件面板
var event_panel: PanelContainer = null
var event_title_label: Label = null
var event_desc_label: Label = null
var event_timer_label: Label = null
var event_timer_countdown = 0.0

signal event_accepted
signal event_rejected
signal upgrade_choice_selected(index: int)
signal upgrade_choice_rerolled
signal crate_reward_taken(index: int)
signal crate_reward_recycled(index: int)

# 低血量暗角
var danger_vignette: ColorRect = null
var danger_pulse_time = 0.0

# 屏幕边缘敌人方向箭头
var arrow_pool = []
var arrow_margin = 30.0
var arrows_enabled = false

# Buff显示
var buff_container: HBoxContainer = null
var buff_labels: Dictionary = {}

# 成就解锁通知
var achievement_queue = []
var achievement_showing = false
var achievement_panel: PanelContainer = null

# 小地图
var minimap_container: Control = null
var minimap_canvas: Node2D = null
const MINIMAP_SIZE = 120
const MINIMAP_RANGE = 500.0

# 角色被动指示器
var passive_label: Label = null

# 子模块
var core: HUDCore
var combat: HUDCombat
var panels: HUDPanels

signal combo_milestone(count: int)

func _ready():
	core = HUDCore.new()
	core.init(self)
	combat = HUDCombat.new()
	combat.init(self)
	panels = HUDPanels.new()
	panels.init(self)

	_build_pause_menu()
	_build_shield_label()
	_build_wave_summary()
	_build_upgrade_choice_panel()
	_build_crate_reward_panel()
	_build_enemy_arrows()
	_build_combo_label()
	_build_notify_panel()
	_build_tutorial_panel()
	_build_modifier_label()
	_build_event_panel()
	_build_danger_vignette()
	_build_buff_display()
	_build_minimap()
	_build_passive_indicator()
	_build_achievement_panel()

func _build_combo_label():
	combo_label = Label.new()
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 40)
	combo_label.visible = false
	combo_label.z_index = 15
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(combo_label)

func _process(delta):
	combat.process_combo(delta)
	panels.process_event_timer(delta)
	combat.process_danger_vignette(delta)
	if arrows_enabled:
		combat.update_enemy_arrows()
	else:
		for arrow in arrow_pool:
			arrow.visible = false

# ─── 公共接口（委托给子模块） ───

# HUDCore
func update_hp(hp, max_hp): core.update_hp(hp, max_hp)
func update_kills(kills): core.update_kills(kills)
func update_wave(wave, total): core.update_wave(wave, total)
func update_timer(t): core.update_timer(t)
func update_xp(xp, xp_to_next): core.update_xp(xp, xp_to_next)
func update_level(lv): core.update_level(lv)
func update_gold(gold): core.update_gold(gold)
func update_weapons(names): core.update_weapons(names)
func update_shield(s, max_s): core.update_shield(s, max_s)
func show_level_up(): core.show_level_up()
func update_buffs(pickups): core.update_buffs(pickups)
func show_wave_modifier(mod_name, mod_desc, color): core.show_wave_modifier(mod_name, mod_desc, color)
func update_passive_indicator(p): core.update_passive_indicator(p)

# HUDCombat
func add_combo_kill(): combat.add_combo_kill()
func show_boss_bar(hp, max_hp): combat.show_boss_bar(hp, max_hp)
func update_boss_bar(hp, max_hp): combat.update_boss_bar(hp, max_hp)
func hide_boss_bar(): combat.hide_boss_bar()
func update_boss_phase(p_phase): combat.update_boss_phase(p_phase)
func flash_damage(): combat.flash_damage()
func _update_danger_vignette(hp, max_hp_val): combat.update_danger_vignette(hp, max_hp_val)
func update_minimap(player_pos, enemies, pickups): combat.update_minimap(player_pos, enemies, pickups)

# HUDPanels
func show_pause_menu(p_player = null): panels.show_pause_menu(p_player)
func hide_pause_menu(): panels.hide_pause_menu()
func show_game_over(kills, wave, p_player = null): panels.show_game_over(kills, wave, p_player)
func show_victory(kills, wave, p_player = null): panels.show_victory(kills, wave, p_player)
func show_wave_summary(p_wave, p_kills, p_gold, p_xp, p_is_boss = false): panels.show_wave_summary(p_wave, p_kills, p_gold, p_xp, p_is_boss)
func show_upgrade_choices(choices: Array):
	# 面板宽度跟随视口：760 在 1280 宽屏上刚好，但窄窗口下会顶到两边。
	# 4 个按钮各 170 + 3×10 间隔 + 32 边距 ≈ 742 是硬下限，再窄就只能换列布局了。
	if upgrade_panel != null:
		# HUD extends CanvasLayer（不是 Control）—— 没有 get_viewport_rect()，
		# 必须走 get_viewport().get_visible_rect()。
		var view: Vector2 = get_viewport().get_visible_rect().size
		upgrade_panel.custom_minimum_size.x = clampf(view.x - 40.0, 742.0, 760.0)
	for i in range(upgrade_choice_buttons.size()):
		var btn = upgrade_choice_buttons[i]
		if i < choices.size():
			var c = choices[i]
			btn.text = "%s\n%s" % [c.name, c.desc]
			btn.visible = true
		else:
			btn.visible = false
	upgrade_panel.visible = true

func hide_upgrade_choices():
	if upgrade_panel:
		upgrade_panel.visible = false

func show_crate_reward(reward: Dictionary):
	if crate_reward_panel == null:
		return
	var rarity_names = ["普通", "精良", "稀有", "传说"]
	var rarity = clamp(int(reward.get("rolled_rarity", reward.get("rarity", 0))), 0, 3)
	crate_reward_title.text = "%s  [%s]" % [reward.get("name", "未知道具"), rarity_names[rarity]]
	crate_reward_desc.text = "%s\n%s" % [reward.get("desc", ""), _format_crate_reward_effect(reward)]
	crate_reward_recycle_button.text = "回收 (+%d材料)" % int(reward.get("recycle_value", 1))
	crate_reward_panel.visible = true

func hide_crate_reward():
	if crate_reward_panel:
		crate_reward_panel.visible = false

func _format_crate_reward_effect(reward: Dictionary) -> String:
	var item_type = reward.get("type", "")
	var value = reward.get("value", 0)
	match item_type:
		"speed": return "速度 +%d" % int(value)
		"fire_rate": return "射速 +%d%%" % int(float(value) * 100.0)
		"damage": return "伤害 +%d" % int(value)
		"hp": return "最大HP +%d" % int(value)
		"heal": return "恢复 %dHP" % int(value)
		"magnet": return "磁铁范围 +%d" % int(value)
		"armor": return "护甲 +%d" % int(value)
		"crit_chance": return "暴击率 +%d%%" % int(float(value) * 100.0)
		"lifesteal": return "生命偷取 +%d%%" % int(float(value) * 100.0)
		"luck": return "幸运 +%d" % int(value)
		"catalog_item": return reward.get("effect_text", reward.get("desc", "道具"))
		_: return "道具"

func show_notification(text, color = Color.WHITE): panels.show_notification(text, color)
func show_achievement_unlock(title, desc): panels.show_achievement_unlock(title, desc)
func show_achievements_summary(new_unlocks): panels.show_achievements_summary(new_unlocks)
func show_event_panel(title, desc, color = Color(1, 0.85, 0.2)): panels.show_event_panel(title, desc, color)
func show_tutorial_hint(): panels.show_tutorial_hint()

# 暂停菜单按钮回调（委托）
func _on_pause_resume(): panels.on_pause_resume()
func _on_pause_restart(): panels.on_pause_restart()
func _on_pause_main_menu(): panels.on_pause_main_menu()
func _on_confirm_yes(): panels.on_confirm_yes()
func _on_confirm_no(): panels.on_confirm_no()
func _on_volume_changed(value): panels.on_volume_changed(value)
func _on_event_accept(): panels.on_event_accept()
func _on_event_reject(): panels.on_event_reject()

# ─── UI构建方法（保留在主脚本中） ───

func _build_pause_menu():
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0, 0, 0, 0.6)
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_overlay)

	pause_panel = PanelContainer.new()
	pause_panel.name = "PausePanel"
	pause_panel.custom_minimum_size = Vector2(300, 280)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	pause_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	pause_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "游戏暂停"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	pause_stats_label = Label.new()
	pause_stats_label.add_theme_font_size_override("font_size", 14)
	pause_stats_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	pause_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(pause_stats_label)

	var vol_hbox = HBoxContainer.new()
	vol_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(vol_hbox)
	var vol_label = Label.new()
	vol_label.text = "主音量"
	vol_label.add_theme_font_size_override("font_size", 16)
	vol_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vol_hbox.add_child(vol_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = 1.0
	volume_slider.custom_minimum_size = Vector2(180, 20)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_on_volume_changed)
	vol_hbox.add_child(volume_slider)

	var resume_btn = Button.new()
	resume_btn.text = "继续游戏"
	resume_btn.custom_minimum_size = Vector2(0, 40)
	resume_btn.add_theme_font_size_override("font_size", 18)
	resume_btn.pressed.connect(_on_pause_resume)
	vbox.add_child(resume_btn)

	var restart_btn = Button.new()
	restart_btn.text = "重新开始"
	restart_btn.custom_minimum_size = Vector2(0, 40)
	restart_btn.add_theme_font_size_override("font_size", 18)
	restart_btn.pressed.connect(_on_pause_restart)
	vbox.add_child(restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(0, 40)
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(_on_pause_main_menu)
	vbox.add_child(menu_btn)

	add_child(pause_panel)
	_build_confirm_dialog()

func _build_confirm_dialog():
	confirm_panel = PanelContainer.new()
	confirm_panel.name = "ConfirmPanel"
	confirm_panel.custom_minimum_size = Vector2(280, 140)
	confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirm_panel.visible = false
	confirm_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_panel.z_index = 10

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.6, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	confirm_panel.add_theme_stylebox_override("panel", style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	confirm_panel.add_child(m)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(vb)

	confirm_label = Label.new()
	confirm_label.text = "是否确认？"
	confirm_label.add_theme_font_size_override("font_size", 20)
	confirm_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(confirm_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)

	var yes_btn = Button.new()
	yes_btn.text = "确定"
	yes_btn.custom_minimum_size = Vector2(90, 36)
	yes_btn.add_theme_font_size_override("font_size", 16)
	yes_btn.pressed.connect(_on_confirm_yes)
	btn_row.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = "取消"
	no_btn.custom_minimum_size = Vector2(90, 36)
	no_btn.add_theme_font_size_override("font_size", 16)
	no_btn.pressed.connect(_on_confirm_no)
	btn_row.add_child(no_btn)

	add_child(confirm_panel)

func _build_shield_label():
	shield_label = Label.new()
	shield_label.name = "ShieldLabel"
	shield_label.position = hp_label.position + Vector2(0, 24)
	shield_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	shield_label.visible = false
	add_child(shield_label)

func _build_modifier_label():
	modifier_label = Label.new()
	modifier_label.name = "ModifierLabel"
	modifier_label.add_theme_font_size_override("font_size", 20)
	modifier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modifier_label.position = Vector2(640 - 200, 50)
	modifier_label.size = Vector2(400, 30)
	modifier_label.visible = false
	modifier_label.z_index = 12
	add_child(modifier_label)

func _build_danger_vignette():
	danger_vignette = ColorRect.new()
	danger_vignette.name = "DangerVignette"
	danger_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_vignette.visible = false
	danger_vignette.z_index = 5
	add_child(danger_vignette)

func _build_wave_summary():
	wave_summary_panel = PanelContainer.new()
	wave_summary_panel.name = "WaveSummaryPanel"
	wave_summary_panel.custom_minimum_size = Vector2(360, 200)
	wave_summary_panel.set_anchors_preset(Control.PRESET_CENTER)
	wave_summary_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave_summary_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	wave_summary_panel.visible = false
	wave_summary_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.6, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	wave_summary_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	wave_summary_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	wave_summary_title = Label.new()
	wave_summary_title.add_theme_font_size_override("font_size", 24)
	wave_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(wave_summary_title)

	wave_summary_stats = Label.new()
	wave_summary_stats.add_theme_font_size_override("font_size", 18)
	wave_summary_stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	wave_summary_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(wave_summary_stats)

	add_child(wave_summary_panel)

func _build_upgrade_choice_panel():
	upgrade_panel = PanelContainer.new()
	upgrade_panel.name = "UpgradeChoicePanel"
	upgrade_panel.visible = false
	# ⚠ 这里原本是 `upgrade_panel.set_anchors_preset(Control.PRESET_CENTER)`。
	# 但那是在面板**还没有尺寸**的时候调的（custom_minimum_size 在下一行才设，
	# 而"最小尺寸"也不会立刻改变实际尺寸），于是四个 offset 全被算成 0 ——
	# 矩形塌缩成屏幕中心的一个点；之后容器按内容把尺寸撑开，
	# 右/下边就**从中心点往右下长** → 面板偏右且右边越界
	# （1280 宽屏上面板 760 宽，右边缘到 1400，超出 120px）。
	# 症状是「居中失败」，根因是**锚点预设的调用时机错了**。
	# 正确做法：交给一个铺满全屏的 CenterContainer 托管，居中由容器负责 ——
	# 与面板自身尺寸、屏幕分辨率都无关，不会再因为改动内容而复发。
	upgrade_panel.custom_minimum_size = Vector2(760, 260)
	upgrade_panel.z_index = 30

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.7, 0.8, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	upgrade_panel.add_theme_stylebox_override("panel", style)

	upgrade_center = CenterContainer.new()
	upgrade_center.name = "UpgradeChoiceCenter"
	upgrade_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(upgrade_center)
	upgrade_center.add_child(upgrade_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	upgrade_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title = Label.new()
	title.name = "Title"
	title.text = "选择一项升级"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title)

	var row = HBoxContainer.new()
	row.name = "ChoiceRow"
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(170, 120)
		btn.pressed.connect(_on_upgrade_choice_button_pressed.bind(i))
		row.add_child(btn)
		upgrade_choice_buttons.append(btn)

func _on_upgrade_choice_button_pressed(index: int):
	upgrade_choice_selected.emit(index)

func _build_crate_reward_panel():
	crate_reward_panel = PanelContainer.new()
	crate_reward_panel.name = "CrateRewardPanel"
	crate_reward_panel.visible = false
	crate_reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	crate_reward_panel.custom_minimum_size = Vector2(520, 260)
	crate_reward_panel.z_index = 20
	add_child(crate_reward_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.75, 0.25)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	crate_reward_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	crate_reward_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	crate_reward_title = Label.new()
	crate_reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_reward_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(crate_reward_title)

	crate_reward_desc = Label.new()
	crate_reward_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_reward_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crate_reward_desc.add_theme_font_size_override("font_size", 15)
	crate_reward_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(crate_reward_desc)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var take_btn = Button.new()
	take_btn.text = "拿取"
	take_btn.custom_minimum_size = Vector2(150, 42)
	take_btn.pressed.connect(func(): crate_reward_taken.emit(0))
	row.add_child(take_btn)

	crate_reward_recycle_button = Button.new()
	crate_reward_recycle_button.custom_minimum_size = Vector2(150, 42)
	crate_reward_recycle_button.pressed.connect(func(): crate_reward_recycled.emit(0))
	row.add_child(crate_reward_recycle_button)

func _build_notify_panel():
	notify_panel = PanelContainer.new()
	notify_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notify_panel.offset_left = -320
	# 原来是 60..100，正好压在右上角小地图（top-right，约 0..130）上。
	# 截图里能直接看到通知框盖住小地图。下移到小地图下方。
	notify_panel.offset_top = 150
	notify_panel.offset_right = -10
	notify_panel.offset_bottom = 190
	notify_panel.visible = false
	notify_panel.z_index = 50
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	notify_panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.name = "NotifyLabel"
	label.add_theme_font_size_override("font_size", 16)
	notify_panel.add_child(label)
	add_child(notify_panel)

func _build_tutorial_panel():
	tutorial_panel = PanelContainer.new()
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tutorial_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tutorial_panel.offset_top = -80
	tutorial_panel.offset_bottom = -40
	tutorial_panel.visible = false
	tutorial_panel.z_index = 40
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.15)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	tutorial_panel.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.name = "TutorialLabel"
	label.text = "WASD 移动 · 自动射击 · 拾取 XP · 消灭敌人后进入商店"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_panel.add_child(label)
	add_child(tutorial_panel)

func _build_enemy_arrows():
	var container = Node2D.new()
	container.name = "ArrowContainer"
	add_child(container)
	for i in range(20):
		var arrow = Polygon2D.new()
		arrow.polygon = PackedVector2Array([
			Vector2(10, 0),
			Vector2(-8, 7),
			Vector2(-8, -7)
		])
		arrow.color = Color(1, 0.2, 0.2, 0.85)
		arrow.visible = false
		arrow.z_index = 10
		container.add_child(arrow)
		arrow_pool.append(arrow)

func set_arrows_enabled(enabled: bool):
	arrows_enabled = enabled

func _build_event_panel():
	event_panel = PanelContainer.new()
	event_panel.name = "EventPanel"
	event_panel.custom_minimum_size = Vector2(400, 250)
	event_panel.set_anchors_preset(Control.PRESET_CENTER)
	event_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	event_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	event_panel.visible = false
	event_panel.z_index = 25
	event_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	event_panel.add_theme_stylebox_override("panel", style)

	var margin_c = MarginContainer.new()
	margin_c.add_theme_constant_override("margin_left", 24)
	margin_c.add_theme_constant_override("margin_right", 24)
	margin_c.add_theme_constant_override("margin_top", 20)
	margin_c.add_theme_constant_override("margin_bottom", 20)
	event_panel.add_child(margin_c)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin_c.add_child(vbox)

	event_title_label = Label.new()
	event_title_label.add_theme_font_size_override("font_size", 26)
	event_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	event_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(event_title_label)

	event_desc_label = Label.new()
	event_desc_label.add_theme_font_size_override("font_size", 18)
	event_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	event_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(event_desc_label)

	event_timer_label = Label.new()
	event_timer_label.add_theme_font_size_override("font_size", 16)
	event_timer_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	event_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(event_timer_label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var accept_btn = Button.new()
	accept_btn.text = "接受"
	accept_btn.custom_minimum_size = Vector2(120, 44)
	accept_btn.add_theme_font_size_override("font_size", 20)
	accept_btn.pressed.connect(_on_event_accept)
	accept_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_row.add_child(accept_btn)

	var reject_btn = Button.new()
	reject_btn.text = "拒绝"
	reject_btn.custom_minimum_size = Vector2(120, 44)
	reject_btn.add_theme_font_size_override("font_size", 20)
	reject_btn.pressed.connect(_on_event_reject)
	reject_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_row.add_child(reject_btn)

	add_child(event_panel)

func _build_buff_display():
	buff_container = HBoxContainer.new()
	buff_container.name = "BuffContainer"
	buff_container.position = Vector2(10, 650)
	buff_container.add_theme_constant_override("separation", 8)
	buff_container.z_index = 20
	add_child(buff_container)

func _build_minimap():
	var screen_w = get_viewport().get_visible_rect().size.x
	minimap_container = Control.new()
	minimap_container.name = "MinimapContainer"
	minimap_container.position = Vector2(screen_w - 130, 10)
	minimap_container.custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	minimap_container.z_index = 18

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.7)
	bg.size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	minimap_container.add_child(bg)

	var border_pts = PackedVector2Array()
	var center = Vector2(MINIMAP_SIZE / 2.0, MINIMAP_SIZE / 2.0)
	for i in range(32):
		var angle = i * TAU / 32.0
		border_pts.append(center + Vector2(cos(angle), sin(angle)) * (MINIMAP_SIZE / 2.0))

	var border_line = Line2D.new()
	border_line.width = 1.5
	border_line.default_color = Color(1, 1, 1, 0.5)
	var line_pts: PackedVector2Array = border_pts.duplicate()
	line_pts.append(border_pts[0])
	border_line.points = line_pts
	minimap_container.add_child(border_line)

	minimap_canvas = Node2D.new()
	minimap_canvas.name = "MinimapCanvas"
	minimap_container.add_child(minimap_canvas)

	add_child(minimap_container)

func _add_minimap_dot(pos: Vector2, color: Color, radius: float):
	var dot = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(8):
		var angle = i * TAU / 8.0
		pts.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	dot.polygon = pts
	dot.color = color
	minimap_canvas.add_child(dot)

func _build_passive_indicator():
	passive_label = Label.new()
	passive_label.position = Vector2(1080, 10)
	passive_label.add_theme_font_size_override("font_size", 14)
	passive_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	passive_label.visible = false
	passive_label.z_index = 10
	add_child(passive_label)

func _build_achievement_panel():
	achievement_panel = PanelContainer.new()
	achievement_panel.name = "AchievementPanel"
	achievement_panel.visible = false
	achievement_panel.z_index = 60
	achievement_panel.custom_minimum_size = Vector2(280, 60)
	achievement_panel.position = Vector2(get_viewport().get_visible_rect().size.x, 160)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.0, 0.9)
	style.border_color = Color(1.0, 0.85, 0.2, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	achievement_panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.name = "AchVBox"
	vbox.add_theme_constant_override("separation", 2)
	var title_lbl = Label.new()
	title_lbl.name = "AchTitle"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title_lbl)
	var desc_lbl = Label.new()
	desc_lbl.name = "AchDesc"
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
	vbox.add_child(desc_lbl)
	achievement_panel.add_child(vbox)
	add_child(achievement_panel)
