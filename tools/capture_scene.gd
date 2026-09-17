extends SceneTree

# 场景截图工具 —— 让视觉改动可以被「看见」，而不是靠脑补
#
# 为什么需要它：本项目的视觉全部由代码程序化绘制（零美术资产），
# 改一个 Color / 尺寸 / 层级的效果只能靠实际渲染出来的画面判断。
# 没有截图，视觉迭代就退化成「改完猜一猜」。
#
# 用法（注意：**不要加 --headless**，无头模式不渲染，截出来是全黑或直接报错）：
#
#   "<godot_console.exe>" --path . --script res://tools/capture_scene.gd \
#       -- --scene=res://scenes/Main.tscn --out=shots/main.png --frames=60
#
# 参数（都跟在 `--` 之后）：
#   --scene=<res://路径>   要截的场景，默认 res://scenes/Main.tscn
#   --out=<路径>           输出 PNG，默认 user://capture.png
#   --frames=<n>           截图前先推进多少帧（让 _ready / 首帧初始化跑完），默认 60
#   --size=WxH             视口尺寸，默认用项目设置（1280x720）
#   --secs=<f>             截图前额外等待的「游戏内」秒数，用于跳过开场动画，默认 0
#   --equip=<武器键>       给玩家装备一把武器（观察近战范围环等）
#   --upgrade=1            强制打开波末升级面板
#
# ─── 状态对齐（做「改前 / 改后」对比的前提）───
#   --seed=<n>             固定全局随机源。不用它的话两次截图之间混着随机噪声，
#                          差异里分不清哪部分是自己的改动。
#   --wave=<n>             设定波次，并同步 HUD 文案；同时把刷怪 / 波次计时全部冻结，
#                          否则晚帧截图会自己跨波甚至走进结算界面。
#   --stage=battle         摆一个**确定的战场**：玩家居中，敌人按固定角度/半径就位
#                          （不杀敌人、不带随机），两次截图得到同一批单位、同一机位。
#   --thaw=1               只摆位不冻结单位（看真实混战用）。默认冻结 —— 冻结后画面
#                          只剩「舞台 + 单位」，适合判断背景本身。
#   --rings=<n>            摆几层同心环（默认 1 = 12 个单位，2 = 24 个），用来压密集混战
#   --god=1                玩家血量顶到 9999，让实时混战能撑到截图那一刻
#                          （否则 12 个敌人 5 秒内就打出 GAME OVER 面板）
#   --bg=<style>           设置 ArenaBackground 的风格（grid / arena / minimal / off），
#                          做方向 A/B 对比；off = 藏掉舞台，是同一份二进制里的性能对照组
#   --minor=<f>            覆盖细网格线透明度（默认 0.16），用来摆「网格要多明显」这一档
#   --effect=<name>        触发一组特效便于目视：pickup / old_pickup / levelup /
#                          old_levelup / crate / wave / probe，或钩子验证
#                          hook_pickup / hook_crate / hook_pickupmanager。
#                          带 old_ 前缀的是**同一份二进制里的对照组**（走的是改造前
#                          那条调用），A/B 时只有「效果本身」这一个变量在变。
#                          配合 --secs=<f> 把截图卡在动画中段。
#                          ⚠ hook_* 与其余的区别很重要：那些 demo 是**截图工具直接调
#                          Effects.\***，只能证明「API 出得来图」；hook_* 一次都不碰
#                          Effects，而是取真对象池里的真单位 + 真实触发条件，由游戏代码
#                          自己发出调用，证明的是「线上真的会调」。
#                          配套 --hook_settle=<n>（触发后等几帧，默认 2）、
#                          --hook_tier=<1-4>、--hook_ptype=<fruit|crate|legendary_crate>、
#                          --hook_value=<n>（hook_pickup 的材料数，默认 3）
#   --settle=<n>           触发特效后先等几帧再继续（默认 8）。短命特效（火花 0.22s、
#                          吸附 0.20s）用默认值会被等到几乎看不见 —— 想卡在最亮的一帧
#                          就用 --settle=1~2。
#
# 诊断：
#   --perf=<n>             用 n 帧（默认 180）实测平均帧耗时 + 节点总数。
#                          会自动关掉垂直同步 —— 否则每帧被锁在 16.7ms，测不出差异。
#   --fps=1                快速打印一次帧率与节点总数
#
# 退出码：0 成功，1 失败（会 print 具体原因）。

