extends RefCounted

# ICE-Server fuer WebRTC: STUN fest, TURN-Zugangsdaten vom Dienst (rein, ohne Netz).
# Antwortform wie Cloudflare generate-ice-servers:
#   {"iceServers": [{"urls": [...], "username": "...", "credential": "..."}]}
# Alles Unerwartete faellt weg; ohne gueltigen TURN-Eintrag bleibt nur STUN.

const STUN_URL := "stun:stun.l.google.com:19302"
const MAX_RESPONSE := 16384      # Antworttext hoechstens so lang
const MAX_TURN_URLS := 3
const MAX_FIELD := 512           # Laenge von URL, Benutzer, Passwort

# Je Art hoechstens eine URL, in dieser Rangfolge. TLS auf 443 kommt durch strenge
# Firewalls (Firma, manche Mobilnetze) und darf deshalb nie wegfallen.
enum Kind { UDP, TCP, TLS_443, OTHER }


static func default_config() -> Dictionary:
	return {"iceServers": [{"urls": [STUN_URL]}]}


static func build_config(turn: Array) -> Dictionary:
	var cfg := default_config()
	(cfg.iceServers as Array).append_array(turn)
	return cfg


# TURN-Eintraege aus der Dienstantwort, [] bei allem Unerwarteten.
static func parse_turn(text: String) -> Array:
	if text.length() > MAX_RESPONSE:
		return []
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var list = data.get("iceServers")
	if typeof(list) == TYPE_DICTIONARY:
		list = [list]
	if typeof(list) != TYPE_ARRAY:
		return []
	# Beste URL je Art suchen: {kind: [url, user, cred]}
	var best := {}
	for entry in list:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var user = entry.get("username")
		var cred = entry.get("credential")
		if not _is_field(user) or not _is_field(cred):
			continue
		var urls = entry.get("urls")
		if typeof(urls) == TYPE_STRING:
			urls = [urls]
		if typeof(urls) != TYPE_ARRAY:
			continue
		for u in urls:
			if not _is_field(u):
				continue
			var kind := _kind(u)
			if kind >= 0 and not best.has(kind):
				best[kind] = [u, user, cred]
	# Nach Art sortiert, je Zugangsdaten zusammengefasst.
	var out := []
	var kinds := best.keys()
	kinds.sort()
	for kind in kinds.slice(0, MAX_TURN_URLS):
		var hit: Array = best[kind]
		var entry := {}
		for e in out:
			if e.username == hit[1] and e.credential == hit[2]:
				entry = e
		if entry.is_empty():
			entry = {"urls": [], "username": hit[1], "credential": hit[2]}
			out.append(entry)
		(entry.urls as Array).append(hit[0])
	return out


# Kuerzt auf max_count, waehlt aber relay- und srflx-Kandidaten zuerst (sonst faellt
# TURN beim Kuerzen still weg). Die Originalreihenfolge bleibt.
static func limit_candidates(cands: Array, max_count: int) -> Array:
	if cands.size() <= max_count:
		return cands
	var picked := {}
	for typ in ["relay", "srflx", ""]:
		for i in cands.size():
			if picked.size() >= max_count:
				break
			if picked.has(i):
				continue
			if typ == "" or _cand_type(cands[i]) == typ:
				picked[i] = true
	var out := []
	for i in cands.size():
		if picked.has(i):
			out.append(cands[i])
	return out


static func _is_field(v) -> bool:
	return typeof(v) == TYPE_STRING and v != "" and (v as String).length() <= MAX_FIELD


# Art einer TURN-URL oder -1 (kein TURN, Port 53).
static func _kind(url: String) -> int:
	var tls := url.begins_with("turns:")
	if not tls and not url.begins_with("turn:"):
		return -1
	var parts := url.split("?", true, 1)
	var host_port: String = parts[0]
	var query: String = parts[1] if parts.size() > 1 else ""
	# Port 53 sperren Browser; ohne Trickle-ICE nur Wartezeit bis zum Zeitlimit.
	if host_port.ends_with(":53"):
		return -1
	if tls:
		return Kind.TLS_443 if host_port.ends_with(":443") else Kind.OTHER
	if query.contains("transport=tcp"):
		return Kind.TCP
	return Kind.UDP


static func _cand_type(c) -> String:
	if typeof(c) != TYPE_DICTIONARY:
		return ""
	var line := str(c.get("candidate", ""))
	var at := line.find(" typ ")
	if at < 0:
		return ""
	return line.substr(at + 5).get_slice(" ", 0)
