extends RefCounted

# Online-Testbildschirm (Online 2, Task 6): Codes tauschen, dann an den Tisch.
# Ohne Netz: Laden, kaputte Codes, Eingabe-Reinigung, WebRTC fehlt, Texte DE/EN,
# Besitz-Uebergabe (Connector reist mit dem Auftrag zum Tisch, ENet-Link).
# Mit webrtc-native: zwei Bildschirme verbinden sich echt (nur lokale Kandidaten),
# die Bildschirme werden freigegeben, die Tische spielen ueber dieselbe Verbindung weiter.
# Jede Warteschleife hat eine harte Obergrenze; alle Verbindungen werden geschlossen.

const OnlineScene = preload("res://scenes/online.tscn")
const OnlineScreen = preload("res://scripts/screens/online_screen.gd")
const TableScene = preload("res://scenes/table.tscn")
const MainMenuScene = preload("res://scenes/main_menu.tscn")
const RtcConnector = preload("res://scripts/net/rtc_connector.gd")
const RtcCode = preload("res://scripts/net/rtc_code.gd")
const PeerLink = preload("res://scripts/net/peer_link.gd")
const I18n = preload("res://scripts/i18n.gd")
const NetCodec = preload("res://scripts/net/net_codec.gd")

const WAIT_CAP_MS := 15000
const LOCAL_ICE := {"iceServers": []}
const SKIP_LINE := "TEST_SKIP test_online_screen: WebRTC-Erweiterung fehlt – echter Bildschirm-zu-Tisch-Test übersprungen"
const PORT_FIRST := 24800
const PORT_LAST := 24860

var t
var app
var _screens: Array = []
var _tables: Array = []
var _conns: Array = []
var _peers: Array = []


# Zaehlt close()-Aufrufe (Ersatz-Besitzer fuer den Uebergabetest ohne WebRTC).
class FakeOwner:
	extends RefCounted
	var closes := 0
	func close() -> void:
		closes += 1


func run(ctx) -> void:
	t = ctx
	app = ctx.root.get_node_or_null("/root/App")
	if app == null:
		t.expect(false, "App-Autoload fehlt")
		return
	var save_before: Dictionary = app.saves.load_match()
	var checks: Array[Callable] = [_check_loads, _check_texts, _check_clean, _check_unavailable,
			_check_broken_codes, _check_main_menu, _check_owner_handoff_enet, _check_abort_closes_owner]
	for check in checks:
		check.call()
		_cleanup()
	if not RtcConnector.is_available():
		print(SKIP_LINE)
		t.expect(OS.get_environment("DAME_REQUIRE_WEBRTC") != "1", "WebRTC-Erweiterung fehlt, DAME_REQUIRE_WEBRTC=1 verlangt sie")
	else:
		var rtc_checks: Array[Callable] = [_check_dropped_connector_kills_link, _check_guest_retry,
				_check_screen_to_table, _check_guest_no_start, _check_guest_rejected, _check_guest_lost]
		for check in rtc_checks:
			check.call()
			_cleanup()
	app.pending = {}
	t.expect(app.saves.load_match() == save_before, "Online-Bildschirm hat den Spielstand veraendert")


# ---------- Hilfen ----------

func _screen(available := 1):
	var s = OnlineScene.instantiate()
	s.ice_config = LOCAL_ICE
	s.webrtc_override = available
	t.root.add_child(s)
	_screens.append(s)
	return s


func _new_table():
	var tb = TableScene.instantiate()
	tb.instant_ai = true
	tb.settings_override = {"memory_aid": true, "turn_timer": false, "animations": false}
	_tables.append(tb)
	return tb


func _free(n) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.free()


# Tische zuerst (schliessen ihre Verbindungen), dann Bildschirme, Connectoren, Peers.
func _cleanup() -> void:
	for tb in _tables:
		_free(tb)
	_tables.clear()
	for s in _screens:
		_free(s)
	_screens.clear()
	for c in _conns:
		c.close()
	_conns.clear()
	for p in _peers:
		p.close()
	_peers.clear()
	app.pending = {}
	app.last_goto = ""


func _wait(cond: Callable, what: String) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < WAIT_CAP_MS:
		if cond.call():
			return true
		OS.delay_msec(5)
	t.expect(false, "Zeitueberschreitung beim Warten auf: " + what)
	return false