const PASS_TAG := "CAPTURE_OK"
const FAIL_TAG := "CAPTURE_FAIL"

# 钩子验证的可调项（见 --effect=hook_*）
var _hook_settle: int = 2       # 触发之后等几帧再截图（卡在动画前段）
var _hook_tier: int = 4         # hook_crate 用的箱子档位 1~4
var _hook_ptype: String = "fruit"  # hook_pickupmanager 用的掉落物类型
var _hook_value: int = 3        # hook_pickup 用的材料数量（太大会顺带触发升级，糊在一张图里）
var _bg_minor: String = ""      # --minor：细网格透明度覆盖值

# 冻结摆场的中心与布局。角度/半径全部写死（不用随机），保证两次截图逐像素可比。
const STAGE_CENTER := Vector2(640.0, 380.0)
const STAGE_UNITS := [
	{"type": "normal", "angle": -90.0, "radius": 205.0},
	{"type": "fast", "angle": -48.0, "radius": 265.0},
	{"type": "tank", "angle": -8.0, "radius": 300.0},
	{"type": "ranged", "angle": 32.0, "radius": 250.0},
	{"type": "armored", "angle": 72.0, "radius": 290.0},
	{"type": "swarm", "angle": 112.0, "radius": 175.0},
	{"type": "ghost", "angle": 148.0, "radius": 305.0},
	{"type": "charger", "angle": 188.0, "radius": 235.0},
	{"type": "healer", "angle": 214.0, "radius": 300.0},
	{"type": "elite", "angle": 246.0, "radius": 195.0},
	{"type": "summoner", "angle": 300.0, "radius": 268.0},
	{"type": "exploder", "angle": 332.0, "radius": 312.0},
]

func _init():
	call_deferred("_run")

