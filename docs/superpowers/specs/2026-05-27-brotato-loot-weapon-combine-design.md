# Brotato Loot And Weapon Combine Design

## Purpose

This spec defines Phase 2A of the Brotato fidelity track for `G:\ClaudeCode\Godot\brotato-gavin`.

Phase 1 made the wave loop material-first and moved level-ups/shop flow closer to Brotato. Phase 2A closes the next largest fidelity gap: wave loot resolution and weapon tier combining.

The implementation remains clean-room. It reproduces mechanics and architecture only. It must not copy original art, audio, trademarks, iconography, or bulk item text from Brotato.

## References

Reference behavior is derived from observable public rule documentation:

- Brotato Waves: wave end bags materials, picks up remaining consumables and loot crates, resolves crate rewards and level-up upgrades, then opens shop.
- Brotato Consumables: fruit heals 3 HP, ordinary crates heal 3 HP, legendary crates heal 100 HP.
- Brotato Loot Crate: crates contain an item that can be taken or recycled for 25% of its current price; crate chance is affected by Luck and by the number of crates already dropped this wave.
- Brotato Shop and Weapons: identical weapons of the same tier combine into one weapon of the next tier; buying a matching weapon while weapon slots are full auto-combines; weapons cannot combine above Tier 4.

## Current State

Relevant existing files:

- `scripts/PickupManager.gd`: spawns temporary buff pickups such as speed boost and rapid fire. It does not model Brotato fruit, crate, or legendary crate drops.
- `scripts/Main.gd`: at wave end, material pickups are bagged, then `pickup_manager.cleanup()` deletes active pickup value without crate reward resolution.
- `scripts/HUD.gd`: has dynamic panels for wave summary and upgrade choices, but no crate reward panel.
- `scripts/Shop.gd`: has shop item cards, lock/reroll, purchase, sell, and a custom weapon upgrade area.
- `scripts/PlayerCombat.gd`: equips weapons and lets the shop spend materials to upgrade a weapon from level 1 to 5.
- `scripts/PlayerUpgrades.gd`: applies item and weapon purchases.
- `data/weapons.tres`, `scripts/WeaponData.gd`, `scripts/WeaponDatabase.gd`: provide weapon definitions but no per-tier stat table yet.
- `tests/phase1_rules_smoke.gd`, `tests/phase1_main_scene_smoke.gd`: current automated smoke coverage.

Current mismatches:

- Normal enemy loot can become temporary buff pickups, which is not the Brotato baseline loot loop.
- Fruit and crates are absent as normal pickups.
- Crates do not queue take/recycle choices after the wave.
- Wave-end cleanup removes buff pickups rather than auto-collecting consumables and crates.
- Weapon progression is paid level-up to level 5 instead of same-type same-tier combining to Tier 4.
- The shop blocks all weapon purchases when six slots are full, even when the purchase should auto-combine.

## Goals

Phase 2A must:

1. Introduce Brotato-like consumable and crate pickup types.
2. Resolve remaining consumables and crates at wave end instead of deleting them.
3. Queue crate item rewards before level-up choices and before shop.
4. Let the player take crate items or recycle them for materials.
5. Replace the normal weapon progression path with same-type same-tier combine rules.
6. Allow full-slot shop weapon purchases when the bought weapon can auto-combine.
7. Preserve the existing six-weapon limit.
8. Add automated smoke coverage for loot resolution and weapon combining.
9. Update the fidelity audit and progress docs.

## Non-Goals

Phase 2A must not:

- Add the full Brotato item catalog.
- Add all original weapon stat tables.
- Add trees, gardens, or all consumable-related character/item synergies.
- Add elite/horde/Danger scheduling beyond the existing Phase 1 audit notes.
- Redesign all shop UI.
- Implement DLC-specific mechanics.
- Copy original item names/descriptions in bulk.

## Architecture

### `LootRules.gd`

Create `scripts/LootRules.gd`.

Responsibilities:

- Decide whether an enemy drops a consumable-like pickup.
- Decide whether that pickup is `fruit`, `crate`, or `legendary_crate`.
- Apply Luck to consumable and crate odds.
- Apply same-wave crate diminishing through `crates_dropped_this_wave`.
- Roll crate reward rarity using the same rarity direction as `ShopRules`.
- Calculate recycle value as 25% of current item price.

Initial Phase 2A formulas should be explicit approximations, not hidden magic:

- `fruit` is the default consumable pickup.
- `crate` is a chance upgrade from a consumable drop.
- `legendary_crate` is reserved for boss/elite paths where the project already exposes those enemy types.
- Luck modifies drop chance with `max(0.0, 1.0 + luck / 100.0)`.
- Crate chance is divided by `1 + crates_dropped_this_wave`.

