extends RefCounted

# Online-Tisch (Online 2, Task 2): Host-Tisch im Online-Host-Modus und Gast-Tisch
# (DameGuest) im selben Prozess, verbunden ueber echte ENet-Peers auf localhost
# (PeerLink). Sitz 0: Host-Tisch, Sitz 1: Gast-Tisch, Sitz 2: KI auf dem Host.
# Beide Tische werden nur ueber die Eingabeschicht gesteuert.
# Jede Warteschleife hat eine harte Obergrenze; alle Peers werden immer geschlossen.

const TableScene = preload("res://scenes/table.tscn")
const DamePolicyScript = preload("res://scripts/dame_policy.gd")
const Protocol = preload("res://scripts/net/net_protocol.gd")
const PeerLink = preload("res://scripts/net/peer_link.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")

const MAX_ITER := 300
const PORT_FIRST := 24700
const PORT_LAST := 24760
const HOST_SEAT := 0
const GUEST_SEAT := 1
const AI_SEAT := 2
const HOST_LEFT_TEXT := "Der Host hat die Partie verlassen. Die Partie endet ohne Wertung."
const PAUSE_ONLINE := "Hauptmenü (Verbindung wird getrennt)"

var t
var app
var _peers: Array = []
var _tables: Array = []
# Aktuelle Verbindung
var server: ENetMultiplayerPeer
var client: ENetMultiplayerPeer
var server_link
var client_link
var gid := 0
var host_table
var guest_table
var guest
var guest_results: Array = []
var fallback_count := 0
var guest_inputs := 0
var input_types := {}


func run(ctx) -> void:
	t = ctx
	app = ctx.root.get_node_or_null("/root/App")
	var profile_before: Dictionary = {}
	var stats_before: Dictionary = {}
	var save_before: Dictionary = {}
	if app != null:
		profile_before = app.profile.data.duplicate(true)
		stats_before = app.stats.values.duplicate(true)
		save_before = app.saves.load_match()
		app.saves.clear()
	_check_full_game(23)
	_check_guest_leaves(41)
	_check_host_leaves(57)
	_check_app_handoff(61)
	_check_offline_pause_label()
	print("ONLINE_TABLE fallback=%d guest_inputs=%d types=%s" % [fallback_count, guest_inputs, str(input_types)])
	if app != null:
		app.pending = {}
		app.profile.data = profile_before
		app.profile._save()
		app.stats.values = stats_before
		app.stats._touch()
		if save_before.is_empty():
			app.saves.clear()
		else:
			app.saves.save_match(save_before.rules, save_before.meta)


# ---------- Hilfen ----------

func _server() -> Array:
	for port in range(PORT_FIRST, PORT_LAST + 1):
		var s := ENetMultiplayerPeer.new()
		if s.create_server(port, 4) == OK:
			_peers.append(s)
			return [s, port]
	t.expect(false, "Kein freier Port in %d..%d" % [PORT_FIRST, PORT_LAST])
	return []


func _client(port: int) -> ENetMultiplayerPeer:
	var c := ENetMultiplayerPeer.new()
	var err := c.create_client("127.0.0.1", port)
	t.expect(err == OK, "create_client fehlgeschlagen: %d" % err)
	_peers.append(c)
	return c


# Ruft cond wiederholt auf (cond pollt selbst), harte Obergrenze, nie haengen.
func _wait(cond: Callable, what: String) -> bool:
	for i in MAX_ITER:
		if cond.call():
			return true
		OS.delay_msec(3)
	t.expect(false, "Zeitueberschreitung beim Warten auf: " + what)
	return false


func _raw_poll() -> void:
	for p in _peers:
		if p.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			p.poll()


func _connected(c: ENetMultiplayerPeer) -> bool:
	return c.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# Tische zuerst freigeben, dann alle Peers schliessen.
func _teardown() -> void:
	for tb in _tables:
		if is_instance_valid(tb):
			if tb.get_parent() != null:
				tb.get_parent().remove_child(tb)
			tb.free()
	_tables.clear()
	for p in _peers:
		p.close()
	_peers.clear()
	host_table = null
	guest_table = null
	guest = null
	server_link = null
	client_link = null


