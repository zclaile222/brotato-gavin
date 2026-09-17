# WaveManager.gd — 波次状态机、计时、生成逻辑
class_name WaveManager
extends Node

enum State { WAVE, SHOP }

const ENEMY_SCENE   = preload("res://scenes/Enemy.tscn")
# 敌人类型表的解析路径。这里刻意用运行时 load() 而不是 const preload()：
# Enemy.gd 引用了 GameState 自动加载，若在解析期拉进来，
# 在 `--script` 形式的冒烟测试里会于自动加载注册之前编译失败，
# 而且失败结果会被写进全局脚本缓存，连带把后面加载的敌人实例一起弄坏。
const ENEMY_SCRIPT_PATH := "res://scripts/Enemy.gd"

# 波次数据来自 data/brotato/enemy_waves.json（BrotatoData.enemy_waves）。
# 下面这组是「目录不可用」时的兜底值，保证目录缺失时游戏仍能跑起来，
# 而不是整波刷不出敌人。
const DEFAULT_WAVE_DURATION = 60.0
const TOTAL_WAVES   = 20
# 刷怪间隔下界。保留 0.2 是为了与改造前一致：无尽波次靠敌人属性倍率加压，
# 不靠把间隔压到 0。
const MIN_SPAWN_INTERVAL = 0.2
const FALLBACK_SPAWN_INTERVAL = 0.2
const FALLBACK_WAVE_POOL = [
	{"type": "normal", "weight": 0.5},
	{"type": "fast", "weight": 0.2},
	{"type": "tank", "weight": 0.15},
	{"type": "ranged", "weight": 0.15},
]

const WAVE_MODIFIERS = [
	{"id": "none",        "name": "",               "desc": ""},
	{"id": "fast",        "name": "⚡ 急速",       "desc": "本波敌人速度+50%",        "color": Color(1,1,0)},
	{"id": "swarm",       "name": "🐜 虫群",       "desc": "本波敌人数量+60%",        "color": Color(0.8,0.5,0)},
	{"id": "elite_wave",  "name": "👑 精英波",     "desc": "所有敌人为精英类型",      "color": Color(1,0.8,0)},
	{"id": "gold_rain",   "name": "材料雨",        "desc": "击杀额外获得+2材料",      "color": Color(1,0.9,0.2)},
	{"id": "double_xp",   "name": "✨ 双倍XP",     "desc": "本波XP获得×2",            "color": Color(0.5,1,0.5)},
	{"id": "armored",     "name": "🛡 装甲波",     "desc": "所有敌人护甲+50%",        "color": Color(0.5,0.5,0.8)},
	{"id": "boss_rush",   "name": "💀 Boss狂潮",   "desc": "提前出现Boss",            "color": Color(1,0.3,0.3)},
	{"id": "healing",     "name": "💚 生命涌动",   "desc": "每击杀回复0.5HP",         "color": Color(0.2,1,0.4)},
	{"id": "tiny",        "name": "🔬 迷你",       "desc": "敌人体型缩小但速度+30%",  "color": Color(0.8,0.8,1)},
]

var state = State.WAVE
var wave_timer = 20.0
var spawn_timer = 0.0
var tree_spawn_timer = 10.0
var landmine_spawn_timer = 12.0
var current_modifier = WAVE_MODIFIERS[0]

# 波次表（来自目录）。为空时全部回落到上面的 FALLBACK_* 常量。
var _wave_table: Dictionary = {}
var _wave_fallback: Dictionary = {}
var _total_waves: int = TOTAL_WAVES
var _warned_pool_types: Dictionary = {}
var _active_bosses: Array = []
var _enemy_types: Dictionary = {}

var main: Node2D  # 引用 Main 节点

func setup(p_main: Node2D):
	main = p_main
	_load_wave_table()
	wave_timer = get_wave_duration(main.wave, GameState.endless_mode)

func _load_wave_table():
	var data = GameState.get_brotato_data()
	if data == null or not GameState.is_brotato_catalog_available():
		return
	_wave_table = data.enemy_waves.duplicate(true)
	_wave_fallback = data.enemy_wave_config.get("fallback", {}).duplicate(true)
	_total_waves = max(1, int(data.enemy_wave_config.get("total_waves", TOTAL_WAVES)))

func total_waves() -> int:
	return _total_waves

