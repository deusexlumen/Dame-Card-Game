extends RefCounted

# Autoritativer Host fuer Online-Partien ohne Server. Ein Spieler fuehrt die
# Regeln aus; Gaeste schicken nur Aktionen und bekommen ihre eigene DameView.
# Der Host-Spieler geht ueber denselben Weg wie ein Gast (submit), damit sich
# beide nie unterschiedlich verhalten. Kein Node, kein Szenenbaum.

const Protocol = preload("res://scripts/net/net_protocol.gd")
const Codec = preload("res://scripts/net/net_codec.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")

signal view_changed(view: Dictionary)
signal action_result(result: Dictionary)
# Presence-Haken fuer die Abwesenheitsstufen (CONCEPT_DECISIONS §11), Logik folgt spaeter.
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

var rules
var link
var seat_of_peer := {}
var rev := 0
var latest_view: Dictionary = {}


# link darf null sein: dann spielt nur der Host-Spieler (lokal).
func _init(match_rules, net_link = null) -> void:
	rules = match_rules
	link = net_link


func seat_of(peer_id: int) -> int:
	return int(seat_of_peer.get(peer_id, -1))


func assign_seat(peer_id: int, seat: int) -> void:
	seat_of_peer[peer_id] = seat
	_dispatch(_broadcast())


func remove_peer(peer_id: int) -> void:
	if seat_of_peer.erase(peer_id):
		peer_left.emit(peer_id)


# Aktion des Host-Spielers selbst. Gleiche Schnittstelle wie beim Gast.
func send_action(action: Dictionary) -> void:
	_dispatch(submit(Protocol.HOST_PEER, action))


# Pakete der Gaeste abholen und beantworten.
func poll() -> void:
	if link == null:
		return
	for pkt in link.receive():
		_dispatch(handle_packet(int(pkt.from), pkt.bytes))


# Timer und Rundenwechsel. Nur der Host darf diese Aktionen ausloesen.
func system_action(action: Dictionary) -> Dictionary:
	var type := str(action.get("type", ""))
	if not Protocol.SYSTEM_ACTIONS.has(type):
		return {"ok": false, "reason": "Keine Systemaktion"}
	var clean := {"type": type}
	if type == "timeout_penalty":
		clean.seat = int(rules.state.current_index)
	var res: Dictionary = rules.apply_action(clean)
	if bool(res.get("ok", false)):
		_dispatch(_broadcast())
	return res


# Nach Aenderungen ausserhalb von submit (z. B. KI-Zuege auf dem Host) aufrufen.
func broadcast() -> void:
	_dispatch(_broadcast())


# Reiner Kern: liefert die ausgehenden Nachrichten als [{to, msg}].
func handle_packet(from: int, bytes: PackedByteArray) -> Array:
	var msg := Codec.decode(bytes)
	match str(msg.get("t", "")):
		"hello":
			if int(msg.get("v", -1)) != Protocol.VERSION:
				return [{"to": from, "msg": {"t": "reject", "reason": "Falsche Spielversion"}}]
			peer_joined.emit(from)
			return [{"to": from, "msg": {"t": "welcome", "peer": from}}]
		"action":
			return submit(from, msg.get("action"))
	return []


# Einziger Eingang fuer Spieleraktionen. Der Platz kommt immer aus der
# Zuordnung des Absenders, nie aus der Nachricht.
func submit(peer_id: int, raw) -> Array:
	var seat := seat_of(peer_id)
	if seat < 0:
		return [_result_to(peer_id, false, "Kein Platz am Tisch")]
	if bool(rules.state.players[seat].is_ai):
		return [_result_to(peer_id, false, "Platz wird von der KI gespielt")]
	var action := Protocol.sanitize_action(raw)
	if action.is_empty():
		return [_result_to(peer_id, false, "Ungültige Aktion")]
	action.seat = seat
	var res: Dictionary = rules.apply_action(action)
	var ok := bool(res.get("ok", false))
	var out: Array = [_result_to(peer_id, ok, str(res.get("reason", "")))]
	if ok:
		out.append_array(_broadcast())
	return out


func _broadcast() -> Array:
	rev += 1
	var out: Array = []
	for peer in seat_of_peer:
		var view: Dictionary = DameViewScript.for_viewer(rules, int(seat_of_peer[peer]))
		out.append({"to": int(peer), "msg": {"t": "view", "rev": rev, "view": view}})
	return out


func _result_to(peer_id: int, ok: bool, reason: String) -> Dictionary:
	return {"to": peer_id, "msg": {"t": "result", "ok": ok, "reason": reason}}


func _dispatch(out: Array) -> void:
	for o in out:
		var to := int(o.to)
		if to == Protocol.HOST_PEER:
			_deliver_local(o.msg)
		elif link != null:
			link.send(to, Codec.encode(o.msg))


func _deliver_local(msg: Dictionary) -> void:
	match str(msg.t):
		"view":
			latest_view = msg.view
			view_changed.emit(latest_view)
		"result":
			action_result.emit(msg)
