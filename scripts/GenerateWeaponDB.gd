@tool
extends EditorScript

# 在 Godot 编辑器中：右键此文件 → Run，生成 data/weapons.tres
# 生成后可删除本文件

func _run():
	var db = WeaponDatabase.new()
	_add(db, "pistol",          "手枪",     "均衡武器",         15, 0,  1, 2.5,  1, 0.0,  500.0, Color(1.0,0.9,0.2))
	_add(db, "shotgun",         "散弹枪",   "5发扇形散射",       30, 1,  1, 1.0,  5, 25.0, 420.0, Color(1.0,0.5,0.1))
	_add(db, "sniper",          "狙击枪",   "4倍伤害超远射程",   35, 1,  4, 0.7,  1, 0.0,  900.0, Color(0.3,0.8,1.0))
	_add(db, "machinegun",      "机关枪",   "超高射速",          40, 2,  1, 8.0,  1, 8.0,  500.0, Color(1.0,0.3,0.3))
	_add(db, "boomerang",       "回旋镖",   "飞出后自动返回",    50, 1, 25, 0.83, 1, 5.7,  300.0, Color(0.8,0.6,0.1), {returns=true})
	_add(db, "knife",           "飞刀",     "高速三连投掷",      45, 1, 12, 5.0,  3, 17.2, 550.0, Color(0.8,0.8,0.8))
	_add(db, "sword",           "剑",       "近战范围攻击",      70, 2, 40, 1.25, 8, 45.0, 0.0,   Color(0.9,0.9,0.9), {melee=true})
	_add(db, "spear",           "长矛",     "穿透型远程投掷",    75, 2, 35, 1.0,  1, 0.0,  500.0, Color(0.7,0.4,0.2), {pierce=true, bullet_scale=Vector2(3,0.5)})
	_add(db, "flamethrower",    "火焰喷射器","短距高速灼烧",     80, 2,  8,10.0,  1, 28.6, 200.0, Color(1.0,0.5,0.0), {range_limit=150.0})
	_add(db, "crossbow",        "弩",       "高伤害精准射击",    85, 2, 60, 0.56, 1, 0.0,  700.0, Color(0.6,0.3,0.1))
	_add(db, "laser",           "激光枪",   "穿透型激光束",      90, 2, 15, 3.3,  1, 0.0,  800.0, Color(1.0,0.0,1.0), {pierce=true})
	_add(db, "grenade",         "手雷",     "溅射爆炸伤害",      95, 2, 50, 0.67, 1, 11.5, 300.0, Color(0.4,0.7,0.2), {splash=true, splash_radius=60.0, gravity=true})
	_add(db, "minigun",         "速射枪",   "极限射速弹幕",     110, 3,  5,20.0,  1, 22.9, 600.0, Color(0.5,0.5,0.5))
	_add(db, "rocket_launcher", "火箭筒",   "大范围溅射爆炸",   120, 3, 80, 0.4,  1, 2.9,  250.0, Color(0.8,0.4,0.1), {splash=true, splash_radius=80.0})
	_add(db, "plasma",          "等离子炮", "超高伤害蓄力炮",   130, 3,100, 0.25, 1, 0.0,  200.0, Color(0.0,1.0,1.0), {charge_time=2.0})
	_add(db, "smg",             "冲锋枪",   "极高射速连射",      35, 1,  1,12.0,  1, 12.0, 480.0, Color(0.9,0.7,0.2))
	ResourceSaver.save(db, "res://data/weapons.tres")
	print("✅ data/weapons.tres 已生成，现在可以在Inspector中可视化编辑武器了！")

func _add(db, type, name, desc, price, rarity, dmg, fr, cnt, spd_spread, spd, col, extras={}):
	var w = WeaponData.new()
	w.weapon_type  = type
	w.display_name = name
	w.desc         = desc
	w.price        = price
	w.rarity       = rarity
	w.damage       = dmg
	w.fire_rate    = fr
	w.count        = cnt
	w.spread       = spd_spread
	w.speed        = spd
	w.color        = col
	for k in extras:
		w.set(k, extras[k])
	db.weapons.append(w)