func has_wave_table() -> bool:
	return not _wave_table.is_empty()

# 敌人类型表（Enemy.ENEMY_TYPES）的懒解析入口。
# Enemy.setup() 会做 ENEMY_TYPES[type] 直查，未知类型是运行时硬错误，
# 所以取用波次表的类型名之前都要先经过这里核对。
func enemy_types() -> Dictionary:
	if _enemy_types.is_empty():
		var script = load(ENEMY_SCRIPT_PATH)
		if script != null:
			_enemy_types = script.ENEMY_TYPES
	return _enemy_types

func has_enemy_type(type_name: String) -> bool:
	return enemy_types().has(type_name)

func get_wave_entry(wave_num: int) -> Dictionary:
	return _wave_table.get(str(wave_num), {})

func get_wave_theme(wave_num: int) -> String:
	return str(get_wave_entry(wave_num).get("theme", ""))

func get_boss_type(wave_num: int) -> String:
	return str(get_wave_entry(wave_num).get("boss", ""))

func get_boss_count(wave_num: int) -> int:
	return max(0, int(get_wave_entry(wave_num).get("boss_count", 0)))

func _fallback_duration() -> float:
	return float(_wave_fallback.get("duration", DEFAULT_WAVE_DURATION))

func _fallback_spawn_interval() -> float:
	return float(_wave_fallback.get("spawn_interval", FALLBACK_SPAWN_INTERVAL))

func get_wave_duration(wave_num: int, endless_mode: bool = false) -> float:
	var entry = get_wave_entry(wave_num)
	if not entry.is_empty():
		return float(entry.get("duration", DEFAULT_WAVE_DURATION))
	# 目录里没有这一波（无尽模式）：沿用兜底值。
	if endless_mode and wave_num > total_waves():
		return DEFAULT_WAVE_DURATION
	return _fallback_duration()

func is_boss_wave() -> bool:
	return not get_boss_type(main.wave).is_empty()

func _get_endless_multiplier() -> float:
	if not GameState.endless_mode or main.wave <= total_waves():
		return 1.0
	return 1.0 + (main.wave - total_waves()) * 0.08

# ─── 波次处理（每帧由 Main._process 调用） ───

func process_wave(delta):
	wave_timer -= delta
	main.hud.update_timer(wave_timer)

	if wave_timer <= 0:
		_on_wave_end()
		return

	# 动态难度采样（每5秒）
	main._diff_timer += delta
	if main._diff_timer >= 5.0:
		_update_difficulty()

	# 难度越高，生成间隔越短。密度是两个因子的乘积：
	#   ① 强度倍率 —— 既有契约，get_difficulty_multiplier() 一直参与间隔缩放；
	#   ② Danger 密度倍率 —— 本次新增的档位旋钮（原版不改刷怪间隔，推导见 GameState）。
	# 两者在 Danger 1（基准档）都是 1.0，所以基准档的刷怪节奏与改造前逐字一致，
	# 21 套既有测试的间隔断言不受影响。
	var diff_mult = GameState.get_difficulty_multiplier() * GameState.get_danger_spawn_multiplier() * _get_endless_multiplier()
	var interval = get_spawn_interval(main.wave, diff_mult, main.difficulty_scale, _get_player_enemies_modifier())
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = interval
		spawn_enemy()
	tree_spawn_timer -= delta
	if tree_spawn_timer <= 0:
		tree_spawn_timer += 10.0
		_spawn_trees_for_tick()
	landmine_spawn_timer -= delta
	if landmine_spawn_timer <= 0:
		landmine_spawn_timer += 12.0
		_spawn_landmines_for_tick()

func get_spawn_interval(wave_num: int, diff_mult: float, difficulty_scale: float, enemies_percent: float = 0.0) -> float:
	# 基础间隔取自波次表，其余全是运行时缩放：
	# 难度倍率 / 动态难度 / 玩家的 enemies_percent。
	# 改造前这里是 `(2.0 - wave_num * 0.1)` 的线性式，第 20 波正好减到 0，
	# 于是 18 波之后全部被下界兜住 —— 曲线尾段是算出来的、不是设计出来的。
	var enemy_count_mult = max(0.05, 1.0 + enemies_percent)
	var base = float(get_wave_entry(wave_num).get("spawn_interval", _fallback_spawn_interval()))
	return max(MIN_SPAWN_INTERVAL, base / diff_mult / difficulty_scale / enemy_count_mult)

