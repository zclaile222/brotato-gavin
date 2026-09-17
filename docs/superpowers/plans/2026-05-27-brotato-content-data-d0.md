# Brotato Content Data D0 Implementation Plan

Execution note: The final implementation went beyond the original D0-only plan by adding staged runtime compatibility paths for character select, combat weapon data, and shop weapon entries, plus a Phase D1 smoke check for legacy `Unknown` weapon filtering. Treat this plan as the historical D0 seed plan; use `docs/PROGRESS.md` and `docs/brotato-fidelity/fidelity-audit.md` for current status.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first data-backed catalog shell for Brotato-like non-art content: JSON seed files, a `BrotatoData` loader/validator, and a Godot smoke test that proves the catalog shape is usable before larger character, weapon, and item imports.

**Architecture:** D0 introduces `data/brotato/` as the canonical home for structured content data, without migrating runtime systems away from existing hardcoded pools yet. `scripts/BrotatoData.gd` loads and validates the JSON catalog and exposes conversion helpers that future D1-D3 tasks will wire into weapons, shop, character select, and upgrades.

**Tech Stack:** Godot 4.6 GDScript, JSON files loaded through `FileAccess` and `JSON.parse_string`, existing headless Godot smoke-test pattern, local Git commits.

---

## Scope

This plan implements only Phase D0 from `docs/superpowers/specs/2026-05-27-brotato-content-data-design.md`.

D0 must not migrate `GameState.gd`, `Shop.gd`, `PlayerCombat.gd`, or `UpgradeChoiceRules.gd` to the catalog yet. That belongs to D1-D3.

D0 must leave the game playable through existing code while adding:

- `data/brotato/catalog_manifest.json`
- `data/brotato/effect_schema.json`
- `data/brotato/item_tags.json`
- `data/brotato/weapon_classes.json`
- `data/brotato/weapons.json`
- `data/brotato/items.json`
- `data/brotato/upgrades.json`
- `data/brotato/characters.json`
- `scripts/BrotatoData.gd`
- `tests/brotato_data_catalog_smoke.gd`

## File Responsibilities

- `data/brotato/catalog_manifest.json`: reference version, source scope, expected long-term counts, and source URLs.
- `data/brotato/effect_schema.json`: allowed structured effect IDs and required fields.
- `data/brotato/item_tags.json`: seed tag definitions referenced by characters/items.
- `data/brotato/weapon_classes.json`: seed weapon-class definitions referenced by weapons.
- `data/brotato/weapons.json`: seed weapon rows with tier data.
- `data/brotato/items.json`: seed item rows with structural effects.
- `data/brotato/upgrades.json`: seed level-up choices, separate from shop items.
- `data/brotato/characters.json`: seed character rows and starting weapon references.
- `scripts/BrotatoData.gd`: load, index, query, convert, and validate catalog files.
- `tests/brotato_data_catalog_smoke.gd`: fail-fast validation for D0 catalog integrity and existing game boot compatibility.
- `docs/PROGRESS.md`: add D0 implementation status and verification notes.
- `docs/architecture.md`: add the data catalog loader to the architecture map.

## Task 1: Add Catalog Seed Files

**Files:**
- Create: `data/brotato/catalog_manifest.json`
- Create: `data/brotato/effect_schema.json`
- Create: `data/brotato/item_tags.json`
- Create: `data/brotato/weapon_classes.json`
- Create: `data/brotato/weapons.json`
- Create: `data/brotato/items.json`
- Create: `data/brotato/upgrades.json`
- Create: `data/brotato/characters.json`

- [ ] **Step 1: Create `data/brotato/catalog_manifest.json`**

Use this exact content:

```json
{
  "schema_version": 1,
  "reference_game": "Brotato",
  "reference_version": "1.1.10.9",
  "include_base_game": true,
  "include_abyssal_terrors": true,
  "expected_counts": {
    "characters": 62,
    "items_total": 237
  },
  "source_urls": [
    "https://brotato.wiki.spellsandguns.com/Characters",
    "https://brotato.wiki.spellsandguns.com/Template%3ACharacter_Data",
    "https://brotato.wiki.spellsandguns.com/Weapons",
    "https://brotato.wiki.spellsandguns.com/Template%3AWeapon_Data",
    "https://brotato.wiki.spellsandguns.com/Items"
  ],
  "notes": [
    "D0 seed catalog is intentionally partial.",
    "Full counts are long-term validation targets, not D0 pass criteria.",
    "Rows store structured mechanics and compact local notes, not copied source prose."
  ]
}
```

