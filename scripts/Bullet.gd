extends Area2D

var direction    = Vector2.RIGHT
var damage       = 1
var bullet_speed = 500.0
var bullet_color = Color(1, 0.9, 0.2)
var shooter      = null   # 玩家引用，用于生命偷取
var is_crit      = false  # 暴击子弹

# 新弹道属性
var pierce       = false  # 穿透
var pierce_count = 0      # 已穿透次数
var pierce_hit_limit = 1
# 目录给出的穿透伤害衰减（weapons.json 的 pierce.damage_multiplier）：
# 第 n 个后续命中按 multiplier^n 衰减。< 0 表示该武器未给出，退回旧的衰减路径。
var pierce_damage_multiplier = -1.0
# 发射这发子弹的武器身份（weapon.runtime_id）。远程命中回调原本不带武器信息，
# 导致任何「按武器差异化的远程命中效果」都无法实现。0 表示非玩家武器发射（结构/敌人等）。
var source_weapon_runtime_id = 0
var piercing_damage_percent = 0.0
var piercing_damage_cap_at_base = false
var splash       = false  # 溅射
var splash_radius = 0     # 溅射范围
var returns      = false  # 回旋
var return_timer = 0.0    # 回旋计时器
var returning    = false  # 是否正在返回
var gravity_fall = false  # 重力弹道
var gravity_vel  = 0.0    # 重力速度累积
var bullet_scale = Vector2(1, 1)  # 子弹缩放
var hit_enemies  = []             # 已命中敌人列表（防止穿透时重复命中）
var chain_lightning = false        # 击杀链闪电
var ammo_type = ""                 # 元素弹药类型: "fire", "ice", "lightning"
var bounce_remaining = 0
var bounce_range = 350.0

# Weapon special rule params
var burn_damage = 0
var burn_instances = 0
var explosion_on_hit = false
var explosion_radius = 120.0
var explosion_damage_percent = 0.5
var pierce_falloff = false
var pierce_falloff_percent = -0.25
var full_pierce = false
var slow_on_hit = false
var slow_factor = 0.3
var slow_duration = 2.0
var material_on_crit_kill = false
var material_on_crit_kill_chance = 0.0

const PLAYER_BULLET_Z_INDEX := 20

var _lifetime = 0.0  # 存活计时器

func _ready():
	add_to_group("bullets")
	z_index = PLAYER_BULLET_Z_INDEX
	# 池中初始状态：不可见、不处理
	visible = false
	set_process(false)
	monitoring = false
	body_entered.connect(_on_body_entered)