# Fuegt Zeichen ein, die Chat-Apps beim Kopieren einstreuen.
static func _dirty(code: String) -> String:
	var nbsp := String.chr(0x00A0)
	var zw := String.chr(0x200B) + String.chr(0x200C) + String.chr(0x200D) + String.chr(0xFEFF) 			+ String.chr(0x200E) + String.chr(0x200F) + String.chr(0x180B) + String.chr(0x180C) + String.chr(0x180D)
	var mid := code.length() / 2
	return zw + " " + code.substr(0, 10) + nbsp + code.substr(10, mid - 10) + String.chr(0x2009) + "\n" \
			+ code.substr(mid, 5) + zw + code.substr(mid + 5) + String.chr(0x3000) + nbsp


# ---------- ohne Netz ----------

func _check_loads() -> void:
	var s = _screen()
	t.expect(s.is_inside_tree() and s.content != null, "Online-Bildschirm laedt nicht")
	t.expect(s.host_box.visible and s.guest_box.visible, "Hosten/Beitreten nicht sichtbar")
	t.expect(not s.unavailable_label.visible, "WebRTC-fehlt-Text trotz WebRTC sichtbar")
	t.expect(s.privacy_label.visible and s.privacy_label.text == OnlineScreen.PRIVACY_TEXT, "Datenschutzhinweis fehlt")
	t.expect(s.seat_option.item_count == 3, "Spieleranzahl nicht 2-4")
	t.expect(s.invite_edit.editable == false, "Einladungscode-Feld ist beschreibbar")
	for b in [s.invite_button, s.invite_copy_button, s.connect_button, s.join_button, s.answer_copy_button, s.cancel_button]:
		t.expect(b.custom_minimum_size.y >= 44, "Knopf kleiner als 44 px: " + b.text)
	for e in [s.invite_edit, s.answer_in_edit, s.join_edit, s.answer_out_edit]:
		t.expect(e.custom_minimum_size.y >= 44, "Feld kleiner als 44 px")
	t.expect(not s.cancel_button.visible, "Abbrechen vor dem Beitreten sichtbar")
	# Zurueck schliesst alles und geht ins Hauptmenue.
	s.go_back()
	t.expect(app.last_goto == app.MAIN_MENU, "Zurueck geht nicht ins Hauptmenue")


func _check_texts() -> void:
	for text in OnlineScreen.TEXTS:
		t.expect(I18n.EN.has(text), "Englisch fehlt: " + str(text))
	t.expect(OnlineScreen.PRIVACY_TEXT == "Der Code enthält deine IP-Adresse. Teile ihn nur mit Leuten, mit denen du spielen willst.", "Datenschutztext falsch")
	t.expect(OnlineScreen.TEXTS.has(OnlineScreen.PRIVACY_TEXT) and OnlineScreen.TEXTS.has("Online (Test)"), "Textliste unvollstaendig")
	t.expect(I18n.EN.has("Online (Test)"), "Menuetext Englisch fehlt")


func _check_clean() -> void:
	var code := RtcCode.encode("offer", "AbCd1234", 2, "v=0\r\n", [{"candidate": "candidate:1 1 udp 1 1.2.3.4 5 typ host", "sdpMid": "0", "sdpMLineIndex": 0}])
	t.expect(code != "", "Testcode nicht erzeugt")
	var dirty := _dirty(code)
	t.expect(dirty != code, "Schmutz nicht eingefuegt")
	t.expect(RtcCode.clean(dirty) == code, "Reinigung entfernt nicht alle Leerraum-/Nullbreitenzeichen")
	var d: Dictionary = RtcCode.decode(dirty, "offer")
	t.expect(bool(d.ok) and str(d.offer_id) == "AbCd1234", "Code mit NBSP/Nullbreite nicht lesbar: " + str(d.get("error", "")))
	t.expect(OnlineScreen.clean_code(dirty) == code, "Bildschirm-Reinigung abweichend")
	# Echte Zeichen im Code bleiben unangetastet.
	t.expect(RtcCode.clean("DAME1-Ab_c-9") == "DAME1-Ab_c-9", "Reinigung veraendert Codezeichen")


