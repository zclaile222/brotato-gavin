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

	var packed = load("res://scenes/Main.tscn")
	main = packed.instantiate()
	root.add_child(main)
	await process_frame

	_check_scene_boot()
	await _check_material_pickup_path()
	_check_enemy_pool_visual_reset()
	_check_enemy_status_effect_visibility()
	await _check_upgrade_choice_sequence()
	_check_shop_material_spend_and_lock()

	if is_instance_valid(main):
		main.queue_free()
	main = null
	for i in range(5):
		await process_frame

	if failures.is_empty():
		print("PHASE1_MAIN_SCENE_SMOKE_PASS")
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
		"res://scripts/UpgradeChoiceRules.gd",
		"res://scripts/PlayerCore.gd",
		"res://scripts/PlayerCombat.gd",
		"res://scripts/PlayerUpgrades.gd",
		"res://scripts/PlayerBuffs.gd",
		"res://scripts/PlayerStats.gd",
		"res://scripts/HUDCore.gd",
		"res://scripts/HUDCombat.gd",
		"res://scripts/HUDPanels.gd",
		"res://scripts/ShopRules.gd",
		"res://scripts/WaveManager.gd",
		"res://scripts/PickupManager.gd",
		"res://scripts/TurretManager.gd",
		"res://scripts/EventManager.gd",
	]
	for path in class_scripts:
		var script = load(path)
		if script == null:
			failures.append("Failed to preload script class: " + path)

func _check_scene_boot():
	if main == null or not is_instance_valid(main):
		failures.append("Main scene did not instantiate")
		return
	if main.get_script() == null:
		failures.append("Main scene script did not load")
		return
	var player = main.get("player")
	var hud = main.get("hud")
	var shop = main.get("shop")
	var economy = main.get("economy")
	var wave_manager = main.get("wave_manager")
	if player == null or not is_instance_valid(player):
		failures.append("Main scene did not resolve player")
	if hud == null or not is_instance_valid(hud):
		failures.append("Main scene did not create HUD")
	if shop == null or not is_instance_valid(shop):
		failures.append("Main scene did not create shop")
	if economy == null or not is_instance_valid(economy):
		failures.append("Main scene did not create RunEconomy")
	if wave_manager == null or wave_manager.get_wave_duration(1, false) != 20.0:
		failures.append("WaveManager did not expose wave 1 duration")
	if wave_manager != null and wave_manager.wave_timer != 20.0:
		failures.append("Main scene did not start wave 1 at 20 seconds")
	if hud != null and not hud.gold_label.text.contains("材料"):
		failures.append("HUD currency label does not use materials wording")

func _check_material_pickup_path():
	if main == null or main.get_script() == null:
		return
	if main.player == null or main.economy == null:
		return
	var starting_materials = main.economy.materials
	var starting_xp = main.player.xp
	var orb = main.get_xp_orb()
	orb.activate(main.player.position, 3)
	orb._on_body_entered(main.player)
	if main.economy.materials != starting_materials + 3:
		failures.append("Material pickup did not increase economy materials")
	if main.player.xp != starting_xp + 3:
		failures.append("Material pickup did not increase XP")
	if not main.hud.gold_label.text.contains("材料"):
		failures.append("HUD currency label lost materials wording after pickup")
	await create_timer(0.4).timeout

func _check_enemy_pool_visual_reset():
	if main == null or main.get_script() == null:
		return
	var ghost = main.get_enemy()
	ghost.setup("ghost", 8)
	ghost.modulate = Color(1, 1, 1, 0.3)
	ghost.get_node("Body").visible = false
	ghost.get_node("Body").modulate = Color(1, 1, 1, 0.0)
	ghost.ghost_invincible = true
	main.recycle_enemy(ghost)
	var reused = main.get_enemy()
	reused.setup("normal", 1)
	if not reused.visible:
		failures.append("Reused enemy should be visible after pool checkout")
	if reused.modulate.a < 0.99:
		failures.append("Reused enemy should reset root alpha to opaque")
	var body = reused.get_node_or_null("Body")
	if body == null:
		failures.append("Reused enemy should keep a Body node")
	else:
		if not body.visible:
			failures.append("Reused enemy Body should be visible")
		if body.modulate.a < 0.99 or body.color.a < 0.99:
			failures.append("Reused enemy Body should reset alpha to opaque")
	if not reused.is_physics_processing() or not reused.is_processing():
		failures.append("Reused enemy should restore process and physics processing")
	main.recycle_enemy(reused)

