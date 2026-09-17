extends Node2D

# ArenaBackground.gd — 战场「舞台」
#
# 为什么需要它：改造前战场是一整块纯色虚空（default_clear_color），单位漂浮其上。
# 后果不只是不好看 —— **没有参照物就看不出移动**：敌人朝玩家走过来时，
# 视觉上只是「一个色块慢慢变大」，位移这件事本身读不出来。而且单位越可爱，
# 空背景越显眼。
#
# 这个脚本只做「舞台」，不碰任何玩法：全部程序化绘制，零美术资产。
#
# ─── 性能纪律（本项目对对象池/性能敏感，这里刻意选了最省的方案）───
# ① **零新增节点**：所有几何都在**一个** CanvasItem 的 `_draw()` 里画完。
#    没有「每个点建一个 Polygon2D」（那会是几百个节点 + 几百次 transform 更新）。
# ② **几何全部缓存**：点集只在 `_ready()` / 窗口尺寸变化 / 波次换色时重建一次，
#    `_draw()` 只做「把缓存好的数组提交给渲染器」。
#    特别注意**没有用 `_process` 重建几何**——那是本项目最常见的性能陷阱。
# ③ **世界空间几何完全静态**：摄像机固定，网格不随任何东西移动，
#    所以 CanvasItem 的绘制指令列表是稳定的，不需要每帧 queue_redraw()。
# ④ 每帧唯一的脚本开销是一个 4Hz 的波次轮询（读一次父节点属性）。
# ⑤ **不使用全局随机数**：舞台一动都不动，用了 `randf()` 只会把全局 RNG 流搅乱，
#    连带让「同一 seed 的两次截图」产生真实差异 —— 那样改前/改后就没法比了。
#
# 这一套下来，1080p 下的收益是「约 50 条静态绘制指令」，代价接近 0。
#
# ─── 与其它层的关系 ───
# z_index 由 Main.tscn 设为负值，且是 Main 的第一个子节点，**必然在所有单位之下**；
# HUD 是 CanvasLayer（独立画布），天然在它之上，不会被遮。

# 舞台画到屏幕外多少像素。摄像机有受击抖动（±15px），不留出血就会在边缘露出底色。
const MARGIN := 96.0
# 暗角向内渗透的深度
const VIGNETTE_DEPTH := 150.0
# 暗角最深处的强度（不能太高：敌人是从屏幕外走进来的，边缘太黑会看不见它们入场）
const VIGNETTE_ALPHA := 0.42

# 方形网格的格距；MAJOR_EVERY 格画一条更亮的线并在交点打点
const GRID := 64.0
const GRID_MAJOR_EVERY := 4
# 环形风格的环距
const RING_STEP := 70.0

const BOUNDARY_INSET := 12.0

# 波次主题色温。给战场一个「这局打到哪了」的叙事：
# 每 5 波换一档，底色与线条一起偏过去。
# 注意 floor 要和 default_clear_color(0.08,0.08,0.12) 拉开一点，
# 否则「画了但看不出来」（截图技能 §2 的经典坑）。
const THEME_BANDS := [
	{"from": 1,  "line": Color(0.30, 0.42, 0.62), "accent": Color(0.42, 0.66, 1.00), "floor": Color(0.070, 0.082, 0.125)},
	{"from": 5,  "line": Color(0.24, 0.46, 0.50), "accent": Color(0.28, 0.88, 0.78), "floor": Color(0.058, 0.098, 0.112)},
	{"from": 10, "line": Color(0.52, 0.42, 0.24), "accent": Color(0.98, 0.72, 0.28), "floor": Color(0.108, 0.088, 0.068)},
	{"from": 15, "line": Color(0.54, 0.26, 0.26), "accent": Color(0.95, 0.34, 0.26), "floor": Color(0.112, 0.062, 0.072)},
	{"from": 20, "line": Color(0.42, 0.26, 0.56), "accent": Color(0.72, 0.42, 0.98), "floor": Color(0.092, 0.068, 0.122)},
]

