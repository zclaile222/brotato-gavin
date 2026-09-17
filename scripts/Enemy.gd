extends CharacterBody2D

const ENEMY_BULLET_SCENE = preload("res://scenes/EnemyBullet.tscn")
const XP_ORB_SCENE = preload("res://scenes/XPOrb.tscn")
const BURN_ZONE_SCENE = preload("res://scenes/BurnZone.tscn")
const GHOST_INVINCIBLE_MODULATE = Color(1, 1, 1, 0.78)

const ENEMY_TYPES = {
	"normal":         {"spd": 80,  "hp_m": 1.0,  "sc": 1.0,  "color": Color(0.9, 0.2, 0.2),  "xp": 1,  "dmg": 1, "dist": 0,   "gold": 2},
	"fast":           {"spd": 170, "hp_m": 0.5,  "sc": 0.65, "color": Color(1.0, 0.6, 0.0),  "xp": 2,  "dmg": 1, "dist": 0,   "gold": 1},
	"tank":           {"spd": 45,  "hp_m": 3.0,  "sc": 1.7,  "color": Color(0.5, 0.1, 0.8),  "xp": 3,  "dmg": 2, "dist": 0,   "gold": 5},
	"ranged":         {"spd": 55,  "hp_m": 0.8,  "sc": 0.9,  "color": Color(0.2, 0.85, 0.3), "xp": 2,  "dmg": 0, "dist": 240, "gold": 3},
	"boss":           {"spd": 50,  "hp_m": 10.0, "sc": 2.4,  "color": Color(1.0, 0.55, 0.0), "xp": 20, "dmg": 2, "dist": 0,   "gold": 30},
	# --- 元素 Boss 变体（docs/boss-variants-design.md「通用实现方案」）---
	# 取值即设计文档「P0 — 数据定义」一节：火焰偏进攻、冰霜偏控制（最慢最厚）、雷电偏机动（最快最脆）。
	# 目前它们之间只差 数据 + 弹幕元素 + 阶段速度倍率；
	# 各自的独特机制（火焰冲锋 / 冰甲+冻结脉冲 / 闪现+链式闪电）属文档里的 P2，尚未实现。
	"boss_fire":      {"spd": 55,  "hp_m": 9.0,  "sc": 2.4,  "color": Color(1.0, 0.3, 0.0),  "xp": 22, "dmg": 2, "dist": 0,   "gold": 32},
	"boss_frost":     {"spd": 40,  "hp_m": 12.0, "sc": 2.6,  "color": Color(0.4, 0.7, 1.0),  "xp": 24, "dmg": 2, "dist": 0,   "gold": 35},
	"boss_lightning": {"spd": 65,  "hp_m": 8.0,  "sc": 2.2,  "color": Color(0.9, 0.9, 0.2),  "xp": 25, "dmg": 3, "dist": 0,   "gold": 35},
	# --- 新增敌人类型 ---
	"exploder":       {"spd": 50,  "hp_m": 0.6,  "sc": 0.8,  "color": Color(1.0, 0.3, 0.0),  "xp": 2,  "dmg": 1, "dist": 0,   "gold": 3},
	"healer":         {"spd": 40,  "hp_m": 1.5,  "sc": 0.9,  "color": Color(0.2, 1.0, 0.5),  "xp": 3,  "dmg": 1, "dist": 0,   "gold": 4},
	"swarm":          {"spd": 200, "hp_m": 0.3,  "sc": 0.5,  "color": Color(1.0, 1.0, 0.3),  "xp": 1,  "dmg": 2, "dist": 0,   "gold": 1},
	"armored":        {"spd": 35,  "hp_m": 2.5,  "sc": 1.3,  "color": Color(0.5, 0.5, 0.6),  "xp": 3,  "dmg": 1, "dist": 0,   "gold": 4},
	"ghost":          {"spd": 70,  "hp_m": 1.0,  "sc": 0.85, "color": Color(0.6, 0.8, 1.0),  "xp": 3,  "dmg": 1, "dist": 0,   "gold": 4},
	"shooter_spread": {"spd": 45,  "hp_m": 1.0,  "sc": 1.0,  "color": Color(0.9, 0.2, 0.6),  "xp": 3,  "dmg": 0, "dist": 220, "gold": 4},
	"charger":        {"spd": 30,  "hp_m": 1.2,  "sc": 1.1,  "color": Color(0.8, 0.4, 0.1),  "xp": 2,  "dmg": 3, "dist": 0,   "gold": 3},
	"summoner":       {"spd": 35,  "hp_m": 2.0,  "sc": 1.2,  "color": Color(0.6, 0.1, 0.6),  "xp": 5,  "dmg": 1, "dist": 0,   "gold": 6},
	"elite":          {"spd": 80,  "hp_m": 2.0,  "sc": 1.3,  "color": Color(1.0, 0.85, 0.0), "xp": 5,  "dmg": 2, "dist": 0,   "gold": 6},
	"miniboss":       {"spd": 45,  "hp_m": 6.0,  "sc": 2.0,  "color": Color(0.8, 0.3, 0.1),  "xp": 12, "dmg": 2, "dist": 0,   "gold": 18},
	"tree":           {"spd": 0,   "hp_m": 0.0,  "sc": 1.2,  "color": Color(0.2, 0.65, 0.25), "xp": 3,  "dmg": 0, "dist": 0,   "gold": 0},
	"loot_alien":     {"spd": 130, "hp_m": 1.0,  "sc": 0.9,  "color": Color(0.25, 0.95, 0.75), "xp": 0,  "dmg": 1, "dist": 0,   "gold": 0},
}

# Boss 家族 = 基础 Boss + 三个元素变体。
# 此前四处写着 `enemy_type == "boss" or enemy_type == "miniboss"`，
# 加变体时必然漏改其中一处（漏了会静默退化：血条不更新、阶段不切换、死后不回收到池），
# 因此收敛成常量 + is_boss_type()。
const BOSS_TYPES := ["boss", "boss_fire", "boss_frost", "boss_lightning"]

# Boss 变体 → 弹幕元素。基础 Boss 刻意不配元素，以保持「均衡」定位作为对照。
# 元素 → 实际效果 的映射只有一份，在 PlayerStatus 里。
const BOSS_ELEMENTS := {
	"boss_fire": "fire",
	"boss_frost": "frost",
	"boss_lightning": "lightning",
}

const PHASE1_SPEED_MULT := {
	"boss_fire": 1.25,
	"boss_frost": 1.15,
	"boss_lightning": 1.3,
}
const PHASE2_SPEED_MULT := {
	"boss_fire": 1.20,
	"boss_frost": 1.13,
	"boss_lightning": 1.15,
}

# ─── 元素 Boss 独特机制参数（docs/boss-variants-design.md 的 P2 部分） ───
# 取值即设计文档 §1.3 / §2.3 / §3.3 的规格；集中在这里便于 playtest 调平衡。
# 每个 Boss 只用自己的那几个常量，互不干扰。

