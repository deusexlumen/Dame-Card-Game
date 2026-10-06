extends "res://scripts/screens/screen_base.gd"

# Online spielen: Partie erstellen oder mit Code beitreten, dann Lobby.
# Nur live (CONCEPT_DECISIONS §10). Sobald der Server den ersten Spielzustand
# schickt, wechselt die Ansicht zum Tisch.

const NetClientScript = preload("res://scripts/online/net_client.gd")
const TIMER_CHOICES := [20, 30, 45]

var name_edit: LineEdit
var server_edit: LineEdit
var seat_option: OptionButton
var timer_option: OptionButton
var code_edit: LineEdit
var create_button: Button
var join_button: Button
var resume_button: Button
var status_label: Label
var start_screen: VBoxContainer
var lobby_box: VBoxContainer
var lobby_code: Label
var lobby_seats: VBoxContainer
var start_match_button: Button
var lobby_hint: Label

func build() -> void:
	frame("Online spielen")
	var app := app_node()
	start_screen = VBoxContainer.new()
	start_screen.add_theme_constant_override("separation", 12)
	content.add_child(start_screen)
	start_screen.add_child(label("Alle spielen gleichzeitig, der Zugtimer läuft immer. Ein kurzes Funkloch kostet nichts. Wer länger als eine Minute weg ist, wird von einer KI vertreten und bekommt beim Wiedereinstieg eine Strafkarte. Nach fünf Minuten ist der Platz verloren.", 15))

	name_edit = LineEdit.new()
	name_edit.max_length = 16
	name_edit.text = str(app.settings.get_value("player_name")) if app != null else "Spieler"
	start_screen.add_child(row("Dein Name", name_edit, 200))

	var net = _net()
	resume_button = button("Zurück in die laufende Partie", _resume)
	resume_button.custom_minimum_size = Vector2(0, 44)
	resume_button.visible = net != null and not net.load_session().is_empty()
	start_screen.add_child(resume_button)

	start_screen.add_child(_heading("Neue Partie"))
	seat_option = option(["2 Plätze", "3 Plätze", "4 Plätze", "5 Plätze", "6 Plätze"], 2)
	start_screen.add_child(row("Anzahl Plätze", seat_option, 200))
	timer_option = option(["20 Sekunden", "30 Sekunden", "45 Sekunden"], 1)
	start_screen.add_child(row("Zugtimer", timer_option, 200))
	create_button = button("Partie erstellen", _create)
	create_button.custom_minimum_size = Vector2(0, 44)
	start_screen.add_child(create_button)

	start_screen.add_child(_heading("Beitreten"))
	code_edit = LineEdit.new()
	code_edit.max_length = 6
	code_edit.placeholder_text = "z. B. K7M2QX"
	start_screen.add_child(row("Code", code_edit, 200))
	join_button = button("Beitreten", _join)
	join_button.custom_minimum_size = Vector2(0, 44)
	start_screen.add_child(join_button)

	server_edit = LineEdit.new()
	var saved_url: String = str(net.load_session().get("url", "")) if net != null else ""
	server_edit.text = saved_url if saved_url != "" else NetClientScript.default_url()
	start_screen.add_child(row("Server", server_edit, 200))

	lobby_box = VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 12)
	lobby_box.visible = false
	content.add_child(lobby_box)
	lobby_box.add_child(label("Gib diesen Code an deine Mitspieler weiter:", 16))
	lobby_code = Label.new()
	lobby_code.add_theme_font_size_override("font_size", 54)
	lobby_code.add_theme_font_override("font", UiTheme.heading_font())
	lobby_code.add_theme_color_override("font_color", UiTheme.GOLD)
	lobby_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_box.add_child(lobby_code)
	lobby_seats = VBoxContainer.new()
	lobby_seats.add_theme_constant_override("separation", 6)
	lobby_box.add_child(lobby_seats)
	lobby_hint = label("", 15)
	lobby_box.add_child(lobby_hint)
	start_match_button = button("Partie starten", _start_match)
	start_match_button.custom_minimum_size = Vector2(0, 48)
	lobby_box.add_child(start_match_button)
	lobby_box.add_child(button("Lobby verlassen", _leave))

	status_label = label("", 16)
	status_label.modulate = Color(1.0, 0.8, 0.6)
	content.add_child(status_label)

	if net != null:
		net.welcome.connect(_on_welcome)
		net.lobby.connect(_on_lobby)
		net.state.connect(_on_state)
		net.failed.connect(_on_failed)
		net.disconnected.connect(func() -> void: status_label.text = tr("Verbindung getrennt. Verbinde neu …"))
		net.connected.connect(func() -> void: status_label.text = "")
		if net.in_room() and not net.last_lobby.is_empty():
			_on_lobby(net.last_lobby)
	create_button.grab_focus()


