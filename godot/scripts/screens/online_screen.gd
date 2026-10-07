extends "res://scripts/screens/screen_base.gd"

# Online (Test): zwei Menschen tauschen Verbindungscodes (Copy-Paste, kein Server),
# danach geht es an den Tisch. Hosten: Einladung erstellen, Antwort einfuegen.
# Beitreten: Einladung einfuegen, Antwort zurueckschicken, auf den Host warten.
#
# Besitz: Der RtcConnector schliesst beim Freigeben seinen WebRTC-Peer. Deshalb
# reist er als "owner" mit dem App-Auftrag zum Tisch, der ihn die ganze Partie haelt.
# Nach der Uebergabe vergisst der Bildschirm ihn (_handed_off), sonst schliesst er
# beim Verlassen alles selbst (shutdown).
#
# Netz nur in poll_net() (jedes Frame aus _process, Tests pumpen von Hand).
# Signale des Connectors kommen mitten aus dessen poll(): dort nur Zustand merken,
# Uebergabe und hello erst danach in poll_net().

const RtcConnector = preload("res://scripts/net/rtc_connector.gd")
const RtcCode = preload("res://scripts/net/rtc_code.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")
const I18n = preload("res://scripts/i18n.gd")

const GUEST_PEER := 2        # einziger Gast in dieser Ausbaustufe
const HOST_SEAT := 0
const GUEST_SEAT := 1
const FIRST_VIEW_MS := 20000  # Gast: so lange auf die erste Sicht des Hosts warten
const AI_NAMES := ["Lotte", "Bruno", "Erika", "Kurt", "Hilde", "Otto"]
const DIFF_KEYS := ["easy", "medium", "hard"]

const TITLE_TEXT := "Online (Test)"
const PRIVACY_TEXT := "Der Code enthält deine IP-Adresse. Teile ihn nur mit Leuten, mit denen du spielen willst."
const UNAVAILABLE_TEXT := "Online-Spiel braucht WebRTC. Diese Version hat es nicht – spiele im Browser oder mit der WebRTC-Erweiterung."
const HOST_HEAD := "Hosten"
const GUEST_HEAD := "Beitreten"
const HOST_INFO := "Du bist Platz 1, dein Gast Platz 2, die übrigen Plätze spielt die KI."
const SEATS_LABEL := "Spieleranzahl"
const INVITE_BUTTON := "Einladung erstellen"
const INVITE_LABEL := "Einladungscode (an deinen Gast schicken)"
const COPY_BUTTON := "Kopieren"
const ANSWER_IN_LABEL := "Antwortcode einfügen"
const CONNECT_BUTTON := "Verbinden"
const JOIN_LABEL := "Einladungscode einfügen"
const JOIN_BUTTON := "Weiter"
const ANSWER_OUT_LABEL := "Antwortcode (an den Host zurückschicken)"
const CANCEL_BUTTON := "Abbrechen"
const MAKING_INVITE_TEXT := "Einladung wird erstellt …"
const INVITE_READY_TEXT := "Schick den Code an deinen Gast und füge seine Antwort ein."
const CONNECTING_TEXT := "Verbinde …"
const MAKING_ANSWER_TEXT := "Antwortcode wird erstellt …"
const WAIT_HOST_TEXT := "Warte auf den Host …"
const WAIT_START_TEXT := "Verbunden. Warte auf den Spielbeginn …"
const COPIED_TEXT := "Kopiert."
const NO_INVITE_TEXT := "Erstelle zuerst eine Einladung."
const EMPTY_CODE_TEXT := "Bitte zuerst einen Code einfügen."
const NO_START_TEXT := "Der Host hat das Spiel nicht gestartet."
const LOST_TEXT := "Die Verbindung zum Host ist abgebrochen."
const REJECTED_TEXT := "Der Host hat die Verbindung abgelehnt."
const GUEST_NAME := "Gast"

