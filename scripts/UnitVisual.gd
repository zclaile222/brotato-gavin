# UnitVisual.gd — 单位形状语言（程序化路线）
#
# 设计目标：混战中靠**形状**区分单位类型，而不是靠颜色。
# 颜色在视觉噪音里最先糊掉，而且对色盲不友好；形状不会。
#
# 每个单位固定 4 层，**层数不随类型变化**（便于对象池复用，不会增减子节点）：
#   1. Body     —— 主色层。受击闪白 / 燃烧变色 / 状态染色都作用在这一层，
#                  因此它必须保留 Polygon2D 的 color 语义（Enemy/Player 的既有逻辑依赖它）
#   2. BodyInner—— 内层高光：缩小的轮廓 + 低透明度白，制造「有厚度」的层次
#   3. BodyDetail— 特征件：表达行为的记号（枪口 / 十字 / 环 / 冠 / 尖刺）
#   4. BodyOutline— 统一深色闭合描边，让单位从深色背景上「立起来」
#
# 形状词汇刻意保持小（简约优先）：7 种底盘 × 6 种特征件。
# 组合出的辨识度已经够用；再加只会让画面变吵，也让玩家记不住。
#
# 尺寸约定：轮廓一律按**名义半径 16** 生成，实际大小仍由节点的 `scale`
# （来自 ENEMY_TYPES 的 `sc`）决定 —— 这样碰撞体尺寸与视觉尺寸保持同源。
#
# ─── 两条渲染路线 ───
# 有精灵资产（sprites/units/{type}.png）就走精灵，没有就回退到程序化几何。
# 因此**游戏与图鉴板共用这一个入口**，不会出现「板子上好看、进游戏不对」。
# 精灵是 `Body` 的**子节点**：`Body` 仍是可见性/透明度的权威
# （幽灵半透明、对象池空闲判定、测试都在用它），父节点隐藏或变透明时精灵跟着走。

class_name UnitVisual
extends RefCounted

const SPRITE_DIR := "res://sprites/units"
const SPRITE_NODE := "Skin"

# 精灵尺寸补偿。AI 精灵自带粗黑描边，缩到游戏尺度（~30px）后描边占比明显，
# 视觉重量低于同面积的纯色几何 —— 看起来会「小一圈」。
# 这个系数把感知尺寸补回来。**待按实际手感调整**（改这一个常量即可）。
const SPRITE_SIZE_COMPENSATION := 1.22

static var _sprite_cache: Dictionary = {}
static var _metrics_cache: Dictionary = {}

# 接触伤害的宽容系数：碰伤范围比可见身体略大一点，擦身而过才算碰到。
# 原来是固定 35（约等于名义半径 16 的 2.2 倍），玩家会在**明显没碰到**的距离挨打。
const CONTACT_GRACE := 1.25

# 几何按类型缓存：apply() 会在对象池每次取用时被调用，
# 不缓存的话每次重生都要重算一遍点集（纯浪费，且会在混战中放大）。
static var _silhouette_cache: Dictionary = {}
static var _mark_cache: Dictionary = {}

const OUTLINE_WIDTH := 2.0
const OUTLINE_COLOR := Color(0.03, 0.03, 0.06, 0.85)
const INNER_ALPHA := 0.24
const INNER_SHRINK := 0.66
const CIRCLE_SEGMENTS := 18

# 4 个视觉层的节点名。层数固定，便于对象池复用。
const LAYER_BODY := "Body"
const LAYER_INNER := "BodyInner"
const LAYER_DETAIL := "BodyDetail"   # 实际节点名是 BodyDetail0..N（一块一个）
const LAYER_OUTLINE := "BodyOutline"
# 特征件的块数上限。当前词汇里最多的是 ring / spikes（各 8 块）。
const MAX_DETAIL_PIECES := 8

