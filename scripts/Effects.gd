extends Node

# Effects.gd — 反馈层
#
# 池化纪律（务必保持，本项目的性能优化专门处理过这块）：
# ① 所有节点都在 `_init_pools()` 里**预建**，运行时只借还，不新建；
# ② 池实例「空闲」的权威判据是 **`visible`**，不是 `set_process`（后者在入树前调用无效）；
# ③ 池耗尽时才新建（保证功能不丢），多余的粒子一律 `visible = false`，
#    **绝不 remove/free** —— 换效果复用时还要用；
# ④ 新增几何一律缓存（`_ring_points()` / `_disc_points()`），`apply` 类函数不重算点集。

# ─── 对象池 ───
var _label_pool: Array = []
var _label_pool_size: int = 30
var _burst_pool: Array = []
var _burst_pool_size: int = 15
# 吸附条纹（材料拾取）：形状与爆散的方块不同，单独一个池，
# 免得混战里把池子抢空。
var _suction_pool: Array = []
var _suction_pool_size: int = 8
# 冲击环（升级 / 开箱 / 拾取高价值材料）
var _ring_pool: Array = []
var _ring_pool_size: int = 8
# 闪光核心盘
var _disc_pool: Array = []
var _disc_pool_size: int = 4
# 上升光柱
var _beam_pool: Array = []
var _beam_pool_size: int = 3

var _active_labels: Array = []  # [{label, expire_time}]
var _burst_children_map: Dictionary = {}     # root -> [Polygon2D]
var _suction_children_map: Dictionary = {}   # root -> [Polygon2D]

const PARTICLE_MAX: int = 20     # 每个爆散根节点的最大粒子数
const SUCTION_BARS: int = 6      # 每个吸附根节点的条纹数
const RING_SEGMENTS: int = 48
const DISC_SEGMENTS: int = 24

# ⚠ 形状必须用**显式 Vector2** 构造，不能写成 `PackedVector2Array([-3, -3, 3, -3, ...])`。
# 后者看着像「一串坐标」，实际会被逐个 float → Vector2 转换，全部变成 (0, 0)，
# 得到一堆**零面积多边形**：节点、可见性、颜色、Tween 全都正常，
# 探针也显示 visible=true、alpha=0.9，但屏幕上**一个像素都不画**。
# 这类「什么都对，就是看不见」的坑极难从代码上看出，必须读回像素才能证实
# （见 tools/capture_scene.gd 的 --effect=probe）。
# （GDScript 不允许把 PackedVector2Array(...) 当常量表达式，所以这里只能用 var。）
var _particle_shape: PackedVector2Array = PackedVector2Array([
	Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
])
var _suction_shape: PackedVector2Array = PackedVector2Array([
	Vector2(-8, -1.5), Vector2(8, -1.5), Vector2(8, 1.5), Vector2(-8, 1.5)
])
var _beam_shape: PackedVector2Array = PackedVector2Array([
	Vector2(-5, -130), Vector2(5, -130), Vector2(5, 0), Vector2(-5, 0)
])

const SUCTION_LIFE: float = 0.20
const SUCTION_CLEANUP: float = 0.34

# 过场（波次开始）：屏幕空间，必须挂在 CanvasLayer 上才压得住 HUD。
# HUD 是 CanvasLayer（默认 layer=1），这里取更高的层号。
const CEREMONY_LAYER: int = 12
const INTRO_DURATION: float = 1.5

var _ring_shape := PackedVector2Array()
var _disc_shape := PackedVector2Array()

var _intro_layer: CanvasLayer = null
var _intro_dim: ColorRect = null
var _intro_sweep: ColorRect = null
var _intro_title: Label = null
var _intro_sub: Label = null
var _intro_tween: Tween = null

func _ready():
	# 延迟初始化，等待 current_scene 就绪
	call_deferred("_init_pools")