- [ ] **Step 2: Create `data/brotato/effect_schema.json`**

Use this exact content:

```json
{
  "stat_delta": {
    "required": ["stat", "value"]
  },
  "stat_multiplier": {
    "required": ["stat", "multiplier"]
  },
  "stat_modifications_multiplier": {
    "required": ["stat", "multiplier"]
  },
  "forbid_weapon_group": {
    "required": ["group"]
  },
  "weapon_class_bonus": {
    "required": ["class_id", "thresholds"]
  },
  "pickup_range_percent": {
    "required": ["value"]
  },
  "weapon_special": {
    "required": ["rule"]
  },
  "material_gain": {
    "required": ["amount"]
  }
}
```

- [ ] **Step 3: Create `data/brotato/item_tags.json`**

Use this exact content:

```json
[
  {
    "id": "max_hp",
    "source_name": "Max HP",
    "category": "stat",
    "implemented": true
  },
  {
    "id": "ranged_damage",
    "source_name": "Ranged Damage",
    "category": "stat",
    "implemented": false
  },
  {
    "id": "range",
    "source_name": "Range",
    "category": "stat",
    "implemented": false
  },
  {
    "id": "pickup",
    "source_name": "Pickup",
    "category": "utility",
    "implemented": true
  }
]
```

- [ ] **Step 4: Create `data/brotato/weapon_classes.json`**

Use this exact content:

```json
[
  {
    "id": "gun",
    "source_name": "Gun",
    "thresholds": {
      "2": [{"effect": "stat_delta", "stat": "range", "value": 25}],
      "3": [{"effect": "stat_delta", "stat": "range", "value": 50}],
      "4": [{"effect": "stat_delta", "stat": "range", "value": 75}],
      "5": [{"effect": "stat_delta", "stat": "range", "value": 100}],
      "6": [{"effect": "stat_delta", "stat": "range", "value": 125}]
    },
    "implemented": false
  },
  {
    "id": "support",
    "source_name": "Support",
    "thresholds": {
      "2": [{"effect": "stat_delta", "stat": "harvesting", "value": 5}],
      "3": [{"effect": "stat_delta", "stat": "harvesting", "value": 8}],
      "4": [{"effect": "stat_delta", "stat": "harvesting", "value": 11}],
      "5": [{"effect": "stat_delta", "stat": "harvesting", "value": 14}],
      "6": [{"effect": "stat_delta", "stat": "harvesting", "value": 17}]
    },
    "implemented": false
  }
]
```

- [ ] **Step 5: Create `data/brotato/weapons.json`**

Use this exact content:

```json
[
  {
    "id": "pistol",
    "source_name": "Pistol",
    "display_name": "Pistol",
    "is_dlc": false,
    "groups": ["gun"],
    "attack_kind": "ranged",
    "unlocked_by": {"type": "default"},
    "tiers": {
      "1": {
        "damage": {"base": 12, "scaling": [{"stat": "ranged_damage", "coefficient": 1.0}]},
        "cooldown": 1.2,
        "range": 400,
        "crit_multiplier": 2.0,
        "crit_chance": 0.05,
        "knockback": 15,
        "lifesteal": 0,
        "base_price": 12,
        "projectiles": 1,
        "pierce": {"count": 1, "damage_multiplier": 0.5}
      },
      "2": {
        "damage": {"base": 18, "scaling": [{"stat": "ranged_damage", "coefficient": 1.0}]},
        "cooldown": 1.12,
        "range": 425,
        "crit_multiplier": 2.0,
        "crit_chance": 0.05,
        "knockback": 15,
        "lifesteal": 0,
        "base_price": 25,
        "projectiles": 1,
        "pierce": {"count": 1, "damage_multiplier": 0.5}
      },
      "3": {
        "damage": {"base": 30, "scaling": [{"stat": "ranged_damage", "coefficient": 1.0}]},
        "cooldown": 1.03,
        "range": 450,
        "crit_multiplier": 2.0,
        "crit_chance": 0.05,
        "knockback": 15,
        "lifesteal": 0,
        "base_price": 55,
        "projectiles": 1,
        "pierce": {"count": 1, "damage_multiplier": 0.5}
      },
      "4": {
        "damage": {"base": 50, "scaling": [{"stat": "ranged_damage", "coefficient": 1.0}]},
        "cooldown": 0.92,
        "range": 500,
        "crit_multiplier": 2.0,
        "crit_chance": 0.05,
        "knockback": 15,
        "lifesteal": 0,
        "base_price": 110,
        "projectiles": 1,
        "pierce": {"count": 1, "damage_multiplier": 0.5}
      }
    },
    "special_rules": [
      {"effect": "weapon_special", "rule": "pierce_falloff"}
    ],
    "implemented": true,
    "implementation_notes": "D0 seed row. Runtime still uses data/weapons.tres until D1."
  }
]
```

