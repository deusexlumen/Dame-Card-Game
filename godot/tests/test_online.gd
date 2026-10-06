extends RefCounted

# Online v1: geschwaerzter Zustand (DameMirror), Aussetzen, Server-Partie (OnlineMatch).
# CONCEPT_DECISIONS §10/§11.

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const DamePolicyScript = preload("res://scripts/dame_policy.gd")
const DameMirrorScript = preload("res://scripts/online/dame_mirror.gd")
const OnlineMatchScript = preload("res://scripts/online/online_match.gd")
const RoomManagerScript = preload("res://scripts/online/room_manager.gd")
const ProtoScript = preload("res://scripts/online/net_protocol.gd")

var t

func run(ctx) -> void:
	t = ctx
	for n in [2, 4, 6]:
		_check_mirror_over_game(n, 11 + n)
	_check_mirror_drops_seed()
	_check_skip_turn()
	_check_client_cannot_cheat()
	_check_timeout_penalty()
	_check_stage1_skip()
	_check_stage2_takeover_and_rejoin_penalty()
	_check_stage3_forfeit()
	_check_all_away_ends()
	_check_full_online_game()
	_check_rooms()
	_check_protocol()


# ---------------------------------------------------------------- Spiegel

func _check_mirror_over_game(n: int, seed: int) -> void:
	var rules = DameRulesScript.new()
	rules.start_match({"seed": seed, "seat_count": n, "ai_seats": range(n)})
	var ai = DameAIScript.new(seed)
	var steps := 0
	var problems := 0
	while steps < 900 and str(rules.state.phase) != "game_over" and problems == 0:
		steps += 1
		if str(rules.state.phase) == "round_end":
			rules.apply_action({"type": "start_next_round"})
		else:
			ai.step(rules)
		for seat in range(n):
			problems += _compare_mirror(rules, seat, "n=%d Schritt %d Platz %d" % [n, steps, seat])
	t.expect(problems == 0, "Spiegel n=%d: %d Abweichungen" % [n, problems])
	t.expect(steps > 20, "Spiegel n=%d: Partie zu kurz (%d)" % [n, steps])


func _compare_mirror(rules, seat: int, label: String) -> int:
	var mirror: Dictionary = DameMirrorScript.for_viewer(rules, seat)
	var client = DameRulesScript.new()
	if not DameMirrorScript.load_into(client, mirror):
		t.expect(false, "%s: Spiegel nicht ladbar (%s)" % [label, client.zone_error])
		return 1
	var real_view: Dictionary = DameViewScript.for_viewer(rules, seat)
	var mirror_view: Dictionary = DameViewScript.for_viewer(client, seat)
	if JSON.stringify(real_view) != JSON.stringify(mirror_view):
		t.expect(false, "%s: Sicht aus Spiegel weicht ab" % label)
		return 1
	var text := JSON.stringify(mirror)
	for id in _hidden_ids(rules, seat):
		if text.contains("\"%s\"" % id):
			t.expect(false, "%s: verdeckte Karte %s im Spiegel" % [label, id])
			return 1
	return 0


# Karten, die der Betrachter nicht kennen darf (ohne die, die er selbst gesehen hat).
func _hidden_ids(rules, seat: int) -> Array:
	var st: Dictionary = rules.state
	var reveal_all := str(st.phase) == "round_end" or str(st.phase) == "game_over"
	var viewer: Dictionary = st.players[seat]
	var allowed := {}
	for id in viewer.seen_ids:
		allowed[str(id)] = true
	if st.get("last_look", null) != null and int(st.last_look_by) == seat:
		allowed[str(st.last_look.id)] = true
	var hidden: Array = []
	for card in st.deck:
		hidden.append(str(card.id))
	for i in range(st.discard.size() - 1):
		hidden.append(str(st.discard[i].id))
	for p in st.players:
		for card in p.penalty_cards:
			hidden.append(str(card.id))
		for i in range(p.hand.size()):
			var card: Dictionary = p.hand[i]
			var own := int(p.seat) == seat
			if reveal_all or bool(card.face_up) or (own and p.known.has(i)):
				continue
			hidden.append(str(card.id))
	if st.drawn_card != null and int(st.current_index) != seat and str(st.get("drawn_from", "deck")) != "discard":
		hidden.append(str(st.drawn_card.id))
	var out: Array = []
	for id in hidden:
		if not allowed.has(id):
			out.append(id)
	return out