# 底盘词汇：
#   hex    六边形  —— 基准/杂兵
#   tri    细三角  —— 速度型（尖角=快）
#   square 切角方  —— 重装型（棱角=重）
#   circle 圆形    —— 远程/功能型（无方向=后手）
#   diamond 菱形   —— 冲刺型
#   star   星形    —— Boss 家族
#   tree   树形    —— 中立材料树
# 特征件词汇：
#   none / gun 枪口 / cross 十字 / ring 虚线环 / crest 星冠 / spikes 尖刺 / fins 三鳍
const UNIT_SHAPES := {
	"normal":         {"sil": "hex",     "mark": "none"},
	"fast":           {"sil": "tri",     "mark": "none"},
	"tank":           {"sil": "square",  "mark": "none"},
	"ranged":         {"sil": "circle",  "mark": "gun"},
	"exploder":       {"sil": "circle",  "mark": "ring"},
	"healer":         {"sil": "circle",  "mark": "cross"},
	"swarm":          {"sil": "tri",     "mark": "none"},
	"armored":        {"sil": "square",  "mark": "spikes"},
	"ghost":          {"sil": "circle",  "mark": "none"},
	"shooter_spread": {"sil": "circle",  "mark": "fins"},
	"charger":        {"sil": "diamond", "mark": "none"},
	"summoner":       {"sil": "hex",     "mark": "crest"},
	"elite":          {"sil": "hex",     "mark": "spikes"},
	"miniboss":       {"sil": "star",    "mark": "crest"},
	"boss":           {"sil": "star",    "mark": "none"},
	"boss_fire":      {"sil": "star",    "mark": "fins"},
	"boss_frost":     {"sil": "star",    "mark": "cross"},
	"boss_lightning": {"sil": "star",    "mark": "spikes"},
	"tree":           {"sil": "tree",    "mark": "none"},
	"loot_alien":     {"sil": "circle",  "mark": "crest"},
	# 玩家用八边形 + 内环：敌人里没有任何一个是「圆润多边形」，
	# 只靠颜色区分玩家与 normal（都是六边形）在混战里不够 —— 形状必须独占。
	"player":         {"sil": "octagon", "mark": "none"},
}

# 底盘半径微调。默认 16 与改造前那个 -16..16 的方块一致，
# **实际大小仍以 ENEMY_TYPES 的 `sc` 为主**（节点 scale），这里只做「让类别读得出来」的微调。
const SILHOUETTE_TUNING := {
	"fast": {"radius": 15.0},
	"tank": {"radius": 18.0},
	"boss": {"radius": 20.0},
	"boss_fire": {"radius": 20.0},
	"boss_frost": {"radius": 20.0},
	"boss_lightning": {"radius": 20.0},
	"miniboss": {"radius": 19.0},
}

# 特征件的固定配色（不随状态色变化，否则状态反馈会把它一起冲掉）。
# ⚠ 必须是**高亮**色，不能用深色：特征件里有相当一部分是戳到轮廓之外的
# （枪口 / 警示环 / 尖刺），深色记号落在深色背景上等于没画。
# v1 用 Color(0.06,0.07,0.11) 时，画面上只有「落在身体内部」的记号能看见，
# 一度让我以为是多块渲染的锅，连查了两轮 API。
const DETAIL_COLOR := Color(0.93, 0.95, 1.0, 0.82)


static func shape_for(type_name: String) -> Dictionary:
	return UNIT_SHAPES.get(type_name, UNIT_SHAPES["normal"])


static func radius_for(type_name: String) -> float:
	var tuning: Dictionary = SILHOUETTE_TUNING.get(type_name, {})
	return float(tuning.get("radius", 16.0))


static func silhouette_points(type_name: String) -> PackedVector2Array:
	if _silhouette_cache.has(type_name):
		return _silhouette_cache[type_name]
	var points := _build_silhouette(type_name)
	_silhouette_cache[type_name] = points
	return points


static func _build_silhouette(type_name: String) -> PackedVector2Array:
	var shape := shape_for(type_name)
	return build_silhouette(str(shape.get("sil", "hex")), radius_for(type_name))


# 按**显式规格**生成轮廓。单位走类型名那一条；角色徽章等其它地方直接调这里 ——
# 形状语言只保留一份实现，避免菜单里另画一套渐渐跑偏。
static func build_silhouette(sil: String, r: float) -> PackedVector2Array:
	match sil:
		"tri":
			return _triangle(r)
		"square":
			return _cut_square(r)
		"circle":
			return _regular(CIRCLE_SEGMENTS, r, -PI * 0.5)
		"diamond":
			return _diamond(r)
		"star":
			return _star(8, r, r * 0.52)
		"tree":
			return _tree(r)
		"octagon":
			return _regular(8, r, PI / 8.0)
		_:
			return _regular(6, r, -PI * 0.5)


