extends RefCounted
class_name Signaling

# Raumcode-Signaling ueber Supabase Realtime (Phoenix-Channels, JSON v1, Broadcast).
# Der Kanal tauscht nur die Verbindungscodes (Einladung/Antwort) aus; die Partie
# selbst laeuft danach direkt per WebRTC. Kein Node: der Besitzer ruft poll().
#
# Ablauf: open(room) -> joined; send_event(name, payload) -> beim anderen event(name, payload).
# Der Raumcode ist das Geheimnis des Kanals (30^6 Moeglichkeiten, kurzlebig).

const NetConfig = preload("res://scripts/net/net_config.gd")
const I18n = preload("res://scripts/i18n.gd")

signal joined()
signal event(name: String, payload: Dictionary)
signal failed(reason: String)

const ROOM_LEN := 6
# Ohne leicht verwechselbare Zeichen (0/O, 1/I/L).
const ROOM_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const HEARTBEAT_MS := 25000
const JOIN_TIMEOUT_MS := 10000
const MAX_FRAME := 65536
const MAX_EVENT_NAME := 32

const UNREACHABLE_TEXT := "Der Raum-Dienst ist nicht erreichbar."
const REFUSED_TEXT := "Der Raum-Dienst hat den Raum abgelehnt."
const LOST_TEXT := "Verbindung zum Raum-Dienst abgebrochen."

var url := NetConfig.SIGNALING_URL
var api_key := NetConfig.SIGNALING_KEY
var room := ""

var _ws: WebSocketPeer = null
var _topic := ""
var _ref := 0
var _join_ref := ""
var _is_joined := false
var _closed := false
var _heartbeat_at := 0
var _deadline := 0


static func new_room_code(rng: RandomNumberGenerator = null) -> String:
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var out := ""
	for i in ROOM_LEN:
		out += ROOM_CHARS[r.randi_range(0, ROOM_CHARS.length() - 1)]
	return out


# Eingabe putzen: Grossbuchstaben, nur erlaubte Zeichen. Leer = ungueltig.
static func normalize_room(text: String) -> String:
	var up := text.strip_edges().to_upper()
	var out := ""
	for ch in up:
		if ROOM_CHARS.contains(ch):
			out += ch
	return out if out.length() == ROOM_LEN and up.length() == ROOM_LEN else ""


static func topic_for(room_code: String) -> String:
	return "realtime:dame-" + room_code


static func join_frame(topic: String, ref: String) -> String:
	return JSON.stringify({
		"topic": topic, "event": "phx_join", "ref": ref, "join_ref": ref,
		"payload": {"config": {
			"broadcast": {"self": false, "ack": false},
			"presence": {"key": ""},
			"postgres_changes": [],
			"private": false,
		}},
	})


static func broadcast_frame(topic: String, ref: String, join_ref: String, name: String, payload: Dictionary) -> String:
	return JSON.stringify({
		"topic": topic, "event": "broadcast", "ref": ref, "join_ref": join_ref,
		"payload": {"type": "broadcast", "event": name, "payload": payload},
	})


static func heartbeat_frame(ref: String) -> String:
	return JSON.stringify({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": ref})


# Eingehenden Frame auswerten. Liefert {kind: "reply"|"event"|"error"|"ignore", ...}.
# Fremde Daten: nie dem Inhalt trauen, nur Typen und Laengen pruefen.
static func parse_frame(text: String, topic: String) -> Dictionary:
	if text.length() > MAX_FRAME:
		return {"kind": "ignore"}
	var j = JSON.parse_string(text)
	if typeof(j) != TYPE_DICTIONARY:
		return {"kind": "ignore"}
	var ev := str(j.get("event", ""))
	var payload = j.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	if ev == "phx_reply" and str(j.get("topic", "")) == topic:
		return {"kind": "reply", "ok": str(payload.get("status", "")) == "ok"}
	if ev == "phx_error" or ev == "phx_close":
		return {"kind": "error"}
	if ev == "broadcast" and str(j.get("topic", "")) == topic:
		var name = payload.get("event", "")
		var inner = payload.get("payload", {})
		if typeof(name) != TYPE_STRING or (name as String).is_empty() or (name as String).length() > MAX_EVENT_NAME:
			return {"kind": "ignore"}
		if typeof(inner) != TYPE_DICTIONARY:
			return {"kind": "ignore"}
		return {"kind": "event", "name": name, "payload": inner}
	return {"kind": "ignore"}


func is_joined() -> bool:
	return _is_joined


func is_closed() -> bool:
	return _closed


func open(room_code: String) -> bool:
	if _ws != null or _closed or room_code.length() != ROOM_LEN:
		return false
	room = room_code
	_topic = topic_for(room)
	_ws = WebSocketPeer.new()
	var full := url
	if not api_key.is_empty():
		full += ("&" if url.contains("?") else "?") + "apikey=" + api_key + "&vsn=1.0.0"
	if _ws.connect_to_url(full) != OK:
		_fail(I18n.t(UNREACHABLE_TEXT))
		return false
	_deadline = Time.get_ticks_msec() + JOIN_TIMEOUT_MS
	return true


func send_event(name: String, payload: Dictionary) -> bool:
	if not _is_joined or _closed:
		return false
	_send(broadcast_frame(_topic, _next_ref(), _join_ref, name, payload))
	return true


func poll() -> void:
	if _ws == null or _closed:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if _join_ref == "":
				_join_ref = _next_ref()
				_send(join_frame(_topic, _join_ref))
			while _ws != null and not _closed and _ws.get_available_packet_count() > 0:
				_handle(_ws.get_packet().get_string_from_utf8())
			if _is_joined and not _closed and Time.get_ticks_msec() >= _heartbeat_at:
				_heartbeat_at = Time.get_ticks_msec() + HEARTBEAT_MS
				_send(heartbeat_frame(_next_ref()))
			if not _is_joined and not _closed and Time.get_ticks_msec() > _deadline:
				_fail(I18n.t(REFUSED_TEXT))
		WebSocketPeer.STATE_CLOSED:
			_fail(I18n.t(LOST_TEXT if _is_joined else UNREACHABLE_TEXT))
		_:
			if not _is_joined and Time.get_ticks_msec() > _deadline:
				_fail(I18n.t(UNREACHABLE_TEXT))


func close() -> void:
	_closed = true
	_is_joined = false
	if _ws != null:
		_ws.close()
		_ws = null


func _handle(text: String) -> void:
	var f: Dictionary = parse_frame(text, _topic)
	match str(f.kind):
		"reply":
			if not _is_joined:
				if bool(f.ok):
					_is_joined = true
					_heartbeat_at = Time.get_ticks_msec() + HEARTBEAT_MS
					joined.emit()
				else:
					_fail(I18n.t(REFUSED_TEXT))
		"error":
			_fail(I18n.t(LOST_TEXT))
		"event":
			event.emit(str(f.name), f.payload)


func _send(text: String) -> void:
	if _ws != null:
		_ws.send_text(text)


func _next_ref() -> String:
	_ref += 1
	return str(_ref)


func _fail(reason: String) -> void:
	if _closed:
		return
	close()
	failed.emit(reason)
