extends RefCounted
class_name SettingsService

# Spieleinstellungen in user://settings.json. Unbekannte oder ungueltige Werte
# fallen auf den Standard zurueck.

signal changed(key: String, value)

const JsonStoreScript = preload("res://scripts/services/json_store.gd")

const DEFAULTS := {
	"sound_enabled": true,
	"music_enabled": true,
	"music_volume": 50,
	"effects_volume": 70,
	"ai_speed": "normal",
	"animations": true,
	"turn_timer": false,
	"turn_timer_seconds": 30,
	"memory_aid": true,
	"table_3d": true,
	"default_difficulty": "medium",
	"fullscreen": false,
	"player_name": "Spieler",
	"language": "de",
	# Feature-Flag, vorbereitet und aus; nicht in den Einstellungen sichtbar.
	"power_effects": false,
}
const CHOICES := {
	"ai_speed": ["slow", "normal", "fast"],
	"turn_timer_seconds": [15, 30, 60],
	"default_difficulty": ["easy", "medium", "hard"],
	"language": ["de", "en"],
}
const AI_DELAYS := {"slow": 1.2, "normal": 0.7, "fast": 0.3}

var path := "user://settings.json"
var values: Dictionary = {}

func _init(p_path: String = "user://settings.json") -> void:
	path = p_path
	load_settings()


func load_settings() -> void:
	values = DEFAULTS.duplicate(true)
	var stored := JsonStoreScript.read_json(path)
	for key in stored:
		if DEFAULTS.has(key):
			var v = _sanitize(key, stored[key])
			if v != null:
				values[key] = v


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> bool:
	if not DEFAULTS.has(key):
		return false
	var v = _sanitize(key, value)
	if v == null:
		return false
	values[key] = v
	JsonStoreScript.write_json(path, values)
	changed.emit(key, v)
	return true


func ai_delay() -> float:
	return float(AI_DELAYS.get(str(get_value("ai_speed")), 0.7))


func _sanitize(key: String, value):
	var def = DEFAULTS[key]
	match typeof(def):
		TYPE_BOOL:
			if typeof(value) == TYPE_BOOL:
				return value
			return null
		TYPE_INT:
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return null
			var n := int(value)
			if CHOICES.has(key):
				return n if CHOICES[key].has(n) else null
			return clampi(n, 0, 100)
		TYPE_STRING:
			if typeof(value) != TYPE_STRING:
				return null
			var s := str(value).strip_edges()
			if CHOICES.has(key):
				return s if CHOICES[key].has(s) else null
			if s == "":
				return null
			return s.substr(0, 16)
	return null
