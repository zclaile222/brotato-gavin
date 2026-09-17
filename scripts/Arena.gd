class_name Arena
extends Node2D

# Arena.gd — 场地与世界边界的**单一数据源**
#
# ─── 为什么要新建这个类 ───
# 改造前整个项目没有「场地」这个概念，于是有三处各自拿**视口**顶替场地：
#   · 玩家移动钳位（PlayerCore）—— 语义是「场地边界」，用视口 → 玩家被锁在一屏内
#   · 刷怪落点（WaveManager）  —— 语义是「屏幕外一圈」，用视口在固定相机下恰好等价
#   · 子弹出界回收（Bullet / EnemyBullet）—— 语义是「离开视野」，用视口在固定相机下等价
# 相机一开始跟随玩家，后两者（依赖「相机 == 视口」）就会静默失效：
# 刷怪会刷在玩家脸上、已经飞到屏幕外的子弹再也收不回来（全图弹道堆积 → 卡顿）。
# 所以这里把三种边界一次讲清楚，全项目只从这里取，避免「同一份数据两条转换路径」。
#
# ─── 为什么不做 autoload ───
# 项目现有三个 autoload（GameState / Effects / SaveSystem）都是**无状态服务**；
# 场地是**有状态**的（相机当前位置），且只在战斗场景里存在。做成 autoload 的话：
#   ① 主菜单 / 角色选择 / 商店也会带着一份没有意义的场地与相机状态；
#   ② 每局重开（reload_current_scene）还得额外处理它的重置。
# 作为 Main 的子节点则天然随场景创建与销毁。访问方式见 `Arena.get_active()`。
#
# ─── 三种矩形 ───
#   world_rect()        场地矩形 —— 玩家移动的硬边界，也就是「地图有多大」
#   camera_view_rect()  相机当前看到的矩形（约一屏）
#   spawn_margin_rect() camera_view_rect() 外扩 SPAWN_MARGIN，专给刷怪用
#
# ─── 尺寸约定 ───
# 世界是 3×3 屏。**按视口尺寸算，不写死 3840×2160**：玩家窗口可以自由缩放，
# 写死常数的话窗口一变大地图就不再是 3×3 屏了。世界原点也刻意**不居中**——
# 场地矩形与所有游戏逻辑一律从 (0,0) 起算，这样测试里的坐标与线上保持同一套语义，
# 不需要「测试坐标 ↔ 线上坐标」的额外换算。

# 场地 = 3×3 屏（用户确认的方案）。x/y 分开给，将来做「更长/更宽的场地」不必改结构。
const WORLD_SCREENS_X: int = 3
const WORLD_SCREENS_Y: int = 3

# 刷怪外扩距离。取一屏的约 1/4：既保证刷出点确实在可视区之外（玩家看不见凭空出现），
# 又不至于远到敌人要走很久才进画面。
const SPAWN_MARGIN: float = 320.0

# 世界尺寸下界。**这不是防御性代码，是实测需要的**：
# `--script` 冒烟测试模式下根视口是 64×64（project.godot 声明的 1280×720 不生效，
# 见 docs §10.2）。没有这个下界，测试里的世界会塌成 192×64，
# 相机每帧把玩家从测试摆好的位置拖走，一连串看似无关的断言都会红。
# 1280×720 = 一屏，语义是「世界至少容得下一屏」，而不是「世界至少这么大」。
# 相机钳位在场地小于视口时会退化成「居中」（见 clamp_camera_center）。
const FLOOR_SIZE := Vector2(1280.0, 720.0)

# 玩家与场地边缘的间距。原值 20 保留，仅把基准从「视口」换成「场地」。
const PLAYER_MARGIN: float = 20.0

# 场地矩形左上角。**有意让世界从 (0,0) 开始而不是关于原点居中** —— 与项目既有的
# 「坐标即世界坐标」保持一致：改造前场地就是一屏 (0,0)-(1280,720)，单位坐标都在这个
# 区间里；改成居中会同时改变玩家出生点、刷怪点、测试夹具三处语义，收益为零。
const GROUND_ORIGIN := Vector2.ZERO

# 场上活跃实例（第一个 register 的胜出）。用静态变量而不是 get_first_node_in_group()：
# 后者要扫场景树，而这几处边界判定在**每颗子弹每一帧**都会问到。
# 静态变量在类首次加载时初始化，不依赖 autoload 顺序，脚本模式下同样可用。
static var _active: Arena = null

