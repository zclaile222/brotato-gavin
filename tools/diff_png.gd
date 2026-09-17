extends SceneTree

# 两张 PNG 的**像素级**差异统计 —— 补 md5 的短板
#
# 为什么 md5 不够：本项目 HUD 上有若干 Tween 驱动的动画（提示条、飘字），
# 它们的位置取决于**真实经过的时间**，所以同一份代码跑两次，md5 也不会相同。
# 于是「md5 变了」推不出「我的改动生效了」。
#
# 这个工具给出的是**差异量级**与**差异分布**：
#   - 差异像素占比：噪声级别通常在千分位以下，真实改动会到几个百分点；
#   - 4x3 分区的变化率热图：可以立刻看出改动集中在哪（例如「整屏都有」= 背景生效了，
#     而「只有 HUD 那一条」= 只动到了界面）。
#
# 用法：
#   "<godot_console.exe>" --path . --script res://tools/diff_png.gd \
#       -- --a=<绝对路径1> --b=<绝对路径2> [--t=8]
#
# --t 是「算作不同」的通道差阈值（0-255，默认 8），用来忽略压缩/抗锯齿噪声。

func _init():
	call_deferred("_run")

func _run():
	var opts: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if not text.begins_with("--"):
			continue
		var body := text.substr(2)
		var eq := body.find("=")
		if eq >= 0:
			opts[body.substr(0, eq)] = body.substr(eq + 1)
	var path_a := str(opts.get("a", ""))
	var path_b := str(opts.get("b", ""))
	var threshold := float(opts.get("t", "8"))

	# 顺手把 md5 与字节数打出来：Windows 精简 shell 里没有 head/tail/grep，
	# 也没法方便地取文件大小，一份图要跑三个命令才能凑齐证据。
	for p in [path_a, path_b]:
		if p.is_empty():
			continue
		var bytes := FileAccess.get_file_as_bytes(p)
		print("FILE %s md5=%s size=%d" % [p.get_file(), FileAccess.get_md5(p), bytes.size()])

	# 只验 md5 / 体积时可以只给 --a（比如「改前后 md5 必须不同」这条硬要求）。
	if path_b.is_empty():
		quit(0)
		return

	var img_a: Image = Image.load_from_file(path_a)
	var img_b: Image = Image.load_from_file(path_b)
	if img_a == null or img_b == null:
		print("DIFF_FAIL 读不出图片：%s / %s" % [path_a, path_b])
		quit(1)
		return
	if img_a.get_size() != img_b.get_size():
		print("DIFF_FAIL 尺寸不一致 %s vs %s" % [str(img_a.get_size()), str(img_b.get_size())])
		quit(1)
		return
	# ⚠ 必须统一到 RGBA8：PNG 没有 alpha 通道时 Godot 会解成 RGB8，
	# 那时按 4 字节步长读就会整张图错位（症状是「变化率 100%」这种假结论）。
	img_a.convert(Image.FORMAT_RGBA8)
	img_b.convert(Image.FORMAT_RGBA8)

	var w: int = img_a.get_width()
	var h: int = img_a.get_height()
	var data_a: PackedByteArray = img_a.get_data()
	var data_b: PackedByteArray = img_b.get_data()

	const COLS := 4
	const ROWS := 3
	var region_total := []
	var region_changed := []
	for i in range(COLS * ROWS):
		region_total.append(0)
		region_changed.append(0)

	var changed := 0
	var total := 0
	var sum := 0.0
	var max_diff := 0.0

	for y in range(h):
		var row := (y * ROWS) / h
		for x in range(w):
			var i := (y * w + x) * 4
			var dr := absi(int(data_a[i]) - int(data_b[i])) / 255.0
			var dg := absi(int(data_a[i + 1]) - int(data_b[i + 1])) / 255.0
			var db := absi(int(data_a[i + 2]) - int(data_b[i + 2])) / 255.0
			var d := dr
			if dg > d:
				d = dg
			if db > d:
				d = db
			total += 1
			sum += d
			if d > max_diff:
				max_diff = d
			var region := row * COLS + (x * COLS) / w
			region_total[region] += 1
			if d * 255.0 > threshold:
				changed += 1
				region_changed[region] += 1

	print("DIFF a=%s" % path_a.get_file())
	print("DIFF b=%s" % path_b.get_file())
	print("DIFF 变化像素 %d / %d（%.2f%%）· 平均差 %.4f · 最大差 %.4f · 阈值 %.0f" % [
		changed, total, 100.0 * float(changed) / float(total), sum / float(total), max_diff, threshold
	])
	print("DIFF 分区变化率（%d 列 x %d 行，左上到右下）：" % [COLS, ROWS])
	for r in range(ROWS):
		var line := "DIFF   "
		for c in range(COLS):
			var idx := r * COLS + c
			var pct := 100.0 * float(region_changed[idx]) / float(maxi(1, region_total[idx]))
			line += "%7.2f%%" % pct
		print(line)
	quit(0)
