extends RefCounted

# Holt TURN-Zugangsdaten per HTTP(S), nicht-blockierend. Der Besitzer ruft poll()
# bis is_done(). config ist immer gueltig: nur STUN, bis eine gueltige Antwort da ist.
# Scheitert irgendetwas (keine/kaputte URL, Zeitlimit, HTTP-Fehler, Muell), bleibt es
# bei STUN. close() bricht ab.

const IceServers = preload("res://scripts/net/ice_servers.gd")

var timeout_ms := 4000
var config: Dictionary = IceServers.default_config()
var has_turn := false

var _http: HTTPClient = null
var _path := ""
var _deadline_ms := 0
var _requested := false
var _got_response := false
var _body := PackedByteArray()
var _done := false


func start(url: String) -> void:
	if _http != null or _done:
		return
	var target := _split(url)
	if target.is_empty():
		_done = true
		return
	_deadline_ms = Time.get_ticks_msec() + timeout_ms
	_path = target.path
	_http = HTTPClient.new()
	var tls: TLSOptions = TLSOptions.client() if bool(target.tls) else null
	if _http.connect_to_host(target.host, int(target.port), tls) != OK:
		_finish(false)


func is_done() -> bool:
	return _done


func poll() -> void:
	if _done or _http == null:
		return
	if Time.get_ticks_msec() > _deadline_ms:
		_finish(false)
		return
	_http.poll()
	match _http.get_status():
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			pass
		HTTPClient.STATUS_CONNECTED:
			if not _requested:
				_requested = true
				if _http.request(HTTPClient.METHOD_GET, _path, ["Accept: application/json"]) != OK:
					_finish(false)
			elif _got_response:
				_finish(true)  # Body vollstaendig gelesen
		HTTPClient.STATUS_BODY:
			if not _got_response:
				_got_response = true
				if _http.get_response_code() != 200:
					_finish(false)
					return
			_body.append_array(_http.read_response_body_chunk())
			if _body.size() > IceServers.MAX_RESPONSE:
				_finish(false)
		HTTPClient.STATUS_DISCONNECTED:
			# Getrennt nach Antwort ist ok (Connection: close), vorher ein Fehler.
			_finish(_got_response)
		_:
			_finish(false)


func close() -> void:
	if _http != null:
		_http.close()
		_http = null
	_done = true


func _finish(ok: bool) -> void:
	if ok:
		var turn: Array = IceServers.parse_turn(_body.get_string_from_utf8())
		if not turn.is_empty():
			config = IceServers.build_config(turn)
			has_turn = true
	_body = PackedByteArray()
	close()


# "http(s)://host[:port][/pfad]" -> {tls, host, port, path} oder {} bei allem anderen.
static func _split(url: String) -> Dictionary:
	var tls := url.begins_with("https://")
	var rest := ""
	if tls:
		rest = url.substr(8)
	elif url.begins_with("http://"):
		rest = url.substr(7)
	else:
		return {}
	var slash := rest.find("/")
	var host_port := rest if slash < 0 else rest.substr(0, slash)
	var path := "/" if slash < 0 else rest.substr(slash)
	var host := host_port
	var port := 443 if tls else 80
	var colon := host_port.rfind(":")
	if colon >= 0:
		host = host_port.substr(0, colon)
		var p := host_port.substr(colon + 1)
		if not p.is_valid_int() or int(p) < 1 or int(p) > 65535:
			return {}
		port = int(p)
	if host == "":
		return {}
	return {"tls": tls, "host": host, "port": port, "path": path}