func _net():
	var app := app_node()
	return app.net() if app != null else null


func _heading(text: String) -> Label:
	var l := label(text, 22)
	l.add_theme_font_override("font", UiTheme.heading_font())
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	return l


func _player_name() -> String:
	var n := name_edit.text.strip_edges()
	var app := app_node()
	if app != null and n != "" and n != str(app.settings.get_value("player_name")):
		app.settings.set_value("player_name", n)
	return n


func _ensure_connected() -> bool:
	var net = _net()
	if net == null:
		return false
	var url := server_edit.text.strip_edges()
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		status_label.text = tr("Die Serveradresse beginnt mit ws:// oder wss://.")
		return false
	if not net.is_open() or net.url != url:
		net.close()
		net.connect_to(url)
		status_label.text = tr("Verbinde …")
	return true


func _create() -> void:
	if not _ensure_connected():
		return
	_net().create_room(_player_name(), seat_option.selected + 2, TIMER_CHOICES[timer_option.selected])


func _join() -> void:
	var code := code_edit.text.strip_edges().to_upper()
	if code.length() != 6:
		status_label.text = tr("Der Code hat sechs Zeichen.")
		return
	if not _ensure_connected():
		return
	_net().join_room(code, _player_name())


func _resume() -> void:
	var net = _net()
	if net != null and net.resume_saved():
		status_label.text = tr("Verbinde …")


func _start_match() -> void:
	var net = _net()
	if net != null:
		net.start_match()


func _leave() -> void:
	var net = _net()
	if net != null:
		net.leave()
	lobby_box.visible = false
	start_screen.visible = true
	resume_button.visible = false


func _on_welcome(_info: Dictionary) -> void:
	status_label.text = ""


func _on_lobby(info: Dictionary) -> void:
	var net = _net()
	start_screen.visible = false
	lobby_box.visible = true
	lobby_code.text = str(info.code)
	for c in lobby_seats.get_children():
		lobby_seats.remove_child(c)
		c.queue_free()
	var host: bool = net != null and net.is_host
	var open := 0
	for s in info.seats:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var kind := str(s.kind)
		var text := ""
		match kind:
			"human":
				text = str(s.name) + (tr(" (du)") if net != null and int(s.seat) == net.seat else "")
			"ai":
				text = tr("KI (%s)") % tr({"easy": "Einfach", "medium": "Mittel", "hard": "Schwer"}.get(str(s.difficulty), "Mittel"))
			_:
				text = tr("frei")
				open += 1
		var l := label(tr("Platz %d") % (int(s.seat) + 1) + ":  " + text, 18)
		l.custom_minimum_size = Vector2(420, 0)
		h.add_child(l)
		if host and int(s.seat) > 0 and kind != "human":
			var seat := int(s.seat)
			var to_ai := kind == "open"
			h.add_child(button("KI setzen" if to_ai else "Platz freigeben", func() -> void: net.set_seat_ai(seat, to_ai)))
		lobby_seats.add_child(h)
	start_match_button.visible = host
	if host:
		lobby_hint.text = tr("Freie Plätze übernimmt beim Start eine KI.") if open > 0 else tr("Alle Plätze sind besetzt.")
	else:
		lobby_hint.text = tr("Warte, bis der Gastgeber die Partie startet.")


func _on_state(_seat: int, _mirror: Dictionary, _meta: Dictionary) -> void:
	var app := app_node()
	if app != null:
		app.online_match()


func _on_failed(reason: String) -> void:
	status_label.text = tr(reason)
	var app := app_node()
	if app != null:
		app.audio.play("error")
