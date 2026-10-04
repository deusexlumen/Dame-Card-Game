extends RefCounted

# M1: Plaetze 2-4, Zonen, Spielende, Speichern, Seeds, leere Stapel.

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")

var t

func run(ctx) -> void:
	t = ctx
	_check_seat_counts()
	_check_seed_determinism()
	_check_empty_piles()
	_check_false_call_penalty_unique()
	_check_scoring_rules()
	_check_game_over()
	_check_auto_dame_on_empty_hand()
	_check_save_roundtrip()
	_check_save_rejects_bad_data()
	for seed in [1, 2, 3, 4, 5]:
		_check_full_game(seed)


func _new_rules(config: Dictionary):
	var rules = DameRulesScript.new()
	rules.start_match(config)
	return rules


func _check_seat_counts() -> void:
	for n in [2, 3, 4]:
		var rules = _new_rules({"seed": 7, "seat_count": n, "ai_seats": []})
		t.expect(rules.seat_count() == n, "seat_count %d falsch: %d" % [n, rules.seat_count()])
		t.expect(rules.state.players.size() == n, "%d Plaetze: falsche Spielerzahl" % n)
		t.expect(rules.state.deck.size() == 52 - 4 * n, "%d Plaetze: Stapelgroesse %d" % [n, rules.state.deck.size()])
		t.expect(rules.assert_zones(), "%d Plaetze: Zonen nach Ausgabe kaputt: %s" % [n, rules.zone_error])
		var order: Array = []
		for _i in range(2 * n):
			order.append(int(rules.state.current_index))
			_auto_turn(rules, 999)
		var expected: Array = []
		for i in range(2 * n):
			expected.append(i % n)
		t.expect(order == expected, "%d Plaetze: Zugreihenfolge %s" % [n, str(order)])
		t.expect(int(rules.state.round) == 3, "%d Plaetze: nach zwei Umlaeufen Runde %d" % [n, int(rules.state.round)])
		t.expect(DameViewScript.for_viewer(rules, 0).players.size() == n, "%d Plaetze: Sicht hat falsche Platzzahl" % n)
	var too_many = _new_rules({"seat_count": 9})
	t.expect(too_many.seat_count() == 4, "seat_count wird nicht auf 4 begrenzt")
	var too_few = _new_rules({"seat_count": 1})
	t.expect(too_few.seat_count() == 2, "seat_count wird nicht auf 2 begrenzt")
	var legacy = _new_rules({"ai_seat": 2})
	t.expect(bool(legacy.state.players[2].is_ai) and not bool(legacy.state.players[0].is_ai), "ai_seat (alt) wird nicht beachtet")
	var multi = _new_rules({"ai_seats": [1, 3], "difficulties": {1: "easy", 3: "hard"}})
	t.expect(bool(multi.state.players[1].is_ai) and bool(multi.state.players[3].is_ai), "ai_seats nicht gesetzt")
	t.expect(str(multi.state.players[3].difficulty) == "hard", "Schwierigkeit nicht gesetzt")
	t.expect(str(multi.state.players[2].difficulty) == "medium", "Standard-Schwierigkeit nicht medium")


func _hand_ids(rules) -> Array:
	var out: Array = []
	for p in rules.state.players:
		for c in p.hand:
			out.append(str(c.id))
	return out


func _check_seed_determinism() -> void:
	var a = _new_rules({"seed": 11})
	var b = _new_rules({"seed": 11})
	var c = _new_rules({"seed": 12})
	t.expect(_hand_ids(a) == _hand_ids(b), "gleicher Seed, andere Ausgabe")
	t.expect(_hand_ids(a) != _hand_ids(c), "anderer Seed, gleiche Ausgabe")
	for r in [a, c]:
		r.state.dame_caller_index = 0
		r._resolve_round()
		r.apply_action({"type": "start_next_round"})
	t.expect(_hand_ids(a) != _hand_ids(c), "zweite Ausgabe ignoriert den Seed")
	t.expect(int(a.state.deal) == 2, "Ausgabe-Zaehler nicht 2")
	t.expect(int(a.state.round) == 1 and bool(a.state.safe_phase), "neue Ausgabe startet nicht in Runde 1 mit Safe Phase")


