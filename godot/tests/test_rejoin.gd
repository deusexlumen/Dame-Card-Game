extends RefCounted

# Wiedereintritt nach Verbindungsverlust (CONCEPT_DECISIONS §11): RejoinHost und
# RejoinGuest ueber einen Raum im Speicher und nachgebaute Connectoren (kein WebRTC).
# Der echte Weg mit WebRTC und zwei Tischen steht in test_online_screen (_check_room_rejoin).

const RejoinHost = preload("res://scripts/net/rejoin_host.gd")
const RejoinGuest = preload("res://scripts/net/rejoin_guest.gd")
const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameHost = preload("res://scripts/net/dame_host.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")
const Loopback = preload("res://scripts/net/loopback_link.gd")
const Protocol = preload("res://scripts/net/net_protocol.gd")
const Codec = preload("res://scripts/net/net_codec.gd")

const WAIT_CAP_MS := 5000
const ROOM := "ABC234"

var t


# Raum-Dienst im Speicher: Broadcast an alle anderen im selben Raum, Zustellung beim poll().
class FakeRoom:
	extends RefCounted
	var members: Array = []
	var down := false
	var sent: Array = []   # [name, payload] aller Nachrichten


class FakeSig:
	extends RefCounted
	signal joined()
	signal event(name: String, payload: Dictionary)
	signal failed(reason: String)
	var hub
	var room := ""
	var inbox: Array = []
	var _joined := false
	var _closed := false
	var _opened := false

	func _init(h) -> void:
		hub = h

	func open(code: String) -> bool:
		room = code
		_opened = true
		return true

	func is_joined() -> bool:
		return _joined

	func send_event(name: String, payload: Dictionary) -> bool:
		if not _joined:
			return false
		hub.sent.append([name, payload])
		for m in hub.members:
			if m != self:
				m.inbox.append([name, payload])
		return true

	func poll() -> void:
		if _closed or not _opened:
			return
		if hub.down:
			_closed = true
			hub.members.erase(self)
			failed.emit("weg")
			return
		if not _joined:
			_joined = true
			hub.members.append(self)
			joined.emit()
		var batch := inbox
		inbox = []
		for e in batch:
			event.emit(e[0], e[1])

	func close() -> void:
		_closed = true
		_joined = false
		hub.members.erase(self)


# Gemeinsamer Zustand der nachgebauten WebRTC-Seiten.
class Wire:
	extends RefCounted
	var serial := 0
	var accepted := {}      # Einladungscode -> true (Host hat die Antwort angenommen)
	var fail_join := false  # Gast-Connector scheitert nach der Antwort


class FakeHostRtc:
	extends RefCounted
	signal invite_ready(code: String)
	signal failed(reason: String)
	signal connected(link)
	var wire
	var dropped: Array = []
	var invites: Array = []
	var _due := ""
	var _connect_due := false

	func _init(w) -> void:
		wire = w

	func create_invite(peer: int) -> void:
		wire.serial += 1
		_due = "INV-%d-%d" % [wire.serial, peer]
		invites.append(_due)

	func drop_peer(peer: int) -> void:
		dropped.append(peer)

	func accept_answer(code: String) -> Dictionary:
		var inv := code.trim_prefix("ANS-")
		if invites.is_empty() or inv != invites[-1]:
			return {"ok": false, "error": "falsch"}
		wire.accepted[inv] = true
		_connect_due = true
		return {"ok": true, "error": ""}

	func poll() -> void:
		if _due != "":
			var c := _due
			_due = ""
			invite_ready.emit(c)
		if _connect_due:
			_connect_due = false
			connected.emit("host-link")


