extends Node

# 存档系统 — 自动单例
# 保存到 user://brotato_save.json

const SAVE_PATH = "user://brotato_save.json"

var _data = {
	"highest_wave": 0,
	"highest_kills": 0,
	"total_games": 0,
	"unlocked_characters": ["normal", "warrior", "hunter"],
	"endless_max_wave": 0,
	"achievements": {},
}

func _ready():
	_data = load_game()

func save_game(data: Dictionary):
	for key in data:
		if _data.has(key):
			_data[key] = data[key]
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data))
		file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _data.duplicate()
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _data.duplicate()
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(text) == OK:
		var result = json.data
		if result is Dictionary:
			# 合并已有数据，确保缺失字段有默认值
			var merged = _data.duplicate()
			for key in result:
				merged[key] = result[key]
			return merged
	return _data.duplicate()

func update_record(wave: int, kills_count: int):
	_data.total_games += 1
	if wave > _data.highest_wave:
		_data.highest_wave = wave
	if kills_count > _data.highest_kills:
		_data.highest_kills = kills_count
	save_game(_data)

func update_endless_record(wave: int):
	if wave > _data.endless_max_wave:
		_data.endless_max_wave = wave
		save_game(_data)

func get_data() -> Dictionary:
	return _data.duplicate()

func unlock_character(char_id: String):
	if char_id not in _data.unlocked_characters:
		_data.unlocked_characters.append(char_id)
		save_game(_data)

func is_character_unlocked(char_id: String) -> bool:
	if GameState.has_method("is_catalog_character_default_unlocked") and GameState.is_catalog_character_default_unlocked(char_id):
		return true
	return char_id in _data.unlocked_characters

func get_unlocked_characters() -> Array:
	return _data.unlocked_characters.duplicate()

# --- 成就系统 ---

const ACHIEVEMENTS = {
	"first_blood":     {"name": "初次击杀",     "desc": "击杀第一个敌人"},
	"wave_5":          {"name": "初露锋芒",     "desc": "存活到第5波"},
	"wave_10":         {"name": "身经百战",     "desc": "存活到第10波"},
	"kill_100":        {"name": "百人斩",       "desc": "单局击杀100个敌人"},
	"kill_500":        {"name": "千人斩",       "desc": "单局击杀500个敌人"},
	"damage_10000":    {"name": "毁灭者",       "desc": "单局造成10000点伤害"},
	"no_damage_wave":  {"name": "完美波次",     "desc": "某波未受到任何伤害"},
	"full_synergy":    {"name": "协同大师",     "desc": "同时激活协同效果"},
	"endless_30":      {"name": "无尽挑战者",   "desc": "无尽模式存活到第30波"},
	"all_weapons":     {"name": "军火库",       "desc": "同时装备5件武器"},
}

func unlock_achievement(id: String) -> bool:
	if not ACHIEVEMENTS.has(id):
		return false
	if _data.achievements.has(id):
		return false
	_data.achievements[id] = true
	save_game(_data)
	return true

func get_achievements() -> Dictionary:
	return _data.achievements.duplicate()