# Alle Spielertexte dieses Bildschirms (Test: Englisch vorhanden).
const TEXTS := [TITLE_TEXT, PRIVACY_TEXT, UNAVAILABLE_TEXT, HOST_HEAD, GUEST_HEAD, HOST_INFO,
	SEATS_LABEL, INVITE_BUTTON, INVITE_LABEL, COPY_BUTTON, ANSWER_IN_LABEL, CONNECT_BUTTON,
	JOIN_LABEL, JOIN_BUTTON, ANSWER_OUT_LABEL, CANCEL_BUTTON, MAKING_INVITE_TEXT, INVITE_READY_TEXT,
	CONNECTING_TEXT, MAKING_ANSWER_TEXT, WAIT_HOST_TEXT, WAIT_START_TEXT, COPIED_TEXT, NO_INVITE_TEXT,
	EMPTY_CODE_TEXT, NO_START_TEXT, LOST_TEXT, REJECTED_TEXT, GUEST_NAME, "%d Spieler"]

# Vor add_child setzbar (Tests): ICE-Konfiguration fuer neue Connectoren ({} = Standard)
# und WebRTC-Erkennung erzwingen (-1 = erkennen, 0 = fehlt, 1 = vorhanden).
var ice_config: Dictionary = {}
var webrtc_override := -1
var first_view_ms := FIRST_VIEW_MS

var unavailable_label: Label
var privacy_label: Label
var host_box: Control
var guest_box: Control
var seat_option: OptionButton
var invite_button: Button
var invite_edit: LineEdit
var invite_copy_button: Button
var answer_in_edit: LineEdit
var connect_button: Button
var host_status: Label
var host_error: Label
var join_edit: LineEdit
var join_button: Button
var answer_out_edit: LineEdit
var answer_copy_button: Button
var guest_status: Label
var guest_error: Label
var cancel_button: Button

var _host_rtc = null
var _host_link = null
var _guest_rtc = null
var _guest_link = null
var _guest_session = null
var _guest_deadline := 0
var _guest_rejected := false
var _guest_lost := false
# Host: Antwort angenommen, Verbindung laeuft. Keine neue Einladung (wuerde den Platz still abbauen).
var _host_connecting := false
var _handed_off := false
var _e2e := false
# JavaScriptBridge-Callbacks muessen referenziert bleiben, sonst sind sie weg.
var _js_callbacks: Array = []


static func detect_webrtc() -> bool:
	return RtcConnector.is_available()


static func clean_code(text: String) -> String:
	return RtcCode.clean(text)


func webrtc_available() -> bool:
	if webrtc_override >= 0:
		return webrtc_override == 1
	return detect_webrtc()


