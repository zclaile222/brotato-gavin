# Brotato Fidelity Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Phase 0-1 Brotato-fidelity foundation: durable fidelity docs, material-first economy, Brotato-like wave durations, post-wave upgrade choices, rule-driven shop generation, and explicit wave-end sequencing.

**Architecture:** Keep the existing Godot 4.6 scene structure and coordinator pattern. Add focused rule/state scripts (`RunEconomy`, `ShopRules`, `UpgradeChoiceRules`, `UpgradeChoiceData`) and adapt existing coordinators (`Main`, `WaveManager`, `PlayerCore`, `Shop`, `HUD`) through compatibility wrappers instead of broad renames. Use current procedural visuals/audio and existing UI panels as rough carriers for the new rules.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scenes, `.tres` resources, Git, PowerShell on Windows.

---

## File Structure

Create:

- `docs/brotato-fidelity/fidelity-audit.md`: persistent gap matrix against Brotato core rules.
- `docs/brotato-fidelity/rules-core.md`: Phase 1 rule target in project terms.
- `scripts/RunEconomy.gd`: material count, wave-start snapshots, material bag, material gain/spend API.
- `scripts/ShopRules.gd`: pure shop pricing, reroll, rarity, slot type, and offer generation helpers.
- `scripts/UpgradeChoiceData.gd`: value object for stat upgrade choices.
- `scripts/UpgradeChoiceRules.gd`: pure generation/reroll/apply helpers for post-wave stat upgrades.

Modify:

- `.gitignore`: either keep `.gd.uid` tracked or explicitly document the chosen policy in comments; this plan chooses to track current Godot script `.uid` files by committing them.
- `docs/PROGRESS.md`: add the Brotato fidelity track and plan/spec pointers.
- `scripts/Main.gd`: instantiate `RunEconomy`, route material updates, explicit wave-end state, pending level-up resolution, shop opening.
- `scripts/WaveManager.gd`: replace fixed `WAVE_DURATION` usage with `get_wave_duration`.
- `scripts/Player.gd`: add transitional material/economy fields and pending upgrade queue accessors.
- `scripts/PlayerCore.gd`: change XP level-up to queue upgrade choices instead of auto-applying `_apply_level_bonus`.
- `scripts/Enemy.gd`: replace separate XP and gold reward with material pickup/value flow.
- `scripts/XPOrb.gd`: convert behavior to material pickup behavior while keeping the scene name for Phase 1 compatibility.
- `scripts/Shop.gd`: delegate offer generation and pricing to `ShopRules`; use materials label text.
- `scripts/HUD.gd`, `scripts/HUDCore.gd`, `scripts/HUDPanels.gd`: material display, wave summary wording, and upgrade choice UI entry points.
- `scripts/EventManager.gd`, `scripts/PlayerBuffs.gd`: rename reward language and route old gold effects through material-compatible APIs.

Do not modify:

- `data/weapons.tres` except if Godot rewrites resource UIDs during a runtime verification pass.
- Existing scenes unless upgrade choice UI cannot be safely built dynamically.

---

## Task 1: Worktree Hygiene And Godot UID Policy

**Files:**
- Modify: `.gitignore`
- Commit existing: `scripts/EventManager.gd.uid`, `scripts/HUDCombat.gd.uid`, `scripts/HUDCore.gd.uid`, `scripts/HUDPanels.gd.uid`, `scripts/PickupManager.gd.uid`, `scripts/PlayerBuffs.gd.uid`, `scripts/PlayerCombat.gd.uid`, `scripts/PlayerCore.gd.uid`, `scripts/PlayerStats.gd.uid`, `scripts/PlayerUpgrades.gd.uid`, `scripts/TurretManager.gd.uid`, `scripts/WaveManager.gd.uid`

- [ ] **Step 1: Inspect current untracked files**

Run:

```powershell
git status --short
```

Expected: only the existing `scripts/*.gd.uid` files are untracked before this task starts.

- [ ] **Step 2: Update `.gitignore` with UID policy**

Add this comment near the Godot ignore section:

```gitignore
# Godot script/resource UID sidecar files are tracked.
# Do not add *.uid here; they keep resource references stable across machines.
```

- [ ] **Step 3: Stage UID sidecars and `.gitignore`**

Run:

```powershell
git add -- .gitignore scripts/EventManager.gd.uid scripts/HUDCombat.gd.uid scripts/HUDCore.gd.uid scripts/HUDPanels.gd.uid scripts/PickupManager.gd.uid scripts/PlayerBuffs.gd.uid scripts/PlayerCombat.gd.uid scripts/PlayerCore.gd.uid scripts/PlayerStats.gd.uid scripts/PlayerUpgrades.gd.uid scripts/TurretManager.gd.uid scripts/WaveManager.gd.uid
```

Expected: `git status --short` shows those files staged with `A` and `.gitignore` staged with `M`.

- [ ] **Step 4: Commit worktree hygiene**

Run:

```powershell
git commit -m "chore: track Godot script UID sidecars"
```

Expected: commit succeeds and `git status --short` has no `.gd.uid` untracked files.

---

## Task 2: Phase 0 Fidelity Documentation

**Files:**
- Create: `docs/brotato-fidelity/fidelity-audit.md`
- Create: `docs/brotato-fidelity/rules-core.md`
- Modify: `docs/PROGRESS.md`

- [ ] **Step 1: Create fidelity audit doc**

Create `docs/brotato-fidelity/fidelity-audit.md` with this content:

```markdown
# Brotato Fidelity Audit

This file is the standing acceptance ledger for the Brotato-faithful remake track.

Clean-room boundary: reproduce mechanics, architecture, tuning workflow, and systemic behavior. Do not copy original art, audio, trademarks, or full original text assets.

Long-term target: current Steam Brotato behavior.

Phase 1 target: stable vanilla core loop only.

| System | Reference Behavior | Current Project Behavior | Status | Target Files | Closure Phase |
|---|---|---|---|---|---|
| Wave duration | Waves use a duration table: 20,25,30,35,40,45,50,55,60 through wave 19, and 90 on wave 20. | `WaveManager.gd` uses fixed `WAVE_DURATION = 20.0`. | missing | `scripts/WaveManager.gd` | Phase 1 |
| Material economy | Materials grant XP and are shop currency. | XP orbs and gold are separate. | missing | `scripts/RunEconomy.gd`, `scripts/XPOrb.gd`, `scripts/Enemy.gd`, `scripts/PlayerCore.gd`, `scripts/Shop.gd`, `scripts/HUDCore.gd` | Phase 1 |
| Level-up timing | Level-ups queue stat choice screens outside combat. | `PlayerCore.gd` auto-applies `_apply_level_bonus()` immediately. | missing | `scripts/PlayerCore.gd`, `scripts/UpgradeChoiceRules.gd`, `scripts/HUD.gd`, `scripts/Main.gd` | Phase 1 |
| Upgrade choices | Four stat choices are presented per queued level-up with reroll support. | No stat choice cards exist; shop passives are separate. | missing | `scripts/UpgradeChoiceData.gd`, `scripts/UpgradeChoiceRules.gd`, `scripts/HUD.gd` | Phase 1 |
| Shop generation | Four slots; rarity and slot pools are rule-driven; Luck affects rarity; early shops have restrictions. | `Shop.gd` owns a local weighted pool and price multipliers. | partial | `scripts/ShopRules.gd`, `scripts/Shop.gd` | Phase 1 |
| Reroll and lock | Reroll spends currency and lock preserves slots. | Already present, but formula and currency are not material-based. | partial | `scripts/Shop.gd`, `scripts/ShopRules.gd` | Phase 1 |
| Material bag | Uncollected material value is not lost and returns through future collection. | Visible XP orbs are returned to pool at wave end. | missing | `scripts/RunEconomy.gd`, `scripts/Main.gd`, `scripts/XPOrb.gd` | Phase 1 |
| Crates and consumables | Wave-end pickups resolve in a defined order. | Buff pickups exist; crate behavior is absent. | missing | `scripts/PickupManager.gd`, `scripts/Main.gd` | Phase 2 |
| Weapon limit | Six weapon slots. | `Player.gd` has `MAX_WEAPONS = 6`. | aligned | `scripts/Player.gd` | Done |
| Weapon upgrading and combining | Weapon levels and merging rules are part of core build progression. | Weapon level upgrades exist through shop area, but combine rules are not faithful. | partial | `scripts/PlayerCombat.gd`, `scripts/Shop.gd` | Phase 2 |
| Character data | Large character roster with restrictions and unique modifiers. | 14 local characters with original rules. | partial | `scripts/GameState.gd` | Phase 2 |
| Item data | Large item pool with tags, limits, unlocks, and scaling. | Local passive pool in `Shop.gd`. | partial | `scripts/Shop.gd`, future data files | Phase 2 |
| Enemy waves | Enemy pools and elite/horde events follow progression rules. | Custom enemy pool and modifiers exist. | partial | `scripts/WaveManager.gd`, `scripts/Enemy.gd` | Phase 2 |
| Boss/elite/horde events | Timed event structure affects wave pacing. | Boss waves and custom modifiers exist. | partial | `scripts/WaveManager.gd`, `scripts/HUD.gd` | Phase 2 |
| Difficulty/Danger model | Danger levels define difficulty modifiers and unlock gates. | Simple difficulty multiplier and dynamic scaling exist. | partial | `scripts/GameState.gd`, `scripts/WaveManager.gd` | Phase 2 |

## Phase 1 Verification Ledger

Update this section after implementation.

| Check | Evidence |
|---|---|
| Wave 1 starts at 20 seconds | Not verified |
| Wave 2 starts at 25 seconds | Not verified |
| Material pickup increases XP and shop currency | Not verified |
| Uncollected material enters material bag | Not verified |
| Queued level-up choice appears after wave | Not verified |
| Shop purchase spends materials | Not verified |
| Locked shop slot survives reroll | Not verified |
```

- [ ] **Step 2: Create core rules doc**

Create `docs/brotato-fidelity/rules-core.md` with this content:

```markdown
# Brotato Core Rules For Phase 1

This document translates the approved Phase 0-1 spec into project-level rules.

## Wave Durations

`WaveManager.get_wave_duration(wave, endless_mode)` returns:

| Wave | Duration |
|---|---:|
| 1 | 20 |
| 2 | 25 |
| 3 | 30 |
| 4 | 35 |
| 5 | 40 |
| 6 | 45 |
| 7 | 50 |
| 8 | 55 |
| 9-19 | 60 |
| 20 | 90 |
| 21+ endless | 60 |

## Materials

Materials are the run currency and XP source.

When a material pickup with value `n` is collected:

1. Add `n` to current materials.
2. Add `n * xp_boost` to XP.
3. Update material and XP UI.

The transitional `gold` field stays during Phase 1 as an alias for current materials.

## Material Bag

At wave end, visible material pickup values are added to `material_bag`.

When future material pickups are spawned, bagged material value is paid out before normal drop value. Phase 1 may pay the entire bag into the next material pickup if exact per-drop behavior is not yet modeled.

## Level-Up Queue

XP thresholds can create multiple pending level-ups.

Level-up effects are not auto-applied during combat. Each level queues one post-wave upgrade choice.

Wave-end sequence:

1. Resolve uncollected materials.
2. Show wave summary.
3. Resolve each pending level-up.
4. Open shop.

## Upgrade Choices

Each queued level-up generates four choices from `UpgradeChoiceRules`.

Phase 1 stat choice pool:

| ID | Name | Apply Effect |
|---|---|---|
| max_hp | Max HP | `max_hp += value`, `hp += value` |
| damage | Damage | `damage_bonus += value` |
| attack_speed | Attack Speed | `fire_rate_multiplier += value` |
| speed | Speed | `speed += value`, `base_speed += value` |
| armor | Armor | `armor += value` |
| crit_chance | Crit Chance | `crit_chance += value` capped at 0.8 |
| luck | Luck | `luck += value` |
| harvesting | Harvesting Approximation | `gold_per_wave += value` as a Phase 1 approximation |

## Shop

Shop UI keeps four slots, lock, reroll, purchase, sell, and weapon upgrade panels.

`ShopRules` owns:

- `get_reroll_cost(reroll_index)`.
- `get_price(base_price, rarity, wave)`.
- `roll_rarity(wave, luck)`.
- `roll_slot_type(wave, slot_index)`.
- `roll_offers(pool, wave, luck, locked_items)`.

All visible shop text should say `Materials` or `材料`, not `金币`.
```

- [ ] **Step 3: Update progress doc**

Append this section near the top of `docs/PROGRESS.md`:

```markdown
## Brotato Fidelity Track

Approved spec: `docs/superpowers/specs/2026-05-27-brotato-fidelity-core-design.md`.

Implementation plan: `docs/superpowers/plans/2026-05-27-brotato-fidelity-core.md`.

Phase 0 creates the standing fidelity audit and core rule reference under `docs/brotato-fidelity/`.

Phase 1 replaces the split XP/gold loop with a material-first loop, table-driven wave durations, post-wave upgrade choices, material bag handling, rule-driven shop generation, and explicit wave-end sequencing.
```

- [ ] **Step 4: Commit Phase 0 docs**

Run:

```powershell
git add -- docs/brotato-fidelity/fidelity-audit.md docs/brotato-fidelity/rules-core.md docs/PROGRESS.md
git commit -m "docs: add Brotato fidelity audit"
```

Expected: a documentation-only commit.

---

## Task 3: Add Run Economy Component

**Files:**
- Create: `scripts/RunEconomy.gd`
- Modify: `scripts/Main.gd`
- Modify: `scripts/Player.gd`
- Modify: `scripts/PlayerCore.gd`
- Modify: `scripts/HUDCore.gd`

- [ ] **Step 1: Create `RunEconomy.gd`**

Create `scripts/RunEconomy.gd`:

```gdscript
class_name RunEconomy
extends Node

signal materials_changed(materials: int)
signal material_bag_changed(material_bag: int)

var materials: int = 0
var wave_start_materials: int = 0
var material_bag: int = 0

func reset(starting_materials: int = 0):
	materials = max(0, starting_materials)
	wave_start_materials = materials
	material_bag = 0
	materials_changed.emit(materials)
	material_bag_changed.emit(material_bag)

func begin_wave_snapshot():
	wave_start_materials = materials

func gain_materials(amount: int) -> int:
	var gained = max(0, amount)
	materials += gained
	materials_changed.emit(materials)
	return gained

func spend_materials(amount: int) -> bool:
	var cost = max(0, amount)
	if materials < cost:
		return false
	materials -= cost
	materials_changed.emit(materials)
	return true

func add_to_bag(amount: int):
	var gained = max(0, amount)
	material_bag += gained
	material_bag_changed.emit(material_bag)

func consume_bag_for_drop(base_value: int) -> int:
	var value = max(0, base_value)
	if material_bag <= 0:
		return value
	var bag_value = material_bag
	material_bag = 0
	material_bag_changed.emit(material_bag)
	return value + bag_value

func get_wave_material_gain() -> int:
	return materials - wave_start_materials
```

- [ ] **Step 2: Wire economy into `Main.gd`**

Modify manager declarations and `_ready()`:

```gdscript
var economy: RunEconomy

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	economy = RunEconomy.new()
	economy.name = "RunEconomy"
	add_child(economy)
	economy.reset(0)
```

After `hud = HUD_SCENE.instantiate()` and `add_child(hud)`, connect:

```gdscript
economy.materials_changed.connect(hud.update_gold)
```

When `player` is found, assign:

```gdscript
player.economy = economy
economy.reset(player.gold)
```

- [ ] **Step 3: Add player economy reference**

In `scripts/Player.gd`, add near progress fields:

```gdscript
var economy: RunEconomy = null
var pending_level_ups: int = 0
```

Keep `gold` as transitional compatibility:

```gdscript
var gold = 0 # Transitional alias for current materials during Phase 1.
```

- [ ] **Step 4: Change `PlayerCore.earn_gold` into material-compatible API**

Replace `earn_gold` in `scripts/PlayerCore.gd`:

```gdscript
func earn_gold(amount):
	var gained = max(0, int(amount))
	if p.economy != null:
		p.economy.gain_materials(gained)
		p.gold = p.economy.materials
	else:
		p.gold += gained
	p.gold_changed.emit(p.gold)
```

Add a new method:

```gdscript
func spend_materials(amount: int) -> bool:
	var cost = max(0, amount)
	if p.economy != null:
		var ok = p.economy.spend_materials(cost)
		p.gold = p.economy.materials
		p.gold_changed.emit(p.gold)
		return ok
	if p.gold < cost:
		return false
	p.gold -= cost
	p.gold_changed.emit(p.gold)
	return true
```

- [ ] **Step 5: Expose spend method on Player**

In `scripts/Player.gd`, add:

```gdscript
func spend_materials(amount: int) -> bool:
	return core.spend_materials(amount)
```

- [ ] **Step 6: Rename HUD currency label text**

In `scripts/HUDCore.gd`, replace:

```gdscript
func update_gold(gold):
	hud.gold_label.text = "💰 金币: %d" % gold
```

with:

```gdscript
func update_gold(materials):
	hud.gold_label.text = "材料: %d" % materials
```

- [ ] **Step 7: Run static parse check**

Run:

```powershell
Get-Command godot -ErrorAction SilentlyContinue
```

If `godot` exists, run:

```powershell
godot --headless --path . --quit
```

Expected: project loads without parse errors. If `godot` is absent, record that manual Godot verification remains required.

- [ ] **Step 8: Commit economy component**

Run:

```powershell
git add -- scripts/RunEconomy.gd scripts/Main.gd scripts/Player.gd scripts/PlayerCore.gd scripts/HUDCore.gd
git commit -m "feat: add material economy foundation"
```

---

## Task 4: Wave Duration Table

**Files:**
- Modify: `scripts/WaveManager.gd`
- Modify: `docs/brotato-fidelity/fidelity-audit.md`

- [ ] **Step 1: Replace fixed wave constant with table**

In `scripts/WaveManager.gd`, replace:

```gdscript
const WAVE_DURATION = 20.0
```

with:

```gdscript
const WAVE_DURATION_TABLE = {
	1: 20.0,
	2: 25.0,
	3: 30.0,
	4: 35.0,
	5: 40.0,
	6: 45.0,
	7: 50.0,
	8: 55.0,
	20: 90.0,
}
const DEFAULT_WAVE_DURATION = 60.0
```

- [ ] **Step 2: Add duration helper**

Add after `setup`:

```gdscript
func get_wave_duration(wave_num: int, endless_mode: bool = false) -> float:
	if endless_mode and wave_num > TOTAL_WAVES:
		return DEFAULT_WAVE_DURATION
	return WAVE_DURATION_TABLE.get(wave_num, DEFAULT_WAVE_DURATION)
```

- [ ] **Step 3: Initialize timer through helper**

Replace:

```gdscript
var wave_timer = WAVE_DURATION
```

with:

```gdscript
var wave_timer = 20.0
```

At the end of `setup`, add:

```gdscript
wave_timer = get_wave_duration(main.wave, GameState.endless_mode)
```

- [ ] **Step 4: Use helper on wave advance**

In `advance_wave`, replace:

```gdscript
wave_timer = WAVE_DURATION
```

with:

```gdscript
wave_timer = get_wave_duration(main.wave, GameState.endless_mode)
```

- [ ] **Step 5: Search for fixed duration**

Run:

```powershell
rg -n "WAVE_DURATION|20\\.0" scripts/WaveManager.gd scripts/Main.gd
```

Expected: no `WAVE_DURATION = 20.0` remains. `20.0` may appear inside the duration table for wave 1.

- [ ] **Step 6: Update audit**

In `docs/brotato-fidelity/fidelity-audit.md`, change Wave duration status from `missing` to `aligned for Phase 1` and evidence text to:

```markdown
Implemented by `WaveManager.get_wave_duration`.
```

- [ ] **Step 7: Commit wave duration**

Run:

```powershell
git add -- scripts/WaveManager.gd docs/brotato-fidelity/fidelity-audit.md
git commit -m "feat: add Brotato wave duration table"
```

---

## Task 5: Material Pickup And Bag

**Files:**
- Modify: `scripts/XPOrb.gd`
- Modify: `scripts/Enemy.gd`
- Modify: `scripts/Main.gd`
- Modify: `docs/brotato-fidelity/fidelity-audit.md`

- [ ] **Step 1: Convert XP orb fields to material fields**

In `scripts/XPOrb.gd`, add compatibility names:

```gdscript
var material_value = 1
var xp_value = 1 # Transitional alias for scene compatibility.
```

Replace `activate` with:

```gdscript
func activate(pos: Vector2, value: int):
	position = pos
	material_value = max(0, value)
	xp_value = material_value
	scale = Vector2(1, 1)
	player = get_tree().get_first_node_in_group("player")
	_active = true
	visible = true
	set_process(true)
```

- [ ] **Step 2: Collect materials and XP together**

Replace `_on_body_entered` collection body with:

```gdscript
if body.is_in_group("player"):
	Effects.hit_spark(position, Color(0.3, 1, 0.4))
	if body.has_method("earn_gold"):
		body.earn_gold(material_value)
	if body.has_method("gain_xp"):
		body.gain_xp(material_value)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.06)
	tw.tween_property(self, "scale", Vector2(0.0, 0.0), 0.1)
	tw.tween_callback(_return_to_pool)
```

- [ ] **Step 3: Feed material bag into drops**

In `scripts/Enemy.gd`, replace `_drop_xp` with:

```gdscript
func _drop_xp():
	var main = get_parent()
	var drop_value = xp_drop
	if main != null and "economy" in main and main.economy != null:
		drop_value = main.economy.consume_bag_for_drop(drop_value)
	var use_pool = main.has_method("get_xp_orb")
	if use_pool:
		var orb = main.get_xp_orb()
		orb.activate(position, drop_value)
	else:
		var orb = XP_ORB_SCENE.instantiate()
		orb.position = position
		orb.xp_value = drop_value
		if "material_value" in orb:
			orb.material_value = drop_value
		main.add_child(orb)
```

- [ ] **Step 4: Remove separate enemy gold payout**

In `Enemy.take_damage`, remove:

```gdscript
if player != null and is_instance_valid(player):
	player.earn_gold(gold_value)
```

If reward pacing becomes too low during manual testing, adjust `xp_drop` values in `Enemy.setup` in a separate tuning commit, not in this mechanics commit.

- [ ] **Step 5: Add wave-end material bag collection**

In `Main._on_wave_ended`, replace:

```gdscript
for orb in xp_orb_pool:
	if orb.visible and orb.has_method("_return_to_pool"):
		orb._return_to_pool()
```

with:

```gdscript
for orb in xp_orb_pool:
	if orb.visible:
		var value = orb.material_value if "material_value" in orb else orb.xp_value
		if economy != null:
			economy.add_to_bag(value)
		if orb.has_method("_return_to_pool"):
			orb._return_to_pool()
```

- [ ] **Step 6: Update audit**

In `fidelity-audit.md`, update:

- Material economy status to `partial`.
- Material bag status to `partial`.
- Evidence: material pickups now grant materials and XP, and visible pickups enter `RunEconomy.material_bag`.

- [ ] **Step 7: Commit material pickup**

Run:

```powershell
git add -- scripts/XPOrb.gd scripts/Enemy.gd scripts/Main.gd docs/brotato-fidelity/fidelity-audit.md
git commit -m "feat: convert XP orbs to material pickups"
```

---

## Task 6: Post-Wave Upgrade Choice Rules

**Files:**
- Create: `scripts/UpgradeChoiceData.gd`
- Create: `scripts/UpgradeChoiceRules.gd`
- Modify: `scripts/Player.gd`
- Modify: `scripts/PlayerCore.gd`
- Modify: `docs/brotato-fidelity/fidelity-audit.md`

- [ ] **Step 1: Create data object**

Create `scripts/UpgradeChoiceData.gd`:

```gdscript
class_name UpgradeChoiceData
extends RefCounted

var id: String
var name: String
var desc: String
var rarity: int
var value

func _init(p_id: String, p_name: String, p_desc: String, p_rarity: int, p_value):
	id = p_id
	name = p_name
	desc = p_desc
	rarity = p_rarity
	value = p_value

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"desc": desc,
		"rarity": rarity,
		"value": value,
	}
```

- [ ] **Step 2: Create upgrade rules**

Create `scripts/UpgradeChoiceRules.gd`:

```gdscript
class_name UpgradeChoiceRules
extends RefCounted

const CHOICE_POOL = [
	{"id": "max_hp", "name": "Max HP", "desc": "Max HP +3", "rarity": 0, "value": 3},
	{"id": "damage", "name": "Damage", "desc": "Damage +1", "rarity": 0, "value": 1},
	{"id": "attack_speed", "name": "Attack Speed", "desc": "Attack speed +8%", "rarity": 0, "value": 0.08},
	{"id": "speed", "name": "Speed", "desc": "Speed +20", "rarity": 0, "value": 20},
	{"id": "armor", "name": "Armor", "desc": "Armor +1", "rarity": 1, "value": 1},
	{"id": "crit_chance", "name": "Crit Chance", "desc": "Crit chance +5%", "rarity": 1, "value": 0.05},
	{"id": "luck", "name": "Luck", "desc": "Luck +5", "rarity": 1, "value": 5},
	{"id": "harvesting", "name": "Harvesting", "desc": "Materials at wave start +2", "rarity": 1, "value": 2},
]

func generate_choices(level: int, luck: int, count: int = 4) -> Array:
	var pool = CHOICE_POOL.duplicate(true)
	pool.shuffle()
	var choices: Array = []
	for item in pool:
		choices.append(item.duplicate(true))
		if choices.size() >= count:
			break
	return choices

func apply_choice(player, choice: Dictionary):
	match choice.id:
		"max_hp":
			player.max_hp += int(choice.value)
			player.hp = min(player.hp + int(choice.value), player.max_hp)
			player.hp_changed.emit(player.hp, player.max_hp)
		"damage":
			player.damage_bonus += int(choice.value)
		"attack_speed":
			player.fire_rate_multiplier += float(choice.value)
		"speed":
			player.speed += int(choice.value)
			player.base_speed += int(choice.value)
		"armor":
			player.armor += int(choice.value)
		"crit_chance":
			player.crit_chance = min(player.crit_chance + float(choice.value), 0.8)
		"luck":
			player.luck += int(choice.value)
		"harvesting":
			player.gold_per_wave += int(choice.value)
```

- [ ] **Step 3: Add upgrade rules object to Player**

In `scripts/Player.gd`, add:

```gdscript
var upgrade_choice_rules: UpgradeChoiceRules
var current_upgrade_choices: Array = []
```

In `_ready()`, after module initialization:

```gdscript
upgrade_choice_rules = UpgradeChoiceRules.new()
```

Add methods:

```gdscript
func has_pending_level_ups() -> bool:
	return pending_level_ups > 0

func pop_upgrade_choices() -> Array:
	if pending_level_ups <= 0:
		current_upgrade_choices = []
		return []
	current_upgrade_choices = upgrade_choice_rules.generate_choices(level, luck, 4)
	return current_upgrade_choices

func apply_upgrade_choice(index: int):
	if index < 0 or index >= current_upgrade_choices.size():
		return
	upgrade_choice_rules.apply_choice(self, current_upgrade_choices[index])
	pending_level_ups = max(0, pending_level_ups - 1)
	current_upgrade_choices = []
```

- [ ] **Step 4: Queue level-ups instead of auto-applying**

In `PlayerCore.gd`, replace `gain_xp` with:

```gdscript
func gain_xp(amount):
	p.xp += int(amount * p.xp_boost)
	while p.xp >= p.xp_to_next:
		p.xp -= p.xp_to_next
		p.level += 1
		p.pending_level_ups += 1
		p.xp_to_next = int(p.xp_to_next * 1.4)
		if p.has_node("/root/AudioManager"):
			p.get_node("/root/AudioManager").play_level_up()
		p.level_up.emit(p.level)
		Effects.level_up_burst(p.position)
	p.xp_changed.emit(p.xp, p.xp_to_next)
```

Leave `_apply_level_bonus()` in file for one commit, but do not call it. Add this comment above it:

```gdscript
# Transitional legacy function. Phase 1 queues post-wave upgrade choices instead of calling this.
```

- [ ] **Step 5: Commit upgrade rules**

Run:

```powershell
git add -- scripts/UpgradeChoiceData.gd scripts/UpgradeChoiceRules.gd scripts/Player.gd scripts/PlayerCore.gd docs/brotato-fidelity/fidelity-audit.md
git commit -m "feat: queue post-wave upgrade choices"
```

---

## Task 7: Upgrade Choice UI And Wave-End Sequencing

**Files:**
- Modify: `scripts/HUD.gd`
- Modify: `scripts/Main.gd`
- Modify: `docs/brotato-fidelity/fidelity-audit.md`

- [ ] **Step 1: Add HUD signal and panel fields**

In `scripts/HUD.gd`, add signals near existing signals:

```gdscript
signal upgrade_choice_selected(index: int)
signal upgrade_choice_rerolled
```

Add fields near wave summary fields:

```gdscript
var upgrade_panel: PanelContainer = null
var upgrade_choice_buttons: Array = []
```

- [ ] **Step 2: Build dynamic upgrade panel**

Add to `_ready()`:

```gdscript
_build_upgrade_choice_panel()
```

Add this method:

```gdscript
func _build_upgrade_choice_panel():
	upgrade_panel = PanelContainer.new()
	upgrade_panel.name = "UpgradeChoicePanel"
	upgrade_panel.visible = false
	upgrade_panel.set_anchors_preset(Control.PRESET_CENTER)
	upgrade_panel.custom_minimum_size = Vector2(760, 260)
	add_child(upgrade_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	upgrade_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title = Label.new()
	title.name = "Title"
	title.text = "Choose an upgrade"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var row = HBoxContainer.new()
	row.name = "ChoiceRow"
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(170, 120)
		btn.pressed.connect(func(index = i): upgrade_choice_selected.emit(index))
		row.add_child(btn)
		upgrade_choice_buttons.append(btn)
```

- [ ] **Step 3: Add HUD display method**

Add:

```gdscript
func show_upgrade_choices(choices: Array):
	for i in range(upgrade_choice_buttons.size()):
		var btn = upgrade_choice_buttons[i]
		if i < choices.size():
			var c = choices[i]
			btn.text = "%s\n%s" % [c.name, c.desc]
			btn.visible = true
		else:
			btn.visible = false
	upgrade_panel.visible = true

func hide_upgrade_choices():
	if upgrade_panel:
		upgrade_panel.visible = false
```

- [ ] **Step 4: Add explicit wave-end state in Main**

In `scripts/Main.gd`, add enum and state fields:

```gdscript
enum RunPhase { COMBAT, WAVE_END, LEVEL_UPS, SHOP, GAME_OVER }
var run_phase = RunPhase.COMBAT
```

In `_ready()`, connect:

```gdscript
hud.upgrade_choice_selected.connect(_on_upgrade_choice_selected)
```

- [ ] **Step 5: Split shop opening into a function**

Create in `Main.gd`:

```gdscript
func _open_shop_after_rewards():
	run_phase = RunPhase.SHOP
	var materials = economy.materials if economy != null else player.gold
	if materials > max_gold_held:
		max_gold_held = materials
	var luck = player.luck if player and is_instance_valid(player) else 0
	shop.open(wave, materials, luck, player)
```

- [ ] **Step 6: Resolve queued upgrades before shop**

Add:

```gdscript
func _resolve_next_level_up_or_shop():
	if player and is_instance_valid(player) and player.has_pending_level_ups():
		run_phase = RunPhase.LEVEL_UPS
		var choices = player.pop_upgrade_choices()
		hud.show_upgrade_choices(choices)
	else:
		hud.hide_upgrade_choices()
		_open_shop_after_rewards()

func _on_upgrade_choice_selected(index: int):
	if not player or not is_instance_valid(player):
		return
	player.apply_upgrade_choice(index)
	hud.update_level(player.level)
	hud.update_xp(player.xp, player.xp_to_next)
	_resolve_next_level_up_or_shop()
```

- [ ] **Step 7: Route wave end to upgrade resolution**

In `_on_wave_ended`, replace the final shop-opening block:

```gdscript
var gold = player.gold if player and is_instance_valid(player) else 0
if gold > max_gold_held:
	max_gold_held = gold
var luck = player.luck if player and is_instance_valid(player) else 0
shop.open(wave, gold, luck, player)
```

