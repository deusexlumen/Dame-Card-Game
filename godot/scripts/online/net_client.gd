extends Node
class_name NetClient

# Verbindung zum Online-Server. Lebt im Autoload App, damit sie den Szenenwechsel
# von der Lobby zum Tisch uebersteht. Haelt keinen Spielzustand, nur die letzte
# empfangene Nachricht. Wiedereinstieg: Code und Token liegen in user://.

const Proto = preload("res://scripts/online/net_protocol.gd")
const SESSION_FILE := "user://online_session.json"
const RECONNECT_DELAYS := [1.0, 2.0, 3.0, 5.0, 5.0, 10.0]

signal connected
signal disconnected
signal welcome(info: Dictionary)
signal lobby(info: Dictionary)
signal state(seat: int, mirror: Dictionary, meta: Dictionary)
signal failed(reason: String)

var url := ""
var code := ""
var token := ""
var seat := -1
var is_host := false
var last_state: Dictionary = {}
var last_lobby: Dictionary = {}

var _ws: WebSocketPeer = null
var _was_open := false
var _retry := 0
var _retry_wait := -1.0
var _queue: Array = []
var session_file := SESSION_FILE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


static func default_url() -> String:
	var configured := str(ProjectSettings.get_setting("dame/online/server_url", ""))
	if configured != "":
		return configured
	return "ws://127.0.0.1:%d" % Proto.DEFAULT_PORT


func is_open() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func in_room() -> bool:
	return code != "" and token != ""


func connect_to(server_url: String) -> void:
	url = server_url
	_retry = 0
	_open()


func close() -> void:
	_retry_wait = -1.0
	if _ws != null:
		_ws.close()
	_ws = null
	_was_open = false


# ---------------------------------------------------------------- Befehle

func create_room(name: String, seat_count: int, turn_seconds: int) -> void:
	_send({"t": "create", "name": name, "seat_count": seat_count, "turn_seconds": turn_seconds})


func join_room(room_code: String, name: String) -> void:
	_send({"t": "join", "code": room_code, "name": name})


func rejoin() -> void:
	if in_room():
		_send({"t": "rejoin", "code": code, "token": token})


func set_seat_ai(target_seat: int, ai: bool, difficulty: String = "medium") -> void:
	_send({"t": "seat_ai", "seat": target_seat, "ai": ai, "difficulty": difficulty})


func start_match() -> void:
	_send({"t": "start"})


func send_action(action: Dictionary) -> void:
	_send({"t": "action", "action": Proto.clean_action(action)})


func ready_next() -> void:
	_send({"t": "ready_next"})


func set_present(present: bool) -> void:
	_send({"t": "presence", "present": present})


func leave() -> void:
	_send({"t": "leave"})
	code = ""
	token = ""
	seat = -1
	last_state = {}
	last_lobby = {}
	_clear_session()


# ---------------------------------------------------------------- Sitzung

func load_session() -> Dictionary:
	if not FileAccess.file_exists(session_file):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(session_file))
	return data if typeof(data) == TYPE_DICTIONARY else {}


func resume_saved() -> bool:
	var s := load_session()
	if str(s.get("code", "")) == "" or str(s.get("token", "")) == "":
		return false
	code = str(s.code)
	token = str(s.token)
	connect_to(str(s.get("url", default_url())))
	return true


func _save_session() -> void:
	var f := FileAccess.open(session_file, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"url": url, "code": code, "token": token}))


func _clear_session() -> void:
	if FileAccess.file_exists(session_file):
		DirAccess.remove_absolute(session_file)


# ---------------------------------------------------------------- Netz

func _open() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_was_open = false
	var err := _ws.connect_to_url(url)
	if err != OK:
		failed.emit("Server nicht erreichbar")
		_schedule_retry()


func _process(delta: float) -> void:
	if _retry_wait >= 0.0:
		_retry_wait -= delta
		if _retry_wait < 0.0:
			_open()
		return
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			_retry = 0
			_ws.send_text(Proto.encode({"t": "hello", "v": Proto.VERSION}))
			connected.emit()
			# Nach Verbindungsabbruch automatisch zurueck an den Platz (§11).
			if in_room():
				rejoin()
			for msg in _queue:
				_ws.send_text(Proto.encode(msg))
			_queue.clear()
		while _ws.get_available_packet_count() > 0:
			var msg := Proto.decode_server(_ws.get_packet())
			if not msg.is_empty():
				_on_message(msg)
	elif st == WebSocketPeer.STATE_CLOSED:
		var had := _was_open
		_ws = null
		_was_open = false
		if had:
			disconnected.emit()
		_schedule_retry()


func _schedule_retry() -> void:
	if url == "":
		return
	_retry_wait = float(RECONNECT_DELAYS[mini(_retry, RECONNECT_DELAYS.size() - 1)])
	_retry += 1


func _on_message(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"welcome":
			code = str(msg.code)
			token = str(msg.token)
			seat = int(msg.seat)
			is_host = bool(msg.host)
			_save_session()
			welcome.emit(msg)
		"lobby":
			last_lobby = msg
			lobby.emit(msg)
		"state":
			last_state = msg
			seat = int(msg.seat)
			state.emit(int(msg.seat), msg.mirror, msg.meta)
		"error":
			var reason := str(msg.get("reason", "Fehler"))
			if reason == "Platz verloren: zu lange weg" or reason == "Code unbekannt" or reason == "Platz unbekannt":
				if in_room() and last_state.is_empty() and last_lobby.is_empty():
					code = ""
					token = ""
					_clear_session()
			failed.emit(reason)


func _send(msg: Dictionary) -> void:
	if is_open():
		_ws.send_text(Proto.encode(msg))
	else:
		_queue.append(msg)