# 三个方向，供人选：
#   grid    —— 方形网格 + 交点亮点 + 直角边界。移动参照最强，工程/科技感。
#   arena   —— 同心环 + 放射虚线 + 圆形边界。像竞技场，但**移动参照较弱**：
#              单位多是径向朝玩家走，而径向运动在同心环上几乎是看不出来的。
#   minimal —— 只有稀疏点阵 + 边界 + 暗角。最保守，几乎不占视觉预算。
@export var style: String = "grid":
	set(value):
		style = value
		if is_node_ready():
			_rebuild()
			queue_redraw()

# 细网格线的透明度。做成参数是为了让「网格要多明显」变成一个可摆出来对比的选择，
# 而不是我替谁拍板 —— 0.16 偏含蓄，0.28 明显得多。
@export_range(0.02, 1.0, 0.01) var grid_minor_alpha: float = 0.16:
	set(value):
		grid_minor_alpha = value
		queue_redraw()

var theme_wave: int = 1

# ─── 缓存几何（只在需要时重建）───
# _world_size = 场地尺寸（3×3 屏，来自 Arena）；_viewport_size = 实际视口，两者是两件事：
# 网格与地面要按**场地**铺满，暗角要按**视口**分布（它贴的是屏幕边，不是场地边）。
var _world_size := Vector2(1280.0, 720.0)
var _viewport_size := Vector2(1280.0, 720.0)
var _floor := Rect2()
var _grid_minor := PackedVector2Array()
var _grid_major := PackedVector2Array()
var _dots := PackedVector2Array()
var _spokes := PackedVector2Array()
var _ring_radii: Array[float] = []
var _boundary := Rect2()
var _brackets := PackedVector2Array()
var _crosshair := PackedVector2Array()
var _vig_points: Array[PackedVector2Array] = []
var _vig_colors: Array[PackedColorArray] = []

# ─── 主题色 ───
var _c_floor := Color(0.07, 0.082, 0.125)
var _c_line := Color(0.30, 0.42, 0.62)
var _c_accent := Color(0.42, 0.66, 1.0)

var _poll_frames := 0
var _last_wave := -1


func _ready():
	_viewport_size = get_viewport_rect().size
	# 两条尺寸通路，各管各的缓存：
	#   · 视口变化 → 暗角要跟着屏幕走（它是屏幕边特效）
	#   · Arena.resized → 场地变化 → 网格 / 地面 / 边界要跟着场地走
	# 项目里的教训是「同一份数据两条转换路径 = 迟早分叉」，这里刻意区分成
	# 两个**不同**的量（_viewport_size / _world_size），不做成一份。
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_viewport_resized)
	# 几何缓存依赖场地尺寸，但本节点是 Main.tscn 里写死的子节点，而 Main.gd 用
	# `Arena.new()` 在**运行时**建场地 —— 本节点 _ready() 必然排在场地注册之前，
	# 此时 `Arena.get_active()` 还是 null。所以订阅走静态入口，它自己处理两种时序。
	# 直接连 `resized` 会漏接（实测过：get_connections() 一直是空的）。
	Arena.on_ready_geometry(_on_arena_resized)
	_apply_theme()
	_rebuild()
	# 开局不放过场：主菜单进来的第一波已经有 HUD 的新手提示，两个大字会互相打架。
	_last_wave = _read_wave()
	# ⚠ world 这里是**初值**，不是最终值：本节点 _ready() 早于 Arena 注册，
	# 此时只能按一屏算。真正的场地尺寸在 Arena 就绪后由 on_ready_geometry 回调重建
	# （下一帧生效），所以这行打印只用于确认「节点起来了」。
	# 要断言最终尺寸请查 tests/camera_arena_smoke.gd，它读的是重建后的 _world_size。
	print("ARENA_BACKGROUND_READY style=%s wave=%d world_init=%dx%d viewport=%dx%d" % [
		style, _last_wave, int(_world_size.x), int(_world_size.y),
		int(_viewport_size.x), int(_viewport_size.y)
	])


