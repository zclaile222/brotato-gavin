extends Node2D

const HUD_SCENE     = preload("res://scenes/HUD.tscn")
const SHOP_SCENE    = preload("res://scenes/Shop.tscn")
# 总波数与 Boss 波次统一由 WaveManager 从 data/brotato/enemy_waves.json 读取，
# 这里不再保留副本 —— 否则改数据后这些判据会静默漂移。

enum RunPhase { COMBAT, WAVE_END, CRATE_REWARDS, LEVEL_UPS, SHOP, GAME_OVER }

var wave        = 1
var kills       = 0
var game_over   = false
var victory     = false
var run_phase   = RunPhase.COMBAT

var hud    = null
var shop   = null
var player = null
var camera: Camera2D
# 场地与世界边界的单一数据源（Arena.gd）。必须是 Main 的**第一个子节点** ——
# 相机跟随与背景重建都依赖它已就绪。见 Arena.gd 顶部对「为什么不做 autoload」的说明。
var arena: Arena
var shake_strength = 0.0
var economy: RunEconomy

# 当波统计
var wave_kills = 0
var wave_gold_start = 0
var wave_xp_start = 0
var pending_crate_rewards: Array = []
var loot_rules = preload("res://scripts/LootRules.gd").new()

# 解锁条件追踪
var max_gold_held = 0 # Transitional name; tracks max materials held.
var total_hits_taken = 0
var max_combo_reached = 0
var wave_hits_taken = 0

# 小地图更新计时
var _minimap_timer = 0.0

# 动态难度系统
var difficulty_scale = 1.0
var _diff_timer = 0.0
var _recent_kills = 0

# 对象池
const BULLET_POOL_SIZE = 80
const ENEMY_BULLET_POOL_SIZE = 60
const XP_ORB_POOL_SIZE = 40
const ENEMY_POOL_INITIAL = 30

var bullet_pool = []
var enemy_bullet_pool = []
var xp_orb_pool = []
var _enemy_pool = []

var bullet_scene = preload("res://scenes/Bullet.tscn")
var enemy_bullet_scene = preload("res://scenes/EnemyBullet.tscn")
var xp_orb_scene = preload("res://scenes/XPOrb.tscn")

# Manager 子节点
var wave_manager: WaveManager
var pickup_manager: PickupManager
var turret_manager: TurretManager
var event_manager: EventManager

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	economy = RunEconomy.new()
	economy.name = "RunEconomy"
	add_child(economy)
	economy.reset(0)

	# 场地必须先于相机与背景建立：相机跟随要按场地钳位，
	# 背景（Main.tscn 里的兄弟节点）在 _ready 时也要先认领到它。
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)

	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()
	# 相机不再固定在屏幕中心，而是每帧跟随玩家并在场地边缘钳位。
	# `__arena_follow` 用 set_meta 打标记而不是加一个脚本：Main.gd 没有 class_name，
	# 给它挂内部脚本会引入一个只有一行的文件，不如一个显式标记好读。
	camera.set_meta("__arena_follow", true)
	arena.setup_camera(camera)

	# 初始化 Managers
	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	wave_manager.setup(self)

	pickup_manager = PickupManager.new()
	pickup_manager.name = "PickupManager"
	add_child(pickup_manager)
	pickup_manager.setup(self)

	turret_manager = TurretManager.new()
	turret_manager.name = "TurretManager"
	add_child(turret_manager)
	turret_manager.setup(self)

	event_manager = EventManager.new()
	event_manager.name = "EventManager"
	add_child(event_manager)
	event_manager.setup(self)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	economy.materials_changed.connect(hud.update_gold)

	shop = SHOP_SCENE.instantiate()
	add_child(shop)
	shop.item_purchased.connect(_on_item_purchased)
	shop.wave_started.connect(_on_wave_started)

	player = get_node_or_null("Player")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player:
		player.hp_changed.connect(hud.update_hp)
		player.xp_changed.connect(hud.update_xp)
		player.level_up.connect(_on_level_up)
		player.weapons_changed.connect(hud.update_weapons)
		player.hurt.connect(_on_player_hurt)
		player.died.connect(_on_player_died)
		player.gold_changed.connect(hud.update_gold)
		player.economy = economy
		economy.materials_changed.connect(player.recalculate_material_scaling_max_hp)
		economy.reset(player.gold)
		player.shield_changed.connect(hud.update_shield)
		player.synergy_activated.connect(_on_synergy_activated)
		player.buff_changed.connect(hud.update_buffs)
		player.request_turret.connect(turret_manager.on_request_turret)
		player.request_undead.connect(turret_manager.on_request_undead)

	hud.update_wave(wave, wave_manager.total_waves())
	hud.update_timer(wave_manager.wave_timer)

	hud.event_accepted.connect(event_manager.on_event_accepted)
	hud.event_rejected.connect(event_manager.on_event_rejected)
	hud.combo_milestone.connect(_on_combo_milestone)
	hud.upgrade_choice_selected.connect(_on_upgrade_choice_selected)
	hud.crate_reward_taken.connect(_on_crate_reward_taken)
	hud.crate_reward_recycled.connect(_on_crate_reward_recycled)

	_init_pools()

	hud.set_arrows_enabled(true)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").start_battle_bgm()

	hud.show_tutorial_hint()
	hud.show_notification("第1波开始！消灭所有敌人！", Color(0.5, 1, 0.5))

