# PlayerCombat.gd — 武器系统、暴击/吸血计算、射击
class_name PlayerCombat
extends RefCounted

var p: CharacterBody2D
var WEAPON_DATA: Dictionary = {}

# DetectArea 缓存
var _cached_enemies: Array = []
var _detect_cache_timer: float = 0.0

# 武器特殊规则运行时状态。key = weapon.runtime_id
var _weapon_state: Dictionary = {}
var _next_runtime_id: int = 1

# ─── 武器持有期属性贡献 ───
# 一部分武器规则的效果是「只要装备着就提供某属性」（如 Hand 提供收获、Hammer 提供击退）。
# 规则名 → [目录属性名, 武器分阶数据里的取值键, 是否按武器数量缩放]。
# 属性名必须能被 PlayerUpgrades._apply_catalog_stat_delta 处理（与 items 走同一套应用器）。
const WEAPON_STAT_CONTRIBUTIONS := {
	"harvesting_by_tier": [["harvesting", "harvesting_bonus", false]],
	"xp_gain_by_tier": [["xp_gain_percent", "xp_gain", false]],
	"armor_and_hp_bonus_by_tier": [["armor", "armor_bonus", false], ["max_hp", "max_hp_bonus", false]],
	"speed_bonus_by_tier": [["speed_percent", "speed_bonus", false]],
	"consumable_heal_bonus_by_tier": [["consumable_heal", "consumable_heal_bonus", false]],
	"flat_knockback_bonus": [["knockback", "knockback_bonus", false]],
	"armor_penalty_per_weapon": [["armor", "armor_penalty_per_weapon", true]],
}

# 当前已应用到玩家身上的武器贡献总量（属性名 → 数值），用于计算差量、保证幂等
var _applied_weapon_contributions: Dictionary = {}

# Sharp Tooth：每满一个 missing_health_lifesteal_step 的缺失生命，命中时额外获得的生命偷取比例
const MISSING_HEALTH_LIFESTEAL_PER_STEP := 0.01

# 需要按「本波击杀数」累积的规则：任意一条存在就要维护 kills_this_wave 计数
const KILL_TRACKING_RULES := [
	"damage_growth_per_kills_this_wave",
	"attack_speed_growth_per_kills_this_wave",
	"max_hp_growth_per_kills_this_wave",
]

func _get_weapon_state(weapon: Dictionary) -> Dictionary:
	var id = int(weapon.get("runtime_id", 0))
	if id == 0:
		id = _next_runtime_id
		_next_runtime_id += 1
		weapon["runtime_id"] = id
	if not _weapon_state.has(id):
		_weapon_state[id] = {}
	return _weapon_state[id]

func _has_rule(weapon: Dictionary, rule: String) -> bool:
	for r in weapon.data.get("special_rules", []):
		if r is Dictionary and r.get("rule", "") == rule:
			return true
	return false

func _get_rule(weapon: Dictionary, rule: String) -> Dictionary:
	for r in weapon.data.get("special_rules", []):
		if r is Dictionary and r.get("rule", "") == rule:
			return r
	return {}

func _rule_value(weapon: Dictionary, rule: String, key: String, default = null):
	var r = _get_rule(weapon, rule)
	if r.has(key):
		return r[key]
	# Fall back to tier data field
	var tier_field = key
	if weapon.data.has(tier_field):
		return weapon.data[tier_field]
	return default

func _on_weapon_removed(weapon: Dictionary):
	var id = int(weapon.get("runtime_id", 0))
	if id != 0 and _weapon_state.has(id):
		_weapon_state.erase(id)

