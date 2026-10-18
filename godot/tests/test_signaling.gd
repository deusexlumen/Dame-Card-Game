extends RefCounted

# Raumcode-Signaling: Frames und ein kleiner Phoenix-Nachbau im selben Prozess
# (TCPServer + WebSocketPeer.accept_stream). Das echte Supabase wird hier nicht erreicht.

const Signaling = preload("res://scripts/net/signaling.gd")

var t
var _server: TCPServer
var _conns: Array = []       # {ws, topic}
var _reject_join := false
var _port := 0


func run(ctx) -> void:
	t = ctx
	_check_room_codes()
	_check_frames()
	_check_parse_hostile()
	_check_exchange()
	_check_rejected()
	_check_unreachable()


func _check_room_codes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 200:
		var c: String = Signaling.new_room_code(rng)
		t.expect(c.length() == 6 and Signaling.normalize_room(c) == c, "Raumcode ungueltig: " + c)
		seen[c] = true
	t.expect(seen.size() > 190, "Raumcodes wiederholen sich zu oft")
	t.expect(Signaling.normalize_room(" k7m2qx ") == "K7M2QX", "Raumcode: Kleinschrift/Leerzeichen")
	for bad in ["", "K7M2Q", "K7M2QXX", "K7M2Q0", "K7M2QI", "K7-2QX", "K7M 2QX"]:
		t.expect(Signaling.normalize_room(bad) == "", "Raumcode '%s' haette abgelehnt werden muessen" % bad)


func _check_frames() -> void:
	var j: Dictionary = JSON.parse_string(Signaling.join_frame("realtime:dame-ABC234", "1"))
	t.expect(j.event == "phx_join" and j.topic == "realtime:dame-ABC234" and j.ref == "1", "join_frame")
	t.expect(bool(j.payload.config.broadcast.has("self")) and j.payload.config.broadcast.self == false, "join: self aus")
	var b: Dictionary = JSON.parse_string(Signaling.broadcast_frame("realtime:dame-ABC234", "2", "1", "invite", {"code": "xyz"}))
	t.expect(b.event == "broadcast" and b.payload.type == "broadcast" and b.payload.event == "invite" and b.payload.payload.code == "xyz", "broadcast_frame")
	var h: Dictionary = JSON.parse_string(Signaling.heartbeat_frame("3"))
	t.expect(h.topic == "phoenix" and h.event == "heartbeat", "heartbeat_frame")


func _check_parse_hostile() -> void:
	var topic := "realtime:dame-ABC234"
	var good := JSON.stringify({"topic": topic, "event": "broadcast", "payload": {"type": "broadcast", "event": "answer", "payload": {"code": "x"}}})
	var p: Dictionary = Signaling.parse_frame(good, topic)
	t.expect(p.kind == "event" and p.name == "answer" and p.payload.code == "x", "parse: gueltiges Broadcast")
	var cases := [
		"", "nicht json", "[]", "null", "5", "{}",
		JSON.stringify({"topic": "anderer", "event": "broadcast", "payload": {"event": "a", "payload": {}}}),
		JSON.stringify({"topic": topic, "event": "broadcast", "payload": {"event": 5, "payload": {}}}),
		JSON.stringify({"topic": topic, "event": "broadcast", "payload": {"event": "", "payload": {}}}),
		JSON.stringify({"topic": topic, "event": "broadcast", "payload": {"event": "a", "payload": "text"}}),
		JSON.stringify({"topic": topic, "event": "broadcast", "payload": "kaputt"}),
		JSON.stringify({"topic": topic, "event": "broadcast", "payload": {"event": "x".repeat(200), "payload": {}}}),
		"x".repeat(Signaling.MAX_FRAME + 1),
	]
	for c in cases:
		t.expect(Signaling.parse_frame(c, topic).kind == "ignore", "parse: Muell wurde nicht ignoriert: " + str(c).left(40))
	t.expect(Signaling.parse_frame(JSON.stringify({"topic": topic, "event": "phx_reply", "payload": {"status": "ok"}}), topic).ok, "parse: reply ok")
	t.expect(not Signaling.parse_frame(JSON.stringify({"topic": topic, "event": "phx_reply", "payload": {"status": "error"}}), topic).ok, "parse: reply error")
	t.expect(Signaling.parse_frame(JSON.stringify({"topic": topic, "event": "phx_error", "payload": {}}), topic).kind == "error", "parse: phx_error")


# ---------- Phoenix-Nachbau ----------

func _start_server() -> bool:
	_server = TCPServer.new()
	for port in range(24700, 24760):
		if _server.listen(port, "127.0.0.1") == OK:
			_port = port
			return true
	return false


