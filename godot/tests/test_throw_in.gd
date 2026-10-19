extends RefCounted

# Mitwerfen (CONCEPT_DECISIONS 13): jeder darf jederzeit, auch ausserhalb seines Zugs, eine verdeckte
# Karte mit gleichem Rang wie die oberste Ablagekarte ablegen. Richtig: Hand wird kleiner. Falsch oder
# zu spaet: eine Strafkarte, die Karte bleibt in der Hand.

const TableScene = preload("res://scenes/table.tscn")
const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const DameHostScript = preload("res://scripts/net/dame_host.gd")
const DameProtocol = preload("res://scripts/net/net_protocol.gd")

var t


func run(ctx) -> void:
	t = ctx
	_check_correct_throw_out_of_turn()
	_check_wrong_throw()
	_check_late_throw()
	_check_chain()
	_check_locked_and_eliminated_and_peek()
	_check_no_power_and_queen()
	_check_last_card_calls_dame()
	_check_own_turn_throw_shrinks_hand()
	_check_ai_reaction()
	_check_host_ai_react()
	_check_table_throw_in()
	_check_table_not_in_hotseat_or_peek()


# Platz 0 wirft eine 7 ab (Ziehen und Ablegen), danach steht er im Extra-Schritt.
# Platz 1 und 2 haben je eine 7 auf Index 0, Platz 3 keine.
func _game(extra: Dictionary = {}):
	var cfg := {
		"ai_seats": [],
		"preset_hands": [
			[{"suit": "hearts", "rank": "9"}, {"suit": "spades", "rank": "8"}, {"suit": "hearts", "rank": "6"}, {"suit": "diamonds", "rank": "4"}],
			[{"suit": "hearts", "rank": "7"}, {"suit": "clubs", "rank": "2"}, {"suit": "clubs", "rank": "3"}, {"suit": "clubs", "rank": "4"}],
			[{"suit": "spades", "rank": "7"}, {"suit": "clubs", "rank": "5"}, {"suit": "clubs", "rank": "6"}, {"suit": "spades", "rank": "2"}],
			[{"suit": "clubs", "rank": "8"}, {"suit": "clubs", "rank": "9"}, {"suit": "clubs", "rank": "10"}, {"suit": "spades", "rank": "3"}],
		],
		"draw_first": [
			{"suit": "diamonds", "rank": "7"},
			{"suit": "clubs", "rank": "A"},
			{"suit": "diamonds", "rank": "5"},
			{"suit": "hearts", "rank": "3"},
			{"suit": "hearts", "rank": "2"},
			{"suit": "diamonds", "rank": "2"},
		],
	}
	cfg.merge(extra, true)
	var r = DameRulesScript.new()
	r.start_match(cfg)
	return r


func _seven_on_top(r) -> void:
	r.apply_action({"type": "draw_deck", "seat": 0})
	r.apply_action({"type": "discard_drawn", "seat": 0})


func _act(r, type: String, seat: int, index: int = -1) -> Dictionary:
	var a := {"type": type, "seat": seat}
	if index >= 0:
		a["hand_index"] = index
	return r.apply_action(a)


func _check_correct_throw_out_of_turn() -> void:
	var r = _game()
	_seven_on_top(r)
	var deck_before: int = r.state.deck.size()
	var res := _act(r, "discard_extra", 1, 0)
	t.expect(bool(res.ok), "richtiges Mitwerfen ausserhalb des Zugs abgelehnt: %s" % str(res.get("reason", "")))
	t.expect(r.state.players[1].hand.size() == 3, "Hand wird nach richtigem Mitwerfen nicht kleiner")
	t.expect(r.state.players[1].penalty_cards.is_empty(), "richtiges Mitwerfen kostet eine Strafkarte")
	t.expect(r.state.deck.size() == deck_before, "richtiges Mitwerfen zieht eine Ersatzkarte")
	t.expect(str(r.top_discard().rank) == "7" and str(r.top_discard().suit) == "hearts", "mitgeworfene Karte liegt nicht oben")
	t.expect(bool(r.top_discard().face_up), "mitgeworfene Karte liegt nicht offen")
	t.expect(int(r.state.current_index) == 0 and str(r.state.turn_step) == "extra", "Mitwerfen stoert den Zug des anderen")
	t.expect(bool(_act(r, "end_turn", 0).ok), "Zugende nach fremdem Mitwerfen scheitert")


