extends RefCounted

# IceFetcher gegen einen lokalen Mini-HTTP-Server (synchron gepumpt, ohne Internet).

const IceFetcher = preload("res://scripts/net/ice_fetcher.gd")
const IceServers = preload("res://scripts/net/ice_servers.gd")

const GOOD_JSON := "{\"iceServers\":[{\"urls\":[\"turn:turn.example:3478?transport=udp\",\"turns:turn.example:443?transport=tcp\"],\"username\":\"u\",\"credential\":\"c\"}]}"

var t


# Nimmt eine Verbindung an, liest die Anfrage und schickt reply (leer = schweigen).
class FakeServer:
	var tcp := TCPServer.new()
	var port := 0
	var peer: StreamPeerTCP = null
	var reply := ""
	var sent := false
	var request := ""

	func start(reply_text: String) -> bool:
		reply = reply_text
		for p in range(47310, 47410):
			if tcp.listen(p, "127.0.0.1") == OK:
				port = p
				return true
		return false

	func pump() -> void:
		if peer == null and tcp.is_connection_available():
			peer = tcp.take_connection()
		if peer == null:
			return
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		var n := peer.get_available_bytes()
		if n > 0:
			request += peer.get_utf8_string(n)
		if not sent and reply != "" and request.contains("\r\n\r\n"):
			peer.put_data(reply.to_utf8_buffer())
			sent = true

	func stop() -> void:
		if peer != null:
			peer.disconnect_from_host()
		tcp.stop()


func run(ctx) -> void:
	t = ctx
	_check_success()
	_check_http_error()
	_check_too_big()
	_check_silent_timeout()
	_check_bad_urls()
	_check_refused()


static func _http(code: int, body: String) -> String:
	return "HTTP/1.1 %d X\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n%s" % [code, body.to_utf8_buffer().size(), body]


# Pumpt Server und Abruf, bis der Abruf fertig ist; gibt die Dauer in ms zurueck.
func _run(f, server: FakeServer, max_ms := 3000) -> int:
	var start := Time.get_ticks_msec()
	while not f.is_done() and Time.get_ticks_msec() - start < max_ms:
		if server != null:
			server.pump()
		f.poll()
		OS.delay_msec(5)
	return Time.get_ticks_msec() - start


func _fetch_from(reply: String, label: String, timeout_ms := 4000) -> Dictionary:
	var server := FakeServer.new()
	if not server.start(reply):
		t.expect(false, label + ": kein freier Port")
		return {}
	var f = IceFetcher.new()
	f.timeout_ms = timeout_ms
	f.start("http://127.0.0.1:%d/functions/v1/turn-credentials" % server.port)
	var ms := _run(f, server)
	var out := {"done": f.is_done(), "has_turn": f.has_turn, "config": f.config, "ms": ms, "request": server.request}
	f.close()
	server.stop()
	return out


func _check_success() -> void:
	var r := _fetch_from(_http(200, GOOD_JSON), "Erfolg")
	if r.is_empty():
		return
	t.expect(r.done and r.has_turn, "Erfolg: fertig mit TURN")
	t.expect((r.config.iceServers as Array).size() == 2, "Erfolg: STUN + TURN")
	t.expect(str(r.request).begins_with("GET /functions/v1/turn-credentials "), "Erfolg: GET auf den Pfad")


func _check_http_error() -> void:
	var r := _fetch_from(_http(500, GOOD_JSON), "500")
	if r.is_empty():
		return
	t.expect(r.done and not r.has_turn, "500: fertig ohne TURN")
	t.expect(r.config == IceServers.default_config(), "500: Standard")


func _check_too_big() -> void:
	var body := "{\"iceServers\":[],\"x\":\"%s\"}" % "a".repeat(IceServers.MAX_RESPONSE + 10)
	var r := _fetch_from(_http(200, body), "zu gross")
	if r.is_empty():
		return
	t.expect(r.done and not r.has_turn, "zu gross: fertig ohne TURN")
	t.expect(r.config == IceServers.default_config(), "zu gross: Standard")


func _check_silent_timeout() -> void:
	var r := _fetch_from("", "schweigt", 300)
	if r.is_empty():
		return
	t.expect(r.done and not r.has_turn, "schweigt: fertig ohne TURN")
	t.expect(int(r.ms) < 1500, "schweigt: Zeitlimit greift (%d ms)" % int(r.ms))


func _check_bad_urls() -> void:
	for url in ["", "ftp://x/y", "https://", "https://:443/x", "http://host:99999/x", "http://host:abc/x"]:
		var f = IceFetcher.new()
		f.start(url)
		t.expect(f.is_done(), "URL '%s': sofort fertig" % url)
		t.expect(f.config == IceServers.default_config() and not f.has_turn, "URL '%s': Standard" % url)
		f.poll()
		f.close()


func _check_refused() -> void:
	# Port suchen, auf dem niemand lauscht: kurz belegen und wieder freigeben.
	var server := FakeServer.new()
	if not server.start(""):
		t.expect(false, "abgelehnt: kein freier Port")
		return
	var port := server.port
	server.stop()
	var f = IceFetcher.new()
	f.timeout_ms = 2000
	f.start("http://127.0.0.1:%d/x" % port)
	_run(f, null)
	t.expect(f.is_done() and not f.has_turn, "abgelehnt: fertig ohne TURN")
	f.close()
