extends SceneTree

# 道具行真实高度量测 —— ItemRow 到底占了多高？
#
# 背景：ItemRow 的 `get_combined_minimum_size().y` = 340（卡片声明的值），
# 但它实测占 408。也就是说「卡片最小高度」不等于「行占用的高度」，
# 手算模型缺了一层。要定位这 68 从哪来，必须直接架起 Shop.tscn
# （不带 Main，省掉加载开销）并单独观察 ItemRow。

const VIEW_SIZE := Vector2i(1280, 720)

var shop = null
var probe_viewport: SubViewport = null
var frames := 0

func _initialize() -> void:
	probe_viewport = SubViewport.new()
	probe_viewport.size = VIEW_SIZE
	probe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(probe_viewport)
	shop = load("res://scenes/Shop.tscn").instantiate()
	probe_viewport.add_child(shop)

func _process(_delta: float) -> bool:
	frames += 1
	# _ready 在 add_child 之后下一帧才跑；等它建好再 open。
	if frames == 2:
		shop.open(3, 500, 0, null)
	if frames < 5:
		return false
	if frames > 5:
		return true
	_report()
	return true

func _report() -> void:
	print("=== 道具行高度量测 ===")
	var panel = shop.get_node_or_null("Panel")
	var row = panel.get_node_or_null("ItemRow")
	print("Panel size=%s" % str(panel.size))
	print("ItemRow  size=%s  min=%s  子节点数=%d" % [
		str(row.size), str(row.get_combined_minimum_size()), row.get_child_count()])
	print("")
	for i in range(row.get_child_count()):
		var card = row.get_child(i)
		print("card[%d] name=%s" % [i, str(card.name)])
		print("    custom_minimum_size=%s  get_combined_minimum_size=%s  size=%s" % [
			str(card.custom_minimum_size), str(card.get_combined_minimum_size()), str(card.size)])
		for j in range(card.get_child_count()):
			var ch = card.get_child(j)
			print("    子[%d] %s (%s) min=%s size=%s" % [
				j, str(ch.name), ch.get_class(),
				str(ch.get_combined_minimum_size()), str(ch.size)])
			# MarginContainer 里再挖一层：VBox 的内容高度
			for k in range(ch.get_child_count()):
				var g = ch.get_child(k)
				print("      孙[%d] %s (%s) min=%s size=%s" % [
					k, str(g.name), g.get_class(),
					str(g.get_combined_minimum_size()), str(g.size)])
				for m in range(g.get_child_count()):
					var gg = g.get_child(m)
					print("        曾[%d] %s (%s) min=%s size=%s" % [
						m, str(gg.name), gg.get_class(),
						str(gg.get_combined_minimum_size()), str(gg.size)])
	print("")
	print("ROW_HEIGHT_PROBE_DONE")
	quit(0)
