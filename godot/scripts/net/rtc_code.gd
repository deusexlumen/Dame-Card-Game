extends RefCounted

# Verbindungscode fuer die Handshake per Copy-Paste (Einladung/Antwort).
# Format: "DAME1-" + Base64-URL(deflate(var_to_bytes({...}))). Rein, ohne Node und ohne WebRTC.
# Kandidaten tragen die Godot-Felder "candidate", "sdpMid" (String) und "sdpMLineIndex" (int).

const I18n = preload("res://scripts/i18n.gd")

const PREFIX := "DAME1-"
const VERSION := 1
const MAX_CODE_CHARS := 40000    # Obergrenze fuer den eingefuegten Text
const MAX_INFLATED := 65536      # dekomprimiert hoechstens 64 KB
const MAX_SDP := 16 * 1024
const MAX_CANDIDATES := 32
const MAX_FIELD := 1024          # Laenge einzelner Kandidatenfelder
const MAX_ID_LEN := 32
const PEER_MIN := 2
const PEER_MAX := 1000

const ERR_BROKEN := "Code unvollständig oder beschädigt."
const ERR_VERSION := "Code von einer anderen Spielversion."
const ERR_IS_ANSWER := "Das ist ein Antwortcode, kein Einladungscode."
const ERR_IS_OFFER := "Das ist ein Einladungscode, kein Antwortcode."
const WRONG_OFFER := "Dieser Antwortcode gehört zu einer anderen Einladung."


# Gibt den Code zurueck, bei ungueltigen Eingaben "" (Aufrufer sind eigener Code).
static func encode(kind: String, offer_id: String, peer_id: int, sdp: String, candidates: Array) -> String:
	if kind != "offer" and kind != "answer":
		return ""
	var payload := {"v": VERSION, "k": kind, "id": offer_id, "p": peer_id, "sdp": sdp, "c": candidates}
	if _validate(payload) != "":
		return ""
	var raw := var_to_bytes(payload)
	var deflated := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	# Kopf: unkomprimierte und komprimierte Laenge (je 4 Byte). Damit gibt es keinen Rest hinter dem Strom.
	var packed := PackedByteArray()
	packed.resize(8)
	packed.encode_u32(0, raw.size())
	packed.encode_u32(4, deflated.size())
	packed.append_array(deflated)
	var b64 := Marshalls.raw_to_base64(packed)
	return PREFIX + b64.replace("+", "-").replace("/", "_").replace("=", "")


# Entfernt Leerraum, den Chat-Apps und Editoren beim Kopieren einstreuen: ASCII-
# Leerraum, geschuetzte Leerzeichen (U+00A0, U+202F), Nullbreitenzeichen
# (U+200B-U+200D, U+2060, U+FEFF) und sonstigen Unicode-Leerraum. Codezeichen bleiben.
static func clean(code: String) -> String:
	var out := ""
	for i in code.length():
		if not _is_space(code.unicode_at(i)):
			out += code[i]
	return out


static func _is_space(c: int) -> bool:
	if c <= 0x20 or c == 0x7F or c == 0x85 or c == 0xA0:
		return true
	if c >= 0x2000 and c <= 0x200D:
		return true
	return c in [0x1680, 0x180E, 0x2028, 0x2029, 0x202F, 0x205F, 0x2060, 0x3000, 0xFEFF]