func _is_burning(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var timer = enemy.get("burn_timer")
	return timer != null and float(timer) > 0.0

func init(player: CharacterBody2D):
	p = player
	var _db := load("res://data/weapons.tres") as WeaponDatabase
	if _db:
		WEAPON_DATA = _db.to_combat_dict()
	var catalog_data = WeaponDatabase.catalog_combat_dict(true)
	for weapon_type in catalog_data:
		WEAPON_DATA[weapon_type] = catalog_data[weapon_type]

func _make_weapon(type: String, tier: int = 1) -> Dictionary:
	var source: Dictionary = WEAPON_DATA[type]
	var minimum_tier = int(source.get("minimum_tier", 1))
	var weapon_tier = clamp(tier, minimum_tier, 4)
	var catalog_tiers: Dictionary = source.get("catalog_tiers", {})
	# 两条数据来源，行为不同：
	#   - catalog 路径（weapons.json 经 BrotatoData.get_combat_dict）必定带 catalog_tiers，
	#     且必定覆盖 minimum_tier..4。
	#   - legacy 路径（weapons.tres 经 _db.to_combat_dict）**不生成** catalog_tiers，
	#     例如 boomerang 只存在于 weapons.tres，其 catalog_tiers 恒为空。
	# 因此下面这个 else 分支不是死代码 —— 删它会让 legacy 武器拿不到任何 tier 数值。
	# （曾误判为死代码并删除，phase2_loot_weapon_smoke 立刻炸出，已回滚。）
	var weapon: Dictionary
	if catalog_tiers.has(str(weapon_tier)):
		var tier_data: Dictionary = catalog_tiers[str(weapon_tier)].duplicate(true)
		weapon = {"type": type, "timer": 0.0, "data": tier_data, "level": weapon_tier, "tier": weapon_tier}
	else:
		var data = source.duplicate(true)
		_apply_tier_stats(data, weapon_tier)
		weapon = {"type": type, "timer": 0.0, "data": data, "level": weapon_tier, "tier": weapon_tier}
	weapon["runtime_id"] = _next_runtime_id
	_next_runtime_id += 1
	_weapon_state[weapon["runtime_id"]] = {}
	return weapon

func _apply_tier_stats(data: Dictionary, tier: int):
	var level = clamp(tier, 1, 4)
	var damage_mult = [1.0, 1.45, 2.05, 2.85][level - 1]
	var fire_rate_mult = [1.0, 1.10, 1.22, 1.35][level - 1]
	data.damage = max(1, int(round(data.damage * damage_mult)))
	data.fire_rate *= fire_rate_mult
	if level >= 3:
		if data.get("melee", false):
			data.melee_radius = int(data.get("melee_radius", 80) * 1.25)
		elif not data.has("pierce"):
			# 目录未给出 pierce 的远程武器，T3 起获得基础穿透（沿用原有设计意图）。
			# 若目录已给出 {count, damage_multiplier}，则必须以目录为准 —— 早先这里是无条件
			# 覆写，会把 T3/T4 的穿透字典整个冲掉。
			data["pierce"] = true
	if level >= 4:
		data.color = Color(1.0, 0.85, 0.0)

func _find_combine_partner(type: String, tier: int, ignore_index: int = -1) -> int:
	if tier >= 4:
		return -1
	for i in range(p.equipped_weapons.size()):
		if i == ignore_index:
			continue
		var weapon = p.equipped_weapons[i]
		if weapon.type == type and int(weapon.get("tier", weapon.get("level", 1))) == tier:
			return i
	return -1

func _weapon_upgrades_locked() -> bool:
	return p.get("weapon_upgrade_locked_sources") != null and int(p.get("weapon_upgrade_locked_sources")) > 0

func equip_weapon(type):
	equip_or_combine_weapon(type, 1)

func can_equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	if not WEAPON_DATA.has(type):
		return false
	var minimum_tier = int(WEAPON_DATA[type].get("minimum_tier", 1))
	var weapon_tier = clamp(tier, minimum_tier, 4)
	if not _weapon_upgrades_locked() and _find_combine_partner(type, weapon_tier) != -1:
		return true
	return p.equipped_weapons.size() < p.get_max_weapon_slots()

func equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	if not WEAPON_DATA.has(type):
		return false
	var minimum_tier = int(WEAPON_DATA[type].get("minimum_tier", 1))
	var weapon_tier = clamp(tier, minimum_tier, 4)
	var partner_index = _find_combine_partner(type, weapon_tier)
	if not _weapon_upgrades_locked() and partner_index != -1:
		p.equipped_weapons[partner_index] = _make_weapon(type, weapon_tier + 1)
		emit_weapons_changed()
		p.upgrades.check_synergies()
		return true
	if p.equipped_weapons.size() >= p.get_max_weapon_slots():
		return false
	p.equipped_weapons.append(_make_weapon(type, weapon_tier))
	emit_weapons_changed()
	p.upgrades.check_synergies()
	return true

func emit_weapons_changed():
	p.weapons_changed.emit(p.equipped_weapons.map(func(w):
		var tier = int(w.get("tier", w.get("level", 1)))
		var prefix = "★" if tier >= 4 else ""
		return "%s%s T%d" % [prefix, w.data.name, tier]
	))
	if p.has_method("recalculate_distinct_weapon_scaling"):
		p.recalculate_distinct_weapon_scaling()
	# 武器集合变了，持有期属性贡献必须重算。这里是所有增删路径（装备/合成/移除）的唯一收敛点，
	# 因此用「目标值 vs 已应用值」的差量方式实现，重复调用是幂等的。
	_refresh_weapon_contributions()

func _refresh_weapon_contributions():
	if p == null or not is_instance_valid(p):
		return
	var upgrades = p.get("upgrades")
	if upgrades == null or not upgrades.has_method("apply_catalog_rule_effects"):
		return
	var weapon_count = p.equipped_weapons.size()
	var desired: Dictionary = {}
	for weapon in p.equipped_weapons:
		for effect in _weapon_contribution_effects(weapon, weapon_count):
			var stat = str(effect.stat)
			var total = float(desired.get(stat, 0.0)) + float(effect.value)
			if is_zero_approx(total):
				desired.erase(stat)
			else:
				desired[stat] = total
	# 取「目标」与「已应用」的并集：卸下武器后目标里不再出现该属性，也必须把已应用的量撤掉
	var stats: Dictionary = {}
	for stat in desired:
		stats[stat] = true
	for stat in _applied_weapon_contributions:
		stats[stat] = true
	for stat in stats:
		var delta = float(desired.get(stat, 0.0)) - float(_applied_weapon_contributions.get(stat, 0.0))
		if is_zero_approx(delta):
			continue
		# 沿用物品系统的约定：direction 承载增减语义，value 传绝对值
		upgrades.apply_catalog_rule_effects([
			{"effect": "stat_delta", "stat": stat, "value": absf(delta)},
		], 1.0 if delta > 0.0 else -1.0)
	_applied_weapon_contributions = desired

func _weapon_contribution_effects(weapon: Dictionary, weapon_count: int) -> Array:
	var effects: Array = []
	for rule in WEAPON_STAT_CONTRIBUTIONS:
		if not _has_rule(weapon, rule):
			continue
		for entry in WEAPON_STAT_CONTRIBUTIONS[rule]:
			var value = float(weapon.data.get(str(entry[1]), 0.0))
			if is_zero_approx(value):
				continue
			if bool(entry[2]):
				# 「每把武器」类规则：Excalibur 的 -3 护甲按当前武器数放大
				value *= float(max(1, weapon_count))
			effects.append({"stat": str(entry[0]), "value": value})
	return effects

func upgrade_weapon(slot_index: int) -> bool:
	return combine_weapon(slot_index)

func can_combine_weapon(slot_index: int) -> bool:
	if _weapon_upgrades_locked():
		return false
	if slot_index < 0 or slot_index >= p.equipped_weapons.size():
		return false
	var weapon = p.equipped_weapons[slot_index]
	var tier = int(weapon.get("tier", weapon.get("level", 1)))
	return _find_combine_partner(weapon.type, tier, slot_index) != -1

func combine_weapon(slot_index: int) -> bool:
	if not can_combine_weapon(slot_index):
		return false
	var weapon = p.equipped_weapons[slot_index]
	var tier = int(weapon.get("tier", weapon.get("level", 1)))
	var partner_index = _find_combine_partner(weapon.type, tier, slot_index)
	var keep_index = min(slot_index, partner_index)
	var remove_index = max(slot_index, partner_index)
	_on_weapon_removed(p.equipped_weapons[remove_index])
	p.equipped_weapons[keep_index] = _make_weapon(weapon.type, tier + 1)
	p.equipped_weapons.remove_at(remove_index)
	emit_weapons_changed()
	p.upgrades.check_synergies()
	if p.has_node("/root/AudioManager"):
		p.get_node("/root/AudioManager").play_level_up()
	return true

# 武器信息快照。**这是 UI（商店武器卡 / tooltip / HUD 武器栏）唯一的数据源。**
#
# 契约：
#   * 数组下标 `i` 必须与 `p.equipped_weapons` 下标严格一致 —— `slot_index` 就是 `i`。
#     商店的武器卡按下标操作、拖拽合成靠它定位、出售靠它精确命中格子。
#     **任何过滤/排序都不许在这里做**：一旦跳过某项，下标就和真实槽位错位，
#     下游会把「第 2 张卡」当成「第 2 个槽位」。要过滤请在消费端过滤。
#   * 既有字段一个都不删、不改语义（`name`/`type`/`level`/`tier`/`damage`/
#     `fire_rate`/`can_combine`/`max_level`），Shop.gd 与测试都在读它们。
#   * 新增字段都是**从 weapon.data 原样透出**，不做二次换算 ——
#     单位语义由 data 决定（如 `crit_chance` 是分数、`spread` 是角度）。
#     渲染方要百分比就自己 ×100，别在这里偷偷转。
func get_weapon_info() -> Array:
	var info = []
	for i in range(p.equipped_weapons.size()):
		var w = p.equipped_weapons[i]
		var tier = int(w.get("tier", w.get("level", 1)))
		info.append({
			"name": w.data.name,
			"type": w.type,
			"level": tier,
			"tier": tier,
			"damage": w.data.damage,
			"fire_rate": w.data.fire_rate,
			"can_combine": can_combine_weapon(i),
			"max_level": tier >= 4,
			# ─── A4' 生产端：槽位下标 ───
			# 与 `i` 恒等。`remove_upgrade` 的第一优先级判据就是它，
			# 有了它才能在同类型同分阶的多把武器里精确命中要卖的那把。
			"slot_index": i,
			# ─── B3：完整 tooltip 所需字段 ───
			# 近战/远程用 `melee` 区分渲染分支（近战没有射程/弹道，看的是挥击半径）。
			"melee": bool(w.data.get("melee", false)),
			"range": float(w.data.get("range", 0.0)),
			"melee_radius": float(w.data.get("melee_radius", 0.0)),
			"crit_chance": p.crit_chance,
			"crit_damage": p.crit_damage,
			# 当前实际冷却（秒）。含攻速加成、武器特殊规则、最小冷却下限 ——
			# 是玩家真正感受得到的那个数，比裸 fire_rate 更有信息量。
			"cooldown": _cooldown_for_weapon(w),
			"projectile_count": int(w.data.get("count", 1)),
			"spread": float(w.data.get("spread", 0.0)),
			"pierce": _weapon_pierce_summary(w),
			"bounces": _weapon_bounce_summary(w),
			"special_rules": _weapon_rule_names(w),
			# 渲染用颜色。零美术资产约定下，这就是「图标」的底色。
			"color": w.data.get("color", Color(0.8, 0.8, 0.8)),
			# 稀有度风格的分阶色，与 BrotatoData._tier_color 同源语义。
			"tier_color": _tier_color(tier),
		})
	return info

# 分阶配色。与 BrotatoData 的 tier 色系保持一致的观感（白/绿/蓝/紫/金），
# 但这里是**独立实现**：PlayerCombat 不该在运行时反查 BrotatoData（那是数据加载层）。
func _tier_color(tier: int) -> Color:
	match clamp(tier, 1, 4):
		1: return Color(0.85, 0.85, 0.85)
		2: return Color(0.40, 0.90, 0.45)
		3: return Color(0.40, 0.70, 1.00)
		_: return Color(1.00, 0.75, 0.20)


# 穿透摘要：统一成 {count:int, full:bool}。
# 目录里 pierce 有三种形态（Dictionary / true / 缺失），消费端不该各自解析一遍。
func _weapon_pierce_summary(weapon: Dictionary) -> Dictionary:
	if _has_rule(weapon, "full_pierce"):
		return {"count": 999, "full": true}
	var pierce_data = weapon.data.get("pierce", null)
	var extra := 0
	if pierce_data is Dictionary:
		extra = max(0, int(pierce_data.get("count", 0)))
	elif pierce_data == true:
		extra = 2  # 旧布尔写法：历史上按 3 次命中处理
	return {"count": extra, "full": false}


# 弹跳摘要：与 _fire_ranged 的算法同源，但**不含**每发暴击才触发的部分
# （那依赖单发结果，tooltip 表达不了）。读的是「常态可得」的弹跳数。
func _weapon_bounce_summary(weapon: Dictionary) -> int:
	if _has_rule(weapon, "cannot_bounce"):
		return 0
	var bounces := 0
	if _has_rule(weapon, "bounce_by_tier"):
		bounces = max(0, int(weapon.data.get("bounces", 0)))
	elif _has_rule(weapon, "bounce_once"):
		bounces = 1
	return bounces + max(0, int(p.projectile_bounce_bonus))


# 特殊规则名列表。tooltip 用它显示「特性」段，也让测试能断言规则确实挂上了。
func _weapon_rule_names(weapon: Dictionary) -> Array:
	var out: Array = []
	for rule in weapon.data.get("special_rules", []):
		if rule is Dictionary:
			var rule_id = str(rule.get("rule", ""))
			if rule_id != "":
				out.append(rule_id)
	return out

func _damage_for_weapon(weapon: Dictionary, target = null) -> int:
	var dmg = float(weapon.data.damage + p.damage_bonus + p.passive_bonus_damage)
	if weapon.data.get("melee", false):
		dmg += float(p.melee_damage_bonus)
	else:
		dmg += float(p.ranged_damage_bonus)
	if p.get("curse_weapon_damage_scaling_coefficient") != null:
		dmg += float(p.curse) * float(p.curse_weapon_damage_scaling_coefficient)
	# Weapon special rules: damage modifiers
	if target != null and is_instance_valid(target):
		if _has_rule(weapon, "bonus_damage_against_low_health"):
			var threshold = float(weapon.data.get("low_health_threshold", 0.5))
			if target.hp <= target.max_hp * threshold:
				dmg += float(weapon.data.get("low_health_damage_bonus", 0))
	if _has_rule(weapon, "current_health_bonus_damage"):
		var coeff = float(weapon.data.get("current_health_bonus_damage", 0))
		if coeff > 0:
			var elite_boss_coeff = float(weapon.data.get("elite_boss_current_health_bonus_damage", coeff))
			var is_boss_or_elite = target != null and is_instance_valid(target) and (target.get("enemy_type") in ["boss", "miniboss"] or target.get("is_elite", false))
			var use_coeff = elite_boss_coeff if is_boss_or_elite else coeff
			dmg += float(p.hp) * use_coeff
	if _has_rule(weapon, "bonus_damage_per_free_weapon_slot"):
		var free_slots = max(0, p.get_max_weapon_slots() - p.equipped_weapons.size())
		dmg += float(weapon.data.get("damage_per_free_slot", 0)) * free_slots
	if _has_rule(weapon, "bonus_damage_above_health_threshold"):
		var threshold = float(weapon.data.get("health_threshold", 0.5))
		if float(p.hp) / max(1, float(p.max_hp)) >= threshold:
			dmg += float(weapon.data.get("above_threshold_damage_bonus", 0))
	if _has_rule(weapon, "bonus_damage_for_duplicate_sticks"):
		var stick_count = 0
		for w in p.equipped_weapons:
			if w.type == "stick":
				stick_count += 1
		if stick_count >= 2:
			dmg += float(weapon.data.get("duplicate_stick_damage_bonus", 0)) * stick_count
	# Stacking growth rules
	if _has_rule(weapon, "damage_growth_per_kills_this_wave"):
		var state = _get_weapon_state(weapon)
		var kills = int(state.get("kills_this_wave", 0))
		dmg += float(weapon.data.get("damage_growth_per_kill", 0)) * kills
	if _has_rule(weapon, "damage_growth_when_damaged_this_wave"):
		var state = _get_weapon_state(weapon)
		var times = int(state.get("self_damage_times", 0))
		dmg += float(weapon.data.get("damage_growth_on_self_damage", 0)) * times
	if _has_rule(weapon, "damage_charges_until_hit"):
		var state = _get_weapon_state(weapon)
		var bonus = float(state.get("charged_damage_bonus", 0.0))
		if bonus > 0:
			dmg += bonus
	dmg *= max(0.0, 1.0 + float(p.damage_percent_bonus))
	# Jousting Lance：原地站定时伤害下降。判定方式与既有的 stand_still 物品一致
	# （Player.update_stand_still_item_bonuses 也用 velocity.length_squared() <= 0.01）。
	# 这里按「开火瞬间」计算，不做状态记录，因此天然可逆。
	if _has_rule(weapon, "damage_penalty_while_standing_still"):
		if p.velocity.length_squared() <= 0.01:
			dmg *= max(0.0, 1.0 + float(weapon.data.get("standing_still_damage_penalty", 0.0)))
	return max(1, int(round(dmg)))

func _refresh_enemy_cache(delta):
	_detect_cache_timer += delta
	if _detect_cache_timer < 0.1:
		return
	_detect_cache_timer = 0.0
	# ⚠ `get_overlapping_bodies()` 报的是**物理重叠**，与 `enemies` 分组无关。
	# 而 `Enemy.recycle()` 只把池实例移出分组、**并没有关掉碰撞层**，
	# 所以池里的隐形实例照样会被这个 Area2D 扫到。不过滤的后果有两个，都在实机出现过：
	#   ① 最近的「敌人」是个隐形池实例 → 子弹朝看不见的地方打，或因为它超出射程而**根本不开火**
	#      （症状：玩家移动时像是无法射击）；
	#   ② 近战（走的就是这份缓存，且不做分组过滤）会把已经 hp<=0 的池实例**再打死一次**，
	#      凭空掉落经验球（症状：击杀不可见物体掉经验）。
	# 因此这里按「活的敌人」二次过滤，与炮台 / AoE / 小地图的既有判据保持一致（都以分组为准）。
	_cached_enemies.clear()
	for body in p.get_node("DetectArea").get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if not body.is_in_group("enemies"):
			continue
		if not body.visible:
			continue
		if int(body.get("hp")) <= 0:
			continue
		_cached_enemies.append(body)

# 近战范围环：取当前所有近战武器中最远的那个范围。
# 近战判定是「半径内的所有敌人」、不分方向，所以用整圈如实表达。
# 每帧重算，因此换武器 / 吃到范围加成立刻反映到环上，不需要额外 UI。
func update_melee_indicator():
	if not p.has_method("set_melee_reach"):
		return
	var reach := 0.0
	for weapon in p.equipped_weapons:
		if not weapon.data.get("melee", false):
			continue
		var r := float(weapon.data.get("melee_radius", 80)) + float(p.range_bonus)
		# 扫击武器有 1.6× 的扫击帧，取外沿作为显示范围，与 _fire_melee 的算法一致
		if _has_rule(weapon, "alternate_thrust_and_sweep"):
			r *= 1.6
		reach = max(reach, r)
	p.set_melee_reach(reach)

func process_weapons(delta):
	_refresh_enemy_cache(delta)
	for weapon in p.equipped_weapons:
		_process_weapon_state(weapon, delta)
		weapon.timer -= delta
		if weapon.timer <= 0:
			weapon.timer = _cooldown_for_weapon(weapon)
			fire_weapon(weapon)

func _process_weapon_state(weapon: Dictionary, delta: float):
	if _has_rule(weapon, "attack_speed_growth_over_wave"):
		var interval = float(weapon.data.get("attack_speed_growth_interval", 1.0))
		if interval > 0:
			var state = _get_weapon_state(weapon)
			state["attack_speed_growth_time"] = float(state.get("attack_speed_growth_time", 0.0)) + delta
			while state["attack_speed_growth_time"] >= interval:
				state["attack_speed_growth_time"] -= interval
				state["attack_speed_growth_stacks"] = int(state.get("attack_speed_growth_stacks", 0)) + 1
	if _has_rule(weapon, "damage_charges_until_hit"):
		var state = _get_weapon_state(weapon)
		state["charge_time"] = float(state.get("charge_time", 0.0)) + delta
	if _has_rule(weapon, "self_damage_over_time"):
		var state = _get_weapon_state(weapon)
		state["self_damage_time"] = float(state.get("self_damage_time", 0.0)) + delta
		var interval = 1.0
		while state["self_damage_time"] >= interval:
			state["self_damage_time"] -= interval
			var dps = float(weapon.data.get("self_damage_per_second", 0))
			if dps > 0 and p.has_method("take_damage"):
				p.take_damage(max(1, int(round(dps))))
				var s = _get_weapon_state(weapon)
				s["self_damage_times"] = int(s.get("self_damage_times", 0)) + 1
	# Screwdriver：按目录间隔周期埋雷（T1 12s → T4 3s）。
	# 计时器初值为 0，因此装上后第一次更新就会先埋一颗，随后按间隔循环。
	if _has_rule(weapon, "spawn_landmine_by_tier"):
		var mine_interval = float(weapon.data.get("mine_spawn_interval", 12.0))
		if mine_interval > 0.0:
			var state = _get_weapon_state(weapon)
			var mine_timer = float(state.get("mine_spawn_timer", 0.0)) - delta
			while mine_timer <= 0.0:
				_spawn_weapon_landmine(weapon)
				mine_timer += mine_interval
			state["mine_spawn_timer"] = mine_timer
	# Pruner：按目录间隔周期结出花园（T1 15s → T4 10s）
	if _has_rule(weapon, "spawn_fruit_garden"):
		var garden_interval = float(weapon.data.get("garden_fruit_interval", 15.0))
		if garden_interval > 0.0:
			var state = _get_weapon_state(weapon)
			var garden_timer = float(state.get("garden_spawn_timer", 0.0)) - delta
			while garden_timer <= 0.0:
				_spawn_weapon_garden(weapon)
				garden_timer += garden_interval
			state["garden_spawn_timer"] = garden_timer

func _cooldown_for_weapon(weapon: Dictionary) -> float:
	var fire_rate = float(weapon.data.fire_rate)
	# Wave-tick growth rules (Drill etc.)
	if _has_rule(weapon, "attack_speed_growth_over_wave"):
		var state = _get_weapon_state(weapon)
		var stacks = int(state.get("attack_speed_growth_stacks", 0))
		var growth_per_stack = float(weapon.data.get("attack_speed_growth", 0.01))
		fire_rate *= max(0.1, 1.0 + growth_per_stack * stacks)
	# Ghost Flint：本波每 N 次击杀提升攻速。按击杀数即时计算（不改动玩家属性），
	# 因此波末 kills_this_wave 归零后加成自动消失，无需回滚状态。
	# ⚠ 必须放在 raw_cooldown 计算之前：这里改的是 fire_rate。
	if _has_rule(weapon, "attack_speed_growth_per_kills_this_wave"):
		var state = _get_weapon_state(weapon)
		var kills = int(state.get("kills_this_wave", 0))
		var kill_interval = int(weapon.data.get("attack_speed_growth_kill_interval", 0))
		var growth_per_step = float(weapon.data.get("attack_speed_growth", 0.01))
		if kill_interval > 0:
			fire_rate *= max(0.1, 1.0 + growth_per_step * float(kills / kill_interval))
	# Cooldown penalties
	if _has_rule(weapon, "attack_speed_penalty"):
		fire_rate *= max(0.1, 1.0 - float(weapon.data.get("attack_speed_penalty_percent", 0.0)))
	var raw_cooldown = 1.0 / max(0.01, fire_rate * float(p.fire_rate_multiplier))
	# Revolver: every 6th shot has a longer cooldown
	if _has_rule(weapon, "sixth_shot_longer_cooldown"):
		var state = _get_weapon_state(weapon)
		var shots = int(state.get("shots_fired", 0))
		if (shots + 1) % 6 == 0:
			raw_cooldown *= max(1.0, float(weapon.data.get("sixth_shot_cooldown_multiplier", 2.0)))
	# Chain Gun：每 N 发后追加一次较长冷却。本函数在 fire_weapon 之前调用，
	# 所以用 (shots + 1) 判断「即将打出的这一发」，与 sixth_shot_longer_cooldown 的既有写法一致。
	if _has_rule(weapon, "cooldown_every_100_shots"):
		var state = _get_weapon_state(weapon)
		var shots = int(state.get("shots_fired", 0))
		var shot_interval = int(weapon.data.get("cooldown_every_shots", 100))
		if shot_interval > 0 and (shots + 1) % shot_interval == 0:
			raw_cooldown += max(0.0, float(weapon.data.get("reload_cooldown", 0.0)))
	# Chainsaw: reload every N attacks
	if _has_rule(weapon, "reload_every_n_attacks_by_tier"):
		var state = _get_weapon_state(weapon)
		var attacks = int(state.get("attacks_since_reload", 0))
		var interval = int(weapon.data.get("reload_interval", 10))
		if interval > 0 and attacks > 0 and attacks % interval == 0:
			raw_cooldown += max(0.0, float(weapon.data.get("reload_cooldown", 0.5)))
	if p.get("weapon_minimum_cooldown") != null:
		return max(raw_cooldown, float(p.weapon_minimum_cooldown))
	return raw_cooldown

func fire_weapon(weapon):
	var nearby = _cached_enemies
	if nearby.is_empty():
		return
	var nearest = null
	var nearest_dist = INF
	for enemy in nearby:
		var d = p.position.distance_to(enemy.position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	if nearest == null:
		return

	# Track fire-event state for cooldown rules
	var state = _get_weapon_state(weapon)
	state["shots_fired"] = int(state.get("shots_fired", 0)) + 1
	state["attacks_since_reload"] = int(state.get("attacks_since_reload", 0)) + 1

	# Melee branch
	if weapon.data.get("melee", false):
		_fire_melee(weapon, nearby)
		return

	# Ranged branch
	if weapon.data.has("range") and nearest_dist > float(weapon.data.range) + float(p.range_bonus):
		return

	_fire_ranged(weapon, nearest, nearby)

func _apply_passive_damage_mods(dmg: int) -> int:
	if p.revenge_bonus and p.hp < p.max_hp * 0.3:
		dmg = int(dmg * 1.5)
	if p.character_passive == "warrior" and p.passive_active:
		dmg = int(dmg * 1.3)
	if p.character_passive == "berserker":
		dmg += p.berserker_hp_bonus
	return dmg

func _fire_melee(weapon: Dictionary, nearby: Array):
	if p.has_node("/root/AudioManager"):
		p.get_node("/root/AudioManager").play_shoot()
	# 每次挥击触发一次的附加行为（与命中敌人数无关）
	_apply_melee_attack_effects(weapon)
	var base_radius = float(weapon.data.get("melee_radius", 80)) + float(p.range_bonus)
	var sweep = _has_rule(weapon, "alternate_thrust_and_sweep")
	var state = _get_weapon_state(weapon)
	var is_sweep = false
	if sweep:
		is_sweep = bool(state.get("melee_is_sweep", false))
		state["melee_is_sweep"] = not is_sweep
	var melee_r = base_radius
	if sweep and is_sweep:
		melee_r *= 1.6
	elif sweep and not is_sweep:
		melee_r *= 0.6
	melee_r = max(1.0, melee_r)

	# 挥击可视化：朝最近的目标亮一条弧。近战此前完全没有视觉反馈，
	# 打没打、多久一下都看不出来（远程至少有子弹）。
	if p.has_method("show_melee_swing"):
		var aim := Vector2.RIGHT
		if not nearby.is_empty() and is_instance_valid(nearby[0]):
			aim = (nearby[0].position - p.position).normalized()
		p.show_melee_swing(melee_r, weapon.data.color, aim, sweep and is_sweep)

	for enemy in nearby:
		if p.position.distance_to(enemy.position) > melee_r:
			continue
		var hit_dmg = _damage_for_weapon(weapon, enemy)
		hit_dmg = _apply_passive_damage_mods(hit_dmg)
		var p_is_crit = false
		if _has_rule(weapon, "always_crit_burning_targets") and _is_burning(enemy):
			# Spoon：对燃烧中的目标必定暴击（不再走随机）
			p_is_crit = true
			hit_dmg = int(hit_dmg * p.crit_damage)
		elif p.crit_chance > 0 and randf() < p.crit_chance:
			hit_dmg = int(hit_dmg * p.crit_damage)
			p_is_crit = true
		if p.has_method("modify_damage_against_target"):
			hit_dmg = p.modify_damage_against_target(hit_dmg, enemy, {"is_crit": p_is_crit})
		Effects.hit_spark(enemy.position, weapon.data.color)
		enemy.take_damage(hit_dmg)
		_apply_weapon_hit_effects(weapon, enemy, hit_dmg, p_is_crit)
		if p.has_method("on_enemy_hit_by_attack"):
			p.on_enemy_hit_by_attack(enemy, {"is_crit": p_is_crit, "damage": hit_dmg})
		p.total_damage_dealt += hit_dmg
		if p.lifesteal > 0:
			p.heal(hit_dmg * p.lifesteal)

func _fire_ranged(weapon: Dictionary, nearest, nearby: Array):
	var base_dir = (nearest.position - p.position).normalized()
	var count = int(weapon.data.count)
	if p.get("seashell_projectile_sources") != null and int(p.seashell_projectile_sources) > 0:
		p.seashell_ranged_shot_counter += 1
		if p.seashell_ranged_shot_counter % 5 == 0:
			count += 3 * int(p.seashell_projectile_sources)
	var spread = weapon.data.spread
	var start = -(count - 1) * spread / 2.0

	if p.has_node("/root/AudioManager"):
		p.get_node("/root/AudioManager").play_shoot()

	var main = p.get_parent()
	var use_pool = main.has_method("get_bullet")

	# Rules that affect every projectile
	var full_pierce = _has_rule(weapon, "full_pierce")
	# 目录里 pierce 是 {count, damage_multiplier}：count 是「额外穿透数」，
	# 所以可命中的敌人总数 = count + 1（与 Bullet.pierce_hit_limit 的语义一致）。
	var pierce_data = weapon.data.get("pierce", null)
	var weapon_pierce_extra = 0
	var pierce_damage_multiplier = -1.0
	if pierce_data is Dictionary:
		weapon_pierce_extra = max(0, int(pierce_data.get("count", 0)))
		if pierce_data.has("damage_multiplier"):
			pierce_damage_multiplier = max(0.0, float(pierce_data.get("damage_multiplier")))
	elif pierce_data == true:
		# 兼容旧的布尔写法：历史上布尔穿透一律按 3 次命中处理
		weapon_pierce_extra = 2
	var explode_on_hit = _has_rule(weapon, "projectile_explosion_on_hit")
	var explosion_radius = float(weapon.data.get("explosion_radius", 120.0))
	var explosion_damage_percent = float(weapon.data.get("explosion_damage_percent", 0.5))
	var slow_on_hit = _has_rule(weapon, "slow")
	var slow_factor = float(weapon.data.get("slow_factor", 0.3))
	var slow_duration = float(weapon.data.get("slow_duration", 2.0))
	# 弹跳：武器自带的弹跳次数。bounce_once 的「一次」与 cannot_bounce 的「禁止」
	# 由规则名唯一确定，无需目录取值；bounce_by_tier / critical_hit_bounce 则取自目录。
	var weapon_bounces = 0
	if _has_rule(weapon, "bounce_by_tier"):
		weapon_bounces = max(0, int(weapon.data.get("bounces", 0)))
	elif _has_rule(weapon, "bounce_once"):
		weapon_bounces = 1
	var cannot_bounce = _has_rule(weapon, "cannot_bounce")
	var crit_bounces = 0
	if _has_rule(weapon, "critical_hit_bounce"):
		crit_bounces = max(0, int(weapon.data.get("crit_bounces", 0)))
	var player_bounce_bonus = max(0, int(p.projectile_bounce_bonus))
	# 工程减速：粒子加速器的减速量随工程点数增长（目录给每点系数）
	if _has_rule(weapon, "engineering_based_slow"):
		var per_point = float(weapon.data.get("engineering_slow_per_point", 0.0))
		if per_point > 0.0:
			slow_on_hit = true
			slow_factor = clamp(float(p.engineering_bonus) * per_point, 0.0, 0.9)
	var burn_damage = int(weapon.data.get("burn_damage", 0))
	var burn_instances = int(weapon.data.get("burn_instances", 0))
	var pierce_falloff = _has_rule(weapon, "pierce_falloff")
	var pierce_falloff_percent = float(weapon.data.get("pierce_falloff_percent", -0.25))
	var material_on_crit_kill = _has_rule(weapon, "material_on_critical_kill")
	var material_on_crit_kill_chance = float(weapon.data.get("material_on_crit_kill_chance", 0.0))
	var nth_crit = _has_rule(weapon, "every_nth_projectile_guaranteed_crit")
	var crit_interval = int(weapon.data.get("critical_projectile_interval", 1))
	var state = _get_weapon_state(weapon)

	# Railgun-like charge
	if _has_rule(weapon, "damage_charges_until_hit"):
		var charge_time = float(state.get("charge_time", 0.0))
		state["charge_time"] = 0.0
		# Cap charge at a reasonable maximum (e.g. 2 seconds worth)
		state["charged_damage_bonus"] = min(charge_time, 2.0) * float(weapon.data.get("charge_damage_per_second", 10.0))

	for i in range(count):
		var dmg = _damage_for_weapon(weapon, nearest)
		dmg = _apply_passive_damage_mods(dmg)
		var p_is_crit = false
		if nth_crit and crit_interval > 0:
			state["nth_projectile_counter"] = int(state.get("nth_projectile_counter", 0)) + 1
			if state["nth_projectile_counter"] % crit_interval == 0:
				p_is_crit = true
				dmg = int(dmg * p.crit_damage)
		elif p.crit_chance > 0 and randf() < p.crit_chance:
			dmg = int(dmg * p.crit_damage)
			p_is_crit = true

		var p_splash = bool(weapon.data.get("splash", false))
		var p_splash_radius = float(weapon.data.get("splash_radius", 0))
		if p_splash:
			dmg = max(1, int(round(float(dmg) * max(0.0, 1.0 + float(p.explosion_damage_percent)))))
			p_splash_radius = max(0.0, p_splash_radius * max(0.0, 1.0 + float(p.explosion_size_percent)))

		var base_pierce = weapon_pierce_extra > 0
		var projectile_pierce_bonus = max(0, int(p.projectile_pierce_bonus))
		var p_pierce = base_pierce or projectile_pierce_bonus > 0 or full_pierce
		var p_pierce_hit_limit = 999 if full_pierce else (weapon_pierce_extra + 1 + projectile_pierce_bonus)
		if p_is_crit and p.critical_hit_projectile_pierce_bonus > 0:
			p_pierce = true
			p_pierce_hit_limit += int(p.critical_hit_projectile_pierce_bonus)
		if p.character_passive == "archer":
			p_pierce = true
			p_pierce_hit_limit = max(p_pierce_hit_limit, 3)

		var bullet_color = weapon.data.color
		if p.ammo_type == "fire":
			bullet_color = Color(1.0, 0.4, 0.1)
		elif p.ammo_type == "ice":
			bullet_color = Color(0.4, 0.8, 1.0)
		elif p.ammo_type == "lightning":
			bullet_color = Color(1.0, 1.0, 0.3)

		var dir = base_dir.rotated(deg_to_rad(start + i * spread))
		# Negative knockback: flip direction for harpoon-style pull (placeholder visual)
		if _has_rule(weapon, "negative_knockback_pull"):
			dir = -dir

		# 每发子弹单独算弹跳：crit 依赖本发是否暴击，cannot_bounce 会压过玩家加成
		var projectile_bounces = 0
		if not cannot_bounce:
			projectile_bounces = weapon_bounces + player_bounce_bonus
			if p_is_crit:
				projectile_bounces += crit_bounces

		var b = main.get_bullet() if use_pool else p.bullet_scene.instantiate()
		b.activate(
			p.position,
			dir,
			weapon.data.spd,
			bullet_color,
			p,
			dmg,
			p_is_crit,
			p_pierce,
			p_splash,
			int(round(p_splash_radius)),
			weapon.data.get("returns", false),
			weapon.data.get("gravity", false),
			weapon.data.get("bullet_scale", Vector2(1, 1)),
			false,
			p.ammo_type,
			p_pierce_hit_limit,
			float(p.piercing_damage_percent),
			bool(p.piercing_damage_cap_at_base),
			projectile_bounces,
			burn_damage,
			burn_instances,
			explode_on_hit,
			explosion_radius,
			explosion_damage_percent,
			pierce_falloff,
			pierce_falloff_percent,
			full_pierce,
			slow_on_hit,
			slow_factor,
			slow_duration,
			material_on_crit_kill,
			material_on_crit_kill_chance,
			pierce_damage_multiplier,
			int(weapon.get("runtime_id", 0))
		)
		if not use_pool and not b.get_parent():
			main.add_child(b)

func _apply_weapon_hit_effects(weapon: Dictionary, enemy, hit_dmg: int, is_crit: bool):
	if not is_instance_valid(enemy):
		return
	# Burn
	if _has_rule(weapon, "burn"):
		var burn_dmg = int(weapon.data.get("burn_damage", 1))
		var burn_inst = int(weapon.data.get("burn_instances", 0))
		if enemy.has_method("apply_burn"):
			enemy.apply_burn(p, burn_dmg, burn_inst)
	# Slow
	if _has_rule(weapon, "slow"):
		var factor = float(weapon.data.get("slow_factor", 0.3))
		var duration = float(weapon.data.get("slow_duration", 2.0))
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(factor, duration)
	# Explosion on hit for melee weapons (Plank, Power Fist, etc.)
	if _has_rule(weapon, "melee_hit_explosion_chance"):
		var chance = float(weapon.data.get("explosion_chance", 0.0))
		if chance > 0 and randf() < chance:
			if p.has_method("deal_catalog_explosion"):
				p.deal_catalog_explosion(enemy.position, hit_dmg, float(weapon.data.get("explosion_radius", 120.0)))
	# Melee hit-explosion by tier
	if _has_rule(weapon, "hit_explosion_chance_by_tier"):
		var chance = float(weapon.data.get("hit_explosion_chance", 0.0))
		if chance > 0 and randf() < chance:
			if p.has_method("deal_catalog_explosion"):
				p.deal_catalog_explosion(enemy.position, hit_dmg, float(weapon.data.get("explosion_radius", 150.0)))
	# Burn spread
	if _has_rule(weapon, "burn_spread_by_tier"):
		var chance = float(weapon.data.get("burn_spread", 0.0))
		if chance > 0 and randf() < chance and enemy.has_method("apply_burn"):
			for e in p.get_node("DetectArea").get_overlapping_bodies():
				if e != enemy and is_instance_valid(e) and e.is_in_group("enemies"):
					e.apply_burn(p, int(weapon.data.get("burn_damage", 1)), int(weapon.data.get("burn_instances", 0)))
					break
	# Sharp Tooth：每满一个 step 的缺失生命，本次命中额外获得 +1% 生命偷取
	if _has_rule(weapon, "lifesteal_per_missing_health"):
		var step = float(weapon.data.get("missing_health_lifesteal_step", 25.0))
		if step > 0.0:
			var missing = max(0.0, float(p.max_hp) - float(p.hp))
			var steps = floor(missing / step)
			if steps > 0.0:
				p.heal(float(hit_dmg) * steps * MISSING_HEALTH_LIFESTEAL_PER_STEP)
	# Lute：命中叠加「受到伤害增加」易伤，按数据上限封顶、按持续时间续期。
	# 用「当前值 + 一步」而不是直接叠计数，这样敌人身上的计时器到期后自然归零。
	if _has_rule(weapon, "damage_taken_debuff_on_hit"):
		var step = float(weapon.data.get("damage_taken_bonus", 0.0))
		var cap = float(weapon.data.get("damage_taken_cap", 0.0))
		var duration = float(weapon.data.get("damage_taken_duration", 0.0))
		if step > 0.0 and duration > 0.0 and enemy.has_method("apply_damage_taken_bonus"):
			var current = float(enemy.get("damage_taken_percent_bonus"))
			var next_bonus = current + step
			if cap > 0.0:
				next_bonus = min(cap, next_bonus)
			enemy.apply_damage_taken_bonus(next_bonus, duration)
	# Brick：命中时有几率碎出材料
	if _has_rule(weapon, "break_and_drop_materials_on_hit"):
		var break_chance = float(weapon.data.get("break_chance", 0.0))
		var break_materials = int(weapon.data.get("break_materials", 0))
		if break_chance > 0.0 and break_materials > 0 and randf() < break_chance:
			if p.has_method("earn_gold"):
				p.earn_gold(break_materials)
	# Vorpal Sword：按目录概率直接斩杀。取剩余血量的 4 倍作为伤害，
	# 是为了越过百分比减伤（armored 敌人减伤 50%），确保「即死」名副其实。
	if _has_rule(weapon, "instant_kill_chance_by_tier"):
		var kill_chance = float(weapon.data.get("instant_kill_chance", 0.0))
		if kill_chance > 0.0 and randf() < kill_chance and enemy.has_method("take_damage"):
			enemy.take_damage(max(1, int(enemy.get("hp")) * 4))
	# Lightning Shiv：命中时射出一发闪电弹（弹跳次数取自目录）
	if _has_rule(weapon, "spawn_lightning_projectile_on_hit"):
		var lightning_damage = max(1, int(weapon.data.get("lightning_damage", 1)))
		var lightning_bounces = max(0, int(weapon.data.get("lightning_bounces", 0)))
		_spawn_simple_projectile(
			enemy.position,
			Vector2.RIGHT.rotated(randf() * TAU),
			lightning_damage,
			Color(1.0, 1.0, 0.3),
			lightning_bounces
		)


func apply_ranged_weapon_hit_effects(runtime_id: int, enemy, hit_dmg: int, is_crit: bool):
	# 远程命中路径的武器效果入口，由 Player.on_enemy_hit_by_attack() 调用
	# （子弹命中时把 weapon_runtime_id 一并带过来）。
	# 武器可能在子弹飞行途中被合成或移除，取不到就跳过 —— 这是正确的容错。
	if runtime_id == 0:
		return
	var weapon = _find_weapon_by_runtime_id(runtime_id)
	if weapon.is_empty():
		return
	_apply_ranged_weapon_hit_effects(weapon, enemy, hit_dmg, is_crit)

func _find_weapon_by_runtime_id(runtime_id: int) -> Dictionary:
	for weapon in p.equipped_weapons:
		if int(weapon.get("runtime_id", 0)) == runtime_id:
			return weapon
	return {}

func _apply_ranged_weapon_hit_effects(weapon: Dictionary, enemy, hit_dmg: int, is_crit: bool):
	# 远程专属命中效果。⚠ 不要在这里处理 burn / slow ——
	# 这两条由 Bullet 自己的 burn_damage / slow_on_hit 通道施加，放这里会重复生效。
	if not is_instance_valid(enemy):
		return
	# Sniper Gun：命中后在目标处炸开一圈弹片。
	# 弹片不再携带武器身份（runtime_id 缺省 0），因此不会递归触发本函数。
	if _has_rule(weapon, "spawn_projectiles_on_hit"):
		var shards = int(weapon.data.get("spawned_projectiles_on_hit", 0))
		if shards > 0:
			var shard_damage = max(1, int(weapon.data.get("spawned_projectile_damage_base", 1)))
			var color = weapon.data.get("color", Color(0.9, 0.9, 0.6))
			for i in range(shards):
				var angle = TAU * float(i) / float(shards)
				_spawn_simple_projectile(enemy.position, Vector2.RIGHT.rotated(angle), shard_damage, color)

func _apply_melee_attack_effects(weapon: Dictionary):
	# War Hammer：每次挥击重置进攻型建筑的开火冷却
	if _has_rule(weapon, "reset_offensive_turret_cooldowns_on_attack"):
		_reset_offensive_turret_cooldowns()
	# Cacti Club：每次挥击向四周发射荆棘弹
	if _has_rule(weapon, "shoot_thorns"):
		_fire_thorns(weapon)


func _turret_manager():
	var main = p.get_parent()
	if main == null or not is_instance_valid(main):
		return null
	var manager = main.get("turret_manager")
	if manager == null or not is_instance_valid(manager):
		return null
	return manager


func _reset_offensive_turret_cooldowns():
	var manager = _turret_manager()
	if manager == null:
		return
	for turret in manager.active_turrets:
		if not is_instance_valid(turret):
			continue
		# 医疗炮台不属于「进攻型」，不重置
		if bool(turret.get_meta("is_medical_turret", false)):
			continue
		turret.set_meta("shoot_timer", 0.0)


func _fire_thorns(weapon: Dictionary):
	var shards = int(weapon.data.get("thorn_projectiles", 0))
	if shards <= 0:
		return
	var scaling = float(weapon.data.get("thorn_damage_scaling", 0.5))
	var thorn_damage = max(1, int(round(float(_damage_for_weapon(weapon, null)) * scaling)))
	var color = weapon.data.get("color", Color(0.4, 0.85, 0.3))
	for i in range(shards):
		var angle = TAU * float(i) / float(shards)
		_spawn_simple_projectile(p.position, Vector2.RIGHT.rotated(angle), thorn_damage, color)


func _spawn_simple_projectile(origin: Vector2, dir: Vector2, damage: int, color: Color, bounces: int = 0):
	var main = p.get_parent()
	if main == null or not is_instance_valid(main):
		return
	var use_pool = main.has_method("get_bullet")
	var bullet = main.get_bullet() if use_pool else p.bullet_scene.instantiate()
	if bullet == null:
		return
	bullet.activate(origin, dir, 500.0, color, p, max(1, damage))
	# activate() 的位置参数太多，弹跳余量在返回后单独赋值更清晰
	bullet.bounce_remaining = max(0, bounces)
	if not use_pool and not bullet.get_parent():
		main.add_child(bullet)

func explosion_damage_growth_bonus() -> float:
	# DEX-troyer：本波每次爆炸都会提高爆炸伤害。按「计数即时折算」返回加成，
	# 不去改玩家的 explosion_damage_percent，因此波末计数归零后加成自动消失。
	var bonus = 0.0
	for weapon in p.equipped_weapons:
		if not _has_rule(weapon, "explosion_damage_growth_per_explosion_this_wave"):
			continue
		var per_explosion = float(weapon.data.get("explosion_damage_growth_per_explosion", 0.0))
		if per_explosion == 0.0:
			continue
		var state = _get_weapon_state(weapon)
		bonus += per_explosion * float(int(state.get("explosions_this_wave", 0)))
	return bonus

func on_explosion_dealt():
	for weapon in p.equipped_weapons:
		if not _has_rule(weapon, "explosion_damage_growth_per_explosion_this_wave"):
			continue
		var state = _get_weapon_state(weapon)
		state["explosions_this_wave"] = int(state.get("explosions_this_wave", 0)) + 1


func _spawn_weapon_landmine(weapon: Dictionary):
	# Screwdriver：按武器的 mine_spawn_interval 周期埋雷，伤害来自目录的 mine_damage
	var manager = _turret_manager()
	if manager == null:
		return
	var base_damage = 10.0
	var engineering_coefficient = 1.0
	var mine_damage = weapon.data.get("mine_damage", null)
	if mine_damage is Dictionary:
		base_damage = max(1.0, float(mine_damage.get("base", base_damage)))
		for scaling in mine_damage.get("scaling", []):
			if scaling is Dictionary and str(scaling.get("stat", "")) == "engineering":
				engineering_coefficient = float(scaling.get("coefficient", engineering_coefficient))
				break
	manager.spawn_landmine(p.position, base_damage, engineering_coefficient)


func _spawn_weapon_garden(weapon: Dictionary):
	# Pruner：按武器的 garden_fruit_interval 周期结出花园
	var manager = _turret_manager()
	if manager == null:
		return
	manager.spawn_garden(p.position, float(weapon.data.get("garden_fruit_interval", 15.0)))

func on_wave_start():
	# 先按记录把上一波发放的最大生命值加成扣回，再清零计数
	_revert_kill_max_hp_growth()
	for id in _weapon_state.keys():
		var state = _weapon_state[id]
		state["kills_this_wave"] = 0
		state["self_damage_times"] = 0
		state["charge_time"] = 0.0
		state["charged_damage_bonus"] = 0.0
		state["attack_speed_growth_stacks"] = 0
		state["attack_speed_growth_time"] = 0.0
		state["shots_fired"] = 0
		state["attacks_since_reload"] = 0
		state["nth_projectile_counter"] = 0
		# 波次开始的建筑计时器归零 → 新的一波会立刻先给出一次自持建筑
		state["mine_spawn_timer"] = 0.0
		state["garden_spawn_timer"] = 0.0
		# 本波爆炸计数（DEX-troyer 的爆炸伤害成长）
		state["explosions_this_wave"] = 0

func on_wave_end():
	# Persist or reset any cross-wave weapon state here if needed.
	pass

func on_enemy_killed(_enemy):
	for weapon in p.equipped_weapons:
		if not _tracks_kills(weapon):
			continue
		var state = _get_weapon_state(weapon)
		state["kills_this_wave"] = int(state.get("kills_this_wave", 0)) + 1
		_apply_kill_max_hp_growth(weapon, state)

func _tracks_kills(weapon: Dictionary) -> bool:
	for rule in KILL_TRACKING_RULES:
		if _has_rule(weapon, rule):
			return true
	return false

func _apply_kill_max_hp_growth(weapon: Dictionary, state: Dictionary):
	# Ghost Scepter：本波每 N 次击杀提升最大生命值。
	# 这是本族里唯一需要「真的改玩家属性」的规则，所以用 applied 记录已发放的档数，
	# 波次开始时按同一记录原样扣回。
	if not _has_rule(weapon, "max_hp_growth_per_kills_this_wave"):
		return
	var kill_interval = int(weapon.data.get("max_hp_growth_kill_interval", 0))
	var per_step = int(weapon.data.get("max_hp_growth", 1))
	if kill_interval <= 0 or per_step <= 0:
		return
	var steps = int(state.get("kills_this_wave", 0)) / kill_interval
	var applied = int(state.get("max_hp_growth_applied", 0))
	if steps <= applied:
		return
	_add_max_hp((steps - applied) * per_step)
	state["max_hp_growth_applied"] = steps

func _revert_kill_max_hp_growth():
	for weapon in p.equipped_weapons:
		if not _has_rule(weapon, "max_hp_growth_per_kills_this_wave"):
			continue
		var state = _get_weapon_state(weapon)
		var applied = int(state.get("max_hp_growth_applied", 0))
		if applied <= 0:
			continue
		_add_max_hp(-applied * int(weapon.data.get("max_hp_growth", 1)))
		state["max_hp_growth_applied"] = 0

func _add_max_hp(delta: int):
	if delta == 0:
		return
	if p.has_method("apply_max_hp_delta"):
		p.apply_max_hp_delta(delta)
		return
	p.max_hp = max(1, p.max_hp + delta)
	if delta > 0:
		p.hp = min(p.hp + delta, p.max_hp)
	else:
		p.hp = min(p.hp, p.max_hp)

func on_material_picked_up():
	# Blunderbuss：拾取材料立刻重置冷却（下次 process_weapons 就会开火）
	for weapon in p.equipped_weapons:
		if _has_rule(weapon, "material_pickup_resets_cooldown"):
			weapon.timer = 0.0

func on_player_damaged(_amount: int):
	for weapon in p.equipped_weapons:
		if _has_rule(weapon, "damage_growth_when_damaged_this_wave"):
			var state = _get_weapon_state(weapon)
			state["self_damage_times"] = int(state.get("self_damage_times", 0)) + 1

func reset_state():
	_weapon_state.clear()
	_next_runtime_id = 1
	# 重新与当前武器集合对齐（幂等）：清空武器后残留的贡献会被撤回
	_refresh_weapon_contributions()