func _init_pools():
	for i in BULLET_POOL_SIZE:
		var b = bullet_scene.instantiate()
		b.visible = false
		b.set_process(false)
		add_child(b)
		bullet_pool.append(b)
	for i in ENEMY_BULLET_POOL_SIZE:
		var b = enemy_bullet_scene.instantiate()
		b.visible = false
		b.set_process(false)
		add_child(b)
		enemy_bullet_pool.append(b)
	for i in XP_ORB_POOL_SIZE:
		var o = xp_orb_scene.instantiate()
		o.visible = false
		o.set_process(false)
		add_child(o)
		xp_orb_pool.append(o)
	# 敌人池
	# ⚠ 顺序敏感：Node.set_physics_process() / set_process() 在节点进入场景树之前调用会被忽略
	#   —— 内部标记已等于目标值（false）时 setter 直接早退，而节点进入场景树时又会因为脚本
	#   定义了 _physics_process 而重新启用处理。因此必须「先 add_child，再 recycle()」。
	#   否则预建的 30 个敌人会每物理帧运行完整 AI（朝玩家移动并造成接触伤害），
	#   并借 Enemy._ensure_visible() 把 visible 拨回 true，使 get_enemy() 的
	#   `if not e.visible` 永远匹配不到空闲实例 —— 敌人池形同虚设，每次刷怪都新建节点。
	var enemy_scene = preload("res://scenes/Enemy.tscn")
	for i in ENEMY_POOL_INITIAL:
		var e = enemy_scene.instantiate()
		add_child(e)
		e.recycle()
		_enemy_pool.append(e)

func get_bullet() -> Node:
	for b in bullet_pool:
		if not b.visible:
			return b
	var b = bullet_scene.instantiate()
	add_child(b)
	bullet_pool.append(b)
	return b

func get_enemy_bullet() -> Node:
	for b in enemy_bullet_pool:
		if not b.visible:
			return b
	var b = enemy_bullet_scene.instantiate()
	add_child(b)
	enemy_bullet_pool.append(b)
	return b

func get_xp_orb() -> Node:
	for o in xp_orb_pool:
		if not o.visible:
			return o
	var o = xp_orb_scene.instantiate()
	add_child(o)
	xp_orb_pool.append(o)
	return o

# ─── 敌人对象池 ───

func get_enemy() -> Node:
	for e in _enemy_pool:
		if not e.visible:
			e.visible = true
			e.set_physics_process(true)
			e.set_process(true)
			if not e.is_in_group("enemies"):
				e.add_to_group("enemies")
			return e
	var enemy_scene = preload("res://scenes/Enemy.tscn")
	var e = enemy_scene.instantiate()
	add_child(e)
	_enemy_pool.append(e)
	return e

