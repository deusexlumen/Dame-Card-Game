extends RefCounted

# WebRTC-Verbindungsaufbau per Copy-Paste-Code (ohne Server, nicht-trickelnd).
# Host: start_host() -> create_invite(gast_peer_id) -> invite_ready(code)
#       -> accept_answer(antwortcode) -> connected(link).
#       Der Aufrufer vergibt die Gast-Peer-IDs 2, 3, ... ueber create_invite(guest_peer_id);
#       die ID steht im Einladungscode.
# Gast: join(einladungscode) -> answer_ready(code) -> connected(link).
#       Nach failed ist der Gast-Connector geschlossen; ein neuer Versuch braucht
#       einen neuen RtcConnector.
# Der Besitzer ruft poll() jedes Frame. Der ausgegebene PeerLink umhuellt den
# WebRTCMultiplayerPeer; den Peer nie multiplayer.multiplayer_peer zuweisen.
# close() immer aufrufen (native WebRTC-Threads halten sonst Godot am Leben).

const RtcCode = preload("res://scripts/net/rtc_code.gd")
const PeerLink = preload("res://scripts/net/peer_link.gd")
const I18n = preload("res://scripts/i18n.gd")

signal invite_ready(code: String)
signal answer_ready(code: String)
signal connected(link)
signal failed(reason: String)

const ICE_CONFIG := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]}
const HOST_PEER := 1
const GATHER_MAX_MS := 8000        # ICE-Sammlung hoechstens so lange
const OFFER_ID_LEN := 8
const ID_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

const TIMEOUT_TEXT := "Verbindung nicht zustande gekommen. Seid ihr beide online?"
const USED_TEXT := "Diese Einladung wurde schon benutzt."
const SETUP_TEXT := "Verbindung konnte nicht vorbereitet werden."

# Vor start_host()/join() setzbar (Tests: {"iceServers": []}, nur lokale Kandidaten).
var ice_config: Dictionary = ICE_CONFIG
# Host: Zeitlimit ab accept_answer (beide Seiten sind dann bereit).
var host_timeout_ms := 30000
# Gast: Zeitlimit ab answer_ready. Lang, weil ein Mensch die Antwort erst noch
# zum Host schicken muss (UI zeigt "Warte auf den Host ..." mit Abbrechen).
var guest_timeout_ms := 600000
var _mp: WebRTCMultiplayerPeer = null
var _link = null
var _is_host := false
var _closed := false
# Je Gast-Platz eine Verbindung: {peer_id, guest_id, offer_id, conn, sdp, candidates,
# started_ms, code_sent, answered, deadline_ms, connected, done}
var _slots: Array = []


# Echte WebRTC-Implementierung vorhanden? (Ohne Erweiterung liefert Godots Stub
# trotzdem OK aus initialize(), deshalb die Klasse der Erweiterung pruefen.)
static func is_available() -> bool:
	return OS.has_feature("web") or ClassDB.class_exists("WebRTCLibPeerConnection")


# ---------- Host ----------

func start_host() -> void:
	if _mp != null or _closed:
		return
	_is_host = true
	_mp = WebRTCMultiplayerPeer.new()
	_mp.create_server()
	_attach_link()


# Neue Einladung fuer den Gast-Platz guest_peer_id (2, 3, ...). Eine neuere
# Einladung fuer denselben Platz ersetzt die alte (alte Antworten passen nicht mehr).
func create_invite(guest_peer_id: int) -> void:
	if not _is_host or _closed:
		return
	if guest_peer_id < RtcCode.PEER_MIN or guest_peer_id > RtcCode.PEER_MAX:
		failed.emit(I18n.t(SETUP_TEXT))
		return
	var old: Dictionary = _slot_by_peer(guest_peer_id)
	if not old.is_empty():
		if bool(old.connected):
			failed.emit(I18n.t(USED_TEXT))
			return
		_drop_slot(old)
	var slot := _new_slot(guest_peer_id, guest_peer_id, _random_id())
	if slot.is_empty():
		return
	var conn: WebRTCPeerConnection = slot.conn
	# add_peer legt die Datenkanaele an, deshalb vor create_offer().
	if _mp.add_peer(conn, guest_peer_id) != OK or conn.create_offer() != OK:
		_drop_slot(slot)
		failed.emit(I18n.t(SETUP_TEXT))


