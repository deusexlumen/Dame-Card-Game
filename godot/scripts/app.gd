extends Node

# Autoload "App": haelt Dienste und wechselt Szenen. Nie den Spielzustand.

const SettingsServiceScript = preload("res://scripts/services/settings_service.gd")
const StatsServiceScript = preload("res://scripts/services/stats_service.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const ProfileServiceScript = preload("res://scripts/services/profile_service.gd")
const AudioServiceScript = preload("res://scripts/services/audio_service.gd")
const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")

const MAIN_MENU := "res://scenes/main_menu.tscn"
const TABLE := "res://scenes/table.tscn"
const SETUP := "res://scenes/setup.tscn"
const RULES := "res://scenes/rules.tscn"
const SETTINGS := "res://scenes/settings.tscn"
const STATS := "res://scenes/stats.tscn"
const SHOP := "res://scenes/shop.tscn"

var settings
var stats
var saves
var profile
var audio
# Auftrag fuer den Tisch: {"mode": "new", "config": {...}} oder {"mode": "resume"}.
var pending: Dictionary = {}
var last_config: Dictionary = {}
var _crt: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# use_test_storage() kann schon vorher gelaufen sein: dann nicht ueberschreiben.
	if settings == null:
		settings = SettingsServiceScript.new()
		stats = StatsServiceScript.new()
		saves = SaveServiceScript.new()
		profile = ProfileServiceScript.new()
		settings.changed.connect(_on_setting_changed)
		profile.changed.connect(apply_theme)
	audio = AudioServiceScript.new()
	audio.name = "Audio"
	add_child(audio)
	apply_theme()
	_apply_window()
	audio.apply_settings(settings)
	_build_crt()


func _build_crt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_crt = ColorRect.new()
	_crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crt.gdshader")
	_crt.material = mat
	layer.add_child(_crt)
	_crt.visible = bool(settings.get_value("crt_effect"))


# Tests: alle Dienste auf eigene Dateien umlenken und leeren.
func use_test_storage() -> void:
	for f in ["settings.json", "stats.json", "save.dat", "profile.json"]:
		var path: String = "user://test_" + f
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	settings = SettingsServiceScript.new("user://test_settings.json")
	stats = StatsServiceScript.new("user://test_stats.json")
	saves = SaveServiceScript.new("user://test_save.dat")
	profile = ProfileServiceScript.new("user://test_profile.json")
	settings.changed.connect(_on_setting_changed)
	profile.changed.connect(apply_theme)
	settings.set_value("music_enabled", false)
	settings.set_value("sound_enabled", false)


func is_web() -> bool:
	return OS.has_feature("web")


func accent() -> Color:
	return Color(str(profile.equipped_data("accent").get("color", "8cff8c")))


func table_color() -> Color:
	return Color(str(profile.equipped_data("table").get("color", "050905")))


func back_style() -> String:
	return str(profile.equipped_data("card_back").get("back_style", "raster"))


func apply_theme() -> void:
	if not is_inside_tree():
		return
	get_tree().root.theme = UiThemeScript.build(accent())
	RenderingServer.set_default_clear_color(UiThemeScript.BG)


func _apply_window() -> void:
	if is_web():
		return
	var full := bool(settings.get_value("fullscreen"))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _on_setting_changed(key: String, _value) -> void:
	if key == "fullscreen":
		_apply_window()
	elif key == "crt_effect" and _crt != null:
		_crt.visible = bool(settings.get_value("crt_effect"))
	elif key in ["sound_enabled", "music_enabled", "music_volume", "effects_volume"] and audio != null:
		audio.apply_settings(settings)


func click() -> void:
	audio.play("click")


func goto(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func new_match(config: Dictionary) -> void:
	last_config = config.duplicate(true)
	pending = {"mode": "new", "config": config}
	goto(TABLE)


func resume_match() -> void:
	pending = {"mode": "resume"}
	goto(TABLE)


func take_pending() -> Dictionary:
	var p := pending
	pending = {}
	return p


func quit_game() -> void:
	get_tree().quit()
