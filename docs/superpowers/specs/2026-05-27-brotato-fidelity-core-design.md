# Brotato Fidelity Core Design

## Purpose

This spec defines the first concrete step toward a Brotato-faithful remake in `G:\ClaudeCode\Godot\brotato-gavin`.

The long-term objective is to make the gameplay and architecture approach current Steam Brotato as closely as possible while keeping this project legally and technically clean: reproduce mechanics, structure, tuning workflows, and systemic behavior; do not copy original art, audio, trademarks, or full copyrighted text assets.

Phase 0-1 deliberately focuses on the rules that every later character, item, weapon, enemy, and DLC-style system depends on. It is not a content-volume pass.

## Baseline

### Long-Term Reference

The long-term target is current Steam Brotato behavior, using official announcements and community-maintained reference pages as rule references where they are observable:

- Steam store page: max 6 weapons, automatic firing, material collection, wave survival, wave-end shop.
- Steam announcements: current release line continues beyond the older vanilla baseline, including newer balance/features and announced DLC direction.
- Brotato Wiki pages: waves, shop, materials, upgrades, characters, items, weapons, and danger rules.

### Phase 0-1 Reference Scope

Phase 0-1 targets the stable vanilla core loop:

1. Arena wave begins.
2. Enemies drop materials.
3. Materials both grant experience and become shop currency.
4. Wave timer ends.
5. Remaining materials and pickups are resolved instead of discarded.
6. Level-up choices are resolved after the wave.
7. Shop opens with Brotato-like reroll, lock, price, rarity, weapon/item generation rules.
8. Next wave starts.

## Current Project Summary

The project is a Godot 4.6 GDScript game with:

- Main scene flow: `MainMenu -> CharacterSelect -> Main`.
- Autoloads: `GameState`, `Effects`, `SaveSystem`.
- Combat coordinator: `scripts/Main.gd`.
- Wave coordinator: `scripts/WaveManager.gd`.
- Player coordinator plus modules: `Player.gd`, `PlayerCore.gd`, `PlayerCombat.gd`, `PlayerUpgrades.gd`, `PlayerBuffs.gd`, `PlayerStats.gd`.
- Shop implementation: `scripts/Shop.gd`.
- Pickup implementation: `scripts/PickupManager.gd`.
- XP orb implementation: `scripts/XPOrb.gd`.
- Weapon data: `data/weapons.tres`, `WeaponData.gd`, `WeaponDatabase.gd`.

Current high-value existing behavior to preserve:

- Godot 4.6 + GL Compatibility setup.
- 6-weapon player limit.
- Auto-firing weapons.
- Wave/shop loop.
- Reroll, lock, sell, and weapon upgrade UI concepts.
- Object pooling for bullets, enemies, XP orbs, pickups, effects.
- Procedural visuals and procedural audio constraints.

Current core mismatches to correct first:

- XP and gold are separate; Brotato materials should be both experience and shop currency.
- Wave duration is fixed at 20 seconds; Brotato uses a wave duration table that reaches 60 seconds and a 90-second final wave.
- Level-ups immediately auto-apply stat bonuses; Brotato queues stat upgrade choices and resolves them outside combat.
- Wave-end XP orbs are recycled; Brotato resolves uncollected materials through collection/bag behavior rather than deleting value.
- Shop generation has Brotato-like UI features but not a faithful price, rarity, Luck, early-shop, and weapon/item generation model.

## Design Goals

### Primary Goals

- Make the project architecture capable of faithfully expressing Brotato's core loop.
- Replace the split XP/gold economy with a material economy.
- Make wave timing table-driven and Brotato-like.
- Move level-up rewards from automatic stat changes to queued post-wave upgrade choices.
- Refactor shop generation around explicit rule functions that can later be tuned against reference data.
- Create durable fidelity documentation so future changes are judged against the target game instead of local intuition.

### Non-Goals For Phase 0-1

- Do not add all original Brotato characters, items, weapons, enemies, or DLC content.
- Do not copy original art, audio, iconography, trademarks, or full original item descriptions.
- Do not fully rebalance every existing weapon and enemy.
- Do not replace the whole project from scratch.
- Do not make the UI pixel-perfect.
- Do not implement every Danger difficulty rule.

## Phase 0: Fidelity Baseline Library

### Files

Create:

- `docs/brotato-fidelity/fidelity-audit.md`
- `docs/brotato-fidelity/rules-core.md`

Update:

- `docs/PROGRESS.md`

