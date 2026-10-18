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
const IceFetcher = preload("res://scripts/net/ice_fetcher.gd")
const NetConfig = preload("res://scripts/net/net_config.gd")
const RtcCode = preload("res://scripts/net/rtc_code.gd")
const DameGuest = preload("res://scripts/net/dame_guest.gd")
const I18n = preload("res://scripts/i18n.gd")
const Signaling = preload("res://scripts/net/signaling.gd")

const GUEST_PEER := 2        # erster Gast; weitere Gaeste haben 3, 4, ...
const HOST_SEAT := 0
const GUEST_SEAT := 1        # Platz des ersten Gastes; weitere folgen
const MAX_SEATS := 6
const ROOM_INVITE_RETRY_MS := 15000   # Einladung ohne Code so lange abwarten, dann neu
const HELLO_EVERY_MS := 3000
const FIRST_VIEW_MS := 300000  # Gast: so lange auf die erste Sicht warten (der Host startet, wenn alle Gaeste da sind)
const AI_NAMES := ["Lotte", "Bruno", "Erika", "Kurt", "Hilde", "Otto"]
const DIFF_KEYS := ["easy", "medium", "hard"]

const TITLE_TEXT := "Online (Test)"
const PRIVACY_TEXT := "Der Code enthält deine IP-Adresse. Teile ihn nur mit Leuten, mit denen du spielen willst."
const UNAVAILABLE_TEXT := "Online-Spiel braucht WebRTC. Diese Version hat es nicht – spiele im Browser oder mit der WebRTC-Erweiterung."
const HOST_HEAD := "Hosten"
const GUEST_HEAD := "Beitreten"
const HOST_INFO := "Du bist Platz 1, deine Gäste sitzen auf den nächsten Plätzen, die übrigen Plätze spielt die KI."
const GUESTS_LABEL := "Gäste"
const START_BUTTON := "Jetzt starten"
const ROOM_COUNT_TEXT := "%d von %d Gästen verbunden."
const ROOM_FAILED_KEEP_TEXT := "Der Raum-Dienst ist weg. Die verbundenen Gäste können trotzdem starten."
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
const PREPARING_TEXT := "Verbindung wird vorbereitet …"
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
const ROOM_BUTTON := "Raum öffnen"
const ROOM_CODE_TEXT := "Raumcode: %s – gib ihn deinem Gast."
const ROOM_OPENING_TEXT := "Raum wird geöffnet …"
const ROOM_JOIN_BUTTON := "Raum beitreten"
const ROOM_LABEL := "Raumcode (vom Host)"
const ROOM_WAIT_TEXT := "Im Raum. Warte auf die Einladung des Hosts …"
const ROOM_BAD_TEXT := "Der Raumcode hat sechs Zeichen."

# Alle Spielertexte dieses Bildschirms (Test: Englisch vorhanden).
const TEXTS := [TITLE_TEXT, PRIVACY_TEXT, UNAVAILABLE_TEXT, HOST_HEAD, GUEST_HEAD, HOST_INFO,
	SEATS_LABEL, INVITE_BUTTON, INVITE_LABEL, COPY_BUTTON, ANSWER_IN_LABEL, CONNECT_BUTTON,
	JOIN_LABEL, JOIN_BUTTON, ANSWER_OUT_LABEL, CANCEL_BUTTON, MAKING_INVITE_TEXT, INVITE_READY_TEXT,
	CONNECTING_TEXT, PREPARING_TEXT, MAKING_ANSWER_TEXT, WAIT_HOST_TEXT, WAIT_START_TEXT, COPIED_TEXT, NO_INVITE_TEXT,
	EMPTY_CODE_TEXT, NO_START_TEXT, LOST_TEXT, REJECTED_TEXT, GUEST_NAME, "%d Spieler", ROOM_BUTTON, ROOM_CODE_TEXT,
	ROOM_OPENING_TEXT, ROOM_JOIN_BUTTON, ROOM_LABEL, ROOM_WAIT_TEXT, ROOM_BAD_TEXT,
	GUESTS_LABEL, START_BUTTON, ROOM_COUNT_TEXT, ROOM_FAILED_KEEP_TEXT, "%d Gast", "%d Gäste", "Gast %d"]

