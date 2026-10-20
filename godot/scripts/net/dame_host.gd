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
# Wiedereintritts-Schluessel je Gast-Peer (geht nur ueber den verschluesselten Datenkanal).
var token_of_peer := {}
# Spielername je Gast-Peer aus dem hello (gesäubert); leer = Platzhalter bleibt.
var name_of_peer := {}
# Abwesenheitsstufe je Platz (siehe DameView.absence_text); geht in jede Sicht.
var absence := {}
var rev := 0
var latest_view: Dictionary = {}
# Plaetze, die an diesem Geraet gespielt werden.
var local_seats: Array = []


# link darf null sein: dann spielt nur der Host-Spieler (lokal).
func _init(match_rules, net_link = null) -> void:
	rules = match_rules
	link = net_link
	# Trennt ein Gast, wird sein Platz freigegeben (peer_left).
	if link != null and link.has_signal("peer_disconnected"):
		link.peer_disconnected.connect(remove_peer)


func is_authority() -> bool:
	return true


func seat_of(peer_id: int) -> int:
	return int(seat_of_peer.get(peer_id, -1))


func assign_seat(peer_id: int, seat: int) -> void:
	seat_of_peer[peer_id] = seat
	_dispatch(_broadcast())


# Namen eines Platzes setzen (Gastname). Doppelte Namen bekommen eine Nummer.
# Ohne announce keine neue Sicht (der Aufrufer schickt gleich eine).
func set_seat_name(seat: int, name: String, announce: bool = true) -> void:
	if name.is_empty() or seat < 0 or seat >= rules.state.players.size():
		return
	var taken := []
	for p in rules.state.players:
		if int(p.seat) != seat:
			taken.append(str(p.name))
	var unique := name
	var n := 2
	while taken.has(unique):
		unique = "%s %d" % [name, n]
		n += 1
	if str(rules.state.players[seat].name) == unique:
		return
	rules.state.players[seat].name = unique
	if announce:
		_dispatch(_broadcast())


# Stufe eines Platzes setzen; bei Aenderung bekommen alle eine neue Sicht.
func set_absence(seat: int, stage: int) -> void:
	if int(absence.get(seat, 0)) == stage:
		return
	if stage == 0:
		absence.erase(seat)
	else:
		absence[seat] = stage
	_dispatch(_broadcast())


func remove_peer(peer_id: int) -> void:
	if seat_of_peer.erase(peer_id):
		peer_left.emit(peer_id)


# Peer zu einem Wiedereintritts-Schluessel, sonst -1.
func peer_of_token(token: String) -> int:
	if token.is_empty():
		return -1
	for peer in token_of_peer:
		if str(token_of_peer[peer]) == token:
			return int(peer)
	return -1


static func new_token() -> String:
	return Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(18))


# Host geht absichtlich: allen Gaesten Bescheid geben (best effort, vor dem Schliessen).
func say_bye() -> void:
	if link == null:
		return
	for peer in seat_of_peer:
		if int(peer) != Protocol.HOST_PEER:
			link.send(int(peer), Codec.encode(Protocol.bye()))


# Aktion des Host-Spielers selbst. Gleiche Schnittstelle wie beim Gast.
func send_action(action: Dictionary) -> void:
	_dispatch(submit(Protocol.HOST_PEER, action))


# Pakete der Gaeste abholen und beantworten.
func poll() -> void:
	if link == null:
		return
	for pkt in link.receive():
		# Die Host-Kennung gehoert nur dem Host selbst: gefaelschte Absender verwerfen.
		if int(pkt.from) == Protocol.HOST_PEER:
			continue
		_dispatch(handle_packet(int(pkt.from), pkt.bytes))


# Ein KI-Schritt auf dem Host; die angenommene Aktion geht mit der Sicht raus.
func ai_step(ai) -> Dictionary:
	var seat := int(rules.state.current_index)
	var before := var_to_str(rules.state)
	var res: Dictionary = ai.step(rules)
	if bool(res.get("ok", false)):
		_dispatch(_broadcast(Protocol.public_action(ai.last_action, seat)))
	elif var_to_str(rules.state) != before:
		# Abgelehnt, aber veraendert (z. B. Strafkarte): neue Sicht ohne Aktion.
		_dispatch(_broadcast())
	return res