### Content Requirements

`fidelity-audit.md` must include a table with:

- System name.
- Brotato reference behavior.
- Current project behavior.
- Gap status: `aligned`, `partial`, `missing`, or `intentionally different`.
- Target files.
- Phase where the gap will be closed.

Required systems in the initial audit:

- Wave duration.
- Material economy.
- XP and level-up timing.
- Upgrade choice generation.
- Shop item generation.
- Shop reroll, lock, and price inflation.
- Material bag.
- Crates and consumables.
- Weapon limit.
- Weapon upgrading/combining.
- Character data.
- Item data.
- Enemy waves.
- Boss/elite/horde events.
- Difficulty/Danger model.

`rules-core.md` must describe Phase 1 target behavior in project terms, with no vague placeholders.

`docs/PROGRESS.md` must mention the new Brotato fidelity track and point to the audit files.

### Acceptance Criteria

- Both fidelity documents exist and are committed.
- The audit names concrete project files for every Phase 1 system.
- The audit explicitly separates long-term full fidelity from Phase 1 scope.
- The docs state the clean-room boundary: mechanics and architecture only, no copied protected assets.

## Phase 1: Core Loop Fidelity

### 1. Material Economy

Replace the current split of XP and gold with a material-first model.

#### Target Behavior

- Enemies drop material pickups.
- Collecting a material pickup:
  - increases `materials`;
  - grants XP using the same pickup value;
  - updates HUD currency and XP displays.
- Shop purchases spend `materials`.
- Existing `gold` terminology becomes legacy or is renamed behind compatibility wrappers during the transition.
- Effects that currently grant gold should grant materials.
- Wave summary should report materials gained and XP gained from materials.

#### Suggested Architecture

Create a focused economy component:

- `scripts/RunEconomy.gd`

Responsibilities:

- Own current material count.
- Track wave-start material count.
- Track material bag count.
- Apply material gains and spends.
- Emit economy update signals or provide update data to `Main.gd` and HUD.

`Player.gd` can continue exposing compatibility methods during Phase 1:

- `earn_gold(amount)` delegates to material gain.
- `gold` remains as a temporary alias if removing it would expand scope too far.

The compatibility layer must be marked as transitional in comments and in `fidelity-audit.md`.

### 2. Material Pickup And Bag

#### Target Behavior

- `XPOrb.gd` becomes or is replaced by a material pickup.
- Material pickup values are not destroyed at wave end.
- Uncollected materials enter a material bag.
- Bagged materials are returned through future material pickup flow before normal material drops are exhausted, or by a clearly documented simplified approximation if exact behavior is deferred.

#### Suggested Architecture

Create or rename:

- `scripts/MaterialPickup.gd`

Phase 1 may keep `XPOrb.tscn` for compatibility if scene churn is risky, but the behavior must be material-first and the file/doc naming debt must be tracked.

### 3. Wave Duration Table

#### Target Behavior

Wave duration must be table-driven:

- Wave 1: 20 seconds.
- Wave 2: 25 seconds.
- Wave 3: 30 seconds.
- Wave 4: 35 seconds.
- Wave 5: 40 seconds.
- Wave 6: 45 seconds.
- Wave 7: 50 seconds.
- Wave 8: 55 seconds.
- Waves 9-19: 60 seconds.
- Wave 20: 90 seconds.
- Endless mode uses an explicit rule documented in `rules-core.md`.

#### Suggested Architecture

Add a pure helper to `WaveManager.gd` or a small rules file:

- `get_wave_duration(wave: int, endless_mode: bool) -> float`

No other code should hardcode `20.0` as the wave length after Phase 1.

### 4. Post-Wave Level-Up Queue

#### Target Behavior

- Gaining enough XP does not immediately auto-apply stat bonuses.
- The player gains level count and queues one upgrade choice event per gained level.
- At wave end, before the shop opens, the game resolves queued level-ups.
- Each queued level-up shows four stat upgrade options.
- Player chooses one option.
- Reroll support exists even if Phase 1 starts with a simple cost model.
- After the queue is empty, the shop opens.

#### Suggested Architecture

Create:

- `scripts/UpgradeChoiceData.gd`
- `scripts/UpgradeChoiceRules.gd`

Extend:

- `PlayerCore.gd`: level progression queues pending upgrade choices.
- `Main.gd`: wave-end state sequence becomes `COLLECTING -> LEVEL_UPS -> SHOP`.
- `HUD.gd` or a new UI scene: display upgrade choice cards.

