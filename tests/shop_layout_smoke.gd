extends SceneTree

# ═══════════════════════════════════════════════════════════════════════════════
# 商店 UI 布局冒烟 —— 动态区域是否真的有可见几何、且彼此不打架
#
# 背景（2026-09-17）：玩家反馈「运行游戏时没发现这些改动」，而这套件的
# 另外 29 个套件当时**全部是绿的** —— 因为既有测试只断言「节点存在、数据正确」，
# 从不检查**布局位置**。这是一整类测试盲区，本套件就是来补它的。
#
# 根因（本套件建立时的第一起）：`$Panel` 是 Panel 类型（非容器），
# `add_child()` 不替子节点布局，于是 SellScroll / UpgradeScroll 全部停在 (0,0)
# 且宽度为 0 —— 内容渲染不出来。
#
# ⚠️ 本套件后来补强过一次，因为第一版**漏掉了第二起重叠**：
#   它直接实例化 `Shop.tscn`，ItemRow 里**一张卡都没有** → 行高 0 →
#   动态区被排到很靠上的位置，自然不重叠。而真实运行时（`shop.open()` 会建 4 张卡）
#   卡片把 ItemRow 撑到 340，落进手算的 310 → 「武器合成」标签压在商品卡上。
#   **不喂入真实内容就测不出真实布局。** 所以现在改为走 `Main.tscn` +
#   `shop.open()`，与玩家实际进入商店的路径完全一致。
#
# 判据（**不是**「函数被调用」，而是「节点是否占据正确矩形」）：
#   ① is_node_ready() 为 true，且 shop.open() 已真的建出卡片（否则测的是空场景）
#   ② SellScroll / UpgradeScroll 的 size.x > 0（宽度为 0 = 内容不可见）
#   ③ 所有区块的矩形完全落在 Panel 内
#   ④ 任意两个区块互不重叠
#   ⑤ 布局幂等（重复同步矩形不变）
#   ⑥ 计算用行高 == 卡片实际需要的行高（判据①②③④抓不到这条，见下）
#   ⑦ 动态区的**内容容器必须撑满区域宽度**，且内容高度不得超出区域
#      （判据①②③④只测容器**外框**，抓不到「外框正确但内容挤成一坨」）
#
# ── ⑦ 的由来（2026-09-16，第三起，也是玩家反馈的真正成因）──
#   修完①②之后我去截图验收，肉眼看到「已购买 / 已装备武器」两条标题下面
#   **像是空的**。但当时 31 个套件全绿、本套件的判据①~⑥ 也全绿。
#   实测（tools/probe_scroll_width.gd，A/B 对照）：
#     · SellScroll 自身 1200 宽，其子 sell_vbox 只有 **239 宽**；
#     · UpgradeScroll 自身 1200 宽，其子 upgrade_hbox 只有 **228 宽**。
#   根因：**ScrollContainer 会把子节点按 minimum 尺寸摆放**，不给
#   `size_flags_horizontal = SIZE_EXPAND_FILL` 就永远撑不满。
#   后果：条目虽然「存在且可见」，却全部挤在左侧一条 ~240 宽的窄柱里，
#   「出售(+N材料)」按钮离标签很远 —— 整块区域在视觉上读起来就是**空的**。
#   A/B 证据：flags=1(SIZE_FILL) → 239 宽；flags=3(SIZE_FILL|SIZE_EXPAND) → 1200 宽。
#   → 教训：**外框正确 ≠ 内容可用**。判据必须下沉到「内容容器是否撑满区域」。
#   本判据直接断言两个中间量（子容器宽度 / 内容所需高度），不只看最终几何。
#
# ── 变异验证记录（2026-09-17，用 tools/run_mutation.cjs 实跑）──
#   | 变异                        | 退出码 | 结论        |
#   |-----------------------------|--------|-------------|
#   | no-area-layout（不做布局）   |   1    | 捕获（2 项）|
#   | area-top-fixed（写死 top）   |   1    | 捕获（5 项）|
#   | row-height-hardcoded(=232)  |   1    | 捕获（2 项）|
#   | row-height-400（行高过大）   |   1    | 捕获（1 项）|
#   | panel-non-idempotent        |   0    | **未捕获**  |
#
#   ⚠️ 最后一行的「未捕获」是**正确结论**，不是缺口：那个变异让面板底边每次调用都
#   累加一次内容高度，但本实现的面板高度是「只增不减 + 取 min(内容, 可用)」，
#   **会自愈回正确值**。也就是说该变异在本实现下确实无害，判据不该报红。
#
#   ⚠️ 另有一条**曾经的假缺口**值得记下：一开始我把变异注入在 `_item_row_height()`
#   的**兜底 return** 上，套件一直绿，我判定「判据有缺口」。
#   实际原因是**变异本身无效** —— 有卡片时函数在循环里就已 return 真实高度（340），
#   末尾那行根本走不到。**「套件没报红」有时是变异没生效，要先证明变异真的改变了行为**，
#   否则会把「无效变异」误判成「测试有缺口」，白白削弱一套本来有效的判据。
#
#   ⚠️ 变异注入必须做**编译自检**：脚本编译不过时套件也会红，但那与「变异被捕获」
#   毫无关系（被测脚本压根没加载）。tools/run_mutation.cjs 已强制这一步，
#   编译失败会把整次验证标记为「作废」而不是「通过」。
#
#   ⚠️ 判据⑦ 的变异验证（2026-09-16 补做）：删掉 `sell_vbox.size_flags_horizontal` 那一行
#   → 判据⑦ 报红（实测 sell_vbox 239 vs 区域 1200），其余判据全绿。
#   这正好复现了「31 个套件全绿但玩家看不见内容」的原始症状。
# ═══════════════════════════════════════════════════════════════════════════════