# Vor add_child setzbar (Tests): ICE-Konfiguration fuer neue Connectoren ({} = Standard)
# und WebRTC-Erkennung erzwingen (-1 = erkennen, 0 = fehlt, 1 = vorhanden).
var ice_config: Dictionary = {}
# TURN-Zugangsdaten vor jeder Einladung/jedem Beitritt holen ("" = nur STUN).
# Wird ignoriert, wenn ice_config gesetzt ist.
var turn_url: String = NetConfig.TURN_URL
var webrtc_override := -1
# Tests: eigener Signaling-Dienst ("" = Standard aus NetConfig).
var signaling_url := ""
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
var room_button: Button
var room_label: Label
var room_edit: LineEdit
var room_join_button: Button
var _sig_host = null
var _sig_guest = null
var guest_option: OptionButton
var start_button: Button
# Raum-Modus (mehrere Gaeste): wie viele Gaeste erwartet werden, wer welchen Platz hat,
# wer schon verbunden ist. nonce -> {peer, code, at}.
var _room_mode := false
var _host_expected := 1
var _room_slots := {}
var _host_connected: Array = []
var _start_requested := false
var _guest_nonce := ""
var _hello_at := 0

var _host_rtc = null
var _host_link = null
var _guest_rtc = null
var _guest_link = null
var _guest_session = null
var _guest_deadline := 0
var _guest_rejected := false
var _guest_lost := false
# Raumcode des Gastes (leer bei Copy-Paste), reist mit der Session zum Tisch.
var _guest_room := ""
# Host: Antwort angenommen, Verbindung laeuft. Keine neue Einladung (wuerde den Platz still abbauen).
var _host_connecting := false
var _handed_off := false
var _e2e := false
# JavaScriptBridge-Callbacks muessen referenziert bleiben, sonst sind sie weg.
var _js_callbacks: Array = []
# Laufender TURN-Abruf, die danach auszufuehrende Aktion und wem sie gehoert ("host"/"guest").
var _ice_fetcher = null
var _ice_action := Callable()
var _ice_owner := ""
# Ergebnis des letzten Abrufs, wird vom naechsten Connector verbraucht.
var _fresh_ice: Dictionary = {}


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
	var seat_items: Array = []
	for n in range(2, MAX_SEATS + 1):
		seat_items.append(tr("%d Spieler") % n)
	seat_option = option(seat_items, 0)
	seat_option.custom_minimum_size = Vector2(0, 44)
	vb.add_child(row(SEATS_LABEL, seat_option, 170))
	guest_option = option([], 0)
	guest_option.custom_minimum_size = Vector2(0, 44)
	vb.add_child(row(GUESTS_LABEL, guest_option, 170))
	seat_option.item_selected.connect(func(_i: int) -> void: _fill_guest_options())
	_fill_guest_options()
	invite_button = _big_button(INVITE_BUTTON, host_invite)
	vb.add_child(invite_button)
	vb.add_child(label(INVITE_LABEL, 15))
	invite_edit = _field("")
	invite_edit.editable = false
	invite_copy_button = _big_button(COPY_BUTTON, func() -> void: _copy(invite_edit, host_status))
	vb.add_child(_field_row(invite_edit, invite_copy_button))
	room_button = _big_button(ROOM_BUTTON, host_room)
	vb.add_child(room_button)
	room_label = label("", 18)
	room_label.add_theme_color_override("font_color", UiTheme.GOLD)
	vb.add_child(room_label)
	answer_in_edit = _field(ANSWER_IN_LABEL)
	connect_button = _big_button(CONNECT_BUTTON, func() -> void: host_accept(answer_in_edit.text))
	vb.add_child(_field_row(answer_in_edit, connect_button))
	host_status = label("", 15)
	vb.add_child(host_status)
	start_button = _big_button(START_BUTTON, host_start)
	start_button.visible = false
	vb.add_child(start_button)
	host_error = _error_label()
	vb.add_child(host_error)
	return vb.get_parent()


