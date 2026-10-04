extends Node

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")

var failures: Array = []

func _ready() -> void:
	_run()
	if failures.is_empty():
		print("STUFE1_OK")
		call_deferred("_quit", 0)
	else:
		for line in failures:
			print("STUFE1_FAIL ", line)
		call_deferred("_quit", 1)

func _quit(code: int) -> void:
	get_tree().quit(code)

func _run() -> void:
	_check_view_nodes()
	_check_extra_and_single_penalty()
	_check_rank_effects()
	_check_full_round()

func _expect(cond: bool, message: String) -> void:
	if not cond:
		failures.append(message)

func _check_view_nodes() -> void:
	var packed: PackedScene = load("res://scenes/table.tscn")
	var table = packed.instantiate()
	add_child(table)
	_expect(table.get_view_mode() == "first_person", "Sicht ist nicht first person")
	_expect(table.get_node_or_null("OwnHand") != null, "OwnHand fehlt")
	_expect(table.get_node_or_null("DiscardPile") != null, "DiscardPile fehlt")
	_expect(table.get_node_or_null("OppositeSeat") != null, "OppositeSeat fehlt")
	_expect(table.get_node("HUD/SideSeatLeft") is Label, "linker Platz ist kein Namens-/Zaehler-Label")
	_expect(table.get_node("HUD/SideSeatRight") is Label, "rechter Platz ist kein Namens-/Zaehler-Label")
	var view: Dictionary = table.rules.display_state(0)
	_expect(str(view.view) == "first_person", "display_state nicht first person")
	var ai_count := 0
	var seats := 0
	for entry in view.players:
		seats += 1
		if bool(entry.is_ai):
			ai_count += 1
		if str(entry.role) == "left" or str(entry.role) == "right":
			_expect(entry.cards.is_empty(), "Seitensitz zeigt Karten statt nur Zaehler")
	_expect(seats == 4, "nicht vier Plaetze in der Sicht")
	_expect(ai_count == 1, "nicht genau eine KI in der Sicht")
	table.queue_free()

func _check_extra_and_single_penalty() -> void:
	var rules = DameRulesScript.new()
	rules.start_match({
		"ai_seat": 2,
		"preset_hands": [
			[{"suit": "hearts", "rank": "7"}, {"suit": "spades", "rank": "K"}, {"suit": "hearts", "rank": "K"}, {"suit": "diamonds", "rank": "K"}],
			[{"suit": "clubs", "rank": "A"}, {"suit": "diamonds", "rank": "A"}, {"suit": "hearts", "rank": "A"}, {"suit": "spades", "rank": "2"}],
			[{"suit": "clubs", "rank": "2"}, {"suit": "diamonds", "rank": "2"}, {"suit": "hearts", "rank": "2"}, {"suit": "spades", "rank": "3"}],
			[{"suit": "clubs", "rank": "3"}, {"suit": "diamonds", "rank": "3"}, {"suit": "hearts", "rank": "3"}, {"suit": "spades", "rank": "4"}],
		],
		"draw_first": [
			{"suit": "diamonds", "rank": "7"},
			{"suit": "clubs", "rank": "5"},
		],
	})
	var draw_r: Dictionary = rules.apply_action({"type": "draw_deck", "seat": 0})
	_expect(bool(draw_r.ok), "Mini: Ziehen fehlgeschlagen " + str(draw_r.reason))
	var disc_r: Dictionary = rules.apply_action({"type": "discard_drawn", "seat": 0})
	_expect(bool(disc_r.ok), "Mini: Ablegen fehlgeschlagen")
	var wrong: Dictionary = rules.apply_action({"type": "discard_extra", "seat": 1, "hand_index": 0})
	_expect(not bool(wrong.ok), "Mini: fremdes Extra-Ablegen war erlaubt")
	_expect("eigenen Zug" in str(wrong.reason), "Mini: Grund ohne eigenen Zug: " + str(wrong.reason))
	var mismatch: Dictionary = rules.apply_action({"type": "discard_extra", "seat": 0, "hand_index": 1})
	_expect(not bool(mismatch.ok), "Mini: falsches Extra war erlaubt")
	_expect(rules.state.players[0].penalty_cards.size() == 1, "Mini: nicht genau eine Strafkarte bei falschem Extra")
	var extra: Dictionary = rules.apply_action({"type": "discard_extra", "seat": 0, "hand_index": 0})
	_expect(bool(extra.ok), "Mini: passendes Extra abgelehnt " + str(extra.reason))
	_expect(rules.state.players[0].penalty_cards.size() == 1, "Mini: Extra hat eine zweite Strafkarte erzeugt")
	_expect(str(rules.top_discard().rank) == "7", "Mini: Extra liegt nicht offen oben")
	_expect(bool(rules.top_discard().face_up), "Mini: Extra-Karte nicht face up")