# 唯一入口：把单位视觉挂到 host 上。body 是场景里那一个 Polygon2D。
# 幂等：重复调用只更新内容，不重复创建节点 —— 对象池反复 setup 时依赖这一点。
static func apply(host: Node2D, body: Polygon2D, type_name: String) -> void:
	if host == null or body == null or not is_instance_valid(host):
		return
	var skin := _ensure_sprite(body)
	var texture = sprite_texture(type_name)
	if texture != null:
		_apply_sprite(host, body, skin, texture, type_name)
	else:
		_apply_procedural(host, body, skin, type_name)


# 该类型是否有精灵资产。图鉴板用它区分「真的走了精灵」与「回退到几何」。
static func has_sprite(type_name: String) -> bool:
	return sprite_texture(type_name) != null


static func sprite_texture(type_name: String):
	if _sprite_cache.has(type_name):
		return _sprite_cache[type_name]
	var texture = null
	var path := "%s/%s.png" % [SPRITE_DIR, type_name]
	if ResourceLoader.exists(path):
		texture = load(path)
	_sprite_cache[type_name] = texture
	return texture


# 「这个单位看起来有多大」——用**等面积圆**的半径表示，局部单位（未乘节点 sc）。
#
# 碰撞体尺寸必须由它推导，不能沿用场景里写死的半径：换成精灵后视觉尺寸是随贴图算出来的，
# 固定半径会立刻和显示范围脱节（症状：打不中 / 没碰到却挨打）。
static func visual_radius(type_name: String) -> float:
	var texture = sprite_texture(type_name)
	if texture == null:
		return _polygon_equivalent_radius(type_name)
	var metrics := _sprite_metrics(type_name, texture)
	var linear: float = SPRITE_SIZE_COMPENSATION * (2.0 * radius_for(type_name)) / sqrt(metrics.w * metrics.h)
	return sqrt(maxf(1.0, metrics.opaque * linear * linear) / PI)


static func _sprite_metrics(type_name: String, texture) -> Dictionary:
	if _metrics_cache.has(type_name):
		return _metrics_cache[type_name]
	var w: int = texture.get_width()
	var h: int = texture.get_height()
	var opaque := 0
	var image: Image = texture.get_image()
	if image != null:
		# 隔点采样：只用来推碰撞半径，精度绰绰有余，但比逐像素快一个数量级
		var stride := 3
		for y in range(0, h, stride):
			for x in range(0, w, stride):
				if image.get_pixel(x, y).a > 0.5:
					opaque += 1
		opaque *= stride * stride
	else:
		opaque = w * h
	var result := {"w": float(w), "h": float(h), "opaque": float(opaque)}
	_metrics_cache[type_name] = result
	return result


static func _polygon_equivalent_radius(type_name: String) -> float:
	var points := silhouette_points(type_name)
	if points.size() < 3:
		return radius_for(type_name)
	# 鞋带公式求多边形面积 → 等面积圆半径
	var doubled := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		doubled += a.x * b.y - b.x * a.y
	return sqrt(maxf(1.0, absf(doubled) * 0.5) / PI)


# ─── 路线 B：精灵 ───
static func _apply_sprite(host: Node2D, body: Polygon2D, skin: Sprite2D, texture, type_name: String) -> void:
	# 多边形清空但节点保留：Body 仍是可见性与透明度的权威，
	# 而 skin 是它的子节点，于是 `Body.visible` / `modulate` / `self_modulate`
	# 这些既有机制（幽灵半透明、对象池空闲判定、测试断言）全部照旧生效。
	body.polygon = PackedVector2Array()
	skin.texture = texture
	# 归一化到与程序化轮廓**同等的占地**：包围盒面积的几何平均 = 2r。
	# 用面积而不是最长边 —— 按最长边会把细长精灵压得又小又弱。
	var w_px: float = maxf(1.0, float(texture.get_width()))
	var h_px: float = maxf(1.0, float(texture.get_height()))
	skin.scale = Vector2.ONE * (SPRITE_SIZE_COMPENSATION * (2.0 * radius_for(type_name)) / sqrt(w_px * h_px))
	skin.visible = true
	_hide_procedural_layers(host)