# 火焰（§1.3 阶段1/阶段2）
const FIRE_CHARGE_INTERVAL_P1 := 4.0
const FIRE_CHARGE_INTERVAL_P2 := 2.5
const FIRE_CHARGE_DURATION := 0.4
const FIRE_CHARGE_SPEED_MULT := 8.0
const BURN_ZONE_SPACING := 40.0     # 冲锋路径上每隔这么多像素留一团火
const BURN_ZONE_DURATION_P1 := 3.0
const BURN_ZONE_DURATION_P2 := 5.0
const BURN_ZONE_RADIUS := 60.0
const FIRE_AURA_RADIUS := 80.0
const FIRE_AURA_TICK := 0.5

# 冰霜（§2.3 阶段1/阶段2）
const FROST_ARMOR_REDUCTION := 30    # armor_value 的单位是百分比（与 armored 的 50 一致）
const FROST_ARMOR_ON_TIME := 5.0
const FROST_ARMOR_OFF_TIME := 4.0
const FREEZE_PULSE_INTERVAL := 5.0
const FREEZE_PULSE_CHARGE := 1.0     # 蓄力预警时长（颜色渐变为纯白）
const FREEZE_PULSE_STUN := 1.5       # 玩家侧没有 apply_freeze，用 apply_stun 表达「冻结」

# 雷电（§3.3 阶段0/1/2）
const BLINK_INTERVAL_P1 := 3.5
const BLINK_INTERVAL_P2 := 2.0
const BLINK_MIN_DIST := 100.0
const BLINK_MAX_DIST := 200.0
const BLINK_SPIRAL_P1 := 8
const BLINK_SPIRAL_P2 := 12
const CHAIN_INTERVAL_P0 := 2.5
const CHAIN_INTERVAL_P1 := 1.5
const CHAIN_INTERVAL_P2 := 1.0
const CHAIN_BOUNCES_P0 := 1
const CHAIN_BOUNCES_P1 := 2
const CHAIN_BOUNCES_P2 := 3
const STORM_INTERVAL := 4.0
const STORM_DELAY := 0.8             # 预警圈到落雷的延迟
const STORM_DAMAGE := 3
const STORM_STUN := 0.5
const STORM_RADIUS := 90.0

var enemy_type = "normal"
var base_speed = 80.0
var hp = 3
var max_hp = 3
var xp_drop = 1
var gold_value = 2
var contact_damage = 1
var preferred_dist = 0.0
var contact_timer = 0.0
var shoot_timer = 0.0
var player = null

# 新敌人类型专用变量
var armor_value = 0           # armored: 子弹伤害减少
var ghost_timer = 0.0         # ghost: 无敌切换计时
var ghost_invincible = false  # ghost: 当前是否无敌
var charger_timer = 0.0       # charger: 冲刺计时
var charger_rushing = false   # charger: 是否在冲刺中
var charger_dir = Vector2.ZERO
var summoner_timer = 0.0      # summoner: 召唤计时
var healer_timer = 0.0        # healer: 治疗计时
var _player_in_contact = false  # ContactArea overlap tracking
var elite_trait = ""          # elite: 随机获得的特性

# 状态效果
var burn_timer = 0.0     # 燃烧剩余时间（>0 表示燃烧中）
var burn_tick = 0.0      # 燃烧 tick 计时
var burn_tick_interval = 0.5
var burn_source = null
var damage_taken_percent_bonus = 0.0
var damage_taken_bonus_timer = 0.0
var damage_taken_bonus_key = ""
var freeze_timer = 0.0   # 冻结剩余时间
var _slow_timer = 0.0    # 减速剩余时间
var _slow_factor = 1.0   # 减速系数（0.3=减速30%）
var _stun_timer = 0.0    # 眩晕剩余时间
var catalog_hit_slow_percent = 0.0
var catalog_cursed = false

# Boss阶段系统
var phase = 0            # 当前阶段（0=正常, 1=强化, 2=狂暴）
var phase_shoot_timer = 0.0  # 阶段特殊攻击计时

# ─── 元素 Boss 独特机制状态 ───
# 每个 Boss 只用自己的那组变量；分计时器而不共用「一个通用计时器」，
# 否则雷电 Boss 的三个周期机制（链式/闪现/雷暴）会互相吃掉计时。
# 火焰：冲锋 + 烈焰光环
var _fire_charge_timer = 0.0
var _dash_timer = 0.0            # > 0 表示冲锋剩余时间
var _dash_dir = Vector2.ZERO
var _dash_travel = 0.0           # 本次冲锋已走过的距离（按间距留火）
var _aura_timer = 0.0
# 冰霜：冰甲 + 冻结脉冲
var _frost_armor_on = false
var _frost_armor_timer = 0.0
var _freeze_pulse_timer = 0.0
var _freeze_charge = 0.0         # > 0 表示正在蓄力（此期间不得施加冻结）
# 雷电：链式闪电 + 闪现 + 雷暴领域
var _chain_timer = 0.0
var _blink_timer = 0.0
var _storm_timer = 0.0
var _storm_pending: Array = []   # [{position, timer, radius}]

signal died
signal hp_changed(hp, max_hp)
signal phase_changed(phase)

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("enemies")
	if get_tree() != null:
		player = get_tree().get_first_node_in_group("player")
	$ContactArea.body_entered.connect(_on_contact_entered)
	$ContactArea.body_exited.connect(_on_contact_exited)

func _on_contact_entered(body):
	if body.is_in_group("player"):
		_player_in_contact = true

func _on_contact_exited(body):
	if body.is_in_group("player"):
		_player_in_contact = false

# ─── Boss 家族判定（唯一判据，避免散落的字符串比较漏改） ───

func is_boss_type() -> bool:
	return enemy_type in BOSS_TYPES

# Boss 与小 Boss 共用「追踪 + 阶段 + 弹幕」那套行为
func uses_boss_behavior() -> bool:
	return is_boss_type() or enemy_type == "miniboss"

# 该敌人弹幕携带的元素（"" = 无元素）
func bullet_element() -> String:
	return str(BOSS_ELEMENTS.get(enemy_type, ""))

