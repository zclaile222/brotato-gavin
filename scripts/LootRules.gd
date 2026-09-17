class_name LootRules
extends RefCounted

const PICKUP_DATA = {
	"fruit": {"kind": "fruit", "heal_amount": 3, "crate_tier": 0, "color": Color(0.25, 1.0, 0.35)},
	"crate": {"kind": "crate", "heal_amount": 3, "crate_tier": 1, "color": Color(0.75, 0.45, 0.18)},
	"legendary_crate": {"kind": "legendary_crate", "heal_amount": 100, "crate_tier": 4, "color": Color(1.0, 0.82, 0.18)},
}

func get_pickup_data(kind: String) -> Dictionary:
	if not PICKUP_DATA.has(kind):
		kind = "fruit"
	return PICKUP_DATA[kind].duplicate(true)

func roll_pickup_kind(enemy_type: String, luck: int, crates_dropped_this_wave: int, fruit_drop_chance_bonus: float = 0.0, consumable_roll: float = -1.0, crate_roll: float = -1.0) -> Dictionary:
	if enemy_type in ["boss", "miniboss"]:
		return get_pickup_data("legendary_crate")
	if enemy_type == "loot_alien":
		return get_pickup_data("crate")
	var luck_mult = max(0.0, 1.0 + float(luck) / 100.0)
	if enemy_type == "tree":
		var tree_consumable_roll = randf() if consumable_roll < 0.0 else consumable_roll
		if tree_consumable_roll > clamp(luck_mult, 0.0, 1.0):
			return {}
		var tree_crate_chance = 0.20 * luck_mult / float(1 + max(0, crates_dropped_this_wave))
		var tree_crate_roll = randf() if crate_roll < 0.0 else crate_roll
		if tree_crate_roll < clamp(tree_crate_chance, 0.0, 0.95):
			return get_pickup_data("crate")
		return get_pickup_data("fruit")
	var base_consumable_chance = 0.10
	if enemy_type == "elite":
		base_consumable_chance = 0.30
	var consumable_chance = (base_consumable_chance + max(0.0, fruit_drop_chance_bonus)) * luck_mult
	var roll = randf() if consumable_roll < 0.0 else consumable_roll
	if roll > clamp(consumable_chance, 0.0, 0.95):
		return {}
	var crate_chance = 0.08 * luck_mult / float(1 + max(0, crates_dropped_this_wave))
	if enemy_type == "elite":
		crate_chance = 0.25 * luck_mult / float(1 + max(0, crates_dropped_this_wave))
	var crate_roll_value = randf() if crate_roll < 0.0 else crate_roll
	if crate_roll_value < clamp(crate_chance, 0.0, 0.95):
		return get_pickup_data("crate")
	return get_pickup_data("fruit")

func get_recycle_value(base_price: int, rarity: int, wave: int, shop_rules: ShopRules = null, recycling_materials_percent: float = 0.0) -> int:
	var current_price = base_price
	if shop_rules != null:
		current_price = shop_rules.get_price(base_price, rarity, wave)
	var recycle_mult = max(0.0, 1.0 + recycling_materials_percent)
	return max(1, int(floor(float(current_price) * 0.25 * recycle_mult)))

func create_crate_reward(item_pool: Array, wave: int, luck: int, crate_tier: int, shop_rules: ShopRules = null, recycling_materials_percent: float = 0.0) -> Dictionary:
	var candidates = item_pool.filter(func(item):
		return item.get("type", "item") != "weapon"
	)
	if candidates.is_empty():
		return {}
	var chosen = candidates[randi() % candidates.size()].duplicate(true)
	var rarity = chosen.get("rarity", 0)
	if crate_tier >= 4:
		rarity = 3
	elif shop_rules != null:
		rarity = max(rarity, shop_rules.roll_rarity(wave, luck))
	else:
		var luck_bonus = clamp(luck, 0, 100) * 0.003
		var r = randf()
		if r < 0.03 + luck_bonus * 0.25:
			rarity = max(rarity, 3)
		elif r < 0.15 + luck_bonus * 0.55:
			rarity = max(rarity, 2)
		elif r < 0.45 + luck_bonus:
			rarity = max(rarity, 1)
	chosen["rolled_rarity"] = clamp(rarity, 0, 3)
	chosen["crate_tier"] = crate_tier
	chosen["recycle_value"] = get_recycle_value(chosen.get("price", 1), int(chosen.get("rolled_rarity", 0)), wave, shop_rules, recycling_materials_percent)
	return chosen
