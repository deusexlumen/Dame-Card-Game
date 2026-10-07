extends RefCounted

# IceServers: TURN-Antwort pruefen, Konfiguration bauen, Kandidaten kuerzen.

const IceServers = preload("res://scripts/net/ice_servers.gd")

const USER := "bc91b63e2b5d759f8eb9f3b58062439e0a0e15893d76317d833265ad08d6631099ce7c7087caabb31ad3e1c386424e3e"
const CRED := "ebd71f1d3edbc2b0edae3cd5a6d82284aeb5c3b8fdaa9b8e3bf9cec683e0d45fe9f5b44e5145db3300f06c250a15b4a0"

var t


func run(ctx) -> void:
	t = ctx
	_check_cloudflare()
	_check_single_object()
	_check_garbage()
	_check_build_config()
	_check_limit_candidates()


# Antwort wie in der Cloudflare-Doku, ergaenzt um eine Port-53-URL.
func _cloudflare_json() -> String:
	return JSON.stringify({"iceServers": [
		{"urls": ["stun:stun.cloudflare.com:3478"]},
		{"urls": [
			"turn:turn.cloudflare.com:53?transport=udp",
			"turn:turn.cloudflare.com:3478?transport=udp",
			"turn:turn.cloudflare.com:443?transport=udp",
			"turn:turn.cloudflare.com:3478?transport=tcp",
			"turn:turn.cloudflare.com:80?transport=tcp",
			"turns:turn.cloudflare.com:5349?transport=tcp",
			"turns:turn.cloudflare.com:443?transport=tcp",
		], "username": USER, "credential": CRED},
	]})


func _all_urls(turn: Array) -> Array:
	var out := []
	for e in turn:
		out.append_array(e.urls)
	return out


func _check_cloudflare() -> void:
	var turn: Array = IceServers.parse_turn(_cloudflare_json())
	var urls := _all_urls(turn)
	t.expect(urls == [
		"turn:turn.cloudflare.com:3478?transport=udp",
		"turn:turn.cloudflare.com:3478?transport=tcp",
		"turns:turn.cloudflare.com:443?transport=tcp",
	], "Cloudflare: UDP, TCP, TLS-443 gewaehlt (%s)" % str(urls))
	t.expect(turn.size() == 1, "Cloudflare: ein Eintrag mit Zugangsdaten")
	if turn.size() == 1:
		t.expect(turn[0].username == USER and turn[0].credential == CRED, "Cloudflare: Zugangsdaten uebernommen")


func _check_single_object() -> void:
	var one := JSON.stringify({"iceServers": {"urls": "turns:t.example:443?transport=tcp", "username": "u", "credential": "c"}})
	var turn: Array = IceServers.parse_turn(one)
	t.expect(_all_urls(turn) == ["turns:t.example:443?transport=tcp"], "Einzelobjekt und URL als String akzeptiert")


func _check_garbage() -> void:
	var cases := {
		"leer": "",
		"html": "<html>502</html>",
		"array": "[]",
		"zahl": JSON.stringify({"iceServers": 5}),
		"urls zahl": JSON.stringify({"iceServers": [{"urls": 7, "username": "u", "credential": "c"}]}),
		"user zahl": JSON.stringify({"iceServers": [{"urls": ["turn:a:3478"], "username": 5, "credential": "c"}]}),
		"cred leer": JSON.stringify({"iceServers": [{"urls": ["turn:a:3478"], "username": "u", "credential": ""}]}),
		"fremdes schema": JSON.stringify({"iceServers": [{"urls": ["javascript:alert(1)", "http://a"], "username": "u", "credential": "c"}]}),
		"nur port 53": JSON.stringify({"iceServers": [{"urls": ["turn:a:53?transport=udp", "turn:a:53"], "username": "u", "credential": "c"}]}),
		"riesig": JSON.stringify({"iceServers": [{"urls": ["turn:a:3478"], "username": "u", "credential": "x".repeat(IceServers.MAX_RESPONSE)}]}),
		"feld zu lang": JSON.stringify({"iceServers": [{"urls": ["turn:a:3478"], "username": "u".repeat(600), "credential": "c"}]}),
	}
	for label in cases:
		var turn: Array = IceServers.parse_turn(cases[label])
		t.expect(turn.is_empty(), "Muell '%s' -> []" % label)


func _check_build_config() -> void:
	t.expect(IceServers.build_config([]) == IceServers.default_config(), "ohne TURN = Standard")
	var turn: Array = IceServers.parse_turn(_cloudflare_json())
	var cfg: Dictionary = IceServers.build_config(turn)
	var servers: Array = cfg.iceServers
	t.expect(servers.size() == 2, "Standard-STUN + TURN")
	t.expect(servers[0] == IceServers.default_config().iceServers[0], "STUN zuerst")
	# Standard darf durch build_config nicht veraendert werden.
	t.expect((IceServers.default_config().iceServers as Array).size() == 1, "Standard unveraendert")


func _cand(typ: String, i: int) -> Dictionary:
	return {"candidate": "candidate:%d 1 udp 100 10.0.0.%d 5000 typ %s generation 0" % [i, i % 250, typ], "sdpMid": "0", "sdpMLineIndex": 0}


func _check_limit_candidates() -> void:
	var cands := []
	for i in 32:
		cands.append(_cand("host", i))
	cands.append(_cand("srflx", 100))
	cands.append(_cand("relay", 101))
	var out: Array = IceServers.limit_candidates(cands, 32)
	t.expect(out.size() == 32, "gekuerzt auf 32")
	t.expect(out.has(cands[32]) and out.has(cands[33]), "srflx und relay bleiben")
	var last := -1
	var ordered := true
	for c in out:
		var idx := cands.find(c)
		ordered = ordered and idx > last
		last = idx
	t.expect(ordered, "Originalreihenfolge")
	var few := cands.slice(0, 5)
	t.expect(IceServers.limit_candidates(few, 32) == few, "unter Grenze unveraendert")