func _check_wrong_throw() -> void:
	var r = _game()
	_seven_on_top(r)
	var res := _act(r, "discard_extra", 3, 0)
	t.expect(not bool(res.ok) and "Passt nicht" in str(res.reason), "falsches Mitwerfen nicht abgelehnt: %s" % str(res.get("reason", "")))
	t.expect(r.state.players[3].penalty_cards.size() == 1, "falsches Mitwerfen ohne genau eine Strafkarte")
	t.expect(r.state.players[3].hand.size() == 4, "falsch mitgeworfene Karte hat die Hand verlassen")
	t.expect(str(r.top_discard().rank) == "7", "falsche Karte liegt auf der Ablage")
	# Ungueltiger Index ist kein Regelverstoss.
	var bad := _act(r, "discard_extra", 3, 9)
	t.expect(not bool(bad.ok) and r.state.players[3].penalty_cards.size() == 1, "ungueltiger Index kostet eine Strafkarte")
	# Ohne Ablage gibt es nichts mitzuwerfen, keine Strafe.
	var fresh = _game()
	var none := _act(fresh, "discard_extra", 1, 0)
	t.expect(not bool(none.ok) and fresh.state.players[1].penalty_cards.is_empty(), "Mitwerfen ohne Ablage bestraft")


func _check_late_throw() -> void:
	# Die 7 liegt nicht mehr oben, sobald der naechste Spieler eine andere Karte ablegt.
	var r = _game()
	_seven_on_top(r)
	_act(r, "end_turn", 0)
	_act(r, "draw_deck", 1)
	_act(r, "discard_drawn", 1)
	t.expect(str(r.top_discard().rank) == "A", "Testaufbau: A liegt nicht oben")
	var late := _act(r, "discard_extra", 2, 0)
	t.expect(not bool(late.ok), "zu spaetes Mitwerfen erlaubt")
	t.expect(r.state.players[2].penalty_cards.size() == 1, "zu spaetes Mitwerfen ohne Strafkarte")
	t.expect(r.state.players[2].hand.size() == 4, "zu spaet mitgeworfene Karte hat die Hand verlassen")


func _check_chain() -> void:
	# Liegt weiterhin ein Rang 7 oben, duerfen mehrere nacheinander mitwerfen.
	var r = _game()
	_seven_on_top(r)
	t.expect(bool(_act(r, "discard_extra", 1, 0).ok), "Kette: erster Wurf abgelehnt")
	t.expect(bool(_act(r, "discard_extra", 2, 0).ok), "Kette: zweiter Wurf abgelehnt")
	t.expect(str(r.top_discard().suit) == "spades", "Kette: oberste Karte falsch")
	t.expect(r.state.players[1].hand.size() == 3 and r.state.players[2].hand.size() == 3, "Kette: Haende nicht kleiner")


func _check_locked_and_eliminated_and_peek() -> void:
	var r = _game()
	_seven_on_top(r)
	r.state.players[1].locked = true
	var locked := _act(r, "discard_extra", 1, 0)
	t.expect(not bool(locked.ok) and "gelockt" in str(locked.reason), "gesperrter Ansager darf mitwerfen")
	t.expect(r.state.players[1].penalty_cards.is_empty() and r.state.players[1].hand.size() == 4, "gesperrter Ansager wurde bestraft")
	var e = _game()
	_seven_on_top(e)
	e.state.players[2].eliminated = true
	t.expect(not bool(_act(e, "discard_extra", 2, 0).ok), "Ausgeschiedener darf mitwerfen")
	# In der Merkphase gibt es kein Mitwerfen.
	var p = _game({"peek_phase": true, "ai_seats": [1, 2, 3]})
	t.expect(not bool(_act(p, "discard_extra", 0, 0).ok), "Mitwerfen in der Merkphase")
	# Nach der Runde auch nicht.
	var o = _game()
	_seven_on_top(o)
	o.state.phase = "round_end"
	t.expect(not bool(_act(o, "discard_extra", 1, 0).ok), "Mitwerfen nach dem Rundenende")