# 场地尺寸发生变化时发出。视口缩放会让世界不再是 3×3 屏（世界尺寸按视口算），
# 战场背景需要据此重建几何缓存 —— 它那份缓存比一帧的绘制贵得多，不能每帧重算。
signal resized

# ─── 运行时状态（由 Main.gd 驱动） ───
var _camera: Camera2D = null
var _viewport_size: Vector2 = FLOOR_SIZE


func _ready() -> void:
	# ⚠ 注册必须**延迟到帧末**，不能在这里直接 register()。
	# 原因：Main.gd 在运行时用 `Arena.new()` 建场地，于是它在场景树里排在
	# Main.tscn 里写死的 ArenaBackground **之后** —— `_ready()` 是按子节点顺序走的，
	# 背景先就绪、拿到的 Arena.get_active() 还是 null，于是按「一屏视口」建了缓存
	# （实测症状：ARENA_BACKGROUND_READY world=1280x720，而场地其实是 3840x2160）。
	# 这不是竞态：脚本模式下 Main 的 _ready 在 SCRIPT 阶段跑，阶段 5（ready）严格更晚，
	# 所以 `call_deferred` 必然排在两个 _ready() 之后，是确定性的。
	# 注册完成后由 _register_now() 去唤醒**已登记但当时还没场地可订阅**的监听者。
	# 注意不能只 `resized.emit()`：那些兄弟节点要连的是**将来**的那个实例，
	# 实测此时 `resized.get_connections()` 是空的，只 emit 自己没人收到。
	call_deferred("_register_now")
	# 连到视口而不是自己轮询：尺寸变化很稀疏（用户拖窗口），
	# 而每帧轮询一次 `world_rect()` 的代价要落在所有调用方身上。
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_on_viewport_size_changed)


func _register_now() -> void:
	tick()
	register(self)
	# 唤醒所有**早于本节点**就绪、当时还没场地可订阅的监听者。
	# 它们是 Main.tscn 里的兄弟节点（ArenaBackground），_ready() 顺序在 Arena 之前，
	# 那时 Arena.get_active() 还是 null，只能先在此登记。
	# 只 emit 自己的 `resized` 是不够的（它们连的是**将来的**那个实例），
	# 实测 `resized.get_connections()` 一直是空的，背景因此一直按一屏建缓存。
	for callback in _deferred_listeners:
		if callback.is_valid():
			callback.call()
	_deferred_listeners.clear()


# 早于场地就绪的监听者回调。静态，因为「有没有场地」本身就是静态信息。
static var _deferred_listeners: Array[Callable] = []


# 订阅「场地尺寸就绪 / 变化」。**静态**，因为「场地是否已就绪」本身就是静态信息，
# 而调用方（ArenaBackground）在自己 _ready() 时很可能还拿不到场地实例。
# 场景里的兄弟节点只用调用这一处，**不需要关心自己排在 Arena 前面还是后面**。
# 判据是 `_active` 而不是 `self`：早到的监听者最先触到的是**先注册**的那个实例。
static func on_ready_geometry(callback: Callable) -> void:
	var active := get_active()
	if active != null:
		# 场地已就绪：连上信号，并立刻补一次通知，调用方不必等下一次尺寸变化
		active.resized.connect(callback)
		callback.call()
	else:
		# 场地还没注册：先登记，等 _register_now() 时机到了再回调一次
		_deferred_listeners.append(callback)


func _exit_tree() -> void:
	unregister(self)


# 视口尺寸变化 → 尺寸缓存失效。世界尺寸是视口的 3 倍，所以两者必然同时变。
func _on_viewport_size_changed() -> void:
	tick()


# ─── 注册 / 查询 ───

# 一个进程里可能有多个实例的**瞬时**窗口（旧的 Main 还在树上、新的已经 add_child）。
# 约定「先注册的胜出」：正在运行的场地不应该被尚未初始化完的新实例顶掉。
# 代价是旧场地销毁后 `_active` 需要重认领，见 unregister()。
static func register(arena: Arena) -> void:
	if _active == null or not is_instance_valid(_active):
		_active = arena


static func unregister(arena: Arena) -> void:
	if _active == arena:
		_active = null


