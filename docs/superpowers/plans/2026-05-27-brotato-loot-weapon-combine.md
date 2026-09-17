# Brotato Loot And Weapon Combine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase 2A Brotato fidelity: fruit/crate loot, wave-end crate reward resolution, take/recycle decisions, and Tier 1-4 weapon combining.

**Architecture:** Add a focused `LootRules` rule layer, keep dynamic UI inside `HUD.gd`, and route wave-end sequencing through `Main.gd` states. Replace the normal paid weapon Lv.5 shop path with player-side equip/combine capability checks so shop purchases are atomic and full weapon slots can auto-combine only when Brotato rules allow it.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scenes, `.tres` weapon resources, PowerShell, Git.

---

## File Structure

Create:

- `scripts/LootRules.gd`: pure loot helper functions for consumable drops, crate reward generation, and recycle value.
- `tests/phase2_loot_weapon_smoke.gd`: Godot `SceneTree` smoke test covering Phase 2A rules, pickups, crate reward flow, and weapon combining.

Modify:

- `scripts/PickupManager.gd`: replace normal buff pickup drops with `fruit`, `crate`, and `legendary_crate`; expose wave-end auto-collection helpers.
- `scripts/Main.gd`: add `CRATE_REWARDS` run phase, pending crate reward queue, crate take/recycle handlers, and wave-end ordering.
- `scripts/HUD.gd`: add crate reward panel, take/recycle signals, and display/hide methods.
- `scripts/Player.gd`: expose weapon equip/combine helper methods.
- `scripts/PlayerCombat.gd`: replace paid level progression with Tier 1-4 combine methods and deterministic tier stat scaling.
- `scripts/PlayerUpgrades.gd`: route weapon purchases through `equip_or_combine_weapon`.
- `scripts/Shop.gd`: check weapon purchase capability before spending materials; remove the normal paid weapon upgrade UI from shop flow.
- `docs/brotato-fidelity/fidelity-audit.md`: update Phase 2A system status and verification evidence.
- `docs/PROGRESS.md`: add Phase 2A progress and verification commands.
- `tests/phase1_main_scene_smoke.gd`: update the `LEVEL_UPS` phase assertion after inserting the `CRATE_REWARDS` enum value.

Do not modify:

- `data/weapons.tres` unless Godot rewrites resource UIDs during import.
- Scene files unless dynamic UI cannot support the required crate panel.

Use the main Godot executable for verification:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Do not use `G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64_console.exe` for required verification while the documented signal 11 issue exists.

---

## Task 1: Phase 2A Smoke Test Skeleton

**Files:**
- Create: `tests/phase2_loot_weapon_smoke.gd`

- [ ] **Step 1: Create the failing Phase 2A smoke test**

Create `tests/phase2_loot_weapon_smoke.gd`:

