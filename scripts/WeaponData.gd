class_name WeaponData
extends Resource

@export var weapon_type:   String = ""
@export var display_name:  String = "新武器"
@export_multiline var desc: String = ""
@export var price:         int    = 20
@export_range(0, 3) var rarity: int = 0   # 0普通 1精良 2稀有 3传说

@export_group("战斗属性")
@export var damage:    int   = 1
@export var fire_rate: float = 2.5
@export var count:     int   = 1
@export var spread:    float = 0.0
@export var speed:     float = 500.0
@export var color:     Color = Color(1, 0.9, 0.2)

@export_group("特殊属性")
@export var pierce:        bool    = false
@export var splash:        bool    = false
@export var splash_radius: float   = 0.0
@export var melee:         bool    = false
@export var melee_radius:  float   = 80.0
@export var returns:       bool    = false
@export var charge_time:   float   = 0.0
@export var gravity:       bool    = false
@export var bullet_scale:  Vector2 = Vector2(1, 1)
@export var range_limit:   float   = 0.0

func to_combat_entry() -> Dictionary:
	var d = {
		"name": display_name, "damage": damage, "fire_rate": fire_rate,
		"count": count, "spread": spread, "spd": speed, "color": color,
	}
	if pierce:              d["pierce"]        = true
	if splash:              d["splash"]        = true
	if splash_radius > 0:   d["splash_radius"] = splash_radius
	if melee:               d["melee"]         = true
	if melee_radius != 80:  d["melee_radius"]  = melee_radius
	if returns:             d["returns"]       = true
	if charge_time > 0:     d["charge_time"]   = charge_time
	if gravity:             d["gravity"]       = true
	if bullet_scale != Vector2(1,1): d["bullet_scale"] = bullet_scale
	if range_limit > 0:     d["range"]         = range_limit
	return d

func to_shop_entry() -> Dictionary:
	return {"name": display_name, "desc": desc, "price": price,
			"rarity": rarity, "type": "weapon", "weapon_type": weapon_type}