func _check_rank_effects() -> void:
	var rules = DameRulesScript.new()
	var pool: Array = rules._fresh_pool()
	_expect(pool.size() == 52, "Blatt hat nicht 52 Karten, ist %d" % pool.size())
	var counts := {}
	for card in pool:
		var rank := str(card.rank)
		counts[rank] = int(counts.get(rank, 0)) + 1
	for code in ["J", "K", "A", "10", "Q"]:
		_expect(rules.RANKS.has(code), code + " fehlt in RANKS")
		_expect(int(counts.get(code, 0)) == 4, "%s nicht viermal im Blatt, ist %d" % [code, int(counts.get(code, 0))])
	_expect(rules.STAGE1_PLAIN_RANKS.has("A") and rules.STAGE1_PLAIN_RANKS.has("10"), "Ass oder Zehn fehlt als normaler Rang")
	_expect(not rules.STAGE1_PLAIN_RANKS.has("J") and not rules.STAGE1_PLAIN_RANKS.has("K"), "Bube oder König steht noch als wirkungslos")
	print("FACT deck=52 bube=4 koenig=4 ass=4 zehn=4 dame=4 seats=%d" % rules.SEAT_COUNT)
	_check_bube_look(false)
	_check_bube_look(true)
	_check_king_swap()
	_check_plain_ace_ten()


