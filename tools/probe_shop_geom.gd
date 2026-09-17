extends SceneTree

# 商店布局实际几何量测 —— 为消除重叠提供依据
#
# ⚠️ 关于视口尺寸：`--headless` 下视口只有 64×64。
#   · `root.size = ...` **被忽略**（实测仍然 (64,64)）；
#   · `root.content_scale_size` 在 `--script` 模式下也**不生效**。
# 视口 64×64 时面板高度会被 `_sync_dynamic_layout()` 的屏幕约束夹到 44，
# 于是所有内容都"排在面板外"，看起来像产品缺陷，其实是探针环境的假象。
# 正解：直接给 `root` 挂一个子 Viewport，用它的 `size` 当作逻辑分辨率 ——
# 下面所有几何都基于 `$ProbeViewport` 取，不再用 root 的 64×64。
const VIEW_SIZE := Vector2i(1280, 720)

var shop = null
var main = null
var probe_viewport: SubViewport = null
var frames := 0

func _initialize() -> void:
	probe_viewport = SubViewport.new()
	probe_viewport.name = "ProbeViewport"
	probe_viewport.size = VIEW_SIZE
	probe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(probe_viewport)

	var p = load("res://scenes/Main.tscn")
	main = p.instantiate()
	probe_viewport.add_child(main)
	# ⚠️ 不要给 SubViewport 里的场景设 current_scene：
	# set_current_scene 要求场景的父节点**必须是 root**，否则报
	# `Condition "p_scene && p_scene->get_parent() != root" is true` 并静默失败。
	# 本探针只测布局几何，不依赖 current_scene，所以干脆不设。

func _process(_delta: float) -> bool:
	frames += 1
	# Main._ready() 是在 _initialize() 的 add_child 之后、下一帧才跑的，
	# 而 shop 是在 Main._ready() 里才 instantiate 的 —— 首帧读必然是 nil。
	if shop == null:
		if main != null:
			shop = main.get("shop")
		if shop == null:
			if frames > 30:
				print("SHOP_GEOM_FAIL: 30 帧后仍拿不到 shop（Main._ready 里没建？）")
				quit(1)
				return true
			return false
	if frames == 10:
		print("shop 已就绪（frames=%d）" % frames)
		var player = main.get("player")
		if player != null and player.has_method("equip_or_combine_weapon"):
			player.equip_or_combine_weapon("pistol", 3)
		shop.open(3, 500, 0, player)
		return false
	if frames < 20:
		return false
	if frames > 20:
		return true
	_report()
	return true

func _report() -> void:
	print("=== 商店实际几何 ===")
	# 前置自检：视口如果不是 1280×720，下面所有"越界"结论都不成立。
	var vr: Vector2 = probe_viewport.get_visible_rect().size
	print("可见视口=%s（必须是 1280x720，否则本探针结论无效）" % str(vr))
	if vr.x < 1200.0 or vr.y < 700.0:
		print("SHOP_GEOM_FAIL: 视口 %s 不是 1280x720，结论不可用" % str(vr))
		quit(1)
		return
	var panel = shop.get_node_or_null("Panel")
	if panel == null:
		print("SHOP_GEOM_FAIL: 找不到 Panel")
		quit(1)
		return
	# ⚠️ 坐标系说明（踩过两次坑）：
	#   · **不要用 global_position**：`Shop` 是 CanvasLayer 挂在 `Main`（Node2D，位于 (30,30)）
	#     之下，所有后代继承恒定 (+30,+30) 位移。实测 Title.global=(60,45) 而 panel.global=(40,30)，
	#     拿全局坐标比面板尺寸 → 全部"溢出"，纯属坐标系混用。
	#   · **也不要拿 `panel.position` 当期初**：面板自身的 position 是它相对 CanvasLayer 的
	#     位置（(40,30)），而子节点的 position 是**相对面板**的（Title 是 (20,15)）。
	#     两者起点不同，直接用 panel.position 当矩形原点同样会整体偏 (40,30)。
	# 正解：子节点矩形以其**父节点为原点**构造；面板包含判据用 (0,0,panel.size)。
	var child_origin := Vector2.ZERO
	var panel_rect = Rect2(child_origin, panel.size)
	print("Panel      size=%s（子节点坐标系的原点；面板自身 position=%s 是相对 CanvasLayer 的）" % [
		str(panel.size), str(panel.position)])
	var names = ["Title", "GoldLabel", "ItemRow", "ButtonRow", "UpgradeScroll", "SellScroll"]
	for n in names:
		var c = panel.get_node_or_null(n)
		if c == null:
			print("%-14s (缺失)" % n)
			continue
		var r = Rect2(c.position, c.size)
		print("%-14s pos=(%4d,%4d) size=(%4d,%4d)  底=%4d" % [
			n, int(r.position.x), int(r.position.y),
			int(r.size.x), int(r.size.y), int(r.position.y + r.size.y)])
	# ItemRow 内部卡片的真实高度
	var item_row = panel.get_node_or_null("ItemRow")
	if item_row == null:
		print("SHOP_GEOM_FAIL: ItemRow 不存在")
		quit(1)
		return
	if item_row.get_child_count() > 0:
		var c0 = item_row.get_child(0)
		print("")
		print("ItemRow 首张卡: size=%s  底=%d" % [
			str(c0.size), int(c0.position.y + c0.size.y)])
		print("ItemRow 子节点数: %d" % item_row.get_child_count())
	# --- ItemRow 高度诊断：内容高度真值 vs 被父级布局夹出来的值 ---
	print("")
	print("=== ItemRow 高度诊断 ===")
	print("  get_combined_minimum_size()=%s  ← 内容真值（幂等，本脚本据此排布）" % str(item_row.get_combined_minimum_size()))
	print("  size=%s  ← 受父级布局影响，可能被夹/被撑" % str(item_row.size))
	var max_child_min: float = 0.0
	for i in range(item_row.get_child_count()):
		var ch = item_row.get_child(i)
		var ch_min: Vector2 = ch.get_combined_minimum_size()
		print("    child[%d] %-22s min=%s  size=%s  flags_v=%d" % [
			i, str(ch.name), str(ch_min), str(ch.size), ch.size_flags_vertical])
		max_child_min = max(max_child_min, ch_min.y)
	print("  子节点最小高度的最大值=%.0f" % max_child_min)
	# 重叠检测
	print("")
	print("=== 重叠检测 ===")
	var rects := {}
	for n in names:
		var c = panel.get_node_or_null(n)
		if c != null:
			rects[n] = Rect2(c.position, c.size)
	var keys = rects.keys()
	var overlaps := 0
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			if rects[keys[i]].intersects(rects[keys[j]]):
				print("  重叠: %s 与 %s" % [keys[i], keys[j]])
				overlaps += 1
	if overlaps == 0:
		print("  无重叠")

	# 面板包含检测：所有区块必须完全落在 Panel 内（统一用局部坐标）
	print("")
	print("=== 面板包含检测 ===")
	var escapes := 0
	for n in rects.keys():
		if not panel_rect.encloses(rects[n]):
			print("  溢出面板: %-14s %s  面板=%s" % [n, str(rects[n]), str(panel_rect)])
			escapes += 1
	if escapes == 0:
		print("  全部在面板内")

	print("")
	if overlaps == 0 and escapes == 0:
		print("SHOP_GEOM_PASS: 无重叠、无溢出，Panel=%s" % str(panel.size))
		quit(0)
	else:
		print("SHOP_GEOM_FAIL: 重叠 %d 项 / 溢出 %d 项" % [overlaps, escapes])
		quit(1)