func _get_player_enemies_modifier() -> float:
	if main == null or main.player == null or not is_instance_valid(main.player):
		return 0.0
	return float(main.player.get("enemies_percent"))

func _update_difficulty():
	main._diff_timer = 0.0
	if not main.player or not is_instance_valid(main.player) or main.player.hp <= 0:
		main._recent_kills = 0
		return
	var hp_ratio = float(main.player.hp) / float(main.player.max_hp)
	var recent_hits = main.player.get_recent_damage_count(5.0)
	if hp_ratio > 0.8 and main._recent_kills > 10:
		main.difficulty_scale = min(2.0, main.difficulty_scale + 0.05)
	elif hp_ratio < 0.3 or recent_hits > 3:
		main.difficulty_scale = max(0.5, main.difficulty_scale - 0.05)
	main._recent_kills = 0

# ─── 敌人生成 ───

func _wave_pool(wave_num: int) -> Array:
	var pool = get_wave_entry(wave_num).get("pool", [])
	if not (pool is Array) or pool.is_empty():
		return FALLBACK_WAVE_POOL
	return pool

func _pick_enemy_type() -> String:
	return pick_enemy_type_for_wave(main.wave)

# 按波次表的权重抽取敌人类型。
# 改造前这里是「累积 append + 等概率抽取」：所有已登场类型权重相同，
# 且第 12 波之后池子不再变化 —— 13-20 波实际是同一波。
# 现在权重显式写在目录里，后期靠提高 armored/charger/elite 的权重完成
# 「数量 → 质量」的替换，而不是靠池子变大。
func pick_enemy_type_for_wave(wave_num: int) -> String:
	var candidates: Array = []
	var total_weight := 0.0
	for entry in _wave_pool(wave_num):
		if not (entry is Dictionary):
			continue
		var type_name := str(entry.get("type", ""))
		if type_name.is_empty():
			continue
		# 消费端兜底：Enemy.setup() 会做 ENEMY_TYPES[type] 直查，
		# 未知类型会直接运行时出错，所以这里先剔除，并且每个类型只告警一次。
		if not has_enemy_type(type_name):
			if not _warned_pool_types.has(type_name):
				_warned_pool_types[type_name] = true
				push_warning("波次表引用了未定义的敌人类型，已跳过: %s" % type_name)
			continue
		var weight := float(entry.get("weight", 0.0))
		if weight <= 0.0:
			continue
		candidates.append({"type": type_name, "weight": weight})
		total_weight += weight
	if candidates.is_empty():
		# 目录池被整池剔除（例如全部是未知类型）时回落到兜底池，
		# 否则这一波会完全刷不出敌人。
		for entry in FALLBACK_WAVE_POOL:
			candidates.append(entry.duplicate())
			total_weight += float(entry.get("weight", 0.0))
	if candidates.is_empty() or total_weight <= 0.0:
		return "normal"
	var roll := randf() * total_weight
	for entry in candidates:
		roll -= float(entry.get("weight", 0.0))
		if roll <= 0.0:
			return str(entry.get("type", "normal"))
	return str(candidates[candidates.size() - 1].get("type", "normal"))

# 供测试使用的确定性权重视图：{type: weight}
func wave_pool_weights(wave_num: int) -> Dictionary:
	var weights: Dictionary = {}
	for entry in _wave_pool(wave_num):
		if not (entry is Dictionary):
			continue
		var type_name := str(entry.get("type", ""))
		if type_name.is_empty():
			continue
		weights[type_name] = float(entry.get("weight", 0.0))
	return weights

func _pick_wave_modifier(wave_num: int):
	if wave_num <= 1 or randf() < 0.4:
		current_modifier = WAVE_MODIFIERS[0]
		return
	var options = WAVE_MODIFIERS.slice(1)
	current_modifier = options[randi() % options.size()]

func _apply_modifier_to_enemy(enemy):
	match current_modifier.id:
		"fast":
			enemy.base_speed *= 1.5
		"elite_wave":
			enemy.setup("elite", main.wave)
		"armored":
			enemy.armor_value = max(enemy.armor_value, 50)
		"tiny":
			enemy.scale *= 0.6
			enemy.base_speed *= 1.3
		"boss_rush":
			pass
	# 诅咒事件：敌人HP+50%
	if main.event_manager.event_active and main.event_manager.current_event and main.event_manager.current_event.id == "curse":
		enemy.hp = int(enemy.hp * 1.5)
		enemy.max_hp = int(enemy.max_hp * 1.5)

