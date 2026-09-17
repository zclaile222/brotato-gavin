extends SceneTree

# 动态区域**内部**几何量测 —— 探针从「容器外框」下沉到「条目是否真的可见」
#
# 为什么需要这个（2026-09-16）：
#   `probe_shop_geom.gd` 判的是 6 个容器的外框不重叠、不溢出，它 PASS 了。
#   但截图里肉眼可见两个问题：
#     ① 「武器合成」区的合成卡被裁在区域底边 —— ScrollContainer 只露出上面一截
#     ② 「已购买」与「已装备武器」两条标题之间没有任何条目 —— 内容排不进去
#   结论：**外框正确 ≠ 内容可见**。本探针量的是区域内部：
#     · UpgradeScroll: upgrade_hbox 的 minimum 高度 vs 区域可用高度
#     · SellScroll:    sell_vbox 的 minimum 高度 vs 区域可用高度
#     · 每个条目的 y 区间是否落在区域底边之内
#
# 判据（红 = 玩家看不见内容）：
#   A. 区域可用高度 > 0（区域自身没塌）
#   B. 内容 minimum 高度 <= 区域可用高度（否则被裁，只有一部分可见）
#   C. 每个已建条目（除标题）的底边 <= 区域底边（条目自身不能被裁）
#   D. 条目数 > 0 时，条目的对角线不能为零（塌陷检测）
#
# 用法：--headless --path . --script res://tools/probe_shop_inner.gd
# 退出码 0 = 全部可见；1 = 有内容被裁
const VIEW_SIZE := Vector2i(1280, 720)

var main = null
var shop = null
var probe_viewport: SubViewport = null
var frames := 0

func _initialize() -> void:
	probe_viewport = SubViewport.new()
	probe_viewport.name = "ProbeViewport"
	probe_viewport.size = VIEW_SIZE
	probe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(probe_viewport)
	main = load("res://scenes/Main.tscn").instantiate()
	probe_viewport.add_child(main)
	# 同 probe_shop_geom：SubViewport 里的场景不能设 current_scene。

func _process(_delta: float) -> bool:
	frames += 1
	if shop == null:
		if main != null:
			shop = main.get("shop")
		if shop == null:
			if frames > 30:
				print("SHOP_INNER_FAIL: 30 帧后仍拿不到 shop")
				quit(1)
				return true
			return false
	if frames == 10:
		var player = main.get("player")
		# 装备 3 把（会合成成 T4）让合成区有内容；
		# 再走一次真实购买让「已购买」区有内容。
		if player != null and player.has_method("equip_or_combine_weapon"):
			for i in range(3):
				player.equip_or_combine_weapon("pistol", 1 + i)
		shop.open(3, 500, 0, player)
		# 买 2 件 —— 让「已购买」区有条目（走真实购买入口保证记账一致）
		for i in range(min(2, shop.current_items.size())):
			var cards = shop.get_node_or_null("Panel/ItemRow")
			if cards != null and i < cards.get_child_count():
				var btn = shop._find_buy_button(cards.get_child(i))
				if btn != null:
					shop._on_buy_pressed(i, btn, null)
		if shop.has_method("_refresh_sell_area"):
			shop._refresh_sell_area()
		if shop.has_method("_refresh_upgrade_area"):
			shop._refresh_upgrade_area()
		return false
	if frames < 20:
		return false
	if frames > 20:
		return true
	_report()
	return true

func _report() -> void:
	print("=== 动态区域内部几何 ===")
	var vr: Vector2 = probe_viewport.get_visible_rect().size
	if vr.x < 1200.0 or vr.y < 700.0:
		print("SHOP_INNER_FAIL: 视口 %s 不是 1280x720，结论不可用" % str(vr))
		quit(1)
		return

	var failures: Array = []
	_check_area("UpgradeScroll", failures)
	_check_area("SellScroll", failures)

	print("")
	if failures.is_empty():
		print("SHOP_INNER_PASS: 两个动态区域的内容全部可见（无裁剪）")
		quit(0)
	else:
		print("SHOP_INNER_FAIL: %d 项内容被裁/不可见" % failures.size())
		for f in failures:
			print("  - %s" % f)
		quit(1)

func _check_area(scroll_name: String, failures: Array) -> void:
	var scroll = shop.get_node_or_null("Panel/" + scroll_name)
	print("")
	print("--- %s ---" % scroll_name)
	if scroll == null:
		failures.append("%s：节点不存在" % scroll_name)
		return
	# ScrollContainer 的可用内容高度 = 自身高度 - 上下滚动条/内边距
	# （这里不猜内边距，直接看「内容 minimum」与「可见高度」谁大）
	var area_h: float = scroll.size.y
	var area_w: float = scroll.size.x
	print("  自身矩形: pos=%s size=%s" % [str(scroll.position), str(scroll.size)])
	# 判据 A：区域自身不能塌
	if area_h <= 0.0 or area_w <= 0.0:
		failures.append("%s：区域矩形塌陷 size=%s" % [scroll_name, str(scroll.size)])
		return

	var box = _first_child(scroll)
	if box == null:
		failures.append("%s：没有内容容器（_build_* 未建 VBox/HBox？）" % scroll_name)
		return
	var box_min: Vector2 = box.get_combined_minimum_size()
	print("  内容容器 %s: min=%s  size=%s  子节点数=%d" % [
		str(box.name), str(box_min), str(box.size), box.get_child_count()])

	# 判据 B：内容 minimum 必须放得下（否则被裁）
	if box_min.y > area_h + 0.5:
		failures.append("%s：内容需要 %.0f 高，区域只有 %.0f → 底部 %.0f 被裁掉（玩家看不到）"
			% [scroll_name, box_min.y, area_h, box_min.y - area_h])

	# 判据 C/D：逐条目检查底边与塌陷
	var inner_top: float = box.position.y
	var visible_bottom: float = area_h
	var n_rows := 0
	for i in range(box.get_child_count()):
		var row = box.get_child(i)
		if row == null or not (row is Control):
			continue
		var rc: Control = row
		var r_bottom: float = inner_top + rc.position.y + rc.size.y
		var label := str(rc.name)
		if rc is Label:
			label = (rc as Label).text
		elif rc is HBoxContainer and rc.get_child_count() > 0:
			var first = rc.get_child(0)
			if first is Label:
				label = (first as Label).text
		print("    行[%d] y=%4d..%4d h=%3d  %s%s" % [
			i, int(inner_top + rc.position.y), int(r_bottom), int(rc.size.y),
			label, "  ← 超出区域底边(%.0f)" % visible_bottom if r_bottom > visible_bottom + 0.5 else ""])
		if rc.size.y <= 0.0:
			failures.append("%s：条目「%s」高度为 0（塌陷）" % [scroll_name, label])
		if r_bottom > visible_bottom + 0.5:
			failures.append("%s：条目「%s」底边 %.0f 超出区域底边 %.0f → 被裁"
				% [scroll_name, label, r_bottom, visible_bottom])
		n_rows += 1

	print("  条目数=%d  区域可用高度=%.0f  内容需要=%.0f" % [n_rows, area_h, box_min.y])
	if n_rows == 0:
		failures.append("%s：一条内容都没有（建了区域但没条目 → 玩家看不到任何东西）" % scroll_name)

func _first_child(node: Node) -> Control:
	for i in range(node.get_child_count()):
		var c = node.get_child(i)
		if c is Control:
			return c
	return null