func _check_mirror_drops_seed() -> void:
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 4242, "seat_count": 3, "ai_seats": []})
	var mirror: Dictionary = DameMirrorScript.for_viewer(rules, 1)
	t.expect(int(mirror.seed) == 0, "Spiegel enthaelt den Seed")
	t.expect(mirror.players[0].known.is_empty(), "Spiegel zeigt fremdes Gedaechtnis")
	t.expect(not mirror.players[1].known.is_empty(), "Spiegel verliert eigenes Gedaechtnis")
	t.expect(int(DameMirrorScript.for_viewer(rules, 0).deck.size()) == rules.state.deck.size(), "Spiegel: Stapelgroesse falsch")


# ---------------------------------------------------------------- Aussetzen

func _check_skip_turn() -> void:
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 3, "seat_count": 3, "ai_seats": []})
	var hand_before: String = JSON.stringify(rules.state.players[0].hand)
	var pen_before: int = rules.state.players[0].penalty_cards.size()
	var r: Dictionary = rules.apply_action({"type": "skip_turn", "seat": 0})
	t.expect(bool(r.ok), "Aussetzen scheitert: %s" % str(r.get("reason", "")))
	t.expect(int(rules.state.current_index) == 1, "Aussetzen: naechster Spieler nicht am Zug")
	t.expect(JSON.stringify(rules.state.players[0].hand) == hand_before, "Aussetzen veraendert die Hand")
	t.expect(rules.state.players[0].penalty_cards.size() == pen_before, "Aussetzen gibt Strafkarte")
	t.expect(rules.assert_zones(), "Aussetzen: Zonen kaputt")
	rules.apply_action({"type": "draw_deck", "seat": 1})
	r = rules.apply_action({"type": "skip_turn", "seat": 1})
	t.expect(not bool(r.ok), "Aussetzen nach dem Ziehen erlaubt")


# ---------------------------------------------------------------- Server-Partie

func _match(kinds: Array, seed: int = 99):
	var list: Array = []
	for i in range(kinds.size()):
		list.append({"name": "P%d" % i, "kind": kinds[i], "difficulty": "easy"})
	var m = OnlineMatchScript.new({"seats": list, "seed": seed, "turn_seconds": 20})
	for seat in m.human_seats():
		m.set_present(seat, true)
	return m


func _check_client_cannot_cheat() -> void:
	var m = _match(["human", "human"])
	t.expect(not bool(m.submit(0, {"type": "timeout_penalty"}).ok), "Client darf Strafe ausloesen")
	t.expect(not bool(m.submit(0, {"type": "start_next_round"}).ok), "Client darf naechste Ausgabe starten")
	t.expect(not bool(m.submit(0, {"type": "skip_turn"}).ok), "Client darf aussetzen")
	t.expect(not bool(m.submit(1, {"type": "draw_deck"}).ok), "Platz 1 zieht fuer Platz 0")
	var r: Dictionary = m.submit(0, {"type": "draw_deck", "seat": 1})
	t.expect(bool(r.ok) and int(m.rules.state.current_index) == 0, "Fremder seat im Paket wird nicht ignoriert")


func _check_timeout_penalty() -> void:
	var m = _match(["human", "human"])
	m.tick(19.0)
	t.expect(int(m.rules.state.current_index) == 0, "Timer laeuft zu frueh ab")
	m.tick(1.5)
	t.expect(int(m.rules.state.current_index) == 1, "Zeit abgelaufen: Zug nicht beendet")
	t.expect(m.rules.state.players[0].penalty_cards.size() == 1, "Zeit abgelaufen: keine Strafkarte")
	t.expect(m.rules.assert_zones(), "Timeout: Zonen kaputt")


