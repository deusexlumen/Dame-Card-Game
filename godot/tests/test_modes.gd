extends RefCounted

# Spielmodi (CONCEPT_DECISIONS 15): Regelschalter und Joker. Das Grundspiel bleibt unveraendert.

const DameRulesScript = preload("res://scripts/dame_rules.gd")

var t


func run(ctx) -> void:
	t = ctx
	_check_classic_defaults()
	_check_switches()
	_check_throw_in_off()
	_check_joker_pool_and_value()
	_check_joker_copies_jack_and_king()
	_check_joker_no_effect_and_no_throw_in()
	_check_save_roundtrip()
	_check_joker_table_and_art()


func _hands() -> Array:
	var h: Array = []
	var ranks := [["9", "8", "6", "4"], ["7", "2", "3", "4"], ["7", "5", "6", "2"], ["8", "9", "10", "3"]]
	for seat in range(4):
		var hand: Array = []
		for i in range(4):
			hand.append({"suit": ["hearts", "clubs", "spades", "diamonds"][seat], "rank": ranks[seat][i]})
		h.append(hand)
	return h


func _new(cfg: Dictionary):
	var r = DameRulesScript.new()
	r.start_match(cfg)
	return r


func _check_classic_defaults() -> void:
	var r = _new({"ai_seats": []})
	t.expect(str(r.state.mode) == "classic", "Standardmodus ist nicht classic")
	t.expect(int(r.state.hand_size) == 4 and int(r.state.penalty_count) == 1 and int(r.state.safe_circuits) == 2, "Grundspiel-Schalter weichen ab")
	t.expect(int(r.state.jokers) == 0 and bool(r.state.throw_in), "Grundspiel hat Joker oder kein Mitwerfen")
	t.expect(r.state.players[0].hand.size() == 4 and r.state.deck.size() + r.state.discard.size() == 52 - 16, "Grundspiel teilt falsch")
	t.expect(r.assert_zones(), "Zonen im Grundspiel: %s" % r.zone_error)
	var weird = _new({"ai_seats": [], "mode": "unsinn"})
	t.expect(str(weird.state.mode) == "classic", "unbekannter Modus faellt nicht auf classic zurueck")


func _check_switches() -> void:
	var r = _new({"ai_seats": [], "mode": "custom", "hand_size": 6, "penalty_count": 2, "safe_circuits": 0})
	t.expect(r.state.players[0].hand.size() == 6 and r.state.deck.size() == 52 - 24, "Handgroesse 6 wird nicht ausgeteilt")
	t.expect(r.assert_zones(), "Zonen mit Handgroesse 6: %s" % r.zone_error)
	# Zwei Strafkarten pro Fehler: Mitwerfen ohne Ablage kostet nichts, mit falscher Karte zwei.
	r.apply_action({"type": "draw_deck", "seat": 0})
	r.apply_action({"type": "discard_drawn", "seat": 0})
	var top_rank := str(r.top_discard().rank)
	var wrong := -1
	for i in range(r.state.players[1].hand.size()):
		if str(r.state.players[1].hand[i].rank) != top_rank:
			wrong = i
			break
	if wrong >= 0:
		r.apply_action({"type": "discard_extra", "seat": 1, "hand_index": wrong})
		t.expect(r.state.players[1].penalty_cards.size() == 2, "penalty_count 2 gibt %d Strafkarten" % r.state.players[1].penalty_cards.size())
	t.expect(r.assert_zones(), "Zonen nach Doppelstrafe: %s" % r.zone_error)
	t.expect(int(r.state.safe_circuits) == 0, "Schonfrist-Schalter fehlt")


func _check_throw_in_off() -> void:
	var r = _new({"ai_seats": [], "preset_hands": _hands(), "throw_in": false,
		"draw_first": [{"suit": "diamonds", "rank": "7"}]})
	r.apply_action({"type": "draw_deck", "seat": 0})
	r.apply_action({"type": "discard_drawn", "seat": 0})
	var res: Dictionary = r.apply_action({"type": "discard_extra", "seat": 1, "hand_index": 0})
	t.expect(not bool(res.ok) and r.state.players[1].penalty_cards.is_empty() and r.state.players[1].hand.size() == 4, "Mitwerfen laesst sich im Modus nicht abschalten")