func _check_bube_look(own: bool) -> void:
	var rules = DameRulesScript.new()
	rules.start_match({
		"ai_seat": 2,
		"preset_hands": [
			[{"suit": "hearts", "rank": "4"}, {"suit": "clubs", "rank": "6"}, {"suit": "diamonds", "rank": "5"}, {"suit": "spades", "rank": "8"}],
			[{"suit": "hearts", "rank": "9"}, {"suit": "clubs", "rank": "5"}, {"suit": "diamonds", "rank": "6"}, {"suit": "spades", "rank": "7"}],
			[{"suit": "hearts", "rank": "8"}, {"suit": "clubs", "rank": "9"}, {"suit": "diamonds", "rank": "4"}, {"suit": "spades", "rank": "5"}],
			[{"suit": "hearts", "rank": "7"}, {"suit": "clubs", "rank": "8"}, {"suit": "diamonds", "rank": "2"}, {"suit": "spades", "rank": "6"}],
		],
		"draw_first": [
			{"suit": "diamonds", "rank": "J"},
			{"suit": "hearts", "rank": "3"},
		],
	})
	_expect(rules.state.players.size() == 4, "Bube: nicht vier Plaetze")
	var ai_seats := 0
	for p in rules.state.players:
		if bool(p.is_ai):
			ai_seats += 1
	_expect(ai_seats == 1, "Bube: nicht genau eine KI")
	var target_seat := 0 if own else 1
	var target_index := 3 if own else 0
	var draw_r: Dictionary = rules.apply_action({"type": "draw_deck", "seat": 0})
	_expect(bool(draw_r.ok), "Bube ziehen fehlgeschlagen: " + str(draw_r.reason))
	var disc_r: Dictionary = rules.apply_action({"type": "discard_drawn", "seat": 0})
	_expect(bool(disc_r.ok), "Bube ablegen fehlgeschlagen: " + str(disc_r.reason))
	_expect(str(rules.state.turn_step) == "jack", "Bube oeffnet nicht den Ansehen-Schritt")
	_expect(str(rules.top_discard().rank) == "J" and bool(rules.top_discard().face_up), "Bube liegt nicht offen auf der Ablage")
	_expect(int(rules.state.queen_penalties_given) == 0, "Bube hat eine Damenstrafe erzeugt")
	var early: Dictionary = rules.apply_action({"type": "end_turn", "seat": 0})
	_expect(not bool(early.ok), "Bube-Zug ohne Ansehen war beendet")
	var looked: Dictionary = rules.state.players[target_seat].hand[target_index]
	var look_id := str(looked.id)
	var look_rank := str(looked.rank)
	var look_suit := str(looked.suit)
	_expect(bool(looked.face_up) == false, "Zielkarte war schon offen")
	var before := _layout(rules)
	var seen: Dictionary = rules.apply_action({
		"type": "look_card",
		"seat": 0,
		"target_seat": target_seat,
		"hand_index": target_index,
	})
	_expect(bool(seen.ok), "Bube-Ansehen fehlgeschlagen: " + str(seen.reason))
	var after := _layout(rules)
	var unchanged := before == after
	var still: Dictionary = rules.state.players[target_seat].hand[target_index]
	var stayed_down := bool(still.face_up) == false and str(still.id) == look_id
	_expect(unchanged, "Bube hat Positionen veraendert")
	_expect(stayed_down, "Angesehene Karte hat sich bewegt oder ist offen")
	_expect(rules.state.last_king_swap == null, "Bube hat einen Tausch gespeichert")
	_expect(rules.state.last_look != null, "Bube hat die angesehene Karte nicht gemerkt")
	_expect(str(rules.state.last_look.id) == look_id, "Bube merkt die falsche Karte")
	_expect(str(rules.state.last_look.rank) == look_rank and str(rules.state.last_look.suit) == look_suit, "Bube-Identitaet falsch")
	_expect(bool(rules.state.last_look.face_up) == false, "Bube-Blick ist nicht verdeckt gemerkt")
	var target_word := "own" if own else "opponent"
	print("FACT bube target=%s look_id=%s look_rank=%s look_suit=%s seat=%d index=%d face_up=false swapped=false positions_unchanged=%s seats=%d" % [target_word, look_id, look_rank, look_suit, target_seat, target_index, str(unchanged and stayed_down).to_lower(), rules.state.players.size()])