Exact enemy-specific Brotato drop rates may be deferred to the enemy wave/content data phase, but the rule function signatures must allow per-enemy base rates later.

### `PickupManager.gd`

Refactor normal drop handling around these pickup kinds:

- `fruit`
- `crate`
- `legendary_crate`

Each active pickup node must store:

- `pickup_kind`
- `heal_amount`
- `crate_tier`
- `reward_seed` or equivalent deterministic reward metadata when useful

Collection behavior:

- Fruit: heal the player for 3 HP plus future consumable healing modifiers.
- Crate: heal for 3 HP and enqueue one crate reward.
- Legendary crate: heal for 100 HP and enqueue one Tier 4 crate reward.

The old temporary buff entries may remain in the file only as non-normal loot helpers for events/debugging. They must not be picked by `_try_spawn_pickup()` in normal enemy death flow.

### `Main.gd`

Wave-end order must become explicit:

1. Stop combat/spawning.
2. Recycle or clear enemies and combat-only entities.
3. Bag visible material pickups.
4. Auto-collect active fruit/crate pickups through `PickupManager`.
5. Show wave summary.
6. Resolve queued crate rewards.
7. Resolve pending level-up choices.
8. Open shop.

Add queue/state fields:

- `pending_crate_rewards: Array`
- `run_phase` should include a crate reward phase, for example `CRATE_REWARDS`.

The crate reward phase must complete before `_resolve_next_level_up_or_shop()`.

### `HUD.gd`

Add a dynamic crate reward panel separate from shop cards.

Signals:

- `crate_reward_taken(index: int)`
- `crate_reward_recycled(index: int)`

Display behavior:

- Show one queued crate reward at a time.
- Display item name, rarity, description, and recycle material value.
- Provide two actions: take and recycle.
- Hide the panel after the queue is empty and continue to level-up choices.

The visual can be rough, but the flow must be functional and readable.

### `Shop.gd`

Shop weapon purchase rules must call player capability checks instead of only checking slot count.

Target behavior:

- If the item is not a weapon, current purchase behavior remains.
- If the item is a weapon and the player has fewer than six weapons, equip it.
- If the player has six weapons and has an identical weapon at the same tier below Tier 4, buying the weapon is allowed and auto-combines.
- If the player has six weapons and cannot auto-combine, buying is blocked.

The existing custom weapon upgrade area should be removed from normal Brotato flow or changed into a manual combine area. It must not spend materials to increase weapon level during normal Phase 2A gameplay.

### `PlayerCombat.gd`

Represent weapon progression as tier 1 through tier 4.

Compatibility direction:

- Existing weapon dictionaries may keep a `level` field temporarily if broad renaming is risky.
- During Phase 2A, `level` must mean `tier`, with valid values 1, 2, 3, 4.
- `upgrade_cost` must stop driving normal weapon progression.

Add methods:

- `can_equip_or_combine_weapon(type: String, tier: int = 1) -> bool`
- `equip_or_combine_weapon(type: String, tier: int = 1) -> bool`
- `can_combine_weapon(slot_index: int) -> bool`
- `combine_weapon(slot_index: int) -> bool`

Combination rule:

- Find another equipped weapon with the same `type` and same `tier`.
- Remove one copy.
- Increase the remaining copy to `tier + 1`.
- Cap at Tier 4.
- Rebuild weapon stats from base data plus deterministic tier scaling.
- Emit `weapons_changed`.
- Re-run synergy checks.

Phase 2A tier scaling can use a documented deterministic multiplier if full per-tier weapon tables are not yet implemented. This must be recorded as a fidelity approximation in `fidelity-audit.md`.

### `PlayerUpgrades.gd`

Weapon shop purchases must call `p.combat.equip_or_combine_weapon(...)`.

If a weapon purchase cannot equip or combine after materials were spent, that is a bug. The purchase path must check first, then spend, then apply.

### `ShopRules.gd`

Keep existing Phase 1 shop generation responsibilities, but expose enough data for crate rewards:

- `get_price(base_price, rarity, wave)` can be reused for recycle value.
- Rarity roll behavior can be shared or mirrored by `LootRules`.

Phase 2A does not need to fully implement all shop rarity tables, but it must not make crate rewards bypass rarity/tier logic entirely.

## Data Model

Crate reward items can use the existing `Shop.gd` item pool for Phase 2A.

Rules:

- Crates should only roll non-weapon items in Phase 2A, matching the main Brotato distinction that weapons are shop-only while items can also come from crates.
- Locked unique item exclusion can be deferred until unique item metadata exists.
- A reward item must store the calculated `rolled_rarity`, `price`, and `recycle_value`.

Weapons:

- Shop weapon entries need a `tier` field, defaulting to `rolled_rarity + 1` only if no better tier source exists.
- Existing `WeaponData.rarity` is currently minimum/base rarity and is not enough for faithful per-tier weapon stats. Phase 2A may use `tier` over a duplicated base stat entry.

## State Flow

Normal wave end:

```text
COMBAT
  -> WAVE_END
  -> CRATE_REWARDS if pending_crate_rewards is not empty
  -> LEVEL_UPS if pending_level_ups > 0
  -> SHOP
  -> COMBAT
```

If no crates dropped, the flow goes directly from wave summary to level-up choices.

If no level-ups are pending, the flow goes directly from crate rewards to shop.

## Testing

Add `tests/phase2_loot_weapon_smoke.gd`.

Automated checks:

1. `LootRules` returns a fruit/crate/legendary crate structure with required fields.
2. Fruit collection heals the player and recycles the pickup.
3. Crate collection enqueues a crate reward and heals the player.
4. Wave-end auto-collection of active crates enqueues rewards before shop.
5. Taking a crate reward applies an upgrade and removes one pending reward.
6. Recycling a crate reward grants 25% material value and removes one pending reward.
7. Two same-type same-tier weapons combine into one next-tier weapon.
8. Tier 4 weapons do not combine above Tier 4.
9. Full-slot weapon purchase is blocked when no combine is possible.
10. Full-slot matching weapon purchase is allowed and auto-combines.

Verification command:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Do not use `Godot_v4.6.1-stable_win64_console.exe` for required verification in this worktree unless the known signal 11 issue is resolved.

Regression checks:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase1_rules_smoke.gd"
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase1_main_scene_smoke.gd"
```

Manual checks:

- Start a run.
- Confirm enemies can drop fruit/crates instead of temporary buff pickups.
- Take damage, collect fruit, and verify healing.
- Leave a crate on the map until wave end and verify it is processed.
- Take a crate item and verify the stat applies.
- Recycle a crate item and verify materials increase.
- Buy duplicate weapons and verify combine behavior.
- Fill six weapon slots and verify only matching same-tier purchases are allowed to auto-combine.

## Documentation Updates

Update:

- `docs/brotato-fidelity/fidelity-audit.md`
- `docs/PROGRESS.md`

Audit status changes after implementation:

- `Crates and consumables`: from `missing` to `aligned for Phase 2A` if fruit, crates, legendary crates, auto-pickup, and take/recycle flow work.
- `Weapon upgrading and combining`: from `partial` to `aligned for Phase 2A` if paid Lv.5 upgrading is removed from normal flow and same-tier combine works.
- `Item data`: remains `partial` because Phase 2A does not add the full item catalog.
- `Shop generation`: remains `aligned for Phase 1` or `partial for full fidelity` depending on later rarity/table work.

## Risks

### Weapon Stat Fidelity

Existing weapon data has one stat row per weapon, not a full four-tier table. Phase 2A can use deterministic tier scaling, but this is still an approximation and must be documented.

### UI Scope

The crate reward panel should be functional, not a full UI redesign. The goal is correct flow and decisions.

### Purchase Atomicity

Weapon purchase must not spend materials before proving the weapon can equip or combine.

### Legacy Upgrade Area

The current shop weapon upgrade area can mislead the gameplay back into a non-Brotato model. It should be removed from normal flow or converted into manual combine actions.

### Existing Buff Pickups

Temporary buff pickups are not part of normal Brotato loot. Leaving them in normal enemy drops would contradict the goal.

## Acceptance Criteria

- `scripts/LootRules.gd` exists and owns drop/crate/recycle rule helpers.
- `PickupManager` normal enemy drops produce fruit/crate/legendary crate pickups, not temporary buff pickups.
- Wave-end auto-collects remaining consumables and crates.
- Crate rewards are resolved before level-up choices and shop.
- Crate rewards can be taken or recycled.
- Weapon progression uses Tier 1-4 combining.
- Paid weapon level-up to Lv.5 is not part of normal shop flow.
- Full weapon slots allow auto-combine purchases only when a same-type same-tier weapon exists.
- Phase 1 smoke tests still pass through the main Godot executable.
- `tests/phase2_loot_weapon_smoke.gd` passes through the main Godot executable.
- Fidelity audit and progress docs record implemented behavior and remaining approximations.