static func decode(code: String, expect_kind: String = "") -> Dictionary:
	# Grobe Obergrenze vor dem zeichenweisen Reinigen (eingefuegter Text kann riesig sein).
	if code.length() > MAX_CODE_CHARS * 2:
		return _fail(ERR_BROKEN)
	var text := clean(code)
	if text.length() > MAX_CODE_CHARS:
		return _fail(ERR_BROKEN)
	if not text.begins_with(PREFIX):
		if _is_other_version(text):
			return _fail(ERR_VERSION)
		return _fail(ERR_BROKEN)
	var body := text.substr(PREFIX.length())
	if body.is_empty() or body.length() % 4 == 1 or not _is_b64url(body):
		return _fail(ERR_BROKEN)
	body = body.replace("-", "+").replace("_", "/")
	while body.length() % 4 != 0:
		body += "="
	var packed := Marshalls.base64_to_raw(body)
	if packed.size() <= 8:
		return _fail(ERR_BROKEN)
	var raw_size := packed.decode_u32(0)
	var deflated_size := packed.decode_u32(4)
	if raw_size == 0 or raw_size > MAX_INFLATED or deflated_size != packed.size() - 8:
		return _fail(ERR_BROKEN)
	# Nicht decompress_dynamic: das haengt bei Restbytes hinter dem Strom. Feste Puffergroesse ist sicher.
	var raw := packed.slice(8).decompress(raw_size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != raw_size:
		return _fail(ERR_BROKEN)
	var data: Variant = bytes_to_var(raw)  # nie bytes_to_var_with_objects
	if typeof(data) != TYPE_DICTIONARY:
		return _fail(ERR_BROKEN)
	var d: Dictionary = data
	if not d.has("v") or typeof(d["v"]) != TYPE_INT:
		return _fail(ERR_BROKEN)
	if int(d["v"]) != VERSION:
		return _fail(ERR_VERSION)
	if _validate(d) != "":
		return _fail(ERR_BROKEN)
	var kind: String = d["k"]
	if expect_kind != "" and kind != expect_kind:
		return _fail(ERR_IS_ANSWER if kind == "answer" else ERR_IS_OFFER)
	var cands: Array = []
	for c in (d["c"] as Array):
		cands.append({"candidate": c["candidate"], "sdpMid": c["sdpMid"], "sdpMLineIndex": c["sdpMLineIndex"]})
	return {"ok": true, "error": "", "kind": kind, "offer_id": d["id"], "peer_id": d["p"], "sdp": d["sdp"], "candidates": cands}


# Antwort gehoert zur aktuellen Einladung (Aufruf durch den Host).
static func matches_offer(decoded: Dictionary, offer_id: String) -> bool:
	return bool(decoded.get("ok", false)) and decoded.get("kind", "") == "answer" and decoded.get("offer_id", "") == offer_id


static func wrong_offer_text() -> String:
	return I18n.t(WRONG_OFFER)


# ---------- intern ----------

static func _fail(msg: String) -> Dictionary:
	var out := I18n.t(msg)
	return {"ok": false, "error": out, "kind": "", "offer_id": "", "peer_id": 0, "sdp": "", "candidates": []}


static func _is_other_version(text: String) -> bool:
	if not text.begins_with("DAME"):
		return false
	var i := 4
	while i < text.length() and text[i] >= "0" and text[i] <= "9":
		i += 1
	return i > 4 and i < text.length() and text[i] == "-"


static func _is_b64url(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 45 or c == 95
		if not ok:
			return false
	return true


static func _is_alnum(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)):
			return false
	return true


# "" wenn gueltig, sonst ein kurzer Grund (nur fuer Tests/Debug, Spieler sieht ERR_BROKEN).
static func _validate(d: Dictionary) -> String:
	for key in ["k", "id", "p", "sdp", "c"]:
		if not d.has(key):
			return "fehlt " + key
	if typeof(d["k"]) != TYPE_STRING or (d["k"] != "offer" and d["k"] != "answer"):
		return "kind"
	var id: Variant = d["id"]
	if typeof(id) != TYPE_STRING or (id as String).is_empty() or (id as String).length() > MAX_ID_LEN or not _is_alnum(id):
		return "id"
	var p: Variant = d["p"]
	if typeof(p) != TYPE_INT or int(p) < PEER_MIN or int(p) > PEER_MAX:
		return "peer"
	var sdp: Variant = d["sdp"]
	if typeof(sdp) != TYPE_STRING or (sdp as String).is_empty() or (sdp as String).length() > MAX_SDP:
		return "sdp"
	if typeof(d["c"]) != TYPE_ARRAY:
		return "c"
	var cands: Array = d["c"]
	if cands.size() > MAX_CANDIDATES:
		return "zu viele Kandidaten"
	for c in cands:
		if typeof(c) != TYPE_DICTIONARY:
			return "Kandidat"
		var cd: Dictionary = c
		if not cd.has("candidate") or typeof(cd["candidate"]) != TYPE_STRING:
			return "candidate"
		if (cd["candidate"] as String).length() > MAX_FIELD:
			return "candidate lang"
		if not cd.has("sdpMid") or typeof(cd["sdpMid"]) != TYPE_STRING or (cd["sdpMid"] as String).length() > MAX_FIELD:
			return "sdpMid"
		if not cd.has("sdpMLineIndex") or typeof(cd["sdpMLineIndex"]) != TYPE_INT:
			return "sdpMLineIndex"
		if int(cd["sdpMLineIndex"]) < 0 or int(cd["sdpMLineIndex"]) > 255:
			return "sdpMLineIndex Bereich"
	return ""