func _init_pools():
	var owner = _get_pool_owner()
	if owner == null:
		return
	# 伤害数字池
	for i in _label_pool_size:
		var label = Label.new()
		label.visible = false
		label.z_index = 20
		owner.add_child(label)
		_label_pool.append(label)
	# 特效池
	for i in _burst_pool_size:
		var root = Node2D.new()
		root.visible = false
		var children = []
		for j in PARTICLE_MAX:  # 最大粒子数
			var sq = Polygon2D.new()
			sq.polygon = _particle_shape
			root.add_child(sq)
			children.append(sq)
		owner.add_child(root)
		_burst_pool.append(root)
		_burst_children_map[root] = children
	# 吸附条纹池：一根指向中心的短棒（所以形状是长条，不是方块）
	for i in _suction_pool_size:
		var sroot = Node2D.new()
		sroot.visible = false
		var bars = []
		for j in SUCTION_BARS:
			var bar = Polygon2D.new()
			bar.polygon = _suction_shape
			sroot.add_child(bar)
			bars.append(bar)
		owner.add_child(sroot)
		_suction_pool.append(sroot)
		_suction_children_map[sroot] = bars
	# 冲击环池
	for i in _ring_pool_size:
		var ring = Line2D.new()
		ring.points = _ring_points()
		ring.closed = true
		ring.z_index = 19
		ring.visible = false
		owner.add_child(ring)
		_ring_pool.append(ring)
	# 闪光核心池
	for i in _disc_pool_size:
		var disc = Polygon2D.new()
		disc.polygon = _disc_points()
		disc.z_index = 19
		disc.visible = false
		owner.add_child(disc)
		_disc_pool.append(disc)
	# 光柱池
	for i in _beam_pool_size:
		var beam = Polygon2D.new()
		beam.polygon = _beam_shape
		beam.z_index = 18
		beam.visible = false
		owner.add_child(beam)
		_beam_pool.append(beam)

func _get_pool_owner() -> Node:
	if is_inside_tree():
		return self
	return null

# 基准圆环：半径恒为 1，节点 scale 就是「当前半径」。
# 这样一条环能覆盖任意半径，不需要为每个尺寸预建不同几何。
func _ring_points() -> PackedVector2Array:
	if _ring_shape.is_empty():
		var pts := PackedVector2Array()
		for i in range(RING_SEGMENTS):
			var a := TAU * float(i) / float(RING_SEGMENTS)
			pts.append(Vector2(cos(a), sin(a)))
		_ring_shape = pts
	return _ring_shape

func _disc_points() -> PackedVector2Array:
	if _disc_shape.is_empty():
		var pts := PackedVector2Array()
		for i in range(DISC_SEGMENTS):
			var a := TAU * float(i) / float(DISC_SEGMENTS)
			pts.append(Vector2(cos(a), sin(a)))
		_disc_shape = pts
	return _disc_shape

func _process(_delta):
	# 清理过期的伤害数字
	var now = Time.get_ticks_msec() / 1000.0
	var i = _active_labels.size() - 1
	while i >= 0:
		if now >= _active_labels[i].expire_time:
			var entry = _active_labels[i]
			entry.label.visible = false
			entry.label.modulate.a = 1.0
			_label_pool.append(entry.label)
			_active_labels.remove_at(i)
		i -= 1

func _get_label() -> Label:
	while _label_pool.size() > 0:
		var label = _label_pool.pop_back()
		if is_instance_valid(label) and label.is_inside_tree():
			return label
	# 池耗尽，创建新的
	var scene = get_tree().current_scene
	var label = Label.new()
	label.z_index = 20
	var owner = _get_pool_owner()
	if owner:
		owner.add_child(label)
	return label

func _get_burst_root() -> Node2D:
	while _burst_pool.size() > 0:
		var pooled_root = _burst_pool.pop_back()
		if is_instance_valid(pooled_root) and pooled_root.is_inside_tree():
			return pooled_root
	# 池耗尽，创建新的
	var scene = get_tree().current_scene
	var root = Node2D.new()
	var children = []
	for j in PARTICLE_MAX:
		var sq = Polygon2D.new()
		sq.polygon = _particle_shape
		root.add_child(sq)
		children.append(sq)
	var owner = _get_pool_owner()
	if owner:
		owner.add_child(root)
	_burst_children_map[root] = children
	return root