# 沿当前**相机可视矩形**的外圈随机取一点（矩形外扩 SPAWN_MARGIN）。
# 改造前这里用视口矩形：在固定相机下「视口外 30px」恰好等于「可视区外 30px」，
# 相机一跟随玩家，用视口就会把敌人刷在玩家脸上（视口中心 ≠ 画面中心了）。
# 现在统一按相机矩形算，语义回到原版：**在玩家看不到的地方入场，再走进画面**。
func _get_random_screen_edge() -> Vector2:
	var arena := Arena.get_active()
	if arena == null:
		# 无场地兜底：保留改造前的视口语义（固定相机下与相机矩形等价）
		var screen = main.get_viewport_rect().size
		match randi() % 4:
			0: return Vector2(randf_range(0, screen.x), -30)
			1: return Vector2(randf_range(0, screen.x), screen.y + 30)
			2: return Vector2(-30, randf_range(0, screen.y))
			3: return Vector2(screen.x + 30, randf_range(0, screen.y))
		return Vector2(-30, randf_range(0, screen.y))

	var view := arena.camera_view_rect()
	match randi() % 4:
		0: return Vector2(randf_range(view.position.x, view.end.x), view.position.y - 30.0)
		1: return Vector2(randf_range(view.position.x, view.end.x), view.end.y + 30.0)
		2: return Vector2(view.position.x - 30.0, randf_range(view.position.y, view.end.y))
		3: return Vector2(view.end.x + 30.0, randf_range(view.position.y, view.end.y))
	return Vector2(view.position.x - 30.0, randf_range(view.position.y, view.end.y))

# 场地内随机一点（树 / 地雷 / 花园 / 漂泊机器人这类「刷在地上」的东西）。
# 与刷怪不同，这些是玩家看得见的地面物件，所以范围是**整个场地**而不是相机外圈。
func _get_random_arena_position() -> Vector2:
	var arena := Arena.get_active()
	if arena == null:
		var screen = main.get_viewport_rect().size
		return Vector2(randf_range(40.0, max(40.0, screen.x - 40.0)), randf_range(40.0, max(40.0, screen.y - 40.0)))
	var world := arena.world_rect()
	return Vector2(
		randf_range(world.position.x + 40.0, max(world.position.x + 40.0, world.end.x - 40.0)),
		randf_range(world.position.y + 40.0, max(world.position.y + 40.0, world.end.y - 40.0))
	)

func _get_player_tree_spawn_bonus() -> int:
	if main == null or main.player == null or not is_instance_valid(main.player):
		return 0
	if main.player.get("tree_spawn_bonus_sources") == null:
		return 0
	return max(0, int(main.player.get("tree_spawn_bonus_sources")))

func roll_tree_spawn_count(tree_stat: float, random_roll: float = -1.0) -> int:
	var average = 0.5 + 0.33 * max(0.0, tree_stat)
	var count = int(floor(average))
	var fraction = average - float(count)
	var roll = randf() if random_roll < 0.0 else random_roll
	if roll < fraction:
		count += 1
	return max(0, count)

func _spawn_trees_for_tick():
	var count = roll_tree_spawn_count(float(_get_player_tree_spawn_bonus()))
	for i in range(count):
		spawn_tree(_get_random_arena_position())

func spawn_tree(pos: Vector2):
	var tree = main.get_enemy()
	tree.setup("tree", main.wave)
	if main.player and is_instance_valid(main.player) and tree.has_method("apply_catalog_modifiers"):
		tree.apply_catalog_modifiers(main.player)
	tree.position = pos
	if not tree.died.is_connected(main._on_enemy_died.bind(tree)):
		tree.died.connect(main._on_enemy_died.bind(tree))
	return tree

func _spawn_gardens_for_wave_start():
	if main == null or main.player == null or not is_instance_valid(main.player) or main.turret_manager == null:
		return
	var count = int(main.player.get("garden_spawn_sources")) if main.player.get("garden_spawn_sources") != null else 0
	for i in range(max(0, count)):
		main.turret_manager.spawn_garden(_get_random_arena_position(), 15.0)