func recycle():
	visible = false
	set_physics_process(false)
	set_process(false)
	_reset_visual_state()
	if is_in_group("neutral_trees"):
		remove_from_group("neutral_trees")
	if is_in_group("enemies"):
		# 空闲池实例不算活敌人：炮台/地雷/小地图/AoE 都以 enemies 组为扫描范围，
		# get_enemy() 取用时会把组员身份加回来（与 Enemy.die() 的处理保持一致）。
		remove_from_group("enemies")
	burn_timer = 0.0
	burn_tick = 0.0
	burn_tick_interval = 0.5
	burn_source = null
	burn_base_damage = 1
	burn_instances_remaining = 0
	damage_taken_percent_bonus = 0.0
	damage_taken_bonus_timer = 0.0
	damage_taken_bonus_key = ""
	catalog_cursed = false
	if has_meta("catalog_cursed"):
		remove_meta("catalog_cursed")
	freeze_timer = 0.0
	_slow_timer = 0.0
	_slow_factor = 1.0
	catalog_hit_slow_percent = 0.0
	_stun_timer = 0.0
	ghost_invincible = false
	charger_rushing = false
	contact_timer = 0.0
	shoot_timer = 0.0
	_player_in_contact = false
	velocity = Vector2.ZERO
	if has_meta("hp_bar"):
		var bar = get_meta("hp_bar")
		if is_instance_valid(bar):
			bar.queue_free()
		remove_meta("hp_bar")

func setup(type_name: String, wave_num: int):
	enemy_type = type_name
	var d = ENEMY_TYPES[type_name]
	_reset_spawn_state()
	_ensure_visible()
	catalog_cursed = false
	if has_meta("catalog_cursed"):
		remove_meta("catalog_cursed")
	if enemy_type == "tree":
		base_speed = 0.0
		hp = 8
		max_hp = 8
		xp_drop = 3
		gold_value = 0
		contact_damage = 0
		preferred_dist = 0.0
		armor_value = 0
		$Body.color = d.color
		scale = Vector2(d.sc, d.sc)
		UnitVisual.apply(self, $Body, type_name)
		_sync_collision_extents()
		if is_in_group("enemies"):
			remove_from_group("enemies")
		if not is_in_group("neutral_trees"):
			add_to_group("neutral_trees")
		return
	if is_in_group("neutral_trees"):
		remove_from_group("neutral_trees")
	if not is_in_group("enemies"):
		add_to_group("enemies")
	var diff_mult = GameState.get_difficulty_multiplier()
	base_speed     = (d.spd + wave_num * 2.0) * diff_mult
	hp             = max(1, int((2 + wave_num) * d.hp_m * diff_mult))
	max_hp         = hp
	xp_drop        = d.xp + int(wave_num / 3)
	gold_value     = d.gold
	contact_damage = max(1, int(d.dmg * diff_mult))
	preferred_dist = d.dist
	$Body.color = d.color
	scale = Vector2(d.sc, d.sc)
	# 单位视觉（精灵或程序化几何）+ 按视觉反推碰撞体
	UnitVisual.apply(self, $Body, type_name)
	_sync_collision_extents()

	# 特殊类型初始化
	if enemy_type == "armored":
		armor_value = 50  # 伤害减少50%
	elif enemy_type == "ghost":
		ghost_timer = 3.0
	elif enemy_type == "charger":
		charger_timer = 2.0
	elif enemy_type == "summoner":
		summoner_timer = 5.0
	elif enemy_type == "healer":
		healer_timer = 3.0
	elif enemy_type == "elite":
		# 随机获得 fast/armored/ghost 之一的特性
		var traits = ["fast", "armored", "ghost"]
		elite_trait = traits[randi() % traits.size()]
		if elite_trait == "fast":
			base_speed *= 1.8
		elif elite_trait == "armored":
			armor_value = 50
		elif elite_trait == "ghost":
			ghost_timer = 3.0

	# 头顶血条：miniboss, elite, tank, armored
	if enemy_type in ["miniboss", "elite", "tank", "armored"]:
		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = max_hp
		bar.value = hp
		bar.custom_minimum_size = Vector2(50, 6)
		bar.position = Vector2(-25, -scale.y * 25 - 10)
		bar.show_percentage = false
		var fg_style = StyleBoxFlat.new()
		fg_style.bg_color = Color(0.2, 0.9, 0.2)
		bar.add_theme_stylebox_override("fill", fg_style)
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.3, 0.1, 0.1)
		bar.add_theme_stylebox_override("background", bg_style)
		add_child(bar)
		set_meta("hp_bar", bar)
	_ensure_visible()

func _reset_spawn_state():
	visible = true
	set_process(true)
	set_physics_process(true)
	_reset_visual_state()
	armor_value = 0
	ghost_timer = 0.0
	ghost_invincible = false
	charger_timer = 0.0
	charger_rushing = false
	charger_dir = Vector2.ZERO
	summoner_timer = 0.0
	healer_timer = 0.0
	elite_trait = ""
	burn_timer = 0.0
	burn_tick = 0.0
	burn_tick_interval = 0.5
	burn_source = null
	burn_base_damage = 1
	burn_instances_remaining = 0
	damage_taken_percent_bonus = 0.0
	damage_taken_bonus_timer = 0.0
	damage_taken_bonus_key = ""
	freeze_timer = 0.0
	_slow_timer = 0.0
	_slow_factor = 1.0
	_stun_timer = 0.0
	catalog_hit_slow_percent = 0.0
	catalog_cursed = false
	phase = 0
	phase_shoot_timer = 0.0
	# 元素机制的定时器必须在这里初始化（而不是只依赖阶段切换），
	# 否则雷电 Boss 的链式闪电在阶段 0 就会带着 0 计时器立刻开火。
	_fire_charge_timer = FIRE_CHARGE_INTERVAL_P1
	_dash_timer = 0.0
	_dash_dir = Vector2.ZERO
	_dash_travel = 0.0
	_aura_timer = 0.0
	_frost_armor_on = false
	_frost_armor_timer = 0.0
	_freeze_pulse_timer = FREEZE_PULSE_INTERVAL
	_freeze_charge = 0.0
	_chain_timer = CHAIN_INTERVAL_P0
	_blink_timer = BLINK_INTERVAL_P1
	_storm_timer = STORM_INTERVAL
	_storm_pending = []
	contact_timer = 0.0
	shoot_timer = 0.0
	_player_in_contact = false
	velocity = Vector2.ZERO
	_sep_frame = 0
	_cached_sep = Vector2.ZERO
	_ai_frame = 0
	if player == null or not is_instance_valid(player):
		# ⚠ 必须用 is_inside_tree() 判断，不能用 `get_tree() != null`：
		# 节点不在树里时，调用 get_tree() 本身就会报
		# `Parameter "data.tree" is null` —— 守卫拦在调用之后，来不及生效。
		# Boss / 小 Boss 走的就是「先 setup() 再 add_child()」的路径，必然踩到。
		# 入树后 _ready() 会补上 player 的解析，所以这里跳过解析是安全的。
		if is_inside_tree():
			player = get_tree().get_first_node_in_group("player")
	if has_meta("hp_bar"):
		var bar = get_meta("hp_bar")
		if is_instance_valid(bar):
			bar.queue_free()
		remove_meta("hp_bar")