func recycle_enemy(enemy):
	for sig_name in ["died", "hp_changed", "phase_changed"]:
		for conn in enemy.get_signal_connection_list(sig_name):
			if enemy.is_connected(sig_name, conn.callable):
				enemy.disconnect(sig_name, conn.callable)
	enemy.recycle()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if game_over or victory:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
			return
		toggle_pause()

func toggle_pause():
	if get_tree().paused:
		get_tree().paused = false
		hud.hide_pause_menu()
	else:
		get_tree().paused = true
		hud.show_pause_menu(player)

func _process(delta):
	# 相机跟随在暂停检查**之前**：Main 是 PROCESS_MODE_ALWAYS，
	# 暂停菜单打开时也应该继续对准玩家（否则暂停那一下相机停在旧位置，
	# 受击抖动会把画面推出世界边缘）。
	# ⚠ 顺序敏感：tick() 刷新视口尺寸必须早于 follow() 用它做钳位。
	if arena != null and is_instance_valid(arena):
		arena.tick()
		if player != null and is_instance_valid(player):
			arena.follow(player.position)

	if get_tree().paused:
		return

	if shake_strength > 0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		shake_strength = lerp(shake_strength, 0.0, 12.0 * delta)
	else:
		if player and is_instance_valid(player) and player.hp > 0 and float(player.hp) / float(player.max_hp) <= 0.2:
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		else:
			camera.offset = Vector2.ZERO

	if game_over or victory:
		if Input.is_key_pressed(KEY_R):
			restart_game()
		return

	if wave_manager.state == WaveManager.State.WAVE:
		wave_manager.process_wave(delta)

		# 小地图更新（每0.1秒）
		_minimap_timer += delta
		if _minimap_timer >= 0.1:
			_minimap_timer = 0.0
			if player and is_instance_valid(player):
				hud.update_minimap(player.position, get_tree().get_nodes_in_group("enemies"), pickup_manager.active_pickup_nodes)

		# 工程师炮塔处理
		turret_manager.process_turrets(delta)
		# 死灵法师亡灵处理
		turret_manager.process_undeads(delta)
		turret_manager.process_gardens(delta)
		turret_manager.process_landmines(delta)
		turret_manager.process_wandering_bots(delta)
		# 更新被动指示器
		if hud.has_method("update_passive_indicator"):
			hud.update_passive_indicator(player)

# 是否处于战斗阶段。玩家用它在非战斗阶段停火 ——
# 波次结束后玩家仍留在树上（process_mode = PAUSABLE，而商店阶段并不暂停整棵树），
# 不设门就会在结算 / 开箱 / 升级 / 商店里继续开火。
func is_combat_phase() -> bool:
	return run_phase == RunPhase.COMBAT

func restart_game():
	for b in bullet_pool:
		if b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()
	for b in enemy_bullet_pool:
		if b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()
	for o in xp_orb_pool:
		if o.visible and o.has_method("_return_to_pool"):
			o._return_to_pool()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	if player and is_instance_valid(player):
		pickup_manager.collect_all_active_for_wave_end(player)
	pickup_manager.cleanup()
	turret_manager.cleanup()

	wave = 1
	kills = 0
	game_over = false
	victory = false
	shake_strength = 0.0

	hud.hide_boss_bar()
	get_tree().reload_current_scene()

func _is_boss_wave() -> bool:
	# 唯一判据在波次表里，这里只做转发
	if wave_manager == null:
		return false
	return wave_manager.is_boss_wave()

# ─── 波次事件处理 ───

func _on_wave_started():
	run_phase = RunPhase.COMBAT
	# 通关判断
	if wave >= wave_manager.total_waves() and not GameState.endless_mode:
		victory = true
		run_phase = RunPhase.GAME_OVER
		_save_record()
		hud.set_arrows_enabled(false)
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").stop_bgm()
		hud.show_victory(kills, wave, player)
		var new_achievements = _check_end_achievements()
		if not new_achievements.is_empty():
			hud.show_achievements_summary(new_achievements)
		return

	wave_manager.advance_wave()

	# 特殊事件触发
	event_manager.try_trigger_event()

