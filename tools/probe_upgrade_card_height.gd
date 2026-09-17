extends SceneTree

# 合成卡真实高度量测 —— `custom_minimum_size = (160, 90)` 到底够不够
#
# 症状（截图 shots/shop_fixed.png）：合成卡底部的「已满阶」贴着区域下边缘，
# 看起来被裁。UpgradeScroll 区域高 110，若卡片实需 > 110 就必然被裁。
#
# 判据：逐张读卡片的 get_combined_minimum_size().y（「内容 minimum + 自身 stylebox 边框」）
# 与「实占 size.y」，取最大值作为区域所需高度。
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
				print("CARD_H_FAIL: 拿不到 shop")
				quit(1)
				return true
			return false
	if frames == 10:
		var player = main.get("player")
		# 两种都建出来：T1（有「合成」按钮）与 T4（有「已满阶」标签）
		if player != null and player.has_method("equip_or_combine_weapon"):
			player.equip_or_combine_weapon("pistol", 1)
			player.equip_or_combine_weapon("smg", 4)
		shop.open(3, 500, 0, player)
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
	print("=== 合成卡真实高度 ===")
	var scroll = shop.get_node_or_null("Panel/UpgradeScroll")
	if scroll == null:
		print("CARD_H_FAIL: 没有 UpgradeScroll")
		quit(1)
		return
	var area_h: float = (scroll as Control).size.y
	print("UpgradeScroll 可用高度 = %.0f" % area_h)

	var box: Control = null
	for i in range((scroll as Control).get_child_count()):
		var c = scroll.get_child(i)
		if c is Control:
			box = c
			break
	if box == null:
		print("CARD_H_FAIL: 没有内容容器")
		quit(1)
		return

	var need: float = 0.0
	var n := 0
	for i in range(box.get_child_count()):
		var ch = box.get_child(i)
		if not (ch is Control):
			continue
		var cc: Control = ch
		if not (cc is PanelContainer):
			print("  [%d] %s (%s) 非卡片，跳过" % [i, str(cc.name), cc.get_class()])
			continue
		n += 1
		var min_need: float = cc.get_combined_minimum_size().y
		print("  卡[%d]  声明custom_min=%s  combined_min=%.0f  实占size.y=%.0f  子节点=%d" % [
			i, str(cc.custom_minimum_size), min_need, cc.size.y, cc.get_child_count()])
		# 卡片内部各子控件的高度累加（判定内容到底要多少）
		for j in range(cc.get_child_count()):
			var inner = cc.get_child(j)
			if inner is Control:
				print("      内[%d] %s min=%.0f size=%.0f" % [
					j, str(inner.name), (inner as Control).get_combined_minimum_size().y,
					(inner as Control).size.y])
				for k in range((inner as Control).get_child_count()):
					var g = (inner as Control).get_child(k)
					if g is Control:
						print("        孙[%d] %s min=%.0f size=%.0f" % [
							k, str(g.name), (g as Control).get_combined_minimum_size().y,
							(g as Control).size.y])
		need = max(need, max(min_need, cc.size.y))

	print("")
	print("卡片数=%d  卡片所需最大高度=%.0f  区域可用=%.0f" % [n, need, area_h])
	print("")
	if n == 0:
		print("CARD_H_FAIL: 没有合成卡（前置条件未满足，本次量测无效）")
		quit(1)
	elif need > area_h + 0.5:
		print("CARD_H_FAIL: 卡片需要 %.0f 高，区域只有 %.0f → 底部 %.0f 被裁"
			% [need, area_h, need - area_h])
		quit(1)
	else:
		print("CARD_H_PASS: 卡片 %.0f <= 区域 %.0f，未被裁（富余 %.0f）"
			% [need, area_h, area_h - need])
		quit(0)