func _run():
	var opts := _parse_args()
	var scene_path := str(opts.get("scene", "res://scenes/Main.tscn"))
	var out_path := str(opts.get("out", "user://capture.png"))
	var frames := int(opts.get("frames", 60))
	var secs := float(opts.get("secs", 0.0))
	_hook_settle = max(1, int(opts.get("hook_settle", "2")))
	_hook_tier = clampi(int(opts.get("hook_tier", "4")), 1, 4)
	_hook_ptype = str(opts.get("hook_ptype", "fruit"))
	_bg_minor = str(opts.get("minor", ""))
	_hook_value = maxi(1, int(opts.get("hook_value", "3")))

	# ⚠ 固定随机源必须在**实例化场景之前**做：_ready 里就会消费随机数。
	# 不固定的话，两次截图之间混着随机噪声，看不出改动到底生效没有。
	if opts.has("seed"):
		seed(int(opts.get("seed", 0)))
		print("CAPTURE_SEED %d" % int(opts.get("seed", 0)))

	if not bool(opts.get("size", "").is_empty()):
		var parts := str(opts.get("size", "")).split("x")
		if parts.size() == 2:
			root.size = Vector2i(int(parts[0]), int(parts[1]))

	if not ResourceLoader.exists(scene_path):
		_fail("场景不存在: %s" % scene_path)
		return
	var packed = load(scene_path)
	if packed == null:
		_fail("场景加载失败: %s" % scene_path)
		return

	# 卸掉自动加载的音频，避免非交互环境下卡在音频初始化
	for name in ["AudioManager"]:
		var node = root.get_node_or_null("/root/" + name)
		if node != null:
			root.remove_child(node)
			node.queue_free()

	var instance = packed.instantiate()
	root.add_child(instance)
	# ⚠ 必须把 current_scene 指过去：`--script` 形式不经过正常的场景切换流程，
	# SceneTree.current_scene 默认是 null，而项目里多个系统（Effects 的每个特效、
	# 若干 manager）都以 `get_tree().current_scene` 作为「游戏是否在跑」的判据 ——
	# 漏了这一步的后果是**特效全部静默不出现**（函数提前 return），
	# 排查时极容易误判成「渲染 API 不生效」。
	current_scene = instance

	# 先跑几帧让 _ready / 对象池初始化跑完，再做状态对齐。
	# ⚠ 顺序敏感：状态必须在推进 frames **之前**设好，否则 --thaw=0 的冻结来不及生效，
	#   敌人会在我们摆位之后又跑起来。
	for i in range(3):
		await process_frame

	_apply_wave(instance, int(opts.get("wave", 0)))
	_apply_bg_style(instance, str(opts.get("bg", "")))
	if str(opts.get("stage", "")) != "":
		_apply_stage(instance, str(opts.get("thaw", "0")) == "1", max(1, int(opts.get("rings", "1"))))
	if str(opts.get("god", "")) == "1":
		_apply_god()

	for i in range(max(1, frames)):
		await process_frame

	# 可选：给玩家装一把武器，用于观察武器相关视觉（近战范围环 / 挥击弧等）。
	# 起始武器是手枪，光靠默认场景看不到近战的表现。
	# ⚠ 必须在游戏跑起来之后再做：开局前武器槽位还是 0，equip 会因「槽位已满」失败。
	var equip := str(opts.get("equip", ""))
	if not equip.is_empty():
		var players := get_nodes_in_group("player")
		if players.is_empty():
			print("CAPTURE_WARN 找不到玩家，无法装备 %s" % equip)
		else:
			var combat = players[0].get("combat")
			if combat == null:
				print("CAPTURE_WARN 玩家没有 combat 模块")
			# ⚠ 用 equip_or_combine_weapon 而不是 equip_weapon：
			# 后者是 void（内部调了前者但没 return），拿它的返回值判断永远为假。
			elif combat.equip_or_combine_weapon(equip, 1):
				print("CAPTURE_EQUIP ok %s" % equip)
			else:
				# 装备失败多半是键名不对（WEAPON_DATA 用的是运行时表里的键，不是目录 id）。
				# 直接把可用的近战键列出来，省得下次又来试一遍。
				var sample: Array = []
				var table = combat.get("WEAPON_DATA")
				if table is Dictionary:
					for key in table:
						if bool(table[key].get("melee", false)):
							sample.append(str(key))
							if sample.size() >= 10:
								break
				print("CAPTURE_WARN 装备失败：%s｜槽位 %d / 已装 %d｜可换用近战键: %s" % [
					equip,
					int(players[0].get_max_weapon_slots()),
					Array(players[0].get("equipped_weapons")).size(),
					", ".join(sample)
				])
		# 装备后再跑一段，让武器视觉（范围环 / 挥击）呈现出来
		for i in range(45):
			await process_frame

	# 可选：强制打开波末「选择一项升级」面板，用于审计它的布局
	if str(opts.get("upgrade", "")) != "":
		var players2 := get_nodes_in_group("player")
		var main2 = root.get_node_or_null("Main")
		if players2.is_empty() or main2 == null:
			print("CAPTURE_WARN 找不到玩家或 Main，无法打开升级面板")
		else:
			var hud = main2.get("hud")
			# pop_upgrade_choices() 有前置门 pending_level_ups <= 0 → 返回空，
			# 所以要先造出「有未处理升级」这个状态
			players2[0].pending_level_ups = 1
			var choices: Array = players2[0].pop_upgrade_choices()
			if hud == null or choices.is_empty():
				print("CAPTURE_WARN 升级面板打不开（hud=%s，选项 %d 个）" % [str(hud), choices.size()])
			else:
				hud.show_upgrade_choices(choices)
				print("CAPTURE_UPGRADE ok 选项 %d 个" % choices.size())
				for i in range(20):
					await process_frame

	# 可选：直接触发一组特效，用于目视「反馈层」的手感（不必等它在实战里随机发生）
	var effect := str(opts.get("effect", ""))
	if not effect.is_empty():
		if effect.begins_with("hook_"):
			# 钩子验证：**不直接调 Effects.\***，而是走线上代码的真实分支，
			# 由游戏自己发出效果调用。这是「API 能出图」与「线上真的会调」的分水岭。
			await _run_hook(effect)
		else:
			_demo_effect(effect)
			# ⚠ 特效动画是「真实时间」驱动的：这里每多等一帧，动画就多走 ~16.7ms。
			# 默认 8 帧 ≈ 0.13s，足够把寿命 0.2~0.3s 的短特效（火花 / 吸附）等到几乎消失，
			# 于是截出来「什么都没发生」，让人误以为特效没生效。
			# 想把图卡在动画最亮的那一帧，用 --settle=1~2。
			for i in range(max(1, int(opts.get("settle", "8")))):
				await process_frame
		if effect == "probe":
			_probe_dump("settle 之后")
			# 目视会被「小方块在缩放后的截图里只有几个像素」骗到，所以直接读回像素。
			await RenderingServer.frame_post_draw
			var probe_img: Image = root.get_texture().get_image()
			if probe_img != null:
				probe_img.convert(Image.FORMAT_RGBA8)
				# ⚠ 采样必须走画布变换：主场景里有 Camera2D 时世界坐标 ≠ 屏幕像素，
				# 直接用世界坐标 get_pixelv 会采到别处，然后得出「没画出来」这种假结论。
				var xform := root.canvas_transform
				print("CAPTURE_CANVAS_TRANSFORM %s" % str(xform))
				var bg := probe_img.get_pixelv(_to_screen(xform, Vector2(180.0, 610.0)))
				# 粒子是**散开**的，正中心很可能正好落在两个粒子之间 —— 单点采样会漏。
				# 所以在落点周围扫一块 46x46，报「与背景色差最大的那一个像素」。
				print("CAPTURE_SPARK 命中粒子在落点 ±23px 内的最大色差 = %.4f（背景 %s）" % [
					_max_deviation(probe_img, xform, Vector2(180.0, 470.0), 23, bg), str(bg)
				])
				print("CAPTURE_CONTROL 正对照方块 最大色差 = %.4f" % [
					_max_deviation(probe_img, xform, Vector2(300.0, 610.0), 23, bg)
				])

	if secs > 0.0:
		await create_timer(secs).timeout

	if str(opts.get("fps", "")) != "":
		print("CAPTURE_PERF fps=%.1f 节点总数=%d" % [
			Engine.get_frames_per_second(), _count_nodes(root)
		])

	# 实测帧耗时。⚠ 必须先关垂直同步：否则每帧被锁在 16.7ms，改前改后都是同一个数字，
	# 这个指标就完全失效了。
	if str(opts.get("perf", "")) != "":
		var perf_frames := int(opts.get("perf", "0"))
		if perf_frames <= 0:
			perf_frames = 180
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for i in range(30):  # 先空转，让渲染管线进入稳定状态
			await process_frame
		var t0 := Time.get_ticks_usec()
		for i in range(perf_frames):
			await process_frame
		var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		print("CAPTURE_PERF %.3f ms/帧（%d 帧合计 %.1f ms）· 节点总数=%d" % [
			elapsed_ms / float(perf_frames), perf_frames, elapsed_ms, _count_nodes(root)
		])

	# 必须等这一帧真的画完，否则拿到的是空纹理
	await RenderingServer.frame_post_draw
	var texture := root.get_texture()
	if texture == null:
		_fail("拿不到视口纹理（视口尺寸为 0？）")
		return
	var image: Image = texture.get_image()
	if image == null:
		_fail("视口纹理取不出 Image")
		return

	var dir := out_path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
	var err := image.save_png(out_path)
	if err != OK:
		_fail("保存 PNG 失败（err=%d）: %s" % [err, out_path])
		return

	print("%s %s %dx%d" % [PASS_TAG, out_path, image.get_width(), image.get_height()])
	quit(0)