func _on_wave_ended():
	# 波次结束（由 WaveManager._on_wave_end 调用）
	run_phase = RunPhase.WAVE_END
	hud.set_arrows_enabled(false)
	# 清除double_xp效果
	if player and is_instance_valid(player):
		if player.get_meta("double_xp_active", false):
			player.xp_boost /= 2.0
			player.set_meta("double_xp_active", false)
		if player.has_method("on_wave_end"):
			player.on_wave_end()
	# 清除特殊事件效果
	event_manager.clear_event_effects()
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").start_shop_bgm()
	hud.hide_boss_bar()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		recycle_enemy(enemy)
	# 回收战场上的子弹。原来只回收敌人、不回收子弹，于是敌方子弹会一路飞进商店阶段 ——
	# 玩家站在商店里仍然会被打（「回合结束了还在射击」的另一半）。
	# 「重开一局」的 restart_game() 一直有这段清理，波末路径漏了。
	for b in bullet_pool:
		if is_instance_valid(b) and b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()
	for b in enemy_bullet_pool:
		if is_instance_valid(b) and b.visible and b.has_method("_return_to_pool"):
			b._return_to_pool()
	for orb in xp_orb_pool:
		if orb.visible:
			var value = orb.material_value if "material_value" in orb else orb.xp_value
			if economy != null:
				economy.add_to_bag(value)
			if orb.has_method("_return_to_pool"):
				orb._return_to_pool()
	pickup_manager.cleanup()
	turret_manager.cleanup()

	# 计算本波获得的材料和XP
	var earned_gold = 0
	var earned_xp = 0
	if player and is_instance_valid(player):
		earned_gold = economy.get_wave_material_gain() if economy != null else player.gold - wave_gold_start
		earned_xp = player.xp + (player.level - 1) * 10 - wave_xp_start

	hud.show_wave_summary(wave, wave_kills, earned_gold, earned_xp, _is_boss_wave())

	# Boss波通关成就
	if _is_boss_wave():
		if wave == 5:
			hud.show_notification("击败首个Boss！", Color(1, 0.6, 0))
		elif wave == 10:
			hud.show_notification("击败第二个Boss！半程完成！", Color(1, 0.7, 0.2))
		elif wave == 20:
			hud.show_notification("击败最终Boss！", Color(1, 0.85, 0.0))
	if wave in [5, 10, 15]:
		hud.show_notification("已通过第 %d 波！" % wave, Color(0.5, 1, 0.8))

	# 波次成就检查
	if wave >= 5:
		_try_achievement("wave_5")
	if wave >= 10:
		_try_achievement("wave_10")
	if wave_hits_taken == 0:
		_try_achievement("no_damage_wave")
	if GameState.endless_mode and wave >= 30:
		_try_achievement("endless_30")

	# 材料利息
	if player and is_instance_valid(player) and player.gold_interest > 0:
		var interest = int(player.gold * player.gold_interest)
		if interest > 0:
			player.earn_gold(interest)

	var materials_held = economy.materials if economy != null else (player.gold if player and is_instance_valid(player) else 0)
	if materials_held > max_gold_held:
		max_gold_held = materials_held
	await get_tree().create_timer(2.0).timeout
	_resolve_next_crate_reward_or_level_up()

func enqueue_crate_reward(crate_tier: int):
	var player_luck = player.luck if player and is_instance_valid(player) else 0
	var recycling_bonus = float(player.get("recycling_materials_percent")) if player and is_instance_valid(player) else 0.0
	var reward = loot_rules.create_crate_reward(shop.ITEM_POOL, wave, player_luck, crate_tier, shop.shop_rules, recycling_bonus)
	if reward.is_empty():
		return
	pending_crate_rewards.append(reward)
	var extra_chance = float(player.get("extra_crate_reward_chance")) if player and is_instance_valid(player) and player.get("extra_crate_reward_chance") != null else 0.0
	if extra_chance > 0.0 and randf() < extra_chance:
		var extra_reward = loot_rules.create_crate_reward(shop.ITEM_POOL, wave, player_luck, crate_tier, shop.shop_rules, recycling_bonus)
		if not extra_reward.is_empty():
			pending_crate_rewards.append(extra_reward)
	var extra_pearl_chance = float(player.get("extra_pearl_crate_chance")) if player and is_instance_valid(player) and player.get("extra_pearl_crate_chance") != null else 0.0
	if extra_pearl_chance > 0.0 and randf() < extra_pearl_chance:
		var pearl_reward = _create_specific_crate_reward("pearl", crate_tier, recycling_bonus)
		if not pearl_reward.is_empty():
			pending_crate_rewards.append(pearl_reward)