# 当前场地。没有场地时返回 null —— 调用方**必须**自行兜底
# （世界空间特效 / 蓄力敌人等会在无场地场景里跑）。
static func get_active() -> Arena:
	if _active != null and is_instance_valid(_active):
		return _active
	return null


# ─── 尺寸与矩形 ───

# 视口尺寸。测试可能在场地注册**之后**才把 root.size 设回 1280×720，
# 所以这里每帧向上读，不缓存一次性结果。
func _read_viewport_size() -> Vector2:
	var size := get_viewport_rect().size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return FLOOR_SIZE


func world_rect() -> Rect2:
	# 保底 1280×720：视口塌成 64×64 时得到 6×4 屏，但仍不小于一屏活动空间
	var w: float = maxf(_viewport_size.x * float(WORLD_SCREENS_X), FLOOR_SIZE.x)
	var h: float = maxf(_viewport_size.y * float(WORLD_SCREENS_Y), FLOOR_SIZE.y)
	return Rect2(GROUND_ORIGIN, Vector2(w, h))


# 相机当前可视矩形。相机不存在时**保底返回一屏**（而不是零矩形）：
# 调用方拿它做「出界回收」，返回零矩形会把所有东西当成出界。
func camera_view_rect() -> Rect2:
	var size := _camera_view_size()
	if _camera != null and is_instance_valid(_camera) and _camera.is_inside_tree():
		var center := _camera.get_screen_center_position()
		return Rect2(center - size * 0.5, size)
	# 无相机：退化成场地中心的一屏，语义是「看得见中间那一屏」
	var world := world_rect()
	return Rect2(world.get_center() - size * 0.5, size)


func spawn_margin_rect() -> Rect2:
	return camera_view_rect().grow(SPAWN_MARGIN)


func _camera_view_size() -> Vector2:
	var size := _read_viewport_size()
	if _camera != null and is_instance_valid(_camera):
		var zoom := _camera.zoom
		if zoom.x != 0.0 and zoom.y != 0.0:
			return Vector2(size.x / absf(zoom.x), size.y / absf(zoom.y))
	return size


# ─── 边界查询（给子弹 / 敌人用来判「出界」）───

# 相机矩形外扩 margin 后的范围。返回 Rect2.grow() 的语义（可为负尺寸的左/上边）。
# 子弹用 margin=50，与改造前 `超出视口 ±50px 即回收` 的松紧度完全一致。
func visible_bounds(margin: float) -> Rect2:
	return camera_view_rect().grow(margin)


func is_outside_viewport(pos: Vector2, margin: float) -> bool:
	return not visible_bounds(margin).has_point(pos)


# ─── 相机跟随 ───

func setup_camera(camera: Camera2D) -> void:
	_camera = camera
	tick()


# 相机中心钳位：世界比视口大时限制在 [半屏, 世界宽-半屏]，
# 使场地边缘**永远贴着视口边**（不会看到地图外的空白）；
# 世界比视口小时退化为「居中」，而不是产生 min > max 的非法区间。
func clamp_camera_center(desired: Vector2) -> Vector2:
	var view := _camera_view_size()
	var world := world_rect()
	var min_x := world.position.x + view.x * 0.5
	var max_x := world.end.x - view.x * 0.5
	var min_y := world.position.y + view.y * 0.5
	var max_y := world.end.y - view.y * 0.5
	var cx := (min_x + max_x) * 0.5 if max_x < min_x else clampf(desired.x, min_x, max_x)
	var cy := (min_y + max_y) * 0.5 if max_y < min_y else clampf(desired.y, min_y, max_y)
	return Vector2(cx, cy)


func follow(target_position: Vector2) -> void:
	if _camera == null or not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return
	_camera.position = clamp_camera_center(target_position)


# 每帧刷新缓存的视口尺寸。必须在 `follow()` **之前**调用 ——
# 否则窗口尺寸或 root.size 变化的那一帧，相机会按旧尺寸钳位。
func tick() -> void:
	var size := _read_viewport_size()
	if not size.is_equal_approx(_viewport_size):
		_viewport_size = size
		resized.emit()


# ─── 玩家移动边界 ───

func clamp_player_position(pos: Vector2) -> Vector2:
	var world := world_rect()
	return Vector2(
		clampf(pos.x, world.position.x + PLAYER_MARGIN, world.end.x - PLAYER_MARGIN),
		clampf(pos.y, world.position.y + PLAYER_MARGIN, world.end.y - PLAYER_MARGIN)
	)