with:

```gdscript
_resolve_next_level_up_or_shop()
```

- [ ] **Step 8: Commit upgrade UI sequence**

Run:

```powershell
git add -- scripts/HUD.gd scripts/Main.gd docs/brotato-fidelity/fidelity-audit.md
git commit -m "feat: resolve level-up choices before shop"
```

---

## Task 8: ShopRules And Material Shop

**Files:**
- Create: `scripts/ShopRules.gd`
- Modify: `scripts/Shop.gd`
- Modify: `scripts/Main.gd`
- Modify: `docs/brotato-fidelity/fidelity-audit.md`

- [ ] **Step 1: Create shop rules**

Create `scripts/ShopRules.gd`:

```gdscript
class_name ShopRules
extends RefCounted

func get_reroll_cost(reroll_index: int) -> int:
	return 5 + max(0, reroll_index) * 5

func get_price(base_price: int, rarity: int, wave: int) -> int:
	var rarity_mult = [1.0, 1.5, 2.5, 4.0][clamp(rarity, 0, 3)]
	var wave_mult = 1.0 + max(0, wave - 1) * 0.06
	return max(1, int(round(base_price * rarity_mult * wave_mult)))

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
			var type_ok = item.get("type", "item") == "weapon" if slot_type == "weapon" else item.get("type", "item") != "weapon"
			return type_ok and item.name not in seen
		)
		if candidates.is_empty():
			candidates = item_pool.filter(func(item): return item.name not in seen)
		var chosen = candidates[randi() % candidates.size()].duplicate(true)
		chosen["rolled_rarity"] = max(chosen.get("rarity", 0), roll_rarity(wave, luck))
		seen.append(chosen.name)
		result.append(chosen)
	return result
```

- [ ] **Step 2: Add rules object to Shop**

In `scripts/Shop.gd`, add:

```gdscript
var shop_rules := ShopRules.new()
var reroll_index = 0
```

In `open`, replace:

```gdscript
reroll_cost = 5
```

with:

```gdscript
reroll_index = 0
reroll_cost = shop_rules.get_reroll_cost(reroll_index)
```

- [ ] **Step 3: Delegate item rolling**

Replace `_roll_items()` with:

```gdscript
func _roll_items():
	var preserved: Dictionary = {}
	for i in locked_indices:
		if i < current_items.size():
			preserved[i] = current_items[i]
	current_items = shop_rules.roll_offers(ITEM_POOL, wave_num, player_luck, preserved, current_items)
	_build_item_cards()
```

- [ ] **Step 4: Delegate pricing**

In `_make_card`, replace:

```gdscript
var rarity = item.get("rarity", 0)
```

with:

```gdscript
var rarity = item.get("rolled_rarity", item.get("rarity", 0))
```

Replace all `int(item.price * RARITY_PRICE_MULT[rarity])` in `Shop.gd` with:

```gdscript
shop_rules.get_price(item.price, rarity, wave_num)
```

- [ ] **Step 5: Change shop label wording**

Replace visible labels:

```gdscript
"💰 金币: %d"
"💰 %d 金币"
"重新刷新 (%d金币)"
"出售(+%d金)"
```

with:

```gdscript
"材料: %d"
"%d 材料"
"重新刷新 (%d材料)"
"出售(+%d材料)"
```

- [ ] **Step 6: Spend through player API**

In `_on_buy_pressed`, before reducing `player_gold`, use:

```gdscript
if player_ref and player_ref.has_method("spend_materials"):
	if not player_ref.spend_materials(actual_price):
		return
	player_gold = player_ref.gold
else:
	player_gold -= actual_price
```

Do not subtract `player_gold` a second time.

- [ ] **Step 7: Update reroll through player API**

In `_on_reroll_pressed`, use:

```gdscript
if player_ref and player_ref.has_method("spend_materials"):
	if not player_ref.spend_materials(reroll_cost):
		return
	player_gold = player_ref.gold
else:
	if player_gold < reroll_cost:
		return
	player_gold -= reroll_cost
reroll_index += 1
reroll_cost = shop_rules.get_reroll_cost(reroll_index)
```

- [ ] **Step 8: Commit shop rules**

Run:

```powershell
git add -- scripts/ShopRules.gd scripts/Shop.gd scripts/Main.gd docs/brotato-fidelity/fidelity-audit.md
git commit -m "feat: move shop generation to rules layer"
```

---

## Task 9: Complete Wave-End Material Summary And Event Compatibility

**Files:**
- Modify: `scripts/Main.gd`
- Modify: `scripts/HUDPanels.gd`
- Modify: `scripts/EventManager.gd`
- Modify: `scripts/PlayerBuffs.gd`
- Modify: `docs/brotato-fidelity/fidelity-audit.md`
- Modify: `docs/PROGRESS.md`

- [ ] **Step 1: Snapshot materials at wave start**

In `WaveManager.advance_wave`, replace:

```gdscript
main.wave_gold_start = main.player.gold
```

with:

```gdscript
if main.economy != null:
	main.economy.begin_wave_snapshot()
main.wave_gold_start = main.player.gold
```

- [ ] **Step 2: Calculate wave material gain**

In `Main._on_wave_ended`, replace earned gold calculation:

```gdscript
earned_gold = player.gold - wave_gold_start
```

with:

```gdscript
earned_gold = economy.get_wave_material_gain() if economy != null else player.gold - wave_gold_start
```

- [ ] **Step 3: Change wave summary wording**

In `HUDPanels.show_wave_summary`, replace:

```gdscript
hud.wave_summary_stats.text = "击杀: %d    金币: +%d    XP: +%d" % [p_kills, p_gold, p_xp]
```

with:

```gdscript
hud.wave_summary_stats.text = "击杀: %d    材料: +%d    XP: +%d" % [p_kills, p_gold, p_xp]
```

- [ ] **Step 4: Update EventManager material wording**

Replace user-facing `金币` strings in `scripts/EventManager.gd` with `材料`.

Replace direct spend:

```gdscript
main.player.gold -= evt.cost
main.player.gold_changed.emit(main.player.gold)
```

with:

```gdscript
if not main.player.spend_materials(evt.cost):
	return
```

- [ ] **Step 5: Keep PlayerBuffs compatible**

In `scripts/PlayerBuffs.gd`, keep calls to `p.core.earn_gold(...)`; they now route to materials. Update notification/comment language from gold to materials if present.

- [ ] **Step 6: Update docs**

Update `fidelity-audit.md` Phase 1 ledger entries from `Not verified` to `Implemented; runtime verification pending` for systems implemented by Tasks 3-9.

Update `docs/PROGRESS.md` with:

```markdown
### Brotato Fidelity Phase 1 Core Loop
- [x] Material-first economy foundation
- [x] Brotato-like wave duration table
- [x] Material pickup grants XP and currency
- [x] Uncollected material bag approximation
- [x] Post-wave level-up choice queue
- [x] Rule-driven shop generation
- [ ] Godot runtime verification
```

- [ ] **Step 7: Commit compatibility and summaries**

Run:

```powershell
git add -- scripts/Main.gd scripts/HUDPanels.gd scripts/EventManager.gd scripts/PlayerBuffs.gd docs/brotato-fidelity/fidelity-audit.md docs/PROGRESS.md
git commit -m "feat: finish material wave-end flow"
```

---

## Task 10: Verification Pass

**Files:**
- Modify: `docs/brotato-fidelity/fidelity-audit.md`
- Modify: `docs/PROGRESS.md`

- [ ] **Step 1: Static scan for legacy wording**

Run:

```powershell
rg -n "金币|gold|GoldLabel|earn_gold|wave_gold_start|get_xp_orb|XPOrb|WAVE_DURATION" scripts docs
```

Expected:

- `gold`, `earn_gold`, `wave_gold_start`, `get_xp_orb`, and `XPOrb` may remain only where documented as transitional compatibility.
- User-facing `金币` should not remain in shop, HUD, wave summary, or event reward text.
- `WAVE_DURATION` should not exist as a fixed wave duration constant.

- [ ] **Step 2: Static Godot load check**

Run:

```powershell
Get-Command godot -ErrorAction SilentlyContinue
```

If Godot is available:

```powershell
godot --headless --path . --quit
```

Expected: exit code 0.

If Godot is not available from PATH, record this exact evidence in `docs/PROGRESS.md`:

```markdown
- Godot CLI verification not run: `godot` was not available on PATH in this shell.
```

- [ ] **Step 3: Manual runtime verification**

Open `project.godot` in Godot 4.6 and verify:

```text
1. Main menu starts.
2. Character selection starts a run.
3. Wave 1 timer starts at 20 seconds.
4. Enemy death drops a material pickup.
5. Collecting pickup increases XP and material display.
6. Wave end sends visible pickups into material bag.
7. If at least one level was gained, upgrade choice panel appears before shop.
8. Choosing an upgrade opens the shop when no pending level-ups remain.
9. Buying an item spends materials.
10. Locking an item and rerolling preserves the locked item.
11. Starting the next wave gives wave 2 a 25-second timer.
```

- [ ] **Step 4: Update verification ledger**

In `docs/brotato-fidelity/fidelity-audit.md`, fill the Phase 1 Verification Ledger with actual evidence:

```markdown
| Wave 1 starts at 20 seconds | Verified in Godot runtime on YYYY-MM-DD |
| Wave 2 starts at 25 seconds | Verified in Godot runtime on YYYY-MM-DD |
| Material pickup increases XP and shop currency | Verified in Godot runtime on YYYY-MM-DD |
| Uncollected material enters material bag | Verified in Godot runtime on YYYY-MM-DD |
| Queued level-up choice appears after wave | Verified in Godot runtime on YYYY-MM-DD |
| Shop purchase spends materials | Verified in Godot runtime on YYYY-MM-DD |
| Locked shop slot survives reroll | Verified in Godot runtime on YYYY-MM-DD |
```

Use the real date and exact evidence. If a check fails, leave the evidence as failed and fix before final commit.

- [ ] **Step 5: Commit verification**

Run:

```powershell
git add -- docs/brotato-fidelity/fidelity-audit.md docs/PROGRESS.md
git commit -m "docs: record Brotato fidelity verification"
```

Expected: final Phase 1 docs contain real verification status.

---

## Self-Review

Spec coverage:

- Phase 0 docs: Task 2.
- Material economy: Task 3.
- Material pickup and bag: Task 5.
- Wave duration table: Task 4.
- Post-wave level-up queue: Task 6 and Task 7.
- Shop rule layer: Task 8.
- Wave-end flow: Task 7 and Task 9.
- Verification: Task 10.
- `.uid` policy: Task 1.

Known execution risk:

- The plan intentionally keeps `gold`, `XPOrb`, and `get_xp_orb` names as transitional compatibility in Phase 1. Task 10 requires scanning and documenting those names so they do not become silent permanent drift.
- Runtime verification depends on a local Godot 4.6 executable. If `godot` is not available on PATH, use the editor UI and record that CLI verification was unavailable.
