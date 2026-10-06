extends RefCounted
class_name RoomManager

# Lobby und Raeume auf dem Server. Kein Netzwerk: NetServer reicht Nachrichten herein.
# Ein Raum = ein Code, 2-6 Plaetze, danach eine OnlineMatch.
# Spieler werden ueber ein geheimes Token wiedererkannt (Wiedereinstieg, §11).

const OnlineMatchScript = preload("res://scripts/online/online_match.gd")

const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6
const NAME_MAX := 16
const LOBBY_IDLE_LIMIT := 900.0     # leere oder vergessene Lobbys aufraeumen
const FINISHED_KEEP := 600.0        # beendete Partien noch kurz fuer Ergebnisse halten
const MAX_ROOMS := 500

var rooms: Dictionary = {}
var _crypto := Crypto.new()


func create(name: String, config: Dictionary) -> Dictionary:
	if rooms.size() >= MAX_ROOMS:
		return _fail("Server ist voll")
	var seat_count := clampi(int(config.get("seat_count", 4)), 2, 6)
	var code := _new_code()
	var token := _new_token()
	var seats: Array = []
	for i in range(seat_count):
		seats.append({"kind": "open", "name": "", "token": ""})
	seats[0] = {"kind": "human", "name": clean_name(name, 0), "token": token}
	rooms[code] = {
		"code": code,
		"host_token": token,
		"seat_count": seat_count,
		"turn_seconds": int(config.get("turn_seconds", OnlineMatchScript.DEFAULT_TURN_SECONDS)),
		"seats": seats,
		"match": null,
		"idle": 0.0,
	}
	return {"ok": true, "code": code, "seat": 0, "token": token, "host": true}


func join(code: String, name: String) -> Dictionary:
	var room = rooms.get(code.to_upper(), null)
	if room == null:
		return _fail("Code unbekannt")
	if room.match != null:
		return _fail("Partie läuft schon")
	for i in range(room.seats.size()):
		if str(room.seats[i].kind) == "open":
			var token := _new_token()
			room.seats[i] = {"kind": "human", "name": clean_name(name, i), "token": token}
			room.idle = 0.0
			return {"ok": true, "code": room.code, "seat": i, "token": token, "host": false}
	return _fail("Tisch ist voll")


# Wiedereinstieg mit Token: in der Lobby immer, in der Partie nur bis Stufe 3.
func rejoin(code: String, token: String) -> Dictionary:
	var room = rooms.get(code.to_upper(), null)
	if room == null:
		return _fail("Code unbekannt")
	var seat := seat_of(room, token)
	if seat < 0:
		return _fail("Platz unbekannt")
	if room.match != null:
		if not room.match.can_rejoin(seat):
			return _fail("Platz verloren: zu lange weg")
		room.match.set_present(seat, true)
	return {"ok": true, "code": room.code, "seat": seat, "token": token, "host": token == str(room.host_token)}


# Gastgeber setzt freie Plaetze auf KI oder wieder auf frei.
func set_seat_ai(code: String, token: String, seat: int, ai: bool, difficulty: String = "medium") -> Dictionary:
	var room = rooms.get(code, null)
	if room == null or token != str(room.host_token):
		return _fail("Nur der Gastgeber")
	if room.match != null or seat <= 0 or seat >= room.seats.size():
		return _fail("Platz nicht änderbar")
	var kind := str(room.seats[seat].kind)
	if kind == "human":
		return _fail("Platz ist besetzt")
	if ai:
		var d := difficulty if ["easy", "medium", "hard"].has(difficulty) else "medium"
		room.seats[seat] = {"kind": "ai", "name": "KI %d" % (seat + 1), "token": "", "difficulty": d}
	else:
		room.seats[seat] = {"kind": "open", "name": "", "token": ""}
	return {"ok": true}