# Mitwerfen der KI (ausserhalb des eigenen Zugs). Gibt true zurueck, wenn eine KI etwas geworfen hat.
func ai_react(ai) -> bool:
	var res: Dictionary = ai.react(rules)
	if res.is_empty():
		return false
	var seat := int(res.seat)
	if bool(res.get("ok", false)):
		_dispatch(_broadcast(Protocol.public_action(ai.last_action, seat)))
		return true
	_dispatch(_broadcast())
	return false


func ai_reaction_due(ai) -> bool:
	return ai.reaction_due(rules)


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


# ---- Abwesenheit (CONCEPT_DECISIONS §11) --------------------------------

# Stufe 1: Platz ist weg, die Wartezeit ist um. Vor dem Ziehen aussetzen (keine Strafkarte),
# mitten im Zug neutral zu Ende spielen.
func absent_turn(ai, seat: int) -> Dictionary:
	if int(rules.state.current_index) != seat:
		return {"ok": false}
	if str(rules.state.turn_step) == "draw" and rules.state.drawn_card == null:
		var skip := {"type": "skip_turn", "seat": seat}
		if bool(rules.apply_action(skip).get("ok", false)):
			_dispatch(_broadcast({"type": "skip_turn", "seat": seat}))
			return {"ok": true}
	# Gezogene Dame nicht ablegen (das gaebe eine Strafkarte): eintauschen.
	var drawn = rules.state.drawn_card
	if str(rules.state.turn_step) == "play" and drawn != null and str(drawn.rank) == "Q":
		_apply_public({"type": "swap", "seat": seat, "hand_index": worst_known_slot(seat)})
	_finish_turn_safely(ai, seat)
	return {"ok": true}


# Stufe 2/3: vorsichtige Vertretung, ein Schritt pro Aufruf. Ruft nie Dame.
func machine_step(ai, seat: int) -> Dictionary:
	if int(rules.state.current_index) != seat:
		return {"ok": false}
	var drawn = rules.state.drawn_card
	if drawn != null and str(drawn.rank) == "Q" and str(rules.state.turn_step) == "play":
		return _apply_public({"type": "swap", "seat": seat, "hand_index": worst_known_slot(seat)})
	var action: Dictionary = _cautious_action(ai, seat)
	var res := _apply_public(action)
	if not bool(res.get("ok", false)):
		_finish_turn_safely(ai, seat)
	return res


# Strafkarte beim Wiedereinstieg (Stufe 2), zu Beginn der naechsten Ausgabe.
func penalize_absence(seat: int) -> Dictionary:
	var res: Dictionary = rules.give_absence_penalty(seat)
	if bool(res.get("ok", false)):
		_dispatch(_broadcast())
	return res


# Hoechste bekannte eigene Karte, sonst die erste.
func worst_known_slot(seat: int) -> int:
	var player: Dictionary = rules.state.players[seat]
	var best := 0
	var best_value := -1
	for i in range(player.hand.size()):
		if player.known.has(i) and int(player.hand[i].value) > best_value:
			best_value = int(player.hand[i].value)
			best = i
	return best


func _finish_turn_safely(ai, seat: int) -> void:
	var guard := 0
	while guard < 10 and int(rules.state.current_index) == seat:
		guard += 1
		var phase := str(rules.state.phase)
		if phase != "play" and phase != "dame_called":
			return
		if not bool(_apply_public(_cautious_action(ai, seat)).get("ok", false)):
			if not _try_any_target(seat):
				return


func _cautious_action(ai, seat: int) -> Dictionary:
	if str(rules.state.turn_step) == "extra":
		return {"type": "end_turn", "seat": seat}
	return ai.fallback_action(rules, seat)


