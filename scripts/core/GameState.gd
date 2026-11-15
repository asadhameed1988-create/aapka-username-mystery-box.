extends Node
## Autoload "GameState": local save (offline progress, settings, current mission).
## Numbers loaded from JSON come back as floats, so readers always cast with int()/float().

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}
var page: String = "achievements"          # which page Pages.tscn shows (not saved)
var open_chapter_on_return: bool = false   # Chapters.tscn reopens the last chapter (not saved)


func _ready() -> void:
	data = _defaults()
	load_game()


func _defaults() -> Dictionary:
	return {
		"version": 3,
		"install_seed": 0,
		"round": 0,
		"rating": 1.0,
		"recent_types": [],
		"recent_signatures": [],
		"recent_questions": [],
		"sections": {"islam": {"boxes": 0, "deck": {}}, "gk": {"boxes": 0, "deck": {}}, "math": {"boxes": 0, "deck": {}}},
		"section_ref": "islam",
		"rewards_won": 0,
		"current_mission": null,
		"current_stage": 0,
		"mission_time": 0.0,
		"mission_hints": 0,
		"mode": "endless",
		"daily_done": "",
		"chapter_ref": [1, 0],
		"chapters": {},
		"achievements": [],
		"inventory": {"hints": 5, "artifacts": []},
		"stats": {
			"solved": 0, "hints": 0, "total_time": 0.0, "no_hint": 0, "fast": 0, "best_time": 0.0,
			"daily_streak": 0, "daily_best": 0, "by_type": {},
		},
		"online": {
			"server_url": "", "token": "", "profile": {}, "queue": [], "daily": {}, "weekly": {},
			"weekly_done": [], "config": {}, "last_result": {}, "events": [],
		},
		"purchases": {"remove_ads": false, "granted_tokens": []},
		"ads": {"rewarded_day": "", "rewarded_count": 0},
		"settings": {"lang": "en", "sound": true, "music": true, "quality": "high", "online": true, "analytics": true, "locks": "quiz"},
	}


func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in parsed.keys():
					data[k] = parsed[k]
				repair()
	if int(data["install_seed"]) == 0:
		randomize()
		data["install_seed"] = (randi() & 0x7FFFFFFF) | 1
		save_game()


## Fills in fields that an older save (or a synced save) does not have yet.
func repair() -> void:
	var defaults: Dictionary = _defaults()
	# Version 2 switched the default locks to easy questions: drop an unfinished
	# box from the older save so the player starts with the new question boxes.
	# Version 3 = separate question sections: an unfinished older box is dropped once.
	if int(data.get("version", 1)) < 3:
		data["current_mission"] = null
		data["version"] = 3
	for k in defaults.keys():
		if not data.has(k):
			data[k] = defaults[k]
	for k in ["stats", "inventory", "settings", "online", "purchases", "ads", "sections"]:
		if typeof(data.get(k)) != TYPE_DICTIONARY:
			data[k] = defaults[k]
		for sub_key in (defaults[k] as Dictionary).keys():
			if not (data[k] as Dictionary).has(sub_key):
				data[k][sub_key] = defaults[k][sub_key]
	for sec in (data["sections"] as Dictionary).keys():
		if typeof(data["sections"][sec]) != TYPE_DICTIONARY:
			data["sections"][sec] = {"boxes": 0, "deck": {}}
		for sub_key in ["boxes", "deck"]:
			if not (data["sections"][sec] as Dictionary).has(sub_key):
				data["sections"][sec][sub_key] = 0 if sub_key == "boxes" else {}


func save_game() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func has_mission() -> bool:
	return typeof(data.get("current_mission")) == TYPE_DICTIONARY


func start_mission(mission: Dictionary, mode: String) -> void:
	data["current_mission"] = mission
	data["current_stage"] = 0
	data["mission_time"] = 0.0
	data["mission_hints"] = 0
	data["mode"] = mode
	save_game()


func lang() -> String:
	return str((data["settings"] as Dictionary).get("lang", "en"))


func set_lang(code: String) -> void:
	data["settings"]["lang"] = code
	save_game()
