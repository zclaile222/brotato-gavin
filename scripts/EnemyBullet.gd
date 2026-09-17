extends Area2D

const SPEED = 220.0
const ENEMY_BULLET_Z_INDEX := 20

# 无元素子弹的颜色，与 scenes/EnemyBullet.tscn 里 Body 的初始色保持一致
const DEFAULT_ELEMENT_COLOR := Color(0.9, 0.3, 0.9)
# 元素只影响两件事：子弹颜色、命中玩家时施加的状态。
# 状态本身在 PlayerStatus 里定义（元素 → 效果的映射只有一份）。
const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.4, 0.0),
	"frost": Color(0.5, 0.8, 1.0),
	"lightning": Color(1.0, 1.0, 0.3),
}

var direction = Vector2.RIGHT
# "" = 无元素（基础 Boss / 普通敌人）
var element := ""
# 链式闪电：命中玩家后还会再飞回来的剩余次数（0 = 普通子弹）。
# 由 Enemy._shoot_chain_bolt() 在激活后写入，见 docs/boss-variants-design.md §3.4。
var chain_remaining := 0
var _lifetime = 0.0
var _active = false

# 链的下一跳从哪里起飞。刻意放在玩家无敌帧（0.8s）之外的距离上：
# 220px/s 飞 200px 约 0.9s，刚好让下一跳能真正落到玩家身上。
# 太近的下一跳会被无敌帧整发挡掉，链式闪电就只剩特效了。
const CHAIN_ARC_DISTANCE := 200.0

func _ready():
	add_to_group("enemy_bullets")
	z_index = ENEMY_BULLET_Z_INDEX
	monitoring = true
	body_entered.connect(_on_body_entered)
	# 池中初始状态
	visible = false
	set_process(false)

# 新字段一律追加到参数表末尾：activate() 已被 Enemy 的三种弹幕模式调用，
# 追加带默认值的参数可以保持所有既有调用方不变。
func activate(pos: Vector2, dir: Vector2, p_element: String = ""):
	position = pos
	direction = dir
	element = p_element
	# 池化对象不能把上一轮的链状态带出去
	chain_remaining = 0
	_lifetime = 0.0
	_active = true
	z_index = ENEMY_BULLET_Z_INDEX
	$Body.color = ELEMENT_COLORS.get(element, DEFAULT_ELEMENT_COLOR)
	visible = true
	set_process(true)

func _return_to_pool():
	visible = false
	set_process(false)
	_active = false
	# 池化对象不能把上一轮的元素 / 链状态带出去
	element = ""
	chain_remaining = 0

func _process(delta):
	_lifetime += delta
	if _lifetime >= 4.0:
		_return_to_pool()
		return

	position += direction * SPEED * delta
	# 与 Bullet.gd 同一判据：出界 = 离开当前视野（相机矩形外扩 50px），不是离开场地。
	var arena := Arena.get_active()
	if arena != null:
		if arena.is_outside_viewport(position, 50.0):
			_return_to_pool()
	else:
		var screen = get_viewport_rect().size
		if position.x < -50 or position.x > screen.x + 50 or position.y < -50 or position.y > screen.y + 50:
			_return_to_pool()

func _on_body_entered(body):
	if not _active:
		return
	if body.is_in_group("player"):
		# element 透传给 take_damage：真正施加状态的是 PlayerCore，
		# 它在伤害落地之后才调用 PlayerStatus.apply_element()，
		# 所以被闪避 / 无敌帧挡下的命中不会附带 debuff。
		body.take_damage(1, element)
		var hops := chain_remaining
		var hop_element := element
		_return_to_pool()
		if hops > 0:
			_spawn_chain_hop(body, hops, hop_element)

# 链式闪电的下一跳。敌方视角下「最近的另一个目标」只有玩家一个，
# 所以链的语义退化为「对同一目标连续打击」（见 docs/boss-variants-design.md §3.3）。
# 新子弹从玩家附近的一个随机方向飞来，而不是从玩家身上原地重生 ——
# 原地重生的话 Area2D 已经重叠，body_entered 不会再触发，第二跳永远打不中。
func _spawn_chain_hop(target, hops: int, hop_element: String):
	var main = get_parent()
	if main == null or not is_instance_valid(main):
		return
	if target == null or not is_instance_valid(target):
		return
	var bullet = null
	if main.has_method("get_enemy_bullet"):
		bullet = main.get_enemy_bullet()
	else:
		bullet = load("res://scenes/EnemyBullet.tscn").instantiate()
		main.add_child(bullet)
	var away := -direction.normalized() if direction.length_squared() > 0.0 else Vector2.RIGHT
	var origin: Vector2 = target.position + away.rotated(randf_range(-0.9, 0.9)) * CHAIN_ARC_DISTANCE
	var aim: Vector2 = target.position - origin
	if aim.length_squared() <= 0.001:
		aim = Vector2.RIGHT
	bullet.activate(origin, aim.normalized(), hop_element)
	bullet.chain_remaining = hops - 1