func _spawn_catalog_structures_for_wave_start():
	_spawn_gardens_for_wave_start()
	_spawn_catalog_turrets_for_wave_start()
	_spawn_turret_variants_for_wave_start()
	_spawn_landmines_for_tick()

func _spawn_catalog_turrets_for_wave_start():
	if main == null or main.player == null or not is_instance_valid(main.player) or main.turret_manager == null:
		return
	var count = int(main.player.get("catalog_turret_sources")) if main.player.get("catalog_turret_sources") != null else 0
	for i in range(max(0, count)):
		main.turret_manager.spawn_catalog_turret(
			_get_random_arena_position(),
			float(main.player.get("catalog_turret_base_damage")),
			float(main.player.get("catalog_turret_engineering_coefficient")),
			float(main.player.get("catalog_turret_range")),
			float(main.player.get("catalog_turret_cooldown"))
		)

func _spawn_landmines_for_tick():
	if main == null or main.player == null or not is_instance_valid(main.player) or main.turret_manager == null:
		return
	var count = int(main.player.get("landmine_spawn_sources")) if main.player.get("landmine_spawn_sources") != null else 0
	for i in range(max(0, count)):
		main.turret_manager.spawn_landmine(
			_get_random_arena_position(),
			float(main.player.get("landmine_base_damage")),
			float(main.player.get("landmine_engineering_coefficient")),
			float(main.player.get("landmine_base_radius"))
		)

func _spawn_turret_variants_for_wave_start():
	if main == null or main.player == null or not is_instance_valid(main.player) or main.turret_manager == null:
		return
	var explosive_count = int(main.player.get("explosive_turret_sources")) if main.player.get("explosive_turret_sources") != null else 0
	for i in range(max(0, explosive_count)):
		main.turret_manager.spawn_damage_turret_variant(
			_get_random_arena_position(),
			"explosive_turret",
			float(main.player.get("explosive_turret_base_damage")),
			float(main.player.get("explosive_turret_engineering_coefficient")),
			float(main.player.get("explosive_turret_range")),
			float(main.player.get("explosive_turret_cooldown")),
			{
				"uses_explosion_modifiers": true,
				"explosion_radius": float(main.player.get("explosive_turret_radius")),
				"body_color": Color(0.95, 0.36, 0.18),
				"barrel_color": Color(1.0, 0.74, 0.18),
			}
		)
	var incendiary_count = int(main.player.get("incendiary_turret_sources")) if main.player.get("incendiary_turret_sources") != null else 0
	for i in range(max(0, incendiary_count)):
		main.turret_manager.spawn_damage_turret_variant(
			_get_random_arena_position(),
			"incendiary_turret",
			float(main.player.get("incendiary_turret_base_damage")),
			float(main.player.get("incendiary_turret_engineering_coefficient")),
			float(main.player.get("incendiary_turret_range")),
			float(main.player.get("incendiary_turret_cooldown")),
			{
				"ammo_type": "fire",
				"applies_burn": true,
				"hit_count": int(main.player.get("incendiary_turret_hit_count")),
				"body_color": Color(0.95, 0.42, 0.14),
				"barrel_color": Color(1.0, 0.88, 0.24),
			}
		)
	var laser_count = int(main.player.get("laser_turret_sources")) if main.player.get("laser_turret_sources") != null else 0
	for i in range(max(0, laser_count)):
		main.turret_manager.spawn_damage_turret_variant(
			_get_random_arena_position(),
			"laser_turret",
			float(main.player.get("laser_turret_base_damage")),
			float(main.player.get("laser_turret_engineering_coefficient")),
			float(main.player.get("laser_turret_range")),
			float(main.player.get("laser_turret_cooldown")),
			{
				"body_color": Color(0.55, 0.42, 1.0),
				"barrel_color": Color(0.45, 0.95, 1.0),
			}
		)
	var medical_count = int(main.player.get("medical_turret_sources")) if main.player.get("medical_turret_sources") != null else 0
	for i in range(max(0, medical_count)):
		main.turret_manager.spawn_medical_turret(
			_get_random_arena_position(),
			float(main.player.get("medical_turret_base_healing")),
			float(main.player.get("medical_turret_engineering_heal_coefficient")),
			float(main.player.get("medical_turret_range")),
			float(main.player.get("medical_turret_cooldown"))
		)
	var builders_count = int(main.player.get("builders_turret_sources")) if main.player.get("builders_turret_sources") != null else 0
	for i in range(max(0, builders_count)):
		main.turret_manager.spawn_builders_turret(_get_random_arena_position())
	var tyler_count = int(main.player.get("tyler_sources")) if main.player.get("tyler_sources") != null else 0
	for i in range(max(0, tyler_count)):
		main.turret_manager.spawn_tyler(
			_get_random_arena_position(),
			int(main.player.get("tyler_projectiles")),
			float(main.player.get("tyler_base_damage")),
			float(main.player.get("tyler_engineering_coefficient")),
			float(main.player.get("tyler_elemental_coefficient")),
			float(main.player.get("tyler_range")),
			float(main.player.get("tyler_cooldown"))
		)
	var wandering_bot_count = int(main.player.get("wandering_bot_sources")) if main.player.get("wandering_bot_sources") != null else 0
	for i in range(max(0, wandering_bot_count)):
		main.turret_manager.spawn_wandering_bot(
			_get_random_arena_position(),
			float(main.player.get("wandering_bot_slow_percent")),
			float(main.player.get("wandering_bot_slow_duration")),
			float(main.player.get("wandering_bot_radius"))
		)