func _check_no_power_and_queen() -> void:
	# Eine mitgeworfene Dame kostet den Werfer wie immer eine Strafkarte, stoert aber den Zug nicht.
	var q = _game({"draw_first": [{"suit": "diamonds", "rank": "Q"}, {"suit": "clubs", "rank": "A"}, {"suit": "diamonds", "rank": "5"}, {"suit": "hearts", "rank": "3"}], "preset_hands": [
		[{"suit": "hearts", "rank": "9"}, {"suit": "spades", "rank": "8"}, {"suit": "hearts", "rank": "6"}, {"suit": "diamonds", "rank": "4"}],
		[{"suit": "hearts", "rank": "Q"}, {"suit": "clubs", "rank": "2"}, {"suit": "clubs", "rank": "3"}, {"suit": "clubs", "rank": "4"}],
		[{"suit": "spades", "rank": "7"}, {"suit": "clubs", "rank": "5"}, {"suit": "clubs", "rank": "6"}, {"suit": "spades", "rank": "2"}],
		[{"suit": "clubs", "rank": "8"}, {"suit": "clubs", "rank": "9"}, {"suit": "clubs", "rank": "10"}, {"suit": "spades", "rank": "3"}],
	]})
	_seven_on_top(q)
	var given: int = int(q.state.queen_penalties_given)
	t.expect(bool(_act(q, "discard_extra", 1, 0).ok), "Dame mitwerfen abgelehnt")
	t.expect(int(q.state.queen_penalties_given) == given + 1, "mitgeworfene Dame ohne Strafkarte")
	t.expect(q.state.players[1].penalty_cards.size() == 1, "Strafkarte der Dame nicht beim Werfer")
	t.expect(int(q.state.current_index) == 0, "Dame mitwerfen aendert den Zug")
	# Ein mitgeworfener Bube loest ausserhalb des eigenen Zugs keine Sonderwirkung aus.
	var j = _game({"draw_first": [{"suit": "diamonds", "rank": "J"}, {"suit": "clubs", "rank": "A"}, {"suit": "diamonds", "rank": "5"}, {"suit": "hearts", "rank": "3"}], "preset_hands": [
		[{"suit": "hearts", "rank": "9"}, {"suit": "spades", "rank": "8"}, {"suit": "hearts", "rank": "6"}, {"suit": "diamonds", "rank": "4"}],
		[{"suit": "hearts", "rank": "J"}, {"suit": "clubs", "rank": "2"}, {"suit": "clubs", "rank": "3"}, {"suit": "clubs", "rank": "4"}],
		[{"suit": "spades", "rank": "7"}, {"suit": "clubs", "rank": "5"}, {"suit": "clubs", "rank": "6"}, {"suit": "spades", "rank": "2"}],
		[{"suit": "clubs", "rank": "8"}, {"suit": "clubs", "rank": "9"}, {"suit": "clubs", "rank": "10"}, {"suit": "spades", "rank": "3"}],
	]})
	_seven_on_top(j)
	t.expect(str(j.state.turn_step) == "jack", "Testaufbau: Bube-Schritt fehlt")
	t.expect(bool(_act(j, "discard_extra", 1, 0).ok), "Bube mitwerfen abgelehnt")
	t.expect(str(j.state.turn_step) == "jack" and int(j.state.current_index) == 0, "Bube mitwerfen aendert den laufenden Zug")
	t.expect(j.state.last_look == null, "Bube mitwerfen hat eine Karte angesehen")