func build() -> void:
	frame(TITLE_TEXT, 1180)
	privacy_label = label(PRIVACY_TEXT, 15)
	privacy_label.modulate = Color(1, 1, 1, 0.8)
	unavailable_label = label(UNAVAILABLE_TEXT, 18)
	unavailable_label.add_theme_color_override("font_color", UiTheme.GOLD)
	content.add_child(unavailable_label)
	content.add_child(privacy_label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	content.add_child(cols)
	host_box = _build_host(cols)
	guest_box = _build_guest(cols)
	var ok := webrtc_available()
	unavailable_label.visible = not ok
	host_box.visible = ok
	guest_box.visible = ok
	privacy_label.visible = ok
	if ok:
		invite_button.grab_focus()
	else:
		back_button.grab_focus()
	var app := app_node()
	_e2e = ok and app != null and app.has_method("e2e_mode") and app.e2e_mode()
	if _e2e:
		_register_e2e()


func _panel_column(parent: Control, head: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var h := label(head, 24)
	h.add_theme_font_override("font", UiTheme.heading_font())
	h.add_theme_color_override("font_color", UiTheme.GOLD)
	vb.add_child(h)
	return vb


func _build_host(parent: Control) -> Control:
	var vb := _panel_column(parent, HOST_HEAD)
	vb.add_child(label(HOST_INFO, 15))
	seat_option = option([tr("%d Spieler") % 2, tr("%d Spieler") % 3, tr("%d Spieler") % 4], 0)
	seat_option.custom_minimum_size = Vector2(0, 44)
	vb.add_child(row(SEATS_LABEL, seat_option, 170))
	invite_button = _big_button(INVITE_BUTTON, host_invite)
	vb.add_child(invite_button)
	vb.add_child(label(INVITE_LABEL, 15))
	invite_edit = _field("")
	invite_edit.editable = false
	invite_copy_button = _big_button(COPY_BUTTON, func() -> void: _copy(invite_edit, host_status))
	vb.add_child(_field_row(invite_edit, invite_copy_button))
	answer_in_edit = _field(ANSWER_IN_LABEL)
	connect_button = _big_button(CONNECT_BUTTON, func() -> void: host_accept(answer_in_edit.text))
	vb.add_child(_field_row(answer_in_edit, connect_button))
	host_status = label("", 15)
	vb.add_child(host_status)
	host_error = _error_label()
	vb.add_child(host_error)
	return vb.get_parent()


func _build_guest(parent: Control) -> Control:
	var vb := _panel_column(parent, GUEST_HEAD)
	join_edit = _field(JOIN_LABEL)
	join_button = _big_button(JOIN_BUTTON, func() -> void: guest_join(join_edit.text))
	vb.add_child(_field_row(join_edit, join_button))
	vb.add_child(label(ANSWER_OUT_LABEL, 15))
	answer_out_edit = _field("")
	answer_out_edit.editable = false
	answer_copy_button = _big_button(COPY_BUTTON, func() -> void: _copy(answer_out_edit, guest_status))
	vb.add_child(_field_row(answer_out_edit, answer_copy_button))
	guest_status = label("", 15)
	vb.add_child(guest_status)
	cancel_button = _big_button(CANCEL_BUTTON, guest_cancel)
	cancel_button.visible = false
	vb.add_child(cancel_button)
	guest_error = _error_label()
	vb.add_child(guest_error)
	return vb.get_parent()


func _big_button(text: String, cb: Callable) -> Button:
	var b := button(text, cb)
	b.custom_minimum_size = Vector2(130, 44)
	return b


func _field(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 44)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.max_length = RtcCode.MAX_CODE_CHARS
	return e


func _field_row(edit: LineEdit, b: Button) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(edit)
	h.add_child(b)
	return h


func _error_label() -> Label:
	var l := label("", 16)
	l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
	return l


func _copy(edit: LineEdit, status: Label) -> void:
	if edit.text == "":
		return
	DisplayServer.clipboard_set(edit.text)
	edit.select_all()
	status.text = COPIED_TEXT


func _new_connector():
	var c = RtcConnector.new()
	if not ice_config.is_empty():
		c.ice_config = ice_config
	return c


func _beep_error() -> void:
	var app := app_node()
	if app != null and app.audio != null:
		app.audio.play("error")


# ---------- Hosten ----------

# Neue Einladung. Ein spaeterer Klick ersetzt die alte (gleicher Gast-Platz).
func host_invite() -> void:
	if _handed_off or _host_connecting:
		return
	host_error.text = ""
	if _host_rtc == null or _host_rtc.is_closed():
		var rtc = _new_connector()
		rtc.invite_ready.connect(_on_host_invite)
		rtc.connected.connect(_on_host_connected)
		rtc.failed.connect(_on_host_failed)
		_host_rtc = rtc
		rtc.start_host()
	invite_edit.text = ""
	host_status.text = MAKING_INVITE_TEXT
	var keep = _host_rtc  # failed kann synchron kommen
	keep.create_invite(GUEST_PEER)


func host_accept(text: String) -> void:
	if _handed_off:
		return
	host_error.text = ""
	if _host_rtc == null or _host_rtc.is_closed() or invite_edit.text == "":
		host_error.text = NO_INVITE_TEXT
		_beep_error()
		return
	if clean_code(text) == "":
		host_error.text = EMPTY_CODE_TEXT
		_beep_error()
		return
	var r: Dictionary = _host_rtc.accept_answer(clean_code(text))
	if not bool(r.ok):
		host_error.text = str(r.error)
		_beep_error()
		return
	host_status.text = CONNECTING_TEXT
	_host_connecting = true
	invite_button.disabled = true


func _on_host_invite(code: String) -> void:
	invite_edit.text = code
	host_status.text = INVITE_READY_TEXT
	if _e2e:
		print("ONLINE_INVITE ", code)


func _on_host_connected(link) -> void:
	# Mitten aus poll(): nur merken, Uebergabe in poll_net().
	if _host_link == null:
		_host_link = link
		if _e2e:
			print("ONLINE_CONNECTED")


func _on_host_failed(reason: String) -> void:
	host_error.text = reason
	host_status.text = ""
	# Die Einladung ist verbraucht: nicht mehr zum Kopieren anbieten.
	invite_edit.text = ""
	_host_connecting = false
	invite_button.disabled = false


func host_config() -> Dictionary:
	var app := app_node()
	var count: int = seat_option.selected + 2
	var host_name := "Spieler"
	var diff := "medium"
	if app != null:
		host_name = str(app.settings.get_value("player_name")).strip_edges()
		var d := str(app.settings.get_value("default_difficulty"))
		if DIFF_KEYS.has(d):
			diff = d
	if host_name == "":
		host_name = tr("Spieler")
	var names: Array = [host_name]
	var guest_name: String = tr(GUEST_NAME)
	if guest_name == host_name:
		guest_name += " 2"
	names.append(guest_name)
	var ai_seats: Array = []
	var difficulties := {}
	for n in AI_NAMES:
		if names.size() >= count:
			break
		if names.has(n):
			continue
		ai_seats.append(names.size())
		difficulties[names.size()] = diff
		names.append(n)
	return {"seat_count": count, "ai_seats": ai_seats, "difficulties": difficulties, "names": names}


func _handoff_host() -> void:
	var app := app_node()
	var job := {
		"config": host_config(), "link": _host_link, "host_seat": HOST_SEAT,
		"guest_seats": {GUEST_PEER: GUEST_SEAT}, "owner": _host_rtc,
	}
	_handed_off = true
	_host_rtc = null
	_host_link = null
	_close_guest()
	if _e2e:
		print("ONLINE_TABLE seat=%d" % HOST_SEAT)
	if app != null:
		app.online_host_match(job)


# ---------- Beitreten ----------

# Jeder Versuch mit neuem Connector (ein gescheiterter Gast-Connector ist geschlossen).
func guest_join(text: String) -> void:
	if _handed_off:
		return
	_close_guest()
	_reset_guest_ui()
	var code := clean_code(text)
	if code == "":
		guest_error.text = EMPTY_CODE_TEXT
		_beep_error()
		return
	var rtc = _new_connector()
	rtc.answer_ready.connect(_on_guest_answer)
	rtc.connected.connect(_on_guest_connected)
	# Nur die Kennung binden: ein gebundener Verweis wuerde den Connector im Kreis halten.
	rtc.failed.connect(_on_guest_failed.bind(rtc.get_instance_id()))
	_guest_rtc = rtc
	var r: Dictionary = rtc.join(code)
	if not bool(r.ok):
		rtc.close()
		if _guest_rtc == rtc:
			_guest_rtc = null
		guest_error.text = str(r.error)
		_beep_error()
		return
	if _guest_rtc != rtc:
		return  # schon synchron gescheitert
	join_edit.editable = false
	join_button.disabled = true
	guest_status.text = MAKING_ANSWER_TEXT
	cancel_button.visible = true


func guest_cancel() -> void:
	_close_guest()
	_reset_guest_ui()
	join_edit.text = ""
	join_button.grab_focus()


func _on_guest_answer(code: String) -> void:
	answer_out_edit.text = code
	guest_status.text = WAIT_HOST_TEXT
	if _e2e:
		print("ONLINE_ANSWER ", code)


func _on_guest_connected(link) -> void:
	if _guest_link == null:
		_guest_link = link
		if _e2e:
			print("ONLINE_CONNECTED")


# Der Gast-Connector hat sich selbst geschlossen; nur loslassen und anzeigen.
func _on_guest_failed(reason: String, rtc_id: int) -> void:
	if _guest_rtc == null or _guest_rtc.get_instance_id() != rtc_id:
		return
	_guest_fail(reason)


func _guest_fail(reason: String) -> void:
	_close_guest()
	_reset_guest_ui()
	guest_error.text = reason
	_beep_error()


func _reset_guest_ui() -> void:
	guest_error.text = ""
	guest_status.text = ""
	answer_out_edit.text = ""
	join_edit.editable = true
	join_button.disabled = false
	cancel_button.visible = false


func _close_guest() -> void:
	_unhook_guest_session()
	var rtc = _guest_rtc
	_guest_rtc = null
	_guest_link = null
	_guest_session = null
	_guest_rejected = false
	_guest_lost = false
	if rtc != null:
		rtc.close()


func _start_guest_session() -> void:
	_guest_session = DameGuest.new(_guest_link)
	# Methoden statt Lambdas: Session und Link reisen zum Tisch, die Verbindungen
	# werden bei der Uebergabe wieder geloest (_unhook_guest_session).
	_guest_session.rejected.connect(_on_guest_rejected)
	_guest_link.peer_disconnected.connect(_on_guest_link_disconnected)
	_guest_session.connect_to_host()
	_guest_deadline = Time.get_ticks_msec() + first_view_ms
	guest_status.text = WAIT_START_TEXT
	cancel_button.visible = true


func _on_guest_rejected(_reason: String) -> void:
	_guest_rejected = true


func _on_guest_link_disconnected(peer_id: int) -> void:
	if peer_id == 1:
		_guest_lost = true


func _unhook_guest_session() -> void:
	if _guest_session != null and _guest_session.rejected.is_connected(_on_guest_rejected):
		_guest_session.rejected.disconnect(_on_guest_rejected)
	if _guest_link != null and _guest_link.peer_disconnected.is_connected(_on_guest_link_disconnected):
		_guest_link.peer_disconnected.disconnect(_on_guest_link_disconnected)


func _handoff_guest() -> void:
	var app := app_node()
	var session = _guest_session
	var owner_rtc = _guest_rtc
	var seat := int(session.latest_view.get("viewer_seat", -1))
	_unhook_guest_session()
	_handed_off = true
	_guest_rtc = null
	_guest_link = null
	_guest_session = null
	_close_host()
	if _e2e:
		print("ONLINE_TABLE seat=%d" % seat)
	if app != null:
		app.online_guest_match(session, owner_rtc)


# ---------- Netz ----------

func _process(_delta: float) -> void:
	poll_net()


func poll_net() -> void:
	if _handed_off:
		return
	# Host: nur den Connector pollen, nie den Link (ein frueher hello bleibt im Peer
	# liegen, bis der Tisch ihn abholt).
	var host = _host_rtc
	if host != null and _host_link == null:
		host.poll()
	if _host_link != null:
		_handoff_host()
		return
	var guest = _guest_rtc
	if guest == null:
		return
	if _guest_session == null:
		guest.poll()
		if _guest_rtc == guest and _guest_link != null:
			_start_guest_session()
		return
	if _guest_lost or not _guest_link.is_open():
		_guest_fail(LOST_TEXT)
		return
	_guest_session.poll()
	if _guest_lost:
		_guest_fail(LOST_TEXT)
		return
	if _guest_rejected:
		_guest_fail(REJECTED_TEXT)
		return
	if not (_guest_session.latest_view as Dictionary).is_empty():
		_handoff_guest()
		return
	if Time.get_ticks_msec() > _guest_deadline:
		_guest_fail(NO_START_TEXT)


func _close_host() -> void:
	var rtc = _host_rtc
	_host_rtc = null
	_host_link = null
	_host_connecting = false
	if invite_button != null:
		invite_button.disabled = false
	if rtc != null:
		rtc.close()


# Idempotent: alles schliessen, was nicht an den Tisch uebergeben wurde.
func shutdown() -> void:
	_close_host()
	_close_guest()
	_unregister_e2e()


func go_back() -> void:
	shutdown()
	super.go_back()


func _exit_tree() -> void:
	shutdown()


# ---------- Web-Test-Bruecke (nur ?e2e=1) ----------

func _register_e2e() -> void:
	var win = JavaScriptBridge.get_interface("window")
	if win == null:
		return
	var host_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: host_invite())
	var join_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
		guest_join(str(args[0]) if args.size() > 0 else ""))
	var accept_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
		host_accept(str(args[0]) if args.size() > 0 else ""))
	_js_callbacks = [host_cb, join_cb, accept_cb]
	win.dameHostInvite = host_cb
	win.dameGuestJoin = join_cb
	win.dameHostAccept = accept_cb


# Fenster-Funktionen loesen, damit Playwright nach dem Verlassen keinen toten Bildschirm ruft.
func _unregister_e2e() -> void:
	if not _e2e or _js_callbacks.is_empty():
		return
	var win = JavaScriptBridge.get_interface("window")
	if win != null:
		win.dameHostInvite = null
		win.dameGuestJoin = null
		win.dameHostAccept = null
	_js_callbacks = []
