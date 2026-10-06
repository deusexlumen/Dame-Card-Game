extends "res://scripts/screens/screen_base.gd"

# Spiel einrichten: Platzanzahl, je Platz Mensch/KI, Name, KI-Stufe.

const AI_NAMES := ["Lotte", "Bruno", "Erika", "Kurt", "Hilde", "Otto"]
const DIFF_KEYS := ["easy", "medium", "hard"]
const DIFF_LABELS := ["Einfach", "Mittel", "Schwer"]

var mode := "ai"
var seat_option: OptionButton
var rows: Array = []
var error_label: Label
var start_button: Button

func build() -> void:
	var app := app_node()
	if app != null and app.pending.has("setup_mode"):
		mode = str(app.pending.setup_mode)
		app.pending = {}
	frame("Neues Spiel" if mode == "ai" else "Hot-Seat")
	content.add_child(label("Hot-Seat: mehrere Menschen teilen sich ein Gerät. Vor jedem Zug wird der Tisch abgedeckt." if mode == "hotseat" else "Du spielst gegen KI-Gegner. Schwer gibt doppelte Sieg-Chips.", 15))
	seat_option = option(["2 Plätze", "3 Plätze", "4 Plätze", "5 Plätze", "6 Plätze"], 2 if mode == "ai" else 0)
	seat_option.item_selected.connect(func(_i: int) -> void: _rebuild_rows())
	content.add_child(row("Anzahl Plätze", seat_option, 200))
	var rows_box := VBoxContainer.new()
	rows_box.name = "Rows"
	rows_box.add_theme_constant_override("separation", 8)
	content.add_child(rows_box)
	error_label = label("", 16)
	error_label.modulate = Color(1.0, 0.7, 0.6)
	content.add_child(error_label)
	start_button = button("Spiel starten", start_game)
	start_button.custom_minimum_size = Vector2(0, 48)
	content.add_child(start_button)
	_rebuild_rows()
	start_button.grab_focus()


func seat_count() -> int:
	return seat_option.selected + 2


func _rebuild_rows() -> void:
	var box: VBoxContainer = content.get_node("Rows")
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	rows.clear()
	var app := app_node()
	var player_name: String = str(app.settings.get_value("player_name")) if app != null else "Spieler"
	var def_diff: int = DIFF_KEYS.find(str(app.settings.get_value("default_difficulty"))) if app != null else 1
	for seat in range(seat_count()):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var tag := label(tr("Platz %d") % (seat + 1), 17)
		tag.custom_minimum_size = Vector2(90, 0)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(tag)
		var is_human := seat == 0 or (mode == "hotseat" and seat == 1)
		var kind := option(["Mensch", "KI"], 0 if is_human else 1)
		kind.custom_minimum_size = Vector2(130, 0)
		kind.disabled = seat == 0
		h.add_child(kind)
		var name_edit := LineEdit.new()
		name_edit.max_length = 16
		name_edit.custom_minimum_size = Vector2(240, 0)
		if seat == 0:
			name_edit.text = player_name
		elif is_human:
			name_edit.text = tr("Spieler %d") % (seat + 1)
		else:
			name_edit.text = AI_NAMES[seat - 1]
		h.add_child(name_edit)
		var diff := option(DIFF_LABELS, maxi(def_diff, 0))
		diff.custom_minimum_size = Vector2(150, 0)
		diff.visible = not is_human
		h.add_child(diff)
		kind.item_selected.connect(func(i: int) -> void: diff.visible = i == 1)
		box.add_child(h)
		rows.append({"kind": kind, "name": name_edit, "difficulty": diff})


# Liefert die Konfiguration oder {} mit Fehlermeldung in error_label.
func build_config() -> Dictionary:
	var names: Array = []
	var ai_seats: Array = []
	var difficulties := {}
	var humans := 0
	for seat in range(rows.size()):
		var r: Dictionary = rows[seat]
		var n := str(r.name.text).strip_edges()
		if n == "":
			error_label.text = tr("Platz %d braucht einen Namen.") % (seat + 1)
			return {}
		if names.has(n):
			error_label.text = tr("Der Name „%s“ ist doppelt.") % n
			return {}
		names.append(n)
		if r.kind.selected == 1:
			ai_seats.append(seat)
			difficulties[seat] = DIFF_KEYS[r.difficulty.selected]
		else:
			humans += 1
	if humans == 0:
		error_label.text = "Mindestens ein Mensch muss mitspielen."
		return {}
	error_label.text = ""
	return {"seat_count": rows.size(), "ai_seats": ai_seats, "difficulties": difficulties, "names": names}


func start_game() -> void:
	var cfg := build_config()
	if cfg.is_empty():
		var app0 := app_node()
		if app0 != null:
			app0.audio.play("error")
		return
	var app := app_node()
	if app != null:
		var first: String = str(cfg.names[0])
		if first != str(app.settings.get_value("player_name")):
			app.settings.set_value("player_name", first)
		app.new_match(cfg)
