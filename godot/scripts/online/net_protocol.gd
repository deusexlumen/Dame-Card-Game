extends RefCounted
class_name NetProtocol

# Nachrichten zwischen Client und Server ueber WebSocket.
# Client -> Server: JSON-Text. Server -> Client: var_to_bytes (binaer, ohne Objekte).
# Feld "t" ist der Typ. Alles, was vom Client kommt, ist feindlich:
# Groesse begrenzen, Typen pruefen, unbekannte Felder verwerfen.

const VERSION := 1
const DEFAULT_PORT := 8910
const MAX_MESSAGE_BYTES := 4096
const MAX_MESSAGES_PER_SECOND := 30

# Client -> Server
const CLIENT_TYPES := ["hello", "create", "join", "rejoin", "seat_ai", "start", "action", "ready_next", "presence", "leave", "ping"]
# Erlaubte Felder einer Spielaktion, alle ganzzahlig ausser "type".
const ACTION_INT_FIELDS := ["hand_index", "target_seat", "opponent_seat", "opponent_index", "chosen_index"]


static func encode(msg: Dictionary) -> String:
	return JSON.stringify(msg)


# Server -> Client. bytes_to_var erlaubt keine Objekte, nur Daten.
static func decode_server(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > (1 << 20):
		return {}
	var data = bytes_to_var(bytes)
	return data if typeof(data) == TYPE_DICTIONARY else {}


# Gibt {} zurueck, wenn die Nachricht ungueltig ist.
static func decode_client(text: String) -> Dictionary:
	if text.length() > MAX_MESSAGE_BYTES:
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var t := str(data.get("t", ""))
	if not CLIENT_TYPES.has(t):
		return {}
	var out := {"t": t}
	match t:
		"hello":
			out.v = _int(data.get("v", 0))
		"create":
			out.name = _str(data.get("name", ""), 32)
			out.seat_count = clampi(_int(data.get("seat_count", 4)), 2, 6)
			out.turn_seconds = _int(data.get("turn_seconds", 30))
		"join":
			out.code = _str(data.get("code", ""), 8).to_upper()
			out.name = _str(data.get("name", ""), 32)
		"rejoin":
			out.code = _str(data.get("code", ""), 8).to_upper()
			out.token = _str(data.get("token", ""), 64)
		"seat_ai":
			out.seat = _int(data.get("seat", -1))
			out.ai = bool(data.get("ai", false))
			out.difficulty = _str(data.get("difficulty", "medium"), 8)
		"action":
			var raw = data.get("action", null)
			if typeof(raw) != TYPE_DICTIONARY:
				return {}
			out.action = clean_action(raw)
		"presence":
			out.present = bool(data.get("present", true))
	return out


static func clean_action(raw: Dictionary) -> Dictionary:
	var action := {"type": _str(raw.get("type", ""), 24)}
	for key in ACTION_INT_FIELDS:
		if raw.has(key):
			action[key] = _int(raw[key])
	return action


static func _int(value) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return -1


static func _str(value, limit: int) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	return str(value).substr(0, limit)