```gdscript
extends SceneTree

var failures: Array[String] = []
var main = null

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
	_preload_script_classes()

	await _check_loot_rules()
	await _check_main_scene_phase2_paths()

	if is_instance_valid(main):
		main.queue_free()
	main = null
	for i in range(5):
		await process_frame

	if failures.is_empty():
		print("PHASE2_LOOT_WEAPON_SMOKE_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _preload_script_classes():
	var class_scripts = [
		"res://scripts/WeaponData.gd",
		"res://scripts/WeaponDatabase.gd",
		"res://scripts/RunEconomy.gd",
		"res://scripts/ShopRules.gd",
		"res://scripts/LootRules.gd",
		"res://scripts/PlayerCore.gd",
		"res://scripts/PlayerCombat.gd",
		"res://scripts/PlayerUpgrades.gd",
		"res://scripts/PlayerBuffs.gd",
		"res://scripts/PlayerStats.gd",
		"res://scripts/HUDCore.gd",
		"res://scripts/HUDCombat.gd",
		"res://scripts/HUDPanels.gd",
		"res://scripts/WaveManager.gd",
		"res://scripts/PickupManager.gd",
		"res://scripts/TurretManager.gd",
		"res://scripts/EventManager.gd",
	]
	for path in class_scripts:
		var script = load(path)
		if script == null:
			failures.append("Failed to preload script class: " + path)

func _check_loot_rules():
	var script = load("res://scripts/LootRules.gd")
	if script == null:
		failures.append("LootRules.gd missing")
		return
	var rules = script.new()
	var normal_drop = rules.roll_pickup_kind("normal", 0, 0)
	if not normal_drop.has("kind") or not normal_drop.has("heal_amount") or not normal_drop.has("crate_tier"):
		failures.append("LootRules.roll_pickup_kind returned malformed drop")
	var fruit = rules.get_pickup_data("fruit")
	if fruit.kind != "fruit" or fruit.heal_amount != 3 or fruit.crate_tier != 0:
		failures.append("LootRules fruit data mismatch")
	var crate = rules.get_pickup_data("crate")
	if crate.kind != "crate" or crate.heal_amount != 3 or crate.crate_tier != 1:
		failures.append("LootRules crate data mismatch")
	var legendary = rules.get_pickup_data("legendary_crate")
	if legendary.kind != "legendary_crate" or legendary.heal_amount != 100 or legendary.crate_tier != 4:
		failures.append("LootRules legendary crate data mismatch")
	var reward = rules.create_crate_reward([{"name": "Test Item", "desc": "Test", "price": 20, "rarity": 0, "type": "damage", "value": 1}], 1, 0, 1)
	if reward.get("name", "") != "Test Item":
		failures.append("LootRules crate reward did not use non-weapon item")
	if reward.get("recycle_value", 0) != 5:
		failures.append("LootRules recycle value should be 25 percent of current price")

func _check_main_scene_phase2_paths():
	var packed = load("res://scenes/Main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	await process_frame
	if main == null or not is_instance_valid(main):
		failures.append("Main scene did not instantiate")
		return
	if main.pickup_manager == null:
		failures.append("Main scene has no PickupManager")
	if main.get("pending_crate_rewards") == null:
		failures.append("Main lacks pending_crate_rewards queue")
	if main.hud == null or not main.hud.has_signal("crate_reward_taken"):
		failures.append("HUD lacks crate reward take signal")
	await _check_fruit_and_crate_collection()
	await _check_crate_reward_actions()
	await _check_weapon_combine_rules()
	await _check_shop_full_slot_purchase_rules()

func _check_fruit_and_crate_collection():
	var player = main.player
	player.hp = max(1, player.max_hp - 5)
	var before_hp = player.hp
	main.pickup_manager._spawn_pickup(player.position, "fruit")
	var fruit = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(player, fruit, "fruit")
	if player.hp <= before_hp:
		failures.append("Fruit collection did not heal player")
	if fruit.visible:
		failures.append("Fruit pickup was not recycled after collection")
	var before_rewards = main.pending_crate_rewards.size()
	main.pickup_manager._spawn_pickup(player.position, "crate")
	var crate = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(player, crate, "crate")
	if main.pending_crate_rewards.size() != before_rewards + 1:
		failures.append("Crate collection did not enqueue reward")

func _check_crate_reward_actions():
	main.pending_crate_rewards.clear()
	main.enqueue_crate_reward(1)
	if main.pending_crate_rewards.size() != 1:
		failures.append("enqueue_crate_reward did not add a reward")
		return
	var before_items = main.shop.purchased_items.size()
	main._resolve_next_crate_reward_or_level_up()
	if main.run_phase != 2:
		failures.append("Main did not enter CRATE_REWARDS phase")
	main._on_crate_reward_taken(0)
	if main.shop.purchased_items.size() <= before_items:
		failures.append("Taking crate reward did not track purchased item")
	main.enqueue_crate_reward(1)
	var before_materials = main.economy.materials
	var recycle_value = int(main.pending_crate_rewards[0].get("recycle_value", 0))
	main._on_crate_reward_recycled(0)
	if main.economy.materials != before_materials + recycle_value:
		failures.append("Recycling crate reward did not grant materials")

func _check_weapon_combine_rules():
	var player = main.player
	player.equipped_weapons.clear()
	player.equip_or_combine_weapon("pistol", 1)
	player.equip_or_combine_weapon("pistol", 1)
	if player.equipped_weapons.size() != 1:
		failures.append("Two same-tier pistols did not combine into one weapon")
		return
	if player.equipped_weapons[0].level != 2:
		failures.append("Combined pistol did not become Tier 2")
	player.equipped_weapons.clear()
	player.equip_or_combine_weapon("pistol", 4)
	player.equip_or_combine_weapon("pistol", 4)
	if player.equipped_weapons.size() != 2:
		failures.append("Tier 4 weapons should not combine above Tier 4")

func _check_shop_full_slot_purchase_rules():
	var player = main.player
	player.equipped_weapons.clear()
	var fill = ["pistol", "shotgun", "sniper", "machinegun", "boomerang", "knife"]
	for weapon_type in fill:
		player.equip_or_combine_weapon(weapon_type, 1)
	if player.equipped_weapons.size() != player.MAX_WEAPONS:
		failures.append("Failed to fill six weapon slots for shop test")
		return
	var blocked_item = {"name": "Sword", "price": 10, "rarity": 0, "type": "weapon", "weapon_type": "sword", "tier": 1}
	if player.can_equip_or_combine_weapon(blocked_item.get("weapon_type", ""), int(blocked_item.get("tier", 1))):
		failures.append("Full slots allowed non-matching weapon purchase")
	var matching_item = {"name": "Pistol", "price": 10, "rarity": 0, "type": "weapon", "weapon_type": "pistol", "tier": 1}
	if not player.can_equip_or_combine_weapon(matching_item.get("weapon_type", ""), int(matching_item.get("tier", 1))):
		failures.append("Full slots blocked matching weapon auto-combine purchase")
```

- [ ] **Step 2: Run test and verify it fails for missing Phase 2A APIs**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Expected: exit code 1 with failures mentioning missing `LootRules.gd`, `pending_crate_rewards`, crate reward signals, or weapon combine methods.

- [ ] **Step 3: Commit failing test**

Run:

```powershell
git add -- tests/phase2_loot_weapon_smoke.gd
git commit -m "test: add Phase 2 loot and weapon smoke check"
```

Expected: commit succeeds with only the new test file.

---

## Task 2: LootRules Rule Layer

**Files:**
- Create: `scripts/LootRules.gd`
- Modify: `tests/phase2_loot_weapon_smoke.gd.uid` if Godot creates it during test runs

