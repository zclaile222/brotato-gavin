extends SceneTree

# ═══════════════════════════════════════════════════════════════════════════════
# 子弹出界判定探针 —— 诊断工具，不是回归套件
#
# 为什么放在 tools/ 而不是 tests/：
#   ① tests/ 里的东西会被 run_all.sh 当成「回归契约」，那是另一种约定（必须长期为真）；
#      本探针只是**一次性诊断**，结论进入证据链之后就完成使命了。
#   ② run_all.sh 的用例清单是多人在改的公共文件，把一个诊断工具塞进去只会制造无谓冲突。
#
# 被检验的假说（机制层）：
#   `scripts/Bullet.gd:178-182` 每帧把位置推进之后，用 `get_viewport_rect().size` 划出一个
#   [-50, w+50] × [-50, h+50] 的「框」，出框即 `_return_to_pool()`。
#   在 headless 运行（= 全部冒烟测试与 run_all.sh 的环境）里根视口只有 64×64，
#   而战场坐标空间是 1280×720、玩家固定在 (427, 325)。于是**任何在玩家身上生成的子弹，
#   第一次 `_process` 就已经在框外** → 存活帧数恒为 1 → headless 下子弹活不过一帧。
#
# 观测手段（刻意与「按危险模型推导」不同源 —— 这是从 Bullet.gd **外部**看行为）：
#   只用两个可观测信号，不读私有状态、不改产品代码一行：
#     ① 死亡点空间分布（可见 → 不可见的那一帧，最后一次被看到的位置在框内还是框外）
#     ② 存活帧数分布
#
# ── 预写死的判伪条件（观测之前写下，事后不改）────────────────────────────
#   ① 若死亡点中有 **≥10%**（OUTSIDE_TOLERANCE）落在框内 → 假说被推翻。
#   ② 若「生成点在框外」这一类样本的**存活帧数众数 ≠ 1** → 假说被推翻。
#   ③ 若实测视口尺寸 ≠ 64×64 → 前置条件不成立，**停下上报，不强行取数**。
#
# ── 对照设计（同一帧、同一批参数，唯一变量是「生成点在框内还是框外」）──────
#   A = 玩家当前位置      （假说预测：框外，存活 1 帧）
#   B = 框正中心          （假说预测：框内，能活多帧）
#   C = 框内、距右界 10px  （标定：框右界确实在 w+50）
#   D = 框外 1px          （标定：越界即死）
#   四发都临时把 collision_mask 置 0，让「死亡」只可能来自出界判定而不是撞到敌人
#   （撞死会污染归因），用完立刻复原并归还池中。
#
#   存活帧数的口径：activate() 之后**同步**读一次 visible（必为 true，activate 里设的），
#   之后每 `await process_frame` 观测一次。两次观测之间恰好跑一遍节点的 `_process`，
#   所以 存活帧数 = 观测到 visible 的次数 + 1。这个 +1 写在代码里，不是事后凑的。
#
# ── 差分实验（--size=WxH）──────────────────────────────────────────────
#   把根视口撑到 1280×720 再跑一遍。若上面那套签名（A 存活 1 帧、死亡点密集在框外）
#   消失，说明「框的尺寸」确实是因果变量，而不只是相关。
#   ⚠ 已知陷阱：历史上 `root.size = Vector2i(1280,720)` 会让 Main 起不来
#   （hud / player 解析不到）。撞到就**停下上报，不改产品代码去迁就它**。
#
# ── 用法（必须 headless：64×64 视口就是 headless 的产物，带渲染跑反而不复现）──
#   "<godot_console.exe>" --headless --path . --script res://tools/probe_bullet_viewport.gd \
#       -- --frames=600 --out=shots/bullet_viewport_probe.txt
#   "<godot_console.exe>" --headless --path . --script res://tools/probe_bullet_viewport.gd \
#       -- --size=1280x720 --frames=600 --out=shots/bullet_viewport_probe_diff1280x720.txt
#
# 输出：同时打到 stdout 与 --out 指定的文本文件（默认 shots/bullet_viewport_probe.txt），
#       行前缀一律 BULLET_*。
# ⚠ 本探针**刻意不打** `*_SMOKE_PASS` 标记、**不进** tests/run_all.sh —— 那是回归套件的约定。
#
# 退出码：0 = 探针完整跑完（结论看 BULLET_VERDICT）；1 = 前置条件不成立 / 环境异常（看 BULLET_PRECONDITION | BULLET_TRAP）。
# ═══════════════════════════════════════════════════════════════════════════════