func _check_unavailable() -> void:
	var s = _screen(0)
	t.expect(s.unavailable_label.visible and s.unavailable_label.text == OnlineScreen.UNAVAILABLE_TEXT, "WebRTC-fehlt-Text nicht sichtbar")
	t.expect(not s.host_box.visible and not s.guest_box.visible, "Knoepfe trotz fehlendem WebRTC sichtbar")
	t.expect(s.back_button != null and s.back_button.visible, "Zurueck fehlt ohne WebRTC")
	# Ohne Override entscheidet die Erkennung.
	t.expect(OnlineScreen.detect_webrtc() == RtcConnector.is_available(), "WebRTC-Erkennung weicht ab")


func _check_broken_codes() -> void:
	var s = _screen()
	s.join_edit.text = "DAME1-kaputt"
	s.join_button.pressed.emit()
	t.expect(s.guest_error.text == I18n.t(RtcCode.ERR_BROKEN), "Kaputter Einladungscode ohne Fehlertext: " + s.guest_error.text)
	t.expect(not s.join_button.disabled and s.join_edit.editable, "Weiter nach Fehler nicht bedienbar")
	t.expect(s._guest_rtc == null, "Gescheiterter Gast-Connector bleibt liegen")
	t.expect(app.pending.is_empty() and app.last_goto == "", "Kaputter Code wechselt die Szene")
	# Nochmal: wieder ein sauberer Fehler, kein "schon benutzt".
	s.guest_join("Unsinn")
	t.expect(s.guest_error.text == I18n.t(RtcCode.ERR_BROKEN), "Zweiter Versuch ohne sauberen Fehler: " + s.guest_error.text)
	var answer_code := RtcCode.encode("answer", "AbCd1234", 2, "v=0\r\n", [])
	s.guest_join(answer_code)
	t.expect(s.guest_error.text == I18n.t(RtcCode.ERR_IS_ANSWER), "Antwortcode als Einladung ohne Fehlertext")
	# Host: Verbinden ohne Einladung und mit kaputtem Code.
	s.answer_in_edit.text = "irgendwas"
	s.connect_button.pressed.emit()
	t.expect(s.host_error.text == OnlineScreen.NO_INVITE_TEXT, "Verbinden ohne Einladung ohne Fehlertext: " + s.host_error.text)
	t.expect(not s.connect_button.disabled and not s.invite_button.disabled, "Host-Knoepfe nach Fehler gesperrt")
	# Leeres Feld
	s.guest_join("   ")
	t.expect(s.guest_error.text != "", "Leerer Einladungscode ohne Fehlertext")
	# Englisch: Fehler in Englisch
	I18n.install("en")
	s.guest_join("kaputt")
	t.expect(s.guest_error.text == "Code incomplete or damaged." or s.guest_error.text == I18n.EN[RtcCode.ERR_BROKEN], "Fehler nicht englisch: " + s.guest_error.text)
	I18n.install("de")


func _check_main_menu() -> void:
	var menu = MainMenuScene.instantiate()
	t.root.add_child(menu)
	_screens.append(menu)
	var found = null
	for b in menu.buttons:
		if b.text == "Online (Test)":
			found = b
	t.expect(found != null, "Hauptmenue ohne Online (Test)")
	if found != null:
		found.pressed.emit()
		t.expect(app.last_goto == app.ONLINE, "Online (Test) oeffnet nicht online.tscn")
	t.expect(app.online_screen() == app.ONLINE, "Tisch faellt noch aufs Hauptmenue zurueck")


func _enet_pair() -> Array:
	for port in range(PORT_FIRST, PORT_LAST + 1):
		var s := ENetMultiplayerPeer.new()
		if s.create_server(port, 2) == OK:
			_peers.append(s)
			var c := ENetMultiplayerPeer.new()
			c.create_client("127.0.0.1", port)
			_peers.append(c)
			_wait(func():
				s.poll()
				c.poll()
				return c.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, "ENet-Verbindung")
			return [s, c]
	t.expect(false, "Kein freier Port")
	return []