func _create_specific_crate_reward(source_id: String, crate_tier: int, recycling_bonus: float = 0.0) -> Dictionary:
	if shop == null or not is_instance_valid(shop):
		return {}
	for item in shop.ITEM_POOL:
		if str(item.get("source_id", item.get("id", ""))) != source_id:
			continue
		var reward = item.duplicate(true)
		var rarity = int(reward.get("rarity", 0))
		if crate_tier >= 4:
			rarity = max(rarity, 3)
		reward["rolled_rarity"] = clamp(rarity, 0, 3)
		reward["crate_tier"] = crate_tier
		reward["recycle_value"] = loot_rules.get_recycle_value(int(reward.get("price", 1)), int(reward.get("rolled_rarity", 0)), wave, shop.shop_rules, recycling_bonus)
		return reward
	return {}

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
		Effects.crate_open_burst(player.position, int(reward.get("tier", int(reward.get("rolled_rarity", reward.get("rarity", 0))) + 1)))
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

func _open_shop_after_rewards():
	run_phase = RunPhase.SHOP
	var materials = 0
	if economy != null:
		materials = economy.materials
	elif player and is_instance_valid(player):
		materials = player.gold
	if materials > max_gold_held:
		max_gold_held = materials
	var luck = player.luck if player and is_instance_valid(player) else 0
	shop.open(wave, materials, luck, player)

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

func _on_item_purchased(upgrade):
	if player and is_instance_valid(player):
		player.gold = economy.materials if economy != null else shop.player_gold
		player.gold_changed.emit(player.gold)
		player.apply_upgrade(upgrade)
		if shop and is_instance_valid(shop) and player.has_method("consume_mirror_duplicate_for_shop_item") and player.consume_mirror_duplicate_for_shop_item(upgrade):
			var tracked = upgrade.duplicate(true)
			tracked["paid_price"] = 0
			tracked["mirror_duplicate"] = true
			shop.purchased_items.append(tracked)
			shop._refresh_sell_area()
	if shop and is_instance_valid(shop) and shop.visible:
		shop.update_gold(player.gold if player and is_instance_valid(player) else 0)

# ─── 敌人死亡处理 ───

func _on_enemy_died(enemy = null):
	var is_tree = enemy != null and is_instance_valid(enemy) and enemy.get("enemy_type") != null and str(enemy.get("enemy_type")) == "tree"
	if not is_tree:
		kills += 1
		_recent_kills += 1
		wave_kills += 1
		hud.update_kills(kills)
		hud.add_combo_kill()
		if hud.combo_count > max_combo_reached:
			max_combo_reached = hud.combo_count
		# 波次修饰词击杀效果
		if player and is_instance_valid(player):
			if wave_manager.current_modifier.id == "gold_rain":
				player.earn_gold(2)
			if wave_manager.current_modifier.id == "healing":
				player.heal(0.5)
		# 特殊事件击杀效果
		event_manager.on_enemy_died(enemy)
	elif player and is_instance_valid(player) and player.has_method("on_tree_killed"):
		player.on_tree_killed(enemy)
	# 战利品掉落
	if enemy and is_instance_valid(enemy):
		pickup_manager._try_spawn_pickup(enemy)
	# 通用敌人死亡触发：用于 Cyberball / 后续击杀类 catalog item 迁移。
	if not is_tree and player and is_instance_valid(player) and player.has_method("on_enemy_died"):
		player.on_enemy_died(enemy)
	# 通知玩家击杀
	if not is_tree and player and is_instance_valid(player) and player.has_method("on_kill"):
		player.on_kill()
	# 成就检测
	if not is_tree:
		_check_achievements()

