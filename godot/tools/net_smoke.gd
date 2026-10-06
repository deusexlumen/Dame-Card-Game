extends SceneTree

# Echte Verbindung ueber localhost: Server + drei Clients in einem Prozess.
# Lobby, Start, Zuege, Spiegel ohne verdeckte Karten, Abbruch + Wiedereinstieg,
# echter Tisch (table.tscn) im Online-Modus mit dem Client aus dem Autoload App.
# Aufruf: godot --headless --path godot --script res://tools/net_smoke.gd

const NetServerScript = preload("res://scripts/online/net_server.gd")
const NetClientScript = preload("res://scripts/online/net_client.gd")
const PORT := 18911

var server
var a
var b
var c
var _step := 0
var _frames := 0
var _fail := ""
var _errors: Array = []
var table

func _initialize() -> void:
	root.get_node("App").use_test_storage()
	server = NetServerScript.new()
	root.add_child(server)
	if not server.listen(PORT):
		_abort("Server startet nicht")
		return
	# Client a ist der Dienst aus App: so laeuft der Tisch genau wie im Spiel.
	a = root.get_node("App").net()
	a.failed.connect(func(reason): _errors.append("a: %s" % reason))
	b = _client("b")
	c = _client("c")
	a.connect_to("ws://127.0.0.1:%d" % PORT)


func _client(tag: String):
	var cl = NetClientScript.new()
	cl.session_file = "user://test_online_%s.json" % tag
	cl.failed.connect(func(reason): _errors.append("%s: %s" % [tag, reason]))
	root.add_child(cl)
	return cl


func _process(_delta: float) -> bool:
	if _fail != "":
		return true
	_frames += 1
	if _frames > 3000:
		return _abort("Zeitlimit in Schritt %d" % _step)
	match _step:
		0:
			if a.is_open():
				a.create_room("Anna", 3, 30)
				_step = 1
		1:
			if a.code != "" and not a.last_lobby.is_empty():
				b.connect_to(a.url)
				b.join_room(a.code.to_lower(), "Ben<script>")
				_step = 2
		2:
			if b.seat == 1 and _lobby_humans(a.last_lobby) == 2:
				if str(a.last_lobby.seats[1].name).contains("<"):
					return _abort("Name nicht bereinigt")
				b.start_match()
				_step = 3
		3:
			# Nur der Gastgeber darf starten.
			if _errors.any(func(e): return str(e).begins_with("b: Nur der Gastgeber")):
				a.set_seat_ai(2, true, "easy")
				a.start_match()
				_step = 4
		4:
			if not a.last_state.is_empty() and not b.last_state.is_empty():
				if not _check_mirror(a.last_state, 0) or not _check_mirror(b.last_state, 1):
					return true
				var cur := int(a.last_state.mirror.current_index)
				var who = a if cur == 0 else b
				who.send_action({"type": "draw_deck", "seat": 2})
				_step = 5
		5:
			var st: Dictionary = a.last_state
			if not st.is_empty() and str(st.mirror.turn_step) == "play":
				# Platz 1 trennt die Verbindung und kommt mit Token zurueck.
				b.close()
				_step = 6
				_frames = 0
		6:
			if _frames > 30 and _seat_present(a.last_state, 1) == false:
				c.session_file = b.session_file
				if not c.resume_saved():
					return _abort("Sitzung nicht gespeichert")
				_step = 7
		7:
			if c.seat == 1 and _seat_present(a.last_state, 1) == true and not c.last_state.is_empty():
				if not _check_mirror(c.last_state, 1):
					return true
				var app = root.get_node("App")
				app.pending = {"mode": "online"}
				table = load("res://scenes/table.tscn").instantiate()
				table.settings_override = {"animations": false, "table_3d": false}
				root.add_child(table)
				_step = 8
				_frames = 0
		8:
			if not (table.online and table.rules != null and table.viewer_seat == 0):
				return false
			if table.rules.state.deck.size() > 0 and not str(table.rules.state.deck[0].id).begins_with("x-"):
				return _abort("Tisch haelt echte Stapelkarten")
			if _frames % 10 != 0:
				return false
			var st: Dictionary = table.rules.state
			if int(st.current_index) == 1:
				_drive_remote(c, str(st.turn_step))
			else:
				# Platz 0 spielt seinen Zug ueber den Tisch zu Ende.
				if str(st.turn_step) == "draw":
					table._on_deck()
				_step = 9
		9:
			var st: Dictionary = table.rules.state
			if _frames % 10 != 0 or int(st.current_index) != 0:
				return false
			match str(st.turn_step):
				"play":
					if st.drawn_card == null or str(st.drawn_card.id).begins_with("x-"):
						return _abort("Eigene gezogene Karte am Tisch verdeckt")
					table._on_drawn()
				"jack":
					table._on_card(1, 0)
				"king":
					table._on_card(0, 0)
					table._on_card(1, 0)
				"extra":
					table.end_turn()
					_step = 10
		10:
			if int(table.rules.state.current_index) == 1:
				print("NET_OK")
				server.stop()
				quit(0)
				return true
	return false


# Gegenspieler (Platz 1) spielt einfach weiter, damit Platz 0 drankommt.
func _drive_remote(cl, step: String) -> void:
	match step:
		"draw":
			cl.send_action({"type": "draw_deck"})
		"play":
			cl.send_action({"type": "discard_drawn"})
		"jack":
			cl.send_action({"type": "look_card", "target_seat": 0, "hand_index": 0})
		"king":
			cl.send_action({"type": "king_swap", "opponent_seat": 0, "opponent_index": 0, "chosen_index": 0})
		"extra":
			cl.send_action({"type": "end_turn"})


func _lobby_humans(info: Dictionary) -> int:
	var n := 0
	for s in info.get("seats", []):
		if str(s.kind) == "human":
			n += 1
	return n


func _seat_present(st: Dictionary, seat: int):
	if st.is_empty():
		return null
	return bool(st.meta.seats[seat].present)


func _check_mirror(st: Dictionary, seat: int) -> bool:
	var m: Dictionary = st.mirror
	if int(st.seat) != seat:
		return not _abort("Falscher Platz im Zustand")
	if int(m.seed) != 0:
		return not _abort("Seed beim Client")
	for p in m.players:
		if int(p.seat) != seat and not p.known.is_empty():
			return not _abort("Fremdes Gedaechtnis beim Client")
		for i in range(p.hand.size()):
			var card: Dictionary = p.hand[i]
			var own := int(p.seat) == seat
			var allowed: bool = bool(card.face_up) or (own and p.known.has(i))
			if not allowed and not str(card.id).begins_with("x-"):
				return not _abort("Verdeckte Karte %s beim Client" % str(card.id))
	for card in m.deck:
		if not str(card.id).begins_with("x-"):
			return not _abort("Stapelkarte beim Client")
	return true


func _abort(reason: String) -> bool:
	_fail = reason
	print("NET_FAIL ", reason, " errors=", _errors)
	if server != null:
		server.stop()
	quit(1)
	return true