- [ ] **Step 6: Create `data/brotato/items.json`**

Use this exact content:

```json
[
  {
    "id": "alien_tongue",
    "source_name": "Alien Tongue",
    "display_name": "Alien Tongue",
    "is_dlc": false,
    "tier": 1,
    "base_price": 25,
    "limit": null,
    "unlocked_by": {"type": "default"},
    "tags": ["pickup"],
    "effects": [
      {"effect": "pickup_range_percent", "value": 0.3},
      {"effect": "stat_delta", "stat": "knockback", "value": 1}
    ],
    "implemented": false,
    "implementation_notes": "Modeled for catalog validation. Runtime item effect migration starts in D3."
  }
]
```

- [ ] **Step 7: Create `data/brotato/upgrades.json`**

Use this exact content:

```json
[
  {
    "id": "max_hp_1",
    "display_name": "Max HP I",
    "tier": 1,
    "stat": "max_hp",
    "value": 3,
    "weight": 1.0,
    "min_wave": 1,
    "max_wave": 999,
    "implemented": true
  },
  {
    "id": "damage_1",
    "display_name": "Damage I",
    "tier": 1,
    "stat": "damage",
    "value": 1,
    "weight": 1.0,
    "min_wave": 1,
    "max_wave": 999,
    "implemented": true
  }
]
```

- [ ] **Step 8: Create `data/brotato/characters.json`**

Use this exact content:

```json
[
  {
    "id": "well_rounded",
    "source_name": "Well Rounded",
    "display_name": "Well Rounded",
    "runtime_aliases": ["normal"],
    "is_dlc": false,
    "unlock": {"type": "default"},
    "unlocks": [{"type": "item", "id": "potato"}],
    "wanted_tags": ["max_hp"],
    "starting_weapons": ["pistol"],
    "fixed_starting_weapons": [],
    "fixed_starting_items": [],
    "base_stats": {
      "max_hp": 5,
      "speed_percent": 0.05,
      "harvesting": 8
    },
    "rules": [
      {"effect": "stat_delta", "stat": "max_hp", "value": 5},
      {"effect": "stat_delta", "stat": "harvesting", "value": 8},
      {"effect": "stat_delta", "stat": "speed_percent", "value": 0.05}
    ],
    "implemented": false,
    "implementation_notes": "D0 seed row. Runtime still uses GameState.CHARACTERS until D2."
  }
]
```

- [ ] **Step 9: Verify JSON files are present**

Run:

```powershell
rg --files data/brotato
```

Expected output includes exactly these file paths:

```text
data/brotato/catalog_manifest.json
data/brotato/characters.json
data/brotato/effect_schema.json
data/brotato/item_tags.json
data/brotato/items.json
data/brotato/upgrades.json
data/brotato/weapon_classes.json
data/brotato/weapons.json
```

- [ ] **Step 10: Commit catalog seed files**

Run:

```powershell
git add -- data/brotato
git commit -m "data: add Brotato catalog seed files"
```

Expected: commit succeeds with 8 new JSON files.

## Task 2: Add `BrotatoData.gd` Loader And Validator

**Files:**
- Create: `scripts/BrotatoData.gd`

- [ ] **Step 1: Write failing loader smoke inline before creating the script**

Run:

```powershell
@'
extends SceneTree

func _init():
	var script = load("res://scripts/BrotatoData.gd")
	if script == null:
		print("EXPECTED_FAIL_BROTATO_DATA_MISSING")
		quit(1)
		return
	quit(0)
'@ | Set-Content -Encoding UTF8 C:\tmp\brotato_data_missing_smoke.gd
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "C:\tmp\brotato_data_missing_smoke.gd"
```

Expected before implementation: exit code `1` and output contains `EXPECTED_FAIL_BROTATO_DATA_MISSING`.

- [ ] **Step 2: Create `scripts/BrotatoData.gd`**

Use this complete implementation:

```gdscript
class_name BrotatoData
extends RefCounted

const CATALOG_DIR := "res://data/brotato"

const REQUIRED_FILES := {
	"manifest": "catalog_manifest.json",
	"effect_schema": "effect_schema.json",
	"item_tags": "item_tags.json",
	"weapon_classes": "weapon_classes.json",
	"weapons": "weapons.json",
	"items": "items.json",
	"upgrades": "upgrades.json",
	"characters": "characters.json",
}

var manifest: Dictionary = {}
var effect_schema: Dictionary = {}
var item_tags: Dictionary = {}
var weapon_classes: Dictionary = {}
var weapons: Dictionary = {}
var items: Dictionary = {}
var upgrades: Dictionary = {}
var characters: Dictionary = {}

var _loaded := false
var _load_errors: Array[String] = []

func load_catalog() -> Array[String]:
	_clear()
	for key in REQUIRED_FILES:
		var path = "%s/%s" % [CATALOG_DIR, REQUIRED_FILES[key]]
		var parsed = _read_json(path)
		if parsed == null:
			continue
		match key:
			"manifest":
				if parsed is Dictionary:
					manifest = parsed
				else:
					_load_errors.append("%s must be an object" % path)
			"effect_schema":
				if parsed is Dictionary:
					effect_schema = parsed
				else:
					_load_errors.append("%s must be an object" % path)
			"item_tags":
				item_tags = _index_array(path, parsed)
			"weapon_classes":
				weapon_classes = _index_array(path, parsed)
			"weapons":
				weapons = _index_array(path, parsed)
			"items":
				items = _index_array(path, parsed)
			"upgrades":
				upgrades = _index_array(path, parsed)
			"characters":
				characters = _index_array(path, parsed)
	_loaded = _load_errors.is_empty()
	return _load_errors.duplicate()

func validate() -> Array[String]:
	if not _loaded:
		load_catalog()
	var errors: Array[String] = []
	errors.append_array(_load_errors)
	_validate_manifest(errors)
	_validate_effect_schema(errors)
	_validate_tags(errors)
	_validate_weapon_classes(errors)
	_validate_weapons(errors)
	_validate_items(errors)
	_validate_upgrades(errors)
	_validate_characters(errors)
	return errors

func get_character(id: String) -> Dictionary:
	_ensure_loaded()
	if characters.has(id):
		return characters[id].duplicate(true)
	for key in characters:
		var row: Dictionary = characters[key]
		if id in row.get("runtime_aliases", []):
			return row.duplicate(true)
	return {}

func get_characters(include_unimplemented: bool = true) -> Dictionary:
	_ensure_loaded()
	return _filter_dictionary(characters, include_unimplemented)

func get_weapon(id: String) -> Dictionary:
	_ensure_loaded()
	return weapons.get(id, {}).duplicate(true)

func get_weapons(include_unimplemented: bool = true) -> Dictionary:
	_ensure_loaded()
	return _filter_dictionary(weapons, include_unimplemented)

func get_items(include_unimplemented: bool = true) -> Dictionary:
	_ensure_loaded()
	return _filter_dictionary(items, include_unimplemented)

func get_shop_pool(include_unimplemented: bool = false) -> Array:
	_ensure_loaded()
	var pool: Array = []
	for id in items:
		var row: Dictionary = items[id]
		if not include_unimplemented and not row.get("implemented", false):
			continue
		pool.append(_item_to_shop_entry(row))
	return pool

func get_weapon_shop_entries(include_unimplemented: bool = false) -> Array:
	_ensure_loaded()
	var entries: Array = []
	for id in weapons:
		var row: Dictionary = weapons[id]
		if not include_unimplemented and not row.get("implemented", false):
			continue
		var tier_one: Dictionary = row.get("tiers", {}).get("1", {})
		entries.append({
			"name": row.get("display_name", row.get("source_name", id)),
			"desc": "Weapon catalog row",
			"price": int(tier_one.get("base_price", 1)),
			"rarity": 0,
			"type": "weapon",
			"weapon_type": id,
			"source_id": id,
		})
	return entries

func get_level_up_choices() -> Array:
	_ensure_loaded()
	var choices: Array = []
	for id in upgrades:
		var row: Dictionary = upgrades[id]
		if not row.get("implemented", false):
			continue
		choices.append(row.duplicate(true))
	return choices

func weapon_tier_to_combat_entry(id: String, tier: int = 1) -> Dictionary:
	_ensure_loaded()
	if not weapons.has(id):
		return {}
	var weapon: Dictionary = weapons[id]
	var tiers: Dictionary = weapon.get("tiers", {})
	var tier_key = str(clamp(tier, 1, 4))
	if not tiers.has(tier_key):
		return {}
	var row: Dictionary = tiers[tier_key]
	var damage: Dictionary = row.get("damage", {})
	var cooldown = max(0.01, float(row.get("cooldown", 1.0)))
	return {
		"name": weapon.get("display_name", weapon.get("source_name", id)),
		"damage": int(damage.get("base", 1)),
		"fire_rate": 1.0 / cooldown,
		"count": int(row.get("projectiles", 1)),
		"spread": float(row.get("spread", 0.0)),
		"spd": float(row.get("projectile_speed", 500.0)),
		"color": Color(1, 0.9, 0.2),
		"range": float(row.get("range", 0)),
		"pierce": row.has("pierce"),
	}

func _item_to_shop_entry(row: Dictionary) -> Dictionary:
	return {
		"name": row.get("display_name", row.get("source_name", row.get("id", ""))),
		"desc": "Structured catalog item",
		"price": int(row.get("base_price", 1)),
		"rarity": max(0, int(row.get("tier", 1)) - 1),
		"type": "catalog_item",
		"source_id": row.get("id", ""),
		"effects": row.get("effects", []),
	}

func _clear():
	manifest = {}
	effect_schema = {}
	item_tags = {}
	weapon_classes = {}
	weapons = {}
	items = {}
	upgrades = {}
	characters = {}
	_loaded = false
	_load_errors.clear()

func _ensure_loaded():
	if not _loaded and _load_errors.is_empty():
		load_catalog()

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		_load_errors.append("Missing catalog file: " + path)
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_load_errors.append("Failed to open catalog file: " + path)
		return null
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		_load_errors.append("Invalid JSON: " + path)
	return parsed

func _index_array(path: String, value) -> Dictionary:
	var indexed: Dictionary = {}
	if not value is Array:
		_load_errors.append("%s must be an array" % path)
		return indexed
	for entry in value:
		if not entry is Dictionary:
			_load_errors.append("%s contains a non-object entry" % path)
			continue
		var id = str(entry.get("id", ""))
		if id == "":
			_load_errors.append("%s contains an entry without id" % path)
			continue
		if indexed.has(id):
			_load_errors.append("%s contains duplicate id: %s" % [path, id])
			continue
		indexed[id] = entry
	return indexed

func _filter_dictionary(source: Dictionary, include_unimplemented: bool) -> Dictionary:
	var result: Dictionary = {}
	for id in source:
		var row: Dictionary = source[id]
		if include_unimplemented or row.get("implemented", false):
			result[id] = row.duplicate(true)
	return result

func _validate_manifest(errors: Array[String]):
	for field in ["schema_version", "reference_game", "reference_version", "expected_counts", "source_urls"]:
		if not manifest.has(field):
			errors.append("catalog_manifest missing field: " + field)

func _validate_effect_schema(errors: Array[String]):
	for effect_id in effect_schema:
		var spec = effect_schema[effect_id]
		if not spec is Dictionary:
			errors.append("effect_schema.%s must be an object" % effect_id)
			continue
		if not spec.has("required") or not spec.required is Array:
			errors.append("effect_schema.%s.required must be an array" % effect_id)

func _validate_tags(errors: Array[String]):
	for id in item_tags:
		var row: Dictionary = item_tags[id]
		_require_fields(errors, "item_tags.%s" % id, row, ["id", "source_name", "category", "implemented"])

func _validate_weapon_classes(errors: Array[String]):
	for id in weapon_classes:
		var row: Dictionary = weapon_classes[id]
		_require_fields(errors, "weapon_classes.%s" % id, row, ["id", "source_name", "thresholds", "implemented"])
		_validate_effects(errors, "weapon_classes.%s.thresholds" % id, _collect_threshold_effects(row.get("thresholds", {})))

func _validate_weapons(errors: Array[String]):
	for id in weapons:
		var row: Dictionary = weapons[id]
		_require_fields(errors, "weapons.%s" % id, row, ["id", "source_name", "display_name", "is_dlc", "groups", "attack_kind", "unlocked_by", "tiers", "special_rules", "implemented"])
		for group in row.get("groups", []):
			if not weapon_classes.has(str(group)):
				errors.append("weapons.%s references missing weapon class: %s" % [id, group])
		var tiers: Dictionary = row.get("tiers", {})
		for tier in ["1", "2", "3", "4"]:
			if not tiers.has(tier):
				errors.append("weapons.%s missing tier %s" % [id, tier])
				continue
			_require_fields(errors, "weapons.%s.tiers.%s" % [id, tier], tiers[tier], ["damage", "cooldown", "range", "crit_multiplier", "crit_chance", "knockback", "lifesteal", "base_price"])
		_validate_effects(errors, "weapons.%s.special_rules" % id, row.get("special_rules", []))

func _validate_items(errors: Array[String]):
	for id in items:
		var row: Dictionary = items[id]
		_require_fields(errors, "items.%s" % id, row, ["id", "source_name", "display_name", "is_dlc", "tier", "base_price", "limit", "unlocked_by", "tags", "effects", "implemented"])
		for tag in row.get("tags", []):
			if not item_tags.has(str(tag)):
				errors.append("items.%s references missing item tag: %s" % [id, tag])
		_validate_effects(errors, "items.%s.effects" % id, row.get("effects", []))

func _validate_upgrades(errors: Array[String]):
	for id in upgrades:
		var row: Dictionary = upgrades[id]
		_require_fields(errors, "upgrades.%s" % id, row, ["id", "display_name", "tier", "stat", "value", "weight", "min_wave", "max_wave", "implemented"])

func _validate_characters(errors: Array[String]):
	for id in characters:
		var row: Dictionary = characters[id]
		_require_fields(errors, "characters.%s" % id, row, ["id", "source_name", "display_name", "is_dlc", "unlock", "unlocks", "wanted_tags", "starting_weapons", "fixed_starting_weapons", "fixed_starting_items", "base_stats", "rules", "implemented"])
		for weapon_id in row.get("starting_weapons", []):
			if not weapons.has(str(weapon_id)):
				errors.append("characters.%s references missing starting weapon: %s" % [id, weapon_id])
		for weapon_id in row.get("fixed_starting_weapons", []):
			if not weapons.has(str(weapon_id)):
				errors.append("characters.%s references missing fixed starting weapon: %s" % [id, weapon_id])
		for item_id in row.get("fixed_starting_items", []):
			if not items.has(str(item_id)):
				errors.append("characters.%s references missing fixed starting item: %s" % [id, item_id])
		for tag in row.get("wanted_tags", []):
			if not item_tags.has(str(tag)):
				errors.append("characters.%s references missing wanted tag: %s" % [id, tag])
		_validate_effects(errors, "characters.%s.rules" % id, row.get("rules", []))

func _validate_effects(errors: Array[String], path: String, effects: Array):
	for i in range(effects.size()):
		var effect = effects[i]
		if not effect is Dictionary:
			errors.append("%s[%d] must be an object" % [path, i])
			continue
		var effect_id = str(effect.get("effect", ""))
		if effect_id == "":
			errors.append("%s[%d] missing effect" % [path, i])
			continue
		if not effect_schema.has(effect_id):
			errors.append("%s[%d] references unknown effect: %s" % [path, i, effect_id])
			continue
		for field in effect_schema[effect_id].get("required", []):
			if not effect.has(str(field)):
				errors.append("%s[%d] effect %s missing field: %s" % [path, i, effect_id, field])

func _collect_threshold_effects(thresholds) -> Array:
	var result: Array = []
	if not thresholds is Dictionary:
		return result
	for key in thresholds:
		var effects = thresholds[key]
		if effects is Array:
			result.append_array(effects)
	return result

func _require_fields(errors: Array[String], path: String, row: Dictionary, fields: Array):
	for field in fields:
		if not row.has(str(field)):
			errors.append("%s missing field: %s" % [path, field])
```