# Der Besitzer der Verbindung reist im App-Auftrag mit und wird vom Tisch geschlossen.
func _check_owner_handoff_enet() -> void:
	var pair := _enet_pair()
	if pair.is_empty():
		return
	var owner := FakeOwner.new()
	var owner_ref: WeakRef = weakref(owner)
	var link = PeerLink.new(pair[0])
	app.online_host_match({"config": {"seed": 5, "seat_count": 3, "ai_seats": [2], "names": ["Host", "Gast", "KI"]},
			"link": link, "host_seat": 0, "guest_seats": {2: 1}, "owner": owner})
	t.expect(app.pending.get("owner") == owner, "App verliert den Besitzer im Host-Auftrag")
	owner = null
	link = null
	var tb = _new_table()
	t.root.add_child(tb)
	t.expect(app.pending.is_empty(), "Host-Auftrag nicht abgeholt")
	t.expect(owner_ref.get_ref() != null, "Besitzer nicht vom Tisch gehalten")
	t.expect(owner_ref.get_ref() != null and owner_ref.get_ref().closes == 0, "Besitzer zu frueh geschlossen")
	var held = owner_ref.get_ref()
	_free(tb)
	t.expect(held.closes >= 1, "Tisch schliesst den Besitzer beim Verlassen nicht")
	held = null
	# Gast-Auftrag: Besitzer als zweiter Parameter.
	var guest_owner := FakeOwner.new()
	var guest_link = PeerLink.new(pair[1])
	var session = load("res://scripts/net/dame_guest.gd").new(guest_link)
	app.online_guest_match(session, guest_owner)
	t.expect(app.pending.get("owner") == guest_owner, "App verliert den Besitzer im Gast-Auftrag")
	var gt = _new_table()
	t.root.add_child(gt)
	t.expect(gt._net_owner == guest_owner and guest_owner.closes == 0, "Gast-Tisch haelt den Besitzer nicht")
	gt._close_link()
	t.expect(guest_owner.closes == 1, "_close_link schliesst den Besitzer nicht")
	_free(gt)


# Kaputter Online-Auftrag: Link und Besitzer werden geschlossen, nie liegen gelassen.
func _check_abort_closes_owner() -> void:
	var owner := FakeOwner.new()
	app.online_host_match({"config": {}, "link": null, "owner": owner})
	var tb = _new_table()
	t.root.add_child(tb)
	t.expect(owner.closes >= 1, "Abbruch schliesst den Besitzer nicht")
	t.expect(app.last_goto == app.ONLINE, "Abbruch geht nicht zum Online-Bildschirm")
	_free(tb)
	var g_owner := FakeOwner.new()
	app.online_guest_match(null, g_owner)
	var gt = _new_table()
	t.root.add_child(gt)
	t.expect(g_owner.closes >= 1, "Gast-Abbruch schliesst den Besitzer nicht")


# ---------- mit WebRTC ----------

func _make() -> RtcConnector:
	var c := RtcConnector.new()
	c.ice_config = LOCAL_ICE
	_conns.append(c)
	return c


# Gegenprobe: ein freigegebener Connector reisst seine Verbindung mit (deshalb muss
# der Tisch ihn halten). Aufbau in einer Hilfsfunktion: deren Lambdas (halten den
# Connector) verschwinden mit ihrem Stapelrahmen.
func _check_dropped_connector_kills_link() -> void:
	var pair := _raw_pair()
	if pair.is_empty():
		return
	var hlink = pair.hlink
	var host_ref: WeakRef = weakref(pair.host)
	t.expect(hlink.is_open(), "Host-Link nicht offen")
	pair.clear()  # letzter Verweis: PREDELETE schliesst den Peer
	t.expect(host_ref.get_ref() == null, "Gegenprobe: Connector nicht freigegeben")
	t.expect(not hlink.is_open(), "Gegenprobe: freigegebener Connector laesst die Verbindung offen")
	if host_ref.get_ref() != null:
		host_ref.get_ref().close()


