# VisualBench.gd — 单位视觉图鉴板
#
# 作用：把全部单位（20 种敌人 + 玩家）在**同一机位、同一尺寸、同一背景**下排成一张图，
# 用来做视觉对比与回归。没有它，「改了形状语言」只能靠进游戏里碰运气看。
#
# 关键：**不实例化 Enemy.tscn**。敌人场景带碰撞体、AI、分离力，摆成一排会互相推挤、
# 还会自己动。这里只复刻「视觉」那一层，几何与尺寸都走 UnitVisual 的同一条代码路径，
# 所以看到的就是游戏里的样子。
#
# 用法（经 tools/capture_scene.gd 调用，参数跟在 -- 之后，两边读同一份 cmdline）：
#   --mode=procedural   程序化几何（默认）
#   --mode=sprite        精灵图（资源缺失时画占位并明确标注）
#   --mode=both          同一张图里上下两栏并排对比

extends Node2D

const COLS := 7
const CELL_W := 170.0
const ORIGIN := Vector2(45.0, 92.0)

const LABEL_COLOR := Color(0.72, 0.76, 0.86)
const TITLE_COLOR := Color(0.94, 0.96, 1.0)
const FRAME_COLOR := Color(0.22, 0.25, 0.34, 0.55)

# 玩家放最后，敌人按 ENEMY_TYPES 的声明顺序
const PLAYER_ENTRY := "player"

# --mode=both 时的默认对比集合：这几个已有精灵资产（见 tools/build_sprite_units.gd）
const COMPARISON_TYPES := ["normal", "fast", "tank", "ranged", "healer", "boss"]
const ROW_LABELS := ["路线 A · 程序化几何", "路线 B · 精灵图"]

var mode := "procedural"
var zoom := 1.0
var enemy_types: Dictionary = {}
var _unit_scale: Dictionary = {}
var _only_types: Array = []


func _ready():
	_parse_args()
	enemy_types = _load_enemy_types()
	if enemy_types.is_empty():
		push_error("图鉴板：取不到 Enemy.ENEMY_TYPES，无法确定单位尺寸与配色")
		return
	_unit_scale = _build_scale_table()
	_build_board()


func _parse_args():
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--mode="):
			mode = text.substr("--mode=".length())
		elif text.begins_with("--zoom="):
			# 放大用：小单位的特征件在 1× 下看不清，判断「记号有没有生效」必须放大看
			zoom = maxf(0.1, float(text.substr("--zoom=".length())))
		elif text.begins_with("--types="):
			# 只看指定类型（逗号分隔），便于把少数单位放大细看
			for item in text.substr("--types=".length()).split(","):
				var name := item.strip_edges()
				if name != "":
					_only_types.append(name)


# 用运行时 load 而不是 const preload：Enemy.gd 引用了 GameState 自动加载，
# 解析期拉它会在自动加载注册前编译失败（这个坑见 docs §五）。
func _load_enemy_types() -> Dictionary:
	var script = load("res://scripts/Enemy.gd")
	if script == null:
		return {}
	return script.ENEMY_TYPES


func _build_scale_table() -> Dictionary:
	# 尺寸与游戏同源：游戏里 scale = Vector2(d.sc, d.sc)，Boss 家族用 2.0–2.6 之间
	var table: Dictionary = {}
	for type_name in _unit_order():
		if type_name == PLAYER_ENTRY:
			table[type_name] = 1.6
			continue
		var row: Dictionary = enemy_types.get(type_name, {})
		table[type_name] = float(row.get("sc", 1.0))
	return table


func _unit_order() -> Array:
	var all: Array = []
	# ENEMY_TYPES 的声明顺序即展示顺序
	for type_name in enemy_types:
		all.append(str(type_name))
	all.append(PLAYER_ENTRY)
	if _only_types.is_empty():
		# 对比模式默认只用「已有精灵资产」的少数类型，否则对不齐
		if mode == "both":
			return COMPARISON_TYPES.duplicate()
		return all
	var filtered: Array = []
	for wanted in _only_types:
		if str(wanted) in all:
			filtered.append(str(wanted))
	if filtered.is_empty():
		push_warning("--types 里的名字一个都不认识，回退为全部单位")
		return all
	return filtered