# ─── 状态对齐 ───

# 设定波次 + 冻结波次推进。刷怪计时器和波次时长都推到很远，
# 否则晚帧截图（--frames=600 以上）会自己跨波，甚至弹结算界面 ——
# 那样「改前」和「改后」比的就不是同一件事了。
func _apply_wave(main, wave: int) -> void:
	if wave <= 0 or main == null:
		return
	main.wave = wave
	var wm = main.get("wave_manager")
	if wm != null:
		wm.spawn_timer = 1.0e9
		wm.tree_spawn_timer = 1.0e9
		wm.landmine_spawn_timer = 1.0e9
		wm.wave_timer = 600.0
	var hud = main.get("hud")
	if hud != null:
		var total = wave
		if wm != null:
			total = int(wm.total_waves())
		hud.update_wave(wave, total)
		hud.update_timer(600.0)
	print("CAPTURE_WAVE wave=%d" % wave)

# 摆一个确定的战场：玩家居中 + 固定角度/半径的一圈敌人。
# 走 main.get_enemy() 的正规对象池入口，所以拿到的是**真实单位**（不是示意图）。
func _apply_stage(main, thaw: bool, rings: int = 1) -> void:
	if main == null:
		print("CAPTURE_WARN 找不到 Main，跳过摆场")
		return
	var players := get_nodes_in_group("player")
	if players.is_empty():
		print("CAPTURE_WARN 找不到玩家，跳过摆场")
		return
	var player = players[0]
	player.position = STAGE_CENTER
	if "velocity" in player:
		player.velocity = Vector2.ZERO

	var wave_num := 1
	if "wave" in main:
		wave_num = int(main.wave)
	var placed := 0
	# rings>1 时把同一套角度复制成多层同心环：用来压出一张「密集混战」的图
	# （刷怪计时器已被冻结，靠等时间是等不到敌人的）。
	for ring in range(max(1, rings)):
		for entry in STAGE_UNITS:
			var unit = main.get_enemy()
			if unit == null:
				continue
			unit.setup(str(entry["type"]), wave_num)
			var a := deg_to_rad(float(entry["angle"]) + float(ring) * 11.0)
			var radius := float(entry["radius"]) + float(ring) * 118.0
			unit.position = STAGE_CENTER + Vector2(cos(a), sin(a)) * radius
			if "velocity" in unit:
				unit.velocity = Vector2.ZERO
			placed += 1

	if not thaw:
		# ⚠ set_process 必须在**入树之后**调用才生效（对象池技能 §3）。
		# 冻结后画面只剩「舞台 + 单位」，适合判断背景；thaw=1 时保留真实混战。
		player.set_physics_process(false)
		player.set_process(false)
		for packed_unit in get_nodes_in_group("enemies"):
			packed_unit.set_physics_process(false)
			packed_unit.set_process(false)
	print("CAPTURE_STAGE placed=%d thaw=%s" % [placed, str(thaw)])