func _on_arena_resized() -> void:
	# 场地尺寸变了（首次注册 / 视口缩放）：网格、地面、边界都要按新场地重建。
	# `_rebuild()` 内部自己从 Arena 读 world_rect()，所以这里不需要传参。
	_rebuild()
	queue_redraw()


func _on_viewport_resized():
	_viewport_size = get_viewport_rect().size
	# 暗角贴的是屏幕边，视口一变就要重建。
	# 场地尺寸也会跟着变（世界 = 3×3 视口），但那一路由 Arena.resized 负责 ——
	# 两条通路各改各的缓存，不会互相触发成环。
	_rebuild()
	queue_redraw()


# 舞台是静态的，这里唯一要做的事是「波次变了 → 换色温 + 播过场」。
# 轮询而不是连信号：Main.gd 不在本轮的改动范围内，而波次变化本身很稀疏（几十秒一次），
# 按帧号轮询（每 15 帧 ≈ 60fps 下 4Hz）读一次父节点属性，比为了一个信号去改 Main.gd 划算得多。
# ⚠ 用**帧号**而不是累加 delta：截图工具里循环跑得极快（delta ≈ 0.5ms），
# 按时间累加要几百帧才够一次轮询 —— 那样离线截图永远截不到换过色的舞台。
func _process(_delta: float):
	_poll_frames += 1
	if _poll_frames < 15:
		return
	_poll_frames = 0
	var wave := _read_wave()
	if wave == _last_wave:
		return
	_last_wave = wave
	theme_wave = wave
	_apply_theme()
	_rebuild()
	queue_redraw()
	_play_wave_intro(wave)


func _read_wave() -> int:
	var parent := get_parent()
	if parent == null or not ("wave" in parent):
		return 1
	return max(1, int(parent.wave))


func _play_wave_intro(wave: int) -> void:
	var total := wave
	var parent := get_parent()
	if parent != null and "wave_manager" in parent and parent.wave_manager != null:
		total = int(parent.wave_manager.total_waves())
	# 用 has_method 而不是直接调用：舞台与反馈层是两件独立的事，
	# 反馈层被裁掉时舞台也应该照常换色温，不该整块挂掉。
	if Effects.has_method("wave_intro"):
		Effects.wave_intro(wave, total, "")


# ─── 主题 ───

func _apply_theme():
	var band: Dictionary = THEME_BANDS[0]
	for entry in THEME_BANDS:
		if theme_wave >= int(entry["from"]):
			band = entry
	_c_floor = band["floor"]
	_c_line = band["line"]
	_c_accent = band["accent"]


# ─── 几何缓存 ───