# Start: freie Plaetze werden KI. Mindestens zwei Plaetze sind immer da.
func start(code: String, token: String) -> Dictionary:
	var room = rooms.get(code, null)
	if room == null or token != str(room.host_token):
		return _fail("Nur der Gastgeber kann starten")
	if room.match != null:
		return _fail("Partie läuft schon")
	var list: Array = []
	for i in range(room.seats.size()):
		var s: Dictionary = room.seats[i]
		if str(s.kind) == "human":
			list.append({"name": str(s.name), "kind": "human"})
		else:
			list.append({"name": str(s.get("name", "")) if str(s.kind) == "ai" else "KI %d" % (i + 1), "kind": "ai", "difficulty": str(s.get("difficulty", "medium"))})
	room.match = OnlineMatchScript.new({"seats": list, "turn_seconds": int(room.turn_seconds)})
	for i in range(room.seats.size()):
		if str(room.seats[i].kind) == "human":
			room.match.set_present(i, false)
	room.idle = 0.0
	return {"ok": true}


func leave(code: String, token: String) -> void:
	var room = rooms.get(code, null)
	if room == null:
		return
	var seat := seat_of(room, token)
	if seat < 0:
		return
	if room.match == null:
		if token == str(room.host_token):
			rooms.erase(code)
		else:
			room.seats[seat] = {"kind": "open", "name": "", "token": ""}
		return
	room.match.set_present(seat, false)


func set_present(code: String, token: String, present: bool) -> void:
	var room = rooms.get(code, null)
	if room == null or room.match == null:
		return
	var seat := seat_of(room, token)
	if seat >= 0:
		room.match.set_present(seat, present)


func action(code: String, token: String, act: Dictionary) -> Dictionary:
	var room = rooms.get(code, null)
	if room == null or room.match == null:
		return _fail("Keine laufende Partie")
	var seat := seat_of(room, token)
	if seat < 0:
		return _fail("Platz unbekannt")
	return room.match.submit(seat, act)


# Zeit fuer alle Raeume. Gibt die Codes zurueck, deren Clients neu beliefert werden muessen.
func tick(delta: float) -> Array:
	var changed: Array = []
	for code in rooms.keys():
		var room: Dictionary = rooms[code]
		room.idle = float(room.idle) + delta
		if room.match == null:
			if float(room.idle) > LOBBY_IDLE_LIMIT:
				rooms.erase(code)
			continue
		var was_finished: bool = room.match.finished
		if room.match.tick(delta):
			changed.append(code)
			room.idle = 0.0
		if was_finished and float(room.idle) > FINISHED_KEEP:
			rooms.erase(code)
	return changed


func lobby_info(code: String) -> Dictionary:
	var room = rooms.get(code, null)
	if room == null:
		return {}
	var seats: Array = []
	for i in range(room.seats.size()):
		var s: Dictionary = room.seats[i]
		seats.append({"seat": i, "kind": str(s.kind), "name": str(s.name), "difficulty": str(s.get("difficulty", ""))})
	return {"code": code, "seats": seats, "turn_seconds": int(room.turn_seconds), "started": room.match != null}


func seat_of(room: Dictionary, token: String) -> int:
	if token == "":
		return -1
	for i in range(room.seats.size()):
		if str(room.seats[i].token) == token:
			return i
	return -1


static func clean_name(raw: String, seat: int) -> String:
	var out := ""
	for ch in raw.strip_edges():
		if ch.unicode_at(0) >= 32 and ch != "<" and ch != ">":
			out += ch
	out = out.substr(0, NAME_MAX).strip_edges()
	return out if out != "" else "Spieler %d" % (seat + 1)


func _new_code() -> String:
	for _attempt in range(50):
		var bytes := _crypto.generate_random_bytes(CODE_LENGTH)
		var code := ""
		for i in range(CODE_LENGTH):
			code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length()]
		if not rooms.has(code):
			return code
	return "X" + _new_token().substr(0, CODE_LENGTH - 1).to_upper()


func _new_token() -> String:
	return _crypto.generate_random_bytes(16).hex_encode()


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