func _check_stage1_skip() -> void:
	var m = _match(["human", "human"])
	var hand_before: String = JSON.stringify(m.rules.state.players[0].hand)
	m.set_present(0, false)
	m.tick(20.5)
	t.expect(int(m.rules.state.current_index) == 0, "Funkloch: Verbindungsreserve nicht abgewartet")
	m.tick(15.0)
	t.expect(int(m.rules.state.current_index) == 1, "Funkloch: Spieler setzt nicht aus")
	t.expect(m.rules.state.players[0].penalty_cards.is_empty(), "Funkloch: Strafkarte vergeben")
	t.expect(JSON.stringify(m.rules.state.players[0].hand) == hand_before, "Funkloch: Hand veraendert")
	t.expect(int(m.seats[0].stage) == 1, "Funkloch: Stufe 1 erwartet, ist %d" % int(m.seats[0].stage))
	m.set_present(0, true)
	t.expect(int(m.seats[0].stage) == 0 and not bool(m.seats[0].pending_penalty), "Funkloch: Rueckkehr nicht straffrei")


func _check_stage2_takeover_and_rejoin_penalty() -> void:
	var m = _match(["human", "human"])
	m.set_present(1, false)
	for _i in range(130):
		m.tick(0.5)
	t.expect(int(m.seats[1].stage) == 2, "Stufe 2 nach 60 s erwartet, ist %d" % int(m.seats[1].stage))
	# Platz 0 spielt seinen Zug, danach muss die Vertretung fuer Platz 1 ziehen.
	_play_turn(m, 0)
	var guard := 0
	while int(m.rules.state.current_index) == 1 and guard < 40:
		guard += 1
		m.tick(0.5)
	t.expect(int(m.rules.state.current_index) != 1, "Stufe 2: Vertretung spielt nicht")
	t.expect(int(m.rules.state.dame_caller_index) != 1, "Vertretung hat Dame gerufen")
	m.set_present(1, true)
	t.expect(bool(m.seats[1].pending_penalty), "Wiedereinstieg in Stufe 2 ohne Strafe")
	var deal: int = int(m.rules.state.deal)
	m.rules.state.phase = "round_end"
	m.tick(m.NEXT_DEAL_SECONDS + 0.1)
	t.expect(int(m.rules.state.deal) == deal + 1, "Naechste Ausgabe startet nicht")
	t.expect(m.rules.state.players[1].penalty_cards.size() == 1, "Wiedereinstieg: Strafkarte fehlt in der naechsten Ausgabe")
	t.expect(not bool(m.seats[1].pending_penalty), "Strafe doppelt vorgemerkt")


func _check_stage3_forfeit() -> void:
	var m = _match(["human", "human", "ai"])
	m.set_present(2 - 1, false)
	for _i in range(320):
		m.tick(1.0)
		if m.finished:
			break
	t.expect(bool(m.seats[1].forfeited), "Stufe 3: Platz nicht verloren")
	m.set_present(1, true)
	t.expect(not bool(m.seats[1].present), "Stufe 3: Wiedereinstieg trotzdem moeglich")
	t.expect(not m.can_rejoin(1), "Stufe 3: can_rejoin meldet true")


func _check_all_away_ends() -> void:
	var m = _match(["human", "human"])
	m.set_present(0, false)
	m.set_present(1, false)
	var current: int = int(m.rules.state.current_index)
	m.tick(100.0)
	t.expect(int(m.rules.state.current_index) == current, "Alle weg: Partie laeuft weiter")
	m.tick(201.0)
	t.expect(m.finished and m.end_reason == "abandoned", "Alle weg: Partie endet nicht ohne Wertung")