func _build_board():
	var order := _unit_order()
	# 标题
	var title := Label.new()
	title.text = "单位视觉图鉴板  ·  模式: %s" % mode
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(ORIGIN.x - 8.0, 34.0)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "同一机位 / 同一背景 / 尺寸取自 ENEMY_TYPES.sc —— 与游戏内一致"
	subtitle.add_theme_color_override("font_color", LABEL_COLOR)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.position = Vector2(ORIGIN.x - 6.0, 62.0)
	add_child(subtitle)

	# 列数随单位数收缩：只看少数单位时格子自动变宽，方便放大细看
	var cols: int = min(COLS, max(1, order.size()))
	var cell_w: float = 1280.0 / float(cols)

	if mode == "both":
		# 上下两栏：同一批单位、同一机位、同一尺寸，只有渲染方式不同 —— 对比才成立
		var base_y := 120.0
		for row_index in range(2):
			var render_mode := "procedural" if row_index == 0 else "sprite"
			var row_label := Label.new()
			row_label.text = ROW_LABELS[row_index]
			row_label.add_theme_color_override("font_color", TITLE_COLOR)
			row_label.add_theme_font_size_override("font_size", 15)
			row_label.position = Vector2(20.0, base_y + float(row_index) * 300.0 - 46.0)
			add_child(row_label)
			for i in range(order.size()):
				var type_name := str(order[i])
				var cx := float(i) * cell_w + cell_w * 0.5
				var cy := base_y + float(row_index) * 300.0 + 70.0
				_draw_cell(Vector2(cx, cy), type_name, cell_w, render_mode)
		return

	for i in range(order.size()):
		var type_name := str(order[i])
		var col := i % cols
		var row := i / cols
		var cx := float(col) * cell_w + cell_w * 0.5
		var cy := ORIGIN.y + float(row) * 230.0 + 70.0
		_draw_cell(Vector2(cx, cy), type_name, cell_w, mode)


func _draw_cell(center: Vector2, type_name: String, cell_w: float, render_mode: String):
	# 单元格细框：帮助判断「构图是否匀」，也避免看成一堆孤立色块
	var half := cell_w * 0.5
	var frame := Line2D.new()
	frame.points = PackedVector2Array([
		center + Vector2(-half + 8.0, -94.0),
		center + Vector2(half - 8.0, -94.0),
		center + Vector2(half - 8.0, 74.0),
		center + Vector2(-half + 8.0, 74.0),
		center + Vector2(-half + 8.0, -94.0),
	])
	frame.width = 1.0
	frame.default_color = FRAME_COLOR
	add_child(frame)

	# 视觉宿主：与游戏一致 —— 父节点持 scale，Body 多边形按名义半径生成
	var host := Node2D.new()
	host.position = center
	host.scale = Vector2.ONE * float(_unit_scale.get(type_name, 1.0)) * zoom
	add_child(host)

	var body := Polygon2D.new()
	body.name = "Body"
	body.color = _base_color(type_name)
	host.add_child(body)

	# 两条路线都走 UnitVisual 的同一个入口 —— 与游戏完全同一条代码路径，
	# 板上看到的就是游戏里的样子（不会出现「板上好看、进游戏不对」）
	UnitVisual.apply(host, body, type_name)
	var fell_back: bool = render_mode == "sprite" and not UnitVisual.has_sprite(type_name)

	var label := Label.new()
	label.text = type_name
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.add_theme_font_size_override("font_size", 13)
	label.position = center + Vector2(-half + 10.0, 80.0)
	add_child(label)

	var meta := Label.new()
	meta.text = "r=%.0f ×%.2f" % [UnitVisual.radius_for(type_name), float(_unit_scale.get(type_name, 1.0))]
	if not is_equal_approx(zoom, 1.0):
		meta.text += "  zoom ×%.1f" % zoom
	if fell_back:
		meta.text += "  ⚠缺精灵·已回退几何"
		meta.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
	else:
		meta.add_theme_color_override("font_color", Color(0.48, 0.52, 0.62))
	meta.add_theme_font_size_override("font_size", 11)
	meta.position = center + Vector2(-half + 10.0, 96.0)
	add_child(meta)


func _base_color(type_name: String) -> Color:
	if type_name == PLAYER_ENTRY:
		return Color(0.20, 0.85, 0.30, 1.0)
	var row: Dictionary = enemy_types.get(type_name, {})
	var color = row.get("color")
	if color is Color:
		return color
	return Color(0.9, 0.9, 0.9)


# 精灵的加载 / 归一化 / 缺资产回退已全部收进 UnitVisual.apply()，
# 这里不再自己实现一份 —— 否则图鉴板与游戏会各走一条路径，迟早不一致。