# Host-Connector (nicht in _conns) und Gast-Connector (in _conns), verbunden.
func _raw_pair() -> Dictionary:
	var host := RtcConnector.new()
	host.ice_config = LOCAL_ICE
	var guest := _make()
	var st := {"invite": "", "answer": "", "hlink": null, "glink": null}
	host.invite_ready.connect(func(c): st.invite = c)
	guest.answer_ready.connect(func(c): st.answer = c)
	host.connected.connect(func(l): st.hlink = l)
	guest.connected.connect(func(l): st.glink = l)
	host.start_host()
	host.create_invite(2)
	var ok := _wait(func():
		host.poll()
		guest.poll()
		if st.invite != "" and not st.has("joined"):
			st.joined = true
			guest.join(st.invite)
		if st.answer != "" and not st.has("accepted"):
			st.accepted = true
			host.accept_answer(st.answer)
		return st.hlink != null and st.glink != null, "Verbindung (Gegenprobe)")
	if not ok:
		host.close()
		return {}
	return {"host": host, "hlink": st.hlink}


func _check_guest_retry() -> void:
	var host := _make()
	var st := {"invite": ""}
	host.invite_ready.connect(func(c): st.invite = c)
	host.start_host()
	host.create_invite(2)
	if not _wait(func():
		host.poll()
		return st.invite != "", "Einladung"):
		return
	var s = _screen()
	s.guest_join(st.invite)
	var first = s._guest_rtc
	t.expect(first != null and s.guest_error.text == "", "Beitreten mit gueltigem Code scheitert: " + s.guest_error.text)
	t.expect(s.cancel_button.visible, "Abbrechen nicht sichtbar")
	t.expect(s.join_button.disabled, "Weiter waehrend laufendem Beitritt bedienbar")
	s.cancel_button.pressed.emit()
	t.expect(not s.join_button.disabled, "Weiter nach Abbrechen gesperrt")
	t.expect(first.is_closed() and s._guest_rtc == null, "Abbrechen schliesst den Connector nicht")
	t.expect(not s.cancel_button.visible and s.answer_out_edit.text == "" and s.join_edit.editable, "Abbrechen setzt den Bildschirm nicht zurueck")
	s.guest_join(_dirty(st.invite))
	t.expect(s._guest_rtc != null and s._guest_rtc != first, "Neuer Versuch ohne neuen Connector")
	t.expect(s.guest_error.text == "", "Neuer Versuch mit Fehler: " + s.guest_error.text)
	if not _wait(func():
		host.poll()
		s.poll_net()
		return s.answer_out_edit.text != "", "Antwortcode nach erneutem Versuch"):
		return
	t.expect(s.guest_status.text == OnlineScreen.WAIT_HOST_TEXT, "Status nicht 'Warte auf den Host'")
	t.expect(s.join_button.disabled, "Weiter bei angezeigter Antwort bedienbar")
	t.expect(RtcCode.decode(s.answer_out_edit.text, "answer").ok, "Antwortcode im Feld ungueltig")
	# Host-Fehler: falscher Code im Antwortfeld des Host-Bildschirms.
	var hs = _screen()
	hs.host_accept(s.answer_out_edit.text)
	t.expect(hs.host_error.text == OnlineScreen.NO_INVITE_TEXT, "Fremde Antwort ohne Einladung angenommen")


# Kern: Host- und Gast-Bildschirm verbinden sich, beide Bildschirme verschwinden,
# die Tische spielen ueber dieselbe WebRTC-Verbindung weiter.
func _check_screen_to_table() -> void:
	var refs := _connect_screens()
	if refs.is_empty():
		return
	var host_table = refs.host_table
	var guest_table = refs.guest_table
	t.expect(refs.host_rtc.get_ref() != null and not refs.host_rtc.get_ref().is_closed(), "Host-Connector nach Bildschirmwechsel geschlossen")
	t.expect(refs.guest_rtc.get_ref() != null and not refs.guest_rtc.get_ref().is_closed(), "Gast-Connector nach Bildschirmwechsel geschlossen")
	t.expect(host_table.session.link.is_open() and guest_table.session.link.is_open(), "Link nach Bildschirmwechsel zu")
	t.expect(host_table.session.seat_of(2) == 1, "Gast nicht auf Platz 2 (Index 1)")
	t.expect(int(guest_table.viewer_seat) == 1, "Gast-Tisch falscher Platz")
	# Verkehr nach dem Wechsel: neue Sichten kommen an.
	var rev_before := int(guest_table.session.rev)
	host_table.session.broadcast()
	_wait(func():
		host_table.session.poll()
		guest_table.session.poll()
		return int(guest_table.session.rev) == int(host_table.session.rev) and int(guest_table.session.rev) > rev_before, "Sicht nach Bildschirmwechsel")
	# Rundweg Gast -> Host -> Gast: eine Aktion des Gastes bekommt ein Ergebnis.
	var results: Array = []
	guest_table.session.action_result.connect(func(r): results.append(r))
	guest_table.session.send_action({"type": "end_turn"})
	_wait(func():
		host_table.session.poll()
		guest_table.session.poll()
		return not results.is_empty(), "Ergebnis einer Gast-Aktion")
	var host_rev := int(host_table.session.rev)
	# Tische verlassen: Verbindung und Connectoren zu.
	var hrtc = refs.host_rtc.get_ref()
	var grtc = refs.guest_rtc.get_ref()
	refs.clear()
	_free(host_table)
	_free(guest_table)
	_tables.clear()
	t.expect(hrtc == null or hrtc.is_closed(), "Host-Connector nach Tisch-Ende offen")
	t.expect(grtc == null or grtc.is_closed(), "Gast-Connector nach Tisch-Ende offen")
	t.expect(host_rev >= 1, "Host ohne Sicht")