func activate(pos: Vector2, dir: Vector2, spd: float, color: Color, p_shooter, p_damage: int, p_is_crit: bool = false, p_pierce: bool = false, p_splash: bool = false, p_splash_radius: int = 0, p_returns: bool = false, p_gravity: bool = false, p_bullet_scale: Vector2 = Vector2(1, 1), p_chain_lightning: bool = false, p_ammo_type: String = "", p_pierce_hit_limit: int = -1, p_piercing_damage_percent: float = 0.0, p_piercing_damage_cap_at_base: bool = false, p_bounce_remaining: int = 0, p_burn_damage: int = 0, p_burn_instances: int = 0, p_explosion_on_hit: bool = false, p_explosion_radius: float = 120.0, p_explosion_damage_percent: float = 0.5, p_pierce_falloff: bool = false, p_pierce_falloff_percent: float = -0.25, p_full_pierce: bool = false, p_slow_on_hit: bool = false, p_slow_factor: float = 0.3, p_slow_duration: float = 2.0, p_material_on_crit_kill: bool = false, p_material_on_crit_kill_chance: float = 0.0, p_pierce_damage_multiplier: float = -1.0, p_source_weapon_runtime_id: int = 0):
	# 重置所有状态
	position = pos
	direction = dir
	bullet_speed = spd
	bullet_color = color
	shooter = p_shooter
	damage = p_damage
	is_crit = p_is_crit
	pierce = p_pierce
	pierce_count = 0
	pierce_hit_limit = max(1, p_pierce_hit_limit) if p_pierce_hit_limit > 0 else (3 if p_pierce else 1)
	piercing_damage_percent = p_piercing_damage_percent
	piercing_damage_cap_at_base = p_piercing_damage_cap_at_base
	splash = p_splash
	splash_radius = p_splash_radius
	returns = p_returns
	return_timer = 0.5 if returns else 0.0
	returning = false
	gravity_fall = p_gravity
	gravity_vel = 0.0
	bullet_scale = p_bullet_scale
	chain_lightning = p_chain_lightning
	ammo_type = p_ammo_type
	bounce_remaining = max(0, p_bounce_remaining)
	hit_enemies.clear()
	_lifetime = 0.0
	z_index = PLAYER_BULLET_Z_INDEX
	# Weapon special rule state
	burn_damage = p_burn_damage
	burn_instances = p_burn_instances
	explosion_on_hit = p_explosion_on_hit
	explosion_radius = p_explosion_radius
	explosion_damage_percent = p_explosion_damage_percent
	pierce_falloff = p_pierce_falloff
	pierce_falloff_percent = p_pierce_falloff_percent
	full_pierce = p_full_pierce
	slow_on_hit = p_slow_on_hit
	slow_factor = p_slow_factor
	slow_duration = p_slow_duration
	material_on_crit_kill = p_material_on_crit_kill
	material_on_crit_kill_chance = p_material_on_crit_kill_chance
	pierce_damage_multiplier = p_pierce_damage_multiplier
	source_weapon_runtime_id = p_source_weapon_runtime_id

	# 视觉设置
	$Body.color = bullet_color if not is_crit else Color(1, 1, 0.3).lerp(bullet_color, 0.3)
	if is_crit:
		scale = Vector2(1.5, 1.5) * bullet_scale
	else:
		scale = bullet_scale

	# 激活
	visible = true
	set_process(true)
	set_deferred("monitoring", true)

func _return_to_pool():
	set_deferred("monitoring", false)
	visible = false
	set_process(false)
	hit_enemies.clear()
	pierce_count = 0
	pierce_hit_limit = 1
	pierce_damage_multiplier = -1.0
	source_weapon_runtime_id = 0
	piercing_damage_percent = 0.0
	piercing_damage_cap_at_base = false
	returning = false
	return_timer = 0.0
	gravity_vel = 0.0
	chain_lightning = false
	ammo_type = ""
	bounce_remaining = 0
	shooter = null
	burn_damage = 0
	burn_instances = 0
	explosion_on_hit = false
	explosion_radius = 120.0
	explosion_damage_percent = 0.5
	pierce_falloff = false
	pierce_falloff_percent = -0.25
	full_pierce = false
	slow_on_hit = false
	slow_factor = 0.3
	slow_duration = 2.0
	material_on_crit_kill = false
	material_on_crit_kill_chance = 0.0

func _process(delta):
	_lifetime += delta
	if _lifetime >= 3.0:
		_return_to_pool()
		return

	# 回旋镖逻辑
	if returns:
		if not returning:
			return_timer -= delta
			if return_timer <= 0:
				returning = true
		if returning and shooter and is_instance_valid(shooter):
			var to_player = (shooter.position - position).normalized()
			direction = direction.lerp(to_player, 8.0 * delta).normalized()
			# 到达玩家附近后消失
			if position.distance_to(shooter.position) < 30:
				_return_to_pool()
				return

	# 重力弹道
	if gravity_fall:
		gravity_vel += 400.0 * delta
		position.y += gravity_vel * delta

	position += direction * bullet_speed * delta
	# 出界 = 离开**当前视野**（相机矩形外扩 50px），不是离开场地。
	# 用场地做判据的话，飞到另一头的子弹要跑满整张图才回收，全图弹道会持续堆积。
	# 相机跟随后视口矩形不再等于视野，所以这里不能再用 get_viewport_rect()。
	var arena := Arena.get_active()
	if arena != null:
		if arena.is_outside_viewport(position, 50.0):
			_return_to_pool()
			return
	else:
		var screen = get_viewport_rect().size
		if position.x < -50 or position.x > screen.x + 50 or position.y < -50 or position.y > screen.y + 50:
			_return_to_pool()
			return

