extends RefCounted

# Tisch als Online-Gast (Online 1b, Task 5): echter DameHost mit Loopback-Netz,
# echter DameGuest, der Tisch bekommt nur seine eigene Sicht und hat keine Regeln.
# Sitz 0: Host-Spieler (vom Test per Policy gesteuert), Sitz 1: Gast-Tisch (nur ueber
# die Eingabeschicht), Sitz 2: KI auf dem Host. Gespielt wird bis zum Spielende.

const TableScene = preload("res://scenes/table.tscn")
const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DamePolicyScript = preload("res://scripts/dame_policy.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const Protocol = preload("res://scripts/net/net_protocol.gd")
const Loopback = preload("res://scripts/net/loopback_link.gd")
const DameHost = preload("res://scripts/net/dame_host.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")

const GUEST_PEER := 2
const GUEST_SEAT := 1

var t
var app
var rules
var host
var guest
var table
# Wie oft die Policy-Entscheidung nicht ueber Eingaben ging und die einfachste
# Ersatzeingabe noetig war (Bericht).
var fallback_count := 0
var guest_inputs := 0
# Eingabearten des Gast-Tischs (Abdeckung: Bube, Koenig, Extra, Dame ueber Eingaben).
var input_types := {}


func run(ctx) -> void:
	t = ctx
	app = ctx.root.get_node_or_null("/root/App")
	# App-Zustand sichern: der Gast zaehlt eigene Statistik und Chips.
	var profile_before: Dictionary = {}
	var stats_before: Dictionary = {}
	var save_before: Dictionary = {}
	if app != null:
		profile_before = app.profile.data.duplicate(true)
		stats_before = app.stats.values.duplicate(true)
		save_before = app.saves.load_match()
	for seed in [23, 58]:
		_play_game(seed)
	print("TABLE_NET fallback=%d guest_inputs=%d types=%s" % [fallback_count, guest_inputs, str(input_types)])
	for type in ["draw_deck", "swap", "discard_drawn", "look_card", "king_swap", "end_turn"]:
		t.expect(int(input_types.get(type, 0)) > 0, "Gast-Tisch hat %s nie ueber Eingaben gespielt" % type)
	t.expect(fallback_count * 4 <= guest_inputs, "Zu viele Ersatzeingaben: %d von %d" % [fallback_count, guest_inputs])
	if app != null:
		app.profile.data = profile_before
		app.profile._save()
		app.stats.values = stats_before
		app.stats._touch()
		if save_before.is_empty():
			app.saves.clear()
		else:
			app.saves.save_match(save_before.rules, save_before.meta)


func _setup(seed: int) -> void:
	rules = DameRulesScript.new()
	rules.start_match({"seed": seed, "seat_count": 3, "ai_seats": [2], "difficulties": {2: "medium"}, "names": ["Host", "Gast", "KI"]})
	var hub = Loopback.new_hub()
	host = DameHost.new(rules, hub.link(Protocol.HOST_PEER))
	guest = DameGuest.new(hub.link(GUEST_PEER))
	guest.connect_to_host()
	host.poll()
	guest.poll()
	host.assign_seat(Protocol.HOST_PEER, 0)
	host.assign_seat(GUEST_PEER, GUEST_SEAT)
	guest.poll()
	table = TableScene.instantiate()
	table.instant_ai = true
	table.settings_override = {"memory_aid": true, "turn_timer": false, "animations": false}
	table.pending_session = guest
	t.root.add_child(table)


func _sync() -> void:
	host.poll()
	table.session.poll()


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	table._unhandled_input(ev)


func _play_game(seed: int) -> void:
	_setup(seed)
	var rounds_before := int(app.stats.values.rounds_played) if app != null else 0
	t.expect(table.rules == null, "Gast-Tisch hat Regeln")
	if table.session != guest or table._view.is_empty():
		t.expect(false, "Gast-Tisch ohne Gast-Session oder ohne erste Sicht")
		t.root.remove_child(table)
		table.free()
		return
	# Kein DameRules, keine KI, keine Startkonfiguration (start() setzt immer seed).
	t.expect(table.ai == null and not table.config.has("seed"), "Gast-Tisch hat eine eigene Partie angelegt")
	t.expect(table.local_seats == [GUEST_SEAT] and table.viewer_seat == GUEST_SEAT, "Gast-Tisch falscher Platz: %s / %d" % [str(table.local_seats), table.viewer_seat])
	t.expect(not table._view.is_empty() and int(table._view.viewer_seat) == GUEST_SEAT, "Gast-Tisch ohne erste Sicht")
	t.expect(table._seats.size() == 3, "Gast-Tisch ohne Plaetze")
	var host_ai = DameAIScript.new(seed)
	var host_rng := RandomNumberGenerator.new()
	host_rng.seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 3 + 1
	var rules_seen := false
	var leaks := 0
	var drift := 0
	var round_ends := 0
	var timer_checks := 0
	var steps := 0
	while steps < 3000 and str(rules.state.phase) != "game_over":
		steps += 1
		if table.rules != null:
			rules_seen = true
		leaks += _hidden_faces_shown()
		if var_to_str(table._view) != var_to_str(guest.latest_view):
			drift += 1
		var phase := str(rules.state.phase)
		if phase == "round_end":
			round_ends += 1
			_check_guest_round_end()
			host.next_round()
			_sync()
			continue
		var cur := int(rules.state.current_index)
		if cur == 2:
			host.ai_step(host_ai)
			_sync()
			continue
		if cur == 0:
			_host_player_step(host_rng)
			continue
		# Gast am Zug: Zugtimer darf nichts ausloesen.
		var pens_before: int = rules.state.players[GUEST_SEAT].penalty_cards.size()
		var state_before := var_to_str(rules.state)
		table.settings_override["turn_timer"] = true
		table._process(999.0)
		_sync()
		table.settings_override["turn_timer"] = false
		timer_checks += 1
		t.expect(rules.state.players[GUEST_SEAT].penalty_cards.size() == pens_before and var_to_str(rules.state) == state_before, "Gast loest Zeitablauf aus")
		_guest_step(rng)
	t.expect(str(rules.state.phase) == "game_over", "Partie mit Gast-Tisch endet nicht (Seed %d)" % seed)
	t.expect(str(table._view.phase) == "game_over", "Gast-Tisch sieht das Spielende nicht")
	t.expect(table._over_panel.visible, "Gast-Tisch zeigt kein Spielende")
	t.expect(not rules_seen and table.rules == null, "Gast-Tisch hat Regeln")
	t.expect(table.ai == null and not table.config.has("seed"), "Gast-Tisch hat eine eigene Partie angelegt")
	t.expect(leaks == 0, "Gast zeigt unbekannte Karte (%d mal, Seed %d)" % [leaks, seed])
	leaks = _hidden_faces_shown()
	t.expect(leaks == 0, "Gast zeigt unbekannte Karte am Spielende")
	t.expect(drift == 0, "Tisch-Sicht weicht von der Gast-Sicht ab (%d mal)" % drift)
	t.expect(round_ends > 0, "Testannahme: kein Rundenende erreicht (Seed %d)" % seed)
	t.expect(timer_checks > 10, "Testannahme: Gast kaum am Zug (Seed %d): %d" % [seed, timer_checks])
	# Gast zaehlt jede Ausgabe genau einmal (eigene Statistik).
	if app != null:
		var rounds := int(app.stats.values.rounds_played) - rounds_before
		t.expect(rounds == int(rules.state.deal), "Gast zaehlt Ausgaben falsch: %d statt %d" % [rounds, int(rules.state.deal)])
	t.root.remove_child(table)
	table.free()
	table = null


# Gesichter (2D-Proxy und Sicht) nur fuer Karten, die die Sicht als known fuehrt.
func _hidden_faces_shown() -> int:
	var n := 0
	var view: Dictionary = table._view
	for seat in range(int(view.seat_count)):
		var cards: Array = view.players[seat].cards
		for i in range(cards.size()):
			if not bool(cards[i].known) and table._face_for(seat, i, cards[i]):
				n += 1
		for cv in table._seats[seat].cards():
			var i := int(cv.index)
			if cv.shows_face() and (i < 0 or i >= cards.size() or not bool(cards[i].known)):
				n += 1
	var drawn = view.drawn
	if drawn != null and not bool(drawn.known) and table._drawn_view.shows_face():
		n += 1
	return n


# Review Focus 3: Enter, Knopf und next_deal starten beim Gast nichts.
func _check_guest_round_end() -> void:
	t.expect(str(table._view.phase) == "round_end", "Gast-Tisch sieht das Rundenende nicht")
	var deal_before: int = int(rules.state.deal)
	table.next_deal()
	_sync()
	t.expect(int(rules.state.deal) == deal_before and str(rules.state.phase) == "round_end", "Gast startet neue Ausgabe")
	t.expect(table._prompt.text == table.tr("Warte auf den Host …"), "Gast zeigt keinen Warte-Hinweis: " + table._prompt.text)
	table._refresh()
	t.expect(table._prompt.text == table.tr("Warte auf den Host …"), "Warte-Hinweis verschwindet beim Neuzeichnen: " + table._prompt.text)
	_key(KEY_ENTER)
	_sync()
	t.expect(int(rules.state.deal) == deal_before and str(rules.state.phase) == "round_end", "Gast startet neue Ausgabe mit Enter")
	t.expect(table._round_button.disabled, "Rundenknopf beim Gast aktiv")
	table._round_button.pressed.emit()
	_sync()
	t.expect(int(rules.state.deal) == deal_before, "Gast startet neue Ausgabe mit dem Knopf")


# Host-Spieler: Policy auf der Host-Sicht, Ersatzaktionen wie im Netztest.
func _host_player_step(rng: RandomNumberGenerator) -> void:
	var view: Dictionary = host.latest_view
	var before := var_to_str(rules.state)
	host.send_action(DamePolicyScript.choose(view, rng))
	if var_to_str(rules.state) == before:
		for cand in _host_candidates(view):
			host.send_action(cand)
			if var_to_str(rules.state) != before:
				break
	if var_to_str(rules.state) == before:
		host.timeout_turn(DameAIScript.new(1))
	_sync()


func _host_candidates(view: Dictionary) -> Array:
	var out: Array = []
	match str(view.turn_step):
		"draw":
			out.append({"type": "draw_deck"})
			out.append({"type": "draw_discard"})
		"play":
			out.append({"type": "discard_drawn"})
		"jack":
			out.append({"type": "look_card", "target_seat": 0, "hand_index": 0})
	out.append({"type": "end_turn"})
	return out


# Gast-Tisch: Entscheidung der Policy aus table._view, ausgefuehrt nur ueber Eingaben.
func _guest_step(rng: RandomNumberGenerator) -> void:
	t.expect(int(table._view.current_index) == GUEST_SEAT and table._human_turn(), "Gast-Tisch nicht am Zug, obwohl der Host es sagt")
	var before := var_to_str(rules.state)
	_input(DamePolicyScript.choose(table._view, rng))
	_sync()
	guest_inputs += 1
	if var_to_str(rules.state) != before:
		return
	fallback_count += 1
	_fallback_input()
	_sync()
	t.expect(var_to_str(rules.state) != before, "Gast-Tisch kommt nicht weiter (Schritt %s)" % str(table._view.turn_step))


func _input(action: Dictionary) -> void:
	input_types[str(action.type)] = int(input_types.get(str(action.type), 0)) + 1
	match str(action.type):
		"draw_deck":
			if guest_inputs % 2 == 0:
				table._on_deck()
			else:
				_key(KEY_SPACE)
		"draw_discard":
			table._on_discard()
		"swap":
			table._on_card(GUEST_SEAT, int(action.hand_index))
		"discard_drawn":
			if guest_inputs % 3 == 0:
				_key(KEY_A)
			elif guest_inputs % 3 == 1:
				table._on_drawn()
			else:
				table._on_discard()
		"discard_extra":
			table.select(int(action.hand_index))
			_key(KEY_X)
		"look_card":
			table._on_card(int(action.target_seat), int(action.hand_index))
		"king_swap":
			table._on_card(GUEST_SEAT, int(action.chosen_index))
			table._on_card(int(action.opponent_seat), int(action.opponent_index))
		"call_dame":
			if guest_inputs % 2 == 0:
				table.call_dame()
			else:
				_key(KEY_D)
		"end_turn":
			if str(table._view.turn_step) == "extra":
				_key(KEY_ENTER)
			else:
				table.end_turn()


# Einfachste erlaubte Eingabe fuer den aktuellen Schritt.
func _fallback_input() -> void:
	var view: Dictionary = table._view
	match str(view.turn_step):
		"draw":
			if int(view.deck_count) == 0 and int(view.discard_count) == 0:
				table.end_turn()
			elif bool(view.must_take_queen) or int(view.deck_count) == 0:
				table._on_discard()
			else:
				table._on_deck()
		"play":
			table._on_discard()
		"jack":
			table._on_card(GUEST_SEAT, 0)
		"king":
			table._on_card(GUEST_SEAT, 0)
			for p in view.players:
				if int(p.seat) != GUEST_SEAT and not bool(p.locked) and not bool(p.eliminated) and int(p.card_count) > 0:
					table._on_card(int(p.seat), 0)
					break
		_:
			table.end_turn()