- [ ] **Step 1: Create `LootRules.gd`**

Create `scripts/LootRules.gd`:

```gdscript
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

func roll_pickup_kind(enemy_type: String, luck: int, crates_dropped_this_wave: int) -> Dictionary:
	if enemy_type in ["boss", "miniboss"]:
		return get_pickup_data("legendary_crate")
	var luck_mult = max(0.0, 1.0 + float(luck) / 100.0)
	var base_consumable_chance = 0.10
	if enemy_type == "elite":
		base_consumable_chance = 0.30
	if randf() > clamp(base_consumable_chance * luck_mult, 0.0, 0.95):
		return {}
	var crate_chance = 0.08 * luck_mult / float(1 + max(0, crates_dropped_this_wave))
	if enemy_type == "elite":
		crate_chance = 0.25 * luck_mult / float(1 + max(0, crates_dropped_this_wave))
	if randf() < clamp(crate_chance, 0.0, 0.95):
		return get_pickup_data("crate")
	return get_pickup_data("fruit")

func get_recycle_value(base_price: int, rarity: int, wave: int, shop_rules: ShopRules = null) -> int:
	var current_price = base_price
	if shop_rules != null:
		current_price = shop_rules.get_price(base_price, rarity, wave)
	return max(1, int(floor(float(current_price) * 0.25)))

func create_crate_reward(item_pool: Array, wave: int, luck: int, crate_tier: int, shop_rules: ShopRules = null) -> Dictionary:
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
	chosen["recycle_value"] = get_recycle_value(chosen.get("price", 1), int(chosen.get("rolled_rarity", 0)), wave, shop_rules)
	return chosen
```

- [ ] **Step 2: Run Phase 2 smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Expected: no `LootRules.gd missing` failure remains. Other failures remain for pickup, HUD, Main, and weapon combine APIs.

- [ ] **Step 3: Commit LootRules**

Run:

```powershell
git add -- scripts/LootRules.gd scripts/LootRules.gd.uid tests/phase2_loot_weapon_smoke.gd.uid
git commit -m "feat: add Brotato loot rules"
```

Expected: commit succeeds. If `.uid` files were not generated, omit those paths from `git add`.

---

## Task 3: PickupManager Fruit And Crate Pickups

**Files:**
- Modify: `scripts/PickupManager.gd`
- Test: `tests/phase2_loot_weapon_smoke.gd`

- [ ] **Step 1: Add loot rules fields**

In `scripts/PickupManager.gd`, add after `var main: Node2D`:

```gdscript
var loot_rules := LootRules.new()
var crates_dropped_this_wave = 0
```

- [ ] **Step 2: Replace normal pickup data**

Replace `PICKUP_TYPES` with:

```gdscript
const PICKUP_TYPES = {
	"fruit": {"name": "Fruit", "color": Color(0.25, 1.0, 0.35), "heal_amount": 3, "crate_tier": 0},
	"crate": {"name": "Loot Crate", "color": Color(0.75, 0.45, 0.18), "heal_amount": 3, "crate_tier": 1},
	"legendary_crate": {"name": "Legendary Crate", "color": Color(1.0, 0.82, 0.18), "heal_amount": 100, "crate_tier": 4},
}

const LEGACY_BUFF_PICKUP_TYPES = {
	"speed_boost": {"name": "速度提升", "color": Color(0.2, 0.8, 1.0), "duration": 10.0},
	"damage_boost": {"name": "伤害提升", "color": Color(1.0, 0.3, 0.2), "duration": 10.0},
	"rapid_fire": {"name": "急速射击", "color": Color(1.0, 0.8, 0.0), "duration": 8.0},
	"shield": {"name": "护盾", "color": Color(0.3, 0.5, 1.0), "duration": 0.0},
	"vampire_fang": {"name": "吸血之牙", "color": Color(0.8, 0.1, 0.3), "duration": 15.0},
}
```

- [ ] **Step 3: Reset per-wave crate count**

Add:

```gdscript
func begin_wave():
	crates_dropped_this_wave = 0
```

In `scripts/WaveManager.gd`, inside `advance_wave()` after `main.wave_kills = 0`, add:

```gdscript
	if main.pickup_manager != null:
		main.pickup_manager.begin_wave()
```

- [ ] **Step 4: Replace `_try_spawn_pickup`**

Replace `_try_spawn_pickup(enemy)` with:

```gdscript
func _try_spawn_pickup(enemy):
	var etype = enemy.get("enemy_type") if enemy.get("enemy_type") else "normal"
	var luck = main.player.luck if main and main.player and is_instance_valid(main.player) else 0
	var drop = loot_rules.roll_pickup_kind(etype, luck, crates_dropped_this_wave)
	if drop.is_empty():
		return
	var kind = drop.get("kind", "fruit")
	if kind in ["crate", "legendary_crate"]:
		crates_dropped_this_wave += 1
	_spawn_pickup(enemy.position, kind)
```

- [ ] **Step 5: Store pickup metadata in `_spawn_pickup`**

Inside `_spawn_pickup(pos, ptype)`, after `pickup.set_meta("pickup_type", ptype)`, add:

```gdscript
	pickup.set_meta("pickup_kind", ptype)
	pickup.set_meta("heal_amount", int(data.get("heal_amount", 0)))
	pickup.set_meta("crate_tier", int(data.get("crate_tier", 0)))
```