# 碰撞体尺寸必须跟着视觉走。
#
# 这里只是把原作者**本来就在做的**事恢复过来：旧视觉是 32×32 的方块，
# 等面积圆半径 = √(32²/π) ≈ 18 —— 场景里那个写死的 18 正是这么来的。
# 换成精灵后视觉尺寸变为按贴图计算，固定的 18 就与显示范围脱节了
# （症状：normal 的碰撞体与显示体积不符）。
#
# ⚠ 场景里的 shape 是**共享 SubResource**：所有 Enemy 实例指向同一个 CircleShape2D，
# 直接改半径会互相污染（最后 setup 的那个敌人决定所有人的碰撞体）。
# 所以必须先 duplicate 出实例自己的一份，并用 meta 记住，避免池复用重复复制。
func _sync_collision_extents():
	var radius := UnitVisual.visual_radius(enemy_type)
	_set_shape_radius($CollisionShape2D, radius)
	_set_shape_radius($ContactArea/CollisionShape2D, radius * UnitVisual.CONTACT_GRACE)

func _set_shape_radius(shape_node, radius: float):
	if shape_node == null or not is_instance_valid(shape_node):
		return
	var shape: Shape2D = shape_node.shape
	if shape == null:
		return
	if not shape.has_meta("enemy_own_shape"):
		shape = shape.duplicate()
		shape.set_meta("enemy_own_shape", true)
		shape_node.shape = shape
	if shape is CircleShape2D:
		shape.radius = radius

func _reset_visual_state():
	modulate = Color(1, 1, 1, 1)
	self_modulate = Color(1, 1, 1, 1)
	_last_modulate = Color(1, 1, 1, 1)
	if has_node("Body"):
		$Body.visible = true
		$Body.modulate = Color(1, 1, 1, 1)
		$Body.self_modulate = Color(1, 1, 1, 1)
		if $Body is Polygon2D:
			$Body.color.a = 1.0

func _ensure_visible():
	# Safety net: active enemies must never be fully invisible.
	var was_fixed = false
	if not visible:
		visible = true
		was_fixed = true
	if modulate.a < 0.1:
		modulate.a = 1.0
		was_fixed = true
	if self_modulate.a < 0.1:
		self_modulate.a = 1.0
		was_fixed = true
	if has_node("Body"):
		if not $Body.visible:
			$Body.visible = true
			was_fixed = true
		if $Body.modulate.a < 0.1:
			$Body.modulate.a = 1.0
			was_fixed = true
		if $Body.self_modulate.a < 0.1:
			$Body.self_modulate.a = 1.0
			was_fixed = true
		if $Body is Polygon2D and $Body.color.a < 0.1:
			$Body.color.a = 1.0
			was_fixed = true
	if was_fixed and OS.is_debug_build():
		print("Enemy visibility restored: ", enemy_type, " pos=", position)

func apply_catalog_modifiers(source):
	if source == null or not is_instance_valid(source):
		return
	if enemy_type == "tree":
		if source.get("trees_die_in_one_hit_sources") != null and int(source.get("trees_die_in_one_hit_sources")) > 0:
			hp = 1
			max_hp = 1
		return
	var health_mult = max(0.05, 1.0 + float(source.get("enemy_health_percent")))
	var speed_mult = max(0.05, 1.0 + float(source.get("enemy_speed_percent")))
	if enemy_type == "loot_alien" and source.get("loot_alien_speed_percent") != null:
		speed_mult *= max(0.05, 1.0 + float(source.get("loot_alien_speed_percent")))
	var damage_mult = max(0.05, 1.0 + float(source.get("enemy_damage_percent")))
	var material_mult = max(0.0, 1.0 + float(source.get("materials_dropped_percent")))
	var curse_value = int(source.get("curse")) if source.get("curse") != null else 0
	hp = max(1, int(round(float(hp) * health_mult)))
	max_hp = max(1, int(round(float(max_hp) * health_mult)))
	base_speed *= speed_mult
	contact_damage = max(1, int(round(float(contact_damage) * damage_mult)))
	xp_drop = max(0, int(round(float(xp_drop) * material_mult)))
	if curse_value > 0:
		var curse_chance = clamp(float(curse_value) * 0.01, 0.0, 0.50)
		if randf() < curse_chance:
			catalog_cursed = true
			set_meta("catalog_cursed", true)
	if has_meta("hp_bar") and is_instance_valid(get_meta("hp_bar")):
		var bar = get_meta("hp_bar")
		bar.max_value = max_hp
		bar.value = hp

var _sep_frame = 0  # 每2帧更新一次分离力
var _cached_sep = Vector2.ZERO
var _ai_frame = 0   # AI分帧计数器
var _last_modulate: Color = Color(-1, -1, -1, -1)  # modulate缓存

func _get_separation_force() -> Vector2:
	var sep = Vector2.ZERO
	for other in $SeparationArea.get_overlapping_bodies():
		if other == self:
			continue
		var dist = position.distance_to(other.position)
		var min_dist = 30.0 * (scale.x + other.scale.x) * 0.5
		if dist < min_dist and dist > 0.1:
			sep += (position - other.position).normalized() * (min_dist - dist) / min_dist
	return sep * 60.0

# `self.modulate` 的语义是**纯染色**：白色 = 不染色。
# 状态（燃烧/冻结/减速/眩晕）结束时必须回到白色，而不是回到「敌人自己的颜色」——
# 后者等于把颜色乘两次（body.color × modulate），单位会明显偏暗，
# 而且一旦改用精灵（颜色已画在贴图里），整只单位会被染成一片单色。
const UNIT_UNTINTED := Color(1, 1, 1, 1)

# 受击闪白用**大于 1 的倍率**提亮，而不是设成白色 ——
# 白色是 modulate 的「不变」值，设白色等于没闪。
const HIT_FLASH_MODULATE := Color(2.4, 2.4, 2.4, 1.0)

# 当前应有的染色：状态优先，否则不染色。
# 闪白结束后要靠它恢复，否则会把正在燃烧/减速的单位闪成「干净」的样子。
func _current_status_tint() -> Color:
	if burn_timer > 0.0:
		return Color(1.0, 0.5, 0.1)
	if freeze_timer > 0.0:
		return Color(0.5, 0.7, 1.0)
	if _slow_timer > 0.0:
		return Color(0.5, 0.8, 1.0)
	if _stun_timer > 0.0:
		return Color(1.0, 1.0, 0.3)
	return UNIT_UNTINTED

func _update_modulate(new_color: Color):
	if new_color != _last_modulate:
		modulate = new_color
		_last_modulate = new_color

