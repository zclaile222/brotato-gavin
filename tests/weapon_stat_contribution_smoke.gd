extends SceneTree

# 武器持有期属性贡献冒烟测试（P1-8 第一批）
#
# 背景：一部分武器的规则是「只要装备着就提供某属性」（Hand 给收获、Hammer 给击退、
# Excalibur 按武器数扣护甲……），此前这些规则在 weapons.json 里存在但运行时完全不生效。
# 2026-09-15 起由 PlayerCombat._refresh_weapon_contributions() 统一处理，
# 并在 emit_weapons_changed()（所有装备/合成/移除路径的唯一收敛点）触发。
#
# 本测试固定：
#   A. 装上武器 → 对应属性按 weapons.json 的分阶数值变化；
#   B. 卸下武器 → 属性完全还原；
#   C. tier 越高贡献越大；
#   D. 「每把武器」类规则（Excalibur）随武器数量缩放；
#   E. 重复触发刷新不会重复累加（幂等）。

const PASS_TAG := "WEAPON_STAT_CONTRIBUTION_SMOKE_PASS"
const FAIL_TAG := "WEAPON_STAT_CONTRIBUTION_SMOKE_FAIL"
const MAX_PRINTED_FAILURES := 15

# 期望值是显式契约（注释里标出对应的 weapons.json 数据键）。
# 数据改动导致不符时应当这里报红，逼一次有意识的确认。
const CASES := [
	# 规则名, 武器 id, tier, 玩家属性, 期望增量, 数据键说明
	["harvesting_by_tier", "hand", 1, "gold_per_wave", 3.0, "harvesting_bonus=3"],
	["harvesting_by_tier", "hand", 4, "gold_per_wave", 18.0, "harvesting_bonus=18"],
	["xp_gain_by_tier", "quarterstaff", 4, "xp_boost", 0.15, "xp_gain=0.15"],
	["armor_and_hp_bonus_by_tier", "rock", 4, "armor", 2.0, "armor_bonus=2"],
	["armor_and_hp_bonus_by_tier", "rock", 4, "max_hp", 2.0, "max_hp_bonus=2"],
	["speed_bonus_by_tier", "jousting_lance", 4, "speed", 15.0, "speed_bonus=0.05 × SPEED_PERCENT_BASE(300)"],
	["consumable_heal_bonus_by_tier", "chopper", 4, "consumable_heal_bonus", 2.0, "consumable_heal_bonus=2"],
	["consumable_heal_bonus_by_tier", "chopper", 1, "consumable_heal_bonus", 1.0, "consumable_heal_bonus=1"],
	# Hammer 的 tiers 只有 2/3/4，没有 tier 1
	["flat_knockback_bonus", "hammer", 2, "knockback_bonus", 2.0, "knockback_bonus=2"],
	["flat_knockback_bonus", "hammer", 4, "knockback_bonus", 6.0, "knockback_bonus=6"],
]

var failures: Array[String] = []
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

	_check_equip_and_unequip_roundtrip()
	_check_tier_scaling()
	_check_per_weapon_scaling()
	_check_refresh_is_idempotent()
	_check_always_crit_burning_targets()
	_check_lifesteal_per_missing_health()

	if is_instance_valid(player):
		player.queue_free()
	player = null

	_report()


func _report():
	if failures.is_empty():
		print(PASS_TAG)
		quit(0)
		return
	print("%s: %d 项断言失败" % [FAIL_TAG, failures.size()])
	for i in range(min(failures.size(), MAX_PRINTED_FAILURES)):
		print("  - %s" % failures[i])
	if failures.size() > MAX_PRINTED_FAILURES:
		print("  ... 其余 %d 项同类失败已省略" % (failures.size() - MAX_PRINTED_FAILURES))
	push_error("%s: %d failures" % [FAIL_TAG, failures.size()])
	quit(1)


func _clear_weapons():
	# 从「无武器」基线开始，避免角色的初始武器干扰「每把武器」类计数
	player.equipped_weapons.clear()
	player.combat.emit_weapons_changed()