func _get_suction_root() -> Node2D:
	while _suction_pool.size() > 0:
		var pooled_root = _suction_pool.pop_back()
		if is_instance_valid(pooled_root) and pooled_root.is_inside_tree():
			return pooled_root
	var root = Node2D.new()
	var bars = []
	for j in SUCTION_BARS:
		var bar = Polygon2D.new()
		bar.polygon = _suction_shape
		root.add_child(bar)
		bars.append(bar)
	var owner = _get_pool_owner()
	if owner:
		owner.add_child(root)
	_suction_children_map[root] = bars
	return root

func _get_ring() -> Line2D:
	while _ring_pool.size() > 0:
		var pooled = _ring_pool.pop_back()
		if is_instance_valid(pooled) and pooled.is_inside_tree():
			return pooled
	var ring = Line2D.new()
	ring.points = _ring_points()
	ring.closed = true
	ring.z_index = 19
	var owner = _get_pool_owner()
	if owner:
		owner.add_child(ring)
	return ring

func _get_disc() -> Polygon2D:
	while _disc_pool.size() > 0:
		var pooled = _disc_pool.pop_back()
		if is_instance_valid(pooled) and pooled.is_inside_tree():
			return pooled
	var disc = Polygon2D.new()
	disc.polygon = _disc_points()
	disc.z_index = 19
	var owner = _get_pool_owner()
	if owner:
		owner.add_child(disc)
	return disc

func _get_beam() -> Polygon2D:
	while _beam_pool.size() > 0:
		var pooled = _beam_pool.pop_back()
		if is_instance_valid(pooled) and pooled.is_inside_tree():
			return pooled
	var beam = Polygon2D.new()
	beam.polygon = _beam_shape
	beam.z_index = 18
	var owner = _get_pool_owner()
	if owner:
		owner.add_child(beam)
	return beam

# ─── 公共接口 ───

# 子弹命中小火花。**保持原样**：它是「命中」的语汇，与拾取/仪式必须是三种不同的观感。
func hit_spark(pos: Vector2, color: Color):
	_burst(pos, color, 5, 55, 0.22)

# 敌人死亡爆炸。也保持原样（死亡 = 向外炸开）。
func death_burst(pos: Vector2, color: Color):
	_burst(pos, color, 12, 95, 0.42)

# ── 材料 / 经验拾取 ──
# 手感的关键是**方向朝内**：原版 Brotato 里最上瘾的就是「材料被吸过来」的那一下。
# 所以这里不用 `_burst()`（它是朝外炸的），而是：
#   ① 吸附条纹：从四周**加速收束**到落点（EASE_IN = 起步慢、末段快，像被吸进去）
#   ② 一圈短促的接收环：给「收下了」一个明确的结算点
#   ③ 高价值材料额外弹一个 +N（避免 1 点材料也刷字，那会糊成一片）
func material_pickup(pos: Vector2, amount: int, color: Color = Color(0.3, 1.0, 0.4)):
	_suction(pos, color)
	_ring_pulse(pos, Color(color.r, color.g, color.b, 0.7), 3.0, 22.0, 0.24, 2.2)
	if amount >= 3:
		_float_text(pos + Vector2(0, -18), "+%d" % amount, color, 15, -26.0, 0.55)

# ── 升级 ──
# 仪式感 = **分层 + 有节奏**，而不是「粒子多一点」。原来只是一把粒子喷出去，
# 和死亡爆炸没有区别，玩家读不出「我升级了」。
# 现在拆成四拍：爆散（保留旧观感）→ 白色闪光核心 → 双环（一快一慢，金色补第二拍）
# → 上升光柱（给「等级提升」一个向上/变强的方向隐喻）。
func level_up_burst(pos: Vector2):
	_burst(pos, Color(0.4, 1.0, 0.5), 20, 130, 0.55)
	_flash(pos, Color(0.8, 1.0, 0.85), 30.0, 0.20)
	_ring_pulse(pos, Color(0.55, 1.0, 0.72, 0.9), 4.0, 62.0, 0.30, 3.0)
	_after(0.12, func():
		_ring_pulse(pos, Color(1.0, 0.9, 0.42, 0.85), 4.0, 92.0, 0.44, 2.4)
	)
	_beam(pos, Color(0.62, 1.0, 0.78), 0.5)