func spawn_enemy():
	var type = _pick_enemy_type()
	if type == "swarm":
		for i in range(3):
			_spawn_single_enemy("swarm")
		_spawn_loot_aliens_from_chance()
		_spawn_additional_elites_from_chance()
		return
	_spawn_single_enemy(type)
	if current_modifier.id == "swarm" and randf() < 0.6:
		_spawn_single_enemy(_pick_enemy_type())
	_spawn_loot_aliens_from_chance()
	_spawn_additional_elites_from_chance()

func _spawn_single_enemy(type: String):
	var enemy = main.get_enemy()
	enemy.setup(type, main.wave)
	_apply_modifier_to_enemy(enemy)
	if main.player and is_instance_valid(main.player) and enemy.has_method("apply_catalog_modifiers"):
		enemy.apply_catalog_modifiers(main.player)
	var em = _get_endless_multiplier()
	if em > 1.0:
		enemy.base_speed *= em
		enemy.hp = int(enemy.hp * em)
		enemy.max_hp = int(enemy.max_hp * em)
		enemy.contact_damage = int(enemy.contact_damage * em)
	enemy.position = _get_random_screen_edge()
	if not enemy.died.is_connected(main._on_enemy_died.bind(enemy)):
		enemy.died.connect(main._on_enemy_died.bind(enemy))

func roll_loot_alien_bonus_spawn_count(random_roll: float = -1.0) -> int:
	if main == null or main.player == null or not is_instance_valid(main.player):
		return 0
	var chance = clamp(float(main.player.get("loot_alien_chance_percent")), 0.0, 0.95)
	if chance <= 0.0:
		return 0
	var roll = randf() if random_roll < 0.0 else random_roll
	return 1 if roll < chance else 0

func _spawn_loot_aliens_from_chance():
	var count = roll_loot_alien_bonus_spawn_count()
	for i in range(count):
		spawn_loot_alien(_get_random_screen_edge())

func roll_additional_elite_spawn_count(random_roll: float = -1.0) -> int:
	if main == null or main.player == null or not is_instance_valid(main.player):
		return 0
	var chance_value = main.player.get("additional_elite_chance")
	if chance_value == null:
		return 0
	# Danger 层叠加的**额外**精英概率（推导见 GameState.DANGER_ELITE_CHANCES）。
	# 只做加法：波次表里第 12-20 波的精英权重（7%→16%）与玩家道具（如 Candy Bag +10%）
	# 都不受影响；Danger 1 时该值为 0，所以基准档行为与改造前一致。
	var chance = clamp(float(chance_value) + GameState.get_danger_elite_chance(), 0.0, 0.95)
	if chance <= 0.0:
		return 0
	var roll = randf() if random_roll < 0.0 else random_roll
	return 1 if roll < chance else 0

func _spawn_additional_elites_from_chance(random_roll: float = -1.0) -> int:
	var count = roll_additional_elite_spawn_count(random_roll)
	for i in range(count):
		spawn_special_enemy(_get_random_screen_edge())
	return count

