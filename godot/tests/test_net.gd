extends RefCounted

# Online-Kern (Schritt 1): Host-Autoritaet, Sitz-Zuordnung, Codec und dass
# ein Gast nie mehr erfaehrt als seine eigene Sicht. Alles ueber das
# Loopback-Netz, also mit echtem Kodieren wie spaeter im Netz.

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")
const DamePolicyScript = preload("res://scripts/dame_policy.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const Protocol = preload("res://scripts/net/net_protocol.gd")
const Codec = preload("res://scripts/net/net_codec.gd")
const Loopback = preload("res://scripts/net/loopback_link.gd")
const DameHost = preload("res://scripts/net/dame_host.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")

const GUEST_PEER := 2
const GUEST_SEAT := 1

var t
var rules
var host
var guest
var hub
var last_result: Dictionary = {}
var guest_views := 0
var leak_checks := 0


func run(ctx) -> void:
	t = ctx
	_check_codec()
	_check_sanitize()
	_check_handshake()
	_check_seat_authority()
	_check_stale_view_dropped()
	_check_public_actions()
	_check_host_drives_ai_and_timeout()
	_check_failed_action_that_changes_state()
	_check_full_game_no_leak()


func _setup(seed: int) -> void:
	rules = DameRulesScript.new()
	rules.start_match({"seed": seed, "seat_count": 3, "ai_seats": [2]})
	hub = Loopback.new_hub()
	host = DameHost.new(rules, hub.link(Protocol.HOST_PEER))
	guest = DameGuest.new(hub.link(GUEST_PEER))
	last_result = {}
	host.action_result.connect(_on_result)
	guest.action_result.connect(_on_result)
	guest.connect_to_host()
	host.poll()
	guest.poll()
	host.assign_seat(Protocol.HOST_PEER, 0)
	host.assign_seat(GUEST_PEER, GUEST_SEAT)
	guest.poll()


func _on_result(r: Dictionary) -> void:
	last_result = r


func _guest_act(action) -> bool:
	last_result = {}
	guest.send_action(action)
	host.poll()
	guest.poll()
	return bool(last_result.get("ok", false))


func _check_codec() -> void:
	var back: Dictionary = Codec.decode(Codec.encode({"seat": 3, "nested": {"i": 2}}))
	t.expect(typeof(back.seat) == TYPE_INT and int(back.seat) == 3, "Codec macht aus int etwas anderes")
	t.expect(typeof(back.nested.i) == TYPE_INT, "Codec verliert int in Verschachtelung")
	t.expect(Codec.decode(PackedByteArray([1, 2, 3])).is_empty(), "Codec akzeptiert Muell")
	t.expect(Codec.decode(var_to_bytes([1, 2])).is_empty(), "Codec akzeptiert Nicht-Dictionary")


func _check_sanitize() -> void:
	t.expect(Protocol.sanitize_action({"type": "start_next_round"}).is_empty(), "Gast darf Runde starten")
	t.expect(Protocol.sanitize_action({"type": "timeout_penalty"}).is_empty(), "Gast darf Strafkarte ausloesen")
	t.expect(Protocol.sanitize_action({"type": "swap", "hand_index": "1"}).is_empty(), "String als Index angenommen")
	t.expect(Protocol.sanitize_action("draw_deck").is_empty(), "Nicht-Dictionary angenommen")
	var clean: Dictionary = Protocol.sanitize_action({"type": "swap", "hand_index": 2.0, "seat": 0, "extra": "x"})
	t.expect(typeof(clean.hand_index) == TYPE_INT, "Index nicht zu int gemacht")
	t.expect(not clean.has("seat") and not clean.has("extra"), "Fremde Felder nicht entfernt")


func _check_handshake() -> void:
	_setup(41)
	t.expect(int(guest.latest_view.get("viewer_seat", -1)) == GUEST_SEAT, "Gast hat nach Zuweisung keine eigene Sicht")
	t.expect(int(host.latest_view.get("viewer_seat", -1)) == 0, "Host-Spieler hat keine eigene Sicht")
	var stranger = hub.link(9)
	stranger.send(Protocol.HOST_PEER, Codec.encode({"t": "hello", "v": Protocol.VERSION + 1}))
	host.poll()
	var rejected := false
	for pkt in stranger.receive():
		rejected = str(Codec.decode(pkt.bytes).get("t", "")) == "reject"
	t.expect(rejected, "Falsche Version nicht abgewiesen")
	stranger.send(Protocol.HOST_PEER, PackedByteArray([7, 7, 7]))
	host.poll()
	t.expect(stranger.receive().is_empty(), "Muellpaket beantwortet")


func _check_seat_authority() -> void:
	_setup(42)
	var deck_before: int = rules.state.deck.size()
	t.expect(int(rules.state.current_index) == 0, "Testannahme: Sitz 0 beginnt")
	t.expect(not _guest_act({"type": "draw_deck"}), "Gast zieht ausserhalb seines Zuges")
	t.expect(not _guest_act({"type": "draw_deck", "seat": 0}), "Gast spielt fuer fremden Sitz")
	t.expect(not _guest_act({"type": "start_next_round"}), "Gast startet Runde")
	t.expect(not _guest_act({"type": "timeout_penalty"}), "Gast loest Strafkarte aus")
	t.expect(rules.state.deck.size() == deck_before, "Abgelehnte Gastaktion hat den Stapel veraendert")
	t.expect(not _guest_act({"type": "start_next_round", "seat": 1}), "Gast startet Runde mit Platzangabe")
	t.expect(rules.state.deck.size() == deck_before, "Gast-Systemaktion hat den Stapel veraendert")
	var lurker = hub.link(5)
	lurker.send(Protocol.HOST_PEER, Codec.encode(Protocol.action({"type": "draw_deck"})))
	host.poll()
	t.expect(rules.state.deck.size() == deck_before, "Peer ohne Platz hat gespielt")
	# Host-Spieler geht ueber denselben Weg und darf ziehen.
	last_result = {}
	host.send_action({"type": "draw_deck"})
	t.expect(bool(last_result.get("ok", false)), "Host-Spieler kann nicht ziehen")
	guest.poll()
	t.expect(str(guest.latest_view.turn_step) == "play", "Gast sieht den Zug des Hosts nicht")
	t.expect(not bool(guest.latest_view.drawn.known), "Gast sieht die gezogene Karte des Hosts")


func _check_public_actions() -> void:
	var a := Protocol.public_action({"type": "king_swap", "opponent_seat": 2, "opponent_index": 1, "chosen_index": 0, "rank": "K", "id": "x"}, 1)
	t.expect(a.keys().size() == 5 and int(a.seat) == 1 and not a.has("rank") and not a.has("id"), "Aktion traegt fremde Felder")
	t.expect(Protocol.public_action({"type": "timeout_penalty", "seat": 0, "card": {}}, 0).keys().size() == 2, "Systemaktion traegt Zusatzfelder")
	var b := Protocol.public_action({"type": "draw_deck", "seat": 2}, 0)
	t.expect(int(b.seat) == 0 and b.keys().size() == 2, "Seat aus Aktion statt Parameter")


func _check_host_drives_ai_and_timeout() -> void:
	_setup(44)
	var actions: Array = []
	guest.view_changed.connect(func(_v, a): actions.append(a))
	host.send_action({"type": "draw_deck"})
	host.send_action({"type": "discard_drawn"})
	host.send_action({"type": "end_turn"})
	guest.poll()
	t.expect(not actions.is_empty() and str(actions[-1].type) == "end_turn" and int(actions[-1].seat) == 0, "Gast bekommt Aktion des Hosts nicht")
	t.expect(int(rules.state.current_index) == GUEST_SEAT, "Testannahme: Gast ist nach dem Host dran")
	var ai = DameAIScript.new(1)
	var pen_before: int = rules.state.players[1].penalty_cards.size()
	var n_before := actions.size()
	var res: Dictionary = host.timeout_turn(ai)
	guest.poll()
	t.expect(bool(res.ok) and int(rules.state.current_index) == 2, "Zeitablauf beendet den Zug nicht")
	t.expect(rules.state.players[1].penalty_cards.size() == pen_before + 1, "Zeitablauf ohne Strafkarte")
	t.expect(str(actions[-1].type) == "end_turn", "Ersatzaktionen nicht einzeln verschickt")
	t.expect(str(actions[n_before].type) == "timeout_penalty" and actions.size() - n_before >= 2, "Strafkarte nicht einzeln verschickt")
	var r2: Dictionary = host.ai_step(ai)
	guest.poll()
	t.expect(bool(r2.ok) and int(actions[-1].seat) == 2, "KI-Schritt nicht verschickt")
	t.expect(host.is_authority() and not guest.is_authority(), "is_authority falsch")
	# Zugfreie Runde: next_round nur im passenden Zustand, sonst abgelehnt.
	t.expect(not bool(host.next_round().get("ok", false)), "next_round mitten in der Runde")


func _check_stale_view_dropped() -> void:
	_setup(43)
	var rev_now: int = guest.rev
	var fake := {"t": "view", "rev": rev_now, "view": {"viewer_seat": 99}}
	hub.deliver(Protocol.HOST_PEER, GUEST_PEER, Codec.encode(fake))
	guest.poll()
	t.expect(int(guest.latest_view.viewer_seat) == GUEST_SEAT, "Veraltete Sicht uebernommen")
	var spoof := {"t": "view", "rev": rev_now + 50, "view": {"viewer_seat": 99}}
	hub.deliver(7, GUEST_PEER, Codec.encode(spoof))
	guest.poll()
	t.expect(int(guest.latest_view.viewer_seat) == GUEST_SEAT, "Sicht von fremdem Peer uebernommen")


# Eine ganze Partie: Sitz 0 Host-Spieler, Sitz 1 Gast, Sitz 2 KI auf dem Host.
# Jede Sicht, die beim Gast ankommt, wird gegen den echten Zustand geprueft.
func _check_full_game_no_leak() -> void:
	for seed in [7, 19]:
		_setup(seed)
		guest_views = 0
		leak_checks = 0
		guest.view_changed.connect(_on_guest_view)
		var ai = DameAIScript.new(seed)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var guest_ok := 0
		var steps := 0
		while steps < 4000 and str(rules.state.phase) != "game_over":
			steps += 1
			var phase := str(rules.state.phase)
			if phase == "round_end":
				host.next_round()
				guest.poll()
				continue
			var cur := int(rules.state.current_index)
			if bool(rules.state.players[cur].is_ai):
				ai.complete_turn(rules)
				host.broadcast()
				guest.poll()
				continue
			var is_guest := cur == GUEST_SEAT
			var view: Dictionary = guest.latest_view if is_guest else host.latest_view
			var ok := _try(is_guest, DamePolicyScript.choose(view, rng))
			if not ok:
				for cand in _candidates(view):
					if _try(is_guest, cand):
						ok = true
						break
			if not ok:
				host.timeout_turn(ai)
				guest.poll()
			elif is_guest:
				guest_ok += 1
			if not rules.assert_zones():
				t.expect(false, "Zonen kaputt nach Netzaktion (Seed %d, Schritt %d): %s" % [seed, steps, rules.zone_error])
				break
		t.expect(str(rules.state.phase) == "game_over", "Netzpartie endet nicht (Seed %d)" % seed)
		t.expect(guest_ok > 20, "Gast hat kaum gespielt (Seed %d): %d" % [seed, guest_ok])
		t.expect(guest_views > 20 and leak_checks == guest_views, "Gastsichten nicht geprueft (Seed %d)" % seed)
		guest.view_changed.disconnect(_on_guest_view)


func _try(is_guest: bool, action: Dictionary) -> bool:
	if is_guest:
		return _guest_act(action)
	last_result = {}
	host.send_action(action)
	guest.poll()
	return bool(last_result.get("ok", false))


# Ersatzaktionen nur aus der Sicht, wie sie ein Client haette.
func _candidates(view: Dictionary) -> Array:
	var out: Array = []
	match str(view.turn_step):
		"draw":
			out.append({"type": "draw_deck"})
			out.append({"type": "draw_discard"})
		"play":
			out.append({"type": "discard_drawn"})
		"jack":
			for p in view.players:
				for c in p.cards:
					out.append({"type": "look_card", "target_seat": int(p.seat), "hand_index": int(c.index)})
		"king":
			var me: Dictionary = view.players[int(view.viewer_seat)]
			for p in view.players:
				if bool(p.is_self):
					continue
				for c in p.cards:
					for mine in me.cards:
						out.append({"type": "king_swap", "opponent_seat": int(p.seat), "opponent_index": int(c.index), "chosen_index": int(mine.index)})
	out.append({"type": "end_turn"})
	return out


func _on_guest_view(view: Dictionary, action: Dictionary) -> void:
	guest_views += 1
	if not action.is_empty():
		var type := str(action.get("type", ""))
		var allowed: Array = ["type", "seat"]
		allowed.append_array(Protocol.PLAYER_ACTIONS.get(type, []))
		t.expect(Protocol.PLAYER_ACTIONS.has(type) or Protocol.SYSTEM_ACTIONS.has(type), "Unbekannter Aktionstyp in Sicht")
		for k in action.keys():
			t.expect(allowed.has(k), "Aktion traegt unerlaubtes Feld %s" % k)
	var expected: Dictionary = DameViewScript.for_viewer(rules, GUEST_SEAT)
	t.expect(var_to_str(view) == var_to_str(expected), "Gastsicht weicht von DameView ab")
	# private_look darf die ID der eigenen angesehenen Karte tragen, sonst keine IDs.
	var public_part := view.duplicate()
	public_part.erase("private_look")
	var text := var_to_str(public_part)
	for suit in DameRulesScript.SUITS:
		t.expect(not text.contains(str(suit) + "-"), "Gastsicht enthaelt Karten-ID")
	var state: Dictionary = rules.state
	var reveal := str(state.phase) == "round_end" or str(state.phase) == "game_over"
	var me: Dictionary = state.players[GUEST_SEAT]
	for p in view.players:
		var real: Dictionary = state.players[int(p.seat)]
		for c in p.cards:
			if not bool(c.known) or reveal:
				continue
			var card: Dictionary = real.hand[int(c.index)]
			var allowed := bool(card.face_up)
			if int(p.seat) == GUEST_SEAT:
				allowed = allowed or me.known.has(int(c.index))
			else:
				allowed = allowed or me.seen_ids.has(str(card.id))
			t.expect(allowed, "Gast sieht fremde verdeckte Karte (Sitz %d, Index %d)" % [int(p.seat), int(c.index)])
	if view.private_look != null:
		t.expect(int(state.last_look_by) == GUEST_SEAT, "Gast sieht fremdes Bube/Koenig-Ansehen")
	if view.drawn != null and bool(view.drawn.known):
		t.expect(int(state.current_index) == GUEST_SEAT or str(state.get("drawn_from", "")) == "discard", "Gast sieht fremde gezogene Karte")
	if state.last_look != null and int(state.last_look_by) != GUEST_SEAT:
		var label := DameRulesScript.card_label(state.last_look)
		for line in view.log:
			if str(line).begins_with("Bube: verdeckte") or str(line).begins_with("König: eigene"):
				t.expect(not str(line).contains(label), "Logzeile verraet angesehene Karte")
	leak_checks += 1


# Abgelehnt, aber veraendert: falsches Extra-Ablegen gibt eine Strafkarte. Alle
# bekommen eine neue Sicht; ein Fehlschlag ohne Aenderung verschickt keine.
func _check_failed_action_that_changes_state() -> void:
	var found := false
	for seed in range(44, 120):
		_setup(seed)
		if not _reach_guest_extra():
			continue
		var hand: Array = rules.state.players[GUEST_SEAT].hand
		var top_rank := str(rules.top_discard().rank)
		var wrong := -1
		for i in range(hand.size()):
			if str(hand[i].rank) != top_rank:
				wrong = i
				break
		if wrong < 0:
			continue
		found = true
		var guest_pen := int(guest.latest_view.players[GUEST_SEAT].penalty_count)
		var host_pen := int(host.latest_view.players[GUEST_SEAT].penalty_count)
		var rev_before: int = host.rev
		t.expect(not _guest_act({"type": "discard_extra", "hand_index": wrong}), "falsches Extra-Ablegen angenommen")
		t.expect(bool(last_result.get("changed", false)), "Ergebnis meldet die Zustandsaenderung nicht")
		t.expect(int(guest.latest_view.players[GUEST_SEAT].penalty_count) == guest_pen + 1, "Gast sieht seine Strafkarte nicht")
		t.expect(int(host.latest_view.players[GUEST_SEAT].penalty_count) == host_pen + 1, "Host-Sicht ohne Strafkarte des Gastes")
		t.expect(host.rev == rev_before + 1, "Neue Sicht nicht genau einmal verteilt")
		# Fehlschlag ohne Aenderung: keine neue Sicht.
		var rev_now: int = host.rev
		var guest_rev: int = guest.rev
		t.expect(not _guest_act({"type": "draw_deck"}), "Ziehen im Extra-Schritt angenommen")
		t.expect(not bool(last_result.get("changed", true)), "Fehlschlag ohne Aenderung meldet Aenderung")
		t.expect(host.rev == rev_now and guest.rev == guest_rev, "Fehlschlag ohne Aenderung verschickt eine Sicht")
		break
	t.expect(found, "kein Seed mit Gast im Extra-Schritt gefunden")


# Host (Sitz 0) zieht und legt ab, Gast zieht und legt ab: Gast steht im Extra-Schritt.
func _reach_guest_extra() -> bool:
	for a in [{"type": "draw_deck"}, {"type": "discard_drawn"}, {"type": "end_turn"}]:
		last_result = {}
		host.send_action(a)
		if not bool(last_result.get("ok", false)):
			return false
	guest.poll()
	if int(rules.state.current_index) != GUEST_SEAT:
		return false
	if not _guest_act({"type": "draw_deck"}) or not _guest_act({"type": "discard_drawn"}):
		return false
	return str(rules.state.turn_step) == "extra"