# ── 开箱 ──
# 与升级区分开：开箱是「有东西交到你手上」，所以是**收束 + 一次爆发**，
# 颜色按箱子的稀有度走，箱子越高级环越多。
func crate_open_burst(pos: Vector2, tier: int = 1):
	var index: int = clampi(tier, 1, 4)
	var colors := [
		Color(0.65, 0.78, 0.95),
		Color(0.45, 0.95, 0.65),
		Color(0.95, 0.72, 0.28),
		Color(0.95, 0.42, 0.75),
	]
	var color: Color = colors[index - 1]
	_burst(pos, color, 10, 90, 0.38)
	_flash(pos, Color(color.r, color.g, color.b, 0.85), 22.0, 0.16)
	# 环数随稀有度递增：普通 1 圈、最高 3 圈，一眼就能看出「这是个好东西」
	for k in range(index):
		var delay := 0.1 * float(k)
		_after(delay, func():
			_ring_pulse(pos, Color(color.r, color.g, color.b, 0.85), 4.0, 54.0 + 22.0 * float(k), 0.34, 2.6)
		)
	if tier >= 4:
		_beam(pos, Color(color.r, color.g, color.b, 0.9), 0.55)

# ── 波次开始过场 ──
# 不只是「弹个提示」：这是一次**屏幕级**的过场 ——
#   ① 压暗一层（把注意力从 HUD/战场上收回来）
#   ② 一条高亮扫描带从上到下扫过（运动本身承担「开始」的语义）
#   ③ 大字波次号 + 副标题，缩放落定后一起淡出
# 用一次性创建的 4 个节点 + Tween 实现，不做对象池：同时只可能有一场过场。
func wave_intro(wave: int, total: int = 0, subtitle: String = ""):
	if not is_inside_tree():
		return
	_ensure_intro_layer()
	if _intro_layer == null:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()

	var view: Vector2 = get_viewport().get_visible_rect().size
	var accent := _wave_accent(wave)
	_intro_title.text = "第 %d 波" % wave
	_intro_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_intro_title.add_theme_font_size_override("font_size", 56)
	_intro_title.size = Vector2(view.x, 80.0)
	_intro_title.position = Vector2(0.0, view.y * 0.5 - 62.0)
	_intro_title.pivot_offset = Vector2(view.x * 0.5, 40.0)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_title.scale = Vector2(0.88, 0.88)
	_intro_title.modulate.a = 0.0

	var sub_text := subtitle
	if sub_text.is_empty() and total > 0:
		sub_text = "%d / %d" % [wave, total]
	_intro_sub.text = sub_text
	_intro_sub.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))
	_intro_sub.add_theme_font_size_override("font_size", 20)
	_intro_sub.size = Vector2(view.x, 28.0)
	# ⚠ 副标题放在中线**下方 62px**：扫描带是从上到下扫过中线的，
	# 贴在中线上会被它糊住（截图里就是「副标题凭空消失」）。
	_intro_sub.position = Vector2(0.0, view.y * 0.5 + 62.0)
	_intro_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_sub.modulate.a = 0.0

	_intro_dim.color = Color(0.02, 0.02, 0.04, 0.0)
	_intro_dim.size = view
	_intro_dim.visible = true
	_intro_sweep.color = Color(accent.r, accent.g, accent.b, 0.55)
	_intro_sweep.size = Vector2(view.x, 5.0)
	_intro_sweep.position = Vector2(0.0, -20.0)
	_intro_sweep.visible = true
	_intro_layer.visible = true

	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	# ① 压暗 → 后段淡出
	_intro_tween.tween_property(_intro_dim, "color:a", 0.34, 0.16)
	_intro_tween.tween_property(_intro_dim, "color:a", 0.0, 0.55).set_delay(0.9)
	# ② 扫描带：先扫完（0.5s 内穿过整屏），文字再落定 ——
	#    顺序反过来（同时进行）的话，扫描带会正好从标题/副标题身上碾过去。
	_intro_tween.tween_property(_intro_sweep, "position:y", view.y + 20.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_intro_sweep, "color:a", 0.0, 0.14).set_delay(0.46)
	# ③ 文字：落定 → 停留 → 淡出
	_intro_tween.tween_property(_intro_title, "modulate:a", 1.0, 0.18).set_delay(0.36)
	_intro_tween.tween_property(_intro_title, "scale", Vector2.ONE, 0.26).set_delay(0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_intro_title, "modulate:a", 0.0, 0.4).set_delay(1.15)
	_intro_tween.tween_property(_intro_sub, "modulate:a", 1.0, 0.2).set_delay(0.54)
	_intro_tween.tween_property(_intro_sub, "modulate:a", 0.0, 0.4).set_delay(1.15)
	_intro_tween.chain().tween_callback(_hide_intro)

