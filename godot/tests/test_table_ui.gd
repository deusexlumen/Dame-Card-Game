extends RefCounted

# M3: Tisch zeigt nur erlaubte Karten, Tasten funktionieren, Hot-Seat deckt ab,
# Rundenende/Spielende, Speichern/Fortsetzen, Zugtimer.

const TableScene = preload("res://scenes/table.tscn")

var t
var app

func run(ctx) -> void:
	t = ctx
	app = ctx.root.get_node_or_null("/root/App")
	_check_single_player_view()
	_check_keyboard_turn()
	_check_full_deal_and_stats()
	_check_hotseat_handoff()
	_check_memory_aid_off()
	_check_turn_timer()
	_check_resume()
	_check_game_over_rewards_once()


func _make_table(cfg: Dictionary, overrides: Dictionary = {}):
	var table = TableScene.instantiate()
	table.instant_ai = true
	var s := {"memory_aid": true, "turn_timer": false, "animations": false}
	s.merge(overrides, true)
	table.settings_override = s
	table.pending_config = cfg
	t.root.add_child(table)
	table.run_ai_until_human()
	return table


func _free(table) -> void:
	t.root.remove_child(table)
	table.free()


func _key(table, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	table._unhandled_input(ev)
	table.run_ai_until_human()


# Alle sichtbaren Kartengesichter eines Platzes.
func _faces(table, seat: int) -> Array:
	var out: Array = []
	for cv in table._seats[seat].cards():
		if cv.shows_face():
			out.append(int(cv.index))
	return out


func _cfg(extra: Dictionary = {}) -> Dictionary:
	var c := {"seed": 101, "seat_count": 4, "ai_seats": [1, 2, 3], "difficulties": {1: "medium", 2: "medium", 3: "hard"}, "names": ["Spieler", "A", "B", "C"]}
	c.merge(extra, true)
	return c


func _check_single_player_view() -> void:
	var table = _make_table(_cfg())
	t.expect(table.viewer_seat == 0, "Betrachter ist nicht Platz 0")
	t.expect(str(table._seats[0].get_meta("role")) == "self", "Platz 0 nicht unten")
	t.expect(_faces(table, 0) == [0, 1], "eigene Startkarten falsch sichtbar: %s" % str(_faces(table, 0)))
	for seat in [1, 2, 3]:
		t.expect(_faces(table, seat).is_empty(), "fremde Karte sichtbar Platz %d" % seat)
		for cv in table._seats[seat].cards():
			t.expect(cv.describe() == "Verdeckte Karte", "Tooltip verraet fremde Karte")
	t.expect(table._human_turn(), "Mensch ist zu Beginn nicht am Zug")
	t.expect("Ziehe" in table._prompt.text, "Hinweis fuer Ziehen fehlt: " + table._prompt.text)
	_free(table)


func _check_keyboard_turn() -> void:
	var table = _make_table(_cfg({"seed": 102}))
	_key(table, KEY_SPACE)
	t.expect(table.rules.state.drawn_card != null, "Leertaste zieht nicht")
	t.expect(table._drawn_view.shows_face(), "gezogene Karte nicht sichtbar")
	_key(table, KEY_A)
	t.expect(table.rules.state.drawn_card == null, "A legt nicht ab")
	_resolve_powers(table)
	t.expect(str(table.rules.state.turn_step) == "extra", "nicht im Extra-Schritt: " + str(table.rules.state.turn_step))
	_key(table, KEY_ENTER)
	t.expect(int(table.rules.state.current_index) == 0, "nach KI-Zuegen nicht wieder am Zug")
	t.expect(int(table.rules.state.round) == 2, "Runde nicht weitergezaehlt")
	_key(table, KEY_2)
	t.expect(table.selected == 1, "Taste 2 waehlt nicht Karte 2")
	t.expect(table._seats[0].card_at(1).has_focus(), "Fokus nicht auf gewaehlter Karte")
	table._refresh()
	t.expect(table._seats[0].card_at(1).has_focus(), "Fokus nach Neuzeichnen verloren")
	_free(table)


func _resolve_powers(table) -> void:
	var step := str(table.rules.state.turn_step)
	if step == "jack":
		table._on_card(1, 0)
	elif step == "king":
		table._on_card(0, 0)
		table._on_card(1, 0)


# Ein Menschenzug ueber die Tisch-API: ziehen, ablegen, Sonderkarten, beenden.
func _human_turn(table, call_from_round: int) -> void:
	if table.rules.can_call_dame() and int(table.rules.state.round) >= call_from_round:
		table.call_dame()
		table.run_ai_until_human()
		return
	if table.rules.must_take_queen():
		table._on_discard()
	else:
		table._on_deck()
	table._on_drawn()
	_resolve_powers(table)
	table.end_turn()
	table.run_ai_until_human()


func _check_full_deal_and_stats() -> void:
	var rounds_before := int(app.stats.values.rounds_played) if app != null else 0
	var chips_before := int(app.profile.chips()) if app != null else 0
	var table = _make_table(_cfg({"seed": 103}))
	var guard := 0
	while str(table.rules.state.phase) != "round_end" and str(table.rules.state.phase) != "game_over" and guard < 60:
		guard += 1
		if table._human_turn():
			_human_turn(table, 3)
		else:
			table.run_ai_until_human()
	t.expect(str(table.rules.state.phase) == "round_end", "Ausgabe endet nicht: " + str(table.rules.state.phase))
	t.expect(table._round_panel.visible, "Rundenende-Fenster fehlt")
	for seat in [1, 2, 3]:
		t.expect(_faces(table, seat).size() == table.rules.state.players[seat].hand.size(), "Rundenende zeigt nicht alle Karten von %d" % seat)
	if app != null:
		t.expect(int(app.stats.values.rounds_played) == rounds_before + 1, "Statistik zaehlt Ausgabe nicht")
		t.expect(int(app.profile.chips()) >= chips_before + 5, "keine Chips fuer die Ausgabe")
		table._after_change()
		t.expect(int(app.stats.values.rounds_played) == rounds_before + 1, "Ausgabe doppelt gezaehlt")
	_key(table, KEY_ENTER)
	t.expect(str(table.rules.state.phase) == "play", "Enter startet keine neue Ausgabe")
	t.expect(int(table.rules.state.deal) == 2, "Ausgabe-Zaehler nicht 2")
	t.expect(table.rules.assert_zones(), "Zonen nach neuer Ausgabe kaputt")
	_free(table)


func _check_hotseat_handoff() -> void:
	var table = _make_table({"seed": 104, "seat_count": 3, "ai_seats": [2], "names": ["Anna", "Ben", "KI"]})
	t.expect(table.is_hotseat(), "zwei Menschen ergeben kein Hot-Seat")
	t.expect(table.handoff_pending and table._handoff.visible, "Start ohne Uebergabe-Schirm")
	for seat in [0, 1, 2]:
		t.expect(_faces(table, seat).is_empty(), "vor Uebergabe sichtbare Karte Platz %d" % seat)
	table.confirm_handoff()
	t.expect(table.viewer_seat == 0, "nach Uebergabe nicht Anna")
	t.expect(_faces(table, 0) == [0, 1], "Anna sieht ihre Startkarten nicht")
	t.expect(_faces(table, 1).is_empty(), "Anna sieht Bens Karten")
	table._on_deck()
	table._on_drawn()
	_resolve_powers(table)
	table.end_turn()
	t.expect(int(table.rules.state.current_index) == 1, "Ben ist nicht dran")
	t.expect(table.handoff_pending and table._handoff.visible, "kein Uebergabe-Schirm vor Ben")
	for seat in [0, 1, 2]:
		t.expect(_faces(table, seat).is_empty(), "waehrend Uebergabe sichtbare Karte Platz %d" % seat)
	t.expect(not table._drawn_view.shows_face(), "gezogene Karte bleibt sichtbar")
	for seat in [0, 1, 2]:
		t.expect(_faces3d(table, seat).is_empty(), "3D: waehrend Uebergabe offene Karte Platz %d" % seat)
	var before_input = table.rules.state.drawn_card
	table._on_deck()
	t.expect(table.rules.state.drawn_card == before_input, "Eingabe hinter dem Uebergabe-Schirm moeglich")
	_key(table, KEY_ENTER)
	t.expect(table.viewer_seat == 1 and not table.handoff_pending, "Enter bestaetigt die Uebergabe nicht")
	t.expect(str(table._seats[1].get_meta("role")) == "self", "Bens Platz nicht unten")
	t.expect(_faces(table, 1) == [0, 1], "Ben sieht seine Startkarten nicht")
	t.expect(_faces(table, 0).is_empty(), "Ben sieht Annas Karten")
	if table._table3d != null:
		t.expect(_faces3d(table, 0).is_empty(), "3D: Ben sieht Annas Karten")
		var hands := 0
		for p in table.rules.state.players:
			hands += p.hand.size()
		# Handkarten plus Stapel, Ablage, gezogene Karte; keine Reste alter Plaetze.
		t.expect(table._table3d.card_node_count() == hands + 3, "3D: alte Karten nach Uebergabe liegen geblieben (%d statt %d)" % [table._table3d.card_node_count(), hands + 3])
	_free(table)


# Offene Kartengesichter im 3D-Tisch fuer einen Platz.
func _faces3d(table, seat: int) -> Array:
	var out: Array = []
	if table._table3d == null:
		return out
	for c in table._table3d._slots.get(seat, []):
		if c.shows_face():
			out.append(int(c.index))
	return out


func _check_memory_aid_off() -> void:
	var table = _make_table(_cfg({"seed": 105}), {"memory_aid": false})
	t.expect(_faces(table, 0) == [0, 1], "Startkarten werden nicht kurz gezeigt")
	table._reveal_until.clear()
	table._refresh()
	t.expect(_faces(table, 0).is_empty(), "ohne Gedaechtnishilfe bleiben Karten offen")
	_free(table)


func _check_turn_timer() -> void:
	var table = _make_table(_cfg({"seed": 106}), {"turn_timer": true, "turn_timer_seconds": 15})
	table._process(0.1)
	t.expect(table._timer_bar.visible, "Zugtimer nicht sichtbar")
	table._process(16.0)
	table.run_ai_until_human()
	t.expect(int(table.rules.state.round) == 2, "Zeitablauf beendet den Zug nicht")
	t.expect(table.rules.assert_zones(), "Zonen nach Zeitablauf kaputt")
	_free(table)


func _check_resume() -> void:
	if app == null:
		return
	var table = _make_table(_cfg({"seed": 107}))
	_human_turn(table, 99)
	var snapshot := var_to_str(table.rules.state)
	_free(table)
	t.expect(app.saves.has_save(), "kein Spielstand gespeichert")
	app.pending = {"mode": "resume"}
	var resumed = TableScene.instantiate()
	resumed.instant_ai = true
	resumed.settings_override = {"memory_aid": true}
	t.root.add_child(resumed)
	t.expect(var_to_str(resumed.rules.state) == snapshot, "fortgesetzter Stand weicht ab")
	_free(resumed)
	# Kaputter Spielstand: neues Spiel statt Absturz, Datei wird gesichert.
	var f := FileAccess.open(app.saves.path, FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	app.pending = {"mode": "resume"}
	var fresh = TableScene.instantiate()
	fresh.instant_ai = true
	t.root.add_child(fresh)
	t.expect(fresh.rules != null and str(fresh.rules.state.phase) == "play", "kaputter Spielstand startet kein Spiel")
	_free(fresh)


func _check_game_over_rewards_once() -> void:
	if app == null:
		return
	var games_before := int(app.stats.values.games_played)
	var chips_before := int(app.profile.chips())
	var table = _make_table(_cfg({"seed": 108, "seat_count": 2, "ai_seats": [1], "difficulties": {1: "hard"}}))
	var r = table.rules
	for i in range(r.state.players[0].hand.size()):
		r.state.players[0].hand[i].value = 0
	r.state.players[1].total_score = 49
	r.state.dame_caller_index = 0
	r._resolve_round()
	table._after_change()
	table._after_change()
	t.expect(table._over_panel.visible, "Spielende-Fenster fehlt")
	t.expect("Du gewinnst" in table._over_text.text, "Siegtext fehlt: " + table._over_text.text)
	t.expect(int(app.stats.values.games_played) == games_before + 1, "Partie nicht genau einmal gezaehlt")
	var expected: int = chips_before + 5 + 20 + 50 * 2
	t.expect(int(app.profile.chips()) == expected, "Chips falsch: %d statt %d" % [int(app.profile.chips()), expected])
	t.expect(not app.saves.has_save(), "Spielstand nach Spielende nicht geloescht")
	_free(table)