func _build_guest(parent: Control) -> Control:
	var vb := _panel_column(parent, GUEST_HEAD)
	join_edit = _field(JOIN_LABEL)
	join_button = _big_button(JOIN_BUTTON, func() -> void: guest_join(join_edit.text))
	vb.add_child(_field_row(join_edit, join_button))
	room_edit = _field(ROOM_LABEL)
	room_edit.max_length = Signaling.ROOM_LEN + 2
	room_join_button = _big_button(ROOM_JOIN_BUTTON, func() -> void: guest_room(room_edit.text))
	vb.add_child(_field_row(room_edit, room_join_button))
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
	_apply_ice(c)
	return c


# Feste Test-Konfiguration oder frisch geholte Zugangsdaten (einmal verbraucht).
func _apply_ice(rtc) -> void:
	if not ice_config.is_empty():
		rtc.ice_config = ice_config
	elif not _fresh_ice.is_empty():
		rtc.ice_config = _fresh_ice
		_fresh_ice = {}


func _wants_ice() -> bool:
	return ice_config.is_empty() and turn_url != "" and _fresh_ice.is_empty()


# Zugangsdaten holen, danach action ausfuehren (aus poll_net).
func _prepare_ice(action: Callable, owner: String, status: Label) -> void:
	_ice_fetcher = IceFetcher.new()
	_ice_fetcher.start(turn_url)
	_ice_action = action
	_ice_owner = owner
	status.text = PREPARING_TEXT


func _cancel_ice() -> void:
	if _ice_fetcher != null:
		_ice_fetcher.close()
	_ice_fetcher = null
	_ice_action = Callable()
	_ice_owner = ""
	_fresh_ice = {}


func _poll_ice() -> void:
	if _ice_fetcher == null:
		return
	_ice_fetcher.poll()
	if not _ice_fetcher.is_done():
		return
	_fresh_ice = _ice_fetcher.config
	if _e2e:
		print("ONLINE_TURN ", "on" if _ice_fetcher.has_turn else "off")
	var action := _ice_action
	var owner := _ice_owner
	_ice_fetcher = null
	_ice_action = Callable()
	_ice_owner = ""
	if owner == "host":
		invite_button.disabled = false
	if action.is_valid():
		action.call()


func _beep_error() -> void:
	var app := app_node()
	if app != null and app.audio != null:
		app.audio.play("error")


# ---------- Hosten ----------

# Neue Einladung. Ein spaeterer Klick ersetzt die alte (gleicher Gast-Platz).
func host_invite() -> void:
	if _handed_off or _host_connecting or _ice_fetcher != null:
		return
	host_error.text = ""
	if _wants_ice():
		invite_button.disabled = true
		_prepare_ice(host_invite, "host", host_status)
		return
	if _host_rtc == null or _host_rtc.is_closed():
		var rtc = _new_connector()
		rtc.invite_ready.connect(_on_host_invite)
		rtc.connected.connect(_on_host_connected)
		rtc.failed.connect(_on_host_failed)
		_host_rtc = rtc
		rtc.start_host()
	_apply_ice(_host_rtc)
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
	if _e2e:
		print("ONLINE_FAILED host ", reason)
	host_error.text = reason
	host_status.text = ""
	# Die Einladung ist verbraucht: nicht mehr zum Kopieren anbieten.
	invite_edit.text = ""
	_host_connecting = false
	if _room_mode:
		# Ein gescheiterter Gast beendet den Raum nicht; er kann neu beitreten.
		_update_room_status()
		return
	invite_button.disabled = false
	_close_sig_host()
	room_label.text = ""


# Anzahl der Gaeste, die der Host erwartet (1 .. Plaetze - 1).
func guest_count() -> int:
	return clampi(guest_option.selected + 1, 1, seat_option.selected + 1)


