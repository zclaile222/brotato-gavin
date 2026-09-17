extends SceneTree

var failures: Array[String] = []
var main = null

func _init():
	call_deferred("_run")

func _run():
	# ── 视口尺寸必须与工程声明一致 ──
	# headless 下根视口的实际尺寸是 **64×64**，而不是 project.godot 里声明的 1280×720。
	# Main 的场地布局、以及 `Bullet._process()` 的「出屏回收」（超出视口 ±50px 即回收）
	# 都以视口尺寸为准，于是整个场景被塞进一个 64px 宽的世界：玩家落在 (44,44)，
	# 子弹以 500px/s 向右飞。而本测试自身的同步建场工作（实例化整个 Main）会把下一帧的
	# delta 抬到 ~0.14s，500×0.14 = 70px > 114-44，一发就越过 `screen.x + 50 = 114`
	# 的出屏线，被 `Bullet._process()` 回收成 `visible = false`。
	# 这才是本节断言偶发红的真因（见 docs §10.2），与碰撞无关。
	# 还原成工程声明的尺寸后，出屏线远在 1330px 外，本检查不可能再被它影响。
	var viewport_w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var viewport_h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	root.size = Vector2i(viewport_w, viewport_h)

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
	if normal_drop.is_empty():
		normal_drop = rules.get_pickup_data("fruit")
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
	await _check_high_tier_catalog_weapon_runtime()
	await _check_player_bullet_rendering_contract()
	await _check_shop_full_slot_purchase_rules()

func _check_fruit_and_crate_collection():
	if not _pickup_manager_source_has_phase2_types():
		failures.append("PickupManager lacks fruit/crate pickup types")
		return
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
	if main.get("pending_crate_rewards") == null:
		return
	var before_rewards = main.pending_crate_rewards.size()
	main.pickup_manager._spawn_pickup(player.position, "crate")
	var crate = main.pickup_manager.active_pickup_nodes.back()
	main.pickup_manager._on_pickup_collected(player, crate, "crate")
	if main.pending_crate_rewards.size() != before_rewards + 1:
		failures.append("Crate collection did not enqueue reward")

func _check_crate_reward_actions():
	if main.get("pending_crate_rewards") == null:
		return
	if not main.has_method("enqueue_crate_reward") or not main.has_method("_resolve_next_crate_reward_or_level_up"):
		failures.append("Main lacks crate reward resolver methods")
		return
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
	if not player.has_method("equip_or_combine_weapon") or not player.has_method("can_equip_or_combine_weapon"):
		failures.append("Player lacks weapon equip/combine methods")
		return
	player.equipped_weapons.clear()
	player.equip_or_combine_weapon("pistol", 1)
	player.equip_or_combine_weapon("pistol", 1)
	if player.equipped_weapons.size() != 1:
		failures.append("Two same-tier pistols did not combine into one weapon")
		return
	if int(player.equipped_weapons[0].get("level", 0)) != 2:
		failures.append("Combined pistol did not become Tier 2")
	player.equipped_weapons.clear()
	player.equip_or_combine_weapon("pistol", 4)
	player.equip_or_combine_weapon("pistol", 4)
	if player.equipped_weapons.size() != 2:
		failures.append("Tier 4 weapons should not combine above Tier 4")

func _check_high_tier_catalog_weapon_runtime():
	var player = main.player
	if not player.has_method("equip_or_combine_weapon") or not player.has_method("can_equip_or_combine_weapon"):
		failures.append("Player lacks weapon equip/combine methods for high-tier catalog check")
		return
	player.equipped_weapons.clear()
	if not player.can_equip_or_combine_weapon("chain_gun", 4):
		failures.append("Chain Gun tier 4 should be runtime-equippable from catalog data")
		return
	if not player.equip_or_combine_weapon("chain_gun", 4):
		failures.append("Equipping Chain Gun tier 4 failed")
		return
	var weapon = player.equipped_weapons.back()
	if int(weapon.get("tier", 0)) != 4:
		failures.append("Chain Gun should equip as tier 4")
	if int(weapon.get("data", {}).get("damage", 0)) != 2:
		failures.append("Chain Gun tier 4 should use exact catalog damage, not legacy tier multipliers")
	if int(weapon.get("data", {}).get("count", 0)) != 3:
		failures.append("Chain Gun tier 4 projectile count mismatch")

