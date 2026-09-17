extends SceneTree

# 精灵图集 → 单个单位 PNG（路线 B 的资产管线）
#
# 输入：一张 AI 生成的精灵图集（若干生物排成网格）
# 输出：sprites/units/{name}.png，每个单位一张、已抠底、已按内容裁紧
#
# 为什么不用「按网格等分切片」：
#   ① 生成模型的网格位置不精确，等分会把单位切歪；
#   ② 图上有水印（右下角），等分会把它并进最后一格。
# 改用**连通域**：每个生物是一个独立连通块，取面积最大的 N 个，再按 行/列 排序还原阅读顺序。
# 水印笔画细、面积小，会被自动排除。
#
# 背景处理：生成器声称输出透明背景，实际给的是一层均匀灰。
# 因此这里做「均匀背景去背 + 去灰边（unmatte）」：
#   纯色背景的边缘像素是「前景 × a + 背景 × (1-a)」的混合，
#   只按距离设 alpha 会留下一圈灰晕，必须把背景的贡献减掉。
#
# 用法（图像处理不需要渲染，可以 --headless）：
#   "<godot>" --headless --path . --script res://tools/build_sprite_units.gd -- \
#       --sheet=sprites/raw/xxx.png --names=normal,fast,tank,ranged,healer,boss

const DEFAULT_OUT_DIR := "res://sprites/units"
const MIN_COMPONENT_AREA := 400
# 抠像阈值。背景是**纯色**，所以匹配必须窄。
# ⚠ 第一版用了 26/78 的宽斜坡，结果把「颜色接近中灰」的部分啃成半透明：
# 背景是灰 0.75，而橙色箭头的亮色 (0.95,0.55,0.1) 与它最大通道差只有 0.2 ≈ 51，
# 正好落在 26~78 之间 → alpha 0.48，箭头发虚发淡。
# 单一色背景下，正确的判据是「是不是那个颜色」，不是「离它多远」。
const BG_TOLERANCE_LOW := 10.0    # 距离小于此值 → 完全透明
const BG_TOLERANCE_HIGH := 34.0   # 距离大于此值 → 完全不透明（中间为抗锯齿过渡带）

func _init():
	call_deferred("_run")

func _run():
	var opts := _parse_args()
	var sheet_path := str(opts.get("sheet", ""))
	if sheet_path.is_empty():
		_fail("缺少 --sheet=<图集路径>")
		return
	var names: Array = []
	for item in str(opts.get("names", "")).split(","):
		var n := item.strip_edges()
		if n != "":
			names.append(n)
	if names.is_empty():
		_fail("缺少 --names=<逗号分隔的单位名，按行优先顺序>")
		return
	var out_dir := str(opts.get("outdir", DEFAULT_OUT_DIR))

	var image := _load_image(sheet_path)
	if image == null:
		_fail("读不到图集: %s" % sheet_path)
		return
	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var bg := _detect_background(image)
	print("SPRITE_SHEET %dx%d bg=%s" % [image.get_width(), image.get_height(), str(bg)])
	_build_alpha(image, bg)

	var comps := _components(image)
	print("SPRITE_COMPONENTS 共 %d 个连通域（面积≥%d）" % [comps.size(), MIN_COMPONENT_AREA])
	if comps.size() < names.size():
		_fail("连通域只有 %d 个，少于需要切出的 %d 个单位" % [comps.size(), names.size()])
		return

	# 取面积最大的 N 个（水印/杂点面积小，会落选）
	var by_area: Array = comps.duplicate()
	by_area.sort_custom(func(a, b): return a.area > b.area)
	var picked: Array = by_area.slice(0, names.size())
	# 还原阅读顺序：先按行（y 中心分带），再按列
	picked.sort_custom(func(a, b):
		# lambda 参数无类型 → 成员访问是 Variant，必须显式标注（本项目把该警告当错误）
		var ay: int = a.miny + a.maxy
		var by: int = b.miny + b.maxy
		var ah: int = a.maxy - a.miny
		var bh: int = b.maxy - b.miny
		# 行中心差小于两行高度的一半时视为同一行
		if absi(ay - by) < maxi(ah, bh):
			return a.minx < b.minx
		return ay < by
	)

	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in range(names.size()):
		var comp = picked[i]
		var rect := Rect2i(comp.minx, comp.miny, comp.maxx - comp.minx + 1, comp.maxy - comp.miny + 1)
		var cropped := image.get_region(rect)
		var out_path := "%s/%s.png" % [out_dir, str(names[i])]
		var err := cropped.save_png(out_path)
		if err != OK:
			_fail("写入失败(%d): %s" % [err, out_path])
			return
		print("SPRITE_UNIT %-16s %dx%d  area=%d -> %s" % [
			str(names[i]), rect.size.x, rect.size.y, comp.area, out_path
		])

	print("SPRITE_BUILD_OK 共 %d 个单位" % names.size())
	quit(0)


