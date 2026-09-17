class_name WeaponDatabase
extends Resource

@export var weapons: Array[WeaponData] = []

func to_combat_dict() -> Dictionary:
	var d = {}
	for w in weapons:
		if _is_placeholder_weapon_type(w.weapon_type):
			continue
		d[w.weapon_type] = w.to_combat_entry()
	return d

func to_shop_entries() -> Array:
	var entries: Array = []
	for w in weapons:
		if _is_placeholder_weapon_type(w.weapon_type):
			continue
		entries.append(w.to_shop_entry())
	return entries

static func _is_placeholder_weapon_type(weapon_type: String) -> bool:
	var normalized = weapon_type.strip_edges().to_lower()
	return normalized == "" or normalized == "unknown"

static func catalog_combat_dict(include_unimplemented: bool = true) -> Dictionary:
	var script = load("res://scripts/BrotatoData.gd")
	if script == null:
		return {}
	var catalog = script.new()
	if not catalog.load_catalog().is_empty():
		return {}
	return catalog.get_combat_dict(include_unimplemented)

static func catalog_shop_entries(include_unimplemented: bool = false) -> Array:
	var script = load("res://scripts/BrotatoData.gd")
	if script == null:
		return []
	var catalog = script.new()
	if not catalog.load_catalog().is_empty():
		return []
	return catalog.get_weapon_shop_entries(include_unimplemented)
	
