extends RefCounted

# PeerLink ueber echte ENet-Peers auf localhost (nur Testtransport, kein WebRTC).
# Jede Warteschleife hat eine harte Obergrenze; alle Peers werden immer geschlossen.

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const Protocol = preload("res://scripts/net/net_protocol.gd")
const Codec = preload("res://scripts/net/net_codec.gd")
const PeerLink = preload("res://scripts/net/peer_link.gd")
const DameHost = preload("res://scripts/net/dame_host.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")

const MAX_ITER := 200
const PORT_FIRST := 24600
const PORT_LAST := 24650

var t
var _peers: Array = []


func run(ctx) -> void:
	t = ctx
	_check_session()
	_check_two_guests()
	_check_oversized()


# ---------- Hilfen ----------

func _server() -> Array:
	for port in range(PORT_FIRST, PORT_LAST + 1):
		var s := ENetMultiplayerPeer.new()
		if s.create_server(port, 4) == OK:
			_peers.append(s)
			return [s, port]
	t.expect(false, "Kein freier Port in %d..%d" % [PORT_FIRST, PORT_LAST])
	return []


func _client(port: int) -> ENetMultiplayerPeer:
	var c := ENetMultiplayerPeer.new()
	var err := c.create_client("127.0.0.1", port)
	t.expect(err == OK, "create_client fehlgeschlagen: %d" % err)
	_peers.append(c)
	return c


# Pollt alle Peers, bis cond wahr ist. Harte Obergrenze, nie haengen.
func _wait(cond: Callable, what: String) -> bool:
	for i in MAX_ITER:
		for p in _peers:
			p.poll()
		if cond.call():
			return true
		OS.delay_msec(5)
	t.expect(false, "Zeitueberschreitung beim Warten auf: " + what)
	return false


func _close_all() -> void:
	for p in _peers:
		p.close()
	_peers.clear()


func _connected(c: ENetMultiplayerPeer) -> bool:
	return c.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# ---------- Tests ----------

func _check_session() -> void:
	var sv: Array = _server()
	if sv.is_empty():
		return
	var client := _client(int(sv[1]))
	var server_link = PeerLink.new(sv[0])
	var client_link = PeerLink.new(client)
	var joined: Array = []
	server_link.peer_connected.connect(func(id): joined.append(id))
	var left_ids: Array = []
	server_link.peer_disconnected.connect(func(id): left_ids.append(id))
	if _wait(func(): return _connected(client) and not joined.is_empty(), "Verbindung"):
		t.expect(server_link.my_id() == Protocol.HOST_PEER, "Server-ID ist nicht HOST_PEER")
		var rules = DameRulesScript.new()
		rules.start_match({"seed": 77, "seat_count": 3, "ai_seats": [2]})
		var host = DameHost.new(rules, server_link)
		var guest = DameGuest.new(client_link)
		var results: Array = []
		var guest_views: Array = []
		var peer_left_ids: Array = []
		var welcomed := [false]
		guest.action_result.connect(func(r): results.append(r))
		guest.view_changed.connect(func(v, _a): guest_views.append(v))
		guest.welcomed.connect(func(): welcomed[0] = true)
		host.peer_left.connect(func(id): peer_left_ids.append(id))
		var gid: int = client.get_unique_id()
		guest.connect_to_host()
		_wait(func():
			host.poll()
			guest.poll()
			return welcomed[0], "welcome")
		host.assign_seat(Protocol.HOST_PEER, 0)
		host.assign_seat(gid, 1)
		_wait(func():
			host.poll()
			guest.poll()
			return not guest_views.is_empty(), "erste Sicht")
		t.expect(not guest_views.is_empty(), "Gast bekam keine Sicht")
		if not guest_views.is_empty():
			t.expect(int(guest_views[0].get("viewer_seat", -1)) == 1, "Gast-Sicht hat falschen Sitz")
		# Gast ist dran, dann eine echte Aktion ueber das Netz.
		rules.state.current_index = 1
		var rev_before: int = guest.rev
		guest.send_action({"type": "draw_deck"})
		_wait(func():
			host.poll()
			guest.poll()
			return guest.rev > rev_before and not results.is_empty(), "Antwort auf Gast-Aktion")
		t.expect(not results.is_empty() and bool(results[0].get("ok", false)), "Gast-Aktion nicht angenommen")
		t.expect(guest.rev > rev_before, "rev steigt nicht nach Gast-Aktion")
		# Client schliessen: Host merkt es und laeuft weiter.
		client.close()
		_wait(func():
			host.poll()
			return not left_ids.is_empty(), "peer_disconnected")
		t.expect(left_ids.has(gid), "Link meldet Trennung nicht")
		t.expect(peer_left_ids.has(gid), "Host meldet peer_left nicht")
		host.poll()
		host.broadcast()
		t.expect(int(host.latest_view.get("viewer_seat", -1)) == 0, "Host laeuft nach Trennung nicht weiter")
	_close_all()