class FakeGuestRtc:
	extends RefCounted
	signal answer_ready(code: String)
	signal connected(link)
	signal failed(reason: String)
	var wire
	var ice_config: Dictionary = {}
	var guest_timeout_ms := 0
	var code := ""
	var closed := false
	var _answered := false

	func _init(w) -> void:
		wire = w

	func join(invite: String) -> Dictionary:
		code = invite
		return {"ok": true, "error": ""}

	func poll() -> void:
		if closed:
			return
		if not _answered:
			_answered = true
			answer_ready.emit("ANS-" + code)
			return
		if wire.accepted.has(code):
			if wire.fail_join:
				wire.fail_join = false
				closed = true
				failed.emit("kaputt")
				return
			connected.emit("guest-link-" + code)

	func close() -> void:
		closed = true


func run(ctx) -> void:
	t = ctx
	_check_tokens_and_bye()
	_check_happy_path()
	_check_wrong_token()
	_check_forfeited()
	_check_unreachable_limit()
	_check_foreign_invite()
	_check_retry_after_failure()
	_check_host_room_reopens()
	_check_two_guests_rejoin()


# ---------- Hilfen ----------

func _host_session():
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 5, "seat_count": 3, "ai_seats": [2]})
	return DameHost.new(rules, null)


# Host-Session mit bekanntem Schluessel fuer Peer 2.
func _session_with_token(tok: String):
	var s = _host_session()
	s.token_of_peer[2] = tok
	return s


func _wait(cond: Callable, what: String) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < WAIT_CAP_MS:
		if cond.call():
			return true
		OS.delay_msec(2)
	t.expect(false, "Zeitueberschreitung beim Warten auf: " + what)
	return false


func _pair(tok_host: String, tok_guest: String, allow: Callable = func(_p): return true) -> Dictionary:
	var hub := FakeRoom.new()
	var wire := Wire.new()
	var hrtc := FakeHostRtc.new(wire)
	var rh = RejoinHost.new(hrtc, _session_with_token(tok_host), ROOM, func(): return FakeSig.new(hub), allow)
	var made: Array = []
	var rg = RejoinGuest.new(ROOM, tok_guest, 2, func(): return FakeSig.new(hub), func():
		var c := FakeGuestRtc.new(wire)
		made.append(c)
		return c)
	var st := {"link": null, "owner": null, "gave_up": null}
	rg.reconnected.connect(func(l, o):
		st.link = l
		st.owner = o)
	rg.gave_up.connect(func(g): st.gave_up = g)
	return {"hub": hub, "wire": wire, "hrtc": hrtc, "rh": rh, "rg": rg, "made": made, "st": st}


func _pump(p: Dictionary) -> void:
	p.rh.poll()
	p.rg.poll()


# ---------- Faelle ----------

# Schluessel bleibt je Peer gleich, bye fuehrt beim Gast zu host_left.
func _check_tokens_and_bye() -> void:
	var hub = Loopback.new_hub()
	var hlink = hub.link(Protocol.HOST_PEER)
	var glink = hub.link(2)
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 5, "seat_count": 3, "ai_seats": [2]})
	var host = DameHost.new(rules, hlink)
	var guest = DameGuest.new(glink)
	guest.connect_to_host()
	host.poll()
	guest.poll()
	t.expect(guest.token.length() >= 20 and guest.peer_id == 2, "Gast hat keinen Schluessel/Peer aus welcome")
	t.expect(host.peer_of_token(guest.token) == 2, "Host findet den Peer zum Schluessel nicht")
	t.expect(host.peer_of_token("") == -1 and host.peer_of_token("falsch") == -1, "Leerer/falscher Schluessel trifft einen Peer")
	var first: String = guest.token
	guest.connect_to_host()
	host.poll()
	guest.poll()
	t.expect(guest.token == first, "Schluessel aendert sich beim erneuten hello")
	# Kaputter Schluessel im welcome wird nicht uebernommen.
	hlink.send(2, Codec.encode({"t": "welcome", "peer": 2, "token": {"x": 1}}))
	guest.poll()
	t.expect(guest.token == first, "Gast uebernimmt kaputten Schluessel")
	host.assign_seat(2, 1)
	guest.poll()
	var left := [false]
	guest.host_left.connect(func(): left[0] = true)
	host.say_bye()
	guest.poll()
	t.expect(left[0], "bye kommt beim Gast nicht als host_left an")


