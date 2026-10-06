extends Node
class_name NetServer

# Headless-Server fuer Online-Partien. Start:
#   godot --headless --path godot res://scenes/server.tscn -- --port=8910
# Nimmt WebSocket-Verbindungen an (Browser und Desktop), reicht Nachrichten an den
# RoomManager und schickt jedem Spieler nur seinen geschwaerzten Zustand (DameMirror).
# TLS (wss://) uebernimmt ein Reverse-Proxy davor (siehe server/README.md).

const RoomManagerScript = preload("res://scripts/online/room_manager.gd")
const Proto = preload("res://scripts/online/net_protocol.gd")

signal started(port: int)

var port := Proto.DEFAULT_PORT
var rooms = RoomManagerScript.new()
var _tcp := TCPServer.new()
var _conns: Dictionary = {}    # id -> {ws, code, token, budget}
var _next_id := 1
var _running := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.substr(7))
	if get_tree().current_scene == self:
		listen(port)


func listen(p: int) -> bool:
	port = p
	var err := _tcp.listen(port, "*")
	if err != OK:
		push_error("NetServer: Port %d nicht verfuegbar (%d)" % [port, err])
		return false
	_running = true
	print("DAME_SERVER_LISTENING port=%d" % port)
	started.emit(port)
	return true


func stop() -> void:
	for id in _conns.keys():
		_conns[id].ws.close()
	_conns.clear()
	_tcp.stop()
	_running = false


func _process(delta: float) -> void:
	if not _running:
		return
	while _tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.outbound_buffer_size = 1 << 20
		if ws.accept_stream(_tcp.take_connection()) == OK:
			_conns[_next_id] = {"ws": ws, "code": "", "token": "", "budget": float(Proto.MAX_MESSAGES_PER_SECOND)}
			_next_id += 1
	for id in _conns.keys():
		_poll(id, delta)
	for code in rooms.tick(delta):
		_push_state(code)


func _poll(id: int, delta: float) -> void:
	var c: Dictionary = _conns[id]
	var ws: WebSocketPeer = c.ws
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		if c.code != "":
			rooms.set_present(c.code, c.token, false)
			_push_state(c.code)
		_conns.erase(id)
		return
	if st != WebSocketPeer.STATE_OPEN:
		return
	c.budget = minf(float(c.budget) + delta * Proto.MAX_MESSAGES_PER_SECOND, float(Proto.MAX_MESSAGES_PER_SECOND))
	while ws.get_available_packet_count() > 0:
		var text := ws.get_packet().get_string_from_utf8()
		c.budget = float(c.budget) - 1.0
		if float(c.budget) < 0.0:
			ws.close(1008, "zu viele Nachrichten")
			return
		var msg := Proto.decode_client(text)
		if msg.is_empty():
			_send(id, {"t": "error", "reason": "Ungültige Nachricht"})
			continue
		_handle(id, msg)


func _handle(id: int, msg: Dictionary) -> void:
	var c: Dictionary = _conns[id]
	match str(msg.t):
		"hello":
			_send(id, {"t": "hello", "v": Proto.VERSION})
		"ping":
			_send(id, {"t": "pong"})
		"create":
			_bind(id, rooms.create(msg.name, msg))
		"join":
			_bind(id, rooms.join(msg.code, msg.name))
		"rejoin":
			_bind(id, rooms.rejoin(msg.code, msg.token))
		"seat_ai":
			_reply_or_lobby(id, rooms.set_seat_ai(c.code, c.token, msg.seat, msg.ai, msg.difficulty))
		"start":
			var r: Dictionary = rooms.start(c.code, c.token)
			if not bool(r.ok):
				_send(id, {"t": "error", "reason": r.reason})
				return
			# Alle schon verbundenen Spieler des Raums sind anwesend.
			for other in _conns.keys():
				if _conns[other].code == c.code:
					rooms.set_present(c.code, _conns[other].token, true)
			_push_state(c.code)
		"action":
			_reply_or_state(id, rooms.action(c.code, c.token, msg.action))
		"ready_next":
			_reply_or_state(id, rooms.action(c.code, c.token, {"type": "ready_next"}))
		"presence":
			rooms.set_present(c.code, c.token, bool(msg.present))
			_push_state(c.code)
		"leave":
			var code: String = c.code
			rooms.leave(code, c.token)
			c.code = ""
			c.token = ""
			_push_lobby(code)
			_push_state(code)


func _bind(id: int, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_send(id, {"t": "error", "reason": str(result.get("reason", "Fehler"))})
		return
	var c: Dictionary = _conns[id]
	# Dasselbe Token auf einer alten Verbindung: alte Verbindung abloesen.
	for other in _conns.keys():
		if other != id and _conns[other].token == result.token:
			_conns[other].code = ""
			_conns[other].token = ""
			_conns[other].ws.close(4000, "an anderer Stelle verbunden")
	c.code = str(result.code)
	c.token = str(result.token)
	_send(id, {"t": "welcome", "code": c.code, "seat": int(result.seat), "token": c.token, "host": bool(result.host)})
	var room = rooms.rooms.get(c.code, null)
	if room != null and room.match != null:
		_push_state(c.code)
	else:
		_push_lobby(c.code)


func _reply_or_lobby(id: int, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_send(id, {"t": "error", "reason": str(result.get("reason", "Fehler"))})
		return
	_push_lobby(_conns[id].code)


func _reply_or_state(id: int, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_send(id, {"t": "error", "reason": str(result.get("reason", "Fehler"))})
	_push_state(_conns[id].code)


func _push_lobby(code: String) -> void:
	var info := rooms.lobby_info(code)
	if info.is_empty():
		return
	for id in _conns.keys():
		if _conns[id].code == code:
			var msg := info.duplicate(true)
			msg.t = "lobby"
			_send(id, msg)


func _push_state(code: String) -> void:
	var room = rooms.rooms.get(code, null)
	if room == null or room.match == null:
		return
	var meta: Dictionary = room.match.meta()
	for id in _conns.keys():
		var c: Dictionary = _conns[id]
		if c.code != code:
			continue
		var seat: int = rooms.seat_of(room, c.token)
		if seat < 0:
			continue
		_send(id, {"t": "state", "seat": seat, "mirror": room.match.mirror_for(seat), "meta": meta})


func _send(id: int, msg: Dictionary) -> void:
	var c = _conns.get(id, null)
	if c == null or c.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	# Server -> Client binaer (var_to_bytes): Zahlentypen bleiben exakt, keine Objekte.
	c.ws.send(var_to_bytes(msg), WebSocketPeer.WRITE_MODE_BINARY)