# Mensch spielt ueber den Client-Weg: Spiegel laden, Sicht bauen, Policy waehlt.
func _play_turn(m, seat: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var guard := 0
	while guard < 10 and int(m.rules.state.current_index) == seat and str(m.rules.state.phase) in ["play", "dame_called"]:
		guard += 1
		var client = DameRulesScript.new()
		DameMirrorScript.load_into(client, m.mirror_for(seat))
		var view: Dictionary = DameViewScript.for_viewer(client, seat)
		var action: Dictionary = DamePolicyScript.choose(view, rng)
		if not bool(m.submit(seat, action).ok):
			m.submit(seat, {"type": "end_turn"})
			break


func _check_full_online_game() -> void:
	var m = _match(["human", "ai", "human", "ai"], 1234)
	var guard := 0
	while not m.finished and guard < 20000:
		guard += 1
		var seat: int = int(m.rules.state.current_index)
		var phase := str(m.rules.state.phase)
		if phase == "round_end":
			for h in m.human_seats():
				m.submit(h, {"type": "ready_next"})
		elif str(m.seats[seat].kind) == "human" and (phase == "play" or phase == "dame_called"):
			_play_turn(m, seat)
		m.tick(0.5)
		if not m.rules.assert_zones():
			t.expect(false, "Online-Partie: Zonen kaputt: %s" % m.rules.zone_error)
			return
	t.expect(m.finished and m.end_reason == "game_over", "Online-Partie endet nicht regulaer (%s, %d Schritte)" % [m.end_reason, guard])


# ---------------------------------------------------------------- Lobby

func _check_rooms() -> void:
	var rm = RoomManagerScript.new()
	t.expect(not bool(rm.join("NOPE42", "X").ok), "Unbekannter Code wird angenommen")
	var host: Dictionary = rm.create("Anna", {"seat_count": 2})
	t.expect(bool(host.ok) and str(host.code).length() == 6, "Raum wird nicht erstellt")
	var guest: Dictionary = rm.join(str(host.code).to_lower(), "Ben")
	t.expect(bool(guest.ok) and int(guest.seat) == 1, "Beitritt mit Kleinbuchstaben scheitert")
	t.expect(not bool(rm.join(host.code, "Cem").ok), "Voller Tisch nimmt weitere Spieler")
	t.expect(str(guest.token) != str(host.token) and str(guest.token).length() == 32, "Token unsicher")
	t.expect(not bool(rm.start(host.code, guest.token).ok), "Gast darf starten")
	rm.leave(host.code, guest.token)
	t.expect(str(rm.rooms[host.code].seats[1].kind) == "open", "Verlassen der Lobby gibt den Platz nicht frei")
	guest = rm.join(host.code, "Ben")
	t.expect(bool(rm.start(host.code, host.token).ok), "Gastgeber kann nicht starten")
	t.expect(not bool(rm.join(host.code, "Cem").ok), "Beitritt in laufende Partie moeglich")
	var again: Dictionary = rm.rejoin(host.code, guest.token)
	t.expect(bool(again.ok) and int(again.seat) == 1, "Wiedereinstieg mit Token scheitert")
	t.expect(not bool(rm.rejoin(host.code, "falsch").ok), "Wiedereinstieg mit falschem Token")
	t.expect(not bool(rm.action(host.code, "falsch", {"type": "draw_deck"}).ok), "Aktion ohne Token angenommen")
	t.expect(RoomManagerScript.clean_name("  <b>Ä\u0007lex</b>  ", 2).find("<") < 0, "Name nicht bereinigt")
	t.expect(RoomManagerScript.clean_name("   ", 2) == "Spieler 3", "Leerer Name ohne Ersatz")


func _check_protocol() -> void:
	t.expect(ProtoScript.decode_client("{kaputt").is_empty(), "Kaputtes JSON angenommen")
	t.expect(ProtoScript.decode_client(JSON.stringify({"t": "hack"})).is_empty(), "Unbekannter Typ angenommen")
	var big := JSON.stringify({"t": "join", "code": "A".repeat(5000)})
	t.expect(ProtoScript.decode_client(big).is_empty(), "Uebergrosse Nachricht angenommen")
	var msg: Dictionary = ProtoScript.decode_client(JSON.stringify({"t": "action", "action": {"type": "swap", "hand_index": 2, "evil": {"x": 1}, "seat": 5}}))
	t.expect(msg.action.has("hand_index") and not msg.action.has("evil") and not msg.action.has("seat"), "Aktion nicht bereinigt")