# ⚠️ 视口尺寸：`--headless` 下视口只有 64×64。
#   · `root.size = ...` **被忽略**（实测仍然 (64,64)）；
#   · `root.content_scale_size` 在 `--script` 模式下也**不生效**。
# 视口 64×64 时面板高度会被屏幕约束夹到 44，所有内容看起来都"在面板外"——
# 那是探针环境的假象，不是产品缺陷。正解是用 SubViewport 给一个固定逻辑分辨率。
const VIEW_SIZE := Vector2i(1280, 720)

var main = null
var shop = null
var player = null
var probe_viewport: SubViewport = null
var frames := 0
var opened := false
var player_available := false

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
	if main == null:
		return false
	# ⚠️ 不要用「第 N 帧做第 N 件事」的写死时序：
	# Main._ready() 建 shop 和取 player 的先后、以及 ready 在哪一帧跑完，
	# 都不是本套件能定的。实测固定在第 8 帧发起时 shop 已就绪但 player 还是 nil，
	# 于是报「拿不到 player」—— 3/3 稳定复现。改为**轮询前置条件**：
	# 两个引用都在手了再 open()，超时才判失败。
	if not opened:
		if shop == null:
			shop = main.get("shop")
		if player == null:
			player = main.get("player")
		# shop 是必需的（没有它整个套件无从测起），player 是可选的（见下）。
		# 不要在这里要求 player 非空：实测 `Main._ready()` 里 shop 先建、
		# player 的赋值路径更靠后，固定帧数内 player 常常还是 nil，
		# 硬等会得到一个与被测对象无关的「拿不到 player」失败（3/3 稳定误红）。
		if shop == null:
			if frames > 60:
				print("SHOP_LAYOUT_SMOKE_FAIL: 60 帧内仍未建出 shop")
				quit(1)
				return true
			return false
		# 装备一把武器，让「武器合成」区真的有条目可排。
		# 拿不到 player 不判失败 —— 本套件测的是**商店自身布局**，
		# 有没有玩家只影响「武器合成」区有没有条目，不影响该区域的矩形是否合法。
		# 但要在报告里写明，以免"跳过"被误读成"通过"。
		if player != null and player.has_method("equip_or_combine_weapon"):
			player.equip_or_combine_weapon("pistol", 3)
		shop.open(3, 500, 0, player)
		player_available = (player != null)
		opened = true
		return false
	# 让 open() 引发的布局/卡片创建跑完几帧再测量。
	if frames < 90:
		return false
	_report()
	return true