# ─── HUD 回调 ───

func _on_player_hurt():
	shake_strength = 10.0
	hud.flash_damage()
	total_hits_taken += 1
	wave_hits_taken += 1

func _on_synergy_activated(synergy_name: String):
	hud.show_notification("协同激活：" + synergy_name, Color(1.0, 0.85, 0.2))
	_try_achievement("full_synergy")

func _on_level_up(lv):
	hud.update_level(lv)
	hud.show_level_up()

func _on_boss_phase_changed(p_phase: int):
	hud.update_boss_phase(p_phase)
	shake_strength = 15.0 if p_phase == 2 else 10.0
	match p_phase:
		1:
			hud.show_notification("Boss 进入强化阶段！", Color(1.0, 0.6, 0.1))
		2:
			hud.show_notification("Boss 狂暴化！", Color(1.0, 0.15, 0.1))

func _on_combo_milestone(count: int):
	if not player or not is_instance_valid(player):
		return
	var bonus_xp = count
	var orb_count = count / 5
	for i in range(orb_count):
		var orb = get_xp_orb()
		if orb:
			var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
			orb.activate(player.position + offset, bonus_xp)
	hud.show_notification("%dx 连击奖励！+%d 经验！" % [count, bonus_xp * orb_count], Color(0.5, 1, 0.5))

# ─── 成就系统 ───

func _check_achievements():
	if kills == 1:
		hud.show_notification("首次击杀！", Color(1, 1, 0.5))
		_try_achievement("first_blood")
	if kills in [10, 50, 100, 500]:
		hud.show_notification("已击杀 %d 个敌人！" % kills, Color(1, 0.8, 0.3))
	if kills >= 100:
		_try_achievement("kill_100")
	if kills >= 500:
		_try_achievement("kill_500")
	if player and is_instance_valid(player) and player.equipped_weapons.size() >= 5:
		_try_achievement("all_weapons")
	if hud.combo_count in [5, 10, 15, 20]:
		hud.show_notification("%dx 连击！" % hud.combo_count, Color(1, 0.5, 0.2))
	if player and is_instance_valid(player) and player.level in [5, 10, 15, 20]:
		hud.show_notification("达到 %d 级！" % player.level, Color(0.5, 0.8, 1))

func _save_record():
	SaveSystem.update_record(wave, kills)
	if GameState.endless_mode:
		SaveSystem.update_endless_record(wave)
	_check_unlock_conditions()