func accept_answer(code: String) -> Dictionary:
	var d: Dictionary = RtcCode.decode(code, "answer")
	if not bool(d.ok):
		return {"ok": false, "error": str(d.error)}
	if not _is_host or _closed:
		return {"ok": false, "error": RtcCode.wrong_offer_text()}
	var slot: Dictionary = {}
	for s in _slots:
		if RtcCode.matches_offer(d, str(s.offer_id)):
			slot = s
	if slot.is_empty():
		return {"ok": false, "error": RtcCode.wrong_offer_text()}
	if bool(slot.answered) or bool(slot.connected) or bool(slot.done):
		return {"ok": false, "error": I18n.t(USED_TEXT)}
	if int(d.peer_id) != int(slot.peer_id):
		return {"ok": false, "error": I18n.t(RtcCode.ERR_BROKEN)}
	var conn: WebRTCPeerConnection = slot.conn
	slot.answered = true
	if conn.set_remote_description("answer", str(d.sdp)) != OK:
		# Unbrauchbare Antwort: Platz still freigeben, der Host macht eine neue Einladung.
		_drop_slot(slot)
		return {"ok": false, "error": I18n.t(RtcCode.ERR_BROKEN)}
	_add_candidates(conn, d.candidates)
	slot.deadline_ms = Time.get_ticks_msec() + host_timeout_ms
	return {"ok": true, "error": ""}


# ---------- Gast ----------

func join(code: String) -> Dictionary:
	var d: Dictionary = RtcCode.decode(code, "offer")
	if not bool(d.ok):
		return {"ok": false, "error": str(d.error)}
	if _mp != null or _closed or _is_host:
		return {"ok": false, "error": I18n.t(USED_TEXT)}
	var guest_id: int = int(d.peer_id)
	_mp = WebRTCMultiplayerPeer.new()
	if _mp.create_client(guest_id) != OK:
		return _join_failed()
	_attach_link()
	var slot := _new_slot(HOST_PEER, guest_id, str(d.offer_id))
	if slot.is_empty():
		return _join_failed()
	var conn: WebRTCPeerConnection = slot.conn
	if _mp.add_peer(conn, HOST_PEER) != OK or conn.set_remote_description("offer", str(d.sdp)) != OK:
		return _join_failed()
	_add_candidates(conn, d.candidates)
	return {"ok": true, "error": ""}


# ---------- Beide ----------

func poll() -> void:
	if _closed or _mp == null:
		return
	_mp.poll()
	var now := Time.get_ticks_msec()
	for slot in _slots.duplicate():
		if bool(slot.done) or bool(slot.connected):
			continue
		if not bool(slot.code_sent):
			_check_gathering(slot, now)
			continue
		var conn: WebRTCPeerConnection = slot.conn
		var state := conn.get_connection_state()
		var dead := state == WebRTCPeerConnection.STATE_FAILED or state == WebRTCPeerConnection.STATE_CLOSED
		var late := int(slot.deadline_ms) > 0 and now > int(slot.deadline_ms)
		if dead or late:
			_fail_slot(slot, I18n.t(TIMEOUT_TEXT))


func is_closed() -> bool:
	return _closed


# Sicherheitsnetz, falls der Besitzer close() vergisst.
func _notification(what: int) -> void:
	# Hier keine Methoden aufrufen (self ist beim Abbau schon ungueltig), nur Felder.
	if what != NOTIFICATION_PREDELETE or _closed:
		return
	_closed = true
	for slot in _slots:
		(slot.conn as WebRTCPeerConnection).close()
	if _mp != null:
		_mp.close()


# Idempotent: schliesst alle Peer-Verbindungen und den Multiplayer-Peer.
func close() -> void:
	if _closed:
		return
	_closed = true
	for slot in _slots:
		slot.done = true
		(slot.conn as WebRTCPeerConnection).close()
	_slots.clear()
	if _mp != null:
		_mp.close()
	_mp = null
	_link = null


# ---------- intern ----------

func _attach_link() -> void:
	_link = PeerLink.new(_mp)
	_mp.peer_connected.connect(_on_peer_connected)