func _parse_args() -> Dictionary:
	var result: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if not text.begins_with("--"):
			continue
		var body := text.substr(2)
		var eq := body.find("=")
		if eq < 0:
			result[body] = true
		else:
			result[body.substr(0, eq)] = body.substr(eq + 1)
	return result


func _load_image(path: String) -> Image:
	# 用 load_from_file 直接读磁盘，绕开 Godot 的导入系统 ——
	# 图集是原始素材，不必（也不该）先 import 成 Texture2D 再取 Image。
	var absolute := path
	if path.begins_with("res://"):
		absolute = ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return image


func _detect_background(image: Image) -> Color:
	# 取边框环上出现次数最多的量化颜色 —— 比只看一个角更稳
	var counts: Dictionary = {}
	var samples: Array[Vector2i] = []
	var w := image.get_width()
	var h := image.get_height()
	for x in range(0, w, maxi(1, w / 64)):
		samples.append(Vector2i(x, 0))
		samples.append(Vector2i(x, h - 1))
	for y in range(0, h, maxi(1, h / 64)):
		samples.append(Vector2i(0, y))
		samples.append(Vector2i(w - 1, y))
	for p in samples:
		var c := image.get_pixel(p.x, p.y)
		var key := "%d_%d_%d" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]
		counts[key] = int(counts.get(key, 0)) + 1
	var best_key := ""
	var best_count := -1
	for key in counts:
		if int(counts[key]) > best_count:
			best_count = int(counts[key])
			best_key = str(key)
	var parts := best_key.split("_")
	if parts.size() != 3:
		return Color(0, 0, 0)
	return Color(int(parts[0]) / 255.0, int(parts[1]) / 255.0, int(parts[2]) / 255.0)


func _color_distance(a: Color, b: Color) -> float:
	# 各通道最大差，比欧氏距离更贴近「肉眼觉得一样不一样」
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b)) * 255.0


func _build_alpha(image: Image, bg: Color):
	var w := image.get_width()
	var h := image.get_height()
	var span: float = BG_TOLERANCE_HIGH - BG_TOLERANCE_LOW
	for y in range(h):
		for x in range(w):
			var c := image.get_pixel(x, y)
			var d := _color_distance(c, bg)
			if d <= BG_TOLERANCE_LOW:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var a := clampf((d - BG_TOLERANCE_LOW) / span, 0.0, 1.0)
			if a >= 1.0:
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
				continue
			# 去灰边：把背景的贡献从混合像素里减掉，否则边缘会留一圈灰晕
			var out := Color(
				clampf((c.r - bg.r * (1.0 - a)) / a, 0.0, 1.0),
				clampf((c.g - bg.g * (1.0 - a)) / a, 0.0, 1.0),
				clampf((c.b - bg.b * (1.0 - a)) / a, 0.0, 1.0),
				a
			)
			image.set_pixel(x, y, out)


func _components(image: Image) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	var total := w * h
	var solid := PackedByteArray()
	solid.resize(total)
	# alpha 过半即视为前景：边缘半透明像素不参与连通域，避免相邻单位被判成一块
	for i in range(total):
		solid[i] = 1 if image.get_pixel(i % w, i / w).a > 0.5 else 0

	var visited := PackedByteArray()
	visited.resize(total)
	var result: Array = []
	for start in range(total):
		if solid[start] == 0 or visited[start] == 1:
			continue
		visited[start] = 1
		var stack: Array = [start]
		var area := 0
		var minx := w
		var maxx := -1
		var miny := h
		var maxy := -1
		while not stack.is_empty():
			var p = stack.pop_back()
			area += 1
			var px: int = p % w
			var py: int = p / w
			if px < minx: minx = px
			if px > maxx: maxx = px
			if py < miny: miny = py
			if py > maxy: maxy = py
			# 4 邻域。用内联判断而不建 Vector2i 数组，热循环里省下大量分配
			if px + 1 < w:
				var r: int = p + 1
				if solid[r] == 1 and visited[r] == 0:
					visited[r] = 1
					stack.append(r)
			if px - 1 >= 0:
				var l: int = p - 1
				if solid[l] == 1 and visited[l] == 0:
					visited[l] = 1
					stack.append(l)
			if py + 1 < h:
				var dn: int = p + w
				if solid[dn] == 1 and visited[dn] == 0:
					visited[dn] = 1
					stack.append(dn)
			if py - 1 >= 0:
				var up: int = p - w
				if solid[up] == 1 and visited[up] == 0:
					visited[up] = 1
					stack.append(up)
		if area >= MIN_COMPONENT_AREA:
			result.append({"area": area, "minx": minx, "maxx": maxx, "miny": miny, "maxy": maxy})
	return result


func _fail(message: String):
	print("SPRITE_BUILD_FAIL %s" % message)
	push_error(message)
	quit(1)