func _physics_process(delta):
	_ensure_visible()
	if player == null or not is_instance_valid(player):
		return
	if enemy_type == "tree":
		velocity = Vector2.ZERO
		return

	# 每2帧更新分离力以优化性能
	process_damage_taken_bonus(delta)

	_sep_frame += 1
	if _sep_frame % 2 == 0:
		_cached_sep = _get_separation_force()

	_ai_frame += 1
	var do_ai = (_ai_frame % 3) == 0

	# 燃烧：持续3秒，每0.5秒扣1HP
	if burn_timer > 0:
		burn_timer -= delta
		burn_tick -= delta
		if burn_tick <= 0:
			burn_tick = burn_tick_interval
			take_damage(_get_burn_tick_damage(1))
			if not is_instance_valid(self):
				return
		_update_modulate(Color(1.0, 0.5, 0.1) if fmod(burn_timer, 0.3) > 0.15 else UNIT_UNTINTED)
	elif freeze_timer > 0:
		freeze_timer -= delta
		_update_modulate(Color(0.5, 0.7, 1.0))
		if freeze_timer <= 0:
			_update_modulate(UNIT_UNTINTED)

	# 减速计时
	if _slow_timer > 0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_factor = 1.0
			if burn_timer <= 0 and freeze_timer <= 0:
				_update_modulate(UNIT_UNTINTED)
		else:
			_update_modulate(Color(0.5, 0.8, 1.0))  # 冰蓝色

	# 眩晕计时
	if _stun_timer > 0:
		_stun_timer -= delta
		_update_modulate(Color(1.0, 1.0, 0.3))  # 黄色闪烁
		if _stun_timer <= 0 and burn_timer <= 0 and freeze_timer <= 0 and _slow_timer <= 0:
			_update_modulate(UNIT_UNTINTED)
		return  # 眩晕时跳过所有移动和攻击

	var dist = position.distance_to(player.position)
	var dir  = (player.position - position).normalized()
	var speed_mult = 0.5 if freeze_timer > 0 else _slow_factor
	var actual_speed = base_speed * speed_mult

	# ghost / elite(ghost特性): 无敌切换
	if enemy_type == "ghost" or (enemy_type == "elite" and elite_trait == "ghost"):
		ghost_timer -= delta
		if ghost_timer <= 0:
			ghost_timer = 3.0
			ghost_invincible = !ghost_invincible
			_update_modulate(GHOST_INVINCIBLE_MODULATE if ghost_invincible else Color(1, 1, 1, 1.0))

	# healer: 定期治疗附近敌人
	if enemy_type == "healer":
		healer_timer -= delta
		if healer_timer <= 0:
			healer_timer = 3.0
			if do_ai:
				_heal_nearby_enemies()

	# summoner: 定期召唤 swarm
	if enemy_type == "summoner":
		summoner_timer -= delta
		if summoner_timer <= 0:
			summoner_timer = 5.0
			if do_ai:
				_summon_swarms()

	if enemy_type == "ranged":
		if dist < preferred_dist - 40:
			velocity = -dir * actual_speed + _cached_sep
		elif dist > preferred_dist + 40:
			velocity = dir * actual_speed + _cached_sep
		else:
			velocity = _cached_sep
		move_and_slide()

		shoot_timer -= delta
		if shoot_timer <= 0 and do_ai:
			shoot_timer = 2.2
			_shoot_spread(dir, 1, 0)

	elif enemy_type == "shooter_spread":
		# 保持距离，发射5发扇形子弹
		if dist < preferred_dist - 40:
			velocity = -dir * actual_speed + _cached_sep
		elif dist > preferred_dist + 40:
			velocity = dir * actual_speed + _cached_sep
		else:
			velocity = _cached_sep
		move_and_slide()

		shoot_timer -= delta
		if shoot_timer <= 0 and do_ai:
			shoot_timer = 3.0  # 射速慢
			_shoot_spread(dir, 5, 15.0)

	elif uses_boss_behavior():
		var prev_pos := position
		# 火焰 Boss 冲锋期间覆盖常规追踪速度（设计文档 §1.3 阶段1「火焰冲锋」）。
		# 冲锋方向在起步那一帧锁定，之后不再跟随玩家 —— 否则变成无法躲开的追踪冲刺。
		if _dash_timer > 0.0:
			velocity = _dash_dir * actual_speed * FIRE_CHARGE_SPEED_MULT
		else:
			velocity = dir * actual_speed + _cached_sep * 0.5
		move_and_slide()

		contact_timer -= delta
		if contact_timer <= 0 and _player_in_contact:
			player.take_damage(contact_damage)
			contact_timer = 1.0

		# 射击：基于阶段调整（Boss每帧射击以保证战斗体验）
		shoot_timer -= delta
		var interval = 1.8 if phase == 0 else (1.0 if phase == 1 else 0.7)
		var count    = 5   if phase == 0 else (8 if phase >= 1 else 5)
		if enemy_type == "miniboss":
			count = 3 if phase == 0 else (5 if phase == 1 else 6)
		# Boss 弹幕带上自己的元素（基础 Boss 为 ""，即无元素）
		var boss_element := bullet_element()
		if shoot_timer <= 0:
			shoot_timer = interval
			if phase == 2:
				_shoot_rage_burst(boss_element)
			else:
				_shoot_spread(dir, count, 14.0, boss_element)

		# 阶段2：定期螺旋弹
		if phase >= 1:
			phase_shoot_timer -= delta
			if phase_shoot_timer <= 0:
				phase_shoot_timer = 3.0 if phase == 1 else 2.0
				_shoot_spiral(12, boss_element)

		# 元素变体的独特机制（设计文档「通用实现方案 → Boss 特殊行为分支」）。
		# 基础 boss / miniboss 不匹配任何分支，行为与 P1 完全一致。
		match enemy_type:
			"boss_fire":
				_process_fire_boss(delta, dist, prev_pos)
			"boss_frost":
				_process_frost_boss(delta)
			"boss_lightning":
				_process_lightning_boss(delta)

	elif enemy_type == "charger":
		charger_timer -= delta
		if charger_rushing:
			velocity = charger_dir * actual_speed * 8.0
			move_and_slide()
			# 冲刺持续0.4秒后停止
			if charger_timer <= 0:
				charger_rushing = false
				charger_timer = 2.0
		else:
			velocity = Vector2.ZERO
			move_and_slide()
			if charger_timer <= 0:
				charger_rushing = true
				charger_dir = dir
				charger_timer = 0.4

		contact_timer -= delta
		if contact_timer <= 0 and _player_in_contact:
			player.take_damage(contact_damage)
			contact_timer = 1.0

	else:
		# normal, fast, tank, exploder, healer, swarm, armored, ghost, summoner, elite
		velocity = dir * actual_speed + _cached_sep
		move_and_slide()

		contact_timer -= delta
		if contact_timer <= 0 and _player_in_contact:
			player.take_damage(contact_damage)
			contact_timer = 1.0

func _shoot_spread(base_dir: Vector2, count: int, spread_deg: float, element: String = ""):
	var main = get_parent()
	var use_pool = main.has_method("get_enemy_bullet")
	var start = -(count - 1) * spread_deg / 2.0
	for i in range(count):
		var bullet
		if use_pool:
			bullet = main.get_enemy_bullet()
		else:
			bullet = ENEMY_BULLET_SCENE.instantiate()
			main.add_child(bullet)
		bullet.activate(position, base_dir.rotated(deg_to_rad(start + i * spread_deg)), element)