# Bube/Koenig: die Standardwahl kann scheitern. Dann irgendein gueltiges Ziel.
func _try_any_target(seat: int) -> bool:
	var step := str(rules.state.turn_step)
	if step != "jack" and step != "king":
		return false
	for p in rules.state.players:
		if bool(p.eliminated):
			continue
		for i in range(p.hand.size()):
			if step == "jack":
				if bool(_apply_public({"type": "look_card", "seat": seat, "target_seat": int(p.seat), "hand_index": i}).get("ok", false)):
					return true
			else:
				for q in rules.state.players:
					if bool(q.eliminated):
						continue
					for j in range(q.hand.size()):
						var a := {"type": "king_swap", "seat": seat, "a_seat": int(p.seat), "a_index": i, "b_seat": int(q.seat), "b_index": j}
						if bool(_apply_public(a).get("ok", false)):
							return true
	return false


# Aktion der Vertretung anwenden und allen die neue Sicht schicken.
func _apply_public(action: Dictionary) -> Dictionary:
	var res: Dictionary = rules.apply_action(action)
	if bool(res.get("ok", false)):
		_dispatch(_broadcast(Protocol.public_action(action, int(action.seat))))
	return res


# Naechste Runde starten (nur der Host).
func next_round() -> Dictionary:
	var res: Dictionary = rules.apply_action({"type": "start_next_round"})
	if bool(res.get("ok", false)):
		_dispatch(_broadcast({"type": "start_next_round", "seat": -1}))
	return res


# Merkphase abbrechen (nur der Host): wer nicht bestaetigt hat, gilt als bereit.
func peek_timeout() -> Dictionary:
	var res: Dictionary = rules.apply_action({"type": "peek_timeout"})
	if bool(res.get("ok", false)):
		_dispatch(_broadcast({"type": "peek_timeout", "seat": -1}))
	return res


# Nach Aenderungen ausserhalb von submit (z. B. KI-Zuege auf dem Host) aufrufen.
func broadcast() -> void:
	_dispatch(_broadcast())


# Reiner Kern: liefert die ausgehenden Nachrichten als [{to, msg}].
func handle_packet(from: int, bytes: PackedByteArray) -> Array:
	var msg := Codec.decode(bytes)
	match str(msg.get("t", "")):
		"hello":
			var v = msg.get("v")
			if typeof(v) != TYPE_INT or int(v) != Protocol.VERSION:
				return [{"to": from, "msg": {"t": "reject", "reason": "Falsche Spielversion"}}]
			# Bei einem Wiedereintritt behaelt der Peer seinen Schluessel.
			if not token_of_peer.has(from):
				token_of_peer[from] = new_token()
			var name := Protocol.clean_name(msg.get("name"))
			if not name.is_empty():
				name_of_peer[from] = name
			peer_joined.emit(from)
			return [{"to": from, "msg": {"t": "welcome", "peer": from, "token": token_of_peer[from]}}]
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
	var before := var_to_str(rules.state)
	var res: Dictionary = rules.apply_action(action)
	var ok := bool(res.get("ok", false))
	# Auch eine abgelehnte Aktion kann den Zustand aendern (falsches Extra-Ablegen
	# gibt eine Strafkarte). Dann bekommen alle eine neue Sicht ohne Aktion.
	var changed := not ok and var_to_str(rules.state) != before
	var out: Array = [_result_to(peer_id, ok, str(res.get("reason", "")), changed)]
	if ok:
		out.append_array(_broadcast(Protocol.public_action(action, seat)))
	elif changed:
		out.append_array(_broadcast())
	return out


func _broadcast(action: Dictionary = {}) -> Array:
	rev += 1
	var out: Array = []
	for peer in seat_of_peer:
		var view: Dictionary = DameViewScript.for_viewer(rules, int(seat_of_peer[peer]), absence)
		out.append({"to": int(peer), "msg": {"t": "view", "rev": rev, "view": view, "action": action}})
	return out


# changed: die Aktion wurde abgelehnt, hat den Zustand aber veraendert; eine
# neue Sicht folgt direkt nach diesem Ergebnis.
func _result_to(peer_id: int, ok: bool, reason: String, changed: bool = false) -> Dictionary:
	return {"to": peer_id, "msg": {"t": "result", "ok": ok, "reason": reason, "changed": changed}}


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