func _check_joker_pool_and_value() -> void:
	var r = _new({"ai_seats": [], "mode": "joker"})
	t.expect(int(r.state.jokers) == 2, "Joker-Modus ohne zwei Joker")
	var total: int = r.state.deck.size() + r.state.discard.size()
	for p in r.state.players:
		total += p.hand.size() + p.penalty_cards.size()
	t.expect(total == 54, "Joker-Modus hat %d statt 54 Karten" % total)
	t.expect(r.assert_zones(), "Zonen mit Jokern: %s" % r.zone_error)
	var found := 0
	for c in r.state.deck:
		if str(c.rank) == "JK":
			found += 1
			t.expect(int(c.value) == 3, "Joker-Wert ist nicht 3")
	for p in r.state.players:
		for c in p.hand:
			if str(c.rank) == "JK":
				found += 1
	t.expect(found == 2, "es gibt %d statt 2 Joker" % found)


func _joker_game(first: Dictionary):
	return _new({"ai_seats": [], "mode": "joker", "preset_hands": _hands(),
		"draw_first": [first, {"suit": "joker", "rank": "JK"}, {"suit": "hearts", "rank": "2"}]})


func _check_joker_copies_jack_and_king() -> void:
	for rank in ["J", "K"]:
		var r = _joker_game({"suit": "diamonds", "rank": rank})
		r.apply_action({"type": "draw_deck", "seat": 0})
		r.apply_action({"type": "discard_drawn", "seat": 0})
		t.expect(str(r.state.turn_step) == ("jack" if rank == "J" else "king"), "%s loest keinen Schritt aus" % rank)
		if rank == "J":
			r.apply_action({"type": "look_card", "seat": 0, "target_seat": 1, "hand_index": 0})
		else:
			r.apply_action({"type": "king_swap", "seat": 0, "a_seat": 1, "a_index": 0, "b_seat": 2, "b_index": 0})
		t.expect(bool(r.apply_action({"type": "end_turn", "seat": 0}).ok), "Zugende vor dem Joker scheitert")
		r.apply_action({"type": "draw_deck", "seat": 1})
		r.apply_action({"type": "discard_drawn", "seat": 1})
		t.expect(str(r.top_discard().rank) == "JK", "Joker liegt nicht oben")
		t.expect(str(r.state.turn_step) == ("jack" if rank == "J" else "king"), "Joker wiederholt %s nicht (Schritt %s)" % [rank, str(r.state.turn_step)])
		t.expect(r.assert_zones(), "Zonen nach Joker: %s" % r.zone_error)


func _check_joker_no_effect_and_no_throw_in() -> void:
	var r = _joker_game({"suit": "diamonds", "rank": "5"})
	r.apply_action({"type": "draw_deck", "seat": 0})
	r.apply_action({"type": "discard_drawn", "seat": 0})
	r.apply_action({"type": "end_turn", "seat": 0})
	r.apply_action({"type": "draw_deck", "seat": 1})
	r.apply_action({"type": "discard_drawn", "seat": 1})
	t.expect(str(r.state.turn_step) == "extra", "Joker ueber einer 5 loest etwas aus")
	# Auf dem Joker darf nichts mitgeworfen werden, auch kein zweiter Joker.
	var res: Dictionary = r.apply_action({"type": "discard_extra", "seat": 2, "hand_index": 0})
	t.expect(not bool(res.ok) and r.state.players[2].penalty_cards.size() == 1, "Mitwerfen auf den Joker kostet keine Strafkarte")


func _check_save_roundtrip() -> void:
	var r = _new({"ai_seats": [], "mode": "joker", "hand_size": 5})
	var copy = DameRulesScript.new()
	t.expect(copy.from_dict(r.to_dict()), "Joker-Spielstand laesst sich nicht laden: %s" % copy.zone_error)
	t.expect(str(copy.state.mode) == "joker" and int(copy.state.hand_size) == 5, "Modus geht beim Speichern verloren")


func _check_joker_table_and_art() -> void:
	# Joker-Partie am Tisch: KI-Spiel laeuft ohne Fehler durch, Kartenbild und Name existieren.
	var art = load("res://scripts/ui/card_art.gd")
	var joker := {"rank": "JK", "suit": "joker", "value": 3}
	for skin in ["klassisch", "vierfarben", "jumbo", "noir"]:
		t.expect(art.face(joker, skin, "de") != null, "Joker-Kartenbild fehlt im Skin %s" % skin)
	t.expect(DameRulesScript.card_label(joker) == "Joker", "Joker-Name falsch")
	var r = _new({"ai_seats": [0, 1, 2, 3], "mode": "joker", "seed": 7})
	var ai = load("res://scripts/dame_ai.gd").new(3)
	var guard := 0
	while guard < 4000 and str(r.state.phase) != "round_end" and str(r.state.phase) != "game_over":
		guard += 1
		if not ai.complete_turn(r):
			t.expect(false, "KI-Zug im Joker-Modus scheitert: %s" % ai.last_error)
			break
	t.expect(guard < 4000, "Joker-Partie endet nicht")
	t.expect(r.assert_zones(), "Zonen nach Joker-Partie: %s" % r.zone_error)