func _hide_intro():
	if _intro_layer != null and is_instance_valid(_intro_layer):
		_intro_layer.visible = false

# 波次主题色 —— 与战场舞台的色温表同源（换色温是「波次叙事」的一部分，
# 过场的强调色跟着一起走，两者才不会互相打架）。
func _wave_accent(wave: int) -> Color:
	if wave >= 20:
		return Color(0.72, 0.42, 0.98)
	if wave >= 15:
		return Color(0.95, 0.34, 0.26)
	if wave >= 10:
		return Color(0.98, 0.72, 0.28)
	if wave >= 5:
		return Color(0.28, 0.88, 0.78)
	return Color(0.42, 0.66, 1.0)

# 浮动伤害数字
func damage_number(pos: Vector2, amount: int, is_crit: bool = false):
	_float_text(
		pos + Vector2(randf_range(-15, 15), -10),
		str(amount) if not is_crit else "!" + str(amount) + "!",
		Color(1, 1, 0.3) if is_crit else Color(1, 0.9, 0.9),
		22 if not is_crit else 32,
		-50.0,
		0.8
	)

# ─── 内部实现 ───

# 向外炸散（命中 / 死亡 / 升级第一拍共用的底层动作）
func _burst(pos: Vector2, color: Color, count: int, spd: float, life: float):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var root = _get_burst_root()
	root.position = pos
	root.visible = true

	var children = _burst_children_map.get(root, [])
	for i in count:
		if i >= children.size():
			break
		var sq = children[i]
		sq.visible = true
		sq.position = Vector2.ZERO
		sq.scale = Vector2.ONE
		sq.color = color

		var angle = TAU * i / count + randf() * 0.5
		var target = Vector2(cos(angle), sin(angle)) * randf_range(spd * 0.4, spd)

		var tw = root.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sq, "position", target, life)
		tw.tween_property(sq, "color", Color(color.r, color.g, color.b, 0.0), life)

	# 隐藏多余的粒子
	for j in range(count, children.size()):
		children[j].visible = false

	get_tree().create_timer(life + 0.1).timeout.connect(func():
		if is_instance_valid(root):
			root.visible = false
			_burst_pool.append(root)
	)

# 向**内**收束。与 _burst 镜像：起点在四周，终点是落点，且用 EASE_IN
# 让人眼读到「加速被吸进去」而不是匀速平移。
func _suction(pos: Vector2, color: Color):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var root = _get_suction_root()
	root.position = pos
	root.visible = true

	var bars = _suction_children_map.get(root, [])
	for i in bars.size():
		var bar: Polygon2D = bars[i]
		var angle := TAU * float(i) / float(bars.size()) + 0.4
		bar.visible = true
		bar.position = Vector2(cos(angle), sin(angle)) * 30.0
		bar.rotation = angle
		bar.scale = Vector2.ONE
		bar.color = Color(color.r, color.g, color.b, 0.95)

		var tw = root.create_tween()
		tw.set_parallel(true)
		tw.tween_property(bar, "position", Vector2.ZERO, SUCTION_LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(bar, "scale", Vector2(0.25, 0.25), SUCTION_LIFE)
		tw.tween_property(bar, "color", Color(color.r, color.g, color.b, 0.0), SUCTION_LIFE)

	get_tree().create_timer(SUCTION_CLEANUP).timeout.connect(func():
		if is_instance_valid(root):
			root.visible = false
			_suction_pool.append(root)
	)

# 冲击环。基准环半径是 1，所以 scale 就是半径；
# `width` 是局部单位（会跟着 scale 一起放大），所以每帧按 1/radius 反算，
# 让**屏幕上的环宽恒定** —— 否则小半径时环细到看不见、大半径时糊成一圈色块。
func _ring_pulse(pos: Vector2, color: Color, from_radius: float, to_radius: float, life: float, screen_width: float):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var ring := _get_ring()
	ring.position = pos
	ring.default_color = color
	ring.visible = true
	ring.scale = Vector2.ONE * from_radius
	ring.width = screen_width / maxf(0.001, from_radius)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(r: float):
		if is_instance_valid(ring):
			ring.scale = Vector2.ONE * r
			ring.width = screen_width / maxf(0.001, r)
	, from_radius, to_radius, life)
	tween.tween_property(ring, "default_color", Color(color.r, color.g, color.b, 0.0), life)
	tween.chain().tween_callback(func():
		if is_instance_valid(ring):
			ring.visible = false
			_ring_pool.append(ring)
	)