# Datenkanaele offen: einmal je Gast-Platz (beim Gast genau einmal, fuer Peer 1).
func _on_peer_connected(id: int) -> void:
	var slot := _slot_by_peer(id)
	if slot.is_empty() or bool(slot.connected):
		return
	slot.connected = true
	connected.emit(_link)


# peer_id: Gegenstelle im WebRTCMultiplayerPeer; guest_id: Gast-Peer-ID im Code.
func _new_slot(peer_id: int, guest_id: int, offer_id: String) -> Dictionary:
	var conn := WebRTCPeerConnection.new()
	if conn.initialize(ice_config) != OK:
		failed.emit(I18n.t(SETUP_TEXT))
		return {}
	var slot := {
		"peer_id": peer_id, "guest_id": guest_id, "offer_id": offer_id, "conn": conn,
		"sdp": "", "candidates": [], "started_ms": Time.get_ticks_msec(),
		"code_sent": false, "answered": false, "deadline_ms": 0, "connected": false, "done": false,
	}
	conn.session_description_created.connect(_on_session.bind(slot))
	conn.ice_candidate_created.connect(_on_candidate.bind(slot))
	_slots.append(slot)
	return slot


func _on_session(type: String, sdp: String, slot: Dictionary) -> void:
	if bool(slot.done):
		return
	slot.sdp = sdp
	(slot.conn as WebRTCPeerConnection).set_local_description(type, sdp)


func _on_candidate(media: String, index: int, name: String, slot: Dictionary) -> void:
	if bool(slot.done):
		return
	(slot.candidates as Array).append({"candidate": name, "sdpMid": media, "sdpMLineIndex": index})


# Nicht-trickelnd: Code erst, wenn die ICE-Sammlung fertig ist (hoechstens GATHER_MAX_MS).
func _check_gathering(slot: Dictionary, now: int) -> void:
	var conn: WebRTCPeerConnection = slot.conn
	var complete := conn.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE
	var overdue := now - int(slot.started_ms) >= GATHER_MAX_MS
	if str(slot.sdp) == "":
		if overdue:
			_fail_slot(slot, I18n.t(SETUP_TEXT))
		return
	if not (complete or overdue):
		return
	var cands: Array = slot.candidates
	if cands.size() > RtcCode.MAX_CANDIDATES:
		cands = cands.slice(0, RtcCode.MAX_CANDIDATES)
	var kind := "offer" if _is_host else "answer"
	var code: String = RtcCode.encode(kind, str(slot.offer_id), int(slot.guest_id), str(slot.sdp), cands)
	slot.code_sent = true
	if code == "" or cands.is_empty():
		_fail_slot(slot, I18n.t(SETUP_TEXT))
		return
	if _is_host:
		invite_ready.emit(code)
	else:
		# Gast: ab jetzt laeuft das Zeitlimit (der Host muss die Antwort noch einfuegen).
		slot.deadline_ms = Time.get_ticks_msec() + guest_timeout_ms
		answer_ready.emit(code)


func _add_candidates(conn: WebRTCPeerConnection, cands: Array) -> void:
	for c in cands:
		conn.add_ice_candidate(str(c.sdpMid), int(c.sdpMLineIndex), str(c.candidate))


# Gescheiterte Verbindung sofort abbauen: Host gibt den Platz fuer eine neue
# Einladung frei, der Gast schliesst den ganzen Connector.
func _fail_slot(slot: Dictionary, reason: String) -> void:
	if _is_host:
		_drop_slot(slot)
	else:
		close()
	failed.emit(reason)


func _drop_slot(slot: Dictionary) -> void:
	slot.done = true
	if _is_host and _mp != null and _mp.has_peer(int(slot.peer_id)):
		_mp.remove_peer(int(slot.peer_id))
	(slot.conn as WebRTCPeerConnection).close()
	_slots.erase(slot)


func _slot_by_peer(peer_id: int) -> Dictionary:
	for s in _slots:
		if int(s.peer_id) == peer_id and not bool(s.done):
			return s
	return {}


func _join_failed() -> Dictionary:
	close()
	return {"ok": false, "error": I18n.t(SETUP_TEXT)}


func _random_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(OFFER_ID_LEN)
	var out := ""
	for b in bytes:
		out += ID_CHARS[b % ID_CHARS.length()]
	return out