func _check_two_guests() -> void:
	var sv: Array = _server()
	if sv.is_empty():
		return
	var c1 := _client(int(sv[1]))
	var c2 := _client(int(sv[1]))
	var server_link = PeerLink.new(sv[0])
	var l1 = PeerLink.new(c1)
	var l2 = PeerLink.new(c2)
	if _wait(func(): return _connected(c1) and _connected(c2), "zwei Gaeste"):
		var id1: int = c1.get_unique_id()
		var id2: int = c2.get_unique_id()
		t.expect(id1 != id2 and id1 != 1 and id2 != 1, "Client-IDs nicht eindeutig")
		l1.send(Protocol.HOST_PEER, PackedByteArray([1, 1]))
		l2.send(Protocol.HOST_PEER, PackedByteArray([2, 2, 2]))
		l1.send(Protocol.HOST_PEER, PackedByteArray([1, 1, 1, 1]))
		var got: Array = []
		_wait(func():
			got.append_array(server_link.receive())
			return got.size() >= 3, "drei Pakete")
		t.expect(got.size() == 3, "Paketanzahl falsch: %d" % got.size())
		var ok := true
		for pkt in got:
			var b: PackedByteArray = pkt.bytes
			var expected := id1 if b[0] == 1 else id2
			if int(pkt.from) != expected:
				ok = false
		t.expect(ok, "Pakete dem falschen Absender zugeordnet")
		# Antwort geht an genau einen Gast.
		server_link.send(id2, PackedByteArray([9]))
		var r1: Array = []
		var r2: Array = []
		_wait(func():
			r1.append_array(l1.receive())
			r2.append_array(l2.receive())
			return not r2.is_empty(), "Antwort an Gast 2")
		t.expect(r1.is_empty() and r2.size() == 1, "Antwort an falschen Gast zugestellt")
		t.expect(not r2.is_empty() and int(r2[0].from) == Protocol.HOST_PEER, "Absender der Antwort ist nicht HOST_PEER")
	_close_all()


func _check_oversized() -> void:
	var sv: Array = _server()
	if sv.is_empty():
		return
	var client := _client(int(sv[1]))
	var server_link = PeerLink.new(sv[0])
	var client_link = PeerLink.new(client)
	if _wait(func(): return _connected(client), "Verbindung (gross)"):
		var big := PackedByteArray()
		big.resize(PeerLink.MAX_PACKET + 1)
		client_link.send(Protocol.HOST_PEER, big)
		client_link.send(Protocol.HOST_PEER, PackedByteArray([5]))
		var got: Array = []
		_wait(func():
			got.append_array(server_link.receive())
			return not got.is_empty(), "kleines Paket nach grossem")
		t.expect(got.size() == 1 and got[0].bytes.size() == 1, "Uebergrosses Paket nicht verworfen oder Link kaputt")
		# Link funktioniert weiter.
		client_link.send(Protocol.HOST_PEER, PackedByteArray([6]))
		var more: Array = []
		_wait(func():
			more.append_array(server_link.receive())
			return not more.is_empty(), "Paket nach Verwurf")
		t.expect(more.size() == 1 and more[0].bytes[0] == 6, "Link nach Verwurf kaputt")
	_close_all()
