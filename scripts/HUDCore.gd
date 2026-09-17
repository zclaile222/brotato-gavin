# HUDCore.gd — HP/XP/材料/波次/计时器/护盾等基础显示更新
class_name HUDCore
extends RefCounted

var hud: CanvasLayer

func init(p_hud: CanvasLayer):
	hud = p_hud

func update_hp(hp, max_hp):
	hud.hp_label.text = "生命: %d / %d" % [hp, max_hp]
	hud._update_danger_vignette(hp, max_hp)

func update_kills(kills):
	hud.kills_label.text = "击杀: %d" % kills

func update_wave(wave, total):
	if GameState.endless_mode and wave > total:
		hud.wave_label.text = "♾ 第 %d 波" % wave
		hud.wave_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	else:
		hud.wave_label.text = "第 %d / %d 波" % [wave, total]
		hud.wave_label.remove_theme_color_override("font_color")

func update_timer(t):
	hud.timer_label.text = "%d 秒" % ceil(t)

func update_xp(xp, xp_to_next):
	hud.xp_bar.max_value = xp_to_next
	hud.xp_bar.value = xp

func update_level(lv):
	hud.level_label.text = "等级.%d" % lv

func update_gold(materials):
	hud.gold_label.text = "材料: %d" % materials

func update_weapons(names):
	hud.weapons_label.text = "武器: " + "  |  ".join(names)

# ─── B4：结构化武器栏 ───
#
# 旧的 `update_weapons(names)` 只拿到一个字符串数组，渲染方无从知道分阶、伤害、
# 能不能合成、该用什么颜色 —— 只能拼一行文字。但数据其实全在
# `PlayerCombat.get_weapon_info()` 里，只是没被传递过来：
# `Main.gd:129` 把 `weapons_changed(names)` 接到 `hud.update_weapons(names)`，
# 而那个信号（`PlayerCombat.emit_weapons_changed`）发出的**只有名字串**。
#
# 本轮我不改信号签名（那会牵动 Main.gd / Player.gd，都不是我的文件），
# 而是让渲染方**主动来取**结构化数据：`hud` 侧拿到 player 引用后调本函数。

# 武器栏单个格子的尺寸。零美术资产 —— 格子是纯几何色块 + 文字，不贴图。
const WEAPON_SLOT_SIZE := Vector2(54, 54)
const WEAPON_SLOT_GAP := 6.0

var weapon_bar: HBoxContainer = null
var _weapon_bar_slots: Array = []

# 建立/更新武器栏。
#
# `weapons` 接受两种形态，都用同一套渲染：
#   * `Array[Dictionary]` —— `PlayerCombat.get_weapon_info()` 的原样输出（推荐）；
#   * `Array[String]`     —— 旧的名字串数组（向后兼容，退化为纯文字格子）。
#
# 传空数组 = 清空武器栏（玩家把武器全卖光时会出现）。
func update_weapon_bar(weapons: Array):
	_ensure_weapon_bar()
	if weapon_bar == null:
		return
	_clear_weapon_bar_slots()
	for i in range(weapons.size()):
		var entry = weapons[i]
		if entry is Dictionary:
			_weapon_bar_slots.append(_make_weapon_slot(entry, i))
		else:
			_weapon_bar_slots.append(_make_weapon_slot({"name": str(entry), "tier": 1, "slot_index": i}, i))


func _ensure_weapon_bar():
	if weapon_bar != null and is_instance_valid(weapon_bar):
		return
	# ⚠ hud 是 CanvasLayer，**不是 Control** —— 它没有 `position`、没有 anchors、
	# 也不能直接量视口。所以必须用一个 Control 来承载布局，位置靠显式 offset 给。
	# （写错会整脚本解析失败，症状是一屏 `Nonexistent function ... in base 'CanvasLayer'`。）
	weapon_bar = HBoxContainer.new()
	weapon_bar.name = "WeaponBar"
	weapon_bar.add_theme_constant_override("separation", int(WEAPON_SLOT_GAP))
	weapon_bar.z_index = 15
	# 贴左下角：旧的 WeaponsLabel 在 (20, 675)，武器栏放它上方，语义上更接近原版的
	# 「装备栏在屏幕角落」的观感，且不会和下方 XP 条打架。
	var viewport_size := hud.get_viewport().get_visible_rect().size
	var total_width := weapons_bar_width(_estimated_slot_count())
	weapon_bar.position = Vector2(20.0, max(0.0, viewport_size.y - 190.0))
	hud.add_child(weapon_bar)
	# 视口改变时重新贴边（HUD 会在窗口尺寸变化时调本函数重建）
	hud.get_viewport().size_changed.connect(_reposition_weapon_bar)


