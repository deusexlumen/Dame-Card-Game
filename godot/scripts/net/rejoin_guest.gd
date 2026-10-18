extends RefCounted

# Gast: nach einem Verbindungsverlust automatisch zurueck an den Tisch
# (CONCEPT_DECISIONS §11, Gegenstueck zu rejoin_host.gd). Ablauf:
#   Raum betreten -> rejoin {token} (alle 3 s) -> invite {code, peer} -> neuer
#   RtcConnector -> answer {code} -> Datenkanal offen -> reconnected(link, connector).
# Danach schickt der Tisch hello ueber den neuen Link und bekommt seine Sicht.
# Aufgeben: nach 5 Minuten (§11 Stufe 3) oder wenn der Raum offen ist, aber der Host
# 30 s lang keine Einladung schickt (Host ist weg).
# Kein Node: der Besitzer ruft poll() jedes Frame und cancel() beim Verlassen.

const IceFetcher = preload("res://scripts/net/ice_fetcher.gd")

signal reconnected(link, connector)
signal gave_up(host_gone: bool)

const RETRY_MS := 3000
const HOST_SILENT_MS := 30000
const LIMIT_MS := 300000
const CONNECT_TIMEOUT_MS := 30000

var room := ""
var token := ""
var peer_id := -1
# func() -> Signaling, func() -> RtcConnector (Tests: Nachbauten)
var make_signaling: Callable
var make_connector: Callable
# TURN-Zugangsdaten vor dem ersten Versuch holen; leer = nur STUN.
var turn_url := ""
var limit_ms := LIMIT_MS
var host_silent_ms := HOST_SILENT_MS

var _sig = null
var _rtc = null
var _link = null
var _fetcher = null
# Nur mit TURN-Abruf gesetzt; sonst behaelt der Connector seine eigene Konfiguration.
var _ice: Dictionary = {}
var _started := false
var _done := false
var _deadline := 0
var _retry_at := 0
var _rejoin_at := 0
var _wait_since := 0


func _init(room_code: String, rejoin_token: String, own_peer: int, signaling_factory: Callable, connector_factory: Callable) -> void:
	room = room_code
	token = rejoin_token
	peer_id = own_peer
	make_signaling = signaling_factory
	make_connector = connector_factory


func is_done() -> bool:
	return _done


func poll() -> void:
	if _done:
		return
	var now := Time.get_ticks_msec()
	if not _started:
		_started = true
		_deadline = now + limit_ms
		if turn_url != "":
			_fetcher = IceFetcher.new()
			_fetcher.start(turn_url)
	if now > _deadline:
		_give_up(false)
		return
	if _fetcher != null:
		_fetcher.poll()
		if not _fetcher.is_done():
			return
		_ice = _fetcher.config
		_fetcher = null
	if _sig == null:
		if now >= _retry_at:
			_open()
		return
	_sig.poll()
	if _done or _sig == null:
		return
	if _rtc != null:
		_rtc.poll()
		# connected kommt mitten aus dem Peer-poll: Uebergabe erst hier.
		if _link != null:
			_finish()
		return
	if not _sig.is_joined():
		return
	if now >= _rejoin_at:
		_rejoin_at = now + RETRY_MS
		_sig.send_event("rejoin", {"token": token})
	if now - _wait_since > host_silent_ms:
		_give_up(true)


# Idempotent: alles schliessen, nichts mehr melden.
func cancel() -> void:
	_done = true
	_close_all()


func _open() -> void:
	var sig = make_signaling.call()
	sig.joined.connect(_on_joined)
	sig.event.connect(_on_signal)
	sig.failed.connect(_on_sig_failed)
	_sig = sig
	if not sig.open(room):
		_on_sig_failed("")


func _on_joined() -> void:
	_wait_since = Time.get_ticks_msec()
	_rejoin_at = 0


# Raum-Dienst nicht erreichbar (eigenes Netz weg): weiter versuchen bis zum Zeitlimit.
func _on_sig_failed(_reason: String) -> void:
	_sig = null
	_drop_rtc()
	_retry_at = Time.get_ticks_msec() + RETRY_MS


func _on_signal(name: String, payload: Dictionary) -> void:
	if name != "invite" or _rtc != null or _done:
		return
	var code = payload.get("code")
	var peer = payload.get("peer", -1)
	if typeof(code) != TYPE_STRING:
		return
	# Einladungen fuer andere Gaeste ignorieren.
	var numeric := typeof(peer) == TYPE_INT or typeof(peer) == TYPE_FLOAT
	if peer_id > 0 and (not numeric or int(peer) != peer_id):
		return
	var rtc = make_connector.call()
	if not _ice.is_empty():
		rtc.ice_config = _ice
	rtc.guest_timeout_ms = CONNECT_TIMEOUT_MS
	rtc.answer_ready.connect(_on_answer)
	rtc.connected.connect(_on_connected)
	rtc.failed.connect(_on_rtc_failed.bind(rtc.get_instance_id()))
	_rtc = rtc
	var r: Dictionary = rtc.join(str(code))
	if not bool(r.get("ok", false)) and _rtc == rtc:
		_on_rtc_failed("", rtc.get_instance_id())


func _on_answer(code: String) -> void:
	if _sig != null:
		_sig.send_event("answer", {"code": code})


func _on_connected(link) -> void:
	if _link == null:
		_link = link


# Versuch gescheitert: neuer Anlauf mit rejoin (der Host baut eine neue Einladung).
func _on_rtc_failed(_reason: String, rtc_id: int) -> void:
	if _rtc == null or _rtc.get_instance_id() != rtc_id:
		return
	_drop_rtc()
	_wait_since = Time.get_ticks_msec()
	_rejoin_at = 0


func _drop_rtc() -> void:
	var rtc = _rtc
	_rtc = null
	_link = null
	if rtc != null:
		rtc.close()


func _finish() -> void:
	var rtc = _rtc
	var link = _link
	_rtc = null
	_link = null
	_done = true
	_close_all()
	reconnected.emit(link, rtc)


func _give_up(host_gone: bool) -> void:
	_done = true
	_close_all()
	gave_up.emit(host_gone)


func _close_all() -> void:
	if _fetcher != null:
		_fetcher.close()
		_fetcher = null
	var sig = _sig
	_sig = null
	if sig != null:
		sig.close()
	_drop_rtc()
