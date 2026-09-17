# Brotato Content Data Design

## Purpose

This spec defines the content-data phase for `G:\ClaudeCode\Godot\brotato-gavin`.

The active goal is to make the project's built-in non-art content assets and data align with Brotato as closely as possible, especially character design, character stats, weapon kinds, weapon stat tables, shop items, tags, unlock metadata, and the data structures needed for those systems.

This is a data and rules fidelity pass. It is not an art, icon, sound, UI skin, or branding pass.

## Reference Sources

Authoritative source priority for this phase:

1. Public Brotato Wiki pages and their data templates for observable gameplay data.
2. The current project implementation, where it already encodes a working mechanic that can consume reference data.
3. Local approximation notes in `docs/brotato-fidelity/fidelity-audit.md` for systems that cannot yet consume every reference field.

Reference pages inspected for this spec:

- Characters: `https://brotato.wiki.spellsandguns.com/Characters`
- Character data template: `https://brotato.wiki.spellsandguns.com/Template%3ACharacter_Data`
- Weapons: `https://brotato.wiki.spellsandguns.com/Weapons`
- Weapon data template: `https://brotato.wiki.spellsandguns.com/Template%3AWeapon_Data`
- Items: `https://brotato.wiki.spellsandguns.com/Items`

Observed reference facts that drive scope:

- The character page states there are 62 characters available and that character data is pulled from `Template:Character Data`.
- The character template exposes `stats`, `unlockedby`, `unlocks`, `unlocktype`, `wantedtags`, `isdlc`, and `startingwpns`.
- The weapon template exposes `rarity`, `types`, `damage`, `attackspeed`, `dps`, `crit`, `range`, `knockback`, `lifesteal`, `special`, `price`, `unlockedby`, `isdlc`, and `attacktype`, with tier selectors.
- The items page states there are 201 vanilla items and 36 Abyssal Terrors items, 237 total, updated for version `1.1.10.9`.

## Clean-Room Boundary

Allowed:

- Store names, IDs, numeric gameplay values, tags, unlock conditions, tiers, and compact mechanical effect descriptors needed by this project.
- Store local normalized effect IDs such as `max_hp`, `attack_speed_percent`, `weapon_class_bonus`, or `cannot_equip_melee`.
- Implement public, observable mechanics and tuning behavior.
- Use procedural placeholder visuals already present in the project.

Not allowed in this phase:

- Copy original art, icons, sprites, audio, fonts, or UI presentation assets.
- Bulk-copy original item or character flavor text.
- Treat wiki wording as source code comments or in-game prose.
- Introduce trademarked branding into the project's title or menus beyond factual developer documentation.

Where a wiki row has long prose, the local data must express the effect structurally, for example:

```json
{
  "effect_id": "pickup_material_damage_proc",
  "chance": 0.75,
  "damage_base": 1,
  "scaling": [{"stat": "luck", "coefficient": 0.15}]
}
```

not by copying the source sentence.

## Current Project State

Current content storage:

- `scripts/GameState.gd`: hardcoded `CHARACTERS` dictionary with 14 local/custom characters.
- `data/weapons.tres`: Godot resource containing 17 weapon rows, including one `Unknown` placeholder.
- `scripts/WeaponData.gd`: one flat stat row per weapon, not a full Brotato tier table.
- `scripts/WeaponDatabase.gd`: converts `WeaponData` resources into combat and shop dictionaries.
- `scripts/Shop.gd`: inline `_PASSIVE_POOL` with 49 local items/passives.
- `scripts/UpgradeChoiceRules.gd`: small hardcoded level-up choice pool.
- `scripts/PlayerUpgrades.gd`: applies only the current local effect vocabulary.

Current gaps:

- Character roster is not Brotato's roster.
- Character unique mechanics are mixed with local custom passives.
- Starting weapon options are not represented as a data list.
- Weapon data lacks per-tier rows, attack type, weapon classes, scaling coefficients, crit, knockback, lifesteal, base price per tier, unlock metadata, and DLC flags.
- Shop items are embedded in code rather than data.
- Item tags, limits, unlocks, and unique effect definitions are missing or partial.
- Level-up upgrades are not separated from shop items with a rich stat vocabulary.
- The runtime has no loader/validator that can prove catalog completeness.