func _check_empty_piles() -> void:
	var rules = _new_rules({"seed": 3})
	rules.state.deck.clear()
	rules.state.discard.clear()
	var r1: Dictionary = rules.apply_action({"type": "draw_deck", "seat": 0})
	t.expect(not bool(r1.ok), "Ziehen aus leerem Stapel war erlaubt")
	t.expect("Keine Karten" in str(r1.reason), "leerer Stapel: Grund unklar: " + str(r1.reason))
	var r2: Dictionary = rules.apply_action({"type": "draw_discard", "seat": 0})
	t.expect(not bool(r2.ok), "Ziehen aus leerer Ablage war erlaubt")
	var before: int = rules.state.players[0].penalty_cards.size()
	var pen: Dictionary = rules._give_one_penalty(rules.state.players[0], "test")
	t.expect(pen.is_empty(), "Strafkarte aus leerem Stapel erfunden")
	t.expect(rules.state.players[0].penalty_cards.size() == before, "Phantom-Strafkarte angehaengt")


func _check_false_call_penalty_unique() -> void:
	var rules = _new_rules({"seed": 5, "seat_count": 3})
	# Ansager hat sicher nicht weniger: alle Haende gleich teuer machen.
	rules.state.dame_caller_index = 0
	for p in rules.state.players:
		for c in p.hand:
			c.value = 5
	rules._resolve_round()
	t.expect(bool(rules.state.last_round_false_call), "Gleichstand gilt nicht als falsche Ansage")
	t.expect(rules.state.players[0].penalty_cards.size() == 1, "falsche Ansage ohne Strafkarte")
	var r: Dictionary = rules.apply_action({"type": "start_next_round"})
	t.expect(bool(r.ok), "naechste Ausgabe scheitert: " + str(r.reason))
	t.expect(rules.state.players[0].hand.size() == 5, "Ansager hat nicht 5 Karten")
	t.expect(rules.assert_zones(), "Strafkarte doppelt in neuer Ausgabe: " + rules.zone_error)


func _set_hand_value(player: Dictionary, total: int) -> void:
	# Erste Karte traegt den Wert, Rest 0. Nur fuer Punkte-Tests.
	for i in range(player.hand.size()):
		player.hand[i].value = total if i == 0 else 0
	player.penalty_cards = []


func _check_scoring_rules() -> void:
	var rules = _new_rules({"seed": 8, "seat_count": 3})
	_set_hand_value(rules.state.players[0], 3)
	_set_hand_value(rules.state.players[1], 4)
	_set_hand_value(rules.state.players[2], 20)
	rules.state.players[1].total_score = 46
	rules.state.players[2].total_score = 31
	rules.state.dame_caller_index = 0
	rules._resolve_round()
	t.expect(not bool(rules.state.last_round_false_call), "strikt weniger gilt nicht als richtig")
	t.expect(rules.state.players[0].penalty_cards.is_empty(), "richtige Ansage hat Strafkarte")
	t.expect(int(rules.state.players[0].total_score) == 3, "Punkte Ansager falsch")
	t.expect(int(rules.state.players[1].total_score) == 0, "genau 50 setzt nicht auf 0")
	t.expect(bool(rules.state.players[2].eliminated), "51 scheidet nicht aus")
	t.expect(str(rules.state.phase) == "round_end", "zwei Uebrige: nicht round_end")
	var r: Dictionary = rules.apply_action({"type": "start_next_round"})
	t.expect(bool(r.ok), "naechste Ausgabe nach Ausscheiden scheitert")
	t.expect(rules.state.players[2].hand.is_empty(), "Ausgeschiedener bekommt Karten")
	t.expect(rules.assert_zones(), "Zonen nach Ausscheiden kaputt: " + rules.zone_error)
	for _i in range(4):
		t.expect(int(rules.state.current_index) != 2, "Ausgeschiedener ist am Zug")
		_auto_turn(rules, 999)