func _fill_guest_options() -> void:
	var keep := guest_option.selected
	guest_option.clear()
	for n in range(1, seat_option.selected + 2):
		guest_option.add_item(tr("%d Gast") % n if n == 1 else tr("%d Gäste") % n)
	guest_option.select(clampi(keep, 0, guest_option.item_count - 1))


# guests: Zahl der menschlichen Gaeste am Tisch (Standard: die gewaehlte).
func host_config(guests: int = -1) -> Dictionary:
	var app := app_node()
	var count: int = seat_option.selected + 2
	if guests < 0:
		guests = guest_count()
	guests = clampi(guests, 1, count - 1)
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
	for g in range(guests):
		var guest_name: String = tr(GUEST_NAME) if g == 0 else tr("Gast %d") % (g + 1)
		while names.has(guest_name):
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
	# Verbundene Gaeste in Peer-Reihenfolge auf die Plaetze 1, 2, ... setzen.
	var peers: Array = _host_connected.duplicate()
	if peers.is_empty():
		peers = [GUEST_PEER]
	peers.sort()
	var guest_seats := {}
	for i in range(peers.size()):
		guest_seats[int(peers[i])] = GUEST_SEAT + i
	# Nicht mehr erwartete Einladungen verfallen lassen (Gast kommt nach dem Start nicht mehr dazu).
	if _room_mode and _host_rtc != null:
		for nonce in _room_slots:
			var pending := int(_room_slots[nonce].peer)
			if not peers.has(pending):
				_host_rtc.drop_peer(pending)
	# Raumcode reist mit: der Tisch haelt den Raum fuer Wiedereintritte offen (leer = Copy-Paste).
	var job := {
		"config": host_config(peers.size()), "link": _host_link, "host_seat": HOST_SEAT,
		"guest_seats": guest_seats, "owner": _host_rtc,
		"room": str(_sig_host.room) if _sig_host != null else "",
	}
	_handed_off = true
	_host_rtc = null
	_host_link = null
	_room_mode = false
	_room_slots = {}
	_host_connected = []
	_close_sig_host()
	_close_guest()
	if _e2e:
		print("ONLINE_TABLE seat=%d" % HOST_SEAT)
	if app != null:
		app.online_host_match(job)


# ---------- Beitreten ----------

# Jeder Versuch mit neuem Connector (ein gescheiterter Gast-Connector ist geschlossen).
func guest_join(text: String) -> void:
	if _handed_off or _ice_fetcher != null:
		return
	_close_guest()
	_reset_guest_ui()
	var code := clean_code(text)
	if code == "":
		guest_error.text = EMPTY_CODE_TEXT
		_beep_error()
		return
	if _wants_ice():
		# Kaputte Codes sofort melden, nicht erst nach dem Abruf.
		var d: Dictionary = RtcCode.decode(code, "offer")
		if not bool(d.ok):
			guest_error.text = str(d.error)
			_beep_error()
			return
		join_edit.editable = false
		join_button.disabled = true
		cancel_button.visible = true
		_prepare_ice(guest_join.bind(text), "guest", guest_status)
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
	if _ice_owner == "guest":
		_cancel_ice()
	_close_guest()
	_reset_guest_ui()
	join_edit.text = ""
	join_button.grab_focus()


func _on_guest_answer(code: String) -> void:
	answer_out_edit.text = code
	guest_status.text = WAIT_HOST_TEXT
	if _sig_guest != null:
		_sig_guest.send_event("answer", {"code": code})
	if _e2e:
		print("ONLINE_ANSWER ", code)


func _on_guest_connected(link) -> void:
	if _guest_link == null:
		_guest_link = link
		# Raumcode merken: darueber kommt der Gast nach einem Verbindungsverlust zurueck.
		if _sig_guest != null:
			_guest_room = str(_sig_guest.room)
		_close_sig_guest()
		if _e2e:
			print("ONLINE_CONNECTED")