func _check_equip_and_unequip_roundtrip():
	for case in CASES:
		var rule = str(case[0])
		var weapon_id = str(case[1])
		var tier = int(case[2])
		var prop = str(case[3])
		var expected = float(case[4])
		var note = str(case[5])

		_clear_weapons()
		var before = player.get(prop)
		if before == null:
			failures.append("Player 不存在属性 %s（规则 %s）" % [prop, rule])
			continue
		if not player.equip_or_combine_weapon(weapon_id, tier):
			failures.append("装备失败：%s T%d（规则 %s）" % [weapon_id, tier, rule])
			continue
		var after_equip = player.get(prop)
		if not is_equal_approx(float(after_equip) - float(before), expected):
			failures.append("%s T%d 应使 %s 变化 %+.2f（%s），实际 %+.2f" % [
				weapon_id, tier, prop, expected, note, float(after_equip) - float(before)
			])

		_clear_weapons()
		var after_remove = player.get(prop)
		if not is_equal_approx(float(after_remove), float(before)):
			failures.append("%s T%d 卸下后 %s 未还原：期望 %.2f，实际 %.2f" % [
				weapon_id, tier, prop, float(before), float(after_remove)
			])


func _check_tier_scaling():
	# 同一把武器的低阶贡献必须小于高阶（防止 tier 数据没被读到）
	_clear_weapons()
	var base = float(player.get("gold_per_wave"))
	player.equip_or_combine_weapon("hand", 1)
	var tier1 = float(player.get("gold_per_wave")) - base
	_clear_weapons()
	player.equip_or_combine_weapon("hand", 4)
	var tier4 = float(player.get("gold_per_wave")) - base
	if not (tier4 > tier1):
		failures.append("Hand 的 tier 4 贡献应大于 tier 1：T1=%+.2f T4=%+.2f" % [tier1, tier4])
	_clear_weapons()


func _check_per_weapon_scaling():
	# Excalibur: armor_penalty_per_weapon = -3，按武器数量缩放
	_clear_weapons()
	var base_armor = float(player.get("armor"))

	player.equip_or_combine_weapon("excalibur", 4)
	var one_weapon = float(player.get("armor")) - base_armor
	if not is_equal_approx(one_weapon, -3.0):
		failures.append("Excalibur 单独装备时应使护甲变化 -3，实际 %+.2f" % one_weapon)

	# 换一把不带护甲贡献的武器凑数量
	player.equip_or_combine_weapon("pistol", 1)
	var two_weapons = float(player.get("armor")) - base_armor
	if not is_equal_approx(two_weapons, -6.0):
		failures.append("两把武器时 Excalibur 应使护甲变化 -6，实际 %+.2f" % two_weapons)

	_clear_weapons()
	if not is_equal_approx(float(player.get("armor")), base_armor):
		failures.append("清空武器后护甲应完全还原：期望 %.2f，实际 %.2f" % [
			base_armor, float(player.get("armor"))
		])


func _check_refresh_is_idempotent():
	_clear_weapons()
	var base = float(player.get("gold_per_wave"))
	player.equip_or_combine_weapon("hand", 4)
	var once = float(player.get("gold_per_wave")) - base
	# 武器集合未变化时重复刷新不得重复累加
	player.combat.emit_weapons_changed()
	player.combat.emit_weapons_changed()
	var thrice = float(player.get("gold_per_wave")) - base
	if not is_equal_approx(once, thrice):
		failures.append("重复触发刷新导致重复累加：首次 %+.2f，三次后 %+.2f" % [once, thrice])
	_clear_weapons()


func _make_enemy(pos: Vector2, burning: bool):
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	# ⚠ 必须先入树再关处理：进树之前调用 set_physics_process 会被忽略
	root.add_child(enemy)
	enemy.setup("normal", 1)
	enemy.position = pos
	if burning:
		enemy.burn_timer = 3.0
	enemy.set_physics_process(false)
	return enemy