- [ ] **Step 6: Replace collection behavior**

Replace `_on_pickup_collected(body, pickup, ptype)` with:

```gdscript
func _on_pickup_collected(body, pickup, ptype):
	if not body.is_in_group("player"):
		return
	if not is_instance_valid(pickup) or not pickup.visible:
		return
	var pdata = PICKUP_TYPES.get(ptype, PICKUP_TYPES["fruit"])
	var heal_amount = int(pdata.get("heal_amount", 0))
	if heal_amount > 0 and body.has_method("heal"):
		body.heal(heal_amount)
	var crate_tier = int(pdata.get("crate_tier", 0))
	if crate_tier > 0 and main and main.has_method("enqueue_crate_reward"):
		main.enqueue_crate_reward(crate_tier)
	Effects.hit_spark(pickup.position, pdata.color)
	if main and main.hud:
		main.hud.show_notification(pdata.name + "!", pdata.color)
	_recycle_pickup(pickup)
```

- [ ] **Step 7: Add wave-end auto-collection helper**

Add before `cleanup()`:

```gdscript
func collect_all_active_for_wave_end(player):
	var pickups = active_pickup_nodes.duplicate()
	for pickup in pickups:
		if is_instance_valid(pickup) and pickup.visible:
			var ptype = pickup.get_meta("pickup_type", "fruit")
			_on_pickup_collected(player, pickup, ptype)
```

- [ ] **Step 8: Run Phase 2 smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Expected: fruit and crate collection failures are gone. Failures remain for `Main` pending reward flow, HUD crate panel, and weapon combine APIs.

- [ ] **Step 9: Commit pickup behavior**

Run:

```powershell
git add -- scripts/PickupManager.gd scripts/WaveManager.gd
git commit -m "feat: add fruit and crate pickups"
```

---

## Task 4: Main And HUD Crate Reward Flow

**Files:**
- Modify: `scripts/Main.gd`
- Modify: `scripts/HUD.gd`
- Modify: `tests/phase1_main_scene_smoke.gd`
- Test: `tests/phase2_loot_weapon_smoke.gd`

- [ ] **Step 1: Add Main crate phase and queue**

In `scripts/Main.gd`, replace:

```gdscript
enum RunPhase { COMBAT, WAVE_END, LEVEL_UPS, SHOP, GAME_OVER }
```

with:

```gdscript
enum RunPhase { COMBAT, WAVE_END, CRATE_REWARDS, LEVEL_UPS, SHOP, GAME_OVER }
```

Add near wave stats:

```gdscript
var pending_crate_rewards: Array = []
var loot_rules := LootRules.new()
```

- [ ] **Step 2: Connect HUD crate reward signals**

In `_ready()`, after `hud.upgrade_choice_selected.connect(_on_upgrade_choice_selected)`, add:

```gdscript
	hud.crate_reward_taken.connect(_on_crate_reward_taken)
	hud.crate_reward_recycled.connect(_on_crate_reward_recycled)
```

- [ ] **Step 3: Add HUD fields and signals**

In `scripts/HUD.gd`, add near upgrade choice fields:

```gdscript
var crate_reward_panel: PanelContainer = null
var crate_reward_title: Label = null
var crate_reward_desc: Label = null
var crate_reward_recycle_button: Button = null
```

Add near existing signals:

```gdscript
signal crate_reward_taken(index: int)
signal crate_reward_recycled(index: int)
```

In `_ready()`, after `_build_upgrade_choice_panel()`, add:

```gdscript
	_build_crate_reward_panel()
```

- [ ] **Step 4: Add HUD crate panel builder**

Add to `scripts/HUD.gd` after `_build_pause_menu()`:

```gdscript
func _build_crate_reward_panel():
	crate_reward_panel = PanelContainer.new()
	crate_reward_panel.name = "CrateRewardPanel"
	crate_reward_panel.visible = false
	crate_reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	crate_reward_panel.custom_minimum_size = Vector2(520, 260)
	crate_reward_panel.z_index = 20
	add_child(crate_reward_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	crate_reward_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	crate_reward_title = Label.new()
	crate_reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_reward_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(crate_reward_title)

	crate_reward_desc = Label.new()
	crate_reward_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crate_reward_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crate_reward_desc.add_theme_font_size_override("font_size", 15)
	crate_reward_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(crate_reward_desc)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var take_btn = Button.new()
	take_btn.text = "拿取"
	take_btn.custom_minimum_size = Vector2(150, 42)
	take_btn.pressed.connect(func(): crate_reward_taken.emit(0))
	row.add_child(take_btn)

	crate_reward_recycle_button = Button.new()
	crate_reward_recycle_button.custom_minimum_size = Vector2(150, 42)
	crate_reward_recycle_button.pressed.connect(func(): crate_reward_recycled.emit(0))
	row.add_child(crate_reward_recycle_button)
```

- [ ] **Step 5: Add HUD crate display methods**

Add after `hide_upgrade_choices()`:

```gdscript
func show_crate_reward(reward: Dictionary):
	if crate_reward_panel == null:
		return
	var rarity_names = ["普通", "精良", "稀有", "传说"]
	var rarity = clamp(int(reward.get("rolled_rarity", reward.get("rarity", 0))), 0, 3)
	crate_reward_title.text = "%s  [%s]" % [reward.get("name", "Unknown Item"), rarity_names[rarity]]
	crate_reward_desc.text = "%s\n%s" % [reward.get("desc", ""), _format_crate_reward_effect(reward)]
	crate_reward_recycle_button.text = "回收 (+%d材料)" % int(reward.get("recycle_value", 1))
	crate_reward_panel.visible = true

func hide_crate_reward():
	if crate_reward_panel:
		crate_reward_panel.visible = false

func _format_crate_reward_effect(reward: Dictionary) -> String:
	var item_type = reward.get("type", "")
	var value = reward.get("value", 0)
	match item_type:
		"speed": return "速度 +%d" % int(value)
		"fire_rate": return "射速 +%d%%" % int(float(value) * 100.0)
		"damage": return "伤害 +%d" % int(value)
		"hp": return "最大HP +%d" % int(value)
		"heal": return "恢复 %dHP" % int(value)
		"magnet": return "磁铁范围 +%d" % int(value)
		"armor": return "护甲 +%d" % int(value)
		"crit_chance": return "暴击率 +%d%%" % int(float(value) * 100.0)
		"lifesteal": return "生命偷取 +%d%%" % int(float(value) * 100.0)
		"luck": return "幸运 +%d" % int(value)
		_: return "道具"
```

- [ ] **Step 6: Add Main crate reward helpers**

Add to `scripts/Main.gd` before `_open_shop_after_rewards()`:

```gdscript
func enqueue_crate_reward(crate_tier: int):
	var reward = loot_rules.create_crate_reward(shop.ITEM_POOL, wave, player.luck if player and is_instance_valid(player) else 0, crate_tier, shop.shop_rules)
	if reward.is_empty():
		return
	pending_crate_rewards.append(reward)

func _resolve_next_crate_reward_or_level_up():
	if pending_crate_rewards.size() > 0:
		run_phase = RunPhase.CRATE_REWARDS
		hud.show_crate_reward(pending_crate_rewards[0])
	else:
		hud.hide_crate_reward()
		_resolve_next_level_up_or_shop()

func _on_crate_reward_taken(index: int):
	if pending_crate_rewards.is_empty():
		return
	var reward = pending_crate_rewards.pop_front()
	if player and is_instance_valid(player):
		player.apply_upgrade(reward)
	if shop and is_instance_valid(shop):
		var tracked = reward.duplicate(true)
		tracked["paid_price"] = 0
		shop.purchased_items.append(tracked)
		shop._refresh_sell_area()
	_resolve_next_crate_reward_or_level_up()

func _on_crate_reward_recycled(index: int):
	if pending_crate_rewards.is_empty():
		return
	var reward = pending_crate_rewards.pop_front()
	var value = int(reward.get("recycle_value", 1))
	if player and is_instance_valid(player):
		player.earn_gold(value)
	_resolve_next_crate_reward_or_level_up()
```

- [ ] **Step 7: Route wave end through crate rewards**

In `_on_wave_ended()`, replace:

```gdscript
	pickup_manager.cleanup()
```

with:

```gdscript
	if player and is_instance_valid(player):
		pickup_manager.collect_all_active_for_wave_end(player)
	pickup_manager.cleanup()
```

At the end of `_on_wave_ended()`, replace:

```gdscript
	_resolve_next_level_up_or_shop()
```

with:

```gdscript
	_resolve_next_crate_reward_or_level_up()
```

- [ ] **Step 8: Update Phase 1 scene smoke phase assertion**

In `tests/phase1_main_scene_smoke.gd`, replace:

```gdscript
	if main.run_phase != 2:
		failures.append("Main did not enter LEVEL_UPS phase for pending level-up")
```

with:

```gdscript
	if main.run_phase != 3:
		failures.append("Main did not enter LEVEL_UPS phase for pending level-up")
```

- [ ] **Step 9: Run Phase 2 smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Expected: crate reward queue, take, and recycle failures are gone. Weapon combine and shop purchase capability failures remain.

- [ ] **Step 10: Commit crate reward flow**

Run:

```powershell
git add -- scripts/Main.gd scripts/HUD.gd tests/phase1_main_scene_smoke.gd
git commit -m "feat: resolve crate rewards before upgrades"
```

---

## Task 5: PlayerCombat Tier 1-4 Weapon Combining

**Files:**
- Modify: `scripts/PlayerCombat.gd`
- Modify: `scripts/Player.gd`
- Test: `tests/phase2_loot_weapon_smoke.gd`

- [ ] **Step 1: Add tier helper methods in PlayerCombat**

In `scripts/PlayerCombat.gd`, add after `init(player)`:

```gdscript
func _make_weapon(type: String, tier: int = 1) -> Dictionary:
	var weapon_tier = clamp(tier, 1, 4)
	var data = WEAPON_DATA[type].duplicate(true)
	_apply_tier_stats(data, weapon_tier)
	return {"type": type, "timer": 0.0, "data": data, "level": weapon_tier, "tier": weapon_tier}

func _apply_tier_stats(data: Dictionary, tier: int):
	var level = clamp(tier, 1, 4)
	var damage_mult = [1.0, 1.45, 2.05, 2.85][level - 1]
	var fire_rate_mult = [1.0, 1.10, 1.22, 1.35][level - 1]
	data.damage = max(1, int(round(data.damage * damage_mult)))
	data.fire_rate *= fire_rate_mult
	if level >= 3:
		if data.get("melee", false):
			data.melee_radius = int(data.get("melee_radius", 80) * 1.25)
		else:
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
```