func _check_player_bullet_rendering_contract():
	var player = main.player
	if player == null or not is_instance_valid(player):
		failures.append("Main scene should expose player for bullet rendering check")
		return
	if not main.has_method("get_bullet"):
		failures.append("Main scene should expose bullet pool for bullet rendering check")
		return
	var bullet = main.get_bullet()
	if bullet == null or not is_instance_valid(bullet):
		failures.append("Bullet pool should return a valid bullet")
		return
	var body = bullet.get_node_or_null("Body")
	if body == null:
		failures.append("Player bullet should expose a visible Body node")
		return
	# 本节只验证「激活后的渲染契约」（visible / Body 可见 / 比例 / z_index），与碰撞无关。
	# 子弹是在玩家当前位置激活的，紧随其后的 process_frame 里若有敌人正好压在玩家身上，
	# `_on_body_entered` 会命中并把子弹立刻归还池中（visible=false），给这条断言引入噪声。
	# 因此测量期间临时屏蔽碰撞。
	#
	# 注意：这不是历史偶发红的真因 —— 探针实测该时刻 `enemies_total=0`（见 docs §10.2），
	# 真因是视口被 headless 压成 64×64 后的**出屏回收**，已在 `_run()` 里从根上修掉。
	# 保留这段屏蔽是因为它只隔离与断言意图无关的子系统，成本为零。
	var saved_collision_mask = bullet.collision_mask
	bullet.collision_mask = 0
	bullet.activate(player.position, Vector2.RIGHT, 500.0, Color(1.0, 0.9, 0.2), player, 1)
	await process_frame
	if not bullet.visible:
		failures.append("Activated player bullet should be visible")
	if not body.visible:
		failures.append("Activated player bullet body should be visible")
	if body.color.a <= 0.0:
		failures.append("Activated player bullet body should not be transparent")
	if bullet.scale.x <= 0.0 or bullet.scale.y <= 0.0:
		failures.append("Activated player bullet should have non-zero visual scale")
	if bullet.z_index <= 0:
		failures.append("Activated player bullet should render above default enemy z-index")
	bullet.collision_mask = saved_collision_mask
	if bullet.has_method("_return_to_pool"):
		bullet._return_to_pool()
	if not main.has_method("get_enemy_bullet"):
		failures.append("Main scene should expose enemy bullet pool for bullet rendering check")
		return
	var enemy_bullet = main.get_enemy_bullet()
	if enemy_bullet == null or not is_instance_valid(enemy_bullet):
		failures.append("Enemy bullet pool should return a valid bullet")
		return
	enemy_bullet.activate(player.position + Vector2(100, 0), Vector2.RIGHT)
	if not enemy_bullet.visible:
		failures.append("Activated enemy bullet should be visible")
	if enemy_bullet.z_index <= 0:
		failures.append("Activated enemy bullet should render above default enemy z-index")
	if enemy_bullet.has_method("_return_to_pool"):
		enemy_bullet._return_to_pool()

func _check_shop_full_slot_purchase_rules():
	var player = main.player
	if not player.has_method("equip_or_combine_weapon") or not player.has_method("can_equip_or_combine_weapon"):
		return
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

func _pickup_manager_source_has_phase2_types() -> bool:
	var file = FileAccess.open("res://scripts/PickupManager.gd", FileAccess.READ)
	if file == null:
		return false
	var text = file.get_as_text()
	return text.contains('"fruit"') and text.contains('"crate"')
