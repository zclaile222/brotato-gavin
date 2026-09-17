extends SceneTree

# ═══════════════════════════════════════════════════════════════════════════════
# 商店界面截图 —— 把「商店 UI 到底长什么样」变成可以看的图
#
# 为什么单独一个工具：`capture_scene.gd` 是截主战场/升级面板的，商店需要
# 先构造出「有商品、有已购道具、有装备武器」的状态才看得出布局对不对。
#
# 用法（**不要加 --headless**）：
#   "<godot_console.exe>" --path . --script res://tools/capture_shop.gd \
#       -- --out=shots/shop.png --frames=8
#
# 参数：
#   --out=<路径>   输出 PNG，默认 shots/shop.png
#   --frames=<n>   开商店后再等几帧（默认 8），等布局与首帧渲染完成
#   --gold=<n>     材料数（默认 500，保证买得起以便看到按钮的「可购买」态）
#   --buy=<n>      先自动购买 n 件商品，让「已购买/出售栏」有内容（默认 2）
#   --equip=<n>    给玩家装备 n 把武器，让「武器合成区」有内容（默认 2）
#
# 退出码 0 成功 / 1 失败，并 print SHOP_CAPTURE_OK / SHOP_CAPTURE_FAIL。
#
# ⚠️ 为什么用 SubViewport 而不是 root.size（2026-09-16 实测）：
#   `root.size = Vector2i(1280, 720)` 在 `--headless` 下**被忽略**（实测视口 64×64），
#   `root.content_scale_size` 在 `--script` 模式也**不生效**。
#   后果极具迷惑性：商店的 1240 宽面板落进 64 宽的视口 → 布局按窄视口重排 →
#   截出来的图与真实游戏完全不是一回事（曾据此误判过「面板被顶出屏幕」）。
#   正解是自建 SubViewport 并设其 size —— 布局与渲染都按这个尺寸算。
#   另：SubViewport 里的场景**不能**调 `set_current_scene()`，会报
#   `p_scene->get_parent() != root` 并静默失败，所以用成员变量持有引用。
# ═══════════════════════════════════════════════════════════════════════════════

const VIEW_SIZE := Vector2i(1280, 720)

var scene_instance = null
var probe_viewport: SubViewport = null
var frames := 0
var target_frames := 8
var out_path := "shots/shop.png"
var gold := 500
var buy_count := 2
var equip_count := 2

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--frames="):
			target_frames = int(a.substr(9))
		elif a.begins_with("--gold="):
			gold = int(a.substr(7))
		elif a.begins_with("--buy="):
			buy_count = int(a.substr(6))
		elif a.begins_with("--equip="):
			equip_count = int(a.substr(8))

	probe_viewport = SubViewport.new()
	probe_viewport.size = VIEW_SIZE
	probe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(probe_viewport)

	var packed = load("res://scenes/Main.tscn")
	if packed == null:
		print("SHOP_CAPTURE_FAIL: 无法加载 Main.tscn")
		quit(1)
		return
	scene_instance = packed.instantiate()
	probe_viewport.add_child(scene_instance)

func _process(_delta: float) -> bool:
	frames += 1
	# 先跑几帧让 Main._ready 建好商店与玩家
	if frames == 10:
		_setup_state()
		return false
	if frames < 10 + target_frames:
		return false
	if frames > 10 + target_frames:
		return true
	_save()
	return true

func _setup_state() -> void:
	# 前置自检：视口必须真的是我们要的尺寸，否则后面截图/布局全是错的参照系。
	var vp_rect := probe_viewport.get_visible_rect()
	if vp_rect.size != Vector2(VIEW_SIZE):
		print("SHOP_CAPTURE_FAIL: 视口尺寸 %s ≠ 期望 %s（布局会按错误尺寸重排）"
			% [str(vp_rect.size), str(Vector2(VIEW_SIZE))])
		quit(1)
		return

	var shop = scene_instance.get("shop")
	if shop == null or not is_instance_valid(shop):
		print("SHOP_CAPTURE_FAIL: Main 里没有 shop（字段名变了？）")
		quit(1)
		return
	var player = scene_instance.get("player")

	# 装备武器 —— 让「武器合成区」有内容
	# 注意：`equip_weapon(type)` 只收一个参数（没有 tier），
	# 用 `equip_or_combine_weapon(type, tier)` 才能指定分阶。
	if player != null and is_instance_valid(player) and equip_count > 0:
		for i in range(equip_count):
			if player.has_method("equip_or_combine_weapon"):
				player.equip_or_combine_weapon("pistol", 1 + i % 3)
			elif player.has_method("equip_weapon"):
				player.equip_weapon("pistol")

	# 打开商店
	shop.open(3, gold, 0, player)

	# 买几件 —— 让「已购买/出售栏」有内容
	if buy_count > 0:
		for i in range(min(buy_count, shop.current_items.size())):
			var item = shop.current_items[i]
			if item == null or not (item is Dictionary):
				continue
			# 直接走 Shop 的购买入口，保证记账路径一致
			if shop.has_method("_on_buy_pressed"):
				var cards = shop.get_node_or_null("Panel/ItemRow")
				var btn = null
				if cards != null and i < cards.get_child_count():
					btn = shop._find_buy_button(cards.get_child(i))
				if btn != null:
					shop._on_buy_pressed(i, btn, null)

	if shop.has_method("_refresh_sell_area"):
		shop._refresh_sell_area()
	if shop.has_method("_refresh_upgrade_area"):
		shop._refresh_upgrade_area()

	var dir_path := out_path.get_base_dir()
	if dir_path != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://") + dir_path)

func _save() -> void:
	# 等 SubViewport 真的画完一帧再取纹理，否则拿到的是空帧。
	# 注意 `frame_post_draw` 是**全局**渲染信号，与哪个视口无关；
	# 这里等它是为了确保本帧的绘制命令已经提交到 SubViewport 的 RT。
	await RenderingServer.frame_post_draw
	var img: Image = probe_viewport.get_texture().get_image()
	if img == null:
		print("SHOP_CAPTURE_FAIL: 取不到视口纹理")
		quit(1)
		return
	var err = img.save_png(out_path)
	if err != OK:
		print("SHOP_CAPTURE_FAIL: 保存失败 err=%d path=%s" % [err, out_path])
		quit(1)
		return
	print("SHOP_CAPTURE_OK: %s  (%dx%d)" % [out_path, img.get_width(), img.get_height()])
	quit(0)