func _check_enemy_status_effect_visibility():
	if main == null or main.get_script() == null or main.player == null:
		return
	var ghost = main.get_enemy()
	ghost.setup("ghost", 8)
	ghost.position = main.player.position + Vector2(120, 0)
	ghost.ghost_timer = 0.0
	ghost._physics_process(0.016)
	if not ghost.ghost_invincible:
		failures.append("Ghost enemy should enter invincible state for visibility check")
	_assert_enemy_readable(ghost, "Ghost invincible enemy")
	main.recycle_enemy(ghost)

	var elite = main.get_enemy()
	elite.setup("elite", 12)
	elite.elite_trait = "ghost"
	elite.position = main.player.position + Vector2(140, 0)
	elite.ghost_timer = 0.0
	elite._physics_process(0.016)
	if not elite.ghost_invincible:
		failures.append("Elite ghost trait enemy should enter invincible state for visibility check")
	_assert_enemy_readable(elite, "Elite ghost trait enemy")
	main.recycle_enemy(elite)

func _assert_enemy_readable(enemy, label: String):
	if enemy.modulate.a < 0.70:
		failures.append(label + " should keep readable root alpha")
	var body = enemy.get_node_or_null("Body")
	if body == null:
		failures.append(label + " should keep a Body node")
		return
	if not body.visible:
		failures.append(label + " Body should be visible")
	var effective_alpha = enemy.modulate.a * body.modulate.a * body.color.a
	if effective_alpha < 0.70:
		failures.append(label + " should keep readable effective alpha")

func _check_upgrade_choice_sequence():
	if main == null or main.get_script() == null:
		return
	if main.player == null or main.hud == null:
		return
	main.player.gain_xp(main.player.xp_to_next)
	if not main.player.has_pending_level_ups():
		failures.append("Level-up did not queue a pending upgrade")
	main._resolve_next_level_up_or_shop()
	if main.run_phase != 3:
		failures.append("Main did not enter LEVEL_UPS phase for pending level-up")
	if main.hud.upgrade_panel == null or not main.hud.upgrade_panel.visible:
		failures.append("Upgrade choice panel did not appear")
	var choices = 0
	for button in main.hud.upgrade_choice_buttons:
		if button.visible:
			choices += 1
	if choices != 4:
		failures.append("Upgrade choice panel did not show four choices")
	main._on_upgrade_choice_selected(0)
	if main.player.has_pending_level_ups():
		failures.append("Selecting an upgrade did not consume pending level-up")
	if not main.shop.visible:
		failures.append("Shop did not open after resolving pending upgrade")
	await create_timer(1.4).timeout

func _check_shop_material_spend_and_lock():
	if main == null or main.get_script() == null:
		return
	if main.player == null or main.shop == null or main.economy == null:
		return
	main.player.earn_gold(500)
	main.shop.open(1, main.economy.materials, main.player.luck, main.player)
	if main.shop.current_items.size() != 4:
		failures.append("Shop did not roll four items")
		return
	main.shop.locked_indices.clear()
	main.shop.locked_indices.append(0)
	var locked_name = main.shop.current_items[0].name
	main.shop._on_reroll_pressed()
	if main.shop.current_items[0].name != locked_name:
		failures.append("Locked shop slot changed after reroll")
	var before_buy_materials = main.economy.materials
	var buy_index = _find_purchasable_shop_index()
	if buy_index == -1:
		failures.append("Shop did not roll a purchasable item for material spend check")
		return
	var item = main.shop.current_items[buy_index]
	var rarity = item.get("rolled_rarity", item.get("rarity", 0))
	var item_price_modifier = float(main.player.get("item_price_percent")) if main.player.get("item_price_percent") != null else 0.0
	var price = main.shop.shop_rules.get_price(item.price, rarity, main.shop.wave_num, item_price_modifier)
	if before_buy_materials < price:
		main.player.earn_gold(price - before_buy_materials + 10)
		before_buy_materials = main.economy.materials
	main.shop.player_gold = main.economy.materials
	var dummy_button = Button.new()
	var dummy_label = Label.new()
	main.shop._on_buy_pressed(buy_index, dummy_button, dummy_label)
	dummy_button.free()
	dummy_label.free()
	if main.economy.materials != before_buy_materials - price:
		failures.append("Shop purchase did not spend materials through RunEconomy")

func _find_purchasable_shop_index() -> int:
	for i in range(main.shop.current_items.size()):
		var item = main.shop.current_items[i]
		if item.get("type", "") != "weapon":
			return i
		var tier = int(item.get("tier", item.get("rolled_rarity", item.get("rarity", 0)) + 1))
		if main.player.can_equip_or_combine_weapon(item.get("weapon_type", ""), tier):
			return i
	return -1