# 打开上帝模式：把玩家血量顶到很高，让实时混战能持续到截图那一刻。
# 不做这一步的话，12 个敌人会在 5 秒内把玩家打死，截到的是 GAME OVER 面板 ——
# 那样看不到「单位在舞台上移动」这件事本身。
func _apply_god() -> void:
	var players := get_nodes_in_group("player")
	if players.is_empty():
		print("CAPTURE_WARN 找不到玩家，--god 被忽略")
		return
	var player = players[0]
	player.max_hp = 9999
	player.hp = 9999
	if "hp_changed" in player:
		player.hp_changed.emit(9999, 9999)
	print("CAPTURE_GOD hp=9999")

func _apply_bg_style(main, style: String) -> void:
	if main == null:
		return
	var bg = main.get_node_or_null("ArenaBackground")
	if bg == null:
		if not style.is_empty() or not _bg_minor.is_empty():
			print("CAPTURE_WARN 场景里没有 ArenaBackground 节点，--bg/--minor 被忽略")
		return
	# --bg=off 直接把舞台整个藏掉：这是**同一份二进制**里的对照组，
	# 用它量舞台到底吃了多少帧时间，比跟改前的旧版本比可靠得多
	# （旧版本的测量隔了一次重新编译与一段系统时间，噪声不可控）。
	if style == "off":
		bg.visible = false
		print("CAPTURE_BG style=off (舞台已隐藏)")
	elif not style.is_empty():
		if not ("style" in bg):
			print("CAPTURE_WARN ArenaBackground 没有 style 属性，--bg 被忽略")
		else:
			bg.set("style", style)
			print("CAPTURE_BG style=%s" % style)
	# 细网格透明度：把「网格要多明显」摆成可对比的一档，便于选型
	if not _bg_minor.is_empty() and ("grid_minor_alpha" in bg):
		bg.set("grid_minor_alpha", float(_bg_minor))
		print("CAPTURE_BG grid_minor_alpha=%s" % _bg_minor)


