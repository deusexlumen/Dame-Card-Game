extends RefCounted

# Host: haelt den Raum der Partie offen, damit Gaeste nach einem Verbindungsverlust
# zurueckkommen (CONCEPT_DECISIONS §11). Ablauf im Raum:
#   Gast  -> rejoin {token}        (Schluessel aus dem welcome, nur der echte Gast kennt ihn)
#   Host  -> invite {code, peer}   (alte Verbindung abgebaut, neue Einladung fuer denselben Peer)
#   Gast  -> answer {code}
# Danach ist der Datenkanal offen, der Gast schickt hello ueber den Link und bekommt
# seinen Platz wie beim ersten Beitritt (DameHost.peer_joined).
# Kein Node: der Besitzer ruft poll() jedes Frame und close() am Ende.

const RETRY_MS := 3000
const MAX_TOKEN := 64

var rtc
var session
var room := ""
# func(peer_id) -> bool: darf dieser Peer zurueck (Platz nicht verloren)?
var allowed: Callable
# func() -> Signaling (Tests: Phoenix-Nachbau)
var make_signaling: Callable

var _sig = null
var _retry_at := 0
var _pending_peer := -1
var _invite := ""
var _closed := false


func _init(connector, host_session, room_code: String, signaling_factory: Callable, allow: Callable) -> void:
	rtc = connector
	session = host_session
	room = room_code
	make_signaling = signaling_factory
	allowed = allow
	rtc.invite_ready.connect(_on_invite)
	rtc.failed.connect(_on_rtc_failed)
	rtc.connected.connect(_on_rtc_connected)


func is_open() -> bool:
	return _sig != null and _sig.is_joined()


func poll() -> void:
	if _closed:
		return
	# Der Connector sammelt die ICE-Kandidaten neuer Einladungen nur in poll().
	rtc.poll()
	if _sig == null:
		if Time.get_ticks_msec() >= _retry_at:
			_open()
		return
	_sig.poll()


func close() -> void:
	if _closed:
		return
	_closed = true
	_reset_pending()
	var sig = _sig
	_sig = null
	if sig != null:
		sig.close()
	if rtc.invite_ready.is_connected(_on_invite):
		rtc.invite_ready.disconnect(_on_invite)
		rtc.failed.disconnect(_on_rtc_failed)
		rtc.connected.disconnect(_on_rtc_connected)


func _open() -> void:
	var sig = make_signaling.call()
	sig.event.connect(_on_signal)
	sig.failed.connect(_on_sig_failed)
	_sig = sig
	if not sig.open(room):
		_on_sig_failed("")


# Raum-Dienst weg: spaeter neu oeffnen. Laufende Einladung bleibt gueltig.
func _on_sig_failed(_reason: String) -> void:
	_sig = null
	_retry_at = Time.get_ticks_msec() + RETRY_MS


func _on_signal(name: String, payload: Dictionary) -> void:
	if name == "rejoin":
		var tok = payload.get("token")
		if typeof(tok) != TYPE_STRING or (tok as String).length() > MAX_TOKEN:
			return
		var peer: int = session.peer_of_token(tok)
		if peer < 0 or not bool(allowed.call(peer)):
			return
		if peer == _pending_peer:
			# Einladung schon unterwegs: fertige noch einmal schicken, sonst abwarten.
			_send_invite()
			return
		_pending_peer = peer
		_invite = ""
		# Der Gast meldet sich neu, also ist seine alte Verbindung tot, auch wenn
		# WebRTC das noch nicht bemerkt hat. Abbauen loest peer_left aus (§11 Stufe 1).
		rtc.drop_peer(peer)
		rtc.create_invite(peer)
	elif name == "answer":
		var code = payload.get("code")
		if _pending_peer < 0 or _invite == "" or typeof(code) != TYPE_STRING:
			return
		# Fremde oder alte Antworten lehnt der Connector ab (falsche Einladungs-ID).
		rtc.accept_answer(str(code))


func _on_invite(code: String) -> void:
	if _pending_peer < 0:
		return
	_invite = code
	_send_invite()


func _send_invite() -> void:
	if _invite != "" and _sig != null and _sig.is_joined():
		_sig.send_event("invite", {"code": _invite, "peer": _pending_peer})


# Einladung gescheitert: der Gast fragt mit rejoin erneut nach.
func _on_rtc_failed(_reason: String) -> void:
	_reset_pending()


func _on_rtc_connected(_link) -> void:
	_reset_pending()


func _reset_pending() -> void:
	_pending_peer = -1
	_invite = ""