# Der Gast-Connector hat sich selbst geschlossen; nur loslassen und anzeigen.
func _on_guest_failed(reason: String, rtc_id: int) -> void:
	if _guest_rtc == null or _guest_rtc.get_instance_id() != rtc_id:
		return
	_guest_fail(reason)


func _guest_fail(reason: String) -> void:
	if _e2e:
		print("ONLINE_FAILED guest ", reason)
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
	if room_edit != null:
		room_edit.editable = true
		room_join_button.disabled = false
	cancel_button.visible = false


func _close_guest() -> void:
	_close_sig_guest()
	_unhook_guest_session()
	var rtc = _guest_rtc
	_guest_rtc = null
	_guest_link = null
	_guest_session = null
	_guest_rejected = false
	_guest_lost = false
	_guest_room = ""
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
	session.room = _guest_room
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

# ---------------------------------------------------------------- Raumcode

func _new_signaling():
	var sig = Signaling.new()
	if signaling_url != "":
		sig.url = signaling_url
		sig.api_key = ""
	return sig


# Host: Raum auf dem Signaling-Dienst oeffnen und die Einladung dort anbieten.
# Host: Raum auf dem Signaling-Dienst oeffnen. Jeder Gast, der "hello" sendet, bekommt
# eine eigene Einladung (Peer 2, 3, ...), adressiert an seine Kennung.
func host_room() -> void:
	if _handed_off or _host_connecting or _ice_fetcher != null or _sig_host != null:
		return
	# Schon verbundene Gaeste bleiben; ohne sie neu anfangen.
	if not _host_connected.is_empty():
		return
	# Ein Connector vom Copy-Paste-Weg kennt die Raum-Signale nicht: frisch beginnen.
	if _host_rtc != null:
		_host_rtc.close()
		_host_rtc = null
		_host_link = null
		invite_edit.text = ""
	host_error.text = ""
	var sig = _new_signaling()
	var code: String = Signaling.new_room_code()
	sig.joined.connect(_update_room_status)
	sig.event.connect(_on_host_signal)
	sig.failed.connect(_on_host_room_failed)
	_sig_host = sig
	_room_mode = true
	_host_expected = guest_count()
	_room_slots = {}
	_host_connected = []
	_start_requested = false
	room_button.disabled = true
	invite_button.disabled = true
	room_label.text = tr(ROOM_CODE_TEXT) % code
	host_status.text = ROOM_OPENING_TEXT
	if not sig.open(code):
		return
	if _e2e:
		print("ONLINE_ROOM ", code)
	_prepare_host_rtc()


# Connector fuer den Raum starten (nach dem TURN-Abruf), noch ohne Einladung.
func _prepare_host_rtc() -> void:
	if _sig_host == null:
		return
	if _wants_ice():
		invite_button.disabled = true
		_prepare_ice(_prepare_host_rtc, "host", host_status)
		return
	if _host_rtc == null or _host_rtc.is_closed():
		var rtc = _new_connector()
		rtc.invite_for.connect(_on_room_invite)
		rtc.guest_connected.connect(_on_room_guest_connected)
		rtc.slot_failed.connect(_on_room_slot_failed)
		rtc.connected.connect(_on_host_connected)
		rtc.failed.connect(_on_host_failed)
		_host_rtc = rtc
		rtc.start_host()
	_apply_ice(_host_rtc)
	invite_button.disabled = true
	_update_room_status()


func _update_room_status() -> void:
	if not _room_mode or _handed_off:
		return
	var n := _host_connected.size()
	if _sig_host != null and not _sig_host.is_joined() and n == 0:
		return
	host_status.text = tr(ROOM_COUNT_TEXT) % [n, _host_expected]
	start_button.visible = n >= 1 and n < _host_expected


func _free_room_peer() -> int:
	for p in range(GUEST_PEER, GUEST_PEER + _host_expected):
		var taken := false
		for nonce in _room_slots:
			if int(_room_slots[nonce].peer) == p:
				taken = true
		if not taken:
			return p
	return -1


