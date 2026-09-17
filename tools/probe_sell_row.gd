extends SceneTree

# 「已购买」行渲染验证 —— 用确定性输入，不靠抽卡运气
#
# 背景：截图工具按随机刷出的商品购买，买到武器时条目归入「已装备武器」，
# 「已购买」行就还是空的（截图上看起来像缺陷）。不能靠反复重掷碰运气来验收，
# 要**直接构造** purchased_items 再刷新，断言这一行真的渲染出来。
#
# 判据：
#   A. 注入一条 purchased_items 后，_refresh_sell_area() 建出「已购买」条目行
#   B. 该行有非零尺寸且完全落在 SellScroll 区域内
#   C. 条目行宽 == 区域宽（撑满，判据⑦ 的针对性验证）
#   D. 「出售」按钮存在且文字含「出售(」
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

func _process(_delta: float) -> bool:
	frames += 1
	if shop == null:
		if main != null:
			shop = main.get("shop")
		if shop == null:
			if frames > 30:
				print("SELLROW_FAIL: 拿不到 shop")
				quit(1)
				return true
			return false
	if frames == 10:
		shop.open(3, 500, 0, main.get("player"))
		# 直接注入一条**非武器**道具，确定性地填满「已购买」行
		shop.purchased_items.clear()
		shop.purchased_items.append({
			"name": "测试护符",
			"type": "item",
			"price": 100,
			"paid_price": 100,
		})
		shop._refresh_sell_area()
		return false
	if frames < 20:
		return false
	if frames > 20:
		return true
	_report()
	return true

func _report() -> void:
	print("=== 「已购买」行渲染验证 ===")
	var failures: Array = []
	var scroll = shop.get_node_or_null("Panel/SellScroll")
	if scroll == null:
		print("SELLROW_FAIL: 没有 SellScroll")
		quit(1)
		return
	var sc_c: Control = scroll
	var box: Control = null
	for i in range(sc_c.get_child_count()):
		var c = sc_c.get_child(i)
		if c is Control:
			box = c
			break
	if box == null:
		print("SELLROW_FAIL: 没有内容容器")
		quit(1)
		return

	print("SellScroll size=%s  内容容器 size=%s min=%s 子节点=%d" % [
		str(sc_c.size), str(box.size), str(box.get_combined_minimum_size()), box.get_child_count()])

	# 逐行打印，找到非标题的条目行
	var found_item_row := false
	for i in range(box.get_child_count()):
		var row = box.get_child(i)
		if not (row is Control):
			continue
		var rc: Control = row
		var txt := ""
		if rc is Label:
			txt = (rc as Label).text
		elif rc is HBoxContainer and rc.get_child_count() > 0:
			var f = rc.get_child(0)
			if f is Label:
				txt = (f as Label).text
		var is_header: bool = txt.begins_with("已购买") or txt.begins_with("已装备武器")
		print("  行[%d] %-30s size=%s  y=%d..%d  %s" % [
			i, txt, str(rc.size), int(rc.position.y), int(rc.position.y + rc.size.y),
			"标题" if is_header else "**条目**"])
		if is_header:
			continue
		found_item_row = true
		# 判据 B：条目必须有非零尺寸且落在区域内
		if rc.size.y <= 0.0 or rc.size.x <= 0.0:
			failures.append("条目「%s」矩形塌陷 size=%s" % [txt, str(rc.size)])
		if rc.position.y + rc.size.y > sc_c.size.y + 0.5:
			failures.append("条目「%s」底边 %d 超出区域高 %.0f → 被裁"
				% [txt, int(rc.position.y + rc.size.y), sc_c.size.y])
		# 判据 D：要有出售按钮
		var has_sell_btn := false
		if rc is HBoxContainer:
			for j in range((rc as HBoxContainer).get_child_count()):
				var ch = (rc as HBoxContainer).get_child(j)
				if ch is Button and (ch as Button).text.contains("出售("):
					has_sell_btn = true
		if not has_sell_btn:
			failures.append("条目「%s」没有「出售(」按钮" % txt)

	if not found_item_row:
		failures.append("注入 purchased_items 后仍未渲染出「已购买」条目行"
			+ "（判据未触发 → 本验证作废，不是通过）")

	# 判据 C：条目行必须撑满区域宽（判据⑦ 的针对性复核）
	if found_item_row and box.size.x < sc_c.size.x - 1.0:
		failures.append("条目容器宽 %.0f 未撑满区域宽 %.0f" % [box.size.x, sc_c.size.x])

	print("")
	if failures.is_empty():
		print("SELLROW_PASS: 「已购买」条目行已渲染、撑满区域、含出售按钮")
		quit(0)
	else:
		print("SELLROW_FAIL: %d 项" % failures.size())
		for f in failures:
			print("  - %s" % f)
		quit(1)