func _check_game_over() -> void:
	var rules = _new_rules({"seed": 9, "seat_count": 2, "ai_seats": [1]})
	_set_hand_value(rules.state.players[0], 2)
	_set_hand_value(rules.state.players[1], 10)
	rules.state.players[1].total_score = 48
	rules.state.dame_caller_index = 0
	rules._resolve_round()
	t.expect(str(rules.state.phase) == "game_over", "letzter Uebriger: kein game_over")
	t.expect(int(rules.state.winner_index) == 0, "Sieger falsch: %d" % int(rules.state.winner_index))
	var r: Dictionary = rules.apply_action({"type": "start_next_round"})
	t.expect(not bool(r.ok), "nach game_over startet neue Ausgabe")
	var view: Dictionary = DameViewScript.for_viewer(rules, 0)
	t.expect(int(view.winner_index) == 0, "Sicht nennt Sieger nicht")
	# Kein Mensch mehr im Spiel: Ende, Sieger ist die KI mit den wenigsten Punkten.
	var solo = _new_rules({"seed": 10, "seat_count": 3, "ai_seats": [1, 2]})
	_set_hand_value(solo.state.players[0], 30)
	_set_hand_value(solo.state.players[1], 2)
	_set_hand_value(solo.state.players[2], 5)
	solo.state.players[0].total_score = 40
	solo.state.players[1].total_score = 20
	solo.state.players[2].total_score = 10
	solo.state.dame_caller_index = 1
	solo._resolve_round()
	t.expect(str(solo.state.phase) == "game_over", "kein Mensch mehr: kein game_over")
	t.expect(int(solo.state.winner_index) == 2, "Sieger bei Gleichstand der KI falsch: %d" % int(solo.state.winner_index))


func _check_auto_dame_on_empty_hand() -> void:
	var rules = _new_rules({"seed": 4, "seat_count": 2})
	var p: Dictionary = rules.state.players[0]
	var keep: Dictionary = p.hand[0]
	p.hand = [keep]
	p.known = [0]
	rules.state.deck = []
	rules.state.discard = [{"id": "test-top", "suit": "clubs", "rank": str(keep.rank), "value": int(keep.value), "face_up": true}]
	rules.state.round = 3
	rules.state.safe_phase = false
	rules.state.turn_step = "extra"
	var r: Dictionary = rules.apply_action({"type": "discard_extra", "seat": 0, "hand_index": 0})
	t.expect(bool(r.ok), "Extra mit letzter Karte scheitert: " + str(r.reason))
	t.expect(p.hand.is_empty(), "Hand nicht leer")
	t.expect(str(rules.state.phase) == "dame_called", "leere Hand ruft nicht automatisch Dame")
	t.expect(int(rules.state.dame_caller_index) == 0, "falscher Ansager")


func _check_save_roundtrip() -> void:
	var rules = _new_rules({"seed": 21, "seat_count": 3, "ai_seats": [2], "difficulties": {2: "hard"}})
	for _i in range(5):
		_auto_turn(rules, 999)
	var data: Dictionary = rules.to_dict()
	t.expect(int(data.get("save_version", 0)) == rules.SAVE_VERSION, "save_version fehlt")
	var text := var_to_str(data)
	var back = str_to_var(text)
	var copy = DameRulesScript.new()
	t.expect(copy.from_dict(back), "gueltiger Spielstand abgelehnt: " + copy.zone_error)
	t.expect(var_to_str(DameViewScript.for_viewer(copy, 0)) == var_to_str(DameViewScript.for_viewer(rules, 0)), "Sicht nach Laden anders")
	_auto_turn(copy, 999)
	_auto_turn(rules, 999)
	t.expect(var_to_str(copy.state) == var_to_str(rules.state), "Spiel laeuft nach Laden anders weiter")
	data.state.players[0].name = "geaendert"
	t.expect(str(rules.state.players[0].name) != "geaendert", "to_dict teilt Referenzen mit dem Zustand")