- [ ] **Step 2: Replace `equip_weapon`**

Replace `equip_weapon(type)` with:

```gdscript
func equip_weapon(type):
	equip_or_combine_weapon(type, 1)

func can_equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	if not WEAPON_DATA.has(type):
		return false
	var weapon_tier = clamp(tier, 1, 4)
	if _find_combine_partner(type, weapon_tier) != -1:
		return true
	return p.equipped_weapons.size() < p.MAX_WEAPONS

func equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	if not WEAPON_DATA.has(type):
		return false
	var weapon_tier = clamp(tier, 1, 4)
	var partner_index = _find_combine_partner(type, weapon_tier)
	if partner_index != -1:
		p.equipped_weapons[partner_index] = _make_weapon(type, weapon_tier + 1)
		emit_weapons_changed()
		p.upgrades.check_synergies()
		return true
	if p.equipped_weapons.size() >= p.MAX_WEAPONS:
		return false
	p.equipped_weapons.append(_make_weapon(type, weapon_tier))
	emit_weapons_changed()
	p.upgrades.check_synergies()
	return true
```

- [ ] **Step 3: Replace paid `upgrade_weapon` with manual combine**

Replace `upgrade_weapon(slot_index: int) -> bool` with:

```gdscript
func upgrade_weapon(slot_index: int) -> bool:
	return combine_weapon(slot_index)

func can_combine_weapon(slot_index: int) -> bool:
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
	p.equipped_weapons[keep_index] = _make_weapon(weapon.type, tier + 1)
	p.equipped_weapons.remove_at(remove_index)
	emit_weapons_changed()
	p.upgrades.check_synergies()
	if p.has_node("/root/AudioManager"):
		p.get_node("/root/AudioManager").play_level_up()
	return true
```

- [ ] **Step 4: Update weapon display info**

Replace `emit_weapons_changed()` with:

```gdscript
func emit_weapons_changed():
	p.weapons_changed.emit(p.equipped_weapons.map(func(w):
		var tier = int(w.get("tier", w.get("level", 1)))
		var prefix = "★" if tier >= 4 else ""
		return "%s%s T%d" % [prefix, w.data.name, tier]
	))
```

Replace `get_weapon_info()` with:

```gdscript
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
			"max_level": tier >= 4
		})
	return info
```

- [ ] **Step 5: Expose methods on Player**

In `scripts/Player.gd`, after `func equip_weapon(type):`, add:

```gdscript
func can_equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	return combat.can_equip_or_combine_weapon(type, tier)

func equip_or_combine_weapon(type: String, tier: int = 1) -> bool:
	return combat.equip_or_combine_weapon(type, tier)

func can_combine_weapon(slot_index: int) -> bool:
	return combat.can_combine_weapon(slot_index)

func combine_weapon(slot_index: int) -> bool:
	return combat.combine_weapon(slot_index)
```

- [ ] **Step 6: Run Phase 2 smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Expected: weapon combine method failures are gone. Shop full-slot purchase path may still fail until Task 6.

- [ ] **Step 7: Commit weapon combining**

Run:

```powershell
git add -- scripts/PlayerCombat.gd scripts/Player.gd
git commit -m "feat: add Brotato weapon tier combining"
```

---

## Task 6: Shop Purchase Atomicity And Manual Combine UI

**Files:**
- Modify: `scripts/Shop.gd`
- Modify: `scripts/PlayerUpgrades.gd`
- Test: `tests/phase2_loot_weapon_smoke.gd`

- [ ] **Step 1: Add weapon tier to shop cards**

In `_make_card(item, index)`, after rarity calculation, add:

```gdscript
	var item_tier = int(item.get("tier", rarity + 1)) if item.get("type", "") == "weapon" else 0
	if item.get("type", "") == "weapon":
		item["tier"] = item_tier
```

In the weapon branch of `_get_tooltip_text(item)`, replace:

```gdscript
			effect_str = "武器"
```

with:

```gdscript
			effect_str = "武器 Tier %d" % int(item.get("tier", item.get("rolled_rarity", item.get("rarity", 0)) + 1))
```

- [ ] **Step 2: Add purchase capability helper**

Add to `scripts/Shop.gd` before `_on_buy_pressed`:

```gdscript
func _can_purchase_item(item: Dictionary) -> bool:
	if item.get("type", "") != "weapon":
		return true
	if player_ref == null or not is_instance_valid(player_ref):
		return false
	var tier = int(item.get("tier", item.get("rolled_rarity", item.get("rarity", 0)) + 1))
	if player_ref.has_method("can_equip_or_combine_weapon"):
		return player_ref.can_equip_or_combine_weapon(item.weapon_type, tier)
	return player_ref.equipped_weapons.size() < player_ref.MAX_WEAPONS
```

- [ ] **Step 3: Use capability in buy button state**

Replace `_set_buy_button_state(btn: Button, price: int, gold: int)` with:

```gdscript
func _set_buy_button_state(btn: Button, price: int, gold: int, item: Dictionary = {}):
	if btn.text == "已购买":
		btn.disabled = true
		return
	btn.text = "购买"
	if not item.is_empty() and not _can_purchase_item(item):
		btn.disabled = true
		btn.text = "无法合成"
		btn.modulate = Color(1.0, 0.45, 0.45, 1.0)
		return
	if gold >= price:
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1)
	else:
		btn.disabled = true
		btn.modulate = Color(1.0, 0.45, 0.45, 1.0)
```

Update both call sites:

```gdscript
	_set_buy_button_state(buy_btn, actual_price, player_gold, item)
```

and:

```gdscript
			_set_buy_button_state(btn, shop_rules.get_price(item.price, r, wave_num), player_gold, item)
```

- [ ] **Step 4: Update purchase ordering**

In `_on_buy_pressed`, replace the existing full-slot weapon block:

```gdscript
	if item.type == "weapon" and player_ref and is_instance_valid(player_ref):
		if player_ref.equipped_weapons.size() >= player_ref.MAX_WEAPONS:
			btn.text = "已满"
			btn.disabled = true
			return
```

with:

```gdscript
	if not _can_purchase_item(item):
		btn.text = "无法合成"
		btn.disabled = true
		return
```

This check must remain before any material spend.

- [ ] **Step 5: Route weapon upgrade UI to manual combine**

In `_refresh_upgrade_area()`, replace:

```gdscript
	title.text = "武器升级"
```

with:

```gdscript
	title.text = "武器合成"
```

Replace upgrade button block:

```gdscript
			up_btn.text = "升级 (%d材料)" % w.upgrade_cost
			up_btn.add_theme_font_size_override("font_size", 13)
			up_btn.custom_minimum_size = Vector2(0, 30)
			if player_gold >= w.upgrade_cost:
				up_btn.disabled = false
			else:
				up_btn.disabled = true
				up_btn.modulate = Color(1.0, 0.45, 0.45, 1.0)
			up_btn.pressed.connect(_on_upgrade_pressed.bind(i))
			vbox.add_child(up_btn)
```

with:

```gdscript
			up_btn.text = "合成"
			up_btn.add_theme_font_size_override("font_size", 13)
			up_btn.custom_minimum_size = Vector2(0, 30)
			if w.get("can_combine", false):
				up_btn.disabled = false
			else:
				up_btn.disabled = true
				up_btn.modulate = Color(1.0, 0.45, 0.45, 1.0)
			up_btn.pressed.connect(_on_upgrade_pressed.bind(i))
			vbox.add_child(up_btn)
```

- [ ] **Step 6: Update manual combine handler**

Replace `_on_upgrade_pressed(slot_index: int)` with:

```gdscript
func _on_upgrade_pressed(slot_index: int):
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if not player_ref.has_method("combine_weapon"):
		return
	var success = player_ref.combine_weapon(slot_index)
	if success:
		player_gold = player_ref.gold
		$Panel/GoldLabel.text = "材料: %d" % player_gold
		_refresh_upgrade_area()
		_refresh_buy_buttons()
		_update_reroll_button()
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_buy()
```

- [ ] **Step 7: Route weapon purchase through combine-aware API**

In `scripts/PlayerUpgrades.gd`, replace the `"weapon"` match branch:

```gdscript
		"weapon":
			p.combat.equip_weapon(upgrade.weapon_type)
			changed_stats.append("weapons")
```

with:

```gdscript
		"weapon":
			var tier = int(upgrade.get("tier", upgrade.get("rolled_rarity", upgrade.get("rarity", 0)) + 1))
			if p.combat.equip_or_combine_weapon(upgrade.weapon_type, tier):
				changed_stats.append("weapons")
```

- [ ] **Step 8: Run Phase 2 smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Expected: output includes `PHASE2_LOOT_WEAPON_SMOKE_PASS` and exit code 0.

- [ ] **Step 9: Commit shop purchase changes**

Run:

```powershell
git add -- scripts/Shop.gd scripts/PlayerUpgrades.gd
git commit -m "feat: make shop weapons combine-aware"
```

---

## Task 7: Documentation And Fidelity Audit

**Files:**
- Modify: `docs/brotato-fidelity/fidelity-audit.md`
- Modify: `docs/PROGRESS.md`

- [ ] **Step 1: Update fidelity audit statuses**

In `docs/brotato-fidelity/fidelity-audit.md`, replace the Crates and consumables row with:

```markdown
| Crates and consumables | Wave-end pickups resolve in a defined order. | Fruit, crate, and legendary crate pickups exist; active crates are auto-collected at wave end and resolved through take/recycle reward choices before level-ups and shop. | aligned for Phase 2A | `scripts/LootRules.gd`, `scripts/PickupManager.gd`, `scripts/Main.gd`, `scripts/HUD.gd` | Phase 2A |
```

Replace the Weapon upgrading and combining row with:

```markdown
| Weapon upgrading and combining | Weapon levels and merging rules are part of core build progression. | Normal weapon progression uses Tier 1-4 same-type same-tier combining; full-slot shop weapon purchases can auto-combine only when matching weapon rules allow it. Per-tier stats are deterministic approximations until full weapon data tables exist. | aligned for Phase 2A | `scripts/PlayerCombat.gd`, `scripts/PlayerUpgrades.gd`, `scripts/Shop.gd` | Phase 2A |
```

