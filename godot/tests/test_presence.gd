extends RefCounted

# Abwesenheit (CONCEPT_DECISIONS §11): Stufen der Presence und die Host-Zuege
# fuer abwesende Plaetze. Zeit nur ueber tick(delta), kein echtes Warten.

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const DameHost = preload("res://scripts/net/dame_host.gd")
const Presence = preload("res://scripts/net/presence.gd")

var t


func run(ctx) -> void:
	t = ctx
	_check_stages()
	_check_rejoin_stage1()
	_check_rejoin_stage2_penalty()
	_check_total_reserve()
	_check_forfeit()
	_check_skip_turn()
	_check_queen_not_forced()
	_check_machine_turn()
	_check_absence_penalty()
	_check_absence_in_views()


func _host(seed: int = 3):
	var rules = DameRulesScript.new()
	rules.start_match({"seed": seed, "seat_count": 3, "ai_seats": [2]})
	return DameHost.new(rules, null)


func _check_stages() -> void:
	var p = Presence.new()
	p.track(1)
	t.expect(p.is_present(1) and p.stage_of(1) == 0, "Presence: Start anwesend")
	p.set_present(1, false)
	t.expect(p.stage_of(1) == 1, "Presence: getrennt = Stufe 1")
	p.tick(59.0)
	t.expect(p.stage_of(1) == 1 and not p.is_machine_controlled(1), "Presence: 59 s noch Stufe 1")
	p.tick(2.0)
	t.expect(p.stage_of(1) == 2 and p.is_machine_controlled(1), "Presence: ueber 60 s Stufe 2")
	p.tick(200.0)
	t.expect(p.stage_of(1) == 2, "Presence: 261 s noch Stufe 2")
	p.tick(50.0)
	t.expect(p.stage_of(1) == 3 and p.is_forfeited(1), "Presence: ueber 300 s Stufe 3, Platz verloren")
	p.set_present(1, true)
	t.expect(not p.is_present(1) and not p.rejoin_allowed(1), "Presence: nach Stufe 3 kein Wiedereinstieg")


func _check_rejoin_stage1() -> void:
	var p = Presence.new()
	p.track(1)
	p.set_present(1, false)
	p.tick(30.0)
	p.set_present(1, true)
	t.expect(p.stage_of(1) == 0 and p.take_pending_penalties().is_empty(), "Presence: Funkloch kostet keine Strafkarte")


func _check_rejoin_stage2_penalty() -> void:
	var p = Presence.new()
	p.track(1)
	p.set_present(1, false)
	p.tick(90.0)
	p.set_present(1, true)
	t.expect(p.stage_of(1) == 0 and p.is_present(1), "Presence: Wiedereinstieg in Stufe 2 klappt")
	var pen: Array = p.take_pending_penalties()
	t.expect(pen == [1], "Presence: Wiedereinstieg in Stufe 2 = genau eine Strafkarte")
	t.expect(p.take_pending_penalties().is_empty(), "Presence: Strafkarte nur einmal abholbar")


func _check_total_reserve() -> void:
	var p = Presence.new()
	p.track(1)
	# Zweimal 50 s, dann 30 s: die Reserve von 120 s je Partie ist aufgebraucht.
	for run_len in [50.0, 50.0]:
		p.set_present(1, false)
		p.tick(run_len)
		p.set_present(1, true)
	p.set_present(1, false)
	p.tick(15.0)
	t.expect(p.stage_of(1) == 1, "Presence: 115 s gesamt noch Stufe 1")
	p.tick(10.0)
	t.expect(p.stage_of(1) == 2, "Presence: ueber 120 s gesamt Stufe 2")


func _check_forfeit() -> void:
	var p = Presence.new()
	p.track(1)
	var seen: Array = []
	p.stage_changed.connect(func(seat, stage): seen.append([seat, stage]))
	p.set_present(1, false)
	p.tick(61.0)
	p.tick(250.0)
	t.expect(seen == [[1, 1], [1, 2], [1, 3]], "Presence: Stufen-Signale in Reihenfolge, war %s" % str(seen))


func _check_skip_turn() -> void:
	var h = _host()
	var ai = DameAIScript.new(5)
	var seat := int(h.rules.state.current_index)
	var hand_before := var_to_str(h.rules.state.players[seat].hand)
	var pen_before: int = h.rules.state.players[seat].penalty_cards.size()
	var res: Dictionary = h.absent_turn(ai, seat)
	t.expect(bool(res.ok), "Aussetzen: ok")
	t.expect(int(h.rules.state.current_index) != seat, "Aussetzen: Zug geht weiter")
	t.expect(var_to_str(h.rules.state.players[seat].hand) == hand_before, "Aussetzen: Hand unveraendert")
	t.expect(h.rules.state.players[seat].penalty_cards.size() == pen_before, "Aussetzen: keine Strafkarte")
	t.expect(h.rules.assert_zones(), "Aussetzen: Zonen heil: %s" % h.rules.zone_error)
	# Mitten im Zug darf Aussetzen nicht gehen.
	var h2 = _host(4)
	var s2 := int(h2.rules.state.current_index)
	h2.rules.apply_action({"type": "draw_deck", "seat": s2})
	t.expect(not bool(h2.rules.apply_action({"type": "skip_turn", "seat": s2}).ok), "Aussetzen: nach dem Ziehen abgelehnt")