func _config(seed: int) -> Dictionary:
	return {"seed": seed, "seat_count": 3, "ai_seats": [AI_SEAT], "difficulties": {AI_SEAT: "medium"}, "names": ["Host", "Gast", "KI"]}


func _new_table():
	var tb = TableScene.instantiate()
	tb.instant_ai = true
	tb.settings_override = {"memory_aid": true, "turn_timer": false, "animations": false}
	_tables.append(tb)
	return tb


# Verbindung, Host-Tisch im Online-Host-Modus, Gast-Tisch nach hello. false = abgebrochen.
func _open(seed: int, via_app: bool = false) -> bool:
	guest_results = []
	var sv: Array = _server()
	if sv.is_empty():
		return false
	server = sv[0]
	client = _client(int(sv[1]))
	server_link = PeerLink.new(server)
	client_link = PeerLink.new(client)
	var joined: Array = []
	server_link.peer_connected.connect(func(id): joined.append(id))
	if not _wait(func():
		_raw_poll()
		return _connected(client) and not joined.is_empty(), "Verbindung"):
		return false
	gid = client.get_unique_id()
	var job := {"config": _config(seed), "link": server_link, "host_seat": HOST_SEAT, "guest_seats": {gid: GUEST_SEAT}}
	host_table = _new_table()
	if via_app:
		app.online_host_match(job)
		t.expect(str(app.last_goto) == app.TABLE, "Online-Host: App wechselt nicht zum Tisch")
	else:
		host_table.pending_online_host = job
	t.root.add_child(host_table)
	if via_app:
		t.expect(app.pending.is_empty(), "Online-Host: Auftrag bleibt in App liegen")
	if host_table.session == null or host_table.session.link != server_link:
		t.expect(false, "Host-Tisch laeuft nicht ueber den uebergebenen Link")
		return false
	t.expect(host_table.rules != null and host_table.session.is_authority(), "Host-Tisch ist keine Autoritaet")
	t.expect(not host_table.is_hotseat(), "Online-Host-Tisch ist Hot-Seat")
	t.expect(host_table.local_seats == [HOST_SEAT] and host_table.viewer_seat == HOST_SEAT, "Host-Tisch falscher Platz: %s / %d" % [str(host_table.local_seats), host_table.viewer_seat])
	t.expect(host_table.session.seat_of(Protocol.HOST_PEER) == HOST_SEAT, "HOST_PEER nicht auf host_seat")
	# Gast-Sitz erst nach hello, nie beim Tischstart.
	t.expect(host_table.session.seat_of(gid) == -1, "Gast-Sitz schon vor hello vergeben")
	host_table.session.poll()
	t.expect(host_table.session.seat_of(gid) == -1, "Gast-Sitz ohne hello vergeben")
	guest = DameGuest.new(client_link)
	guest.action_result.connect(func(r): guest_results.append(r))
	guest.connect_to_host()
	if not _wait(func():
		host_table.session.poll()
		guest.poll()
		return not guest.latest_view.is_empty(), "erste Gast-Sicht"):
		return false
	t.expect(host_table.session.seat_of(gid) == GUEST_SEAT, "Gast-Sitz nach hello nicht vergeben")
	t.expect(int(guest.latest_view.viewer_seat) == GUEST_SEAT, "Gast-Sicht falscher Platz")
	guest_table = _new_table()
	if via_app:
		app.online_guest_match(guest)
		t.expect(str(app.last_goto) == app.TABLE, "Online-Gast: App wechselt nicht zum Tisch")
	else:
		guest_table.pending_session = guest
	t.root.add_child(guest_table)
	if via_app:
		t.expect(app.pending.is_empty(), "Online-Gast: Auftrag bleibt in App liegen")
	if guest_table.session != guest or guest_table._view.is_empty():
		t.expect(false, "Gast-Tisch ohne Gast-Session oder Sicht")
		return false
	t.expect(guest_table.rules == null, "Gast-Tisch hat Regeln")
	# Pause-Text online an beiden Tischen.
	t.expect(host_table._pause_menu_button.text == PAUSE_ONLINE, "Host-Pause-Text online: " + host_table._pause_menu_button.text)
	t.expect(guest_table._pause_menu_button.text == PAUSE_ONLINE, "Gast-Pause-Text online: " + guest_table._pause_menu_button.text)
	return true