func _check_king_swap() -> void:
	var rules = DameRulesScript.new()
	rules.start_match({
		"ai_seat": 2,
		"preset_hands": [
			[{"suit": "hearts", "rank": "4"}, {"suit": "spades", "rank": "3"}, {"suit": "diamonds", "rank": "5"}, {"suit": "clubs", "rank": "6"}],
			[{"suit": "hearts", "rank": "9"}, {"suit": "clubs", "rank": "5"}, {"suit": "diamonds", "rank": "6"}, {"suit": "spades", "rank": "7"}],
			[{"suit": "clubs", "rank": "8"}, {"suit": "hearts", "rank": "2"}, {"suit": "diamonds", "rank": "9"}, {"suit": "spades", "rank": "4"}],
			[{"suit": "hearts", "rank": "7"}, {"suit": "clubs", "rank": "9"}, {"suit": "diamonds", "rank": "2"}, {"suit": "spades", "rank": "6"}],
		],
		"draw_first": [
			{"suit": "diamonds", "rank": "K"},
			{"suit": "hearts", "rank": "3"},
		],
	})
	_expect(rules.state.players.size() == 4, "König: nicht vier Plaetze")
	var draw_r: Dictionary = rules.apply_action({"type": "draw_deck", "seat": 0})
	_expect(bool(draw_r.ok) and str(rules.state.drawn_card.rank) == "K", "König wurde nicht gezogen")
	var disc_r: Dictionary = rules.apply_action({"type": "discard_drawn", "seat": 0})
	_expect(bool(disc_r.ok), "König ablegen fehlgeschlagen: " + str(disc_r.reason))
	_expect(str(rules.state.turn_step) == "king", "König oeffnet nicht den Tauschschritt")
	_expect(str(rules.top_discard().rank) == "K" and bool(rules.top_discard().face_up), "König liegt nicht offen auf der Ablage")
	var early: Dictionary = rules.apply_action({"type": "end_turn", "seat": 0})
	_expect(not bool(early.ok), "König-Zug ohne Tausch war beendet")
	var own_before: Dictionary = rules.state.players[0].hand[1]
	var opp_before: Dictionary = rules.state.players[2].hand[0]
	var own_id := str(own_before.id)
	var opp_id := str(opp_before.id)
	var opp_rank := str(opp_before.rank)
	var opp_suit := str(opp_before.suit)
	_expect(bool(own_before.face_up) == false and bool(opp_before.face_up) == false, "König-Karten waren schon offen")
	var others_before := _layout_except(rules, [0, 2])
	var swapped: Dictionary = rules.apply_action({
		"type": "king_swap",
		"seat": 0,
		"opponent_seat": 2,
		"opponent_index": 0,
		"chosen_index": 1,
	})
	_expect(bool(swapped.ok), "Königstausch fehlgeschlagen: " + str(swapped.reason))
	var now_own: Dictionary = rules.state.players[0].hand[1]
	var now_opp: Dictionary = rules.state.players[2].hand[0]
	var own_moved := str(now_opp.id) == own_id and str(now_own.id) == opp_id
	var both_down := bool(now_own.face_up) == false and bool(now_opp.face_up) == false
	_expect(own_moved, "König hat die beiden Karten nicht getauscht")
	_expect(both_down, "König hat eine Karte offen gelassen")
	_expect(_layout_except(rules, [0, 2]) == others_before, "König hat unbeteiligte Haende veraendert")
	_expect(str(rules.state.players[0].hand[0].id) != own_id and str(rules.state.players[0].hand[0].rank) == "4", "eigene Nebenkarte verschoben")
	var own_rank := str(own_before.rank)
	var own_suit := str(own_before.suit)
	_expect(rules.state.last_look != null and str(rules.state.last_look.id) == own_id, "König hat die eigene Karte nicht gemerkt")
	_expect(str(rules.state.last_look.rank) == own_rank and str(rules.state.last_look.suit) == own_suit, "König-Blick zeigt nicht die eigene Karte")
	_expect(int(rules.state.last_look.seat) == 0 and int(rules.state.last_look.index) == 1, "König hat nicht die eigene Position angesehen")
	_expect(bool(rules.state.last_look.face_up) == false, "König-Blick ist nicht verdeckt gemerkt")
	_expect(str(rules.state.last_look.id) != opp_id, "König hat die Gegnerkarte offengelegt")
	_expect(not rules.state.players[0].known.has(1), "König zeigt die getauschte Gegnerkarte als bekannt")
	var view: Dictionary = rules.display_state(0)
	var self_cards: Array = []
	for entry in view.players:
		if str(entry.role) == "self":
			self_cards = entry.cards
	_expect(self_cards.size() > 1 and str(self_cards[1].rank) == "", "Sicht zeigt die ungesehene Karte")
	_expect(view.private_look != null and str(view.private_look.id) == own_id, "private Sicht zeigt nicht die eigene Karte")
	_expect(str(view.private_look.id) != opp_id, "private Sicht nennt die Gegnerkarte")
	var public_blob := str(rules.state.last_look) + "|" + str(rules.state.last_king_swap) + "|" + str(rules.state.last_action) + "|" + str(view.private_look)
	_expect(opp_id not in public_blob, "Gegneridentitaet wurde gespeichert oder gezeigt")
	_expect(opp_rank not in public_blob and opp_suit not in public_blob, "Gegnerrang oder -farbe wurde gezeigt")
	_expect(bool(rules.state.last_king_swap.blind_unseen), "blinder Tausch nicht markiert")
	_expect(int(rules.state.queen_penalties_given) == 0, "König hat eine Damenstrafe erzeugt")
	_expect(str(rules.top_discard().rank) == "K", "Königstausch hat die Ablage ersetzt")
	var fact := "FACT koenig look_own_id=%s look_rank=%s look_suit=%s seat=0 index=1 moved_to=2:0 face_up=false blind_from=2:0 blind_unseen=true blind_identity_printed=false both_face_down=%s swapped=%s seats=%d" % [own_id, own_rank, own_suit, str(both_down).to_lower(), str(own_moved).to_lower(), rules.state.players.size()]
	_expect(opp_id not in fact and opp_rank not in fact and opp_suit not in fact, "FACT nennt die Gegnerkarte")
	print(fact)