func _check_queen_not_forced() -> void:
	# Eine offene Dame auf der Ablage zwingt niemanden: Ziehen vom Stapel ist erlaubt, Aussetzen auch.
	var h = _host(6)
	var seat := int(h.rules.state.current_index)
	var q = {"id": "test-queen", "rank": "Q", "suit": "hearts", "value": 0, "face_up": true}
	var cards: Array = h.rules.state.deck
	for i in range(cards.size()):
		if str(cards[i].rank) == "Q":
			q = cards[i]
			cards.remove_at(i)
			break
	q.face_up = true
	h.rules.state.discard.append(q)
	h.rules.state.safe_phase = false
	var ai = DameAIScript.new(5)
	var res: Dictionary = h.absent_turn(ai, seat)
	t.expect(bool(res.ok), "offene Dame: Abwesenheit ok")
	t.expect(h.rules.assert_zones(), "offene Dame: Zonen heil: %s" % h.rules.zone_error)
	t.expect(int(h.rules.state.current_index) != seat, "offene Dame: Zug beendet")
	t.expect(h.rules.state.players[seat].penalty_cards.is_empty(), "offene Dame: keine Strafkarte")
	var r = _host(4)
	var s2 := int(r.rules.state.current_index)
	r.rules.state.discard.append({"id": "q2", "rank": "Q", "suit": "spades", "value": 0, "face_up": true})
	r.rules.state.safe_phase = false
	t.expect(bool(r.rules.apply_action({"type": "draw_deck", "seat": s2}).ok), "offene Dame zwingt zum Nehmen von der Ablage")


func _check_machine_turn() -> void:
	# Vertretung spielt volle Zuege, ruft nie Dame, Zonen bleiben heil.
	var h = _host(8)
	var ai = DameAIScript.new(9)
	var guard := 0
	var calls := 0
	while guard < 300 and str(h.rules.state.phase) == "play":
		guard += 1
		var seat := int(h.rules.state.current_index)
		if bool(h.rules.state.players[seat].is_ai):
			h.ai_step(ai)
		else:
			var before_dame: bool = str(h.rules.state.phase) == "dame_called"
			h.machine_step(ai, seat)
			if str(h.rules.state.phase) == "dame_called" and not before_dame:
				calls += 1
		if not h.rules.assert_zones():
			t.expect(false, "Vertretung: Zonen kaputt: %s" % h.rules.zone_error)
			return
	t.expect(guard > 10, "Vertretung: spielt Zuege")
	t.expect(calls == 0, "Vertretung: ruft nie Dame")


func _check_absence_penalty() -> void:
	var h = _host()
	var before: int = h.rules.state.players[1].penalty_cards.size()
	var res: Dictionary = h.penalize_absence(1)
	t.expect(bool(res.ok) and h.rules.state.players[1].penalty_cards.size() == before + 1, "Wiedereinstieg: genau eine Strafkarte")
	t.expect(h.rules.assert_zones(), "Wiedereinstieg: Zonen heil: %s" % h.rules.zone_error)
	t.expect(not bool(h.penalize_absence(9).ok), "Wiedereinstieg: ungueltiger Platz abgelehnt")


# Abwesenheit geht als Zahl je Platz in die Sicht jedes Gastes; ohne Aenderung kein neuer Versand.
func _check_absence_in_views() -> void:
	var Loopback = preload("res://scripts/net/loopback_link.gd")
	var DameGuest = preload("res://scripts/net/dame_guest.gd")
	var hub = Loopback.new_hub()
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 3, "seat_count": 3, "ai_seats": [2]})
	var host = DameHost.new(rules, hub.link(1))
	var guest = DameGuest.new(hub.link(2))
	guest.connect_to_host()
	host.poll()
	guest.poll()
	host.assign_seat(2, 1)
	guest.poll()
	t.expect(int(guest.latest_view.players[0].absence) == 0, "Abwesenheit: Standard nicht 0")
	var rev: int = guest.rev
	host.set_absence(0, 1)
	guest.poll()
	t.expect(int(guest.latest_view.players[0].absence) == 1 and guest.rev == rev + 1, "Abwesenheit: Gast sieht Stufe 1 des Hosts nicht")
	host.set_absence(0, 1)
	guest.poll()
	t.expect(guest.rev == rev + 1, "Abwesenheit: gleiche Stufe sendet erneut")
	host.set_absence(0, 3)
	guest.poll()
	t.expect(int(guest.latest_view.players[0].absence) == 3, "Abwesenheit: Stufe 3 fehlt")
	host.set_absence(0, 0)
	guest.poll()
	t.expect(int(guest.latest_view.players[0].absence) == 0 and not host.absence.has(0), "Abwesenheit: Rueckkehr loescht die Stufe nicht")
	t.expect(DameView.absence_text(0) == "" and DameView.absence_text(1) != "" and DameView.absence_text(9) == "", "Abwesenheit: Texte")