func take_damage(amount):
	# ghost 无敌状态免疫伤害
	if ghost_invincible:
		return

	# armored / elite(armored特性): 伤害减少50%
	if armor_value > 0:
		amount = max(1, int(amount * (1.0 - armor_value / 100.0)))

	if not is_equal_approx(damage_taken_percent_bonus, 0.0):
		amount = max(1, int(round(float(amount) * (1.0 + damage_taken_percent_bonus))))

	hp -= amount
	# 浮动伤害数字
	if is_instance_valid(self):
		Effects.damage_number(position, amount, amount > 15)
	if uses_boss_behavior():
		hp_changed.emit(hp, max_hp)
	# 更新头顶血条
	if has_meta("hp_bar") and is_instance_valid(get_meta("hp_bar")):
		get_meta("hp_bar").value = hp
	# 受击闪白：走 modulate，会一并作用到精灵子节点。
	# 不能再用 `$Body.color = WHITE` —— 精灵路线下 Body 的多边形是空的，闪白会彻底失效。
	_update_modulate(HIT_FLASH_MODULATE)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self):
			_update_modulate(_current_status_tint())
	)
	# Boss阶段检测
	if uses_boss_behavior() and hp > 0:
		_check_phase_transition()

	if hp <= 0:
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_enemy_die()
		Effects.death_burst(position, ENEMY_TYPES[enemy_type].color)
		# exploder: 死亡时发射8方向弹
		if enemy_type == "exploder":
			_explode_on_death()
		_drop_xp()
		died.emit()
		# Boss/miniboss 使用 queue_free（不池化），普通敌人回收到池
		if uses_boss_behavior():
			queue_free()
		else:
			remove_from_group("enemies")
			var main_node = get_parent()
			if main_node and main_node.has_method("recycle_enemy"):
				main_node.recycle_enemy(self)
			else:
				recycle()

var burn_base_damage: int = 1
var burn_instances_remaining: int = 0

func apply_burn(source = null, base_damage: int = 1, instances: int = 0):
	burn_timer = max(burn_timer, float(instances) * burn_tick_interval) if instances > 0 else 3.0
	burn_source = source
	burn_tick_interval = 0.5
	if source != null and is_instance_valid(source) and source.get("burn_tick_interval_percent_modifier") != null:
		burn_tick_interval = max(0.05, 0.5 * (1.0 + float(source.get("burn_tick_interval_percent_modifier"))))
	burn_tick = burn_tick_interval
	burn_base_damage = max(1, base_damage)
	burn_instances_remaining = instances

func _get_burn_tick_damage(base_amount: int) -> int:
	var amount = max(1, int(burn_base_damage))
	if burn_source != null and is_instance_valid(burn_source) and burn_source.has_method("modify_burn_tick_damage"):
		return burn_source.modify_burn_tick_damage(amount, self)
	return amount

func apply_damage_taken_bonus(percent: float, duration: float, key: String = "") -> bool:
	if damage_taken_bonus_timer > 0.0 and key != "" and key == damage_taken_bonus_key:
		return false
	damage_taken_percent_bonus = max(damage_taken_percent_bonus, max(0.0, percent))
	damage_taken_bonus_timer = max(damage_taken_bonus_timer, max(0.0, duration))
	damage_taken_bonus_key = key
	return damage_taken_bonus_timer > 0.0 and damage_taken_percent_bonus > 0.0

func process_damage_taken_bonus(delta: float):
	if damage_taken_bonus_timer <= 0.0:
		return
	damage_taken_bonus_timer -= max(0.0, delta)
	if damage_taken_bonus_timer <= 0.0:
		damage_taken_percent_bonus = 0.0
		damage_taken_bonus_timer = 0.0
		damage_taken_bonus_key = ""

func apply_freeze():
	freeze_timer = 1.5

func apply_slow(factor: float, duration: float):
	_slow_factor = 1.0 - clamp(factor, 0.0, 0.9)
	_slow_timer = duration

func apply_catalog_hit_slow(value: float, max_value: float):
	catalog_hit_slow_percent = min(max(0.0, max_value), catalog_hit_slow_percent + max(0.0, value))
	_slow_factor = max(0.05, 1.0 - catalog_hit_slow_percent)

func apply_stun(duration: float):
	_stun_timer = duration

# exploder: 死亡时8方向弹
func _explode_on_death():
	var main = get_parent()
	var use_pool = main.has_method("get_enemy_bullet")
	for i in range(8):
		var bullet
		if use_pool:
			bullet = main.get_enemy_bullet()
		else:
			bullet = ENEMY_BULLET_SCENE.instantiate()
			main.add_child(bullet)
		bullet.activate(position, Vector2.RIGHT.rotated(deg_to_rad(i * 45.0)))

# healer: 治疗附近50像素内的敌人恢复10%HP
func _heal_nearby_enemies():
	for enemy in $SeparationArea.get_overlapping_bodies():
		if enemy == self:
			continue
		var heal_amount = max(1, int(enemy.max_hp * 0.1))
		enemy.hp = min(enemy.hp + heal_amount, enemy.max_hp)

# summoner: 召唤2只swarm
func _summon_swarms():
	var main = get_parent()
	if main == null:
		return
	for i in range(2):
		var swarm = main.get_enemy() if main.has_method("get_enemy") else null
		if swarm == null:
			var enemy_scene = load("res://scenes/Enemy.tscn")
			swarm = enemy_scene.instantiate()
			main.add_child(swarm)
		var wave_num = max(1, int((max_hp / ENEMY_TYPES["summoner"].hp_m) - 2))
		swarm.setup("swarm", wave_num)
		swarm.position = position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		if not swarm.died.is_connected(main._on_enemy_died.bind(swarm)):
			swarm.died.connect(main._on_enemy_died.bind(swarm))
		if not swarm.is_in_group("enemies"):
			swarm.add_to_group("enemies")

func _drop_xp():
	var main = get_parent()
	if main == null:
		return
	var drop_value = xp_drop
	if "economy" in main and main.economy != null:
		drop_value = main.economy.consume_bag_for_drop(drop_value)
	var use_pool = main.has_method("get_xp_orb")
	var orb = null
	if use_pool:
		orb = main.get_xp_orb()
		orb.activate(position, drop_value)
	else:
		orb = XP_ORB_SCENE.instantiate()
		orb.position = position
		orb.xp_value = drop_value
		if "material_value" in orb:
			orb.material_value = drop_value
		main.add_child(orb)
	var player_ref = main.player if "player" in main else (get_tree().get_first_node_in_group("player") if get_tree() != null else null)
	if player_ref != null and is_instance_valid(player_ref) and player_ref.get("material_drop_instant_attract_chance") != null:
		if randf() < float(player_ref.get("material_drop_instant_attract_chance")) and orb != null and orb.has_method("collect"):
			orb.collect(player_ref)