func _check_plain_ace_ten() -> void:
	var rules = DameRulesScript.new()
	rules.start_match({
		"ai_seat": 2,
		"preset_hands": [
			[{"suit": "hearts", "rank": "A"}, {"suit": "clubs", "rank": "2"}, {"suit": "diamonds", "rank": "3"}, {"suit": "spades", "rank": "4"}],
			[{"suit": "hearts", "rank": "10"}, {"suit": "clubs", "rank": "5"}, {"suit": "diamonds", "rank": "6"}, {"suit": "spades", "rank": "7"}],
			[{"suit": "hearts", "rank": "8"}, {"suit": "clubs", "rank": "8"}, {"suit": "diamonds", "rank": "9"}, {"suit": "spades", "rank": "9"}],
			[{"suit": "diamonds", "rank": "8"}, {"suit": "spades", "rank": "8"}, {"suit": "hearts", "rank": "9"}, {"suit": "clubs", "rank": "9"}],
		],
		"draw_first": [
			{"suit": "diamonds", "rank": "A"},
			{"suit": "hearts", "rank": "2"},
			{"suit": "diamonds", "rank": "10"},
			{"suit": "hearts", "rank": "3"},
		],
	})
	_expect(rules.state.players.size() == 4, "Ass/Zehn: nicht vier Plaetze")
	var sequence := [
		{"seat": 0, "code": "A", "label": "Ass"},
		{"seat": 1, "code": "10", "label": "Zehn"},
	]
	for step in sequence:
		var seat := int(step.seat)
		var code := str(step.code)
		var label := str(step.label)
		_expect(int(rules.state.current_index) == seat, label + " ist nicht am Zug")
		_expect(str(rules.state.turn_step) == "draw", label + " startet nicht im Ziehschritt")
		var others_before := _hand_ids_except(rules, seat)
		var deck_before: int = rules.state.deck.size()
		var penalties_before: int = rules.state.players[seat].penalty_cards.size()
		var draw_r: Dictionary = rules.apply_action({"type": "draw_deck", "seat": seat})
		_expect(bool(draw_r.ok), label + " ziehen fehlgeschlagen: " + str(draw_r.reason))
		_expect(rules.state.drawn_card != null and str(rules.state.drawn_card.rank) == code, label + " wurde nicht gezogen")
		var disc_r: Dictionary = rules.apply_action({"type": "discard_drawn", "seat": seat})
		_expect(bool(disc_r.ok), label + " ablegen fehlgeschlagen: " + str(disc_r.reason))
		_expect(str(rules.state.turn_step) == "extra", label + " hat einen Sonder-Schritt geoeffnet")
		_expect(rules.state.last_look == null, label + " hat eine Karte angesehen")
		_expect(rules.state.last_king_swap == null, label + " hat getauscht")
		var top = rules.top_discard()
		_expect(top != null and str(top.rank) == code and bool(top.face_up), label + " liegt nicht offen oben")
		_expect(str(top.rank) != "Q", label + " wurde wie eine Dame behandelt")
		_expect(rules.state.players[seat].penalty_cards.size() == penalties_before, label + " hat eine Strafkarte erzeugt")
		_expect(int(rules.state.queen_penalties_given) == 0, label + " hat die Damenstrafe ausgeloest")
		var extra: Dictionary = rules.apply_action({"type": "discard_extra", "seat": seat, "hand_index": 0})
		_expect(bool(extra.ok), label + " Extra-Ablegen abgelehnt: " + str(extra.reason))
		_expect(str(rules.state.turn_step) == "extra", label + " Extra hat einen Sonder-Schritt geoeffnet")
		_expect(rules.state.last_look == null and rules.state.last_king_swap == null, label + " Extra hat geschaut oder getauscht")
		_expect(str(rules.top_discard().rank) == code, label + " Extra liegt nicht oben")
		_expect(rules.state.players[seat].penalty_cards.size() == penalties_before, label + " Extra hat eine Strafkarte erzeugt")
		_expect(rules.state.deck.size() == deck_before - 2, label + " hat nicht genau eine Ersatzkarte gezogen")
		_expect(_hand_ids_except(rules, seat) == others_before, label + " hat fremde Haende veraendert")
		var end_r: Dictionary = rules.apply_action({"type": "end_turn", "seat": seat})
		_expect(bool(end_r.ok), label + " Zugende fehlgeschlagen: " + str(end_r.reason))
		var expected_next := (seat + 1) % 4
		_expect(int(rules.state.current_index) == expected_next, label + " hat den naechsten Sitz uebersprungen, ist %d" % int(rules.state.current_index))
		_expect(rules.state.drawn_card == null, label + " laesst eine gezogene Karte liegen")
	var denied_look: Dictionary = rules.apply_action({"type": "look_card", "seat": 2, "target_seat": 0, "hand_index": 0})
	_expect(not bool(denied_look.ok), "Ass/Zehn hat nachtraeglich einen Bube-Blick erlaubt")
	var denied_swap: Dictionary = rules.apply_action({"type": "king_swap", "seat": 2, "opponent_seat": 0, "opponent_index": 0, "chosen_index": 0})
	_expect(not bool(denied_swap.ok), "Ass/Zehn hat nachtraeglich einen Königstausch erlaubt")
	for forbidden in ["USE_JACK_EFFECT", "USE_KING_EFFECT", "USE_ACE_EFFECT", "USE_TEN_EFFECT"]:
		var denied: Dictionary = rules.apply_action({"type": forbidden, "seat": 2})
		_expect(not bool(denied.ok), "Sonderaktion war erlaubt: " + forbidden)
	print("FACT ass_zehn ranks=A,10 played=normal look=false swap=false skip=false seats=%d" % rules.state.players.size())