func _check_happy_path() -> void:
	var p := _pair("geheim", "geheim")
	_wait(func():
		_pump(p)
		return p.st.link != null, "Wiedereintritt (Nachbau)")
	t.expect(str(p.st.link).begins_with("guest-link-INV-"), "Falscher Link nach Wiedereintritt: " + str(p.st.link))
	t.expect(p.st.owner == p.made[-1], "Besitzer ist nicht der neue Connector")
	t.expect(p.hrtc.dropped == [2], "Host baut die alte Verbindung nicht genau einmal ab: " + str(p.hrtc.dropped))
	t.expect(p.made.size() == 1 and p.made[0].guest_timeout_ms == RejoinGuest.CONNECT_TIMEOUT_MS, "Gast-Connector falsch eingerichtet")
	var invites := (p.hub.sent as Array).filter(func(e): return e[0] == "invite")
	t.expect(not invites.is_empty() and int(invites[0][1].peer) == 2, "Einladung ohne Peer-Kennung")
	t.expect(p.rg.is_done() and p.st.gave_up == null, "Gast meldet nach Erfolg noch etwas")
	# Danach bleibt der Host-Raum offen (naechster Verlust), der Gast ist fertig.
	t.expect(p.rh.is_open(), "Host-Raum nach Wiedereintritt zu")
	p.rh.close()


func _check_wrong_token() -> void:
	var p := _pair("geheim", "falsch")
	p.rg.host_silent_ms = 200
	_wait(func():
		_pump(p)
		return p.st.gave_up != null, "Aufgeben bei falschem Schluessel")
	t.expect(p.st.gave_up == true, "Falscher Schluessel: Host gilt nicht als weg")
	t.expect(p.hrtc.invites.is_empty() and p.hrtc.dropped.is_empty(), "Host reagiert auf falschen Schluessel")
	p.rh.close()


# §11 Stufe 3: verlorener Platz bekommt keine Einladung mehr.
func _check_forfeited() -> void:
	var p := _pair("geheim", "geheim", func(_peer): return false)
	p.rg.host_silent_ms = 200
	_wait(func():
		_pump(p)
		return p.st.gave_up != null, "Aufgeben bei verlorenem Platz")
	t.expect(p.hrtc.invites.is_empty(), "Verlorener Platz bekommt eine Einladung")
	p.rh.close()


# Eigenes Netz weg: Raum-Dienst nie erreichbar, nach dem Zeitlimit aufgeben (nicht "Host weg").
func _check_unreachable_limit() -> void:
	var p := _pair("geheim", "geheim")
	p.hub.down = true
	p.rg.limit_ms = 300
	_wait(func():
		p.rg.poll()
		return p.st.gave_up != null, "Aufgeben nach Zeitlimit")
	t.expect(p.st.gave_up == false, "Zeitlimit als 'Host weg' gemeldet")
	p.rh.close()


# Einladungen fuer andere Gaeste nicht annehmen.
func _check_foreign_invite() -> void:
	var hub := FakeRoom.new()
	var wire := Wire.new()
	var made: Array = []
	var rg = RejoinGuest.new(ROOM, "geheim", 2, func(): return FakeSig.new(hub), func():
		var c := FakeGuestRtc.new(wire)
		made.append(c)
		return c)
	var host_sig := FakeSig.new(hub)
	host_sig.open(ROOM)
	host_sig.poll()
	_wait(func():
		rg.poll()
		host_sig.poll()
		return rg._sig != null and rg._sig.is_joined(), "Gast im Raum")
	host_sig.send_event("invite", {"code": "INV-9-3", "peer": 3})
	host_sig.send_event("invite", {"code": "INV-9-x", "peer": "2"})
	host_sig.send_event("invite", {"code": 5, "peer": 2})
	for i in 5:
		rg.poll()
	t.expect(made.is_empty(), "Gast nimmt fremde oder kaputte Einladung an")
	host_sig.send_event("invite", {"code": "INV-9-2", "peer": 2.0})
	rg.poll()
	t.expect(made.size() == 1, "Gast nimmt eigene Einladung (Zahl als float) nicht an")
	rg.cancel()
	t.expect(made[0].closed, "cancel schliesst den Connector nicht")