The existing `_apply_level_bonus()` automatic bonus function should be removed or bypassed for the fidelity path. If retained temporarily, it must not execute during normal Phase 1 flow.

### 5. Shop Rule Layer

#### Target Behavior

Shop generation must be moved behind explicit rules:

- Four shop slots.
- Lock preserves slots through reroll.
- Reroll cost increases.
- Item prices scale with wave/progression.
- Luck affects rarity.
- Early-shop weapon/item generation restrictions are represented as rules.
- Weapon and item entries have separate identity and generation pools.

#### Suggested Architecture

Create:

- `scripts/ShopRules.gd`

Responsibilities:

- Calculate reroll cost.
- Calculate item price.
- Roll rarity.
- Roll whether a slot is weapon or item.
- Generate four shop offers while respecting locked slots.

`Shop.gd` should keep UI rendering and user actions, but stop owning the rule formulas directly.

### 6. Wave-End Flow

#### Target Behavior

At wave timer end:

1. Disable combat input and spawning.
2. Resolve remaining material pickups.
3. Resolve remaining consumables/crates according to Phase 1 approximation.
4. Clear temporary combat-only entities.
5. Display wave summary.
6. Resolve pending level-up choices.
7. Open shop.

This flow must be explicit in `Main.gd` state, not an incidental ordering hidden across callbacks.

## Data Model Direction

Phase 1 should not migrate all content data, but new rules should be shaped so Phase 2 can move content into data tables cleanly.

Future data domains:

- `characters`
- `weapons`
- `items`
- `upgrade_choices`
- `enemies`
- `wave_events`
- `danger_modifiers`
- `tags`

Phase 1 code must avoid hardcoding formulas in UI files when those formulas belong to data/rules.

## Testing And Verification Strategy

Godot runtime testing is still required before claiming feature completion.

Minimum verification for Phase 1:

- Static script parse check through Godot CLI if available.
- Manual run from `MainMenu.tscn`.
- Start a run and verify wave 1 timer starts at 20 seconds.
- Force or observe wave 2 and verify timer starts at 25 seconds.
- Kill an enemy and verify material pickup increments both XP and shop currency.
- Leave materials uncollected at wave end and verify their value is not lost.
- Gain at least one level and verify upgrade choices appear after the wave, not instantly during combat.
- Buy from the shop and verify materials decrease.
- Lock one shop item, reroll, and verify the locked item stays.
- Confirm `.uid` files are either intentionally tracked or intentionally ignored before final Phase 1 commit.

Automated verification targets:

- Pure rule functions in `WaveManager.gd`, `ShopRules.gd`, and `UpgradeChoiceRules.gd` should be structured so they can be tested without running a full scene.

## Risk Register

### UI Scope Creep

The upgrade UI and shop UI could grow into a full redesign. Phase 1 accepts rough UI if the rule flow is correct.

### Existing Save Compatibility

Save data may contain old gold/achievement assumptions. Phase 1 should either migrate safely or reset run-only state without corrupting persistent unlock data.

### Naming Debt

Keeping `XPOrb` as a material pickup is acceptable only as a short transition. The debt must be documented.

### External Reference Drift

Brotato is still receiving updates. Phase 1 uses stable vanilla core rules; later phases should update `fidelity-audit.md` when new official behavior matters.

### Legal Boundary

The implementation must remain a clean-room mechanical remake. Do not import original assets or bulk-copy original text tables.

## Deliverables

Phase 0 deliverables:

- `docs/brotato-fidelity/fidelity-audit.md`
- `docs/brotato-fidelity/rules-core.md`
- Updated `docs/PROGRESS.md`

Phase 1 deliverables:

- Material-first economy path.
- Wave duration table.
- Material pickup and bag behavior.
- Post-wave level-up queue.
- Rule-driven shop generation layer.
- Explicit wave-end state flow.
- Verification notes in `docs/brotato-fidelity/fidelity-audit.md` or `docs/PROGRESS.md`.

## Open Decisions

These are intentionally fixed for Phase 1 to avoid ambiguity:

- Use vanilla core loop first, not DLC or current-patch content volume.
- Keep procedural visuals/audio.
- Preserve existing scenes unless a scene prevents the rule flow.
- Prefer compatibility wrappers over broad renames when a rename would balloon risk.
- Do not mark the whole remake complete until the full fidelity audit is green across mechanics, content, and runtime behavior.