## Design Goals

This phase must:

1. Move non-art content into explicit data files under `data/brotato/`.
2. Model the Brotato base game and Abyssal Terrors content separately but load them through one API.
3. Replace hardcoded character, weapon, and item pools with data-backed loaders.
4. Preserve current gameplay while expanding data coverage.
5. Represent unsupported mechanics structurally and mark them as `implemented: false` instead of hiding them.
6. Add automated validation that detects missing IDs, invalid starting weapons, malformed tier tables, invalid tags, and duplicate entries.
7. Keep this project playable after each implementation step.

## Non-Goals

This phase must not:

- Implement every unique character mechanic in one pass.
- Implement every unique item effect in one pass.
- Replace procedural placeholder visuals.
- Implement DLC maps, new enemies, or map-specific content unless required by a data field.
- Remove the current smoke tests.
- Push to a remote repository.

## Data Layout

Create this directory:

```text
data/brotato/
  catalog_manifest.json
  characters.json
  weapons.json
  items.json
  upgrades.json
  weapon_classes.json
  item_tags.json
  effect_schema.json
```

### `catalog_manifest.json`

Purpose:

- Record data version and source scope.
- Gate validation expectations.

Required fields:

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
  "source_urls": []
}
```

Weapon expected count is not fixed in this spec because the inspected wiki page is a mixed vanilla/DLC table and the implementation should validate exact IDs from `weapons.json` rather than a guessed number.

### `characters.json`

One row per character.

Required fields:

- `id`: local snake_case stable ID.
- `source_name`: reference display name.
- `display_name`: local display name. May equal source name or a localized name.
- `is_dlc`: boolean.
- `unlock`: structured unlock object.
- `unlocks`: array of item or weapon IDs.
- `wanted_tags`: array of item tag IDs.
- `starting_weapons`: array of weapon IDs that can be selected at run start.
- `fixed_starting_weapons`: array of weapon IDs automatically granted.
- `fixed_starting_items`: array of item IDs automatically granted.
- `base_stats`: normalized stat deltas.
- `rules`: structural character modifiers.
- `implemented`: boolean.
- `implementation_notes`: short local notes.

Example shape:

```json
{
  "id": "ranger",
  "source_name": "Ranger",
  "display_name": "Ranger",
  "is_dlc": false,
  "unlock": {"type": "default"},
  "unlocks": [{"type": "item", "id": "night_goggles"}],
  "wanted_tags": ["ranged_damage", "range"],
  "starting_weapons": ["pistol"],
  "fixed_starting_weapons": [],
  "fixed_starting_items": [],
  "base_stats": {"range": 50},
  "rules": [
    {"effect": "stat_modifications_multiplier", "stat": "ranged_damage", "multiplier": 1.5},
    {"effect": "forbid_weapon_group", "group": "melee"},
    {"effect": "stat_modifications_multiplier", "stat": "max_hp", "multiplier": 0.75}
  ],
  "implemented": false,
  "implementation_notes": "Data row present. Runtime restriction support pending."
}
```

### `weapons.json`

One row per weapon.

Required fields:

- `id`
- `source_name`
- `display_name`
- `is_dlc`
- `groups`: weapon class tags, for example `gun`, `precise`, `primitive`.
- `attack_kind`: `ranged`, `melee_thrust`, `melee_sweep`, `structure`, or `special`.
- `unlocked_by`
- `tiers`: object with keys `1`, `2`, `3`, `4`.
- `special_rules`: structural rules not covered by base stat fields.
- `implemented`
- `implementation_notes`

Each tier must include:

- `damage`: base value plus scaling entries.
- `cooldown`: seconds.
- `range`
- `crit_multiplier`
- `crit_chance`
- `knockback`
- `lifesteal`
- `base_price`
- Optional projectile fields: `projectiles`, `pierce`, `bounce`, `spread`, `explosion_radius`.

Example shape:

```json
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
    }
  },
  "special_rules": [],
  "implemented": true,
  "implementation_notes": "Uses current projectile path; full pierce damage falloff pending."
}
```

### `items.json`

One row per shop/crate item.

Required fields:

- `id`
- `source_name`
- `display_name`
- `is_dlc`
- `tier`: 1 to 4.
- `base_price`
- `limit`: integer or null.
- `unlocked_by`
- `tags`
- `effects`: array of structured effects.
- `implemented`
- `implementation_notes`

Item prose from the source should not be copied. Use structural effects.

### `upgrades.json`

Level-up stat upgrade choices are not the same as shop items.

Required fields:

- `id`
- `display_name`
- `tier`
- `stat`
- `value`
- `weight`
- `min_wave`
- `max_wave`
- `implemented`

### `weapon_classes.json`

Weapon class bonuses are separate from individual weapons.

Required fields:

- `id`
- `source_name`
- `thresholds`: keyed by weapon count.
- `effects`

### `item_tags.json`

Tags control shop weighting and character wanted tags.

Required fields:

- `id`
- `source_name`
- `category`
- `implemented`

### `effect_schema.json`

Purpose:

- Declare allowed effect IDs and required fields.
- Let tests validate data rows without executing all effects.

Example:

```json
{
  "stat_delta": {"required": ["stat", "value"]},
  "stat_multiplier": {"required": ["stat", "multiplier"]},
  "forbid_weapon_group": {"required": ["group"]},
  "weapon_class_bonus": {"required": ["class_id", "thresholds"]}
}
```

## Runtime Architecture

### `BrotatoData.gd`

Create `scripts/BrotatoData.gd`.

Responsibilities:

- Load all JSON files once.
- Expose dictionaries by ID.
- Expose filtered lists for base game, DLC, implemented-only, unlocked-only, and shop-eligible entries.
- Convert weapon tier data into the current combat dictionary format.
- Convert item rows into the current shop item format.
- Convert character rows into the current character-select format.
- Provide validation errors for tests and startup diagnostics.

Required API:

```gdscript
class_name BrotatoData
extends RefCounted

