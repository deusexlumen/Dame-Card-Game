extends "res://scripts/screens/screen_base.gd"

# Hauptmenue. Fortsetzen nur, wenn ein gueltiger Spielstand da ist.

const VERSION_TEXT := "Version %s"

var buttons: Array = []
var resume_button: Button
var chips_label: Label

func build() -> void:
	var app := app_node()
	var logo := Label.new()
	logo.text = "D A M E"
	logo.position = Vector2(0, 70)
	logo.size = Vector2(1280, 90)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 72)
	logo.add_theme_font_override("font", UiTheme.heading_font())
	logo.add_theme_color_override("font_color", UiTheme.GOLD)
	logo.add_theme_constant_override("outline_size", 12)
	logo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	add_child(logo)
	var sub := Label.new()
	sub.text = "Das Kartenspiel mit Gedächtnis und Bluff"
	sub.position = Vector2(0, 160)
	sub.size = Vector2(1280, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(1, 1, 1, 0.75)
	add_child(sub)

	var col := VBoxContainer.new()
	col.position = Vector2(440, 220)
	col.size = Vector2(400, 480)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	resume_button = _menu_button(col, "Spiel fortsetzen", func() -> void: app.resume_match())
	resume_button.visible = app != null and app.saves.has_save()
	_menu_button(col, "Gegen die KI spielen", func() -> void: _open_setup("ai"))
	_menu_button(col, "Hot-Seat (mehrere Menschen)", func() -> void: _open_setup("hotseat"))
	_menu_button(col, "Online (Test)", func() -> void: app.goto(app.ONLINE))
	_menu_button(col, "Regeln", func() -> void: app.goto(app.RULES))
	_menu_button(col, "Shop", func() -> void: app.goto(app.SHOP))
	_menu_button(col, "Statistik", func() -> void: app.goto(app.STATS))
	_menu_button(col, "Einstellungen", func() -> void: app.goto(app.SETTINGS))
	if app == null or not app.is_web():
		_menu_button(col, "Beenden", func() -> void: app.quit_game())

	chips_label = Label.new()
	chips_label.position = Vector2(980, 20)
	chips_label.size = Vector2(280, 30)
	chips_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(chips_label)
	var version := Label.new()
	version.text = VERSION_TEXT % str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	version.position = Vector2(980, 686)
	version.size = Vector2(280, 24)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", 13)
	version.modulate = Color(1, 1, 1, 0.5)
	add_child(version)
	if app != null:
		chips_label.text = tr("%d Chips") % app.profile.chips()
	for b in buttons:
		if b.visible:
			b.grab_focus()
			break
	# Marker fuer Smoke-Tests der exportierten Builds.
	print("DAME_READY")
	# Web-Test-Bruecke: direkt in einen Bildschirm springen (nur ?e2e=1, einmalig).
	if app != null and app.has_method("take_e2e_start_screen"):
		var start: String = app.take_e2e_start_screen()
		if start != "":
			app.goto.call_deferred(start)


func _menu_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := button(text, cb)
	b.custom_minimum_size = Vector2(400, 44)
	parent.add_child(b)
	buttons.append(b)
	return b


func _open_setup(mode: String) -> void:
	var app := app_node()
	if app == null:
		return
	app.pending = {"setup_mode": mode}
	app.goto(app.SETUP)
