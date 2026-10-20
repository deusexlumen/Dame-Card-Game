extends RefCounted

# Koenig: zwei beliebige verdeckte Karten blind tauschen. KI waehlt immer eine gueltige Kombination,
# der Tisch laesst zwei beliebige Karten antippen und zeigt allen den Tausch (nie die Karten).

const TableScene = preload("res://scenes/table.tscn")
const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")

var t


func run(ctx) -> void:
	t = ctx
	_check_ai_always_valid()
	_check_ai_all_opponents_locked()
	_check_table_two_taps()
	_check_table_deselect_and_keyboard()
	_check_table_announces_for_observers()


func _hands() -> Array:
	return [
		[{"suit": "hearts", "rank": "4"}, {"suit": "spades", "rank": "3"}, {"suit": "diamonds", "rank": "5"}, {"suit": "clubs", "rank": "6"}],
		[{"suit": "hearts", "rank": "9"}, {"suit": "clubs", "rank": "5"}, {"suit": "diamonds", "rank": "6"}, {"suit": "spades", "rank": "7"}],
		[{"suit": "clubs", "rank": "8"}, {"suit": "hearts", "rank": "2"}, {"suit": "diamonds", "rank": "9"}, {"suit": "spades", "rank": "4"}],
		[{"suit": "hearts", "rank": "7"}, {"suit": "clubs", "rank": "9"}, {"suit": "diamonds", "rank": "2"}, {"suit": "spades", "rank": "6"}],
	]


func _king_step(ai_seats: Array, difficulty: String):
	var diffs := {}
	for s in ai_seats:
		diffs[s] = difficulty
	var r = DameRulesScript.new()
	r.start_match({"ai_seats": ai_seats, "difficulties": diffs, "preset_hands": _hands(), "draw_first": [{"suit": "diamonds", "rank": "K"}, {"suit": "hearts", "rank": "3"}]})
	r.apply_action({"type": "draw_deck", "seat": 0})
	r.apply_action({"type": "discard_drawn", "seat": 0})
	return r


func _check_ai_always_valid() -> void:
	for difficulty in ["easy", "medium", "hard"]:
		for seed in range(1, 13):
			var r = _king_step([0, 1, 2, 3], difficulty)
			var ai = DameAIScript.new(seed)
			t.expect(str(r.state.turn_step) == "king", "Testaufbau: kein König-Schritt")
			var res: Dictionary = ai.step(r)
			t.expect(bool(res.get("ok", false)) and str(r.state.turn_step) == "extra", "KI (%s, Seed %d): König-Tausch scheitert: %s" % [difficulty, seed, str(res.get("reason", ""))])
			t.expect(r.assert_zones(), "KI-Königstausch zerstoert die Zonen: %s" % r.zone_error)
			t.expect(r.state.last_king_swap != null, "KI-Königstausch ohne oeffentliche Plaetze")


func _check_ai_all_opponents_locked() -> void:
	# Alle anderen gesperrt: die KI tauscht zwei eigene Karten, statt im König-Schritt festzuhaengen.
	for difficulty in ["easy", "medium", "hard"]:
		var r = _king_step([0, 1, 2, 3], difficulty)
		for sd in [1, 2, 3]:
			r.state.players[sd].locked = true
		var ai = DameAIScript.new(3)
		var res: Dictionary = ai.step(r)
		t.expect(bool(res.get("ok", false)), "KI (%s) tauscht bei gesperrten Gegnern nicht: %s" % [difficulty, str(res.get("reason", ""))])
		t.expect(int(r.state.last_king_swap.a_seat) == 0 and int(r.state.last_king_swap.b_seat) == 0, "KI tauscht fremde gesperrte Karten")
	# Auch die sichere Ersatzaktion findet eine gueltige Wahl.
	var f = _king_step([0, 1, 2, 3], "medium")
	var fb: Dictionary = DameAIScript.new(1).fallback_action(f, 0)
	t.expect(str(fb.type) == "king_swap" and bool(f.apply_action(fb).ok), "Ersatzaktion fuer den König scheitert")