func _check_unlock_conditions():
	var p_level = player.level if player and is_instance_valid(player) else 1
	if GameState.has_method("is_brotato_catalog_available") and GameState.is_brotato_catalog_available():
		if victory:
			# 通关于 Danger N 时解锁 win_with_danger_0..N（目录 characters.json 里
			# 0..5 六条条件都真实存在，对应原版 D0-D5 各自的通关解锁）。
			# 改造前只写到 2（隐含「简单/普通/困难」三档），六级模型下会漏掉
			# Danger 3/4/5 三条解锁；这里改成按当前档位展开，并夹到合法区间，
			# 避免非法难度值把循环放大成 0..N 的无意义查询。
			var win_danger: int = clampi(GameState.difficulty, GameState.MIN_DANGER, GameState.MAX_DANGER)
			for danger_id in range(win_danger + 1):
				_try_unlock_condition("win_with_danger_%d" % danger_id)
			if player and is_instance_valid(player) and int(player.get("curse")) <= 0:
				_try_unlock_condition("finish_run_with_0_curse")
		if kills >= 300:
			_try_unlock_condition("kill_300_enemies")
		if kills >= 2000:
			_try_unlock_condition("kill_2000_enemies")
		if kills >= 5000:
			_try_unlock_condition("kill_5000_enemies")
		if kills >= 10000:
			_try_unlock_condition("kill_10000_enemies")
		if kills >= 20000:
			_try_unlock_condition("kill_20000_enemies")
		if max_gold_held >= 300:
			_try_unlock_condition("collect_300_materials")
		if max_gold_held >= 2000:
			_try_unlock_condition("collect_2000_materials")
		if max_gold_held >= 3000:
			_try_unlock_condition("hold_3000_materials")
		if max_gold_held >= 5000:
			_try_unlock_condition("collect_5000_materials")
		if max_gold_held >= 10000:
			_try_unlock_condition("collect_10000_materials")
		if max_gold_held >= 20000:
			_try_unlock_condition("collect_20000_materials")
		if p_level >= 20:
			_try_unlock_condition("reach_level_20")
		if p_level >= 10 and wave < 6:
			_try_unlock_condition("reach_level_10_before_wave_6")
		return

	if victory:
		_try_unlock("gunner")
	if wave_kills >= 30:
		_try_unlock("berserker")
	if wave >= 5:
		_try_unlock("engineer")
	# 旧判据 `difficulty == 2` 表达的是「在困难模式下通关」。旧「困难」的敌人强度倍率
	# 1.40 正好等于新模型 Danger 5 的倍率，所以按强度换算到 LEGACY_HARD_DANGER。
	# （这里用 >= 而不是 ==：难度等级是单调的，通关高难档自然也满足「至少困难」。）
	if victory and GameState.difficulty >= GameState.LEGACY_HARD_DANGER:
		_try_unlock("ninja")
	if p_level >= 20:
		_try_unlock("wizard")
	if total_hits_taken >= 500 and not game_over:
		_try_unlock("knight")
	if wave < 15 and kills >= 100:
		_try_unlock("archer")
	if max_gold_held >= 200:
		_try_unlock("merchant")
	if max_combo_reached >= 10:
		_try_unlock("berserker2")

func _try_unlock_condition(condition: String):
	if condition == "" or not GameState.has_method("get_character_ids_for_unlock_condition"):
		return
	for char_id in GameState.get_character_ids_for_unlock_condition(condition):
		_try_unlock(char_id)

func _try_unlock(char_id: String):
	if not SaveSystem.is_character_unlocked(char_id):
		SaveSystem.unlock_character(char_id)
		var char_name = GameState.get_character_display_name(char_id) if GameState.has_method("get_character_display_name") else char_id
		hud.show_notification("解锁新角色：%s！" % char_name, Color(1, 0.85, 0.0))

func _try_achievement(id: String):
	if SaveSystem.unlock_achievement(id):
		var info = SaveSystem.ACHIEVEMENTS.get(id, {"name": id, "desc": ""})
		hud.show_achievement_unlock(info.name, info.desc)

func _check_end_achievements() -> Array:
	var new_unlocks = []
	if player and is_instance_valid(player) and player.total_damage_dealt >= 10000:
		if SaveSystem.unlock_achievement("damage_10000"):
			new_unlocks.append("damage_10000")
	if kills >= 100 and SaveSystem.unlock_achievement("kill_100"):
		new_unlocks.append("kill_100")
	if kills >= 500 and SaveSystem.unlock_achievement("kill_500"):
		new_unlocks.append("kill_500")
	if wave >= 5 and SaveSystem.unlock_achievement("wave_5"):
		new_unlocks.append("wave_5")
	if wave >= 10 and SaveSystem.unlock_achievement("wave_10"):
		new_unlocks.append("wave_10")
	if GameState.endless_mode and wave >= 30 and SaveSystem.unlock_achievement("endless_30"):
		new_unlocks.append("endless_30")
	if player and is_instance_valid(player) and player.equipped_weapons.size() >= 5:
		if SaveSystem.unlock_achievement("all_weapons"):
			new_unlocks.append("all_weapons")
	return new_unlocks

func _on_player_died():
	game_over = true
	run_phase = RunPhase.GAME_OVER
	_save_record()
	var new_achievements = _check_end_achievements()
	hud.set_arrows_enabled(false)
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").stop_bgm()
	hud.show_game_over(kills, wave, player)
	if not new_achievements.is_empty():
		hud.show_achievements_summary(new_achievements)
