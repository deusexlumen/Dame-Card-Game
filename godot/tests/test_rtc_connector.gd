extends RefCounted

# RtcConnector: echter WebRTC-Aufbau zwischen Host und Gast im selben Prozess.
# Codes werden per Variable getauscht (statt Copy-Paste). Ohne webrtc-native
# wird die Suite sichtbar uebersprungen (TEST_SKIP-Zeile, godot-test.mjs listet
# sie am Ende); mit DAME_REQUIRE_WEBRTC=1 (CI) ist das ein Fehlschlag.
# Jede Warteschleife hat eine harte Obergrenze; alle Verbindungen werden immer
# geschlossen, sonst halten native WebRTC-Threads Headless-Godot am Leben.

const RtcConnector = preload("res://scripts/net/rtc_connector.gd")
const RtcCode = preload("res://scripts/net/rtc_code.gd")
const I18n = preload("res://scripts/i18n.gd")
const DameRulesScript = preload("res://scripts/dame_rules.gd")
const Protocol = preload("res://scripts/net/net_protocol.gd")
const DameHost = preload("res://scripts/net/dame_host.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")

const WAIT_CAP_MS := 15000
const SKIP_LINE := "TEST_SKIP test_rtc_connector: WebRTC-Erweiterung fehlt – Verbindungstest übersprungen"

var t
var _conns: Array = []


func run(ctx) -> void:
	t = ctx
	_check_errors_without_network()
	if not RtcConnector.is_available():
		print(SKIP_LINE)
		t.expect(OS.get_environment("DAME_REQUIRE_WEBRTC") != "1", "WebRTC-Erweiterung fehlt, DAME_REQUIRE_WEBRTC=1 verlangt sie")
		return
	_check_connect()
	# Auch nach einem Skriptfehler im Testkoerper: alles schliessen.
	_close_all()
	_check_timeout_and_retry()
	_close_all()


# ---------- Hilfen ----------

func _make() -> RtcConnector:
	var c := RtcConnector.new()
	_conns.append(c)
	return c


func _close_all() -> void:
	for c in _conns:
		c.close()
	_conns.clear()


# Pollt alle Connectoren (und extra), bis cond wahr ist. Harte Obergrenze.
func _wait(cond: Callable, what: String, extra: Callable = Callable()) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < WAIT_CAP_MS:
		for c in _conns:
			c.poll()
		if extra.is_valid():
			extra.call()
		if cond.call():
			return true
		OS.delay_msec(5)
	t.expect(false, "Zeitueberschreitung beim Warten auf: " + what)
	return false


# ---------- Tests ----------

# Fehlerpfade, die keine Netzverbindung brauchen (laufen auch ohne Erweiterung).
func _check_errors_without_network() -> void:
	var host := _make()
	var r: Dictionary = host.accept_answer("DAME1-kaputt")
	t.expect(not bool(r.ok) and str(r.error) == I18n.t(RtcCode.ERR_BROKEN), "Antwort ohne Host: kaputter Code abgelehnt")
	var guest := _make()
	var j: Dictionary = guest.join("Unsinn")
	t.expect(not bool(j.ok) and str(j.error) == I18n.t(RtcCode.ERR_BROKEN), "Kaputter Einladungscode abgelehnt")
	var answer_code: String = RtcCode.encode("answer", "AbCd1234", 2, "v=0\r\n", [])
	var j2: Dictionary = guest.join(answer_code)
	t.expect(not bool(j2.ok) and str(j2.error) == I18n.t(RtcCode.ERR_IS_ANSWER), "Antwortcode als Einladung abgelehnt")
	t.expect(RtcConnector.TIMEOUT_TEXT == "Verbindung nicht zustande gekommen. Seid ihr beide online?", "Zeitlimit-Text")
	t.expect(I18n.EN.has(RtcConnector.TIMEOUT_TEXT) and I18n.EN.has(RtcConnector.USED_TEXT), "Englische Texte vorhanden")
	_close_all()