# ─── 特效目视 ───

# ─── 真实钩子验证 ───
#
# 为什么要有这一组：`--effect=pickup` 只证明了「Effects.material_pickup 被单独调用时能出图」，
# 它证明不了**线上真的会调**。方案乙（只交 API + 截图）栽的就是这一点。
# 所以这里刻意**一次都不碰 Effects.\***：取真实对象池里的真单位，构造真实的触发条件，
# 让游戏代码自己把效果发出来。
func _run_hook(name: String) -> void:
	var main = root.get_node_or_null("Main")
	if main == null:
		print("CAPTURE_WARN hook 需要 Main 节点")
		return
	var players := get_nodes_in_group("player")
	if players.is_empty():
		print("CAPTURE_WARN hook 需要玩家")
		return
	var player = players[0]

	match name:
		"hook_pickup":
			# 材料拾取：从 main 的经验球池取一个真球，activate 之后**不做任何别的动作**，
			# 让它靠自己的磁吸逻辑飞向玩家，由 Area2D.body_entered 触发 XPOrb.collect()。
			# 效果由此产生 —— 调用栈里没有一行是截图工具写的。
			var orb = main.get_xp_orb()
			if orb == null:
				print("CAPTURE_WARN 拿不到经验球")
				return
			orb.activate(player.position + Vector2(-118.0, 56.0), int(_hook_value))
			var frames := 0
			while bool(orb.get("_active")) and frames < 300:
				await process_frame
				frames += 1
			if bool(orb.get("_active")):
				print("CAPTURE_WARN 经验球 %d 帧内没被撞到（玩家碰撞体没生效？）" % frames)
				return
			print("HOOK_PICKUP 经 XPOrb.collect() 触发，磁吸飞行 %d 帧；工具未直接调用 Effects.*" % frames)
			for i in range(max(1, int(_hook_settle))):
				await process_frame
		"hook_crate":
			# 开箱：走 Main.enqueue_crate_reward() → _on_crate_reward_taken()，
			# 也就是玩家在箱子里点「领取」时的那条真实路径。
			main.enqueue_crate_reward(int(_hook_tier))
			var pending: Array = main.get("pending_crate_rewards")
			if pending == null or pending.is_empty():
				print("CAPTURE_WARN 箱子奖励没入队（shop.ITEM_POOL 为空？）")
				return
			var before := pending.size()
			main._on_crate_reward_taken(0)
			# ⚠ 领取之后真实流程会立刻把「商店」面板推上来（_resolve_next_level_up_or_shop），
			# 整个屏幕被盖住、光效全看不见。为了截图**只把面板藏起来**，
			# 不动任何游戏状态 —— 而且这一步是在效果已经发出之后才做的，
			# 取消不了「钩子确实被调用过」这个事实（日志里有队列变化）。
			var shop = main.get("shop")
			if shop is CanvasLayer:
				(shop as CanvasLayer).visible = false
			var hud = main.get("hud")
			if hud != null and hud.has_method("hide_crate_reward"):
				hud.hide_crate_reward()
			print("HOOK_CRATE 经 Main._on_crate_reward_taken() 触发；奖励队列 %d → %d，crate_tier=%d"
				% [before, main.pending_crate_rewards.size(), int(_hook_tier)]
				+ "（截图时已把随后弹出的商店面板藏起，游戏状态未改）")
			for i in range(max(1, int(_hook_settle))):
				await process_frame
		"hook_pickupmanager":
			# 场景掉落物（水果 / 箱子）：走 PickupManager._on_pickup_collected()，
			# 也就是玩家碰到掉落物时的那条真实路径。
			var pm = main.get("pickup_manager")
			if pm == null:
				print("CAPTURE_WARN 场景里没有 pickup_manager")
				return
			var pool: Array = pm.get("_pool_available")
			if pool == null or pool.is_empty():
				print("CAPTURE_WARN 掉落物池是空的")
				return
			var pickup = pool[0]
			pickup.visible = true
			pickup.position = player.position + Vector2(104.0, -66.0)
			pm._on_pickup_collected(player, pickup, str(_hook_ptype))
			print("HOOK_PICKUP_MANAGER 经 _on_pickup_collected() 触发，ptype=%s" % str(_hook_ptype))
			for i in range(max(1, int(_hook_settle))):
				await process_frame
		_:
			print("CAPTURE_WARN 未知钩子 %s（可用：hook_pickup / hook_crate / hook_pickupmanager）" % name)