func _on_body_entered(body):
	if not visible:
		return
	# 可伤害目标 = 敌人 或 中立材料树。
	# 树在 `neutral_trees` 分组（Enemy.setup 会把树从 enemies 组里移出），
	# 原来这里只认 enemies，于是子弹打树完全没有反应。
	var is_enemy: bool = body.is_in_group("enemies")
	var is_tree: bool = body.is_in_group("neutral_trees")
	if not is_enemy and not is_tree:
		return
	# 池里的隐形实例与已死亡的实例都不该再吃伤害
	# （`recycle()` 只把敌人移出分组，碰撞层仍然开着）
	if not body.visible:
		return
	if body.get("hp") != null and int(body.get("hp")) <= 0:
		return
	if body in hit_enemies:
		return

	hit_enemies.append(body)
	Effects.hit_spark(position, bullet_color)
	var hit_damage = damage
	# 穿透衰减：优先用目录的 pierce.damage_multiplier（第 n 个后续命中按 multiplier^n 衰减）。
	# multiplier = 0 会落到 max(1, …) 下界，即「后续命中固定 1 点」——
	# Flamethrower 的 "pierce_99_for_one_damage" 正是靠这个组合自然成立，无需特判分支。
	if pierce_count > 0 and pierce_damage_multiplier >= 0.0:
		hit_damage = max(1, int(round(float(damage) * pow(pierce_damage_multiplier, float(pierce_count)))))
	# 旧路径（目录未给出 multiplier 时）：线性衰减 / 玩家 piercing 加成
	elif pierce_count > 0 and pierce_falloff:
		var mult = 1.0 + (pierce_falloff_percent * pierce_count)
		hit_damage = max(1, int(round(float(damage) * max(0.1, mult))))
	elif pierce_count > 0 and not is_equal_approx(piercing_damage_percent, 0.0):
		hit_damage = max(1, int(round(float(damage) * (1.0 + piercing_damage_percent))))
		if piercing_damage_cap_at_base:
			hit_damage = min(hit_damage, damage)
	if shooter and is_instance_valid(shooter) and shooter.has_method("modify_damage_against_target"):
		hit_damage = shooter.modify_damage_against_target(hit_damage, body, {"is_crit": is_crit})
	body.take_damage(hit_damage)
	# 中立树只吃伤害就结束：击杀回调 / 命中回调 / 吸血 / 总伤害统计 / 点燃 / 元素 / 减速
	# 都是围绕「敌人」语义的，套到树上会变成bug（例如打不还手的树刷吸血）。
	if not is_enemy:
		_finish_hit(body)
		return
	if shooter and is_instance_valid(shooter) and is_instance_valid(body) and int(body.get("hp")) <= 0:
		if shooter.has_method("on_enemy_killed_by_hit"):
			shooter.on_enemy_killed_by_hit({"is_crit": is_crit, "damage": hit_damage})
		if is_crit and material_on_crit_kill and randf() < material_on_crit_kill_chance:
			if shooter.has_method("earn_gold"):
				shooter.earn_gold(1)
	if shooter and is_instance_valid(shooter):
		if is_instance_valid(body) and shooter.has_method("on_enemy_hit_by_attack"):
			# 把武器身份一并交给回调：远程的「按武器差异化命中效果」需要它
			shooter.on_enemy_hit_by_attack(body, {
				"is_crit": is_crit,
				"damage": hit_damage,
				"weapon_runtime_id": source_weapon_runtime_id,
			})
		shooter.total_damage_dealt += hit_damage
		if shooter.lifesteal > 0:
			shooter.heal(hit_damage * shooter.lifesteal)
	# 触发状态效果
	if shooter and is_instance_valid(shooter) and is_instance_valid(body):
		# 武器自带 burn 值时**无条件**施加 —— 这是武器的 burn 规则，不该再掷骰子。
		# 玩家的 burn_chance（fire_master 协同 / 物品）是**额外来源**，作用于不自带燃烧的武器。
		# 修正前这里只看 burn_chance，导致 3 把远程武器（particle_accelerator / wand / fireball）
		# 的 burn_damage / burn_instances 数据完全失效（近战走 _apply_weapon_hit_effects，不受影响）。
		var should_burn = burn_damage > 0
		if not should_burn and shooter.get("burn_chance") and randf() < shooter.burn_chance:
			should_burn = true
		if should_burn and body.has_method("apply_burn"):
			body.apply_burn(shooter, burn_damage if burn_damage > 0 else 1, burn_instances)
			if shooter.has_method("on_enemy_burn_applied"):
				shooter.on_enemy_burn_applied(body)
		if shooter.get("freeze_chance") and randf() < shooter.freeze_chance:
			if body.has_method("apply_freeze"):
				body.apply_freeze()
	# 元素弹药效果
	if ammo_type != "" and is_instance_valid(body):
		if ammo_type == "fire" and body.has_method("apply_burn"):
			body.apply_burn(shooter, burn_damage if burn_damage > 0 else 1, burn_instances)
			if shooter and is_instance_valid(shooter) and shooter.has_method("on_enemy_burn_applied"):
				shooter.on_enemy_burn_applied(body)
		elif ammo_type == "ice" and body.has_method("apply_slow"):
			body.apply_slow(0.3, 2.0)
		elif ammo_type == "lightning" and randf() < 0.2:
			if body.has_method("apply_stun"):
				body.apply_stun(1.0)
		if shooter and is_instance_valid(shooter) and shooter.has_method("on_enemy_elemental_hit"):
			shooter.on_enemy_elemental_hit(body)
	# Weapon-specific slow
	if slow_on_hit and is_instance_valid(body) and body.has_method("apply_slow"):
		body.apply_slow(slow_factor, slow_duration)
	# 溅射
	if splash and splash_radius > 0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != body and is_instance_valid(e) and position.distance_to(e.position) <= splash_radius:
				e.take_damage(max(1, int(damage * 0.5)))
				Effects.hit_spark(e.position, bullet_color)
	# 命中爆炸（Rocket Launcher 等）
	if explosion_on_hit and explosion_radius > 0:
		var explosion_dmg = max(1, int(round(float(hit_damage) * explosion_damage_percent)))
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != body and is_instance_valid(e) and position.distance_to(e.position) <= explosion_radius:
				e.take_damage(explosion_dmg)
				Effects.hit_spark(e.position, bullet_color)
	# 链式闪电
	var has_chain = chain_lightning or (shooter and is_instance_valid(shooter) and shooter.get("chain_lightning"))
	if has_chain:
		var chain_dmg = max(1, int(hit_damage * 0.5))
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != body and is_instance_valid(e) and position.distance_to(e.position) <= 200.0:
				e.take_damage(chain_dmg)
				Effects.hit_spark(e.position, Color(0.3, 0.6, 1.0))
				if shooter and is_instance_valid(shooter):
					shooter.total_damage_dealt += chain_dmg
				break
	_finish_hit(body)


# 一次命中之后如何收尾：先看能不能弹跳，否则按穿透次数决定是否回收。
# 抽出来是为了让「中立树」这条短路径复用同一套收尾逻辑，而不是另写一份。
func _finish_hit(body):
	if _try_bounce_to_next_target(body):
		return
	if pierce:
		pierce_count += 1
		if pierce_count >= pierce_hit_limit:
			_return_to_pool()
	else:
		_return_to_pool()

func _try_bounce_to_next_target(current_body) -> bool:
	if bounce_remaining <= 0:
		return false
	var target = null
	var best_distance = bounce_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == current_body or enemy in hit_enemies:
			continue
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible:
			continue
		if not enemy.has_method("take_damage") or int(enemy.get("hp")) <= 0:
			continue
		var distance = position.distance_to(enemy.position)
		if distance < best_distance:
			best_distance = distance
			target = enemy
	if target == null:
		return false
	bounce_remaining -= 1
	direction = (target.position - position).normalized()
	return true
