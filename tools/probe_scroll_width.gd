extends SceneTree

# ScrollContainer 子容器宽度塌陷诊断 —— 为什么 sell_vbox 只有 239 宽而区域有 1200
#
# 症状（probe_shop_inner 实测）：
#   UpgradeScroll 自身 1200 宽，但其子 upgrade_hbox 只有 228 宽；
#   SellScroll   自身 1200 宽，但其子 sell_vbox   只有 239 宽。
# 两者的宽度恰好等于「内容最小宽度」—— 说明 ScrollContainer 把子节点按 minimum 尺寸摆了。
#
# 要区分两种可能：
#   A. ScrollContainer 的 horizontal_scroll_mode 让它在水平方向按内容尺寸布局
#      （那么子节点永远只有 minimum 宽，加上 size_flags 才能撑开）
#   B. 子节点缺 size_flags_horizontal = SIZE_EXPAND_FILL（默认 SHRINK_BEGIN）
#
# 判据：本探针**在运行时**给子节点补上 SIZE_EXPAND_FILL，看下一帧宽度是否变成 1200。
#   变了 → 根因是 B（缺 flags），补 flags 即可修。
#   没变 → 根因是 A，得改 ScrollContainer 的模式。
const VIEW_SIZE := Vector2i(1280, 720)

var main = null
var shop = null
var probe_viewport: SubViewport = null
var frames := 0
var patched := false

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
				print("WIDTH_PROBE_FAIL: 拿不到 shop")
				quit(1)
				return true
			return false
	if frames == 10:
		var player = main.get("player")
		if player != null and player.has_method("equip_or_combine_weapon"):
			player.equip_or_combine_weapon("pistol", 1)
		shop.open(3, 500, 0, player)
		return false
	if frames == 14:
		print("=== 补 flags 之前 ===")
		_snap()
		# 运行时给两个内容容器补上水平撑开
		for nm in ["Panel/UpgradeScroll", "Panel/SellScroll"]:
			var sc = shop.get_node_or_null(nm)
			if sc == null:
				continue
			for i in range(sc.get_child_count()):
				var c = sc.get_child(i)
				if c is Control:
					(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		patched = true
		print(">>> 已给两个内容容器补 size_flags_horizontal = SIZE_EXPAND_FILL")
		return false
	if frames < 20:
		return false
	if frames > 20:
		return true
	print("")
	print("=== 补 flags 之后 ===")
	var ok := _snap()
	print("")
	if ok:
		print("WIDTH_PROBE_RESULT: 根因 = 缺 size_flags_horizontal（补上后子容器撑满区域宽度）")
		quit(0)
	else:
		print("WIDTH_PROBE_RESULT: 补 flags 无效 → 根因是 ScrollContainer 的滚动模式，另找修法")
		quit(1)
	return true

func _snap() -> bool:
	var all_ok := true
	for nm in ["Panel/UpgradeScroll", "Panel/SellScroll"]:
		var sc = shop.get_node_or_null(nm)
		if sc == null:
			print("%s 缺失" % nm)
			all_ok = false
			continue
		# 用显式类型，否则 `abs(...)` 的结果是 Variant → `:=` 推断失败
		# （本项目把该警告当错误，会直接解析不过）。
		var sc_c: Control = sc
		var box: Control = null
		for i in range(sc_c.get_child_count()):
			var c = sc_c.get_child(i)
			if c is Control:
				box = c
				break
		if box == null:
			print("%s 无内容容器" % nm)
			all_ok = false
			continue
		var filled: bool = abs(box.size.x - sc_c.size.x) < 1.0
		print("%-22s 区域宽=%.0f  内容容器宽=%.0f  撑满=%s  flags=%d" % [
			nm, sc_c.size.x, box.size.x,
			str(filled), box.size_flags_horizontal])
		if not filled:
			all_ok = false
	return all_ok