func _demo_effect(effect: String) -> void:
	var effects = root.get_node_or_null("/root/Effects")
	if effects == null:
		print("CAPTURE_WARN 找不到 Effects 自动加载，无法演示 %s" % effect)
		return
	var players := get_nodes_in_group("player")
	var pos := STAGE_CENTER
	if not players.is_empty():
		pos = players[0].position
	match effect:
		"pickup":
			# 一排材料在玩家周围被「吸」进来：最后一个是高价值（会带 +N 文字）
			for i in range(5):
				effects.material_pickup(pos + Vector2(-160.0 + float(i) * 80.0, 70.0), 1, Color(0.3, 1, 0.4))
			effects.material_pickup(pos + Vector2(0, -80), 12, Color(0.3, 1, 0.4))
		"old_pickup":
			# 对照组：这就是改造前 XPOrb.collect() 实际调用的那一个效果。
			# 同一份二进制、同一批位置、同一时刻触发 —— 只有「效果本身」不同，
			# 这样 A/B 才成立（不用去 git stash 旧版本，避免混入别的变量）。
			for i in range(5):
				effects.hit_spark(pos + Vector2(-160.0 + float(i) * 80.0, 70.0), Color(0.3, 1, 0.4))
			effects.hit_spark(pos + Vector2(0, -80), Color(0.3, 1, 0.4))
		"levelup":
			effects.level_up_burst(pos)
		"old_levelup":
			# 对照组：改造前的 level_up_burst 就是「一把 _burst」，
			# 观感与 death_burst 同类（12 粒子、向外炸开、无环无光柱）。
			effects.death_burst(pos, Color(0.4, 1.0, 0.5))
		"crate":
			effects.crate_open_burst(pos, 4)
		"probe":
			# 状态探针：在**空地上**放一次火花，并把池内实例的真实状态打出来。
			# 「应该画了却没出现」时，先确认「到底有没有对象、可不可见」，
			# 而不是继续猜渲染 API。
			var far := Vector2(180.0, 470.0)
			effects.hit_spark(far, Color(1, 0, 1))
			# 负对照：扁平 float 数组写的多边形。
			# ⚠ 这种写法**不会**生成 4 个点，而是把 8 个 float 各自转成 Vector2(0,0)，
			# 得到零面积多边形 —— 节点在树里、visible=true、颜色正常，屏幕上一个像素都不画。
			# 这是本项目 Effects.gd 里潜伏了很久的坑（所有爆散粒子都因此不可见）。
			var bad := Polygon2D.new()
			bad.name = "ProbeBadFlatArray"
			bad.polygon = PackedVector2Array([-10, -10, 10, -10, 10, 10, -10, 10])
			bad.color = Color(1.0, 0.15, 0.15)
			bad.position = Vector2(180.0, 610.0)
			effects.add_child(bad)
			# 正对照：同样形状，但用显式 Vector2。
			var good := Polygon2D.new()
			good.name = "ProbeGoodVector2"
			good.polygon = PackedVector2Array([
				Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
			])
			good.color = Color(0.55, 1.0, 0.1)
			good.position = Vector2(300.0, 610.0)
			effects.add_child(good)
			print("CAPTURE_PROBE 多边形点数：扁平写法=%d 显式写法=%d；扁平写法解析结果=%s" % [
				bad.polygon.size(), good.polygon.size(), str(bad.polygon)
			])
			_probe_dump("触发瞬间")
		"wave":
			var total := 20
			var main = root.get_node_or_null("Main")
			if main != null and "wave_manager" in main and main.wave_manager != null:
				total = int(main.wave_manager.total_waves())
			effects.wave_intro(int(main.wave) if main != null else 1, total, "")
		_:
			print("CAPTURE_WARN 未知特效名 %s（可用：pickup / old_pickup / levelup / old_levelup / crate / wave）" % effect)
			return
	print("CAPTURE_EFFECT %s" % effect)