# ─── 路线 A：程序化几何 ───
static func _apply_procedural(host: Node2D, body: Polygon2D, skin: Sprite2D, type_name: String) -> void:
	skin.visible = false
	draw_procedural_layers(host, body, silhouette_points(type_name), mark_pieces(type_name))


# 用显式规格生成程序化视觉（永不走精灵）。
# 角色徽章等地方直接调它 —— 形状语言只有这一份实现，菜单里不会再画一套渐渐跑偏的。
static func apply_shape(host: Node2D, body: Polygon2D, silhouette: String, mark: String, radius: float) -> void:
	if host == null or body == null or not is_instance_valid(host):
		return
	# 同一节点可能曾作为单位用过，留着一个精灵皮肤就先收起来
	var skin = body.get_node_or_null(SPRITE_NODE)
	if skin != null and skin is Sprite2D:
		skin.visible = false
	draw_procedural_layers(host, body, build_silhouette(silhouette, radius), build_marks(mark, radius))


# 把轮廓 + 内层高光 + 特征件 + 描边画到 host 上。程序化的两条入口共用这一段，
# 保证「单位」与「徽章」的分层与描边规则完全一致。
static func draw_procedural_layers(host: Node2D, body: Polygon2D, points: PackedVector2Array, pieces: Array) -> void:
	body.polygon = points

	var inner := _ensure_layer(host, body, LAYER_INNER)
	var outline := _ensure_outline(host, body)
	# 可能刚从精灵路线切回来，必须显式恢复可见
	inner.visible = true
	outline.visible = true

	# 内层高光：轮廓按中心收缩
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= max(1.0, float(points.size()))
	var inner_points := PackedVector2Array()
	for p in points:
		inner_points.append(center + (p - center) * INNER_SHRINK)
	inner.polygon = inner_points
	inner.color = Color(1, 1, 1, INNER_ALPHA)

	# 特征件：**每块一个节点**。
	# 走过的两条弯路记在这里，别再试第三次：
	#   ① 把互不相连的块拼进同一个 Polygon2D 的 `polygon`：会被当成一个整体三角化，画不出来；
	#   ② 改用 `Polygon2D.polygons`（下标分块）：几何数据正确（探针确认 8 块 32 点都在），
	#      但实际渲染只出来一部分（画在轮廓内部的块可见、外侧的块不出现），行为不可预期。
	# 结论：多块渲染不值得依赖，改成一块一个 Polygon2D —— 行为确定，代价只是节点数。
	_apply_detail_slots(host, body, pieces)

	# 描边：Line2D 画在 host 的局部空间，会被 host.scale 一起缩放。
	# 若直接用固定宽度，sc=0.5 的 swarm 描边会细到 1px 而看不见 —— 所以按 scale 反向补偿，
	# 让描边的**屏幕宽度恒定**。
	var host_scale: float = max(0.05, absf(host.scale.x))
	outline.points = _closed(points)
	outline.width = OUTLINE_WIDTH / host_scale
	outline.default_color = OUTLINE_COLOR


# 特征件：返回单个合并多边形（不连通的部件用多个小方块拼在同一组点里，
# 多边形之间用零面积连接即可 —— 对纯色装饰来说视觉上无差别）
# 特征件槽位：一块一个节点。按需创建（没有特征件的类型不会多出任何节点），
# 多余槽位只隐藏不销毁 —— 对象池把一个单位从 armored 复用成 normal 时依赖这一点。
static func _apply_detail_slots(host: Node2D, body: Polygon2D, pieces: Array):
	var count: int = min(pieces.size(), MAX_DETAIL_PIECES)
	if pieces.size() > MAX_DETAIL_PIECES:
		push_warning("特征件块数 %d 超过上限 %d，多余的已丢弃" % [pieces.size(), MAX_DETAIL_PIECES])
	for i in range(MAX_DETAIL_PIECES):
		var slot := _ensure_detail_slot(host, body, i)
		if i < count:
			slot.polygon = pieces[i]
			slot.color = DETAIL_COLOR
			slot.visible = true
		else:
			slot.visible = false


