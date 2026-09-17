# PlayerStatus.gd — 玩家身上的元素状态（燃烧 / 减速 / 眩晕）
#
# 来源：敌方元素子弹，见 docs/boss-variants-design.md。
# 在实现之前，玩家侧**完全没有状态效果系统**（burn / slow / stun 都不存在），
# 所以设计文档里那句「Player 命中时 apply_burn()」需要先把这个模块建起来。
#
# 设计要点：
# 1. **不改玩家属性，只在消费点折算。** 减速不写 `p.speed`，而是由
#    `PlayerCore.process_movement()` 现乘 `speed_multiplier()`。
#    这样状态到期不需要「回滚」，也不会和 `PlayerBuffs` 的临时增益、
#    `apply_temporary_speed_delta()` 的加减速互相污染
#    （改属性再回滚是本项目反复踩过的坑：一旦漏回滚就永久残留）。
# 2. **眩晕必须带冷却。** 雷电 Boss 一轮 5-8 发弹幕；命中虽已被玩家的
#    无敌帧（`INVINCIBLE_TIME = 0.8s`）节流，但 0.3s 眩晕 / 0.8s 仍等于
#    37% 时间失控。这里再要求「眩晕结束后 1.0s 内不再被眩晕」，
#    把最坏失控比例压到约 1/4，避免被弹幕锁死。
# 3. **燃烧用 `apply_self_damage_without_invulnerability()` 结算**，
#    即 DoT 不吃无敌帧也不吃护甲 —— 与敌人身上的燃烧语义一致
#    （燃烧是独立伤害通道）。否则「身上着火时刚好处于无敌帧」会完全免疫，
#    而持续伤害被无敌帧吞掉是反直觉的。
# 4. 数值全部集中在下面，待真机 playtest 定标。

class_name PlayerStatus
extends RefCounted

# ─── 可调数值（待 playtest 定标） ───
# 玩家基础 HP 只有 5，所以这里必须远轻于敌人身上的燃烧（3s / 0.5s tick / 1 伤害）。
# 取「1 伤害 / 1 秒，最多 2 跳」= 单次命中最多 2 点伤害；重复命中只刷新时长、不叠伤害。
const BURN_TICK_INTERVAL := 1.0
const BURN_DURATION := 2.0
const BURN_TICK_DAMAGE := 1

const SLOW_FACTOR := 0.3      # 减速 30%（设计文档取值）
const SLOW_DURATION := 2.0

const STUN_DURATION := 0.3
const STUN_COOLDOWN := 1.0    # 一次眩晕结束后的免疫窗口

# 元素 → 效果的映射。新增元素只改这一张表 + 对应的 apply_* 分支。
const ELEMENT_RULES := {
	"fire": true,
	"frost": true,
	"lightning": true,
}

const TINT_NONE := Color(1, 1, 1)
const TINT_BURN := Color(1.0, 0.55, 0.2)
const TINT_SLOW := Color(0.6, 0.85, 1.0)
const TINT_STUN := Color(1.0, 1.0, 0.45)

var p: CharacterBody2D

var burn_timer := 0.0
var burn_tick := 0.0
var burn_tick_interval := BURN_TICK_INTERVAL
var burn_tick_damage := BURN_TICK_DAMAGE
var slow_timer := 0.0
var slow_factor := 1.0
var stun_timer := 0.0
var stun_cooldown := 0.0

func init(player: CharacterBody2D):
	p = player

# ─── 施加 ───

# 由 PlayerCore.take_damage() 在**伤害真正落地之后**调用，
# 所以闪避 / 无敌帧 / 免伤挡下的命中不会附加状态。
# 返回 true 表示该元素被识别并已施加。
func apply_element(element: String) -> bool:
	if not ELEMENT_RULES.has(element):
		return false
	match element:
		"fire":
			apply_burn()
		"frost":
			apply_slow(SLOW_FACTOR, SLOW_DURATION)
		"lightning":
			return apply_stun(STUN_DURATION)
	return true

func apply_burn(duration: float = BURN_DURATION, tick_interval: float = BURN_TICK_INTERVAL, tick_damage: int = BURN_TICK_DAMAGE) -> void:
	# 刷新时长而不是叠加伤害：否则被连续命中会瞬间烧死
	burn_timer = max(burn_timer, duration)
	burn_tick_interval = max(0.05, tick_interval)
	burn_tick_damage = max(1, tick_damage)
	if burn_tick <= 0.0:
		burn_tick = burn_tick_interval

func apply_slow(factor: float = SLOW_FACTOR, duration: float = SLOW_DURATION) -> void:
	# 取更强者而非叠加：多个减速不该叠成「完全动不了」
	slow_factor = min(slow_factor, 1.0 - clamp(factor, 0.0, 0.9))
	slow_timer = max(slow_timer, duration)

# 返回 true 表示这次眩晕真的生效（冷却中会被拒绝）
func apply_stun(duration: float = STUN_DURATION) -> bool:
	if stun_cooldown > 0.0:
		return false
	stun_timer = max(stun_timer, duration)
	return true

# ─── 查询 ───

# 移动速度乘数：眩晕 = 完全不能动，否则取减速系数。
# 由 PlayerCore.process_movement() 在消费点读取。
func speed_multiplier() -> float:
	if stun_timer > 0.0:
		return 0.0
	return slow_factor

func is_burning() -> bool:
	return burn_timer > 0.0

func is_slowed() -> bool:
	return slow_timer > 0.0

func is_stunned() -> bool:
	return stun_timer > 0.0

# ─── 每帧推进 ───

func process(delta: float) -> void:
	if stun_cooldown > 0.0:
		stun_cooldown = max(0.0, stun_cooldown - delta)

	if burn_timer > 0.0:
		burn_timer -= delta
		burn_tick -= delta
		if burn_tick <= 0.0 and burn_timer > 0.0:
			burn_tick = burn_tick_interval
			if p != null and is_instance_valid(p) and p.hp > 0:
				p.apply_self_damage_without_invulnerability(burn_tick_damage)
		if burn_timer <= 0.0:
			_clear_burn()

	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0

	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_timer <= 0.0:
			stun_cooldown = STUN_COOLDOWN

	_update_tint()

func _clear_burn() -> void:
	burn_timer = 0.0
	burn_tick = 0.0

# 波次切换时清空：状态是「本波内」的东西，不该带进商店或下一波
func clear() -> void:
	_clear_burn()
	slow_timer = 0.0
	slow_factor = 1.0
	stun_timer = 0.0
	stun_cooldown = 0.0
	_update_tint()

func _update_tint() -> void:
	if p == null or not is_instance_valid(p):
		return
	var tint := TINT_NONE
	if burn_timer > 0.0:
		tint = TINT_BURN
	elif slow_timer > 0.0:
		tint = TINT_SLOW
	elif stun_timer > 0.0:
		tint = TINT_STUN
	# 只改 RGB、保留 alpha —— 否则会覆盖 PlayerCore.process_invincibility() 的无敌帧闪烁
	p.modulate = Color(tint.r, tint.g, tint.b, p.modulate.a)