# 短促的闪光核心
func _flash(pos: Vector2, color: Color, radius: float, life: float):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var disc := _get_disc()
	disc.position = pos
	disc.color = color
	disc.scale = Vector2.ONE * radius * 0.45
	disc.visible = true

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(disc, "scale", Vector2.ONE * radius, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(disc, "color", Color(color.r, color.g, color.b, 0.0), life)
	tween.chain().tween_callback(func():
		if is_instance_valid(disc):
			disc.visible = false
			_disc_pool.append(disc)
	)

# 上升光柱：给「变强」一个方向。多边形以原点为底、向上展开，所以 scale.y 就是「长出来」。
func _beam(pos: Vector2, color: Color, life: float):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var beam := _get_beam()
	beam.position = pos
	beam.color = color
	beam.scale = Vector2(0.6, 0.25)
	beam.visible = true

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam, "scale:y", 1.0, life * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(beam, "scale:x", 1.0, life * 0.45)
	tween.tween_property(beam, "color", Color(color.r, color.g, color.b, 0.0), life).set_delay(life * 0.3)
	tween.chain().tween_callback(func():
		if is_instance_valid(beam):
			beam.visible = false
			_beam_pool.append(beam)
	)

func _after(seconds: float, callback: Callable):
	if not is_inside_tree():
		return
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_inside_tree():
			callback.call()
	)

# 浮动文字（伤害数字与 +N 共用）。生命周期由 `_process` 统一回收，
# 比让 Tween 回调回收更稳（Tween 在场景切换时会被打断）。
func _float_text(pos: Vector2, text: String, color: Color, font_size: int, rise: float, life: float):
	var label = _get_label()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	label.modulate.a = 1.0
	label.visible = true
	var scene = get_tree().current_scene
	if scene:
		var tween = scene.create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y + rise, life)
		tween.tween_property(label, "modulate:a", 0.0, life)
	# 回收时间比动画稍长，确保动画完成
	_active_labels.append({"label": label, "expire_time": Time.get_ticks_msec() / 1000.0 + life + 0.05})

# 过场用的 4 个节点：一次性建好后反复用。
# 过场同一时刻只可能有一场，所以不需要池化；但也**绝不每次调用都新建**。
func _ensure_intro_layer():
	if _intro_layer != null and is_instance_valid(_intro_layer):
		return
	var owner = _get_pool_owner()
	if owner == null:
		return
	_intro_layer = CanvasLayer.new()
	_intro_layer.name = "CeremonyLayer"
	_intro_layer.layer = CEREMONY_LAYER
	_intro_layer.visible = false
	owner.add_child(_intro_layer)

	_intro_dim = ColorRect.new()
	_intro_dim.name = "Dim"
	_intro_dim.color = Color(0.02, 0.02, 0.04, 0.0)
	_intro_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(_intro_dim)

	_intro_sweep = ColorRect.new()
	_intro_sweep.name = "Sweep"
	_intro_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(_intro_sweep)

	_intro_title = Label.new()
	_intro_title.name = "Title"
	_intro_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(_intro_title)

	_intro_sub = Label.new()
	_intro_sub.name = "Subtitle"
	_intro_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_layer.add_child(_intro_sub)