func _rebuild():
	# 场地尺寸优先从 Arena 取（单一数据源），无场地时退回视口尺寸。
	# 注意**不能**在这里无条件用视口：那正是「3×3 世界里背景只铺一屏」的根因。
	var arena := Arena.get_active()
	_world_size = arena.world_rect().size if arena != null else _viewport_size

	var w := _world_size.x
	var h := _world_size.y
	var center := Vector2(w * 0.5, h * 0.5)
	_floor = Rect2(-MARGIN, -MARGIN, w + MARGIN * 2.0, h + MARGIN * 2.0)
	_boundary = Rect2(BOUNDARY_INSET, BOUNDARY_INSET, w - BOUNDARY_INSET * 2.0, h - BOUNDARY_INSET * 2.0)

	_grid_minor = PackedVector2Array()
	_grid_major = PackedVector2Array()
	_dots = PackedVector2Array()
	_spokes = PackedVector2Array()
	_ring_radii = []

	var reach_x := w + MARGIN
	var reach_y := h + MARGIN

	# ⚠ PackedVector2Array 是**值类型**（COW）：不能先 `var a = _grid_minor` 再 append，
	# 那样只会改到副本、缓存数组仍然是空的（画面上就是「网格没画出来」）。
	# 所以这里用两个局部数组累积，最后一次性赋回。
	var minor := PackedVector2Array()
	var major := PackedVector2Array()
	var i := 0
	var x := -MARGIN
	while x <= reach_x:
		if i % GRID_MAJOR_EVERY == 0:
			major.append(Vector2(x, -MARGIN))
			major.append(Vector2(x, reach_y))
		else:
			minor.append(Vector2(x, -MARGIN))
			minor.append(Vector2(x, reach_y))
		x += GRID
		i += 1
	i = 0
	var y := -MARGIN
	while y <= reach_y:
		if i % GRID_MAJOR_EVERY == 0:
			major.append(Vector2(-MARGIN, y))
			major.append(Vector2(reach_x, y))
		else:
			minor.append(Vector2(-MARGIN, y))
			minor.append(Vector2(reach_x, y))
		y += GRID
		i += 1
	_grid_minor = minor
	_grid_major = major

	# 交点亮点：只在「主格」交点上打，数量约 24 个，用来在网格里放几个可数的锚点
	var step := GRID * GRID_MAJOR_EVERY
	var mx := 0.0
	while mx <= reach_x:
		var my := 0.0
		while my <= reach_y:
			_dots.append(Vector2(mx, my))
			my += step
		mx += step

	# 环形风格：同心环半径 + 12 条放射短线
	var max_radius := center.length() + MARGIN
	var r := RING_STEP
	while r <= max_radius:
		_ring_radii.append(r)
		r += RING_STEP
	for k in range(12):
		var a := TAU * float(k) / 12.0
		var dir := Vector2(cos(a), sin(a))
		# 虚线：从 40px 起每 26px 画一段 12px 的短线
		var d := 40.0
		while d < max_radius:
			_spokes.append(center + dir * d)
			_spokes.append(center + dir * (d + 12.0))
			d += 26.0

	# 角标：4 个直角折线，用来强化「战场边界」是一个有明确范围的框
	_brackets = PackedVector2Array()
	var inner := BOUNDARY_INSET + 6.0
	var outer_x := w - BOUNDARY_INSET - 6.0
	var outer_y := h - BOUNDARY_INSET - 6.0
	var arm := 52.0
	var corners := [
		[Vector2(inner, inner), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(outer_x, inner), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
		[Vector2(outer_x, outer_y), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)],
		[Vector2(inner, outer_y), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
	]
	for corner in corners:
		var c: Vector2 = corner[0]
		var dx: Vector2 = corner[1]
		var dy: Vector2 = corner[2]
		_brackets.append(c)
		_brackets.append(c + dx * arm)
		_brackets.append(c)
		_brackets.append(c + dy * arm)

	# 中心准星
	_crosshair = PackedVector2Array([
		center + Vector2(-26.0, 0.0), center + Vector2(-9.0, 0.0),
		center + Vector2(9.0, 0.0), center + Vector2(26.0, 0.0),
		center + Vector2(0.0, -26.0), center + Vector2(0.0, -9.0),
		center + Vector2(0.0, 9.0), center + Vector2(0.0, 26.0),
	])

	_build_vignette()


# 暗角：不用着色器，用四条「内边透明 → 外边压暗」的梯形带。
# 相邻两条带在四角自然叠加，角落会比边中更暗 —— 正好是暗角该有的样子。
func _build_vignette():
	_vig_points = []
	_vig_colors = []
	# ⚠ 暗角用**视口**尺寸，不是场地尺寸。它压暗的是「屏幕四条边」，
	# 若按场地铺，3×3 屏的暗角会跑到 3840px 外 —— 玩家在场地中间永远看不到它，
	# 「把注意力收回中心」的意图就彻底失效了。
	var w := _viewport_size.x
	var h := _viewport_size.y
	var clear := Color(_c_floor.r, _c_floor.g, _c_floor.b, 0.0)
	var dark := Color(0.0, 0.0, 0.0, VIGNETTE_ALPHA)
	var o := MARGIN
	var d := MARGIN + VIGNETTE_DEPTH

	_add_vignette_quad(
		PackedVector2Array([
			Vector2(-o, -o), Vector2(w + o, -o),
			Vector2(w + o, d), Vector2(-o, d),
		]),
		PackedColorArray([dark, dark, clear, clear])
	)
	_add_vignette_quad(
		PackedVector2Array([
			Vector2(-o, h - d), Vector2(w + o, h - d),
			Vector2(w + o, h + o), Vector2(-o, h + o),
		]),
		PackedColorArray([clear, clear, dark, dark])
	)
	_add_vignette_quad(
		PackedVector2Array([
			Vector2(-o, -o), Vector2(d, -o),
			Vector2(d, h + o), Vector2(-o, h + o),
		]),
		PackedColorArray([dark, clear, clear, dark])
	)
	_add_vignette_quad(
		PackedVector2Array([
			Vector2(w - d, -o), Vector2(w + o, -o),
			Vector2(w + o, h + o), Vector2(w - d, h + o),
		]),
		PackedColorArray([clear, dark, dark, clear])
	)


func _add_vignette_quad(points: PackedVector2Array, colors: PackedColorArray):
	_vig_points.append(points)
	_vig_colors.append(colors)


# ─── 绘制 ───

func _draw():
	# 1) 地面：把整块纯色虚空换成有色调的「地」
	draw_rect(_floor, _c_floor, true)

	# 2) 地面纹样（移动参照的来源）
	match style:
		"arena":
			_draw_rings()
		"minimal":
			_draw_minimal()
		_:
			_draw_grid()

	# 3) 边界与中心：告诉玩家「战场有多大」、中心在哪
	_draw_boundary()

	# 4) 暗角最后画：连网格一起压暗，注意力才会收到中心
	for i in range(_vig_points.size()):
		draw_polygon(_vig_points[i], _vig_colors[i])


func _draw_grid():
	var minor := Color(_c_line.r, _c_line.g, _c_line.b, grid_minor_alpha)
	var major := Color(_c_line.r, _c_line.g, _c_line.b, 0.30)
	# 整片网格只用两次 draw_multiline —— 不是每条线一次调用，更不是一个点一个节点
	draw_multiline(_grid_minor, minor, 1.0)
	draw_multiline(_grid_major, major, 1.0)
	var dot := Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.34)
	for point: Vector2 in _dots:
		draw_circle(point, 1.9, dot)