func _layout(rules) -> Array:
	var out: Array = []
	for p in rules.state.players:
		for i in range(p.hand.size()):
			var card: Dictionary = p.hand[i]
			out.append("%d:%d:%s:%s" % [int(p.seat), i, str(card.id), str(bool(card.face_up))])
	return out


func _layout_except(rules, seats: Array) -> Array:
	var out: Array = []
	for p in rules.state.players:
		if seats.has(int(p.seat)):
			continue
		for i in range(p.hand.size()):
			var card: Dictionary = p.hand[i]
			out.append("%d:%d:%s:%s" % [int(p.seat), i, str(card.id), str(bool(card.face_up))])
	return out


func _hand_ids_except(rules, seat: int) -> Array:
	var out: Array = []
	for p in rules.state.players:
		if int(p.seat) == seat:
			continue
		var ids: Array = []
		for card in p.hand:
			ids.append(str(card.id))
		out.append(ids)
	return out

func _check_full_round() -> void:
	var rules = DameRulesScript.new()
	var ai = DameAIScript.new()
	var draw_first: Array = [{"suit": "hearts", "rank": "Q"}]
	var fillers := [
		["spades", "4"], ["hearts", "4"], ["diamonds", "4"], ["clubs", "4"],
		["spades", "5"], ["hearts", "5"], ["diamonds", "5"], ["clubs", "5"],
		["spades", "6"], ["hearts", "6"], ["diamonds", "6"], ["clubs", "6"],
	]
	for pair in fillers:
		draw_first.append({"suit": pair[0], "rank": pair[1]})
	rules.start_match({
		"ai_seat": 2,
		"preset_hands": [
			[{"suit": "spades", "rank": "K"}, {"suit": "hearts", "rank": "K"}, {"suit": "diamonds", "rank": "K"}, {"suit": "clubs", "rank": "K"}],
			[{"suit": "spades", "rank": "A"}, {"suit": "hearts", "rank": "A"}, {"suit": "diamonds", "rank": "A"}, {"suit": "clubs", "rank": "2"}],
			[{"suit": "clubs", "rank": "A"}, {"suit": "spades", "rank": "2"}, {"suit": "hearts", "rank": "2"}, {"suit": "diamonds", "rank": "2"}],
			[{"suit": "spades", "rank": "3"}, {"suit": "hearts", "rank": "3"}, {"suit": "diamonds", "rank": "3"}, {"suit": "clubs", "rank": "3"}],
		],
		"draw_first": draw_first,
	})
	var ai_seats := 0
	for p in rules.state.players:
		if bool(p.is_ai):
			ai_seats += 1
	_expect(rules.state.players.size() == 4, "nicht vier Spieler")
	_expect(ai_seats == 1, "nicht genau eine KI")
	_expect(bool(rules.state.players[2].is_ai), "KI sitzt nicht gegenueber")
	var guard := 0
	while guard < 20:
		guard += 1
		if int(rules.state.round) >= 3 and not bool(rules.state.safe_phase) and int(rules.state.current_index) == 0 and str(rules.state.turn_step) == "draw" and str(rules.state.phase) == "play":
			break
		_play_one(rules, ai)
	_expect(int(rules.state.round) == 3, "Safe Phase nicht nach zwei Umlaeufen beendet, Runde=%d" % int(rules.state.round))
	_expect(not bool(rules.state.safe_phase), "safe_phase noch an")
	_expect(int(rules.state.queen_penalties_given) == 1, "Koeniginnen-Strafe nicht genau eine, ist %d" % int(rules.state.queen_penalties_given))
	var call: Dictionary = rules.apply_action({"type": "call_dame", "seat": 0})
	_expect(bool(call.ok), "Dame-Ansage fehlgeschlagen: " + str(call.reason))
	_expect(str(rules.state.phase) == "dame_called", "Phase nach Ansage falsch")
	_expect(int(rules.state.dame_turns_left) == 3, "nicht genau drei verbleibende Zuege, ist %d" % int(rules.state.dame_turns_left))
	_expect(bool(rules.state.players[0].locked), "Ansage lockt den Ansager nicht")
	var locked_try: Dictionary = rules.apply_action({"type": "draw_deck", "seat": 0})
	_expect(not bool(locked_try.ok), "gelockter Ansager durfte noch ziehen")
	var turns := 0
	while str(rules.state.phase) == "dame_called" and turns < 6:
		turns += 1
		_expect(int(rules.state.current_index) != 0, "Ansager ist nach der Ansage wieder am Zug")
		_play_one(rules, ai)
	_expect(turns == 3, "nach der Ansage nicht genau drei Zuege, ist %d" % turns)
	_expect(str(rules.state.phase) == "round_end", "Runde nicht aufgedeckt")
	_expect(bool(rules.state.last_round_false_call), "Ansage war nicht falsch")
	_expect(rules.state.players[0].penalty_cards.size() == 1, "Falsche Ansage hat nicht genau eine Strafkarte")
	_expect(int(rules.state.false_call_penalties_given) == 1, "false_call Zaehler nicht 1")
	_expect(int(rules.state.ai_turns_finished) >= 3, "KI hat nicht genug eigene Zuege beendet: %d" % int(rules.state.ai_turns_finished))
	_expect(rules.state.drawn_card == null, "gezogene Karte blieb nach der Runde liegen")
	var penalty_id := str(rules.state.players[0].penalty_cards[0].id)
	var next_r: Dictionary = rules.apply_action({"type": "start_next_round"})
	_expect(bool(next_r.ok), "Naechste Ausgabe fehlgeschlagen: " + str(next_r.reason))
	_expect(rules.state.players[0].hand.size() == 5, "Ansager hat nicht 5 Karten, ist %d" % rules.state.players[0].hand.size())
	_expect(str(rules.state.players[0].hand[4].id) == penalty_id, "die fuenfte Karte ist nicht die Strafkarte")
	for seat in [1, 2, 3]:
		_expect(rules.state.players[seat].hand.size() == 4, "Sitz %d hat nicht 4 Karten" % seat)
	_expect(rules.PENALTY_CARD_COUNT == 1, "PENALTY_CARD_COUNT ist nicht 1")
	print("FACT seats=%d ai_turns=%d queen_penalties=%d false_call=%s caller_cards=%d other_cards=%d" % [rules.state.players.size(), int(rules.state.ai_turns_finished), int(rules.state.queen_penalties_given), str(rules.state.last_round_false_call), rules.state.players[0].hand.size(), rules.state.players[1].hand.size()])