func _report() -> void:
	print("=== 商店布局冒烟 ===")
	var failures: Array = []

	# 前置自检①：视口必须是 1280×720，否则"越界"结论全部不可信
	var vr: Vector2 = probe_viewport.get_visible_rect().size
	if vr.x < 1200.0 or vr.y < 700.0:
		print("SHOP_LAYOUT_SMOKE_FAIL: 视口 %s 不是 1280x720，结论不可用" % str(vr))
		quit(1)
		return

	# 前置自检②：_ready 必须真的跑过
	if not shop.is_node_ready():
		print("SHOP_LAYOUT_SMOKE_FAIL: _ready 未执行（is_node_ready=false），测的是空壳")
		quit(1)
		return

	var panel = shop.get_node_or_null("Panel")
	if panel == null:
		print("SHOP_LAYOUT_SMOKE_FAIL: 找不到 Panel")
		quit(1)
		return

	# 前置自检③：必须真的有 4 张商品卡。
	# 这一条是本套件第一版的致命缺陷所在 —— 没有卡片时 ItemRow 高度为 0，
	# 动态区被排得很靠上，"互不重叠"会**静默通过**，而真实运行时是重叠的。
	var item_row = panel.get_node_or_null("ItemRow")
	var card_count := 0
	if item_row != null:
		for i in range(item_row.get_child_count()):
			if not item_row.get_child(i).is_queued_for_deletion():
				card_count += 1
	if card_count < 4:
		failures.append("前置自检失败：ItemRow 只有 %d 张卡（应为 4）。"
			% card_count + "卡片为空时行高为 0，本套件的重叠判据会静默通过 —— "
			+ "这正是它第一版漏掉真实重叠的原因。")
	print("前置自检：视口=%s  商品卡=%d 张  玩家引用=%s" % [
		str(vr), card_count, "有" if player_available else "无（武器合成区为空，该区矩形仍照测）"])

	# ⚠️ 坐标系：Shop 是 CanvasLayer 挂在 Main（Node2D，位于 (30,30)）之下，
	# 后代都继承恒定位移，**不能用 global_position**（会把所有区块误判为溢出）。
	# 面板自身 position 是相对 CanvasLayer 的，而子节点 position 是相对**面板**的，
	# 两者原点不同 —— 所以子节点矩形以父节点为原点构造，面板包含判据用 (0,0,size)。
	var panel_rect = Rect2(Vector2.ZERO, panel.size)
	print("Panel  size=%s" % str(panel.size))

	var names = ["Title", "GoldLabel", "ItemRow", "ButtonRow", "SellScroll", "UpgradeScroll"]
	var rects := {}
	for nm in names:
		var n = _find(panel, nm)
		if n == null:
			failures.append("%s：前置自检失败，节点不存在（_build_* 未执行？）" % nm)
			continue
		var r = Rect2(n.position, n.size)
		rects[nm] = r
		print("%-14s pos=(%5.0f,%5.0f) size=(%5.0f,%5.0f)  底=%5.0f" % [
			nm, r.position.x, r.position.y, r.size.x, r.size.y,
			r.position.y + r.size.y])

	# 判据②：两个动态区必须有可见宽度
	for nm in ["SellScroll", "UpgradeScroll"]:
		if not rects.has(nm):
			continue
		var r: Rect2 = rects[nm]
		if r.size.x <= 0.0:
			failures.append("%s：宽度为 %.0f，内容完全渲染不出来（Panel 非容器，必须显式给几何）"
				% [nm, r.size.x])
		if r.size.y <= 0.0:
			failures.append("%s：高度为 %.0f" % [nm, r.size.y])

	# 判据③：所有区块必须完全落在 Panel 内
	for nm in rects.keys():
		if not panel_rect.encloses(rects[nm]):
			failures.append("%s 矩形 %s 未完全落在 Panel %s 内"
				% [nm, str(rects[nm]), str(panel_rect)])

	# 判据④：任意两区块不得重叠（含 ItemRow 与动态区 —— 这是第二起重叠的形态）
	var keys = rects.keys()
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			if rects[keys[i]].intersects(rects[keys[j]]):
				failures.append("%s 与 %s 重叠：%s vs %s"
					% [keys[i], keys[j], str(rects[keys[i]]), str(rects[keys[j]])])

	# 判据⑤：布局必须**幂等** —— 再触发一次同步，矩形不得变化。
	# 这是「面板高度用上一帧尺寸自我放大」那类缺陷的专属探针：
	# 非幂等的布局会每调用一次就更歪一点，直到内容被推出面板。
	var before := rects.duplicate(true)
	shop._sync_dynamic_layout()
	var after := {}
	for nm in names:
		var n = _find(panel, nm)
		if n != null:
			after[nm] = Rect2(n.position, n.size)
	for nm in before.keys():
		if after.has(nm) and not before[nm].is_equal_approx(after[nm]):
			failures.append("布局非幂等：%s 在重复同步后由 %s 变为 %s（会逐次累积偏移）"
				% [nm, str(before[nm]), str(after[nm])])

	# 判据⑥：**计算用的行高必须容得下真实卡片**。
	#
	# 🔴 这条是被变异验证逼出来的（2026-09-17）：把 `_item_row_height()` 改成 232 或 400，
	# 判据①~⑤ **全部通过** —— 因为 `_sync_dynamic_layout()` 每帧被多次调用，
	# 且面板高度取了 `min(内容高度, 可用高度)`，一次算错会被**后续调用覆盖回正确值**。
	# 也就是说这套布局对「行高算错」是**自愈**的；只看最终几何，永远抓不到它。
	# 而「自愈」的前提是够调用几次 —— 一旦某个改动让某次调用成为**最后一次**，
	# 错误就会留在屏幕上。所以要直接断言那个**中间量**：行高算得对不对。
	var needed_row_h: float = 0.0
	if item_row != null:
		for i in range(item_row.get_child_count()):
			var ch = item_row.get_child(i)
			if ch.is_queued_for_deletion() or not (ch is Control):
				continue
			needed_row_h = max(needed_row_h, (ch as Control).custom_minimum_size.y)
	var used_row_h: float = shop._item_row_height()
	print("行高核对：计算用=%.0f  卡片实需=%.0f" % [used_row_h, needed_row_h])
	if needed_row_h > 0.0 and abs(used_row_h - needed_row_h) > 1.0:
		failures.append("行高与卡片实际需求不符：计算用 %.0f，卡片实需 %.0f。"
			% [used_row_h, needed_row_h]
			+ "布局目前会靠后续调用自愈，但一旦某次调用成为最后一次，"
			+ "ItemRow 就会盖住下面的区域（这正是第二起重叠的成因）。")

	# 判据⑦：动态区域的**内容容器必须撑满区域宽度**，且内容高度不得超出区域。
	#
	# 🔴 这条的由来（2026-09-16）：修完①②后我截图验收，肉眼看到「已购买 /
	# 已装备武器」两条标题下面**像是空的**，而当时 31 个套件全绿、判据①~⑥ 也全绿。
	# 实测根因：**ScrollContainer 把子节点按 minimum 尺寸摆放** ——
	# SellScroll 自身 1200 宽，其子 sell_vbox 只有 239 宽（= 最长标签宽度）；
	# UpgradeScroll 自身 1200 宽，其子 upgrade_hbox 只有 228 宽。
	# 条目并非「没渲染」，而是被挤进左侧一条 ~240 宽的窄柱里，
	# 「出售(+N材料)」按钮离标签很远 —— 整块区域读起来就是空的。
	# 修法：给内容容器加 `size_flags_horizontal = SIZE_EXPAND_FILL`。
	# A/B 证据：flags=1(SIZE_FILL) → 239 宽；flags=3(SIZE_FILL|SIZE_EXPAND) → 1200 宽。
	#
	# 为什么判据①~④ 抓不到：它们只测**容器外框**（矩形合法、不重叠、在面板内），
	# 而这里是「外框全对、内容却不可用」。**外框正确 ≠ 内容可用。**
	for area_nm in ["SellScroll", "UpgradeScroll"]:
		var sc = _find(panel, area_nm)
		if sc == null or not (sc is Control):
			continue
		var sc_c: Control = sc
		if sc_c.size.x <= 0.0:
			continue  # 塌陷已由判据②报过，不重复
		var box: Control = null
		for i in range(sc_c.get_child_count()):
			var c = sc_c.get_child(i)
			if c is Control:
				box = c
				break
		if box == null:
			failures.append("%s：没有内容容器（_build_* 未建 VBox/HBox？）" % area_nm)
			continue
		# ⑦a 内容容器宽度必须撑满区域（ScrollContainer 不给 EXPAND 就不会撑）
		var w_gap: float = sc_c.size.x - box.size.x
		print("内容容器 %-14s 区域宽=%.0f 子宽=%.0f 差=%.0f 内容min高=%.0f 区域高=%.0f" % [
			area_nm, sc_c.size.x, box.size.x, w_gap,
			box.get_combined_minimum_size().y, sc_c.size.y])
		if w_gap > 1.0:
			failures.append("%s：内容容器宽 %.0f 未撑满区域宽 %.0f（差 %.0f）。"
				% [area_nm, box.size.x, sc_c.size.x, w_gap]
				+ "ScrollContainer 按 minimum 摆放子节点 —— 缺 size_flags_horizontal = "
				+ "SIZE_EXPAND_FILL。条目会挤在左侧窄柱里，视觉上整块区域像空的。")
		# ⑦b 内容高度不得超出区域（否则底部被裁，玩家看不到）
		var box_h: float = box.get_combined_minimum_size().y
		if box_h > sc_c.size.y + 0.5:
			failures.append("%s：内容需要 %.0f 高，区域只有 %.0f → 底部 %.0f 被裁掉"
				% [area_nm, box_h, sc_c.size.y, box_h - sc_c.size.y])

	print("")
	if failures.is_empty():
		print("SHOP_LAYOUT_SMOKE_PASS（7 类判据全部满足：有真实卡片 / 有宽度 / 在面板内 / "
			+ "不重叠 / 幂等 / 行高同源 / 内容撑满区域）")
		quit(0)
	else:
		print("SHOP_LAYOUT_SMOKE_FAIL: %d 项" % failures.size())
		for f in failures:
			print("  - %s" % f)
		quit(1)

func _find(node: Node, nm: String) -> Control:
	for i in range(node.get_child_count()):
		var c = node.get_child(i)
		if str(c.name) == nm:
			return c
		var deep = _find(c, nm)
		if deep != null:
			return deep
	return null