func _estimated_slot_count() -> int:
	return max(1, _weapon_bar_slots.size())


func weapons_bar_width(slot_count: int) -> float:
	if slot_count <= 0:
		return 0.0
	return float(slot_count) * WEAPON_SLOT_SIZE.x + float(slot_count - 1) * WEAPON_SLOT_GAP


func _reposition_weapon_bar():
	if weapon_bar == null or not is_instance_valid(weapon_bar):
		return
	var viewport_size := hud.get_viewport().get_visible_rect().size
	weapon_bar.position = Vector2(20.0, max(0.0, viewport_size.y - 190.0))


func _clear_weapon_bar_slots():
	_weapon_bar_slots.clear()
	if weapon_bar == null or not is_instance_valid(weapon_bar):
		return
	for child in weapon_bar.get_children():
		weapon_bar.remove_child(child)
		child.free()


# 单个武器格子：一个带描边的色块 + 分阶角标 + 名字首字。
# 全部用 StyleBoxFlat / Label 画，**零贴图**。
func _make_weapon_slot(info: Dictionary, index: int) -> Control:
	var tier := int(info.get("tier", info.get("level", 1)))
	var tier_color: Color = info.get("tier_color", _tier_color_for(tier))

	var slot := PanelContainer.new()
	slot.name = "WeaponSlot%d" % index
	slot.custom_minimum_size = WEAPON_SLOT_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14, 0.85)
	# 状态一律用 border_color 表达，**绝不用 modulate** ——
	# modulate 是乘算且作用于整棵子树，会把格子里的文字一起压暗。
	style.border_color = tier_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	slot.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	slot.add_child(vbox)

	# 顶部：分阶角标（T1..T4），T4 加星号与金框
	var tier_label := Label.new()
	tier_label.text = "★T4" if tier >= 4 else "T%d" % tier
	tier_label.add_theme_font_size_override("font_size", 11)
	tier_label.add_theme_color_override("font_color", tier_color)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(tier_label)

	# 中部：名字首字（当「图标」用）—— 取前 2 个字符，够区分又不撑爆格子
	var icon_label := Label.new()
	icon_label.text = _weapon_icon_text(str(info.get("name", "?")))
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", info.get("color", tier_color))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# 底部：可合成指示。同样只改文字颜色，不用 modulate。
	var state_label := Label.new()
	if bool(info.get("can_combine", false)):
		state_label.text = "可合成"
		state_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.5))
	elif bool(info.get("max_level", false)):
		state_label.text = "满阶"
		state_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		state_label.text = ""
	state_label.add_theme_font_size_override("font_size", 9)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(state_label)

	# 槽位下标做成 meta：渲染方/测试可以据此定位它对应 equipped_weapons 的哪一格
	slot.set_meta("slot_index", int(info.get("slot_index", index)))
	slot.tooltip_text = "%s T%d" % [str(info.get("name", "")), tier]
	return slot


func _weapon_icon_text(name: String) -> String:
	if name.length() <= 2:
		return name
	return name.substr(0, 2)


func _tier_color_for(tier: int) -> Color:
	match clamp(tier, 1, 4):
		1: return Color(0.85, 0.85, 0.85)
		2: return Color(0.40, 0.90, 0.45)
		3: return Color(0.40, 0.70, 1.00)
		_: return Color(1.00, 0.75, 0.20)


