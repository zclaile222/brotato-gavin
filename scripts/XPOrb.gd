extends Area2D

const SPEED_MIN = 150.0
const SPEED_MAX = 600.0

var material_value = 1
var xp_value = 1 # Transitional alias for scene compatibility.
var player = null
var _active = false

func _ready():
	add_to_group("xp_orbs")
	monitoring = true
	body_entered.connect(_on_body_entered)
	# 池中初始状态
	visible = false
	set_process(false)

func activate(pos: Vector2, value: int):
	position = pos
	material_value = max(0, value)
	xp_value = material_value
	scale = Vector2(1, 1)
	player = get_tree().get_first_node_in_group("player") if get_tree() != null else null
	_active = true
	visible = true
	set_process(true)

func _return_to_pool():
	visible = false
	set_process(false)
	_active = false
	player = null
	material_value = 1
	xp_value = 1
	scale = Vector2(1, 1)

func _process(delta):
	if player == null or not is_instance_valid(player):
		return
	var mag_range = player.magnet_range if "magnet_range" in player else 160.0
	var dist = position.distance_to(player.position)
	if dist < mag_range:
		# 距离越近速度越快：远处150，近处600
		var ratio = 1.0 - clamp(dist / mag_range, 0.0, 1.0)
		var spd = lerp(SPEED_MIN, SPEED_MAX, ratio)
		position = position.move_toward(player.position, spd * delta)

func _on_body_entered(body):
	collect(body)

func collect(body):
	if not _active:
		return
	if body.is_in_group("player"):
		_active = false
		set_process(false)
		var gained_value = material_value
		if body.has_method("apply_material_pickup_modifiers"):
			gained_value = body.apply_material_pickup_modifiers(material_value)
		# 拾取手感：向内吸附 + 接收环（旧的 hit_spark 是向外炸的火花，语汇相反）。
		# 必须放在 gained_value 算完之后 —— 飘字要显示**实际到手**的数量。
		Effects.material_pickup(position, gained_value, Color(0.3, 1, 0.4))
		if body.has_method("earn_gold"):
			body.earn_gold(gained_value)
		if body.has_method("gain_xp"):
			body.gain_xp(gained_value)
		# 拾取材料的钩子（Blunderbuss 的 material_pickup_resets_cooldown 用它重置冷却）
		if body.has_method("on_material_picked_up"):
			body.on_material_picked_up(gained_value)
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.06)
		tw.tween_property(self, "scale", Vector2(0.0, 0.0), 0.1)
		tw.tween_callback(_return_to_pool)