# --- Boss阶段系统 ---

func _check_phase_transition():
	var hp_ratio = float(hp) / float(max_hp)
	var new_phase = phase
	if hp_ratio <= 0.15:
		new_phase = 2
	elif hp_ratio <= 0.40:
		new_phase = 1
	elif hp_ratio <= 0.75:
		new_phase = 1

	if new_phase > phase:
		phase = new_phase
		_on_phase_change()

func _on_phase_change():
	# 阶段切换特效：用该类型自己的颜色（设计文档「通用实现方案 → 阶段切换特效差异化」）
	Effects.death_burst(position, ENEMY_TYPES[enemy_type].color)
	phase_changed.emit(phase)

	match phase:
		1:
			# 阶段1：按 Boss 类型加速（取值见设计文档的「阶段差异化」表）
			base_speed *= _phase1_speed_mult()
		2:
			# 阶段2：在阶段1之上再乘一次，累计约 1.4–1.5x
			base_speed *= _phase2_speed_mult()
			_shoot_spiral(12, bullet_element())
	_on_element_phase_change()

# 元素机制进入新阶段时的状态初始化。
# 单独成函数（而不是塞进上面的 match）是为了让「阶段 → 机制参数」的映射只有一份。
func _on_element_phase_change():
	match enemy_type:
		"boss_fire":
			_fire_charge_timer = FIRE_CHARGE_INTERVAL_P2 if phase >= 2 else FIRE_CHARGE_INTERVAL_P1
		"boss_frost":
			# 阶段1 起有冰甲，阶段2 常驻（由 _process_frost_boss 维持）
			_set_frost_armor(true)
			_freeze_pulse_timer = FREEZE_PULSE_INTERVAL
		"boss_lightning":
			_blink_timer = BLINK_INTERVAL_P2 if phase >= 2 else BLINK_INTERVAL_P1
			_storm_timer = STORM_INTERVAL if phase >= 2 else 0.0

func _phase1_speed_mult() -> float:
	return float(PHASE1_SPEED_MULT.get(enemy_type, 1.2))

func _phase2_speed_mult() -> float:
	return float(PHASE2_SPEED_MULT.get(enemy_type, 1.17))

# 螺旋弹：count方向均匀分布
func _shoot_spiral(count: int, element: String = ""):
	var main = get_parent()
	var use_pool = main.has_method("get_enemy_bullet")
	for i in range(count):
		var bullet
		if use_pool:
			bullet = main.get_enemy_bullet()
		else:
			bullet = ENEMY_BULLET_SCENE.instantiate()
			main.add_child(bullet)
		bullet.activate(position, Vector2.RIGHT.rotated(deg_to_rad(i * (360.0 / count))), element)

# 狂暴连发：8方向×3连发
func _shoot_rage_burst(element: String = ""):
	for burst in range(3):
		get_tree().create_timer(burst * 0.15).timeout.connect(func():
			if is_instance_valid(self):
				_shoot_spiral(8, element)
		)

# ══════════════════════════════════════════════════════════════════
#  元素 Boss 独特机制（docs/boss-variants-design.md 的 P2）
#  三个变体各自实现一个 _process_*_boss()，由 _physics_process 的
#  boss 分支按 enemy_type 分派。公共行为（追踪 / 阶段弹幕 / 血条）
#  仍在上面那段里，这里只追加「这个 Boss 独有的东西」。
# ══════════════════════════════════════════════════════════════════

# ─── 共用小工具 ───

func _direction_to_player() -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	var to_player = player.position - position
	if to_player.length_squared() <= 0.0001:
		return Vector2.ZERO
	return to_player.normalized()

# 玩家侧的 PlayerStatus。玩家没有状态模块时返回 null（不静默改玩家属性）。
func _player_status():
	if player == null or not is_instance_valid(player):
		return null
	return player.get("status")

# 取一发池化敌方子弹并按 (位置, 方向, 元素) 激活。
# 走 Main 的对象池，池满时 Main 自己会新建实例。
func _spawn_enemy_bullet(at: Vector2, dir: Vector2, element: String):
	var main = get_parent()
	if main == null or not is_instance_valid(main):
		return null
	var bullet = null
	if main.has_method("get_enemy_bullet"):
		bullet = main.get_enemy_bullet()
	else:
		bullet = ENEMY_BULLET_SCENE.instantiate()
		main.add_child(bullet)
	bullet.activate(at, dir, element)
	return bullet

# ─── 火焰 Boss（§1.3 / §1.4）───

func _process_fire_boss(delta: float, dist: float, prev_pos: Vector2):
	if _dash_timer > 0.0:
		# 冲锋中：按走过的距离在路径上留下燃烧区域
		_dash_timer -= delta
		_dash_travel += position.distance_to(prev_pos)
		while _dash_travel >= BURN_ZONE_SPACING:
			_dash_travel -= BURN_ZONE_SPACING
			_spawn_burn_zone(position)
	else:
		_fire_charge_timer -= delta
		if _fire_charge_timer <= 0.0 and phase >= 1:
			_start_fire_charge()

	# 烈焰光环：阶段2 才会对近身玩家持续点火（§1.3 阶段2）
	if phase >= 2:
		_aura_timer -= delta
		if _aura_timer <= 0.0 and dist <= FIRE_AURA_RADIUS:
			_aura_timer = FIRE_AURA_TICK
			_apply_burn_to_player()

# 冲锋只在阶段 1 起出现（设计文档把它列为阶段1 的新机制）
func _start_fire_charge():
	var dir_to_player = _direction_to_player()
	if dir_to_player == Vector2.ZERO:
		return
	_dash_dir = dir_to_player
	_dash_timer = FIRE_CHARGE_DURATION
	_dash_travel = 0.0
	_fire_charge_timer = FIRE_CHARGE_INTERVAL_P2 if phase >= 2 else FIRE_CHARGE_INTERVAL_P1
	Effects.hit_spark(position, ENEMY_TYPES[enemy_type].color)

func _spawn_burn_zone(at: Vector2):
	var main = get_parent()
	if main == null or not is_instance_valid(main):
		return
	var zone = BURN_ZONE_SCENE.instantiate()
	# 先入树再 activate：节点在树外调用节点 API 是硬报错（SKILL §3.1）
	main.add_child(zone)
	var duration = BURN_ZONE_DURATION_P2 if phase >= 2 else BURN_ZONE_DURATION_P1
	zone.activate(at, duration, BURN_ZONE_RADIUS)

func _apply_burn_to_player():
	var status = _player_status()
	if status == null:
		return
	status.apply_burn()

# ─── 冰霜 Boss（§2.3 / §2.4）───

