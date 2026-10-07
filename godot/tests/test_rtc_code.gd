extends RefCounted

# Verbindungscode (RtcCode): Rundreise, Laenge und feindliche Eingaben.

const RtcCode = preload("res://scripts/net/rtc_code.gd")

# Realistisches Chrome-Angebot nur fuer einen Datenkanal (ICE-Kandidaten kommen separat).
const SDP := "v=0\r\no=- 4611731400430051336 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=group:BUNDLE 0\r\na=extmap-allow-mixed\r\na=msid-semantic: WMS\r\nm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\nc=IN IP4 0.0.0.0\r\na=ice-ufrag:Xk3f\r\na=ice-pwd:7vQ2hLw9ZpR4sT8uYb1nMc6d\r\na=ice-options:trickle\r\na=fingerprint:sha-256 4A:1F:9C:03:BB:7E:52:D8:61:AF:0C:E4:93:2B:77:15:C8:5D:A0:3E:F1:86:29:B4:7A:D3:60:1C:EE:95:48:0B\r\na=setup:actpass\r\na=mid:0\r\na=sctp-port:5000\r\na=max-message-size:262144\r\n"

const BROKEN := "Code unvollständig oder beschädigt."

var t


func run(ctx) -> void:
	t = ctx
	_check_roundtrip()
	_check_kinds()
	_check_hostile()
	_check_validation()


func _cands() -> Array:
	return [
		{"candidate": "candidate:842163049 1 udp 1677729535 203.0.113.7 51472 typ srflx raddr 192.168.1.20 rport 51472 generation 0 ufrag Xk3f network-cost 999", "sdpMid": "0", "sdpMLineIndex": 0},
		{"candidate": "candidate:1467250027 1 udp 2122260223 192.168.1.20 51472 typ host generation 0 ufrag Xk3f network-id 1", "sdpMid": "0", "sdpMLineIndex": 0},
		{"candidate": "candidate:3205941710 1 tcp 1518280447 192.168.1.20 9 typ host tcptype active generation 0 ufrag Xk3f network-id 1", "sdpMid": "0", "sdpMLineIndex": 0},
		{"candidate": "candidate:1110010283 1 udp 2122194687 10.0.0.5 62001 typ host generation 0 ufrag Xk3f network-id 2", "sdpMid": "0", "sdpMLineIndex": 0},
	]


func _bad(code: String, want: String, label: String, expect_kind := "") -> void:
	var r: Dictionary = RtcCode.decode(code, expect_kind)
	t.expect(not bool(r.get("ok", true)), label + ": ok == false")
	t.expect(str(r.get("error", "")) == want, label + ": Fehlertext (%s)" % str(r.get("error", "")))


func _check_roundtrip() -> void:
	var code: String = RtcCode.encode("offer", "AbC123", 2, SDP, _cands())
	print("RTC_CODE_LENGTH ", code.length())
	t.expect(code.begins_with("DAME1-"), "Praefix")
	t.expect(code.length() < 1500, "Code kuerzer als 1500 Zeichen (%d)" % code.length())
	t.expect(code.find("=") == -1 and code.find("+") == -1 and code.find("/") == -1, "URL-sicher, ohne Padding")
	var r: Dictionary = RtcCode.decode(code)
	t.expect(bool(r.ok), "Rundreise ok")
	t.expect(r.kind == "offer" and r.offer_id == "AbC123" and r.peer_id == 2, "Kopffelder")
	t.expect(r.sdp == SDP, "SDP identisch")
	t.expect(r.candidates == _cands(), "Kandidaten identisch")
	var chopped := code.substr(0, 40) + "\n" + code.substr(40, 50) + " \r\n\t" + code.substr(90)
	t.expect(bool(RtcCode.decode("  " + chopped + "\n").ok), "Whitespace toleriert")
	var a: Dictionary = RtcCode.decode(RtcCode.encode("answer", "AbC123", 2, SDP, []), "answer")
	t.expect(bool(a.ok) and a.kind == "answer" and a.candidates.is_empty(), "Antwort ohne Kandidaten")
	t.expect(RtcCode.matches_offer(a, "AbC123") and not RtcCode.matches_offer(a, "Other"), "matches_offer")
	t.expect(not RtcCode.matches_offer(r, "AbC123"), "matches_offer verlangt Antwort")
	t.expect(RtcCode.WRONG_OFFER == "Dieser Antwortcode gehört zu einer anderen Einladung.", "Konstante")


func _check_kinds() -> void:
	var offer: String = RtcCode.encode("offer", "x1", 2, SDP, [])
	var answer: String = RtcCode.encode("answer", "x1", 2, SDP, [])
	_bad(answer, "Das ist ein Antwortcode, kein Einladungscode.", "Antwort statt Einladung", "offer")
	_bad(offer, "Das ist ein Einladungscode, kein Antwortcode.", "Einladung statt Antwort", "answer")
	t.expect(RtcCode.encode("nonsense", "x1", 2, SDP, []) == "", "Unbekannter kind liefert leeren Code")


