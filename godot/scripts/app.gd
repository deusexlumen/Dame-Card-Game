extends Node

# Autoload "App": haelt Dienste und wechselt Szenen. Nie den Spielzustand.

const SettingsServiceScript = preload("res://scripts/services/settings_service.gd")
const StatsServiceScript = preload("res://scripts/services/stats_service.gd")
const SaveServiceScript = preload("res://scripts/services/save_service.gd")
const ProfileServiceScript = preload("res://scripts/services/profile_service.gd")
const AudioServiceScript = preload("res://scripts/services/audio_service.gd")
const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")
const I18nScript = preload("res://scripts/i18n.gd")

const MAIN_MENU := "res://scenes/main_menu.tscn"
const TABLE := "res://scenes/table.tscn"
const SETUP := "res://scenes/setup.tscn"
const RULES := "res://scenes/rules.tscn"
const SETTINGS := "res://scenes/settings.tscn"
const STATS := "res://scenes/stats.tscn"
const SHOP := "res://scenes/shop.tscn"
# Online-Bildschirm (Verbindung per Code). Fehlt die Szene noch, geht es ins Hauptmenue.
const ONLINE := "res://scenes/online.tscn"

var settings
var stats
var saves
var profile
var audio
# Auftrag fuer den Tisch: {"mode": "new", "config": {...}}, {"mode": "resume"},
# {"mode": "online_host", "config", "link", "host_seat", "guest_seats", "owner"} oder
# {"mode": "online_guest", "session": DameGuest, "owner"}. Link und Session reisen nur hier mit
# und werden beim Abholen geloescht; niemand pollt sie bis der Tisch sie uebernimmt.
# "owner" besitzt die Verbindung (RtcConnector: schliesst beim Freigeben seinen Peer).
# Der Tisch haelt ihn die ganze Partie und schliesst ihn mit der Verbindung.
var pending: Dictionary = {}
var last_config: Dictionary = {}
# Tests: Szenenwechsel nur merken, nicht ausfuehren.
var test_mode := false
var last_goto := ""
# Zwischenspeicher fuer e2e_mode(): -1 unbekannt, 0 aus, 1 an.
var _e2e := -1

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
	I18nScript.install(str(settings.get_value("language")))
	audio = AudioServiceScript.new()
	audio.name = "Audio"
	add_child(audio)
	apply_theme()
	_apply_window()
	audio.apply_settings(settings)


# Tests: alle Dienste auf eigene Dateien umlenken und leeren.
func use_test_storage() -> void:
	test_mode = true
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


# Casino-Gold fuer Markierungen und Akzente (fest, keine Kosmetik mehr).
func accent() -> Color:
	return UiThemeScript.GOLD


func table_color() -> Color:
	return Color(str(profile.equipped_data("table").get("color", "1f5a3a")))


func back_skin() -> String:
	return str(profile.equipped_data("card_back").get("skin", "bordeaux"))


func face_skin() -> String:
	return str(profile.equipped_data("card_face").get("skin", "klassisch"))


func language() -> String:
	return str(settings.get_value("language")) if settings != null else "de"


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
	elif key == "language":
		I18nScript.install(str(settings.get_value("language")))
		# Offene Ansicht neu aufbauen, damit alle Texte wechseln.
		if not test_mode and get_tree().current_scene != null:
			get_tree().reload_current_scene()
	elif key in ["sound_enabled", "music_enabled", "music_volume", "effects_volume"] and audio != null:
		audio.apply_settings(settings)


func click() -> void:
	audio.play("click")


func goto(path: String) -> void:
	last_goto = path
	if test_mode:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func new_match(config: Dictionary) -> void:
	last_config = config.duplicate(true)
	pending = {"mode": "new", "config": config}
	goto(TABLE)


func resume_match() -> void:
	pending = {"mode": "resume"}
	goto(TABLE)


# Online-Host: der Tisch startet die Regeln und uebernimmt den Link (und das Pollen).
func online_host_match(job: Dictionary) -> void:
	pending = {
		"mode": "online_host",
		"config": job.get("config", {}),
		"link": job.get("link"),
		"host_seat": int(job.get("host_seat", 0)),
		"guest_seats": job.get("guest_seats", {}),
		"owner": job.get("owner"),
	}
	goto(TABLE)


# Online-Gast: der Tisch uebernimmt die verbundene Session (DameGuest).
func online_guest_match(session, owner = null) -> void:
	pending = {"mode": "online_guest", "session": session, "owner": owner}
	goto(TABLE)


# Web-Test-Bruecke (Playwright): nur wenn die Seiten-URL ?e2e=1 enthaelt. Nie ausserhalb.
func e2e_mode() -> bool:
	if _e2e < 0:
		_e2e = 0
		if is_web():
			var on = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('e2e') === '1'", true)
			_e2e = 1 if on == true else 0
	return _e2e == 1


# Ziel nach einer Online-Partie: Online-Bildschirm, solange es ihn noch nicht gibt das Hauptmenue.
func online_screen() -> String:
	return ONLINE if ResourceLoader.exists(ONLINE) else MAIN_MENU


func take_pending() -> Dictionary:
	var p := pending
	pending = {}
	return p


func quit_game() -> void:
	get_tree().quit()
