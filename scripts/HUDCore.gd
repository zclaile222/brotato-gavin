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