- [ ] **Step 2: Add Phase 2A verification ledger**

Append after the Phase 1 verification ledger:

```markdown
## Phase 2A Verification Ledger

| Check | Evidence |
|---|---|
| Fruit heals and recycles | Verified by `tests/phase2_loot_weapon_smoke.gd` |
| Crate queues reward | Verified by `tests/phase2_loot_weapon_smoke.gd` |
| Crate reward take applies item | Verified by `tests/phase2_loot_weapon_smoke.gd` |
| Crate reward recycle grants materials | Verified by `tests/phase2_loot_weapon_smoke.gd` |
| Same-tier weapons combine to next tier | Verified by `tests/phase2_loot_weapon_smoke.gd` |
| Tier 4 weapons do not combine above cap | Verified by `tests/phase2_loot_weapon_smoke.gd` |
| Full-slot nonmatching weapon purchase is blocked | Verified by `tests/phase2_loot_weapon_smoke.gd` |
| Full-slot matching weapon purchase can auto-combine | Verified by `tests/phase2_loot_weapon_smoke.gd` |
```

- [ ] **Step 3: Update progress doc**

In `docs/PROGRESS.md`, after the Phase 1 list, add:

```markdown
### Brotato Fidelity Phase 2A Loot And Weapon Combine
- [x] Loot rule layer for fruit/crate/legendary crate
- [x] Wave-end crate reward queue before upgrades and shop
- [x] Crate take/recycle flow
- [x] Tier 1-4 same-type same-tier weapon combining
- [x] Full-slot auto-combine weapon purchase rule
- [x] Godot headless Phase 2A smoke test through main executable
- [ ] Manual gameplay verification

Verification note: Phase 2A smoke test passed on 2026-05-27 with `G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe --headless --path . --script res://tests/phase2_loot_weapon_smoke.gd`, output `PHASE2_LOOT_WEAPON_SMOKE_PASS`.
```

- [ ] **Step 4: Commit documentation**

Run:

```powershell
git add -- docs/brotato-fidelity/fidelity-audit.md docs/PROGRESS.md
git commit -m "docs: record Phase 2A loot verification"
```

---

## Task 8: Final Verification Pass

**Files:**
- Modify: docs only if verification evidence needs correction

- [ ] **Step 1: Static scan for forbidden normal-flow patterns**

Run:

```powershell
rg -n "speed_boost|damage_boost|rapid_fire|upgrade_cost|Lv\\.5|升级 \\(%d材料\\)|WAVE_DURATION = 20\\.0|Godot_v4\\.6\\.1-stable_win64_console" scripts tests docs
```

Expected:

- `speed_boost`, `damage_boost`, and `rapid_fire` appear only under `LEGACY_BUFF_PICKUP_TYPES` or docs explaining they are not normal drops.
- `upgrade_cost` does not drive normal weapon shop progression.
- No shop UI string offers paid weapon upgrade.
- `Godot_v4.6.1-stable_win64_console` appears only in docs as a known-bad fallback warning.

- [ ] **Step 2: Run Phase 1 rule regression**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase1_rules_smoke.gd"
```

Expected: exit code 0.

- [ ] **Step 3: Run Phase 1 scene regression**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase1_main_scene_smoke.gd"
```

Expected: exit code 0.

- [ ] **Step 4: Run Phase 2A smoke test**

Run:

```powershell
& "G:\ClaudeCode\Download\Godot_v4.6.1-stable_win64.exe" --headless --path . --script "res://tests/phase2_loot_weapon_smoke.gd"
```

Expected: output includes `PHASE2_LOOT_WEAPON_SMOKE_PASS` and exit code 0.

- [ ] **Step 5: Commit any verification evidence correction**

If docs needed correction, run:

```powershell
git add -- docs/brotato-fidelity/fidelity-audit.md docs/PROGRESS.md
git commit -m "docs: update Phase 2A verification evidence"
```

If no docs changed, run:

```powershell
git status --short
```

Expected: clean worktree.

---

## Self-Review

Spec coverage:

- `LootRules.gd`: Task 2.
- Fruit/crate/legendary crate pickups: Task 3.
- Wave-end auto-collection and crate queue before upgrades/shop: Task 4.
- Crate take/recycle UI: Task 4.
- Tier 1-4 weapon combining: Task 5.
- Full-slot auto-combine purchase behavior: Task 6.
- Paid Lv.5 weapon upgrade removed from normal shop flow: Task 6 and Task 8 static scan.
- Automated smoke coverage: Task 1 and Task 8.
- Fidelity audit and progress docs: Task 7.

Known approximations:

- Per-tier weapon stats use deterministic multipliers until a later weapon data phase introduces full per-tier tables.
- Crate reward items use the existing local non-weapon item pool until a later item data phase introduces a fuller clean-room catalog.
- Enemy-specific drop rates remain approximations, but `LootRules` has signatures that allow more exact data later.

Execution notes:

- Use the main Godot executable, not the console wrapper.
- Commit after each task.
- If any smoke test reveals a GDScript parse/runtime error, stop and use `superpowers:systematic-debugging` before changing implementation.