func spawn_loot_alien(pos: Vector2):
	var enemy = main.get_enemy()
	enemy.setup("loot_alien", main.wave)
	if main.player and is_instance_valid(main.player) and enemy.has_method("apply_catalog_modifiers"):
		enemy.apply_catalog_modifiers(main.player)
	enemy.position = pos
	if not enemy.died.is_connected(main._on_enemy_died.bind(enemy)):
		enemy.died.connect(main._on_enemy_died.bind(enemy))
	return enemy

func _spawn_pending_loot_aliens_for_wave_start():
	if main == null or main.player == null or not is_instance_valid(main.player):
		return
	var count = int(main.player.get("next_wave_loot_alien_count_pending")) if main.player.get("next_wave_loot_alien_count_pending") != null else 0
	if count <= 0:
		return
	main.player.next_wave_loot_alien_count_pending = 0
	for i in range(count):
		spawn_loot_alien(_get_random_screen_edge())

func _spawn_pending_special_enemies_for_wave_start():
	if main == null or main.player == null or not is_instance_valid(main.player):
		return
	var count = int(main.player.get("next_wave_special_enemy_count_pending")) if main.player.get("next_wave_special_enemy_count_pending") != null else 0
	if count <= 0:
		return
	main.player.next_wave_special_enemy_count_pending = 0
	for i in range(count):
		spawn_special_enemy(_get_random_screen_edge())

func spawn_special_enemy(pos: Vector2):
	var enemy = main.get_enemy()
	enemy.setup("elite", main.wave)
	if main.player and is_instance_valid(main.player) and enemy.has_method("apply_catalog_modifiers"):
		enemy.apply_catalog_modifiers(main.player)
	enemy.position = pos
	if not enemy.died.is_connected(main._on_enemy_died.bind(enemy)):
		enemy.died.connect(main._on_enemy_died.bind(enemy))
	return enemy

func spawn_boss(boss_type: String = "", position_offset: Vector2 = Vector2.ZERO):
	# Boss 类型由波次表决定（第 5/10/15/20 波各不相同），留空则取当前波的定义。
	var resolved_type := boss_type
	if resolved_type.is_empty():
		resolved_type = get_boss_type(main.wave)
	if resolved_type.is_empty():
		resolved_type = "boss"
	if not has_enemy_type(resolved_type):
		push_warning("未定义的 Boss 类型，回退为 boss: %s" % resolved_type)
		resolved_type = "boss"
	var boss = ENEMY_SCENE.instantiate()
	boss.setup(resolved_type, main.wave)
	if main.player and is_instance_valid(main.player) and boss.has_method("apply_catalog_modifiers"):
		boss.apply_catalog_modifiers(main.player)
	boss.position = Vector2(640, -60) + position_offset
	# 血条只跟随「主 Boss」（列表中第一个存活的）。
	# 多 Boss 时若各自直连 HUD，会互相覆盖；而且先死的那个会把还活着的 Boss 的血条一起藏掉。
	_active_bosses.append(boss)
	boss.died.connect(main._on_enemy_died.bind(boss))
	boss.died.connect(_on_boss_died.bind(boss))
	boss.hp_changed.connect(_on_boss_hp_changed.bind(boss))
	boss.phase_changed.connect(main._on_boss_phase_changed)
	main.add_child(boss)
	_refresh_boss_bar()
	# 与 spawn_tree / spawn_loot_alien / spawn_special_enemy 保持一致，返回实例便于调用方持有
	return boss

func _prune_bosses():
	var alive: Array = []
	for boss in _active_bosses:
		if boss != null and is_instance_valid(boss) and not boss.is_queued_for_deletion():
			alive.append(boss)
	_active_bosses = alive

func _on_boss_hp_changed(hp, max_hp, boss):
	_prune_bosses()
	if _active_bosses.is_empty() or _active_bosses[0] != boss:
		return
	main.hud.update_boss_bar(hp, max_hp)

func _on_boss_died(boss):
	_active_bosses.erase(boss)
	# 还有 Boss 存活时把血条交接给它，全部清空才隐藏。
	_refresh_boss_bar()

func _refresh_boss_bar():
	_prune_bosses()
	if _active_bosses.is_empty():
		main.hud.hide_boss_bar()
		return
	main.hud.show_boss_bar(_active_bosses[0].hp, _active_bosses[0].max_hp)