# 把 Effects 下所有可见根节点及其子绘图节点的**实时**状态打出来。
# delay 之后调用才有意义：Tween 是真实时间驱动的，触发瞬间 position 必然还是 0。
func _probe_dump(tag: String) -> void:
	var effects = root.get_node_or_null("/root/Effects")
	if effects == null:
		return
	var solids: Array[String] = []
	for child in effects.get_children():
		if child is Node2D and child.visible:
			var parts: Array[String] = []
			for sub in child.get_children():
				if sub is Polygon2D or sub is Line2D:
					if not sub.visible:
						continue
					var alpha := 1.0
					if sub is Polygon2D:
						alpha = (sub as Polygon2D).color.a
					else:
						alpha = (sub as Line2D).default_color.a
					parts.append("a=%.2f gpos=%s" % [alpha, str(sub.get_global_position())])
			solids.append("root(name=%s z=%d zrel=%s gpos=%s inv=%s) %s" % [
				str(child.name), int(child.z_index), str(child.z_as_relative),
				str(child.get_global_position()), str(child.is_visible_in_tree()),
				", ".join(parts)
			])
	print("CAPTURE_PROBE[%s] 可见根节点 %d 个" % [tag, solids.size()])
	for line in solids:
		print("CAPTURE_PROBE[%s] %s" % [tag, line])

# 世界坐标 → 视口像素
func _to_screen(xform: Transform2D, world: Vector2) -> Vector2i:
	var p: Vector2 = xform * world
	return Vector2i(int(p.x), int(p.y))

# 以 center 为心、边长 2*radius 的方框内，与参考色 bg 的最大通道差。
# 用来回答「这里到底画没画东西」—— 单点采样会漏掉散开的粒子。
func _max_deviation(img: Image, xform: Transform2D, center: Vector2, radius: int, bg: Color) -> float:
	var c := _to_screen(xform, center)
	var worst := 0.0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var px := img.get_pixelv(Vector2i(x, y))
			var d: float = maxf(absf(px.r - bg.r), maxf(absf(px.g - bg.g), absf(px.b - bg.b)))
			if d > worst:
				worst = d
	return worst

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

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

func _fail(message: String):
	print("%s %s" % [FAIL_TAG, message])
	push_error(message)
	quit(1)