func _draw_minimal():
	var dot := Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.30)
	for point: Vector2 in _dots:
		draw_circle(point, 2.2, dot)


func _draw_rings():
	var center := _vec_center()
	for i in range(_ring_radii.size()):
		var radius := _ring_radii[i]
		var is_major := i % 3 == 2
		var alpha := 0.26 if is_major else 0.11
		draw_arc(center, radius, 0.0, TAU, 96,
			Color(_c_line.r, _c_line.g, _c_line.b, alpha), 2.0 if is_major else 1.0)
	draw_multiline(_spokes, Color(_c_line.r, _c_line.g, _c_line.b, 0.12), 1.0)


func _draw_boundary():
	var glow := Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.10)
	var line := Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.42)
	draw_rect(_boundary, glow, false, 10.0)
	draw_rect(_boundary, line, false, 2.0)
	draw_multiline(_brackets, Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.72), 4.0)

	var center := _vec_center()
	draw_arc(center, 52.0, 0.0, TAU, 48, Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.16), 1.5)
	draw_multiline(_crosshair, Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.30), 1.5)
	draw_circle(center, 3.0, Color(_c_accent.r, _c_accent.g, _c_accent.b, 0.45))


func _vec_center() -> Vector2:
	# 场地中心（不是视口中心）：同心环 / 准星讲的是「战场中心在哪」，
	# 而 3×3 屏的战场中心现在在 (1920,1080)，不再是屏幕中点。
	return Vector2(_world_size.x * 0.5, _world_size.y * 0.5)