func _check_last_card_calls_dame() -> void:
	var r = _game()
	_seven_on_top(r)
	# Platz 1 hat nur noch seine 7.
	r.state.players[1].hand = [r.state.players[1].hand[0]]
	r.state.players[1].known = []
	var res := _act(r, "discard_extra", 1, 0)
	t.expect(bool(res.ok), "letzte Karte mitwerfen abgelehnt")
	t.expect(str(r.state.phase) == "dame_called" and int(r.state.dame_caller_index) == 1, "leere Hand ruft nicht Dame")
	t.expect(bool(r.state.players[1].locked), "Ansager nicht gesperrt")
	t.expect(int(r.state.dame_turns_left) == 3, "falsche Zahl Restzuege: %d" % int(r.state.dame_turns_left))
	t.expect(int(r.state.current_index) == 0 and str(r.state.turn_step) == "extra", "Dame durch Mitwerfen stoert den laufenden Zug")
	# Der laufende Zug zaehlt als erster der Restzuege; danach folgen zwei weitere.
	var turns := 0
	var guard := 0
	while str(r.state.phase) == "dame_called" and guard < 12:
		guard += 1
		var seat := int(r.state.current_index)
		if str(r.state.turn_step) == "draw":
			_act(r, "draw_deck", seat)
			_act(r, "discard_drawn", seat)
		if str(r.state.turn_step) == "jack" or str(r.state.turn_step) == "king":
			# Bube/Koenig aufloesen: Zug einfach ueber die sichere KI-Ersatzaktion beenden.
			var ai = DameAIScript.new()
			var fb: Dictionary = ai.fallback_action(r, seat)
			r.apply_action(fb)
		_act(r, "end_turn", seat)
		turns += 1
	t.expect(str(r.state.phase) == "round_end" and turns == 3, "Runde endet nicht nach genau 3 Zuegen (%d, Phase %s)" % [turns, str(r.state.phase)])


func _check_own_turn_throw_shrinks_hand() -> void:
	# Eigener Zug, Extra-Schritt: gleiche Regel (Hand wird kleiner), Platz 0 hat eine zweite 7.
	var r = _game({"preset_hands": [
		[{"suit": "hearts", "rank": "7"}, {"suit": "spades", "rank": "8"}, {"suit": "hearts", "rank": "6"}, {"suit": "diamonds", "rank": "4"}],
		[{"suit": "clubs", "rank": "2"}, {"suit": "clubs", "rank": "3"}, {"suit": "clubs", "rank": "4"}, {"suit": "clubs", "rank": "A"}],
		[{"suit": "spades", "rank": "5"}, {"suit": "clubs", "rank": "5"}, {"suit": "clubs", "rank": "6"}, {"suit": "spades", "rank": "2"}],
		[{"suit": "clubs", "rank": "8"}, {"suit": "clubs", "rank": "9"}, {"suit": "clubs", "rank": "10"}, {"suit": "spades", "rank": "3"}],
	]})
	_seven_on_top(r)
	var deck_before: int = r.state.deck.size()
	t.expect(bool(_act(r, "discard_extra", 0, 0).ok), "eigenes Mitwerfen abgelehnt")
	t.expect(r.state.players[0].hand.size() == 3 and r.state.deck.size() == deck_before, "eigenes Mitwerfen: Hand nicht kleiner oder Ersatzkarte gezogen")
	t.expect(str(r.state.turn_step) == "extra", "eigenes Mitwerfen verlaesst den Extra-Schritt")


func _ai_game(difficulty: String):
	return _game({"ai_seats": [1, 2, 3], "difficulties": {1: difficulty, 2: difficulty, 3: difficulty}, "preset_hands": [
		[{"suit": "hearts", "rank": "9"}, {"suit": "spades", "rank": "8"}, {"suit": "hearts", "rank": "6"}, {"suit": "diamonds", "rank": "4"}],
		[{"suit": "hearts", "rank": "7"}, {"suit": "clubs", "rank": "2"}, {"suit": "clubs", "rank": "3"}, {"suit": "clubs", "rank": "4"}],
		[{"suit": "clubs", "rank": "5"}, {"suit": "clubs", "rank": "6"}, {"suit": "spades", "rank": "7"}, {"suit": "spades", "rank": "2"}],
		[{"suit": "clubs", "rank": "8"}, {"suit": "clubs", "rank": "9"}, {"suit": "clubs", "rank": "10"}, {"suit": "spades", "rank": "3"}],
	]})


