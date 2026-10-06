extends "res://scripts/screens/screen_base.gd"

# Statistik des lokalen Spielers (nur Partien mit genau einem Menschen).

var grid: GridContainer
var reset_button: Button
var confirm_box: HBoxContainer

func build() -> void:
	frame("Statistik")
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	content.add_child(label("Gezählt werden Partien gegen die KI. Hot-Seat-Partien zählen nicht.", 14))
	reset_button = button("Statistik zurücksetzen", func() -> void: confirm_box.visible = true)
	content.add_child(reset_button)
	confirm_box = HBoxContainer.new()
	confirm_box.visible = false
	confirm_box.add_theme_constant_override("separation", 12)
	confirm_box.add_child(label("Wirklich alles löschen?", 16))
	confirm_box.add_child(button("Ja, zurücksetzen", reset_stats))
	confirm_box.add_child(button("Abbrechen", func() -> void: confirm_box.visible = false))
	content.add_child(confirm_box)
	refresh()
	back_button.grab_focus()


func refresh() -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var app := app_node()
	if app == null:
		return
	var v: Dictionary = app.stats.values
	var best := int(v.best_round_score)
	var entries := [
		["Partien gespielt", str(int(v.games_played))],
		["Partien gewonnen", str(int(v.games_won))],
		["Siegquote", "%d %%" % int(round(app.stats.win_rate() * 100.0))],
		["Ausgaben gespielt", str(int(v.rounds_played))],
		["Dame gerufen", str(int(v.dame_calls))],
		["davon richtig", str(int(v.successful_dame_calls))],
		["Strafkarten", str(int(v.total_penalty_cards))],
		["Beste Ausgabe", "–" if best < 0 else tr("%d Punkte") % best],
		["Chips", str(app.profile.chips())],
		["Zuletzt gespielt", "–" if str(v.last_played_at) == "" else str(v.last_played_at).replace("T", " ")],
	]
	for e in entries:
		var key := label(str(e[0]), 18)
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		key.custom_minimum_size = Vector2(340, 0)
		grid.add_child(key)
		var val := label(str(e[1]), 18)
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		val.custom_minimum_size = Vector2(260, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)


func reset_stats() -> void:
	var app := app_node()
	if app != null:
		app.stats.reset()
	confirm_box.visible = false
	refresh()