func _on_host_signal(name: String, payload: Dictionary) -> void:
	if name == "hello":
		_room_hello(payload)
	elif name == "answer":
		_room_answer(payload)


func _room_hello(payload: Dictionary) -> void:
	var nonce = payload.get("nonce")
	if typeof(nonce) != TYPE_STRING or (nonce as String).length() < 4 or (nonce as String).length() > 32:
		return
	if _host_rtc == null or _host_rtc.is_closed() or _start_requested:
		return
	var now := Time.get_ticks_msec()
	var slot: Dictionary = _room_slots.get(nonce, {})
	if not slot.is_empty():
		if str(slot.code) != "":
			_publish_room_invite(str(nonce))
		elif now - int(slot.at) > ROOM_INVITE_RETRY_MS:
			# Einladung hat nie einen Code bekommen: neu versuchen.
			slot.at = now
			_host_rtc.create_invite(int(slot.peer))
		return
	var peer := _free_room_peer()
	if peer < 0:
		return  # Raum voll
	_room_slots[nonce] = {"peer": peer, "code": "", "at": now}
	_host_rtc.create_invite(peer)


func _on_room_invite(peer: int, code: String) -> void:
	for nonce in _room_slots:
		if int(_room_slots[nonce].peer) == peer:
			_room_slots[nonce].code = code
			_publish_room_invite(str(nonce))
			if _e2e:
				print("ONLINE_INVITE ", code)


func _publish_room_invite(nonce: String) -> void:
	var slot: Dictionary = _room_slots.get(nonce, {})
	if slot.is_empty() or _sig_host == null or not _sig_host.is_joined():
		return
	_sig_host.send_event("invite", {"code": slot.code, "peer": int(slot.peer), "for": nonce})


func _room_answer(payload: Dictionary) -> void:
	var code = payload.get("code")
	if typeof(code) != TYPE_STRING or _host_rtc == null or _host_rtc.is_closed():
		return
	# Fremde oder doppelte Antworten lehnt der Connector selbst ab (Einladungs-Kennung).
	_host_rtc.accept_answer(clean_code(str(code)))


func _on_room_guest_connected(peer: int) -> void:
	if not _host_connected.has(peer):
		_host_connected.append(peer)
	_update_room_status()


func _on_room_slot_failed(peer: int) -> void:
	for nonce in _room_slots.keys():
		if int(_room_slots[nonce].peer) == peer:
			_room_slots.erase(nonce)


# Host startet mit den bisher verbundenen Gaesten; der Rest wird KI.
func host_start() -> void:
	if _room_mode and not _host_connected.is_empty():
		_start_requested = true


func _on_host_room_failed(reason: String) -> void:
	_close_sig_host()
	host_error.text = reason
	room_label.text = ""
	_beep_error()
	if _room_mode and _host_connected.is_empty():
		# Niemand verbunden: alles zuruecksetzen, neu oeffnen moeglich.
		_reset_room_state()
		return
	if _room_mode:
		# Verbundene Gaeste koennen auch ohne Raum-Dienst starten.
		host_status.text = tr(ROOM_FAILED_KEEP_TEXT)
		start_button.visible = true
		room_button.disabled = true


func _reset_room_state() -> void:
	_room_mode = false
	_room_slots = {}
	_host_connected = []
	_start_requested = false
	if start_button != null:
		start_button.visible = false
	if invite_button != null:
		invite_button.disabled = false
	var rtc = _host_rtc
	_host_rtc = null
	_host_link = null
	if rtc != null:
		rtc.close()


func _close_sig_host() -> void:
	var sig = _sig_host
	_sig_host = null
	if sig != null:
		sig.close()
	if room_button != null:
		room_button.disabled = false