const TAG := "BULLET_PROBE"
const SPEED := 500.0
const EDGE_MARGIN := 50.0
# 判伪条件①的阈值。「非平凡比例」在观测之前就定死成 10%，避免事后挑数字。
const OUTSIDE_TOLERANCE := 0.10
const EXPECTED_VIEW := Vector2(64.0, 64.0)
const POOL_SIZE_EXPECTED := 80

var _log_file: FileAccess = null
var _size_override := Vector2i.ZERO
var _group := "baseline"

func _init():
	call_deferred("_run")

func _run() -> void:
	var opts := _parse_args()
	var frames: int = maxi(60, int(opts.get("frames", "600")))
	var out_path := str(opts.get("out", "shots/bullet_viewport_probe.txt"))
	if not _open_log(out_path):
		quit(1)
		return

	_log("%s BEGIN engine=%s" % [TAG, str(Engine.get_version_info().get("string", "?"))])
	_log("%s CMD %s" % [TAG, " ".join(OS.get_cmdline_args())])

	if opts.has("size"):
		var parts := str(opts.get("size", "")).split("x")
		if parts.size() == 2:
			_size_override = Vector2i(int(parts[0]), int(parts[1]))
			_group = "differential"
			root.size = _size_override
			_log("%s DIFFERENTIAL 根视口已设为 %s —— 本组的目的是让假说的签名**消失**（因果检验）"
				% [TAG, str(_size_override)])
	_log("%s GROUP %s frames=%d" % [TAG, _group, frames])
	_log("%s PREREG 判伪① 死亡点落在框内的比例 ≥ %.0f%% 即推翻；判伪② 框外生成样本的存活帧数众数 ≠ 1 即推翻；判伪③ 实测视口 ≠ 64×64 即前置不成立"
		% [TAG, OUTSIDE_TOLERANCE * 100.0])

	seed(1234)
	for i in range(3):
		await process_frame
	_measure_env("Main 实例化之前")

	# 声音系统在非交互环境会拖初始化；测试与截图工具都先把它摘掉，这里保持一致。
	for name in ["AudioManager"]:
		var node = root.get_node_or_null("/root/" + name)
		if node != null:
			root.remove_child(node)
			node.queue_free()

	var packed = load("res://scenes/Main.tscn")
	if packed == null:
		_log("%s TRAP Main.tscn 加载失败，停下上报" % TAG)
		_finish(1)
		return
	var main = packed.instantiate()
	root.add_child(main)
	# ⚠ 同 capture_scene：`--script` 形式不经过正常场景切换，SceneTree.current_scene 默认为 null，
	# 而项目里多个系统以它为「游戏是否在跑」的判据 —— 缺这一步会让一批效果静默 no-op。
	current_scene = main
	for i in range(8):
		await process_frame

	if not is_instance_valid(main):
		_log("%s TRAP Main 实例无效，停下上报" % TAG)
		_finish(1)
		return
	var player = main.get("player")
	var hud = main.get("hud")
	if player == null or hud == null:
		_log("%s TRAP 场景起不来：player=%s hud=%s —— 这就是 team-lead 警告过的 root.size 陷阱。"
			% [TAG, str(player), str(hud)])
		_log("%s TRAP 按约定停下上报，不绕过、不改产品代码去迁就它。" % TAG)
		_finish(1)
		return

	_measure_env("Main 就绪之后")

	# ⚠ 视口必须从**一枚真子弹**身上量：Bullet.gd 用的就是 `get_viewport_rect().size`，
	# 而 root.size 与它之间还隔着窗口 / 画布链路，量 root 不等价。
	var view := Vector2.ZERO
	if main.has_method("get_bullet"):
		var probe_bullet = main.get_bullet()
		if probe_bullet != null:
			view = probe_bullet.get_viewport_rect().size
			if probe_bullet.has_method("_return_to_pool"):
				probe_bullet._return_to_pool()
	if view == Vector2.ZERO:
		view = root.get_visible_rect().size
		_log("%s WARN 子弹上量不到视口，退回 root.get_visible_rect() = %s" % [TAG, str(view)])
	_log("%s ENV VIEW_FROM_BULLET %s  ← Bullet.gd 用的就是这一句 get_viewport_rect().size"
		% [TAG, str(view)])

	var pool: Array = main.get("bullet_pool")
	_log("%s ENV 玩家子弹池实例数 = %d（Main.BULLET_POOL_SIZE 期望 %d）"
		% [TAG, pool.size(), POOL_SIZE_EXPECTED])

	var box := Rect2(Vector2(-EDGE_MARGIN, -EDGE_MARGIN), Vector2(view.x + EDGE_MARGIN * 2.0, view.y + EDGE_MARGIN * 2.0))
	_log("%s ENV BOX 左上（-50,-50）右下（%.1f,%.1f）；玩家位置=%s；玩家在框内=%s"
		% [TAG, box.end.x, box.end.y, str(player.position), str(box.has_point(player.position))])

	if _size_override == Vector2i.ZERO:
		# 判伪条件③：前置条件。不成立就停下上报，不强行取数。
		if not (is_equal_approx(view.x, EXPECTED_VIEW.x) and is_equal_approx(view.y, EXPECTED_VIEW.y)):
			_log("%s PRECONDITION FAIL 实测视口 %s ≠ 期望 %s —— 假说的前置条件不成立。"
				% [TAG, str(view), str(EXPECTED_VIEW)])
			_log("%s PRECONDITION 按约定停下上报，不强行解释；本组到此为止（未进入观测阶段）。" % TAG)
			_finish(1)
			return
		_log("%s PRECONDITION PASS 实测视口 = %s，与假说的前置条件一致" % [TAG, str(view)])

	# ── 阶段 P：被动观测（只给上限，不给归因）──
	var passive := await _observe_passive(frames)
	_log("%s PASSIVE 观测 %d 帧：有可见子弹的帧数=%d 帧内同时可见的峰值=%d 记录到的死亡事件=%d 起"
		% [TAG, frames, int(passive["frames_with_live"]), int(passive["peak_live"]), Array(passive["deaths"]).size()])
	_log("%s PASSIVE 每帧可见子弹数直方图 %s" % [TAG, _hist_text(passive["live_hist"])])
	_log("%s PASSIVE 每帧处理中子弹数直方图 %s" % [TAG, _hist_text(passive["busy_hist"])])

	# ── 阶段 C：受控对照（归因靠这一阶段）──
	var records := await _observe_controlled(main, player, view, frames)

	# ── 汇总与判定 ──
	var deaths: Array = []
	deaths.append_array(passive["deaths"])
	for r in records:
		if int(r["death_obs"]) >= 0:
			deaths.append(r)
	_log("%s TOTAL 死亡事件合计 %d 起（被动 %d + 受控 %d）"
		% [TAG, deaths.size(), Array(passive["deaths"]).size(), records.size()])

	var inside_raw := 0
	var inside_pred := 0
	var lifetime_hist := {}
	for d in deaths:
		var last: Vector2 = d["last"]
		var pred: Vector2 = _predicted_death(d)
		if box.has_point(last):
			inside_raw += 1
		if box.has_point(pred):
			inside_pred += 1
		var f: int = _lifetime_frames(d)
		lifetime_hist[f] = int(lifetime_hist.get(f, 0)) + 1
	var ratio_raw := float(inside_raw) / float(maxi(1, deaths.size()))
	_log("%s DEATHS 存活帧数直方图 %s" % [TAG, _hist_text(lifetime_hist)])
	_log("%s DEATHS 死亡点按「最后一次被看到的位置」判：框内 %d / 框外 %d，框内占比 %.1f%%（阈值 %.0f%%）"
		% [TAG, inside_raw, deaths.size() - inside_raw, ratio_raw * 100.0, OUTSIDE_TOLERANCE * 100.0])
	_log("%s DEATHS 死亡点按「位置 + 一帧位移」外推后判：框内 %d / 框外 %d"
		% [TAG, inside_pred, deaths.size() - inside_pred])

	# 判伪条件②：只取**生成点已知在框外**的受控样本（玩家位置 A、框外 1px D）。
	# 被动阶段的样本看到子弹时它已经在飞，生成点不可知，因此不参与② —— 这是保守取值。
	var outside_class: Array = []
	for r in records:
		if int(r["death_obs"]) < 0:
			continue
		if not box.has_point(r["spawn"]):
			outside_class.append(_lifetime_frames(r))
	var mode := _mode_of(outside_class)
	_log("%s CLASS 框外生成样本（受控）存活帧数 = %s，众数=%d，最大=%d"
		% [TAG, str(outside_class), mode, _max_of(outside_class)])

	# 差分实验要比的是**同一发**：A（玩家身上）在两组的存活帧数。
	# 用 A 而不是整个 class —— D 是按新框的边界定义的，换了视口它照样在框外，
	# 把 D 混进来会让「签名是否消失」永远得不出变化。
	var anchor_a: Dictionary = {}
	for r in records:
		if str(r["label"]) == "A_player_position":
			anchor_a = r
			break
	var a_outside := not anchor_a.is_empty() and not box.has_point(anchor_a["spawn"])
	var a_life := -1
	if not anchor_a.is_empty() and int(anchor_a["death_obs"]) >= 0:
		a_life = _lifetime_frames(anchor_a)
	_log("%s ANCHOR_A 生成点=%s 在框内=%s 存活帧数=%s"
		% [TAG, str(anchor_a.get("spawn", Vector2.ZERO)), str(not a_outside),
			("未知（观测窗口内未死）" if a_life < 0 else str(a_life))])
	# 假说的签名 = 「生成点在框外」且「首帧就被回收」。两条同时成立才叫签名在。
	var signature_present := a_outside and a_life == 1
	_log("%s SIGNATURE 玩家身上生成的子弹「首帧即出界回收」= %s" % [TAG, str(signature_present)])

	var fail_reasons: Array = []
	if ratio_raw >= OUTSIDE_TOLERANCE:
		fail_reasons.append("判伪①：死亡点框内占比 %.1f%% ≥ %.0f%%" % [ratio_raw * 100.0, OUTSIDE_TOLERANCE * 100.0])
	if outside_class.is_empty():
		_log("%s CLASS 本组没有「生成点在框外」的受控样本 —— 判伪② 无法评估（既不算支持也不算推翻）" % TAG)
	elif mode != 1:
		fail_reasons.append("判伪②：框外生成样本的存活帧数众数 %d ≠ 1" % mode)

	if _group == "differential":
		if signature_present:
			_log("%s VERDICT DIFFERENTIAL 签名**未消失**：视口撑到 %s 之后，玩家身上生成的子弹仍然首帧即出界 —— 说明「框的尺寸」不是唯一原因"
				% [TAG, str(_size_override)])
		else:
			_log("%s VERDICT DIFFERENTIAL 签名**消失**：视口撑到 %s 之后，同一发（玩家身上生成）不再首帧即出界 —— 与「框的尺寸是因果变量」一致"
				% [TAG, str(_size_override)])
	elif fail_reasons.is_empty() and signature_present:
		_log("%s VERDICT SUPPORTED 假说在 %s 组成立：子弹在 headless 下首次 _process 即出界回收" % [TAG, _group])
	elif not fail_reasons.is_empty():
		_log("%s VERDICT FALSIFIED 假说在 %s 组被推翻：%s" % [TAG, _group, "；".join(fail_reasons)])
	else:
		_log("%s VERDICT INCONCLUSIVE 两条判伪条件都没被触发，但签名也不完整（见上面 SIGNATURE 行）" % TAG)
	_finish(0)