func _check_ai_reaction() -> void:
	var ai = DameAIScript.new(3)
	var r = _ai_game("medium")
	t.expect(not ai.reaction_due(r), "KI will ohne Ablage mitwerfen")
	_seven_on_top(r)
	t.expect(not ai.reaction_for(r, 1).is_empty(), "KI wirft eine sicher bekannte 7 nicht mit")
	# Platz 2 hat seine 7 auf Index 2, die ist ihm unbekannt: kein Mitwerfen aus Verdacht.
	t.expect(ai.reaction_for(r, 2).is_empty(), "KI wirft eine unbekannte Karte mit")
	t.expect(ai.reaction_for(r, 3).is_empty(), "KI wirft ohne passende Karte mit")
	t.expect(ai.reaction_for(r, 0).is_empty(), "Reaktion fuer einen Menschen")
	var res: Dictionary = ai.react(r)
	t.expect(bool(res.get("ok", false)) and int(res.seat) == 1, "KI-Reaktion nicht angewendet")
	t.expect(r.state.players[1].hand.size() == 3 and r.state.players[1].penalty_cards.is_empty(), "KI-Reaktion: Hand nicht kleiner oder Strafkarte")
	t.expect(not ai.reaction_due(r), "KI hat nach dem Mitwerfen noch etwas")
	var easy = _ai_game("easy")
	_seven_on_top(easy)
	t.expect(not DameAIScript.new(3).reaction_due(easy), "Einfach-KI wirft mit")
	# Dame wirft die KI nie mit, auch wenn sie sie kennt.
	var q = _ai_game("hard")
	q.state.players[1].hand[0] = {"id": "x", "suit": "hearts", "rank": "Q", "value": 0, "face_up": false}
	q.state.discard.append({"id": "y", "suit": "spades", "rank": "Q", "value": 0, "face_up": true})
	t.expect(DameAIScript.new(3).reaction_for(q, 1).is_empty(), "KI wirft eine Dame mit")
	# Gesperrt (nach Dame) oder in der Merkphase: nichts.
	var l = _ai_game("medium")
	_seven_on_top(l)
	l.state.players[1].locked = true
	t.expect(DameAIScript.new(3).reaction_for(l, 1).is_empty(), "gesperrte KI wirft mit")


func _check_host_ai_react() -> void:
	var r = _ai_game("medium")
	_seven_on_top(r)
	var host = DameHostScript.new(r, null)
	host.assign_seat(DameProtocol.HOST_PEER, 0)
	var ai = DameAIScript.new(3)
	t.expect(host.ai_reaction_due(ai), "Host meldet keine Reaktion")
	t.expect(host.ai_react(ai), "Host-Reaktion der KI gescheitert")
	t.expect(r.state.players[1].hand.size() == 3, "Host-Reaktion hat die Hand nicht veraendert")
	t.expect(not host.ai_react(ai), "Host-Reaktion ohne Anlass")
	# Menschliches Mitwerfen ueber den Host-Eingang, auch ausserhalb des eigenen Zugs.
	var h = _game({"ai_seats": [3]})
	_seven_on_top(h)
	var host2 = DameHostScript.new(h, null)
	host2.assign_seat(DameProtocol.HOST_PEER, 1)
	var out: Array = host2.submit(DameProtocol.HOST_PEER, {"type": "discard_extra", "hand_index": 0})
	t.expect(bool(out[0].msg.ok), "Host nimmt Mitwerfen ausserhalb des Zugs nicht an")
	var wrong: Array = host2.submit(DameProtocol.HOST_PEER, {"type": "discard_extra", "hand_index": 1})
	t.expect(not bool(wrong[0].msg.ok) and bool(wrong[0].msg.changed), "falsches Mitwerfen meldet keine Zustandsaenderung")