- [ ] **Step 3: Run inline loader smoke to verify it now passes**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "C:\tmp\brotato_data_missing_smoke.gd"
```

Expected: exit code `0`.

- [ ] **Step 4: Commit loader**

Run:

```powershell
git add -- scripts/BrotatoData.gd
git commit -m "feat: add Brotato catalog loader"
```

Expected: commit succeeds with one new GDScript file.

## Task 3: Add Catalog Smoke Test

**Files:**
- Create: `tests/brotato_data_catalog_smoke.gd`

- [ ] **Step 1: Write `tests/brotato_data_catalog_smoke.gd`**

Use this complete test:

```gdscript
extends SceneTree

var failures: Array[String] = []

func _init():
	call_deferred("_run")

func _run():
	var data := BrotatoData.new()
	var load_errors = data.load_catalog()
	if not load_errors.is_empty():
		for error in load_errors:
			failures.append("Load error: " + error)

	var validation_errors = data.validate()
	if not validation_errors.is_empty():
		for error in validation_errors:
			failures.append("Validation error: " + error)

	_check_manifest(data)
	_check_seed_catalog(data)
	_check_shop_filters(data)
	_check_conversions(data)
	await _check_main_scene_still_boots()

	if failures.is_empty():
		print("BROTATO_DATA_CATALOG_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_manifest(data: BrotatoData):
	if data.manifest.get("reference_version", "") != "1.1.10.9":
		failures.append("Manifest reference version mismatch")
	if not data.manifest.get("include_base_game", false):
		failures.append("Manifest must include base game scope")
	if not data.manifest.get("include_abyssal_terrors", false):
		failures.append("Manifest must include Abyssal Terrors scope")
	var counts: Dictionary = data.manifest.get("expected_counts", {})
	if int(counts.get("characters", 0)) != 62:
		failures.append("Manifest expected character count must stay at 62")
	if int(counts.get("items_total", 0)) != 237:
		failures.append("Manifest expected total item count must stay at 237")

func _check_seed_catalog(data: BrotatoData):
	if data.get_character("well_rounded").is_empty():
		failures.append("Missing well_rounded seed character")
	if data.get_character("normal").is_empty():
		failures.append("Missing runtime alias for current normal character")
	if data.get_weapon("pistol").is_empty():
		failures.append("Missing pistol seed weapon")
	if not data.get_items(true).has("alien_tongue"):
		failures.append("Missing alien_tongue seed item")
	if data.get_level_up_choices().size() < 2:
		failures.append("Expected at least two implemented level-up seed choices")

func _check_shop_filters(data: BrotatoData):
	var playable_items = data.get_shop_pool(false)
	if not playable_items.is_empty():
		failures.append("D0 playable shop item pool should exclude unimplemented seed items")
	var debug_items = data.get_shop_pool(true)
	if debug_items.size() != 1:
		failures.append("D0 debug shop item pool should include exactly one seed item")
	var weapon_entries = data.get_weapon_shop_entries(false)
	if weapon_entries.size() != 1:
		failures.append("D0 implemented weapon shop entries should include pistol")
	elif weapon_entries[0].get("weapon_type", "") != "pistol":
		failures.append("D0 weapon shop entry should resolve pistol")

func _check_conversions(data: BrotatoData):
	var combat = data.weapon_tier_to_combat_entry("pistol", 1)
	if combat.is_empty():
		failures.append("Pistol tier 1 did not convert to combat entry")
		return
	if int(combat.get("damage", 0)) != 12:
		failures.append("Pistol tier 1 combat damage mismatch")
	if float(combat.get("fire_rate", 0.0)) <= 0.0:
		failures.append("Pistol tier 1 combat fire rate must be positive")
	if int(combat.get("count", 0)) != 1:
		failures.append("Pistol tier 1 projectile count mismatch")

func _check_main_scene_still_boots():
	var game_state = root.get_node("/root/GameState")
	game_state.selected_character = "normal"
	game_state.difficulty = 1
	game_state.endless_mode = false
	var packed = load("res://scenes/Main.tscn")
	if packed == null:
		failures.append("Main scene failed to load")
		return
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	if main.get_script() == null:
		failures.append("Main scene script did not load after adding BrotatoData")
	if main.get("player") == null:
		failures.append("Main scene did not resolve player after adding BrotatoData")
	main.queue_free()
	for i in range(5):
		await process_frame
```

- [ ] **Step 2: Run the new smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/brotato_data_catalog_smoke.gd"
```

Expected output:

```text
BROTATO_DATA_CATALOG_SMOKE_PASS
```

Expected exit code: `0`.

- [ ] **Step 3: Run existing smoke tests**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/phase1_rules_smoke.gd"
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/phase1_main_scene_smoke.gd"
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/effects_pool_scene_change_smoke.gd"
```

Expected outputs:

```text
PHASE1_RULE_SMOKE_PASS
PHASE1_MAIN_SCENE_SMOKE_PASS
PHASE2_LOOT_WEAPON_SMOKE_PASS
EFFECTS_POOL_SCENE_CHANGE_SMOKE_PASS
```

Known acceptable warning: the main scene smoke may print Godot dummy-renderer RID cleanup warnings at process exit. Exit code must still be `0`.

- [ ] **Step 4: Commit catalog smoke test**

Run:

```powershell
git add -- tests/brotato_data_catalog_smoke.gd
git commit -m "test: add Brotato catalog smoke coverage"
```

Expected: commit succeeds with one new test file. If Godot creates `tests/brotato_data_catalog_smoke.gd.uid`, inspect it and include it in the commit.

## Task 4: Update Documentation

**Files:**
- Modify: `docs/PROGRESS.md`
- Modify: `docs/architecture.md`
- Modify: `docs/brotato-fidelity/fidelity-audit.md`

- [ ] **Step 1: Update `docs/PROGRESS.md` Phase D checklist**

Change the Phase D section to:

```markdown
### Brotato Fidelity Phase D Content Data
- [x] Content-data design spec for Brotato-like non-art catalogs
- [x] Phase D0 implementation plan
- [x] JSON catalog shell and seed data
- [x] `BrotatoData` loader and validator
- [x] Godot headless catalog smoke test
- [ ] Data-backed character catalog
- [ ] Data-backed weapon catalog with tier rows
- [ ] Data-backed item, upgrade, tag, and weapon-class catalogs
- [ ] Runtime migration from hardcoded pools to `BrotatoData`

Spec: `docs/superpowers/specs/2026-05-27-brotato-content-data-design.md`.

D0 plan: `docs/superpowers/plans/2026-05-27-brotato-content-data-d0.md`.

D0 verification note: `BROTATO_DATA_CATALOG_SMOKE_PASS` must be recorded after the test passes.
```

- [ ] **Step 2: Update `docs/architecture.md` data section**

Find the existing section that describes `WeaponDatabase / data/weapons.tres`.

Add this paragraph near it:

```markdown
### Brotato Content Catalog

`scripts/BrotatoData.gd` loads structured non-art content data from `data/brotato/*.json`.
The D0 catalog is a seed shell with manifest, characters, weapons, items, upgrades, tags, weapon classes, and effect schema.
Runtime systems still use existing pools until later D1-D3 migrations, but new data work should target `BrotatoData` rather than adding more canonical content to `GameState.gd`, `Shop.gd`, or `data/weapons.tres`.
```

- [ ] **Step 3: Update `docs/brotato-fidelity/fidelity-audit.md` data rows**

Find the `Character data`, `Item data`, and `Weapon upgrading and combining` rows.

Update or append a note below the table:

```markdown
## Phase D Data Catalog Status

Phase D0 adds a seed JSON catalog and `BrotatoData` validator. This is not full content completion.

- Character catalog: seed only; full target remains 62 reference characters.
- Weapon catalog: seed only; D1 must replace deterministic tier scaling with tier rows.
- Item catalog: seed only; full target remains 237 reference items for the selected reference scope.
- Runtime migration: pending; existing gameplay still uses hardcoded/local pools until D1-D3.
```

- [ ] **Step 4: Run documentation sanity check**

Run:

```powershell
rg -n "Phase D|BrotatoData|brotato-content-data-d0|BROTATO_DATA_CATALOG_SMOKE_PASS" docs
```

Expected: output references all three documentation files updated in this task.

- [ ] **Step 5: Commit docs**

Run:

```powershell
git add -- docs/PROGRESS.md docs/architecture.md docs/brotato-fidelity/fidelity-audit.md
git commit -m "docs: record Brotato catalog D0 status"
```

Expected: commit succeeds.

## Task 5: Final D0 Verification

**Files:**
- No file edits unless verification exposes a bug.

- [ ] **Step 1: Run catalog smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/brotato_data_catalog_smoke.gd"
```

Expected:

```text
BROTATO_DATA_CATALOG_SMOKE_PASS
```

- [ ] **Step 2: Run full current smoke suite**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/phase1_rules_smoke.gd"
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/phase1_main_scene_smoke.gd"
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe" --headless --path . --script "res://tests/effects_pool_scene_change_smoke.gd"
```

Expected:

```text
PHASE1_RULE_SMOKE_PASS
PHASE1_MAIN_SCENE_SMOKE_PASS
PHASE2_LOOT_WEAPON_SMOKE_PASS
EFFECTS_POOL_SCENE_CHANGE_SMOKE_PASS
```

- [ ] **Step 3: Check Git status**

Run:

```powershell
git status --short --branch
```

Expected:

```text
## master
```

- [ ] **Step 4: Check recent commits**

Run:

```powershell
git log --oneline --decorate --max-count 8
```

Expected: recent history includes these D0 commits:

```text
data: add Brotato catalog seed files
feat: add Brotato catalog loader
test: add Brotato catalog smoke coverage
docs: record Brotato catalog D0 status
```

## Self-Review Checklist

- Spec coverage: This plan implements Phase D0 only and explicitly leaves D1-D4 for later plans.
- Data shell: Task 1 creates all JSON files named in the spec.
- Loader: Task 2 creates `BrotatoData.gd` with the API named in the spec.
- Validation: Task 2 and Task 3 validate IDs, tier keys, effect schema, starting weapon references, tag references, and shop filtering.
- Runtime safety: Task 3 and Task 5 keep existing smoke tests in the verification gate.
- Clean-room boundary: Seed data uses compact structural rows and local notes, not copied long prose or assets.
- No broad migration: Runtime consumers stay untouched in D0.