func _spawn_miniboss():
	var mb = ENEMY_SCENE.instantiate()
	mb.setup("miniboss", main.wave)
	if main.player and is_instance_valid(main.player) and mb.has_method("apply_catalog_modifiers"):
		mb.apply_catalog_modifiers(main.player)
	mb.position = _get_random_screen_edge()
	mb.died.connect(main._on_enemy_died.bind(mb))
	mb.hp_changed.connect(main.hud.update_boss_bar)
	mb.died.connect(main.hud.hide_boss_bar)
	mb.phase_changed.connect(main._on_boss_phase_changed)
	main.add_child(mb)
	main.hud.show_boss_bar(mb.hp, mb.max_hp)

# ─── 波次开始 ───

func advance_wave():
	main.wave += 1
	wave_timer = get_wave_duration(main.wave, GameState.endless_mode)
	spawn_timer = 0.0
	tree_spawn_timer = 10.0
	landmine_spawn_timer = 12.0
	state = State.WAVE
	_active_bosses.clear()
	main.hud.set_arrows_enabled(true)
	if main.has_node("/root/AudioManager"):
		main.get_node("/root/AudioManager").start_battle_bgm()
	main.hud.update_wave(main.wave, total_waves())
	main.hud.update_timer(wave_timer)

	# 清除上波double_xp效果
	if main.player and is_instance_valid(main.player):
		if main.player.get_meta("double_xp_active", false):
			main.player.xp_boost /= 2.0
			main.player.set_meta("double_xp_active", false)

	# 随机波次修饰词
	_pick_wave_modifier(main.wave)
	if current_modifier.id != "none":
		main.hud.show_wave_modifier(current_modifier.name, current_modifier.desc, current_modifier.color)
	else:
		# 没有修饰词时用波次主题占位 —— 这是波次表「每波可命名」原则的落点：
		# 玩家需要知道这一波由什么构成，才能做出针对性决策。
		var theme_name := get_wave_theme(main.wave)
		if theme_name.is_empty():
			main.hud.show_wave_modifier("", "", Color.WHITE)
		else:
			main.hud.show_wave_modifier("第 %d 波 · %s" % [main.wave, theme_name], "", Color(0.85, 0.9, 1.0))

	# double_xp修饰词
	if current_modifier.id == "double_xp" and main.player and is_instance_valid(main.player):
		main.player.xp_boost *= 2.0
		main.player.set_meta("double_xp_active", true)

	# boss_rush修饰词
	if current_modifier.id == "boss_rush" and not is_boss_wave():
		spawn_boss()

	# 重置当波统计
	main.wave_kills = 0
	main.wave_hits_taken = 0
	if main.pickup_manager != null:
		main.pickup_manager.begin_wave()
	if main.player and is_instance_valid(main.player):
		if main.economy != null:
			main.economy.begin_wave_snapshot()
		main.wave_gold_start = main.player.gold
		main.wave_xp_start = main.player.xp + (main.player.level - 1) * 10

	# 每波回血 + 角色被动触发
	if main.player and is_instance_valid(main.player):
		main.player.wave_regen()
		main.player.on_wave_start(main.wave)
		_spawn_catalog_structures_for_wave_start()
		_spawn_pending_loot_aliens_for_wave_start()
		_spawn_pending_special_enemies_for_wave_start()

	# Boss 波次生成 Boss：类型与数量都由波次表决定（第 20 波为双 Boss）。
	# 数量 > 1 时左右分开出场，避免两只叠在同一点。
	var boss_count := get_boss_count(main.wave)
	for i in range(boss_count):
		var offset := Vector2.ZERO
		if boss_count > 1:
			offset = Vector2(-220.0 + 440.0 * float(i), 0.0)
		spawn_boss("", offset)

	# 每10波生成 miniboss
	if main.wave % 10 == 0 and not is_boss_wave():
		_spawn_miniboss()
	elif main.wave >= 10 and main.wave % 5 == 0 and not is_boss_wave():
		_spawn_miniboss()

	# 无尽模式额外生成
	if GameState.endless_mode:
		if main.wave > 30:
			_spawn_miniboss()
		if main.wave > 40:
			spawn_boss()

# ─── 波次结束 ───

func _on_wave_end():
	state = State.SHOP
	# 通知 Main 处理清理和结算
	main._on_wave_ended()