# Liefert nur Schwachverweise und die Tische; die Bildschirme sind danach freigegeben.
func _connect_screens() -> Dictionary:
	app.pending = {}
	var hs = _screen()
	var gs = _screen()
	hs.seat_option.select(1)  # 3 Plaetze: Host, Gast, KI
	hs.invite_button.pressed.emit()
	if not _wait(func():
		hs.poll_net()
		return hs.invite_edit.text != "", "Einladungscode im Bildschirm"):
		return {}
	var host_rtc: WeakRef = weakref(hs._host_rtc)
	gs.join_edit.text = _dirty(hs.invite_edit.text)
	gs.join_button.pressed.emit()
	if not _wait(func():
		hs.poll_net()
		gs.poll_net()
		return gs.answer_out_edit.text != "", "Antwortcode im Bildschirm"):
		return {}
	var guest_rtc: WeakRef = weakref(gs._guest_rtc)
	hs.answer_in_edit.text = _dirty(gs.answer_out_edit.text)
	hs.connect_button.pressed.emit()
	t.expect(hs.host_error.text == "", "Host lehnt Antwort ab: " + hs.host_error.text)
	# Waehrend der Verbindung keine neue Einladung (wuerde den Platz still abbauen).
	var invite_before: String = hs.invite_edit.text
	t.expect(hs.invite_button.disabled, "Einladung erstellen waehrend Verbinden bedienbar")
	hs.host_invite()
	t.expect(hs.invite_edit.text == invite_before and hs.host_status.text == OnlineScreen.CONNECTING_TEXT, "Neue Einladung waehrend Verbinden angenommen")
	if not _wait(func():
		hs.poll_net()
		gs.poll_net()
		return str(app.pending.get("mode", "")) == "online_host", "Host-Uebergabe an den Tisch"):
		return {}
	t.expect(app.last_goto == app.TABLE, "Host wechselt nicht zum Tisch")
	t.expect(hs._host_rtc == null and hs._handed_off, "Host-Bildschirm haelt den Connector nach Uebergabe")
	var job: Dictionary = app.pending
	t.expect(job.get("guest_seats", {}) == {2: 1} and int(job.get("host_seat", -1)) == 0, "Host-Auftrag falsche Plaetze")
	t.expect(int(job.config.seat_count) == 3 and job.config.ai_seats == [2], "Host-Konfiguration falsch: " + str(job.config))
	job = {}
	var host_table = _new_table()
	t.root.add_child(host_table)
	_free(hs)
	t.expect(not is_instance_valid(hs), "Host-Bildschirm nicht freigegeben")
	hs = null
	if host_table.session == null:
		t.expect(false, "Host-Tisch ohne Session")
		return {}
	if not _wait(func():
		host_table.session.poll()
		gs.poll_net()
		return str(app.pending.get("mode", "")) == "online_guest", "Gast-Uebergabe an den Tisch"):
		return {}
	t.expect(gs._guest_rtc == null and gs._handed_off, "Gast-Bildschirm haelt den Connector nach Uebergabe")
	var guest_table = _new_table()
	t.root.add_child(guest_table)
	_free(gs)
	gs = null
	_screens.clear()
	if guest_table.session == null or guest_table._view.is_empty():
		t.expect(false, "Gast-Tisch ohne Session oder Sicht")
		return {}
	return {"host_rtc": host_rtc, "guest_rtc": guest_rtc, "host_table": host_table, "guest_table": guest_table}