# ─── 阶段 P：被动观测 ───
#
# 只读地数一遍 bullets 组：每帧有多少发可见、多少发正在处理。
# ⚠ 这一阶段**给不出归因**，只给上限：存活短于一个观测间隔的子弹会在两个观测点之间生灭，
#   轮询根本看不见它 —— 而「几乎看不见」恰恰是假说预测的形态。
#   所以这里同时报「处理中」的计数：它是「有子弹被激活过」的旁证（activate() 会 set_process(true)）。
func _observe_passive(frames: int) -> Dictionary:
	var tracked := {}
	var deaths: Array = []
	var live_hist := {}
	var busy_hist := {}
	var frames_with_live := 0
	var peak_live := 0
	var raw_printed := 0
	for i in range(frames):
		await process_frame
		var seen := {}
		var live := 0
		var busy := 0
		for b in get_nodes_in_group("bullets"):
			if not is_instance_valid(b):
				continue
			if b.is_processing():
				busy += 1
			if not b.visible:
				continue
			var id: int = b.get_instance_id()
			seen[id] = true
			live += 1
			if tracked.has(id):
				var rec: Dictionary = tracked[id]
				var prev: Vector2 = rec["prev"]
				rec["steps"].append(prev.distance_to(b.position))
				rec["frames"] = int(rec["frames"]) + 1
				rec["prev"] = b.position
				rec["last"] = b.position
			else:
				tracked[id] = {
					"frames": 1, "prev": b.position, "last": b.position,
					"first": b.position, "steps": [], "source": "passive",
					"death_obs": i,
				}
		# 上一帧还在、这一帧不见了 = 一次死亡
		for id in tracked.keys():
			if not seen.has(id):
				deaths.append(tracked[id])
				tracked.erase(id)
		live_hist[live] = int(live_hist.get(live, 0)) + 1
		busy_hist[busy] = int(busy_hist.get(busy, 0)) + 1
		if live > 0:
			frames_with_live += 1
		if live > peak_live:
			peak_live = live
		# 原始逐帧行只打「有动静」的帧（否则 600 行会把结论淹掉）；直方图已经覆盖了全量。
		if (live > 0 or busy > 0) and raw_printed < 60:
			_log("%s PASSIVE_FRAME frame=%d 可见=%d 处理中=%d" % [TAG, i, live, busy])
			raw_printed += 1
	return {
		"deaths": deaths, "live_hist": live_hist, "busy_hist": busy_hist,
		"frames_with_live": frames_with_live, "peak_live": peak_live,
	}