func _check_save_rejects_bad_data() -> void:
	var rules = _new_rules({"seed": 22})
	var before := var_to_str(rules.state)
	t.expect(not rules.from_dict({}), "leerer Spielstand angenommen")
	t.expect(not rules.from_dict({"save_version": 999, "state": rules.state.duplicate(true)}), "fremde Version angenommen")
	var dup: Dictionary = rules.to_dict()
	dup.state.players[0].hand[0] = dup.state.players[1].hand[0].duplicate()
	t.expect(not rules.from_dict(dup), "doppelte Karte angenommen")
	var broken: Dictionary = rules.to_dict()
	broken.state.erase("deck")
	t.expect(not rules.from_dict(broken), "Spielstand ohne Stapel angenommen")
	t.expect(not rules.from_dict({"save_version": rules.SAVE_VERSION, "state": "kaputt"}), "Text statt Zustand angenommen")
	t.expect(var_to_str(rules.state) == before, "abgelehnter Spielstand hat Zustand veraendert")


func _check_full_game(seed: int) -> void:
	var rules = _new_rules({"seed": seed, "seat_count": 4, "ai_seats": [0, 1, 2, 3]})
	var guard := 0
	var zones_ok := true
	while str(rules.state.phase) != "game_over" and guard < 4000:
		guard += 1
		if not _auto_turn(rules, 4):
			break
		if not rules.assert_zones():
			zones_ok = false
			t.expect(false, "Seed %d: Zonen kaputt nach Zug %d: %s" % [seed, guard, rules.zone_error])
			break
	t.expect(zones_ok, "Seed %d: Zonenfehler" % seed)
	t.expect(str(rules.state.phase) == "game_over", "Seed %d: Spiel endet nicht (Zuege %d, Ausgabe %d)" % [seed, guard, int(rules.state.deal)])
	var w := int(rules.state.winner_index)
	var all_out := true
	for p in rules.state.players:
		if not bool(p.eliminated):
			all_out = false
	t.expect(w >= 0 and (all_out or not bool(rules.state.players[w].eliminated)), "Seed %d: Sieger ungueltig (%d)" % [seed, w])


# Spielt den Zug des aktuellen Platzes mit einer einfachen festen Strategie.
func _auto_turn(rules, call_from_round: int) -> bool:
	var phase := str(rules.state.phase)
	if phase == "round_end":
		return bool(rules.apply_action({"type": "start_next_round"}).ok)
	if phase == "game_over":
		return false
	var seat := int(rules.state.current_index)
	var n: int = rules.seat_count()
	if rules.can_call_dame() and int(rules.state.round) >= call_from_round:
		return bool(rules.apply_action({"type": "call_dame", "seat": seat}).ok)
	var draw_type := "draw_discard" if rules.must_take_queen() else "draw_deck"
	var d: Dictionary = rules.apply_action({"type": draw_type, "seat": seat})
	if not bool(d.ok):
		t.expect(false, "Ziehen scheitert: " + str(d.reason))
		return false
	rules.apply_action({"type": "discard_drawn", "seat": seat})
	var target := -1
	var king_target := -1
	for k in range(1, n):
		var cand := (seat + k) % n
		var cp: Dictionary = rules.state.players[cand]
		if bool(cp.eliminated) or cp.hand.is_empty():
			continue
		if target < 0:
			target = cand
		if king_target < 0 and not bool(cp.locked):
			king_target = cand
	if str(rules.state.turn_step) == "jack":
		rules.apply_action({"type": "look_card", "seat": seat, "target_seat": target, "hand_index": 0})
	elif str(rules.state.turn_step) == "king":
		rules.apply_action({"type": "king_swap", "seat": seat, "opponent_seat": king_target, "opponent_index": 0, "chosen_index": 0})
	var e: Dictionary = rules.apply_action({"type": "end_turn", "seat": seat})
	if not bool(e.ok):
		t.expect(false, "Zugende scheitert Sitz %d Schritt %s: %s" % [seat, str(rules.state.turn_step), str(e.reason)])
		return false
	return true