func _play_one(rules, ai) -> void:
	var seat := int(rules.state.current_index)
	var player: Dictionary = rules.state.players[seat]
	if bool(player.is_ai):
		var done: bool = ai.complete_turn(rules)
		_expect(done, "KI beendet den Zug nicht: " + str(ai.last_error))
		_expect(rules.state.drawn_card == null or int(rules.state.current_index) != seat, "KI laesst eine gezogene Karte liegen")
		return
	var draw_type := "draw_discard" if rules.must_take_queen() else "draw_deck"
	var draw_r: Dictionary = rules.apply_action({"type": draw_type, "seat": seat})
	_expect(bool(draw_r.ok), "Ziehen fehlgeschlagen Sitz %d: %s" % [seat, draw_r.reason])
	if rules.state.drawn_card != null and str(rules.state.drawn_card.rank) == "Q":
		var before: int = rules.state.players[seat].penalty_cards.size()
		var disc_r: Dictionary = rules.apply_action({"type": "discard_drawn", "seat": seat})
		_expect(bool(disc_r.ok), "Dame ablegen fehlgeschlagen")
		var top = rules.top_discard()
		_expect(top != null and str(top.rank) == "Q" and bool(top.face_up), "abgelegte Dame liegt nicht offen")
		_expect(rules.state.players[seat].penalty_cards.size() == before + 1, "Dame hat nicht genau eine Strafkarte erzeugt")
	else:
		var disc_r2: Dictionary = rules.apply_action({"type": "discard_drawn", "seat": seat})
		_expect(bool(disc_r2.ok), "Ablegen fehlgeschlagen Sitz %d: %s" % [seat, disc_r2.reason])
	_resolve_special(rules, seat)
	var other := (seat + 1) % 4
	var foreign: Dictionary = rules.apply_action({"type": "discard_extra", "seat": other, "hand_index": 0})
	_expect(not bool(foreign.ok), "Extra-Ablegen ausserhalb des eigenen Zuges war erlaubt")
	var end_r: Dictionary = rules.apply_action({"type": "end_turn", "seat": seat})
	_expect(bool(end_r.ok), "Zugende fehlgeschlagen Sitz %d: %s" % [seat, end_r.reason])

func _resolve_special(rules, seat: int) -> void:
	var step := str(rules.state.turn_step)
	if step == "jack":
		var seen: Dictionary = rules.apply_action({
			"type": "look_card",
			"seat": seat,
			"target_seat": (seat + 1) % 4,
			"hand_index": 0,
		})
		_expect(bool(seen.ok), "Bube-Ansehen im Rundentest fehlgeschlagen: " + str(seen.reason))
	elif step == "king":
		var swapped: Dictionary = rules.apply_action({
			"type": "king_swap",
			"seat": seat,
			"opponent_seat": (seat + 1) % 4,
			"opponent_index": 0,
			"chosen_index": 0,
		})
		_expect(bool(swapped.ok), "Koenigstausch im Rundentest fehlgeschlagen: " + str(swapped.reason))