func load_catalog() -> Array[String]
func get_character(id: String) -> Dictionary
func get_characters(include_unimplemented: bool = true) -> Dictionary
func get_weapon(id: String) -> Dictionary
func get_weapons(include_unimplemented: bool = true) -> Dictionary
func get_items(include_unimplemented: bool = true) -> Dictionary
func get_shop_pool(include_unimplemented: bool = false) -> Array
func get_weapon_shop_entries(include_unimplemented: bool = false) -> Array
func get_level_up_choices() -> Array
func validate() -> Array[String]
```

### Integration Points

`GameState.gd`:

- Stop owning the canonical character table.
- Keep compatibility wrappers for `CHARACTERS` only during migration.
- Use `BrotatoData` to resolve selected character rows.

`CharacterSelect.gd`:

- Iterate through data-backed characters.
- Show all reference rows, with unimplemented rows disabled or marked as pending if their runtime rules are not supported yet.

`WeaponData.gd` and `WeaponDatabase.gd`:

- Keep existing `.tres` resource temporarily for compatibility.
- Add a JSON-backed path through `BrotatoData`.
- Defer deleting `data/weapons.tres` until the runtime no longer depends on it.

`PlayerCombat.gd`:

- Stop deterministic tier multipliers once tier table data is available.
- Build equipped weapon dictionaries from `weapons.json` tier rows.
- Preserve existing projectile/melee behavior for supported attack kinds.

`Shop.gd`:

- Build `ITEM_POOL` from `BrotatoData.get_shop_pool()`.
- Remove `_PASSIVE_POOL` as canonical data.
- Keep local fallback only for failed catalog load, with a visible validation failure in tests.

`UpgradeChoiceRules.gd`:

- Load choices from `upgrades.json`.
- Keep current pool only as fallback until migration finishes.

`PlayerUpgrades.gd`:

- Apply item effects from structured `effects`.
- Unsupported effects must be no-ops with explicit `implemented: false` catalog rows, not silently treated as implemented.

## Migration Phases

### Phase D0: Data Shell And Validator

Deliverables:

- Create `data/brotato/` JSON files with schema, manifest, and a small seed subset.
- Create `scripts/BrotatoData.gd`.
- Add `tests/brotato_data_catalog_smoke.gd`.

Acceptance:

- Loader validates JSON shape.
- Seed rows include at least the current default player path: one default character, one starting weapon, one shop item, one level-up choice.
- Existing smoke tests still pass.

### Phase D1: Weapon Catalog First

Deliverables:

- Replace current `data/weapons.tres` canonical source with `weapons.json`.
- Add all base-game weapon IDs and tier structures that can be represented by the current runtime.
- Mark unsupported weapons or special effects with `implemented: false`.

Acceptance:

- No `Unknown` placeholder weapon remains in the shop pool.
- Current starting weapons resolve through `BrotatoData`.
- Weapon combine tests use tier rows rather than deterministic multiplier approximations.

### Phase D2: Character Catalog

Deliverables:

- Replace `GameState.CHARACTERS` as canonical data with `characters.json`.
- Add all 62 reference character rows.
- Mark runtime-unsupported unique rules as `implemented: false`.
- Character select can show all rows and prevent selecting rows whose starting setup cannot run.

Acceptance:

- Catalog validation proves 62 character rows.
- Every starting weapon ID exists in `weapons.json`.
- At least the default reference characters with supported mechanics can start a run.

### Phase D3: Item And Upgrade Catalog

Deliverables:

- Move `_PASSIVE_POOL` into `items.json`.
- Expand toward the reference item catalog.
- Move level-up choices into `upgrades.json`.
- Add effect-schema validation.

Acceptance:

- Shop and crate rewards read from data files.
- Item rows validate tags, limits, tier, and effect schema.
- Unsupported effects are visible in validation reports and not offered in the playable shop unless explicitly allowed.

### Phase D4: Runtime Effect Coverage

Deliverables:

- Implement high-impact missing effects by group:
  - stat deltas and stat multipliers
  - weapon restrictions
  - item tags and shop weighting
  - weapon class bonuses
  - character start items and start weapons
  - unique economy and pickup rules

Acceptance:

- The playable shop can include only implemented rows by default.
- A debug flag can include unimplemented rows for data inspection.
- `fidelity-audit.md` has per-domain coverage numbers.

## Tests

Add:

- `tests/brotato_data_catalog_smoke.gd`

Required assertions:

- Manifest loads.
- Required files exist.
- Character IDs are unique.
- Weapon IDs are unique.
- Item IDs are unique.
- Every character starting weapon exists.
- Every character unlock target exists if represented.
- Every weapon has tier keys `1`, `2`, `3`, `4` unless explicitly marked non-playable.
- Every item effect matches `effect_schema.json`.
- Shop pool excludes `implemented: false` rows by default.
- Current run smoke can still instantiate `Main.tscn`.

Update existing tests:

- `phase1_main_scene_smoke.gd` should assert that player start weapon resolves through the data loader once D1 starts.
- `phase2_loot_weapon_smoke.gd` should assert that weapon tiers come from data rows once D1 starts.

## Documentation Updates

Update:

- `docs/brotato-fidelity/fidelity-audit.md`
- `docs/PROGRESS.md`
- `docs/architecture.md`

Required audit fields:

- Character catalog count.
- Weapon catalog count.
- Item catalog count.
- Implemented item effect count.
- Unsupported-but-modeled effect count.
- Runtime playable coverage.

## Risks

### Data Volume

The full catalog is large. The implementation must support staged data import and validation instead of requiring every effect to be playable immediately.

### Unsupported Effects

Many items and characters have mechanics not currently implemented. The correct behavior is to model the row and mark it unimplemented, then keep it out of normal shop/start pools until runtime support exists.

### Copyright And Text Assets

Do not bulk-copy source descriptions. Store structured effects and local implementation notes.

### Encoding

Existing project files contain Chinese text and some mojibake from earlier edits. New JSON files should use UTF-8 and keep IDs ASCII.

## Completion Criteria For The Full Goal

The broader user goal is not complete until current-state evidence proves:

1. The project has data-backed character, weapon, item, upgrade, tag, and class catalogs.
2. The catalog scope matches the selected reference version and documents base/DLC inclusion.
3. Character design and numeric data are represented structurally.
4. Weapon kinds and tier stat data are represented structurally.
5. Shop item data is represented structurally.
6. Runtime systems consume the data instead of hardcoded local pools.
7. Automated validation proves ID integrity and catalog shape.
8. Smoke tests prove the game still starts and the combat/shop loop still works.
9. The fidelity audit states remaining unsupported mechanics explicitly.

Until all nine points are verified, this goal remains active.