# Verbindung scheitert nach der Antwort: neuer Anlauf, neue Einladung.
func _check_retry_after_failure() -> void:
	var p := _pair("geheim", "geheim")
	p.wire.fail_join = true
	_wait(func():
		_pump(p)
		return p.st.link != null, "Wiedereintritt nach gescheitertem Versuch")
	t.expect(p.made.size() == 2 and p.made[0].closed, "Kein neuer Connector nach Fehlschlag")
	t.expect(p.hrtc.invites.size() == 2, "Host macht keine neue Einladung: " + str(p.hrtc.invites))
	p.rh.close()


# Raum-Dienst des Hosts faellt aus: wird wieder geoeffnet, Wiedereintritt klappt danach.
func _check_host_room_reopens() -> void:
	var p := _pair("geheim", "geheim")
	p.hub.down = true
	p.rh.poll()
	p.rh.poll()
	t.expect(not p.rh.is_open(), "Host-Raum trotz Ausfall offen")
	p.hub.down = false
	p.rh._retry_at = 0
	_wait(func():
		_pump(p)
		return p.st.link != null, "Wiedereintritt nach Ausfall des Raum-Dienstes")
	p.rh.close()
	t.expect(not p.rh.is_open(), "close laesst den Host-Raum offen")


# Zwei Gaeste (Peer 2 und 3) im selben Raum: jeder kommt mit seinem Schluessel zurueck,
# der andere Platz bleibt unberuehrt.
func _check_two_guests_rejoin() -> void:
	var hub := FakeRoom.new()
	var wire := Wire.new()
	var hrtc := FakeHostRtc.new(wire)
	var session = _host_session()
	session.token_of_peer[2] = "schluessel-zwei"
	session.token_of_peer[3] = "schluessel-drei"
	var rh = RejoinHost.new(hrtc, session, ROOM, func(): return FakeSig.new(hub), func(_p): return true)
	var out := {"2": null, "3": null}
	var guests: Array = []
	for pair in [[2, "schluessel-zwei"], [3, "schluessel-drei"]]:
		var rg = RejoinGuest.new(ROOM, pair[1], pair[0], func(): return FakeSig.new(hub), func(): return FakeGuestRtc.new(wire))
		var key := str(pair[0])
		rg.reconnected.connect(func(l, _o): out[key] = l)
		guests.append(rg)
	# Nur Gast 3 verliert die Verbindung: nur er meldet sich.
	var only3: Array = [guests[1]]
	_wait(func():
		rh.poll()
		for g in only3:
			g.poll()
		return out["3"] != null, "Zwei Gaeste: Gast 3 kommt zurueck")
	t.expect(hrtc.dropped == [3] and out["2"] == null, "Zwei Gaeste: Gast 2 beruehrt: %s" % str(hrtc.dropped))
	t.expect(str(out["3"]).ends_with("-3"), "Zwei Gaeste: Gast 3 bekam fremde Einladung: %s" % str(out["3"]))
	# Danach verliert auch Gast 2 die Verbindung.
	_wait(func():
		rh.poll()
		guests[0].poll()
		return out["2"] != null, "Zwei Gaeste: Gast 2 kommt zurueck")
	t.expect(hrtc.dropped == [3, 2] and str(out["2"]).ends_with("-2"), "Zwei Gaeste: Gast 2 falsch: %s %s" % [str(hrtc.dropped), str(out["2"])])
	rh.close()