static func _ensure_detail_slot(host: Node2D, body: Polygon2D, index: int) -> Polygon2D:
	var slot_name := "%s%d" % [LAYER_DETAIL, index]
	var existing = host.get_node_or_null(slot_name)
	if existing != null and existing is Polygon2D:
		return existing
	var slot := Polygon2D.new()
	slot.name = slot_name
	host.add_child(slot)
	slot.z_index = body.z_index + 2
	return slot


# 特征件：每个「块」是一个独立多边形
static func mark_pieces(type_name: String) -> Array:
	if _mark_cache.has(type_name):
		return _mark_cache[type_name]
	var result := _build_marks(type_name)
	_mark_cache[type_name] = result
	return result


static func _build_marks(type_name: String) -> Array:
	var shape := shape_for(type_name)
	return build_marks(str(shape.get("mark", "none")), radius_for(type_name))


static func build_marks(mark: String, r: float) -> Array:
	match mark:
		# 特征件尺寸刻意偏大：v1 的教训是「按 0.2r 做的记号在图鉴板上完全看不见」，
		# 而看不见的特征件等于没有 —— 玩家不会为了一个像素去记类型。
		"gun":
			return [_quad(Vector2(r * 0.80, -r * 0.34), Vector2(r * 1.55, r * 0.34))]
		"cross":
			return [
				_quad(Vector2(-r * 0.24, -r * 0.66), Vector2(r * 0.24, r * 0.66)),
				_quad(Vector2(-r * 0.66, -r * 0.24), Vector2(r * 0.66, r * 0.24)),
			]
		"ring":
			return _dashed_ring(r * 1.34, r * 0.22, 8)
		"crest":
			return _crest(r)
		"spikes":
			return _spikes(r * 1.26, r * 0.30, 8)
		"fins":
			return _fins(r)
		_:
			return []


# ─── 几何工具 ───

static func _regular(sides: int, r: float, rotation: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := rotation + TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func _star(points: int, r_out: float, r_in: float, rotation: float = -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points * 2):
		var a := rotation + PI * float(i) / float(points)
		var rad := r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a), sin(a)) * rad)
	return pts


static func _triangle(r: float) -> PackedVector2Array:
	# 朝 +X 的细三角：尖角指向移动方向 = 「快」
	return PackedVector2Array([
		Vector2(r * 1.30, 0.0),
		Vector2(-r * 0.78, -r * 0.92),
		Vector2(-r * 0.78, r * 0.92),
	])


static func _cut_square(r: float) -> PackedVector2Array:
	# 切角要小：0.32r 的切角看起来是圆角矩形（像糖果），读不出「重装」
	var c := r * 0.22
	return PackedVector2Array([
		Vector2(-r + c, -r), Vector2(r - c, -r), Vector2(r, -r + c),
		Vector2(r, r - c), Vector2(r - c, r), Vector2(-r + c, r),
		Vector2(-r, r - c), Vector2(-r, -r + c),
	])


static func _diamond(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 1.25, 0.0), Vector2(0.0, -r * 0.86),
		Vector2(-r * 4.0, 0.0), Vector2(0.0, r * 0.86),
	])


static func _tree(r: float) -> PackedVector2Array:
	# 树：向上收窄的三角冠 + 短干
	return PackedVector2Array([
		Vector2(-r * 0.86, r), Vector2(r * 0.86, r),
		Vector2(r * 0.56, r * 0.34), Vector2(r * 0.82, r * 0.34),
		Vector2(0.0, -r * 1.12), Vector2(-r * 0.82, r * 0.34),
		Vector2(-r * 0.56, r * 0.34),
	])


static func _quad(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(b.x, b.y), Vector2(a.x, b.y),
	])


static func _dashed_ring(r: float, dash: float, count: int) -> Array:
	var pieces: Array = []
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var dir := Vector2(cos(a), sin(a))
		var tang := Vector2(-dir.y, dir.x)
		var c := dir * r
		pieces.append(PackedVector2Array([
			c - tang * dash - dir * dash * 0.6,
			c + tang * dash - dir * dash * 0.6,
			c + tang * dash + dir * dash * 0.6,
			c - tang * dash + dir * dash * 0.6,
		]))
	return pieces