# ─── 阶段 C：受控对照 ───
func _observe_controlled(main, player, view: Vector2, frames: int) -> Array:
	var right_edge := view.x + EDGE_MARGIN   # Bullet.gd 的判据：position.x > screen.x + 50 即出界
	var anchors := [
		{"label": "A_player_position", "pos": player.position,
			"why": "玩家身上 —— 假说预测：框外，存活 1 帧"},
		{"label": "B_viewport_center", "pos": Vector2(view.x * 0.5, view.y * 0.5),
			"why": "框正中心 —— 假说预测：框内，能活多帧"},
		{"label": "C_edge_inside", "pos": Vector2(right_edge - 10.0, view.y * 0.5),
			"why": "框内距右界 10px —— 标定右界确实在 %.1f" % right_edge},
		{"label": "D_edge_outside", "pos": Vector2(right_edge + 1.0, view.y * 0.5),
			"why": "框外 1px —— 标定越界即死"},
	]
	var box := Rect2(Vector2(-EDGE_MARGIN, -EDGE_MARGIN), Vector2(view.x + EDGE_MARGIN * 2.0, view.y + EDGE_MARGIN * 2.0))

	var records: Array = []
	for a in anchors:
		var b = main.get_bullet()
		if b == null or not is_instance_valid(b):
			_log("%s WARN 池里拿不到子弹，跳过 %s" % [TAG, a["label"]])
			continue
		var saved_mask: int = int(b.collision_mask)
		# 屏蔽碰撞：让「死亡」只可能来自出界判定，而不是撞到敌人（否则归因被污染）。
		# 这只是临时改这一枚池对象的属性，用完复原 —— 产品代码一行不动。
		b.collision_mask = 0
		b.activate(a["pos"], Vector2.RIGHT, SPEED, Color(1.0, 0.5, 0.2), player, 1)
		records.append({
			"label": str(a["label"]), "why": str(a["why"]), "node": b,
			"spawn": a["pos"], "last": a["pos"], "prev": a["pos"],
			"steps": [], "frames": 0, "death_obs": -1, "alive": true,
			"first_obs_done": false, "first_obs_visible": false,
			"visible_at_activation": bool(b.visible), "saved_mask": saved_mask,
			"source": "controlled",
		})
		_log("%s CONTROLLED_SPAWN %s pos=%s 生成点在框内=%s ｜ %s"
			% [TAG, a["label"], str(a["pos"]), str(box.has_point(a["pos"])), a["why"]])

	var obs := 0
	while obs < frames:
		await process_frame
		obs += 1
		var any_alive := false
		for r in records:
			if not bool(r["alive"]):
				continue
			var b = r["node"]
			if not is_instance_valid(b):
				r["alive"] = false
				continue
			var vis: bool = b.visible
			if not bool(r["first_obs_done"]):
				r["first_obs_done"] = true
				r["first_obs_visible"] = vis
			_log("%s TRACE %s obs=%d visible=%s pos=%s" % [TAG, r["label"], obs, str(vis), str(b.position)])
			if vis:
				# 第一次观测也有位移可测（prev 初始值就是生成点），所以不跳过 —— 样本本来就少。
				var prev: Vector2 = r["prev"]
				r["steps"].append(prev.distance_to(b.position))
				r["prev"] = b.position
				r["last"] = b.position
				r["frames"] = int(r["frames"]) + 1
				any_alive = true
			else:
				r["alive"] = false
				r["death_obs"] = obs
		if not any_alive:
			break

	# 汇总 + 复原现场
	for r in records:
		var b = r["node"]
		var step := _mean_of(r["steps"])
		var lifetime_text := "未知（%d 次观测内未死）" % obs
		if int(r["death_obs"]) >= 0:
			lifetime_text = str(_lifetime_frames(r))
		var step_text := "未知"
		if step >= 0.0:
			step_text = "%.3f px" % step
		var last: Vector2 = r["last"]
		var pred: Vector2 = _predicted_death(r)
		_log("%s CONTROLLED %s spawn=%s 激活瞬间可见=%s 存活帧数=%s 首次观测即可见=%s 死亡于第 %d 次观测 最后可见位置=%s 该位置在框内=%s 每帧位移=%s 外推死亡点=%s 外推点在框内=%s"
			% [TAG, r["label"], str(r["spawn"]), str(r["visible_at_activation"]), lifetime_text,
				str(r["first_obs_visible"]), int(r["death_obs"]), str(last),
				str(box.has_point(last)), step_text, str(pred), str(box.has_point(pred))])
		if is_instance_valid(b):
			b.collision_mask = int(r["saved_mask"])
			if b.has_method("_return_to_pool"):
				b._return_to_pool()
	_log("%s CONTROLLED_RESTORE 四发的 collision_mask 已复原、已归还池中" % TAG)
	return records

