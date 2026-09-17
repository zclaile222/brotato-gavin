extends Area2D

# BurnZone.gd — 地面燃烧区域（火焰 Boss 冲锋路径的产物）
#
# 来源：docs/boss-variants-design.md §1.4「燃烧区域：新的场景节点 BurnZone.tscn，
# 持续时间可配置，玩家进入后触发 apply_burn」。
#
# 设计要点：
# 1. **只点燃玩家，不伤敌人**（collision_mask 只留玩家所在的 layer 1）。
#    敌方自己踩自己的火没有意义，而且会让火焰 Boss 变成「友军杀手」。
# 2. 触发方式是**每物理帧轮询重叠体**，不是 body_entered 信号：
#    Boss 冲锋时可能把燃烧区域直接生成在玩家身上，此时信号不会触发
#    （Area2D 进入树时已经重叠，body_entered 要等「先离开再进入」才发）。
#    轮询等价于「站在火里就着火」，语义更贴近地面火焰。
# 3. **重新施加有节流**（REAPPLY_INTERVAL）。逐帧刷新会让玩家在火里的燃烧
#    永远不会到期，等于「站在火里持续掉血」，与设计文档「踩上去触发」不符。
# 4. 状态施加走 PlayerStatus 的公开 API（apply_burn），不碰玩家属性 ——
#    玩家侧的燃烧语义（刷新时长不叠伤害）只有一份定义。

const REAPPLY_INTERVAL := 0.5

var life_timer := 0.0
var radius := 60.0
var _apply_timer := 0.0

func _ready():
	add_to_group("burn_zones")
	z_index = -1  # 地面层：画在单位之下
	# 池外节点，使用结束后 queue_free，不参与对象池
	_sync_body_polygon(radius)

# 视觉跟着半径走：场景里的 Body 只声明颜色，多边形在这里按半径生成，
# 避免「改了半径但圈还是原来那么大」这种视觉/判定脱节（Enemy 的碰撞体同理）。
func _sync_body_polygon(value: float):
	var body = get_node_or_null("Body")
	if body == null or not (body is Polygon2D):
		return
	var pts := PackedVector2Array()
	var segments := 24
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * value)
	body.polygon = pts

# 由火焰 Boss 调用。追加在 _ready 之后（必须先 add_child 再 activate）：
# 节点在树外调用 get_viewport_rect() 之类的 API 会直接报错。
func activate(at: Vector2, duration: float, p_radius: float = 60.0):
	position = at
	life_timer = max(0.05, duration)
	# 形状必须先 duplicate —— 场景里的 shape 是共享 SubResource，
	# 直接改半径会污染其它实例（Enemy._sync_collision_extents 踩过同一个坑）。
	_set_shape_radius(max(1.0, p_radius))
	_sync_body_polygon(max(1.0, p_radius))
	radius = max(1.0, p_radius)
	_apply_timer = 0.0
	visible = true
	set_process(true)
	set_physics_process(true)

func _set_shape_radius(value: float):
	var shape_node = get_node_or_null("CollisionShape2D")
	if shape_node == null:
		return
	var shape: Shape2D = shape_node.shape
	if shape == null:
		return
	if not shape.has_meta("burn_zone_own_shape"):
		shape = shape.duplicate()
		shape.set_meta("burn_zone_own_shape", true)
		shape_node.shape = shape
	if shape is CircleShape2D:
		shape.radius = value

func _process(delta):
	# 持续时间可配置：到期即消失（queue_free 延迟释放，但已不再施加燃烧）
	life_timer -= delta
	if life_timer <= 0.0:
		set_process(false)
		set_physics_process(false)
		queue_free()

func _physics_process(delta):
	if _apply_timer > 0.0:
		_apply_timer -= delta
	if _apply_timer > 0.0:
		return
	var status = _player_status_in_zone()
	if status == null:
		return
	_apply_timer = REAPPLY_INTERVAL
	status.apply_burn()

# 只有玩家会被点燃。返回玩家的 PlayerStatus，取不到就返回 null。
func _player_status_in_zone():
	for body in get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue
		if not body.is_in_group("player"):
			continue
		var status = body.get("status")
		if status == null:
			continue
		return status
	return null