func _process_frost_boss(delta: float):
	if phase >= 2:
		# 阶段2：冰甲常驻
		_set_frost_armor(true)
		if _freeze_charge > 0.0:
			_freeze_charge -= delta
			# 蓄力预警：颜色在 1s 内渐变到纯白（§2.5）。必须走 _update_modulate，
			# 直接写 modulate 会让 _last_modulate 缓存与真实值脱节，之后恢复不回来。
			var progress = 1.0 - clamp(_freeze_charge / FREEZE_PULSE_CHARGE, 0.0, 1.0)
			var base_color: Color = ENEMY_TYPES[enemy_type].color
			_update_modulate(base_color.lerp(Color(1, 1, 1), progress))
			if _freeze_charge <= 0.0:
				_release_freeze_pulse()
		else:
			_freeze_pulse_timer -= delta
			if _freeze_pulse_timer <= 0.0:
				_freeze_pulse_timer = FREEZE_PULSE_INTERVAL
				_freeze_charge = FREEZE_PULSE_CHARGE
	elif phase >= 1:
		# 阶段1：冰甲 5s 开 / 4s 关循环
		_frost_armor_timer -= delta
		if _frost_armor_timer <= 0.0:
			_set_frost_armor(not _frost_armor_on)

func _set_frost_armor(on: bool):
	var target := FROST_ARMOR_REDUCTION if on else 0
	if _frost_armor_on == on and armor_value == target:
		return
	_frost_armor_on = on
	armor_value = target
	_frost_armor_timer = FROST_ARMOR_ON_TIME if on else FROST_ARMOR_OFF_TIME

func _release_freeze_pulse():
	_update_modulate(_current_status_tint())
	Effects.death_burst(position, Color(0.75, 0.9, 1.0))
	var status = _player_status()
	if status == null:
		return
	# 玩家侧没有 apply_freeze，冻结用 apply_stun 表达（§2.4；apply_stun 自带 1s 冷却，
	# 这是有意设计——不要绕过它去直接写 stun_timer）。
	status.apply_stun(FREEZE_PULSE_STUN)

# ─── 雷电 Boss（§3.3 / §3.4）───

func _process_lightning_boss(delta: float):
	# 链式闪电：三个阶段都在发，间隔与弹射次数随阶段收紧
	_chain_timer -= delta
	if _chain_timer <= 0.0:
		_chain_timer = _chain_interval()
		_shoot_chain_bolt()

	# 闪现：阶段1 起（§3.3）
	if phase >= 1:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = BLINK_INTERVAL_P2 if phase >= 2 else BLINK_INTERVAL_P1
			_blink()

	# 雷暴领域：阶段2（§3.3）
	if phase >= 2:
		_storm_timer -= delta
		if _storm_timer <= 0.0:
			_storm_timer = STORM_INTERVAL
			_schedule_storm_strike()

	_process_storm_strikes(delta)

func _chain_interval() -> float:
	match phase:
		0: return CHAIN_INTERVAL_P0
		1: return CHAIN_INTERVAL_P1
		_: return CHAIN_INTERVAL_P2

func _chain_bounces() -> int:
	match phase:
		0: return CHAIN_BOUNCES_P0
		1: return CHAIN_BOUNCES_P1
		_: return CHAIN_BOUNCES_P2

func _shoot_chain_bolt():
	var dir_to_player = _direction_to_player()
	if dir_to_player == Vector2.ZERO:
		return
	var bullet = _spawn_enemy_bullet(position, dir_to_player, bullet_element())
	if bullet == null:
		return
	bullet.chain_remaining = _chain_bounces()

# 闪现：传送到玩家周围 100–200px 的随机位置，并在落点释放一圈雷弹（§3.3）
func _blink():
	if player == null or not is_instance_valid(player):
		return
	var target = player.position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(BLINK_MIN_DIST, BLINK_MAX_DIST)
	if is_inside_tree():
		# 落点限制在**场地**内（不是视口内）。改造前用视口是「相机 == 视口」时代的
		# 遗留写法，相机跟随之后等于把 Boss 闪现锁死在玩家出生点那一屏。
		# 落点由「玩家位置 ± 100~200px」给出，那个距离远小于场地边界，
		# 所以这次钳位只可能挡住玩家贴着场地边缘时向外侧的落点。
		var arena := Arena.get_active()
		if arena != null:
			var world := arena.world_rect()
			target.x = clampf(target.x, world.position.x + 40.0, world.end.x - 40.0)
			target.y = clampf(target.y, world.position.y + 40.0, world.end.y - 40.0)
		else:
			var screen = get_viewport_rect().size
			target.x = clamp(target.x, 40.0, screen.x - 40.0)
			target.y = clamp(target.y, 40.0, screen.y - 40.0)
	Effects.hit_spark(position, Color(0.6, 0.2, 0.8))
	position = target
	Effects.hit_spark(position, Color(0.6, 0.2, 0.8))
	_shoot_spiral(BLINK_SPIRAL_P2 if phase >= 2 else BLINK_SPIRAL_P1, bullet_element())

# 雷暴领域：先在玩家当前位置排一次延迟落雷（带预警圈）
func _schedule_storm_strike():
	if player == null or not is_instance_valid(player):
		return
	var at: Vector2 = player.position
	_storm_pending.append({"position": at, "timer": STORM_DELAY, "radius": STORM_RADIUS})
	_spawn_storm_warning(at)

# 预警圈：紫色空心圆，落雷或超时后自行移除
func _spawn_storm_warning(at: Vector2):
	var main = get_parent()
	if main == null or not is_instance_valid(main) or not is_inside_tree():
		return
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.6, 0.2, 0.8, 0.7)
	ring.z_index = -1
	ring.position = at
	var pts := PackedVector2Array()
	var segments := 24
	for i in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * STORM_RADIUS)
	ring.points = pts
	main.add_child(ring)
	get_tree().create_timer(STORM_DELAY).timeout.connect(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)

# 延迟落雷由 Boss 自己按 delta 推进（而不是 create_timer）：可测试、可暂停，
# 也不会出现「Boss 已死但定时器回调还在访问它」的悬垂引用。
func _process_storm_strikes(delta: float):
	if _storm_pending.is_empty():
		return
	var remaining: Array = []
	for strike in _storm_pending:
		strike["timer"] = float(strike["timer"]) - delta
		if float(strike["timer"]) <= 0.0:
			_resolve_storm_strike(strike)
		else:
			remaining.append(strike)
	_storm_pending = remaining

func _resolve_storm_strike(strike: Dictionary):
	var at: Vector2 = strike["position"]
	Effects.death_burst(at, Color(1.0, 1.0, 0.3))
	if player == null or not is_instance_valid(player):
		return
	if player.position.distance_to(at) > float(strike["radius"]):
		return  # 预警期内躲开了就不落伤
	player.take_damage(STORM_DAMAGE)
	var status = _player_status()
	if status == null:
		return
	status.apply_stun(STORM_STUN)