# 存活帧数的口径（与文件头一致）：
#   受控样本在 activate() 之后**同步**读过一次 visible（activate 里设的，必为 true），
#   之后每 `await process_frame` 观测一次，两次观测之间恰好跑一遍节点的 `_process`，
#   所以 真实存活帧数 = 观测到 visible 的次数 + 1。
#   被动样本看不到「激活那一刻」，只能给**下界**（观测到几次就是几次），因此不加 1。
func _lifetime_frames(record: Dictionary) -> int:
	if str(record.get("source", "")) == "controlled":
		return int(record["frames"]) + 1
	return int(record["frames"])

# 外推死亡点 = 最后可见位置 + 一帧位移（方向固定 RIGHT，位移是**实测**的相邻帧距离，
# 不是照抄速度算出来的）。用来回答「最后一次被看到时还在框内，但其实是同一帧里飞出去的」。
func _predicted_death(record: Dictionary) -> Vector2:
	var last: Vector2 = record["last"]
	var step := _mean_of(record.get("steps", []))
	if step <= 0.0:
		return last
	return last + Vector2(step, 0.0)

func _measure_env(tag: String) -> void:
	_log("%s ENV[%s] 工程设置 display/window/size = %dx%d" % [
		TAG, tag,
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))])
	_log("%s ENV[%s] root.size=%s root.get_visible_rect().size=%s headless=%s" % [
		TAG, tag, str(root.size), str(root.get_visible_rect().size),
		str(DisplayServer.get_name())])