# Bis der Gast alle Sichten des Hosts hat und kein Ergebnis mehr aussteht.
func _sync() -> bool:
	return _wait(func():
		host_table.session.poll()
		guest_table.session.poll()
		return guest.rev == host_table.session.rev and not guest_table._awaiting_result, "Gast holt Host ein")


func _key(tb, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	tb._unhandled_input(ev)


func _phase() -> String:
	return str(host_table.rules.state.phase)


# Gesichter (2D-Proxy und Sicht) nur fuer Karten, die die Sicht als known fuehrt.
func _hidden_faces_shown(tb) -> int:
	var n := 0
	var view: Dictionary = tb._view
	if view.is_empty():
		return 0
	for seat in range(int(view.seat_count)):
		var cards: Array = view.players[seat].cards
		for i in range(cards.size()):
			if not bool(cards[i].known) and tb._face_for(seat, i, cards[i]):
				n += 1
		for cv in tb._seats[seat].cards():
			var i := int(cv.index)
			if cv.shows_face() and (i < 0 or i >= cards.size() or not bool(cards[i].known)):
				n += 1
	var drawn = view.drawn
	if drawn != null and not bool(drawn.known) and tb._drawn_view.shows_face():
		n += 1
	return n


# Ein Schritt der Partie ueber die Eingabeschicht. false = keine Bewegung moeglich.
func _step(rng: RandomNumberGenerator, lock_checked: Array) -> bool:
	var phase := _phase()
	if phase == "round_end":
		_key(host_table, KEY_ENTER)
		return _sync()
	var cur := int(host_table.rules.state.current_index)
	if cur == AI_SEAT:
		host_table.run_ai_until_human()
		return _sync()
	if cur == HOST_SEAT:
		return _table_step(host_table, HOST_SEAT, rng)
	if not lock_checked[0] and str(guest_table._view.turn_step) == "draw" and not bool(guest_table._view.must_take_queen) and int(guest_table._view.deck_count) > 0:
		lock_checked[0] = true
		_check_input_lock()
		return true
	return _table_step(guest_table, GUEST_SEAT, rng)


# Entscheidung der Policy aus der Tisch-Sicht, ausgefuehrt nur ueber Eingaben.
func _table_step(tb, seat: int, rng: RandomNumberGenerator) -> bool:
	if not tb._human_turn():
		t.expect(false, "Tisch %d nicht am Zug, obwohl der Host es sagt" % seat)
		return false
	var before := var_to_str(host_table.rules.state)
	var choice: Dictionary = DamePolicyScript.choose(tb._view, rng)
	_input(tb, seat, choice)
	if not _sync():
		return false
	if seat == GUEST_SEAT:
		guest_inputs += 1
	if var_to_str(host_table.rules.state) != before:
		if seat == GUEST_SEAT:
			input_types[str(choice.type)] = int(input_types.get(str(choice.type), 0)) + 1
		return true
	if seat == GUEST_SEAT:
		fallback_count += 1
	_fallback_input(tb, seat)
	if not _sync():
		return false
	var moved := var_to_str(host_table.rules.state) != before
	t.expect(moved, "Tisch %d kommt nicht weiter (Schritt %s)" % [seat, str(tb._view.turn_step)])
	return moved


func _input(tb, seat: int, action: Dictionary) -> void:
	match str(action.type):
		"draw_deck":
			_key(tb, KEY_SPACE)
		"draw_discard":
			tb._on_discard()
		"swap":
			tb._on_card(seat, int(action.hand_index))
		"discard_drawn":
			_key(tb, KEY_A)
		"discard_extra":
			tb.select(int(action.hand_index))
			_key(tb, KEY_X)
		"look_card":
			tb._on_card(int(action.target_seat), int(action.hand_index))
		"king_swap":
			tb._on_card(seat, int(action.chosen_index))
			tb._on_card(int(action.opponent_seat), int(action.opponent_index))
		"call_dame":
			_key(tb, KEY_D)
		"end_turn":
			if str(tb._view.turn_step) == "extra":
				_key(tb, KEY_ENTER)
			else:
				tb.end_turn()


func _fallback_input(tb, seat: int) -> void:
	var view: Dictionary = tb._view
	match str(view.turn_step):
		"draw":
			if int(view.deck_count) == 0 and int(view.discard_count) == 0:
				tb.end_turn()
			elif bool(view.must_take_queen) or int(view.deck_count) == 0:
				tb._on_discard()
			else:
				tb._on_deck()
		"play":
			tb._on_discard()
		"jack":
			tb._on_card(seat, 0)
		"king":
			tb._on_card(seat, 0)
			for p in view.players:
				if int(p.seat) != seat and not bool(p.locked) and not bool(p.eliminated) and int(p.card_count) > 0:
					tb._on_card(int(p.seat), 0)
					break
		_:
			tb.end_turn()


# Doppelte Eingabe beim Gast: solange ein Ergebnis aussteht, geht nichts raus.
func _check_input_lock() -> void:
	var results_before := guest_results.size()
	var rev_before: int = host_table.session.rev
	var first: Dictionary = guest_table.act({"type": "draw_deck"})
	t.expect(bool(first.get("ok", false)) and bool(first.get("pending", false)), "Gast: erste Eingabe nicht gesendet")
	t.expect(guest_table._awaiting_result, "Gast: keine Eingabesperre nach dem Senden")
	_key(guest_table, KEY_SPACE)
	var second: Dictionary = guest_table.act({"type": "draw_deck"})
	t.expect(not bool(second.get("ok", true)), "Gast: zweite Eingabe trotz Sperre angenommen")
	_sync()
	# Ein paar Runden weiter pollen: es darf kein zweites Ergebnis kommen.
	for i in 10:
		host_table.session.poll()
		guest_table.session.poll()
		OS.delay_msec(2)
	t.expect(guest_results.size() - results_before == 1, "Gast: %d Ergebnisse statt 1 (doppelte Eingabe)" % (guest_results.size() - results_before))
	t.expect(host_table.session.rev == rev_before + 1, "Host bekam mehr als eine Aktion")
	t.expect(not guest_table._awaiting_result, "Gast: Sperre nach Ergebnis nicht geloest")
	t.expect(str(guest_table._view.turn_step) == "play", "Gast: Ziehen kam nicht an")


func _check_no_leaks(counter: Array) -> void:
	counter[0] += _hidden_faces_shown(host_table)
	counter[1] += _hidden_faces_shown(guest_table)
	if int(host_table._view.get("viewer_seat", -1)) != HOST_SEAT:
		counter[2] += 1
	if int(host_table.session.latest_view.get("viewer_seat", -1)) != HOST_SEAT:
		counter[2] += 1


# ---------- Tests ----------

# Ganze Partie bis game_over, dann „Neues Spiel“ online an beiden Tischen.
func _check_full_game(seed: int) -> void:
	if _open(seed):
		_play_full(seed)
	_teardown()


func _play_full(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 3 + 1
	var lock_checked := [false]
	var counter := [0, 0, 0]
	var steps := 0
	var round_ends := 0
	while steps < 3000 and _phase() != "game_over":
		steps += 1
		_check_no_leaks(counter)
		if _phase() == "round_end":
			round_ends += 1
		if not _step(rng, lock_checked):
			break
	_check_no_leaks(counter)
	t.expect(_phase() == "game_over", "Online-Partie endet nicht (Seed %d, %d Schritte)" % [seed, steps])
	t.expect(round_ends > 0, "Testannahme: kein Rundenende (Seed %d)" % seed)
	t.expect(lock_checked[0], "Testannahme: Eingabesperre nie geprueft")
	t.expect(counter[0] == 0, "Host-Tisch zeigt unbekannte Karten (%d)" % counter[0])
	t.expect(counter[1] == 0, "Gast-Tisch zeigt unbekannte Karten (%d)" % counter[1])
	t.expect(counter[2] == 0, "Host-Tisch bekam fremde Sicht (%d)" % counter[2])
	t.expect(str(guest_table._view.phase) == "game_over" and guest_table._over_panel.visible, "Gast-Tisch zeigt kein Spielende")
	t.expect(host_table._over_panel.visible, "Host-Tisch zeigt kein Spielende")
	t.expect(not host_table.is_hotseat(), "Online-Host-Tisch wurde Hot-Seat")
	t.expect(not host_table._owns_save(), "Online-Host besitzt Spielstand")
	if app != null:
		t.expect(not app.saves.has_save(), "Online-Partie hat einen Spielstand geschrieben")
	var expected_online: String = app.ONLINE if ResourceLoader.exists(app.ONLINE) else app.MAIN_MENU
	# „Neues Spiel“ beim Gast: Verbindung zu, zurueck zum Online-Bildschirm.
	var host_session = host_table.session
	var host_seed := int(host_table.config.seed)
	app.last_goto = ""
	guest_table._again_button.pressed.emit()
	t.expect(app.last_goto == expected_online, "Gast: Neues Spiel geht nach '%s'" % app.last_goto)
	t.expect(client.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "Gast: Neues Spiel schliesst die Verbindung nicht")
	t.expect(app.pending.is_empty(), "Gast: Neues Spiel legt einen Auftrag an")
	guest_table._process(0.0)
	# Host: Gast weg, dann „Neues Spiel“ – nie still ein Offline-Spiel.
	_wait(func():
		host_table._process(0.0)
		return host_table.session.seat_of(gid) == -1, "Host merkt Gast-Trennung")
	app.last_goto = ""
	host_table._again_button.pressed.emit()
	t.expect(app.last_goto == expected_online, "Host: Neues Spiel geht nach '%s'" % app.last_goto)
	t.expect(server.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "Host: Neues Spiel schliesst die Verbindung nicht")
	t.expect(app.pending.is_empty(), "Host: Neues Spiel legt einen Auftrag an")
	t.expect(host_table.session == host_session and int(host_table.config.seed) == host_seed, "Host: Neues Spiel startet still eine Offline-Partie")
	host_table._process(0.0)


# Gast verlaesst die Partie mitten im Spiel (Pause -> Hauptmenue): Host laeuft weiter.
func _check_guest_leaves(seed: int) -> void:
	if _open(seed):
		_guest_leaves(seed)
	_teardown()


func _guest_leaves(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lock_checked := [true]
	# Ein paar Zuege spielen, bis der Host am Zug ist.
	var steps := 0
	while steps < 40 and (steps < 8 or int(host_table.rules.state.current_index) != HOST_SEAT or _phase() != "play"):
		steps += 1
		if not _step(rng, lock_checked):
			return
	t.expect(int(host_table.rules.state.current_index) == HOST_SEAT, "Testannahme: Host nicht am Zug")
	app.last_goto = ""
	_key(guest_table, KEY_ESCAPE)
	t.expect(guest_table._pause_panel.visible, "Gast: Pause oeffnet nicht")
	guest_table._pause_menu_button.pressed.emit()
	t.expect(app.last_goto == app.MAIN_MENU, "Gast: Hauptmenue geht nach '%s'" % app.last_goto)
	t.expect(client.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "Gast: Hauptmenue trennt nicht")
	guest_table._process(0.0)
	var left: Array = []
	host_table.session.peer_left.connect(func(id): left.append(id))
	_wait(func():
		host_table._process(0.0)
		return not left.is_empty(), "peer_left auf dem Host")
	t.expect(left.has(gid) and host_table.session.seat_of(gid) == -1, "Host gibt Gast-Platz nicht frei")
	# Host und KI spielen weiter, bis der (abwesende) Gast dran waere.
	var rev_before: int = host_table.session.rev
	var guard := 0
	while guard < 30 and int(host_table.rules.state.current_index) != GUEST_SEAT and _phase() != "game_over":
		guard += 1
		var before := var_to_str(host_table.rules.state)
		if _phase() == "round_end":
			_key(host_table, KEY_ENTER)
		elif int(host_table.rules.state.current_index) == AI_SEAT:
			host_table.run_ai_until_human()
		else:
			var choice: Dictionary = DamePolicyScript.choose(host_table._view, rng)
			_input(host_table, HOST_SEAT, choice)
			if var_to_str(host_table.rules.state) == before:
				_fallback_input(host_table, HOST_SEAT)
		host_table._process(0.0)
		if var_to_str(host_table.rules.state) == before:
			break
	t.expect(host_table.session.rev > rev_before, "Host-Tisch laeuft nach Gast-Trennung nicht weiter")
	t.expect(int(host_table._view.viewer_seat) == HOST_SEAT, "Host-Tisch: fremde Sicht nach Trennung")
	t.expect(host_table.session.link != null and host_table.rules != null, "Host-Tisch verliert Session")


# Host verlaesst die Partie: Gast sieht die Meldung und einen Knopf ins Menue.
func _check_host_leaves(seed: int) -> void:
	if _open(seed):
		_host_leaves(seed)
	_teardown()


func _host_leaves(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lock_checked := [true]
	var steps := 0
	while steps < 6:
		steps += 1
		if not _step(rng, lock_checked):
			return
	t.expect(_phase() != "game_over", "Testannahme: Partie schon vorbei")
	app.last_goto = ""
	_key(host_table, KEY_ESCAPE)
	host_table._pause_menu_button.pressed.emit()
	t.expect(app.last_goto == app.MAIN_MENU, "Host: Hauptmenue geht nach '%s'" % app.last_goto)
	t.expect(server.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED, "Host: Hauptmenue trennt nicht")
	host_table._process(0.0)
	_wait(func():
		guest_table._process(0.0)
		return guest_table._host_left_panel != null and guest_table._host_left_panel.visible, "Gast merkt Host-Trennung")
	if guest_table._host_left_panel == null:
		return
	t.expect(guest_table._host_left_label.text == guest_table.tr(HOST_LEFT_TEXT), "Gast: falsche Meldung: " + guest_table._host_left_label.text)
	# Danach keine Eingaben mehr, kein Pollen eines toten Links.
	var r: Dictionary = guest_table.act({"type": "draw_deck"})
	t.expect(not bool(r.get("ok", true)), "Gast: Eingabe nach Host-Trennung angenommen")
	for i in 3:
		guest_table._process(0.0)
	app.last_goto = ""
	guest_table._host_left_button.pressed.emit()
	t.expect(app.last_goto == app.MAIN_MENU, "Gast: Knopf nach Host-Trennung geht nach '%s'" % app.last_goto)


# Produktiver Weg: App-Auftrag (online_host / online_guest) statt Test-Feldern.
# Am Spielende verlaesst der Host die Partie: Gast zeigt keine „ohne Wertung“-Meldung.
func _check_app_handoff(seed: int) -> void:
	if app == null:
		return
	if _open(seed, true):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var lock_checked := [true]
		var steps := 0
		while steps < 3000 and _phase() != "game_over":
			steps += 1
			if not _step(rng, lock_checked):
				break
		t.expect(_phase() == "game_over", "App-Uebergabe: Partie endet nicht")
		host_table._again_button.pressed.emit()
		var dummy := [0]
		_wait(func():
			guest_table._process(0.0)
			dummy[0] += 1
			return client.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED or dummy[0] > 60, "Gast merkt Ende")
		t.expect(guest_table._host_left_panel == null or not guest_table._host_left_panel.visible, "Gast zeigt 'ohne Wertung' nach Spielende")
	_teardown()


# Offline bleibt der Pause-Text unveraendert.
func _check_offline_pause_label() -> void:
	var tb = _new_table()
	tb.pending_config = {"seed": 5, "seat_count": 2, "ai_seats": [1], "difficulties": {1: "easy"}, "names": ["A", "B"]}
	t.root.add_child(tb)
	t.expect(tb._pause_menu_button.text == "Hauptmenü (Spiel wird gespeichert)", "Offline-Pause-Text geaendert")
	t.expect(tb.session.link == null, "Offline-Tisch hat Link")
	_teardown()
	if app != null:
		app.saves.clear()