# Gast: Raum betreten, die Einladung des Hosts kommt von selbst.
func guest_room(text: String) -> void:
	if _handed_off or _ice_fetcher != null:
		return
	var code := Signaling.normalize_room(text)
	if code == "":
		guest_error.text = ROOM_BAD_TEXT
		_beep_error()
		return
	_close_guest()
	_reset_guest_ui()
	_guest_nonce = _new_nonce()
	var sig = _new_signaling()
	sig.joined.connect(_on_guest_room_joined)
	sig.event.connect(_on_guest_signal)
	sig.failed.connect(_on_guest_room_failed)
	_sig_guest = sig
	join_edit.editable = false
	join_button.disabled = true
	room_edit.editable = false
	room_join_button.disabled = true
	cancel_button.visible = true
	guest_status.text = ROOM_OPENING_TEXT
	sig.open(code)


func _on_guest_room_joined() -> void:
	guest_status.text = ROOM_WAIT_TEXT
	_hello_at = 0
	_say_hello()


func _new_nonce() -> String:
	var bytes := Crypto.new().generate_random_bytes(8)
	var out := ""
	for b in bytes:
		out += RtcConnector.ID_CHARS[b % RtcConnector.ID_CHARS.length()]
	return out


# Gast: "hello" mit eigener Kennung, bis die Einladung da ist (Host war evtl. noch nicht im Raum).
func _say_hello() -> void:
	if _sig_guest == null or not _sig_guest.is_joined() or _guest_rtc != null:
		return
	var now := Time.get_ticks_msec()
	if now < _hello_at:
		return
	_hello_at = now + HELLO_EVERY_MS
	_sig_guest.send_event("hello", {"nonce": _guest_nonce})


func _on_guest_signal(name: String, payload: Dictionary) -> void:
	# Nur die Einladung, die an diese Kennung adressiert ist (mehrere Gaeste im Raum).
	if name == "invite" and _guest_rtc == null and typeof(payload.get("code")) == TYPE_STRING \
			and payload.get("for") == _guest_nonce:
		# guest_join setzt die Oberflaeche zurueck, die Raumverbindung bleibt fuer die Antwort.
		var keep = _sig_guest
		_sig_guest = null
		guest_join(str(payload.code))
		if _guest_rtc != null:
			_sig_guest = keep
			room_edit.editable = false
			room_join_button.disabled = true
		elif keep != null:
			keep.close()
			room_edit.editable = true
			room_join_button.disabled = false


func _on_guest_room_failed(reason: String) -> void:
	_sig_guest = null
	_reset_guest_ui()
	guest_error.text = reason
	_beep_error()


func _close_sig_guest() -> void:
	var sig = _sig_guest
	_sig_guest = null
	if sig != null:
		sig.close()


func _process(_delta: float) -> void:
	poll_net()


func poll_net() -> void:
	if _handed_off:
		return
	_poll_ice()
	if _handed_off:
		return
	if _sig_host != null:
		_sig_host.poll()
	if _sig_guest != null:
		_sig_guest.poll()
	# Host: nur den Connector pollen, nie den Link (ein frueher hello bleibt im Peer
	# liegen, bis der Tisch ihn abholt).
	var host = _host_rtc
	if host != null:
		host.poll()
	if _host_link != null and _host_ready():
		_handoff_host()
		return
	_say_hello()
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


# Copy-Paste: sofort, wenn der eine Gast da ist. Raum: wenn alle erwarteten da sind oder der Host startet.
func _host_ready() -> bool:
	if not _room_mode:
		return true
	return _host_connected.size() >= _host_expected or _start_requested


func _close_host() -> void:
	var rtc = _host_rtc
	_host_rtc = null
	_host_link = null
	_host_connecting = false
	_room_mode = false
	_room_slots = {}
	_host_connected = []
	_start_requested = false
	if start_button != null:
		start_button.visible = false
	_close_sig_host()
	if room_label != null:
		room_label.text = ""
	if invite_button != null:
		invite_button.disabled = false
	if rtc != null:
		rtc.close()


# Idempotent: alles schliessen, was nicht an den Tisch uebergeben wurde.
func shutdown() -> void:
	_cancel_ice()
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