# 取某个格子的槽位下标；越界返回 -1。给拖拽 / 出售用。
func get_weapon_slot_index_at(slot_position: int) -> int:
	if slot_position < 0 or slot_position >= _weapon_bar_slots.size():
		return -1
	var slot = _weapon_bar_slots[slot_position]
	if slot == null or not is_instance_valid(slot):
		return -1
	return int(slot.get_meta("slot_index", -1))


func get_weapon_bar_slot_count() -> int:
	return _weapon_bar_slots.size()

func update_shield(s, max_s):
	if hud.shield_label == null:
		return
	if max_s > 0:
		hud.shield_label.text = "护盾: %d / %d" % [s, max_s]
		hud.shield_label.visible = true
	else:
		hud.shield_label.visible = false

func show_level_up():
	hud.level_up_label.visible = true
	await hud.get_tree().create_timer(1.2).timeout
	if is_instance_valid(hud.level_up_label):
		hud.level_up_label.visible = false

# ─── Buff 图标显示 ───

const BUFF_NAMES = {
	"speed_boost": "速度",
	"damage_boost": "伤害",
	"rapid_fire": "急速",
	"shield": "护盾",
	"vampire_fang": "吸血",
}

const BUFF_COLORS = {
	"speed_boost": Color(0.2, 0.8, 1.0),
	"damage_boost": Color(1.0, 0.3, 0.2),
	"rapid_fire": Color(1.0, 0.8, 0.0),
	"shield": Color(0.3, 0.5, 1.0),
	"vampire_fang": Color(0.8, 0.1, 0.3),
}

func update_buffs(pickups: Dictionary):
	for btype in hud.buff_labels.keys():
		if not pickups.has(btype):
			hud.buff_labels[btype].queue_free()
			hud.buff_labels.erase(btype)
	for btype in pickups:
		var timer_val = pickups[btype].timer
		if not hud.buff_labels.has(btype):
			var label = Label.new()
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", BUFF_COLORS.get(btype, Color.WHITE))
			hud.buff_container.add_child(label)
			hud.buff_labels[btype] = label
		hud.buff_labels[btype].text = "%s %ds" % [BUFF_NAMES.get(btype, btype), ceil(timer_val)]

# ─── 波次修饰词 ───

func show_wave_modifier(mod_name: String, mod_desc: String, color: Color):
	if mod_name == "":
		hud.modifier_label.visible = false
		return
	hud.modifier_label.text = mod_name + "  " + mod_desc
	hud.modifier_label.add_theme_color_override("font_color", color)
	hud.modifier_label.visible = true
	hud.modifier_label.modulate = Color(1, 1, 1, 1)
	var tw = hud.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func():
		if is_instance_valid(hud.modifier_label):
			hud.modifier_label.text = mod_name
			var tw2 = hud.create_tween()
			tw2.tween_property(hud.modifier_label, "modulate", Color(1, 1, 1, 0.5), 1.0)
	)

# ─── 角色被动指示器 ───

func update_passive_indicator(p):
	if not p or not is_instance_valid(p):
		hud.passive_label.visible = false
		return
	var txt = ""
	match p.character_passive:
		"engineer":
			var cd = max(0, p.turret_timer)
			txt = "[工程师] 炮塔 CD: %.1fs" % cd
			hud.passive_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		"berserker":
			var tiers = 0
			if p.max_hp > 0:
				var pct = float(p.hp) / float(p.max_hp)
				if pct <= 0.75: tiers += 1
				if pct <= 0.50: tiers += 1
				if pct <= 0.25: tiers += 1
			txt = "[狂战士] 伤害+%d (%d/3)" % [p.berserker_hp_bonus, tiers]
			var c = Color(0.8, 0.2, 0.9).lerp(Color(1, 0.2, 0.2), float(tiers) / 3.0)
			hud.passive_label.add_theme_color_override("font_color", c)
		"ghost":
			txt = "[幽灵] 闪避 25%  累计: %d" % p.total_dodges
			hud.passive_label.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
		"necromancer":
			var count = hud.get_tree().get_nodes_in_group("undeads").size()
			txt = "[死灵] 亡灵: %d/5" % count
			hud.passive_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.8))
		_:
			hud.passive_label.visible = false
			return
	hud.passive_label.text = txt
	hud.passive_label.visible = true