func _table():
	var table = TableScene.instantiate()
	table.instant_ai = true
	table.settings_override = {"memory_aid": false, "turn_timer": false, "animations": false}
	table.pending_config = {"peek_phase": false, "seat_count": 4, "ai_seats": [1, 2, 3], "names": ["Spieler", "A", "B", "C"], "preset_hands": _hands(), "draw_first": [{"suit": "diamonds", "rank": "K"}, {"suit": "hearts", "rank": "3"}]}
	t.root.add_child(table)
	table.run_ai_until_human()
	table._on_deck()
	table._on_drawn()
	return table


func _check_table_two_taps() -> void:
	var table = _table()
	t.expect(str(table._view.turn_step) == "king", "Tisch: kein König-Schritt")
	t.expect("erste Karte" in table._prompt.text, "Tisch: Hinweis zur ersten Karte fehlt: " + table._prompt.text)
	var id_a := str(table.rules.state.players[1].hand[0].id)
	var id_b := str(table.rules.state.players[2].hand[3].id)
	# Erste Karte: irgendeine fremde. Zweite: wieder eine fremde, anderer Spieler.
	table._on_card(1, 0)
	t.expect(table.king_a == Vector2i(1, 0), "Tisch: erste Königskarte nicht gemerkt")
	t.expect("zweite Karte" in table._prompt.text, "Tisch: Hinweis zur zweiten Karte fehlt")
	t.expect(str(table.rules.state.turn_step) == "king", "Tisch: Tausch schon nach der ersten Karte")
	table._on_card(2, 3)
	t.expect(str(table.rules.state.players[1].hand[0].id) == id_b and str(table.rules.state.players[2].hand[3].id) == id_a, "Tisch: zwei fremde Karten nicht getauscht")
	t.expect(table.king_a.y < 0, "Tisch: Auswahl nach dem Tausch nicht geleert")
	t.expect("blind getauscht" in table._toast.text, "Tisch: kein Hinweis auf den Tausch: " + table._toast.text)
	for seat in [1, 2, 3]:
		for cv in table._seats[seat].cards():
			t.expect(not cv.shows_face(), "Tisch: nach dem Königstausch ist eine fremde Karte offen")
	_free(table)


func _check_table_deselect_and_keyboard() -> void:
	var table = _table()
	table._on_card(0, 1)
	t.expect(table.king_a == Vector2i(0, 1), "Tisch: eigene erste Karte nicht gewaehlt")
	table._on_card(0, 1)
	t.expect(table.king_a.y < 0, "Tisch: dieselbe Karte hebt die Auswahl nicht auf")
	t.expect(str(table.rules.state.turn_step) == "king", "Tisch: Auswahl aufheben hat getauscht")
	# Tasten 1 und 3: zwei eigene Karten.
	var own1 := str(table.rules.state.players[0].hand[0].id)
	var own3 := str(table.rules.state.players[0].hand[2].id)
	table.select(0)
	table.select(2)
	t.expect(str(table.rules.state.players[0].hand[0].id) == own3 and str(table.rules.state.players[0].hand[2].id) == own1, "Tisch: Zahlentasten tauschen zwei eigene Karten nicht")
	_free(table)


func _check_table_announces_for_observers() -> void:
	# Auch wer nicht am Zug ist, bekommt Hinweis und Tonsignal (Plaetze, nie Karten).
	var table = _table()
	table._toast.text = ""
	table._announce_king_swap({"type": "king_swap", "seat": 0, "a_seat": 1, "a_index": 0, "b_seat": 3, "b_index": 2})
	t.expect("A" in table._toast.text and "Karte 1" in table._toast.text and "Karte 3" in table._toast.text, "Beobachter: Hinweis ohne Plaetze: " + table._toast.text)
	table._flash_cards([[1, 0], [3, 2]])
	t.expect(true, "Aufleuchten ohne Absturz")
	_free(table)


func _free(table) -> void:
	t.root.remove_child(table)
	table.free()