func _hist_text(hist: Dictionary) -> String:
	var keys: Array = hist.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s→%d 帧" % [str(k), int(hist[k])])
	return " ".join(parts)

func _mean_of(values) -> float:
	var arr: Array = values
	if arr.is_empty():
		return -1.0
	var total := 0.0
	for v in arr:
		total += float(v)
	return total / float(arr.size())

func _max_of(values: Array) -> int:
	var best := 0
	for v in values:
		if int(v) > best:
			best = int(v)
	return best

# 众数：出现次数最多的取值；并列时取较小者。直方图已一并打印，方便核对。
func _mode_of(values: Array) -> int:
	if values.is_empty():
		return -1
	var counts := {}
	for v in values:
		counts[int(v)] = int(counts.get(int(v), 0)) + 1
	var best_value := -1
	var best_count := -1
	var keys: Array = counts.keys()
	keys.sort()
	for k in keys:
		if int(counts[k]) > best_count:
			best_count = int(counts[k])
			best_value = int(k)
	return best_value

func _open_log(path: String) -> bool:
	var dir := path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	if _log_file == null:
		push_error("打不开输出文件: %s" % path)
		return false
	return true

# 每一行都同时进终端与证据文件：终端会滚掉，文件不会。
func _log(line: String) -> void:
	print(line)
	if _log_file != null:
		_log_file.store_line(line)
		_log_file.flush()

func _finish(code: int) -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
	quit(code)

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
