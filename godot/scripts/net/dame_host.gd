extends RefCounted

# Autoritativer Host fuer Online-Partien ohne Server. Ein Spieler fuehrt die
# Regeln aus; Gaeste schicken nur Aktionen und bekommen ihre eigene DameView.
# Der Host-Spieler geht ueber denselben Weg wie ein Gast (submit), damit sich
# beide nie unterschiedlich verhalten. Kein Node, kein Szenenbaum.

const Protocol = preload("res://scripts/net/net_protocol.gd")
const Codec = preload("res://scripts/net/net_codec.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")

signal view_changed(view: Dictionary, action: Dictionary)
signal action_result(result: Dictionary)
# Presence-Haken fuer die Abwesenheitsstufen (CONCEPT_DECISIONS §11), Logik folgt spaeter.
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

var rules
var link
var seat_of_peer := {}
var rev := 0
var latest_view: Dictionary = {}
# Plaetze, die an diesem Geraet gespielt werden.
var local_seats: Array = []


# link darf null sein: dann spielt nur der Host-Spieler (lokal).
func _init(match_rules, net_link = null) -> void:
	rules = match_rules
	link = net_link


func is_authority() -> bool:
	return true


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


# Ein KI-Schritt auf dem Host; die angenommene Aktion geht mit der Sicht raus.
func ai_step(ai) -> Dictionary:
	var seat := int(rules.state.current_index)
	var res: Dictionary = ai.step(rules)
	if bool(res.get("ok", false)):
		_dispatch(_broadcast(Protocol.public_action(ai.last_action, seat)))
	return res


# Zeit abgelaufen: genau eine Strafkarte, dann sichere Ersatzaktionen bis Zugende.
func timeout_turn(ai) -> Dictionary:
	var seat := int(rules.state.current_index)
	var pen: Dictionary = rules.apply_action({"type": "timeout_penalty", "seat": seat})
	if not bool(pen.get("ok", false)):
		return {"ok": false, "penalty": false}
	_dispatch(_broadcast({"type": "timeout_penalty", "seat": seat}))
	var guard := 0
	while guard < 8 and int(rules.state.current_index) == seat:
		var phase := str(rules.state.phase)
		if phase != "play" and phase != "dame_called":
			break
		guard += 1
		var fallback: Dictionary = ai.fallback_action(rules, seat)
		if not bool(rules.apply_action(fallback).get("ok", false)):
			break
		_dispatch(_broadcast(Protocol.public_action(fallback, seat)))
	return {"ok": true, "penalty": bool(pen.get("penalty", false))}


# Naechste Runde starten (nur der Host).
func next_round() -> Dictionary:
	var res: Dictionary = rules.apply_action({"type": "start_next_round"})
	if bool(res.get("ok", false)):
		_dispatch(_broadcast({"type": "start_next_round", "seat": -1}))
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
		out.append_array(_broadcast(Protocol.public_action(action, seat)))
	return out


func _broadcast(action: Dictionary = {}) -> Array:
	rev += 1
	var out: Array = []
	for peer in seat_of_peer:
		var view: Dictionary = DameViewScript.for_viewer(rules, int(seat_of_peer[peer]))
		out.append({"to": int(peer), "msg": {"t": "view", "rev": rev, "view": view, "action": action}})
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
			view_changed.emit(latest_view, msg.get("action", {}))
		"result":
			action_result.emit(msg)
