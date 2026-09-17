class_name CharacterEmblem
extends RefCounted

# 角色徽章 —— 给角色选择界面的每张卡一个可辨认的形象。
#
# 复用 UnitVisual 的形状语言（同一套几何 / 描边 / 内高光），所以菜单与游戏内看起来是同一套美术，
# 而且**零新资产**：62 个角色的形象全由代码派生。
#
# 两条设计约束：
#   ① **确定性**：同一个角色永远得到同一个徽章（由 id 哈希决定，不用 randf）。
#      否则每次进菜单形象都变，等于没有识别度 —— 玩家记不住任何东西。
#   ② 形状与**角色配色**配合：形状给"这是哪一类"，颜色给"这是哪一个"。
#      单靠形状只能区分 7×7 种组合，单靠颜色对色盲不友好，两者叠加才够用。

const SILHOUETTES := ["hex", "octagon", "star", "circle", "diamond", "square", "tri"]
const MARKS := ["none", "gun", "cross", "ring", "crest", "spikes", "fins"]

# 徽章在卡片里的显示尺寸（与 UnitVisual 的名义半径 16 不是一个量纲：
# 这里是"给多少像素"，画出来会比同半径的单位大一圈，正好适合卡面）
const EMBLEM_RADIUS_MIN := 15.0
const EMBLEM_RADIUS_VARIANTS := 3


static func spec_for(key: String) -> Dictionary:
	var h := stable_hash(key)
	return {
		"silhouette": SILHOUETTES[h % SILHOUETTES.size()],
		"mark": MARKS[(h / SILHOUETTES.size()) % MARKS.size()],
		"radius": EMBLEM_RADIUS_MIN + float((h / 17) % EMBLEM_RADIUS_VARIANTS),
	}


# 自己算一份稳定哈希：String.hash() 在不同引擎版本间不保证一致，
# 徽章是要"永远长一样"的东西，不能依赖它。
static func stable_hash(key: String) -> int:
	var h := 2166136261
	for i in range(key.length()):
		h = (h ^ key.unicode_at(i)) * 16777619
		# 每轮掩成非负，避免溢出成负数后取模得到负下标
		h = h & 0x7fffffff
	return h


# 在 parent 下建一个居中的徽章。
# 返回 {"holder": Control, "body": Polygon2D} —— holder 供容器布局用它的最小尺寸，
# body 留给调用方按选中/锁定状态改色（选中时不该靠压暗整体来表达，那会连文字一起压黑）。
static func build(parent: Control, key: String, color: Color, box: float) -> Dictionary:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(box, box)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

	var host := Node2D.new()
	host.position = Vector2(box * 0.5, box * 0.5)
	holder.add_child(host)

	var body := Polygon2D.new()
	body.name = "Body"
	body.color = color
	host.add_child(body)

	var spec := spec_for(key)
	UnitVisual.apply_shape(host, body, str(spec.silhouette), str(spec.mark), float(spec.radius))
	return {"holder": holder, "body": body}