func _free_enemy(enemy):
	if enemy != null and is_instance_valid(enemy):
		enemy.queue_free()


func _check_always_crit_burning_targets():
	# Spoon：对燃烧中的目标必定暴击。把暴击率清零以排除随机性。
	_clear_weapons()
	player.crit_chance = 0.0
	if not player.equip_or_combine_weapon("spoon", 1):
		failures.append("装备 Spoon 失败，无法验证 always_crit_burning_targets")
		return
	var weapon = player.equipped_weapons[0]
	var crit_mult = max(1.0, float(player.crit_damage))

	var plain = _make_enemy(Vector2(30, 0), false)
	var burning = _make_enemy(Vector2(50, 0), true)
	var plain_before = int(plain.hp)
	var burning_before = int(burning.hp)
	player.combat._fire_melee(weapon, [plain, burning])
	var plain_dmg = plain_before - int(plain.hp)
	var burning_dmg = burning_before - int(burning.hp)

	if plain_dmg <= 0:
		failures.append("Spoon 对普通目标未造成伤害，无法比对暴击行为")
	elif burning_dmg <= plain_dmg:
		failures.append("Spoon 对燃烧目标应必定暴击：普通目标 %d 伤害，燃烧目标 %d 伤害" % [plain_dmg, burning_dmg])
	elif burning_dmg != int(plain_dmg * crit_mult):
		failures.append("Spoon 对燃烧目标的伤害应为普通命中的 %.1f 倍：普通 %d，燃烧 %d" % [
			crit_mult, plain_dmg, burning_dmg
		])

	_free_enemy(plain)
	_free_enemy(burning)
	_clear_weapons()


func _check_lifesteal_per_missing_health():
	# Sharp Tooth：每满一个 step 的缺失生命提供 +1% 生命偷取。
	# 玩家基础 lifesteal 为 0，因此任何回复都来自该规则。
	_clear_weapons()
	player.crit_chance = 0.0
	if not player.equip_or_combine_weapon("sharp_tooth", 4):
		failures.append("装备 Sharp Tooth 失败，无法验证 lifesteal_per_missing_health")
		return
	var weapon = player.equipped_weapons[0]
	var step = float(weapon.data.get("missing_health_lifesteal_step", 25.0))
	if step <= 0.0:
		failures.append("Sharp Tooth T4 应带 missing_health_lifesteal_step 数据")
		return

	# 情形一：满血 → 缺失为 0 → 不应有任何额外回复
	player.max_hp = 1005
	player.hp = player.max_hp
	var full_hp_enemy = _make_enemy(Vector2(30, 0), false)
	var full_before = float(player.hp)
	player.combat._fire_melee(weapon, [full_hp_enemy])
	var full_heal = float(player.hp) - full_before
	if full_heal > 0.5:
		failures.append("满血时 Sharp Tooth 不应额外回复生命，实际回复 %.2f" % full_heal)
	_free_enemy(full_hp_enemy)

	# 情形二：缺失 1000 点 → 1000/step 段 → 额外生命偷取 = 段数 × 1%
	player.hp = 5.0
	var hurt_enemy = _make_enemy(Vector2(30, 0), false)
	var hurt_before = float(player.hp)
	var enemy_before = int(hurt_enemy.hp)
	player.combat._fire_melee(weapon, [hurt_enemy])
	var healed = float(player.hp) - hurt_before
	var dealt = enemy_before - int(hurt_enemy.hp)
	var expected = float(dealt) * floor(1000.0 / step) * 0.01
	if dealt <= 0:
		failures.append("Sharp Tooth 未造成伤害，无法验证缺失生命加成")
	elif absf(healed - expected) > 1.0:
		failures.append("缺失生命加成回复量不符：期望约 %.2f（%d 伤害 × %d 段 × 1%%），实际 %.2f" % [
			expected, dealt, int(floor(1000.0 / step)), healed
		])
	_free_enemy(hurt_enemy)
	_clear_weapons()