func _check_connect() -> void:
	var host := _make()
	var guest_old := _make()
	var guest := _make()
	var invites: Array = []
	var answers_old: Array = []
	var answers: Array = []
	var host_links: Array = []
	var guest_links: Array = []
	var failures: Array = []
	host.invite_ready.connect(func(code): invites.append(code))
	host.connected.connect(func(link): host_links.append(link))
	host.failed.connect(func(reason): failures.append("Host: " + reason))
	guest_old.answer_ready.connect(func(code): answers_old.append(code))
	guest.answer_ready.connect(func(code): answers.append(code))
	guest.connected.connect(func(link): guest_links.append(link))
	guest.failed.connect(func(reason): failures.append("Gast: " + reason))

	host.start_host()
	var t0 := Time.get_ticks_msec()
	host.create_invite(2)
	if not _wait(func(): return invites.size() >= 1, "erste Einladung"):
		return
	print("RTC_GATHER_MS ", Time.get_ticks_msec() - t0)
	var invite_old: String = invites[0]
	var dec: Dictionary = RtcCode.decode(invite_old, "offer")
	t.expect(bool(dec.ok) and int(dec.peer_id) == 2, "Einladung traegt Gast-Peer-ID 2")
	t.expect(str(dec.offer_id).length() == 8, "Angebots-ID hat 8 Zeichen")
	# Erster Gast antwortet, waehrend der Host schon eine neuere Einladung fuer Platz 2 macht.
	var jo: Dictionary = guest_old.join(invite_old)
	t.expect(bool(jo.ok), "Gast (alt) tritt bei: " + str(jo.error))
	host.create_invite(2)
	if not _wait(func(): return invites.size() >= 2 and answers_old.size() >= 1, "neue Einladung und alte Antwort"):
		return
	var invite: String = invites[1]
	t.expect(str(RtcCode.decode(invite).offer_id) != str(dec.offer_id), "Neue Einladung hat neue Angebots-ID")
	# Review Focus 4: Antwort auf die alte Einladung wird abgelehnt.
	var stale: Dictionary = host.accept_answer(answers_old[0])
	t.expect(not bool(stale.ok) and str(stale.error) == RtcCode.wrong_offer_text(), "Antwort auf alte Einladung abgelehnt")
	var as_offer: Dictionary = host.accept_answer(invite)
	t.expect(not bool(as_offer.ok) and str(as_offer.error) == I18n.t(RtcCode.ERR_IS_OFFER), "Einladung als Antwort abgelehnt")
	guest_old.close()

	var jn: Dictionary = guest.join(invite)
	t.expect(bool(jn.ok), "Gast tritt bei: " + str(jn.error))
	t.expect(not bool(guest.join(invite).ok), "Zweites join abgelehnt")
	if not _wait(func(): return answers.size() >= 1, "Antwortcode"):
		return
	var answer: String = answers[0]
	# Review Focus 5: Laengen protokollieren.
	print("RTC_INVITE_LENGTH ", invite.length(), " candidates=", RtcCode.decode(invite).candidates.size())
	print("RTC_ANSWER_LENGTH ", answer.length(), " candidates=", RtcCode.decode(answer).candidates.size())
	t.expect(invite.length() < 1500, "Einladungscode kuerzer als 1500 (%d)" % invite.length())
	t.expect(answer.length() < 1500, "Antwortcode kuerzer als 1500 (%d)" % answer.length())
	var acc: Dictionary = host.accept_answer(answer)
	t.expect(bool(acc.ok), "Antwort angenommen: " + str(acc.error))
	var again: Dictionary = host.accept_answer(answer)
	t.expect(not bool(again.ok) and str(again.error) == I18n.t(RtcConnector.USED_TEXT), "Gleiche Antwort zweimal abgelehnt")
	if not _wait(func(): return host_links.size() >= 1 and guest_links.size() >= 1, "WebRTC-Verbindung"):
		print("RTC_FAILURES ", failures)
		return
	print("RTC_CONNECT_MS ", Time.get_ticks_msec() - t0)
	t.expect(failures.is_empty(), "Keine Fehlermeldung: " + str(failures))
	var hl = host_links[0]
	var gl = guest_links[0]
	t.expect(hl.my_id() == Protocol.HOST_PEER, "Host-Link hat Peer-ID 1")
	t.expect(gl.my_id() == 2, "Gast-Link hat Peer-ID 2")

	# Hello/Welcome ueber die beiden PeerLinks.
	var rules = DameRulesScript.new()
	rules.start_match({"seed": 5, "seat_count": 2})
	var dhost = DameHost.new(rules, hl)
	var dguest = DameGuest.new(gl)
	var welcomed := [false]
	var views: Array = []
	dguest.welcomed.connect(func(): welcomed[0] = true)
	dguest.view_changed.connect(func(v, _a): views.append(v))
	dguest.connect_to_host()
	var pump := func():
		dhost.poll()
		dguest.poll()
	if not _wait(func(): return welcomed[0], "welcome ueber WebRTC", pump):
		return
	dhost.assign_seat(Protocol.HOST_PEER, 0)
	dhost.assign_seat(2, 1)
	_wait(func(): return not views.is_empty(), "Sicht ueber WebRTC", pump)
	t.expect(not views.is_empty() and int(views[0].get("viewer_seat", -1)) == 1, "Gast bekommt Sicht fuer Sitz 1")

	# close() schliesst auch den ausgegebenen Link.
	host.close()
	host.close()  # idempotent
	t.expect(not hl.is_open(), "Host-Link nach close() zu")


# Zeitlimit: Gast ist weg, Host meldet genau einmal den Zeitlimit-Text. Danach
# bekommt eine neue Einladung fuer denselben Platz sauber einen Code.
func _check_timeout_and_retry() -> void:
	var host := _make()
	var guest := _make()
	host.timeout_ms = 300
	var invites: Array = []
	var answers: Array = []
	var failures: Array = []
	host.invite_ready.connect(func(code): invites.append(code))
	host.failed.connect(func(reason): failures.append(reason))
	guest.answer_ready.connect(func(code): answers.append(code))
	host.start_host()
	host.create_invite(2)
	if not _wait(func(): return invites.size() >= 1, "Einladung (Zeitlimit)"):
		return
	t.expect(bool(guest.join(invites[0]).ok), "Gast tritt bei (Zeitlimit)")
	if not _wait(func(): return answers.size() >= 1, "Antwort (Zeitlimit)"):
		return
	guest.close()
	t.expect(bool(host.accept_answer(answers[0]).ok), "Antwort angenommen (Zeitlimit)")
	if not _wait(func(): return failures.size() >= 1, "Zeitlimit-Meldung"):
		return
	t.expect(failures == [I18n.t(RtcConnector.TIMEOUT_TEXT)], "Genau eine Zeitlimit-Meldung: " + str(failures))
	host.create_invite(2)
	_wait(func(): return invites.size() >= 2, "neue Einladung nach Zeitlimit")
	t.expect(failures.size() == 1, "Keine weitere Meldung nach neuer Einladung: " + str(failures))
	var again: Dictionary = host.accept_answer(answers[0])
	t.expect(not bool(again.ok) and str(again.error) == RtcCode.wrong_offer_text(), "Alte Antwort nach Zeitlimit abgelehnt")
