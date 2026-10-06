extends "res://scripts/screens/screen_base.gd"

# Einstellungen. Jede Aenderung wird sofort gespeichert.

const SPEED_KEYS := ["slow", "normal", "fast"]
const SPEED_LABELS := ["Langsam", "Normal", "Schnell"]
const TIMER_VALUES := [15, 30, 60]
const DIFF_KEYS := ["easy", "medium", "hard"]
const DIFF_LABELS := ["Einfach", "Mittel", "Schwer"]

var controls := {}

func build() -> void:
	frame("Einstellungen")
	var app := app_node()
	if app == null:
		return
	var s = app.settings
	content.add_child(label("Ton", 20))
	_check("sound_enabled", "Soundeffekte", s)
	_slider("effects_volume", "Lautstärke Effekte", s)
	_check("music_enabled", "Musik", s)
	_slider("music_volume", "Lautstärke Musik", s)
	content.add_child(HSeparator.new())
	content.add_child(label("Spiel", 20))
	_choice("ai_speed", "KI-Tempo", SPEED_KEYS, SPEED_LABELS, s)
	_choice("default_difficulty", "Standard-KI-Stufe", DIFF_KEYS, DIFF_LABELS, s)
	_check("memory_aid", "Gedächtnishilfe (bekannte Karten bleiben offen)", s)
	_check("turn_timer", "Zugtimer", s)
	_choice("turn_timer_seconds", "Zeit pro Zug", TIMER_VALUES, ["15 Sekunden", "30 Sekunden", "60 Sekunden"], s)
	var name_edit := LineEdit.new()
	name_edit.max_length = 16
	name_edit.text = str(s.get_value("player_name"))
	name_edit.text_submitted.connect(func(t: String) -> void: s.set_value("player_name", t))
	name_edit.focus_exited.connect(func() -> void: s.set_value("player_name", name_edit.text))
	controls["player_name"] = name_edit
	content.add_child(row("Dein Name", name_edit))
	content.add_child(HSeparator.new())
	content.add_child(label("Darstellung", 20))
	_check("table_3d", "3D-Tisch (Egoperspektive)", s)
	_check("animations", "Animationen", s)
	if not app.is_web():
		_check("fullscreen", "Vollbild", s)
	controls["sound_enabled"].grab_focus()


# Schalter als Knopf mit AN/AUS, passend zum Phosphor-Stil.
func _check(key: String, text: String, s) -> void:
	var c := Button.new()
	c.toggle_mode = true
	c.button_pressed = bool(s.get_value(key))
	c.text = "AN" if c.button_pressed else "AUS"
	c.custom_minimum_size = Vector2(110, 32)
	c.toggled.connect(func(on: bool) -> void:
		c.text = "AN" if on else "AUS"
		s.set_value(key, on)
		var app := app_node()
		if app != null:
			app.click())
	controls[key] = c
	var r := row(text, c, 460)
	c.size_flags_horizontal = Control.SIZE_SHRINK_END
	content.add_child(r)


func _slider(key: String, text: String, s) -> void:
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 100
	sl.step = 5
	sl.value = int(s.get_value(key))
	sl.custom_minimum_size = Vector2(240, 24)
	sl.value_changed.connect(func(v: float) -> void: s.set_value(key, int(v)))
	controls[key] = sl
	content.add_child(row(text, sl, 460))


func _choice(key: String, text: String, keys: Array, labels: Array, s) -> void:
	var o := option(labels, keys.find(s.get_value(key)))
	o.item_selected.connect(func(i: int) -> void: s.set_value(key, keys[i]))
	controls[key] = o
	content.add_child(row(text, o, 460))