static func _spikes(r: float, spike: float, count: int) -> Array:
	# 尖刺从 r*0.72 起、伸到约 1.5r —— 必须**戳出轮廓之外**才看得见
	var pieces: Array = []
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var dir := Vector2(cos(a), sin(a))
		var tang := Vector2(-dir.y, dir.x)
		pieces.append(PackedVector2Array([
			dir * (r * 0.72) + tang * spike,
			dir * (r * 0.72) - tang * spike,
			dir * (r + spike * 1.6),
		]))
	return pieces


static func _crest(r: float) -> Array:
	# 顶部双尖星冠
	return [
		PackedVector2Array([
			Vector2(-r * 0.54, -r * 0.80), Vector2(-r * 0.26, -r * 1.52), Vector2(-r * 0.02, -r * 0.80),
		]),
		PackedVector2Array([
			Vector2(r * 0.02, -r * 0.80), Vector2(r * 0.26, -r * 1.52), Vector2(r * 0.54, -r * 0.80),
		]),
	]


static func _fins(r: float) -> Array:
	# 三向鳍：前 + 左右，表示「同时打多个方向」
	var pieces: Array = []
	for a in [0.0, 2.2, -2.2]:
		var dir := Vector2(cos(a), sin(a))
		var tang := Vector2(-dir.y, dir.x)
		pieces.append(PackedVector2Array([
			dir * (r * 0.60) + tang * r * 0.26,
			dir * (r * 0.60) - tang * r * 0.26,
			dir * (r * 1.62),
		]))
	return pieces


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var pts := PackedVector2Array(points)
	if pts.size() > 0:
		pts.append(pts[0])
	return pts


# ─── 层管理 ───

# 精灵是 Body 的子节点，不是 host 的 —— 这样 Body 的 visible / modulate
# 会自动作用到精灵上，无需额外同步代码。
static func _ensure_sprite(body: Polygon2D) -> Sprite2D:
	var existing = body.get_node_or_null(SPRITE_NODE)
	if existing != null and existing is Sprite2D:
		return existing
	var skin := Sprite2D.new()
	skin.name = SPRITE_NODE
	body.add_child(skin)
	return skin


# 走精灵路线时收起程序化那几层。只隐藏不销毁 —— 对象池可能把同一个节点
# 复用成「有精灵的类型」再复用成「没有精灵的类型」，那时还要用回来。
static func _hide_procedural_layers(host: Node2D):
	for child in host.get_children():
		if child == null:
			continue
		if child.name == LAYER_INNER or str(child.name).begins_with(LAYER_DETAIL) or child.name == LAYER_OUTLINE:
			child.visible = false


static func _ensure_layer(host: Node2D, body: Polygon2D, layer_name: String) -> Polygon2D:
	# ⚠ 必须在 **host** 下查找：层是挂在 host 上的（与 Body 同级），
	# 若在 body 下查找就永远找不到已存在的层，于是每次 apply() 都新建一层 ——
	# 对象池每次复用敌人都会多留下 2 个孤儿节点。
	var existing = host.get_node_or_null(layer_name)
	if existing != null and existing is Polygon2D:
		return existing
	var layer := Polygon2D.new()
	layer.name = layer_name
	# 与 Body 同级挂在 host 上：Body 自身可能带 scale，子节点会跟着缩放两次
	host.add_child(layer)
	# ⚠ 层级必须压在 Body **之上**。v1 把内层与特征件放在 z_index - 1（Body 之下），
	# 结果两者被完全不透明的主色层挡住 —— 图上看就是「特征件没实现」，
	# 实际是画了但被盖住了。
	match layer_name:
		LAYER_INNER:
			layer.z_index = body.z_index + 1
		LAYER_DETAIL:
			layer.z_index = body.z_index + 2
		_:
			layer.z_index = body.z_index
	return layer


static func _ensure_outline(host: Node2D, body: Polygon2D) -> Line2D:
	var existing = host.get_node_or_null(LAYER_OUTLINE)
	if existing != null and existing is Line2D:
		return existing
	var outline := Line2D.new()
	outline.name = LAYER_OUTLINE
	outline.closed = false
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	host.add_child(outline)
	# 描边在最上：否则特征件会盖住轮廓线，小单位又糊成一团
	outline.z_index = body.z_index + 3
	return outline