# ---- Tisch

func _table(cfg: Dictionary, settings: Dictionary = {}):
	var table = TableScene.instantiate()
	table.instant_ai = true
	var s := {"memory_aid": false, "turn_timer": false, "animations": false}
	s.merge(settings, true)
	table.settings_override = s
	var c := {"peek_phase": false, "seed": 101, "seat_count": 4, "ai_seats": [1, 2, 3], "names": ["Spieler", "A", "B", "C"]}
	c.merge(cfg, true)
	table.pending_config = c
	t.root.add_child(table)
	return table


func _free(table) -> void:
	t.root.remove_child(table)
	table.free()


func _check_table_throw_in() -> void:
	var table = _table({})
	var st: Dictionary = table.rules.state
	# Platz 2 (KI) ist am Zug, oben liegt eine 7, Karte 1 des Menschen ist eine 7.
	st.current_index = 2
	st.turn_step = "draw"
	st.discard = [{"id": "d7", "suit": "diamonds", "rank": "7", "value": 7, "face_up": true}]
	st.players[0].hand[0] = {"id": "c3", "suit": "clubs", "rank": "3", "value": 3, "face_up": false}
	st.players[0].hand[1] = {"id": "h7", "suit": "hearts", "rank": "7", "value": 7, "face_up": false}
	table.session.broadcast()
	t.expect(not table._human_turn(), "Testaufbau: Mensch ist am Zug")
	t.expect(table._can_throw_in(), "Mitwerfen laut Tisch nicht moeglich")
	t.expect("mitwerfen" in table._prompt.text, "Hinweis zum Mitwerfen fehlt: " + table._prompt.text)
	# Falsche Karte: Strafkarte.
	table._on_card(0, 0)
	t.expect(int(table._view.players[0].penalty_count) == 1 and int(table._view.players[0].card_count) == 4, "falscher Klick ohne Strafkarte")
	# Richtige Karte: Hand wird kleiner, die 7 liegt oben.
	table._on_card(0, 1)
	t.expect(int(table._view.players[0].card_count) == 3, "richtiger Klick verkleinert die Hand nicht")
	t.expect(str(table._view.discard_top.suit) == "hearts" and str(table._view.discard_top.rank) == "7", "mitgeworfene Karte liegt nicht oben")
	t.expect(int(table._view.current_index) == 2, "Mitwerfen aendert den Zug")
	_free(table)

	# Die Zeit-Planung der KI-Reaktion laeuft nur im echten Spiel, nicht in Tests mit instant_ai.
	var live = _table({})
	live.instant_ai = false
	var ls: Dictionary = live.rules.state
	ls.current_index = 0
	ls.turn_step = "draw"
	ls.discard = [{"id": "d7", "suit": "diamonds", "rank": "7", "value": 7, "face_up": true}]
	ls.players[1].hand[0] = {"id": "h7", "suit": "hearts", "rank": "7", "value": 7, "face_up": false}
	ls.players[1].known = [0]
	live._plan_reaction("play")
	t.expect(not live._react_timer.is_stopped(), "KI-Reaktion wird im echten Spiel nicht eingeplant")
	live.instant_ai = true
	live._react_timer.stop()
	live._plan_reaction("play")
	t.expect(live._react_timer.is_stopped(), "KI-Reaktion wird trotz instant_ai eingeplant")
	_free(live)


func _check_table_not_in_hotseat_or_peek() -> void:
	var hot = _table({"seat_count": 3, "ai_seats": [2], "names": ["Anna", "Ben", "KI"]})
	hot.confirm_handoff()
	hot.rules.state.discard = [{"id": "d7", "suit": "diamonds", "rank": "7", "value": 7, "face_up": true}]
	hot.session.broadcast()
	t.expect(not hot._can_throw_in(), "Mitwerfen im Hot-Seat moeglich")
	_free(hot)
	var peek = _table({"peek_phase": true})
	t.expect(not peek._can_throw_in(), "Mitwerfen in der Merkphase moeglich")
	_free(peek)