# ---------- Gast wartet nach der Verbindung: Zeitlimit, Ablehnung, Abbruch ----------

# Verbindet einen rohen Host-Connector (ohne Tisch) mit dem Gast-Bildschirm gs.
# Liefert {"host", "hlink", "grtc"} oder {} (dann schon ein Fehlschlag gemeldet).
func _guest_screen_connected(gs) -> Dictionary:
	var host := _make()
	var st := {"invite": "", "hlink": null}
	host.invite_ready.connect(func(c): st.invite = c)
	host.connected.connect(func(l): st.hlink = l)
	host.start_host()
	host.create_invite(2)
	if not _wait(func():
		host.poll()
		return st.invite != "", "Einladung (Gast wartet)"):
		return {}
	gs.guest_join(st.invite)
	var grtc = gs._guest_rtc
	if not _wait(func():
		host.poll()
		gs.poll_net()
		return gs.answer_out_edit.text != "", "Antwort (Gast wartet)"):
		return {}
	var r: Dictionary = host.accept_answer(gs.answer_out_edit.text)
	t.expect(bool(r.ok), "Host nimmt Antwort nicht an")
	if not _wait(func():
		host.poll()
		gs.poll_net()
		return st.hlink != null and gs._guest_session != null, "Gast verbunden, wartet auf Sicht"):
		return {}
	t.expect(gs.guest_status.text == OnlineScreen.WAIT_START_TEXT, "Status nicht 'Warte auf den Spielbeginn'")
	return {"host": host, "hlink": st.hlink, "grtc": grtc}


func _expect_guest_failed(gs, grtc, text: String, what: String) -> void:
	t.expect(gs.guest_error.text == text, what + ": falscher Fehlertext: " + gs.guest_error.text)
	t.expect(grtc.is_closed() and gs._guest_rtc == null, what + ": Connector nicht geschlossen")
	t.expect(not gs.join_button.disabled and gs.join_edit.editable and not gs.cancel_button.visible, what + ": Bildschirm nicht zurueckgesetzt")
	t.expect(app.pending.is_empty(), what + ": trotzdem an den Tisch")


func _check_guest_no_start() -> void:
	var gs = _screen()
	gs.first_view_ms = 300
	var c := _guest_screen_connected(gs)
	if c.is_empty():
		return
	# Host antwortet nie (kein Tisch): nach first_view_ms Fehler.
	_wait(func():
		c.host.poll()
		gs.poll_net()
		return gs.guest_error.text != "", "Zeitlimit erste Sicht")
	_expect_guest_failed(gs, c.grtc, OnlineScreen.NO_START_TEXT, "Kein Spielbeginn")
	# Neuer Versuch mit neuer Einladung klappt (neuer Connector).
	var old = c.grtc
	c.clear()
	var again := _guest_screen_connected(gs)
	t.expect(not again.is_empty() and again.grtc != old, "Neuer Versuch nach Zeitlimit scheitert")


func _check_guest_rejected() -> void:
	var gs = _screen()
	var c := _guest_screen_connected(gs)
	if c.is_empty():
		return
	c.hlink.send(2, NetCodec.encode({"t": "reject", "reason": "Falsche Spielversion"}))
	_wait(func():
		c.host.poll()
		gs.poll_net()
		return gs.guest_error.text != "", "Ablehnung beim Gast")
	_expect_guest_failed(gs, c.grtc, OnlineScreen.REJECTED_TEXT, "Abgelehnt")


func _check_guest_lost() -> void:
	var gs = _screen()
	var c := _guest_screen_connected(gs)
	if c.is_empty():
		return
	c.host.close()
	_wait(func():
		gs.poll_net()
		return gs.guest_error.text != "", "Verbindungsabbruch beim Gast")
	_expect_guest_failed(gs, c.grtc, OnlineScreen.LOST_TEXT, "Host weg")
