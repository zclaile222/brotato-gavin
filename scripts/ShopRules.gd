class_name ShopRules
extends RefCounted

func get_reroll_cost(reroll_index: int, reroll_price_percent: float = 0.0) -> int:
	var base_cost = 5 + max(0, reroll_index) * 5
	return max(1, int(round(float(base_cost) * max(0.05, 1.0 + reroll_price_percent))))

func get_price(base_price: int, rarity: int, wave: int, item_price_percent: float = 0.0) -> int:
	var rarity_mult = [1.0, 1.5, 2.5, 4.0][clamp(rarity, 0, 3)]
	var wave_mult = 1.0 + max(0, wave - 1) * 0.06
	var item_price_mult = max(0.05, 1.0 + item_price_percent)
	return max(1, int(round(base_price * rarity_mult * wave_mult * item_price_mult)))

func roll_rarity(wave: int, luck: int) -> int:
	var rare_bonus = clamp(luck, 0, 100) * 0.003 + max(0, wave - 1) * 0.01
	var r = randf()
	if r < 0.03 + rare_bonus * 0.25:
		return 3
	if r < 0.15 + rare_bonus * 0.55:
		return 2
	if r < 0.45 + rare_bonus:
		return 1
	return 0

func roll_slot_type(wave: int, slot_index: int) -> String:
	if wave <= 2 and slot_index == 0:
		return "weapon"
	return "weapon" if randf() < 0.35 else "item"

func roll_offers(item_pool: Array, wave: int, luck: int, locked_items: Dictionary, current_items: Array) -> Array:
	var result: Array = []
	var seen: Array = []
	for slot in range(4):
		if locked_items.has(slot):
			var locked = locked_items[slot]
			result.append(locked)
			seen.append(locked.name)
			continue
		var slot_type = roll_slot_type(wave, slot)
		var candidates = item_pool.filter(func(item):
			var item_type = item.get("type", "item")
			var type_ok = item_type == "weapon" if slot_type == "weapon" else item_type != "weapon"
			return type_ok and item.name not in seen
		)
		if candidates.is_empty():
			candidates = item_pool.filter(func(item): return item.name not in seen)
		var chosen = candidates[randi() % candidates.size()].duplicate(true)
		chosen["rolled_rarity"] = max(chosen.get("rarity", 0), roll_rarity(wave, luck))
		seen.append(chosen.name)
		result.append(chosen)
	return result