func _pump_server() -> void:
	while _server != null and _server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(_server.take_connection())
		_conns.append({"ws": ws, "topic": ""})
	for c in _conns:
		var ws: WebSocketPeer = c.ws
		ws.poll()
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		while ws.get_available_packet_count() > 0:
			var j = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if typeof(j) != TYPE_DICTIONARY:
				continue
			match str(j.event):
				"phx_join":
					c.topic = str(j.topic)
					var status := "error" if _reject_join else "ok"
					ws.send_text(JSON.stringify({"topic": j.topic, "event": "phx_reply", "ref": j.ref, "payload": {"status": status, "response": {}}}))
				"broadcast":
					for other in _conns:
						if other != c and other.topic == c.topic and other.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
							other.ws.send_text(JSON.stringify({"topic": j.topic, "event": "broadcast", "payload": j.payload}))
				"heartbeat":
					ws.send_text(JSON.stringify({"topic": "phoenix", "event": "phx_reply", "ref": j.ref, "payload": {"status": "ok"}}))


func _wait(clients: Array, cond: Callable, what: String) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 5000:
		_pump_server()
		for c in clients:
			c.poll()
		if cond.call():
			return true
		OS.delay_msec(5)
	t.expect(false, "Signaling: Zeitueberschreitung bei " + what)
	return false


func _stop_server() -> void:
	for c in _conns:
		c.ws.close()
	_conns.clear()
	if _server != null:
		_server.stop()
	_server = null
	_reject_join = false


func _client(room: String):
	var s = Signaling.new()
	s.url = "ws://127.0.0.1:%d/websocket" % _port
	s.api_key = ""
	s.open(room)
	return s


func _check_exchange() -> void:
	if not _start_server():
		t.expect(false, "Signaling: kein freier Port")
		return
	var host = _client("ABC234")
	var guest = _client("ABC234")
	var other = _client("ZZZ999")
	var got_host: Array = []
	var got_guest: Array = []
	var got_other: Array = []
	host.event.connect(func(n, p): got_host.append([n, p]))
	guest.event.connect(func(n, p): got_guest.append([n, p]))
	other.event.connect(func(n, p): got_other.append([n, p]))
	if _wait([host, guest, other], func(): return host.is_joined() and guest.is_joined() and other.is_joined(), "Beitritt"):
		t.expect(host.send_event("invite", {"code": "EINLADUNG"}), "Signaling: senden nach Beitritt")
		_wait([host, guest, other], func(): return not got_guest.is_empty(), "Einladung beim Gast")
		t.expect(got_guest.size() == 1 and got_guest[0][0] == "invite" and got_guest[0][1].code == "EINLADUNG", "Signaling: Einladung kommt beim Gast an")
		guest.send_event("answer", {"code": "ANTWORT"})
		_wait([host, guest, other], func(): return not got_host.is_empty(), "Antwort beim Host")
		t.expect(got_host.size() == 1 and got_host[0][0] == "answer" and got_host[0][1].code == "ANTWORT", "Signaling: Antwort kommt beim Host an")
		t.expect(got_other.is_empty(), "Signaling: fremder Raum hoert mit")
		t.expect(got_host.size() == 1 and got_guest.size() == 1, "Signaling: Echo an den Absender")
	host.close()
	guest.close()
	other.close()
	t.expect(not host.send_event("x", {}), "Signaling: senden nach close")
	_stop_server()


func _check_rejected() -> void:
	if not _start_server():
		return
	_reject_join = true
	var c = _client("ABC234")
	var reasons: Array = []
	c.failed.connect(func(r): reasons.append(r))
	_wait([c], func(): return not reasons.is_empty(), "Ablehnung")
	t.expect(reasons.size() == 1 and c.is_closed() and not c.is_joined(), "Signaling: abgelehnter Raum meldet failed genau einmal")
	_stop_server()


func _check_unreachable() -> void:
	# Port, auf dem niemand lauscht.
	var probe := TCPServer.new()
	var free_port := 0
	for port in range(24800, 24860):
		if probe.listen(port, "127.0.0.1") == OK:
			free_port = port
			probe.stop()
			break
	_port = free_port
	var c = _client("ABC234")
	var reasons: Array = []
	c.failed.connect(func(r): reasons.append(r))
	_wait([c], func(): return not reasons.is_empty(), "unerreichbarer Dienst")
	t.expect(reasons.size() == 1 and c.is_closed(), "Signaling: unerreichbar meldet failed genau einmal")