func _check_hostile() -> void:
	var code: String = RtcCode.encode("offer", "AbC123", 2, SDP, _cands())
	_bad("", BROKEN, "leer")
	_bad("   \n ", BROKEN, "nur Leerraum")
	_bad(code.substr(0, code.length() / 2), BROKEN, "abgeschnitten")
	_bad("DAME1-", BROKEN, "nur Praefix")
	_bad("XYZ9-" + code.substr(6), BROKEN, "falsches Praefix")
	_bad("DAME1-!!!!", BROKEN, "ungueltige Zeichen")
	var mid := 30
	var flipped := code.substr(0, mid) + ("A" if code[mid] != "A" else "B") + code.substr(mid + 1)
	var rf: Dictionary = RtcCode.decode(flipped)
	t.expect(not bool(rf.ok) or rf.sdp != SDP or rf.candidates != _cands(), "geaendertes Zeichen wird nie still akzeptiert")
	_bad(code + code.substr(6), BROKEN, "doppelt eingefuegt")
	_bad("DAME1-" + "A".repeat(200000), BROKEN, "gigantisch")
	_bad("DAME1-" + _raw("A".repeat(300000).to_utf8_buffer()), BROKEN, "Dekompressionsbombe")
	_bad("DAME1-" + _raw("A".repeat(300000).to_utf8_buffer(), 1000), BROKEN, "Dekompressionsbombe mit falschem Kopf")
	_bad("DAME1-" + _raw(var_to_bytes({"v": 1}), 99999), BROKEN, "Kopf ueber Grenze")
	_bad("DAME1-" + _raw(var_to_bytes([1, 2, 3])), BROKEN, "Array statt Dictionary")
	_bad("DAME1-" + _raw(var_to_bytes("text")), BROKEN, "String statt Dictionary")
	_bad("DAME1-" + _raw(var_to_bytes_with_objects(RefCounted.new())), BROKEN, "Objekt")
	var v2 := {"v": 2, "k": "offer", "id": "a", "p": 2, "sdp": "x", "c": []}
	_bad("DAME1-" + _raw(var_to_bytes(v2)), "Code von einer anderen Spielversion.", "Version 2")
	_bad("DAME2-" + code.substr(6), "Code von einer anderen Spielversion.", "Praefix DAME2")


func _check_validation() -> void:
	var base := {"v": 1, "k": "offer", "id": "a1", "p": 2, "sdp": "v=0", "c": []}
	t.expect(bool(RtcCode.decode("DAME1-" + _raw(var_to_bytes(base))).ok), "Basis gueltig")
	var mutations := {
		"kind Zahl": {"k": 5}, "kind unbekannt": {"k": "x"},
		"id leer": {"id": ""}, "id zu lang": {"id": "a".repeat(33)}, "id Sonderzeichen": {"id": "a-b"}, "id Zahl": {"id": 7},
		"peer 1": {"p": 1}, "peer 1001": {"p": 1001}, "peer String": {"p": "2"}, "peer Float": {"p": 2.5},
		"sdp Zahl": {"sdp": 1}, "sdp leer": {"sdp": ""}, "sdp zu lang": {"sdp": "a".repeat(16 * 1024 + 1)},
		"c kein Array": {"c": "x"},
		"c Element kein Dict": {"c": [1]},
		"c ohne candidate": {"c": [{"sdpMid": "0", "sdpMLineIndex": 0}]},
		"c candidate Zahl": {"c": [{"candidate": 1, "sdpMid": "0", "sdpMLineIndex": 0}]},
		"c Mid Zahl": {"c": [{"candidate": "c", "sdpMid": 0, "sdpMLineIndex": 0}]},
		"c Index String": {"c": [{"candidate": "c", "sdpMid": "0", "sdpMLineIndex": "0"}]},
		"c Index negativ": {"c": [{"candidate": "c", "sdpMid": "0", "sdpMLineIndex": -1}]},
	}
	var many: Array = []
	for i in 33:
		many.append({"candidate": "c", "sdpMid": "0", "sdpMLineIndex": 0})
	mutations["c zu viele"] = {"c": many}
	for label in mutations:
		var d: Dictionary = base.duplicate(true)
		for k in mutations[label]:
			d[k] = mutations[label][k]
		_bad("DAME1-" + _raw(var_to_bytes(d)), BROKEN, label)
	var missing: Dictionary = base.duplicate()
	missing.erase("sdp")
	_bad("DAME1-" + _raw(var_to_bytes(missing)), BROKEN, "Feld fehlt")


# Nutzlast wie encode: Kopf (Laengen), deflate, Base64 URL-sicher ohne Padding.
func _raw(bytes: PackedByteArray, claimed_size := -1) -> String:
	var deflated := bytes.compress(FileAccess.COMPRESSION_DEFLATE)
	var packed := PackedByteArray()
	packed.resize(8)
	packed.encode_u32(0, bytes.size() if claimed_size < 0 else claimed_size)
	packed.encode_u32(4, deflated.size())
	packed.append_array(deflated)
	var b64 := Marshalls.raw_to_base64(packed)
	return b64.replace("+", "-").replace("/", "_").replace("=", "")
