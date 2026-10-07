extends Control

# Spieltisch. Schreibt nur ueber die Session (DameHost), nie direkt in die Regeln.
# Zeigt nur die eigene Sicht der Session; Darstellung, Animation und Toene kommen allein aus
# _on_view. KI-Zuege laufen schrittweise ueber einen Timer.

signal state_changed

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const DameHostScript = preload("res://scripts/net/dame_host.gd")
const DameProtocol = preload("res://scripts/net/net_protocol.gd")
const SeatViewScript = preload("res://scripts/ui/seat_view.gd")
const CardViewScript = preload("res://scripts/ui/card_view.gd")
const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")
const CatalogScript = preload("res://scripts/services/catalog.gd")
const Table3DScript = preload("res://scripts/table3d/table_3d.gd")
const I18nScript = preload("res://scripts/i18n.gd")
const FxLayerScript = preload("res://scripts/ui/fx_layer.gd")

const REVEAL_DEAL_MS := 5000
const HELP_DE := """[b]Dein Zug[/b]
1. Ziehe vom [b]Stapel[/b] (Leertaste) oder nimm die oberste Karte der [b]Ablage[/b].
2. Tausche sie gegen eine eigene Karte (Karte anklicken) oder lege sie direkt ab (A).
3. Passt eine eigene Karte zum Rang der Ablage, darfst du sie zusätzlich ablegen (X). Falsch = eine Strafkarte.
4. Zug beenden (Enter).

[b]Ziel[/b]
Möglichst wenige Punkte. Über 50 Gesamtpunkte scheidest du aus, genau 50 setzt auf 0.
Ass 1 · Zwei bis Zehn nach Augen · Bube 10 · König 10 · Dame 0

[b]Sonderkarten[/b]
[b]Bube:[/b] Sieh dir eine beliebige verdeckte Karte an, deine oder eine fremde.
[b]König:[/b] Sieh dir eine eigene Karte an und tausche sie blind mit einer Karte eines Gegners.
[b]Dame:[/b] Wer sie ablegt, bekommt eine Strafkarte. Eine offene Dame muss der nächste Spieler nehmen.

[b]Dame rufen[/b]
Ab Runde 3 zu Beginn deines Zuges (D), wenn du glaubst, die wenigsten Punkte zu haben. Alle anderen haben noch genau einen Zug. Nur mit strikt weniger Punkten liegst du richtig, sonst startest du die nächste Ausgabe mit 5 Karten.

[b]Tasten[/b]
1–6 Karte wählen · Leertaste ziehen · Enter bestätigen / Zug beenden · A gezogene Karte ablegen · X extra ablegen · D Dame rufen · Z/E Ansehen verdecken · H Hilfe · Esc Menü"""
const HELP_EN := """[b]Your turn[/b]
1. Draw from the [b]deck[/b] (Space) or take the top card of the [b]discard[/b].
2. Swap it for one of your cards (click the card) or discard it directly (A).
3. If one of your cards matches the discard's rank, you may discard it too (X). Wrong = one penalty card.
4. End your turn (Enter).

[b]Goal[/b]
As few points as possible. Above 50 total points you are out, exactly 50 resets to 0.
Ace 1 · Two to Ten by pips · Jack 10 · King 10 · Queen 0

[b]Special cards[/b]
[b]Jack:[/b] Look at any face-down card, yours or someone else's.
[b]King:[/b] Look at one of your cards and swap it blind with an opponent's card.
[b]Queen:[/b] Whoever discards it gets a penalty card. An open queen must be taken by the next player.

[b]Calling Dame[/b]
From round 3, at the start of your turn (D), if you think you have the fewest points. Everyone else gets exactly one more turn. You are only right with strictly fewer points; otherwise you start the next deal with 5 cards.

[b]Keys[/b]
1–6 pick card · Space draw · Enter confirm / end turn · A discard drawn card · X extra discard · D call Dame · Z/E hide peek · H help · Esc menu"""
const REVEAL_PEEK_MS := 3000
const REVEAL_SWAP_MS := 2200

# DameHost oder DameGuest. Einziger Weg, das Spiel zu veraendern.
var session = null
# Nur lesend: die Regeln des Hosts (Start, Fortsetzen, Speichern, Tests). Gaeste haben keine.
var rules:
	get:
		return session.rules if session != null and session.is_authority() else null
var ai = null
var config: Dictionary = {}
var match_id := ""
var viewer_seat := 0
# Plaetze, die an diesem Geraet gespielt werden (Host: session.local_seats, Gast: eigener Platz).
var local_seats: Array = []
var instant_ai := false
var settings_override: Dictionary = {}
# Gesetzt vor add_child: Tisch startet mit dieser Konfiguration (Tests).
var pending_config: Dictionary = {}
# Gesetzt vor add_child: Tisch spielt als Online-Gast ueber diese Session (DameGuest
# mit erster Sicht). Ohne Regeln, ohne KI, ohne Spielstand.
var pending_session = null
# Gesetzt vor add_child: Tisch ist Online-Host. {"config", "link", "host_seat",
# "guest_seats": {peer_id: seat}}. Gast-Plaetze erst nach gueltigem hello (peer_joined).
var pending_online_host: Dictionary = {}
# Gesetzt vor add_child (Gast): Besitzer der Verbindung (RtcConnector), siehe _net_owner.
var pending_owner = null
var handoff_pending := false
var spectating := false
var selected := -1
var king_own := -1

var _view: Dictionary = {}
# Ergebnis der letzten eigenen Aktion (Host antwortet synchron).
var _last_result: Dictionary = {}
# Abgelehnte Aktion mit Zustandsaenderung: Sicht davor, Ton kommt mit der neuen Sicht.
var _failure_before: Dictionary = {}
var _awaiting_failure_view := false
# Zaehlt empfangene Sichten (erkennt, ob nach einem KI-Fehlschlag eine kam).
var _views_seen := 0
# Waehrend des Zeitablaufs: keine Einzeltoene, kein Aufdecken (wie bisher).
var _quiet := false
# Test-Haken: wird bei jeder animierten Aktion zusaetzlich aufgerufen.
var _table3d_queue_hook: Callable
var _reveal_until := {}
var _recorded_deal := -1
var _game_recorded := false
# Gast wartet noch auf seinen Platz (Sicht kam erst nach dem Anhaengen).
var _guest_seat_pending := false
# Online-Host: erlaubte Gaeste {peer_id: seat}.
var _guest_seats := {}
# Gast: eigene Aktion gesendet, Ergebnis steht noch aus (keine Doppel-Eingabe).
var _awaiting_result := false
# Online: Verbindung beendet (selbst getrennt oder Host weg). Nicht mehr pollen.
var _net_closed := false
# Besitzer der Verbindung (RtcConnector). Er schliesst beim Freigeben seinen Peer,
# deshalb haelt ihn der Tisch die ganze Partie und schliesst ihn mit dem Link.
var _net_owner = null
var _pause_menu_button: Button
var _again_button: Button
var _host_left_panel: PanelContainer
var _host_left_label: Label
var _host_left_button: Button
var _turn_left := 0.0
var _turn_owner := -1
var _accent := Color(0.55, 1.0, 0.55)
var _back_style := "bordeaux"
var _face_skin := "klassisch"
var _lang := "de"
# 3D-Tisch in Egoperspektive. Die 2D-Plaetze bleiben unsichtbar fuer Fokus und Tests.
var _use_3d := true
var _view3d: SubViewportContainer
var _table3d
var _piles: HBoxContainer

var _bg: ColorRect
var _seats := {}
var _deck_view
var _discard_view
var _drawn_view
var _deck_label: Label
var _discard_label: Label
var _drawn_label: Label
var _info: Label
var _prompt: Label
var _toast: Label
var _log: Label
var _keys: Label
var _actions: HBoxContainer
var _timer_bar: ProgressBar
var _ai_timer: Timer
var _handoff: Control
var _handoff_label: Label
var _handoff_button: Button
var _round_panel: PanelContainer
var _round_text: RichTextLabel
var _round_button: Button
var _over_panel: PanelContainer
var _over_text: RichTextLabel
var _pause_panel: PanelContainer
var _help_panel: PanelContainer
var _fx
var _last_phase := ""
var _last_current := -1
# 0..1: Punkte zaehlen am Rundenende hoch.
var _sum_t := 1.0
var _bars: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_cosmetics()
	_use_3d = bool(_setting("table_3d"))
	_build_ui()
	# Marker fuer den Web-Smoke-Test.
	print("TABLE_READY 3d=%s" % str(_use_3d))
	if session != null:
		return
	if not pending_online_host.is_empty():
		start_online_host(pending_online_host)
		return
	if pending_session != null:
		_net_owner = pending_owner
		pending_owner = null
		_attach_guest(pending_session)
		return
	if not pending_config.is_empty():
		start(pending_config)
		return
	var app := _app()
	var job: Dictionary = app.take_pending() if app != null else {}
	var mode := str(job.get("mode", ""))
	if mode == "online_host":
		start_online_host(job)
		return
	if mode == "online_guest":
		_net_owner = job.get("owner")
		var guest_session = job.get("session")
		if guest_session == null or guest_session.is_authority():
			# Kaputter Auftrag: nie still ein Offline-Spiel starten.
			_abort_online("Online-Gast-Auftrag ohne Gast-Session")
			return
		_attach_guest(guest_session)
		return
	if mode == "resume" and _try_resume():
		return
	var cfg: Dictionary = job.get("config", {})
	if cfg.is_empty():
		cfg = default_config()
	start(cfg)


static func default_config() -> Dictionary:
	return {
		"seat_count": 4,
		"ai_seats": [1, 2, 3],
		"difficulties": {1: "medium", 2: "medium", 3: "medium"},
		"names": ["Spieler", "Lotte", "Bruno", "Erika"],
	}


func _app() -> Node:
	return get_node_or_null("/root/App")


func _setting(key: String):
	if settings_override.has(key):
		return settings_override[key]
	var app := _app()
	if app != null:
		return app.settings.get_value(key)
	var defaults := {"memory_aid": true, "animations": true, "turn_timer": false, "turn_timer_seconds": 30, "ai_speed": "normal", "table_3d": true}
	return defaults.get(key)


func _ai_delay() -> float:
	if instant_ai:
		return 0.0
	return float({"slow": 1.2, "normal": 0.7, "fast": 0.3}.get(str(_setting("ai_speed")), 0.7))


func _sound(name: String) -> void:
	var app := _app()
	if app != null:
		app.audio.play(name)


func _load_cosmetics() -> void:
	var app := _app()
	if app != null:
		_accent = app.accent()
		_back_style = app.back_skin()
		_face_skin = app.face_skin()
		_lang = app.language()


# ---------------------------------------------------------------- Spielstart

func start(cfg: Dictionary) -> void:
	var r = _new_rules(cfg)
	_attach_host(r, int(config.seed) + 7, REVEAL_DEAL_MS)


# Regeln wie offline anlegen (Seed, Match-Kennung); setzt config.
func _new_rules(cfg: Dictionary):
	config = cfg.duplicate(true)
	if not config.has("seed"):
		config.seed = int(Time.get_unix_time_from_system()) % 1000000 + randi() % 1000
	match_id = str(config.get("match_id", "m%d" % int(config.seed)))
	config.match_id = match_id
	var r = DameRulesScript.new()
	r.start_match(config)
	return r


# Online-Host: Regeln wie offline, aber mit Verbindung. Nur der eigene Platz ist lokal
# (kein Hot-Seat), kein Spielstand (_owns_save), KI-Plaetze wie offline ueber ai_step.
# Gaeste bekommen ihren Platz erst nach gueltigem hello (peer_joined).
func start_online_host(job: Dictionary) -> void:
	_net_owner = job.get("owner")
	var link = job.get("link")
	var host_seat := int(job.get("host_seat", 0))
	var cfg = job.get("config", {})
	if link == null or typeof(cfg) != TYPE_DICTIONARY or (cfg as Dictionary).is_empty():
		# Kaputter Auftrag: nie still ein Offline-Spiel starten.
		_abort_online("Online-Host-Auftrag ohne Link oder Konfiguration", link)
		return
	var r = _new_rules(cfg)
	var players: Array = r.state.players
	if host_seat < 0 or host_seat >= players.size() or bool(players[host_seat].is_ai):
		_abort_online("Online-Host-Auftrag mit ungueltigem Host-Platz", link)
		return
	# Nur gueltige Gast-Plaetze: im Tisch, nicht der Host-Platz, kein KI-Platz.
	_guest_seats = {}
	var seats = job.get("guest_seats", {})
	if typeof(seats) == TYPE_DICTIONARY:
		for peer in seats:
			var seat := int(seats[peer])
			var pid := int(peer)
			if pid == DameProtocol.HOST_PEER or seat == host_seat or seat < 0 or seat >= players.size() or bool(players[seat].is_ai):
				push_warning("Tisch: Gast-Platz verworfen (Peer %d -> Platz %d)" % [pid, seat])
				continue
			_guest_seats[pid] = seat
	_attach_host(r, int(config.seed) + 7, REVEAL_DEAL_MS, link, [host_seat])
	session.peer_joined.connect(_on_peer_joined)
	session.peer_left.connect(_on_peer_left)
	_apply_online_ui()


func _try_resume() -> bool:
	var app := _app()
	if app == null:
		return false
	var data: Dictionary = app.saves.load_match()
	if data.is_empty():
		return false
	var r = DameRulesScript.new()
	if not r.from_dict(data.rules):
		app.saves.quarantine()
		return false
	config = data.meta.get("config", {})
	match_id = str(data.meta.get("match_id", "resume"))
	_recorded_deal = int(data.meta.get("recorded_deal", -1))
	_attach_host(r, int(config.get("seed", 1)) + int(r.state.deal) * 31)
	_toast_text("Spiel fortgesetzt.")
	return true


# Lokale Partie: dieses Geraet ist Host ohne Verbindung. Die erste Sicht kommt
# ueber assign_seat und laeuft durch _on_view wie jede spaetere.
func _attach_host(r, ai_seed: int, reveal_ms: int = 0, link = null, seats: Array = []) -> void:
	session = DameHostScript.new(r, link)
	session.view_changed.connect(_on_view)
	session.action_result.connect(_on_result)
	ai = DameAIScript.new(ai_seed)
	session.local_seats = seats.duplicate() if not seats.is_empty() else _human_seats_of(r)
	_after_start()
	var seat: int = viewer_seat
	if seat < 0:
		seat = int(local_seats[0]) if not local_seats.is_empty() else 0
	session.assign_seat(DameProtocol.HOST_PEER, seat)
	# Aufdecken braucht die eigene Sicht: erst nach der Zuordnung.
	if reveal_ms > 0:
		_reveal_own_known(reveal_ms)
		_refresh()


# Online-Gast: keine Regeln, keine KI. Der eigene Platz steht in der Sicht des Hosts;
# lokale Plaetze werden vor der ersten Sicht gesetzt.
# Geltungsbereich: nur Sessions ohne Autoritaet (Online-Host: start_online_host).
func _attach_guest(s) -> void:
	if s.is_authority():
		push_error("Tisch: Authority-Session kann nicht als Gast angehaengt werden")
		return
	session = s
	session.view_changed.connect(_on_view)
	session.action_result.connect(_on_result)
	ai = null
	# Host weg (Review Focus 7): Meldung und Knopf ins Menue.
	if session.link != null and session.link.has_signal("peer_disconnected"):
		session.link.peer_disconnected.connect(_on_link_peer_disconnected)
	_apply_online_ui()
	var first: Dictionary = session.latest_view
	local_seats = [int(first.get("viewer_seat", 0))]
	viewer_seat = int(local_seats[0])
	# Eigene Kennung fuer Chip-Belohnungen (jede Online-Partie zaehlt einzeln).
	match_id = "net%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	if first.is_empty():
		# Platz kommt mit der ersten Sicht (siehe _on_view).
		_guest_seat_pending = true
		return
	_on_view(first, {})
	_reveal_own_known(REVEAL_DEAL_MS)
	_refresh()


static func _human_seats_of(r) -> Array:
	var out: Array = []
	for p in r.state.players:
		if not bool(p.is_ai):
			out.append(int(p.seat))
	return out


# Lokale Plaetze aus der Session; die Plaetze am Tisch entstehen mit der ersten Sicht.
func _after_start() -> void:
	local_seats = session.local_seats.duplicate()
	viewer_seat = int(local_seats[0]) if not local_seats.is_empty() else 0
	if is_hotseat():
		# Erster Mensch am Zug bekommt das Geraet nach der Uebergabe.
		viewer_seat = -1


func is_hotseat() -> bool:
	return local_seats.size() > 1


# ---------------------------------------------------------------- Aufbau

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var app := _app()
	_bg.color = app.table_color() if app != null else Color(0.02, 0.035, 0.02)
	add_child(_bg)
	if _use_3d:
		_build_3d(_bg.color)
	_fx = FxLayerScript.new()
	add_child(_fx)

	var top := HBoxContainer.new()
	top.position = Vector2(16, 8)
	top.size = Vector2(1248, 32)
	top.add_theme_constant_override("separation", 16)
	add_child(top)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("font_size", 16)
	top.add_child(_info)
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(180, 18)
	_timer_bar.show_percentage = false
	_timer_bar.visible = false
	top.add_child(_timer_bar)
	var help := Button.new()
	help.text = "Hilfe [H]"
	help.focus_mode = Control.FOCUS_NONE
	help.pressed.connect(toggle_help)
	top.add_child(help)
	var menu := Button.new()
	menu.text = "Menü [Esc]"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(toggle_pause)
	top.add_child(menu)

	_prompt = Label.new()
	_prompt.position = Vector2(240, 214)
	_prompt.size = Vector2(800, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 17)
	add_child(_prompt)

	var piles := HBoxContainer.new()
	_piles = piles
	piles.position = Vector2(445, 250)
	piles.size = Vector2(390, 180)
	piles.alignment = BoxContainer.ALIGNMENT_CENTER
	piles.add_theme_constant_override("separation", 26)
	add_child(piles)
	var deck_box := _pile_box("Stapel")
	piles.add_child(deck_box[0])
	_deck_view = deck_box[1]
	_deck_label = deck_box[2]
	_deck_view.pressed.connect(func(_v) -> void: _on_deck())
	var discard_box := _pile_box("Ablage")
	piles.add_child(discard_box[0])
	_discard_view = discard_box[1]
	_discard_label = discard_box[2]
	_discard_view.pressed.connect(func(_v) -> void: _on_discard())
	var drawn_box := _pile_box("Gezogen")
	piles.add_child(drawn_box[0])
	_drawn_view = drawn_box[1]
	_drawn_label = drawn_box[2]
	_drawn_view.pressed.connect(func(_v) -> void: _on_drawn())

	_actions = HBoxContainer.new()
	_actions.position = Vector2(240, 444)
	_actions.size = Vector2(800, 40)
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 10)
	add_child(_actions)

	_log = Label.new()
	_log.position = Vector2(968, 500)
	_log.size = Vector2(300, 210)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.add_theme_font_size_override("font_size", 12)
	_log.clip_text = true
	add_child(_log)

	_keys = Label.new()
	_keys.position = Vector2(14, 560)
	_keys.size = Vector2(300, 150)
	_keys.add_theme_font_size_override("font_size", 12)
	_keys.modulate = Color(1, 1, 1, 0.65)
	_keys.text = "Tasten\n1-6  Karte wählen\nLeertaste  vom Stapel ziehen\nEnter  bestätigen / Zug beenden\nA  gezogene Karte ablegen\nX  Extra ablegen\nD  Dame rufen\nZ / E  Ansehen verdecken\nEsc  abbrechen / Menü"
	_keys.visible = false
	add_child(_keys)

	_toast = Label.new()
	_toast.position = Vector2(240, 486)
	_toast.size = Vector2(800, 30)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 18)
	_toast.modulate.a = 0.0
	add_child(_toast)

	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.timeout.connect(_ai_step)
	add_child(_ai_timer)

	if _use_3d:
		_layout_hud_3d()
	_build_round_panel()
	_build_over_panel()
	_build_handoff()
	_build_pause()
	_build_help()


# HUD ueber der 3D-Szene: Hinweise oben, Tisch und Hand bleiben frei.
func _layout_hud_3d() -> void:
	_piles.modulate = Color(1, 1, 1, 0)
	_prompt.position = Vector2(240, 44)
	_actions.position = Vector2(240, 74)
	_toast.position = Vector2(240, 122)
	_log.position = Vector2(14, 330)
	_log.size = Vector2(300, 200)
	_keys.position = Vector2(14, 556)
	for l in [_info, _prompt, _toast, _log, _keys]:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))


func _pile_box(caption: String) -> Array:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var cv = CardViewScript.new()
	cv.setup(false)
	cv.accent = _accent
	cv.back_style = _back_style
	vb.add_child(cv)
	var l := Label.new()
	l.text = caption
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	vb.add_child(l)
	return [vb, cv, l]


func _layout_seats() -> void:
	for s in _seats.values():
		s.queue_free()
	_seats.clear()
	# Rollen aus dem eigenen Blickwinkel, nicht aus der Sicht: bei der Uebergabe
	# ist die Sicht noch die des vorigen Platzes. Namen sind oeffentlich.
	var n: int = int(_view.seat_count)
	var anchor_seat := viewer_seat if viewer_seat >= 0 else (int(local_seats[0]) if not local_seats.is_empty() else 0)
	for seat in range(n):
		var role: String = DameRulesScript.seat_role_for(anchor_seat, seat, n)
		var sv = SeatViewScript.new()
		sv.ghost = _use_3d
		sv.accent = _accent
		sv.back_style = _back_style
		sv.setup(seat, role != "self")
		sv.set_meta("role", role)
		sv.card_pressed.connect(_on_card)
		add_child(sv)
		move_child(sv, 1)
		_seats[seat] = sv
	_place_seats()
	if _table3d != null:
		var roles := {}
		var names := {}
		var angles := {}
		for seat in range(n):
			roles[seat] = DameRulesScript.seat_role_for(anchor_seat, seat, n)
			names[seat] = str(_view.players[seat].name)
			angles[seat] = DameRulesScript.seat_angle_for(anchor_seat, seat, n)
		_table3d.layout(roles, names, angles)


func _place_seats() -> void:
	for seat in _seats:
		var sv: Control = _seats[seat]
		sv.reset_size()
		var sz: Vector2 = sv.get_combined_minimum_size()
		match str(sv.get_meta("role")):
			"self":
				sv.position = Vector2(640 - sz.x / 2.0, 712 - sz.y)
			"opposite":
				sv.position = Vector2(640 - sz.x / 2.0, 44)
			"left":
				sv.position = Vector2(14, 230)
			"right":
				sv.position = Vector2(1266 - sz.x, 230)


func _panel(pos: Vector2, sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = sz
	p.visible = false
	add_child(p)
	return p


func _build_round_panel() -> void:
	_round_panel = _panel(Vector2(380, 214), Vector2(520, 270))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_round_panel.add_child(vb)
	_round_text = RichTextLabel.new()
	_round_text.bbcode_enabled = true
	_round_text.fit_content = true
	_round_text.custom_minimum_size = Vector2(490, 180)
	_round_text.add_theme_font_size_override("normal_font_size", 15)
	_round_text.add_theme_font_size_override("bold_font_size", 17)
	vb.add_child(_round_text)
	_round_button = Button.new()
	_round_button.text = "Nächste Ausgabe [Enter]"
	_round_button.pressed.connect(next_deal)
	vb.add_child(_round_button)


func _build_over_panel() -> void:
	_over_panel = _panel(Vector2(340, 170), Vector2(600, 330))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_over_panel.add_child(vb)
	_over_text = RichTextLabel.new()
	_over_text.bbcode_enabled = true
	_over_text.fit_content = true
	_over_text.custom_minimum_size = Vector2(570, 220)
	_over_text.add_theme_font_size_override("normal_font_size", 16)
	_over_text.add_theme_font_size_override("bold_font_size", 22)
	vb.add_child(_over_text)
	_bars = VBoxContainer.new()
	_bars.add_theme_constant_override("separation", 4)
	vb.add_child(_bars)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	var again := Button.new()
	again.text = "Neues Spiel"
	again.pressed.connect(_on_play_again)
	row.add_child(again)
	_again_button = again
	var menu := Button.new()
	menu.text = "Hauptmenü"
	menu.pressed.connect(_on_main_menu)
	row.add_child(menu)


func _build_handoff() -> void:
	_handoff = ColorRect.new()
	_handoff.set_anchors_preset(Control.PRESET_FULL_RECT)
	(_handoff as ColorRect).color = Color(0.01, 0.02, 0.01, 1.0)
	_handoff.visible = false
	add_child(_handoff)
	var vb := VBoxContainer.new()
	vb.position = Vector2(340, 260)
	vb.size = Vector2(600, 200)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	_handoff.add_child(vb)
	_handoff_label = Label.new()
	_handoff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_handoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_handoff_label.add_theme_font_size_override("font_size", 24)
	vb.add_child(_handoff_label)
	_handoff_button = Button.new()
	_handoff_button.pressed.connect(confirm_handoff)
	vb.add_child(_handoff_button)


# Anleitung im Spiel (Spec: Tutorial-Fenster): kompakte Regeln und Tasten, scrollbar.
func _build_help() -> void:
	_help_panel = _panel(Vector2(190, 70), Vector2(900, 590))
	_help_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_help_panel.add_child(vb)
	var title := Label.new()
	title.text = "Anleitung"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiThemeScript.heading_font())
	title.add_theme_font_size_override("font_size", 28)
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 450)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var text := RichTextLabel.new()
	text.name = "HelpText"
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(840, 0)
	text.add_theme_font_size_override("normal_font_size", 16)
	text.add_theme_font_size_override("bold_font_size", 17)
	text.text = HELP_EN if _lang == "en" else HELP_DE
	scroll.add_child(text)
	var close := Button.new()
	close.text = "Schließen [H]"
	close.pressed.connect(toggle_help)
	vb.add_child(close)


func toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible
	if _help_panel.visible:
		_pause_panel.visible = false
		_ai_timer.paused = true
		_help_panel.get_child(0).get_child(2).grab_focus()
	else:
		_ai_timer.paused = false


func _build_pause() -> void:
	_pause_panel = _panel(Vector2(440, 170), Vector2(400, 300))
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(vb)
	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)
	var cont := Button.new()
	cont.text = "Weiterspielen"
	cont.pressed.connect(toggle_pause)
	vb.add_child(cont)
	var menu := Button.new()
	menu.text = "Hauptmenü (Spiel wird gespeichert)"
	menu.pressed.connect(_on_main_menu)
	vb.add_child(menu)
	_pause_menu_button = menu
	_build_skin_picker(vb)


# Schnellauswahl (Spec Professional Polish): nur gekaufte Skins, wirkt sofort.
var skin_pickers := {}

func _build_skin_picker(parent: VBoxContainer) -> void:
	var app := _app()
	if app == null:
		return
	var sep := HSeparator.new()
	parent.add_child(sep)
	var head := Label.new()
	head.text = "Aussehen"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(head)
	for cat in CatalogScript.CATEGORIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := Label.new()
		l.text = str(CatalogScript.CATEGORIES[cat])
		l.custom_minimum_size = Vector2(150, 0)
		row.add_child(l)
		var o := OptionButton.new()
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ids: Array = []
		for it in CatalogScript.items_in(cat):
			if app.profile.owns(str(it.id)):
				o.add_item(str(it.name))
				ids.append(str(it.id))
		o.select(maxi(ids.find(app.profile.equipped(cat)), 0))
		o.disabled = ids.size() < 2
		o.item_selected.connect(func(i: int) -> void: apply_skin(ids[i]))
		row.add_child(o)
		parent.add_child(row)
		skin_pickers[cat] = o


func apply_skin(id: String) -> void:
	var app := _app()
	if app == null or not app.profile.equip(id):
		return
	_back_style = app.back_skin()
	_face_skin = app.face_skin()
	if _table3d != null:
		_table3d.restyle({"back": _back_style, "face": _face_skin, "felt": app.table_color()})
	for sv in _seats.values():
		sv.back_style = _back_style
	_refresh()


func _build_3d(bg: Color) -> void:
	_view3d = SubViewportContainer.new()
	_view3d.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view3d.stretch = true
	_view3d.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_view3d)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	_view3d.add_child(vp)
	_table3d = Table3DScript.new()
	vp.add_child(_table3d)
	_table3d.build({"accent": _accent, "back": _back_style, "face": _face_skin, "felt": bg, "lang": _lang})
	_view3d.gui_input.connect(_on_view3d_input)


func _on_view3d_input(event: InputEvent) -> void:
	if _table3d == null:
		return
	if event is InputEventMouseMotion:
		var info: Dictionary = _table3d.pick(event.position)
		_table3d.set_hover(info)
		_view3d.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _table3d.is_target(info) else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit: Dictionary = _table3d.pick(event.position)
		match str(hit.get("kind", "")):
			"card":
				_on_card(int(hit.seat), int(hit.index))
			"deck":
				_on_deck()
			"discard":
				_on_discard()
			"drawn":
				_on_drawn()
		accept_event()


func _sync_3d() -> void:
	var targets := {}
	for seat in _seats:
		targets[seat] = _targets_for(seat, _view.players[seat])
	_table3d.animate = bool(_setting("animations"))
	_table3d.sync(_view, {
		"face": _face_for,
		"peek": func(seat: int, i: int) -> bool: return int(_reveal_until.get("%d:%d" % [seat, i], 0)) > Time.get_ticks_msec(),
		"targets": targets,
		"selected": king_own if king_own >= 0 else selected,
		"drawn_face": _drawn_view.shows_face(),
		"deck_target": _deck_view.targetable,
		"discard_target": _discard_view.targetable,
		"drawn_target": _drawn_view.targetable,
	})
	# Unsichtbare 2D-Reste duerfen keine Klicks abfangen.
	for sv in _seats.values():
		_ghostify(sv)
	_ghostify(_piles)


static func _ghostify(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ghostify(c)


# ---------------------------------------------------------------- Ablauf

func _after_change() -> void:
	if _view.is_empty():
		return
	var phase := str(_view.phase)
	var current := int(_view.current_index)
	var current_is_ai := bool(_view.players[current].is_ai)
	if phase == "round_end" or phase == "game_over":
		spectating = false
		if is_hotseat() and viewer_seat < 0:
			viewer_seat = int(local_seats[0])
		_record_round_once()
		if phase == "game_over":
			_record_game_once()
	elif is_hotseat():
		if current_is_ai:
			spectating = true
		elif (current != viewer_seat or spectating) and not handoff_pending:
			_begin_handoff(current)
	if not current_is_ai or phase == "round_end" or phase == "game_over":
		_ai_timer.stop()
	_events(phase, current)
	_refresh()
	# KI-Zuege plant nur der Host.
	if (phase == "play" or phase == "dame_called") and current_is_ai and not handoff_pending and session.is_authority():
		if instant_ai:
			_ai_timer.stop()
			call_deferred("_ai_step")
		else:
			_ai_timer.start(maxf(_ai_delay(), 0.05))
	state_changed.emit()


func _events(phase: String, current: int) -> void:
	if _fx == null:
		return
	_fx.animate = bool(_setting("animations")) and not instant_ai
	_fx.set_dame_active(phase == "dame_called", int(_view.dame_turns_left))
	if phase == "dame_called" and _last_phase == "play":
		var caller := int(_view.dame_caller_index)
		if caller >= 0:
			_fx.dame_called(str(_view.players[caller].name))
	elif (phase == "play" or phase == "dame_called") and current != _last_current and not handoff_pending:
		var mine := current == viewer_seat and not bool(_view.players[current].is_ai)
		_fx.turn_banner(tr("Du bist am Zug") if mine else tr("Zug von %s") % str(_view.players[current].name))
	if phase == "round_end" and _last_phase != "round_end":
		# Punkte zaehlen sichtbar hoch.
		_sum_t = 0.0 if _fx.animate else 1.0
		if _fx.animate:
			var tw := create_tween()
			tw.tween_interval(0.6)
			tw.tween_method(func(v: float) -> void:
				_sum_t = v
				if _round_panel.visible:
					_round_text.text = _round_summary(), 0.0, 1.0, 1.2)
	if phase == "game_over" and _last_phase != "game_over":
		var w := int(_view.winner_index)
		if w >= 0 and not bool(_view.players[w].is_ai):
			_fx.confetti()
		if w >= 0:
			_fx.winner(tr("Du gewinnst!") if w == _local_seat() else tr("%s gewinnt!") % str(_view.players[w].name))
	elif phase != "game_over":
		_fx.clear_winner()
	_last_phase = phase
	_last_current = current


func _begin_handoff(seat: int) -> void:
	handoff_pending = true
	spectating = false
	selected = -1
	king_own = -1
	_reveal_until.clear()
	# Erst alle Gesichter weg, dann die Abdeckung zeigen.
	for sv in _seats.values():
		sv.clear_faces()
	_drawn_view.set_card({}, false)
	if _table3d != null:
		_table3d.clear_faces()
	var name := str(_view.players[seat].name)
	_handoff_label.text = tr("Gerät an %s weitergeben.\nNiemand sonst schaut hin.") % name
	_handoff_button.text = tr("Ich bin %s – Karten zeigen [Enter]") % name
	_handoff.visible = true
	_handoff_button.grab_focus()


func confirm_handoff() -> void:
	if not handoff_pending:
		return
	handoff_pending = false
	_handoff.visible = false
	var seat := int(_view.current_index)
	var relayout: bool = viewer_seat != seat
	viewer_seat = seat
	if relayout:
		_layout_seats()
	# Hot-Seat: das Geraet spielt jetzt diesen Platz; der Host ordnet ihn zu und
	# liefert die Sicht des neuen Spielers. Erst danach aufdecken.
	session.assign_seat(DameProtocol.HOST_PEER, seat)
	_reveal_own_known(REVEAL_DEAL_MS if int(_view.round) == 1 else REVEAL_SWAP_MS)
	_sound("click")
	_after_change()


func _ai_step() -> void:
	if not _ai_due():
		return
	# Erfolg kommt als Sicht ueber _on_view; nur ein Fehlschlag braucht Nacharbeit.
	var before := _view
	var seen := _views_seen
	var result: Dictionary = session.ai_step(ai)
	if not bool(result.get("ok", false)):
		_feedback_from(before, _view, {}, false)
		if seen == _views_seen:
			# Keine neue Sicht: trotzdem weiterplanen wie bisher.
			_after_change()


# Fuer Tests: alle anstehenden KI-Schritte sofort ausfuehren.
func run_ai_until_human(max_steps: int = 400) -> void:
	var guard := 0
	while guard < max_steps and _ai_due():
		guard += 1
		_ai_timer.stop()
		_ai_step()


# KI ist laut Sicht am Zug und dieses Geraet ist der Host.
func _ai_due() -> bool:
	if session == null or not session.is_authority() or _view.is_empty():
		return false
	var phase := str(_view.phase)
	if phase != "play" and phase != "dame_called":
		return false
	return bool(_view.players[int(_view.current_index)].is_ai)


# Einziger Schreibweg des Menschen: Aktion an die Session. Der Platz kommt vom Host.
func act(action: Dictionary) -> Dictionary:
	if session == null or handoff_pending or _net_closed:
		return {"ok": false, "reason": "Nicht bereit"}
	# Gast: solange das Ergebnis der letzten Aktion aussteht, nichts doppelt senden.
	if _awaiting_result:
		return {"ok": false, "reason": "Warte auf den Host …"}
	_last_result = {}
	if not session.is_authority():
		_awaiting_result = true
	session.send_action(action)
	# Host antwortet synchron; ein Gast bekommt das Ergebnis spaeter per Signal.
	return _last_result if not _last_result.is_empty() else {"ok": true, "pending": true}


# Antwort auf die eigene Aktion. Fehler: Ton und Hinweis, sonst Auswahl zuruecksetzen.
func _on_result(msg: Dictionary) -> void:
	_awaiting_result = false
	_last_result = {"ok": bool(msg.get("ok", false)), "reason": str(msg.get("reason", ""))}
	if bool(_last_result.ok):
		selected = -1
		king_own = -1
		return
	_toast_text(str(_last_result.reason))
	if bool(msg.get("changed", false)):
		# Abgelehnt, aber veraendert (falsches Extra-Ablegen = Strafkarte): der Host
		# schickt gleich eine neue Sicht; der Ton entsteht beim Vergleich in _on_view.
		_failure_before = _view
		_awaiting_failure_view = true
	else:
		_feedback_from(_view, _view, {}, false)


# Einziger Ort fuer Darstellung: Sicht merken, Aktion animieren, Toene, Aufdecken.
func _on_view(view: Dictionary, action: Dictionary) -> void:
	var before := _view
	_view = view
	# Absichtlich: jede neue Sicht loest die Eingabesperre. Der Host schickt das
	# Ergebnis immer vor der Sicht; eine Sicht heisst also, die Aktion ist erledigt.
	_awaiting_result = false
	# Gast vor Platzzuweisung angehaengt: Platz aus der ersten Sicht, einmal neu aufbauen.
	if _guest_seat_pending and not view.is_empty() and not session.is_authority():
		_guest_seat_pending = false
		local_seats = [int(view.get("viewer_seat", 0))]
		viewer_seat = int(local_seats[0])
		if not _seats.is_empty():
			_layout_seats()
		# Wie beim direkten Anhaengen: eigene bekannte Karten kurz zeigen.
		_reveal_own_known(REVEAL_DEAL_MS)
	_views_seen += 1
	# Web-Test-Bruecke (nur ?e2e=1): jede empfangene Sicht melden.
	if _is_online():
		var e2e_app := _app()
		if e2e_app != null and e2e_app.has_method("e2e_mode") and e2e_app.e2e_mode():
			print("ONLINE_VIEW rev=%d" % int(session.rev))
	# Erste Sicht (oder andere Platzzahl): Plaetze aus der Sicht aufbauen.
	if _seats.size() != int(view.seat_count):
		_layout_seats()
	if action.is_empty() and _awaiting_failure_view:
		_awaiting_failure_view = false
		_feedback_from(_failure_before, view, {}, false)
		_failure_before = {}
	if not action.is_empty():
		if _table3d != null:
			_table3d.queue_action(action)
		if _table3d_queue_hook.is_valid():
			_table3d_queue_hook.call(action)
		if not _quiet:
			_feedback_from(before, view, action)
			var seat := int(action.get("seat", -1))
			if seat >= 0 and seat == viewer_seat:
				_after_own_action(action)
	if session.is_authority():
		_save()
	_after_change()


func _after_own_action(action: Dictionary) -> void:
	var seat := int(action.seat)
	match str(action.type):
		"swap":
			_reveal(seat, int(action.hand_index), REVEAL_SWAP_MS)
		"look_card":
			_reveal(int(action.target_seat), int(action.hand_index), REVEAL_PEEK_MS)
		"king_swap":
			var look = _view.get("private_look")
			if look != null:
				_toast_text(tr("König: angesehen %s, dann blind getauscht.") % _card_name(look))


static func _penalties_in(view: Dictionary) -> int:
	var n := 0
	for p in view.get("players", []):
		n += int(p.penalty_count)
	return n


# Toene aus dem Vergleich zweier Sichten, Reihenfolge wie bisher.
func _feedback_from(before: Dictionary, after: Dictionary, action: Dictionary, ok: bool = true) -> void:
	if str(action.get("type", "")) == "start_next_round":
		_reveal_until.clear()
		if is_hotseat():
			viewer_seat = -1
			spectating = true
		else:
			_reveal_own_known(REVEAL_DEAL_MS)
		_sound("shuffle")
		return
	if before.is_empty() or after.is_empty():
		if not ok:
			_sound("error")
		return
	var phase := str(after.phase)
	if _penalties_in(after) > _penalties_in(before) and phase != "round_end":
		_sound("penalty")
	elif not ok:
		_sound("error")
		return
	if phase == "dame_called" and str(before.phase) == "play":
		_sound("dame")
	elif phase == "game_over":
		# Sieg-Jingle nur, wenn ein Mensch gewinnt; sonst der absteigende.
		var w := int(after.winner_index)
		_sound("win" if w >= 0 and not bool(after.players[w].is_ai) else "lose")
	elif phase == "round_end":
		_sound("flip")
	elif int(after.discard_count) != int(before.discard_count):
		_sound("place")
	else:
		_sound("draw")


# ---------------------------------------------------------------- Eingabe

func _human_turn() -> bool:
	if _view.is_empty() or handoff_pending or _net_closed:
		return false
	var phase := str(_view.phase)
	if phase != "play" and phase != "dame_called":
		return false
	var current := int(_view.current_index)
	return not bool(_view.players[current].is_ai) and current == viewer_seat


func _on_deck() -> void:
	if _human_turn() and str(_view.turn_step) == "draw":
		act({"type": "draw_deck"})


func _on_discard() -> void:
	if not _human_turn():
		return
	var step := str(_view.turn_step)
	if step == "draw":
		act({"type": "draw_discard"})
	elif step == "play":
		act({"type": "discard_drawn"})


func _on_drawn() -> void:
	if _human_turn() and str(_view.turn_step) == "play":
		act({"type": "discard_drawn"})


func _on_card(seat: int, index: int) -> void:
	if not _human_turn():
		return
	match str(_view.turn_step):
		"draw":
			if seat == viewer_seat:
				select(index)
		"play":
			if seat == viewer_seat:
				act({"type": "swap", "hand_index": index})
		"jack":
			act({"type": "look_card", "target_seat": seat, "hand_index": index})
		"king":
			if seat == viewer_seat:
				king_own = index
				selected = index
				_refresh()
			elif king_own >= 0:
				act({"type": "king_swap", "opponent_seat": seat, "opponent_index": index, "chosen_index": king_own})
			else:
				_toast_text("Erst eine eigene Karte wählen.")
		"extra":
			if seat == viewer_seat:
				act({"type": "discard_extra", "hand_index": index})


func select(index: int) -> void:
	var sv = _seats.get(viewer_seat)
	if sv == null or index < 0 or index >= sv.cards().size():
		return
	selected = index
	if str(_view.get("turn_step", "")) == "king":
		king_own = index
	_refresh()


func call_dame() -> void:
	if _human_turn():
		act({"type": "call_dame"})


func end_turn() -> void:
	if _human_turn():
		act({"type": "end_turn"})


func next_deal() -> void:
	# Nur der Host startet die naechste Ausgabe; Ton und Aufdecken kommen aus _on_view.
	if session == null or str(_view.get("phase", "")) != "round_end":
		return
	if session.is_authority():
		session.next_round()
	else:
		# Gast: nur der Hinweis, er bleibt auch nach jedem Neuzeichnen (_prompt_text).
		_prompt.text = _prompt_text()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if _help_panel.visible:
		if key == KEY_H or key == KEY_ESCAPE:
			toggle_help()
			accept_event()
		return
	if key == KEY_H and not handoff_pending:
		toggle_help()
		accept_event()
		return
	if _pause_panel.visible:
		if key == KEY_ESCAPE:
			toggle_pause()
			accept_event()
		return
	if handoff_pending:
		if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
			confirm_handoff()
			accept_event()
		elif key == KEY_ESCAPE:
			toggle_pause()
			accept_event()
		return
	var phase := str(_view.get("phase", ""))
	if phase == "round_end" and (key == KEY_ENTER or key == KEY_KP_ENTER):
		next_deal()
		accept_event()
		return
	if key >= KEY_1 and key <= KEY_6:
		select(key - KEY_1)
		accept_event()
		return
	var step := str(_view.get("turn_step", ""))
	match key:
		KEY_SPACE:
			_on_deck()
		KEY_ENTER, KEY_KP_ENTER:
			if step == "play" and selected >= 0:
				act({"type": "swap", "hand_index": selected})
			elif step == "extra":
				end_turn()
			elif step == "jack" and selected >= 0:
				act({"type": "look_card", "target_seat": viewer_seat, "hand_index": selected})
			else:
				return
		KEY_A:
			if step == "play" and _human_turn():
				act({"type": "discard_drawn"})
		KEY_X:
			if step == "extra" and selected >= 0 and _human_turn():
				act({"type": "discard_extra", "hand_index": selected})
		KEY_D:
			call_dame()
		KEY_Z, KEY_E:
			_reveal_until.clear()
			_refresh()
		KEY_ESCAPE:
			if king_own >= 0 or selected >= 0:
				king_own = -1
				selected = -1
				_refresh()
			else:
				toggle_pause()
		_:
			return
	accept_event()


func toggle_pause() -> void:
	_pause_panel.visible = not _pause_panel.visible
	if _pause_panel.visible:
		_pause_panel.reset_size()
		_pause_panel.position = (Vector2(1280, 720) - _pause_panel.size) / 2.0
		_ai_timer.paused = true
		_pause_panel.get_child(0).get_child(1).grab_focus()
	else:
		_ai_timer.paused = false


func _on_main_menu() -> void:
	_save()
	# Online: Verbindung trennen (Pause-Text sagt es an).
	_close_link()
	var app := _app()
	if app != null:
		app.goto(app.MAIN_MENU)


func _on_play_again() -> void:
	# Online (Gast oder Host mit Link): Verbindung schliessen, zurueck zum
	# Online-Bildschirm. Nie still ein Offline-Spiel starten.
	if _is_online():
		_close_link()
		var online_app := _app()
		if online_app != null:
			online_app.goto(online_app.online_screen())
		return
	var cfg := config.duplicate(true)
	cfg.erase("seed")
	cfg.erase("match_id")
	cfg.erase("_chips_earned")
	var app := _app()
	if app != null:
		app.new_match(cfg)
	else:
		start(cfg)


# ---------------------------------------------------------------- Online

# Partie mit Verbindung (Gast oder Online-Host).
func _is_online() -> bool:
	return session != null and session.link != null


# Online-Texte, sobald die Session feststeht (_build_ui laeuft vorher).
func _apply_online_ui() -> void:
	if _is_online() and _pause_menu_button != null:
		_pause_menu_button.text = "Hauptmenü (Verbindung wird getrennt)"


# Verbindung beenden und danach nicht mehr pollen.
# Idempotent: schliesst immer, auch wenn die Gegenseite schon weg ist.
func _close_link() -> void:
	# Besitzer zuerst: schliesst Peer-Verbindungen und Multiplayer-Peer (WebRTC-Threads).
	_close_owner()
	if not _is_online():
		return
	_net_closed = true
	_awaiting_result = false
	if session.link.has_method("close"):
		session.link.close()


# Idempotent: Besitzer genau einmal schliessen und loslassen.
func _close_owner() -> void:
	if _net_owner == null:
		return
	var net_owner = _net_owner
	_net_owner = null
	if net_owner.has_method("close"):
		net_owner.close()


# Tisch verschwindet auf irgendeinem Weg (Szenenwechsel, free): Verbindung nie offen lassen.
func _exit_tree() -> void:
	_close_link()


# Kaputter Online-Auftrag: zurueck zum Online-Bildschirm (sonst Hauptmenue), Link schliessen.
func _abort_online(reason: String, link = null) -> void:
	push_warning("Tisch: " + reason)
	_close_owner()
	if link != null and link.has_method("close"):
		link.close()
	var app := _app()
	if app != null:
		app.goto(app.online_screen())


# Host: gueltiges hello eines Gastes. Nur bekannte Peers bekommen ihren Platz.
func _on_peer_joined(peer_id: int) -> void:
	if not _guest_seats.has(peer_id) or _net_closed:
		return
	session.assign_seat(peer_id, int(_guest_seats[peer_id]))


# Host: Gast getrennt. Der Platz bleibt am Tisch (Abwesenheit nach §11 folgt spaeter).
func _on_peer_left(peer_id: int) -> void:
	if not _guest_seats.has(peer_id) or _view.is_empty():
		return
	var seat := int(_guest_seats[peer_id])
	if seat >= 0 and seat < (_view.players as Array).size():
		_toast_text(tr("%s hat die Verbindung verloren.") % str(_view.players[seat].name))


# Gast: die Verbindung zum Host ist weg.
func _on_link_peer_disconnected(peer_id: int) -> void:
	if peer_id != DameProtocol.HOST_PEER or _net_closed:
		return
	# Sofort nicht mehr pollen; schliessen erst nach dem laufenden poll() des Peers
	# (das Signal kommt mitten aus dessen Schleife). _exit_tree schliesst sonst.
	_net_closed = true
	_awaiting_result = false
	call_deferred("_close_link")
	_ai_timer.stop()
	# Nach dem Spielende ist das normal (Host spielt neu oder geht): keine Meldung.
	if str(_view.get("phase", "")) == "game_over":
		return
	_show_host_left()


func _show_host_left() -> void:
	if _host_left_panel == null:
		_host_left_panel = _panel(Vector2(340, 250), Vector2(600, 200))
		_host_left_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 16)
		_host_left_panel.add_child(vb)
		_host_left_label = Label.new()
		_host_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_host_left_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_host_left_label.custom_minimum_size = Vector2(560, 0)
		_host_left_label.add_theme_font_size_override("font_size", 20)
		_host_left_label.text = "Der Host hat die Partie verlassen. Die Partie endet ohne Wertung."
		vb.add_child(_host_left_label)
		_host_left_button = Button.new()
		_host_left_button.text = "Hauptmenü"
		_host_left_button.pressed.connect(_on_main_menu)
		vb.add_child(_host_left_button)
	_pause_panel.visible = false
	_host_left_panel.visible = true
	_host_left_button.grab_focus()
	_refresh()


# ---------------------------------------------------------------- Zugtimer

func _process(delta: float) -> void:
	# Online: Pakete abholen (Gast immer, Host nur mit Verbindung).
	if session != null and session.link != null and not _net_closed:
		session.poll()
	if _view.is_empty():
		return
	# Zugtimer laeuft nur beim Host; ein Gast hat (vorerst) keinen.
	if session == null or not session.is_authority():
		_timer_bar.visible = false
		_turn_owner = -1
		return
	var step := str(_view.turn_step)
	# Pause bei Bube/Koenig-Auswahl (Spec Blitz-Modus).
	var paused := step == "jack" or step == "king"
	var running := bool(_setting("turn_timer")) and _human_turn() and not _pause_panel.visible
	_timer_bar.visible = running
	if not running:
		_turn_owner = -1
		return
	var owner := int(_view.current_index) * 1000 + int(_view.round)
	var total := float(_setting("turn_timer_seconds"))
	if owner != _turn_owner:
		_turn_owner = owner
		_turn_left = total
	if not paused:
		_turn_left -= delta
	_timer_bar.max_value = total
	_timer_bar.value = maxf(_turn_left, 0.0)
	if _turn_left <= 0.0:
		_turn_owner = -1
		timeout_turn()


# Zeit abgelaufen: Zug mit sicheren Standardaktionen beenden.
func timeout_turn() -> void:
	# Zeitablauf entscheidet nur der Host.
	if not _human_turn() or not session.is_authority():
		return
	# Zeit abgelaufen: der Host gibt genau eine Strafkarte und beendet den Zug sicher.
	# Die Einzelschritte bleiben stumm; Toene und Hinweis wie bisher einmal am Ende.
	_quiet = true
	var res: Dictionary = session.timeout_turn(ai)
	_quiet = false
	if bool(res.get("ok", false)):
		_sound("penalty")
	_toast_text("Zeit abgelaufen – Strafkarte, Zug beendet.")
	_sound("error")


# ---------------------------------------------------------------- Darstellung

func _reveal(seat: int, index: int, ms: int) -> void:
	_reveal_until["%d:%d" % [seat, index]] = Time.get_ticks_msec() + ms
	get_tree().create_timer(ms / 1000.0 + 0.05).timeout.connect(_refresh)


# Eigene bekannte Karten kurz zeigen, nur aus der eigenen Sicht (nie aus einer fremden).
func _reveal_own_known(ms: int) -> void:
	if viewer_seat < 0 or _view.is_empty() or int(_view.get("viewer_seat", -1)) != viewer_seat:
		return
	for card in _view.players[viewer_seat].cards:
		if bool(card.known):
			_reveal(viewer_seat, int(card.index), ms)


func _face_for(seat: int, index: int, card: Dictionary) -> bool:
	if not bool(card.get("known", false)):
		return false
	var phase := str(_view.get("phase", ""))
	if phase == "round_end" or phase == "game_over":
		return true
	if spectating or handoff_pending:
		return false
	if bool(_setting("memory_aid")):
		return true
	return int(_reveal_until.get("%d:%d" % [seat, index], 0)) > Time.get_ticks_msec()


func _targets_for(seat: int, data: Dictionary) -> Array:
	var out: Array = []
	if not _human_turn() or bool(data.eliminated):
		return out
	var step := str(_view.turn_step)
	var own := seat == viewer_seat
	var all: Array = range(data.cards.size())
	match step:
		"play", "extra":
			return all if own else out
		"jack":
			return all
		"king":
			if own:
				return all
			if king_own >= 0 and not bool(data.locked):
				return all
	return out


func _refresh() -> void:
	# Zeichnet nur aus der zuletzt empfangenen Sicht plus lokalem UI-Zustand.
	if _view.is_empty():
		return
	var phase := str(_view.phase)
	for seat in _seats:
		var data: Dictionary = _view.players[seat]
		var sel := selected if seat == viewer_seat else -1
		if seat == viewer_seat and king_own >= 0:
			sel = king_own
		_seats[seat].animate = bool(_setting("animations"))
		_seats[seat].update(data, _face_for, _targets_for(seat, data), sel)
	_place_seats()
	# Stapel, Ablage, gezogene Karte.
	_deck_view.set_card({"known": false} if int(_view.deck_count) > 0 else {}, false)
	_deck_view.targetable = _human_turn() and str(_view.turn_step) == "draw" and not bool(_view.must_take_queen)
	_deck_label.text = tr("Stapel (%d)") % int(_view.deck_count)
	var top = _view.discard_top
	var top_changed := var_to_str(top) != var_to_str(_discard_view.card if not _discard_view.card.is_empty() else null)
	_discard_view.set_card(top if top != null else {}, top != null)
	if top_changed and top != null and bool(_setting("animations")):
		_discard_view.pop()
	var step := str(_view.turn_step)
	_discard_view.targetable = _human_turn() and ((step == "draw" and top != null) or step == "play")
	_discard_label.text = tr("Ablage (%d)") % int(_view.discard_count)
	var drawn = _view.drawn
	var drawn_face: bool = drawn != null and bool(drawn.known) and not spectating and not handoff_pending
	_drawn_view.set_card(drawn if drawn != null else {}, drawn_face)
	_drawn_view.targetable = _human_turn() and step == "play"
	for cv in [_deck_view, _discard_view, _drawn_view]:
		cv.queue_redraw()
	if _table3d != null:
		_sync_3d()
	_info.text = _info_text()
	_prompt.text = _prompt_text()
	var lines: Array = []
	for l in _view.log.slice(maxi(0, _view.log.size() - 9)):
		lines.append(I18nScript.line(str(l)))
	_log.text = "\n".join(PackedStringArray(lines))
	_update_actions()
	_round_panel.visible = phase == "round_end"
	_over_panel.visible = phase == "game_over"
	if phase == "round_end":
		_round_text.text = _round_summary()
		# Die naechste Ausgabe startet nur der Host; der Gast wartet.
		var host: bool = session.is_authority()
		_round_button.disabled = not host
		_round_button.text = "Nächste Ausgabe [Enter]" if host else "Warte auf den Host …"
		if host and not _round_button.has_focus():
			_round_button.grab_focus()
	if phase == "game_over":
		_over_text.text = _game_summary()
		_fill_bars()
	if selected >= 0 and _seats.has(viewer_seat):
		var cv = _seats[viewer_seat].card_at(selected)
		if cv != null and not cv.has_focus():
			cv.grab_focus()


func _info_text() -> String:
	var parts: Array = [tr("Ausgabe %d") % int(_view.deal), tr("Runde %d") % int(_view.round)]
	if bool(_view.safe_phase) and str(_view.phase) == "play":
		parts.append(tr("Safe Phase (Dame ab Runde 3)"))
	if str(_view.phase) == "dame_called":
		parts.append(tr("DAME gerufen – noch %d Züge") % int(_view.dame_turns_left))
	return "  ·  ".join(PackedStringArray(parts))


func _prompt_text() -> String:
	var phase := str(_view.phase)
	if phase == "round_end":
		if session != null and not session.is_authority():
			return tr("Warte auf den Host …")
		return "Ausgabe vorbei. Alle Karten liegen offen."
	if phase == "game_over":
		return "Spiel vorbei."
	if handoff_pending:
		return ""
	var current := int(_view.current_index)
	var name := str(_view.current_name)
	if bool(_view.players[current].is_ai):
		return tr("%s ist am Zug …") % name
	if current != viewer_seat:
		return tr("%s ist am Zug.") % name
	match str(_view.turn_step):
		"draw":
			if bool(_view.must_take_queen):
				return "Offene Dame! Du musst sie von der Ablage nehmen."
			var t := "Ziehe vom Stapel [Leertaste] oder nimm die Ablage."
			if bool(_view.can_call_dame):
				t += " Oder rufe Dame [D]."
			return t
		"play":
			return "Klicke eine eigene Karte zum Tauschen oder lege die gezogene ab [A]."
		"jack":
			return "Bube: Klicke eine verdeckte Karte zum Ansehen."
		"king":
			if king_own < 0:
				return "König: Wähle eine eigene Karte (du siehst sie, dann wird sie getauscht)."
			return "König: Wähle jetzt eine Karte eines Gegners."
		"extra":
			return "Gleicher Rang wie die Ablage? Karte klicken (falsch = Strafkarte). Sonst Zug beenden [Enter]."
	return ""


func _update_actions() -> void:
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	if not _human_turn():
		return
	var step := str(_view.turn_step)
	match step:
		"draw":
			_action_button("Vom Stapel ziehen", _on_deck, not bool(_view.must_take_queen) and int(_view.deck_count) + int(_view.discard_count) > 1)
			_action_button("Ablage nehmen", func() -> void: act({"type": "draw_discard"}), _view.discard_top != null)
			_action_button("Dame rufen", call_dame, bool(_view.can_call_dame))
			if int(_view.deck_count) == 0 and int(_view.discard_count) == 0:
				_action_button("Aussetzen (nichts zu ziehen)", end_turn, true)
		"play":
			_action_button("Gezogene ablegen", func() -> void: act({"type": "discard_drawn"}), true)
		"king":
			if king_own >= 0:
				_action_button("Auswahl aufheben", func() -> void:
					king_own = -1
					selected = -1
					_refresh(), true)
		"extra":
			_action_button("Zug beenden", end_turn, true)


func _action_button(text: String, cb: Callable, enabled: bool) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_actions.add_child(b)


# Gesamtpunkte als Balken, laufen beim Spielende von 0 hoch (Grenze 50 markiert).
func _fill_bars() -> void:
	if _bars == null or _bars.get_child_count() > 0:
		return
	for p in _view.players:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name := Label.new()
		name.text = str(p.name)
		name.custom_minimum_size = Vector2(150, 0)
		row.add_child(name)
		var bar := ProgressBar.new()
		bar.max_value = 60
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(330, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := Label.new()
		val.text = str(int(p.total_score))
		row.add_child(val)
		_bars.add_child(row)
		var target := float(mini(int(p.total_score), 60))
		if bool(_setting("animations")) and not instant_ai:
			create_tween().tween_property(bar, "value", target, 1.0).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			bar.value = target


func _round_summary() -> String:
	var lines: Array = []
	var caller := int(_view.dame_caller_index)
	if caller >= 0:
		var cname := str(_view.players[caller].name)
		var me := caller == _local_seat()
		if bool(_view.last_round_false_call):
			if me:
				lines.append(tr("[b]Du hast dich verrechnet![/b] Strafkarte in der nächsten Ausgabe."))
			else:
				lines.append(tr("[b]%s hat sich verrechnet![/b] Strafkarte in der nächsten Ausgabe.") % cname)
		elif me:
			lines.append(tr("[b]Du hast Dame richtig gerufen![/b]"))
		else:
			lines.append(tr("[b]%s hat Dame richtig gerufen.[/b]") % cname)
	lines.append("")
	# Echte Tabelle: die Casino-Schrift hat keine festen Zeichenbreiten.
	var cells: Array = ["[b]%s[/b]" % tr("Spieler"), "[b]%s[/b]" % tr("Ausgabe"), "[b]%s[/b]" % tr("Gesamt")]
	for p in _view.players:
		var status := ""
		if bool(p.eliminated):
			status = tr("  raus")
		# Gesamt startet beim alten Stand und zaehlt die Ausgabe dazu.
		var sc := int(round(int(p.score) * _sum_t))
		var tot := int(p.total_score) - int(p.score) + sc
		cells.append_array([str(p.name), str(sc), str(tot) + status])
	lines.append("[table=3]" + "".join(PackedStringArray(cells.map(func(c): return "[cell padding=0,2,28,2]%s[/cell]" % c))) + "[/table]")
	lines.append("")
	lines.append(tr("Über 50 scheidet aus, genau 50 setzt auf 0."))
	return "\n".join(PackedStringArray(lines))


func _game_summary() -> String:
	var w := int(_view.winner_index)
	var lines: Array = []
	if w >= 0:
		if w == _local_seat():
			lines.append(tr("[b]Du gewinnst![/b]"))
		else:
			lines.append(tr("[b]%s gewinnt![/b]") % str(_view.players[w].name))
	lines.append("")
	var order: Array = _view.players.duplicate()
	order.sort_custom(func(a, b) -> bool:
		if bool(a.eliminated) != bool(b.eliminated):
			return not bool(a.eliminated)
		return int(a.total_score) < int(b.total_score))
	var place := 1
	var cells: Array = []
	for p in order:
		cells.append_array(["%d." % place, str(p.name), tr("%d Punkte") % int(p.total_score), tr("  (raus)") if bool(p.eliminated) else ""])
		place += 1
	lines.append("[table=4]" + "".join(PackedStringArray(cells.map(func(c): return "[cell padding=0,2,24,2]%s[/cell]" % c))) + "[/table]")
	var earned := int(config.get("_chips_earned", 0))
	if earned > 0:
		lines.append("")
		lines.append(tr("Verdient in dieser Partie: %d Chips") % earned)
	return "\n".join(PackedStringArray(lines))


func _toast_text(text: String) -> void:
	# Gruende aus den Regeln sind deutsch: Muster-Uebersetzung fuer Englisch.
	_toast.text = I18nScript.line(text)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _card_name(card: Dictionary) -> String:
	var rank := str(card.rank)
	return I18nScript.card_name("%s %s" % [CardViewScript.SUIT_NAMES.get(str(card.suit), ""), CardViewScript.RANK_NAMES.get(rank, rank)])


# ---------------------------------------------------------------- Speichern, Statistik, Chips

func _save() -> void:
	var app := _app()
	# Speichern nur als Authority ohne Link (ein Online-Host speichert in 1b nicht).
	if app == null or not _owns_save() or _view.is_empty():
		return
	if str(_view.phase) == "game_over":
		app.saves.clear()
		return
	app.saves.save_match(rules.to_dict(), {"config": config, "match_id": match_id, "recorded_deal": _recorded_deal})


# Spielstand gehoert nur der lokalen Partie: Authority und kein Link.
func _owns_save() -> bool:
	return session != null and session.is_authority() and session.link == null


func _local_seat() -> int:
	# Statistik und Chips nur fuer Partien mit genau einem Menschen.
	return int(local_seats[0]) if local_seats.size() == 1 else -1


func _has_hard_ai() -> bool:
	for p in _view.players:
		if bool(p.is_ai) and str(p.difficulty) == "hard":
			return true
	return false


func _record_round_once() -> void:
	var deal := int(_view.deal)
	if _recorded_deal == deal:
		return
	_recorded_deal = deal
	var app := _app()
	var me := _local_seat()
	if app == null or me < 0:
		_save()
		return
	var p: Dictionary = _view.players[me]
	var called := int(_view.dame_caller_index) == me
	var correct := called and not bool(_view.last_round_false_call)
	app.stats.record_round(int(p.score), called, correct, int(p.get("deal_penalties", 0)))
	var earned := 0
	if app.profile.award("%s-deal-%d" % [match_id, deal], CatalogScript.REWARD_ROUND):
		earned += CatalogScript.REWARD_ROUND
	if correct and app.profile.award("%s-call-%d" % [match_id, deal], CatalogScript.REWARD_CORRECT_CALL):
		earned += CatalogScript.REWARD_CORRECT_CALL
	config["_chips_earned"] = int(config.get("_chips_earned", 0)) + earned
	if earned > 0:
		_toast_text(tr("+%d Chips") % earned)
		_sound("chips")
	_save()


func _record_game_once() -> void:
	if _game_recorded:
		return
	_game_recorded = true
	var app := _app()
	var me := _local_seat()
	if app == null or me < 0:
		return
	var won := int(_view.winner_index) == me
	app.stats.record_game(won)
	if won:
		var amount := CatalogScript.REWARD_WIN * (CatalogScript.HARD_MULTIPLIER if _has_hard_ai() else 1)
		if app.profile.award("%s-win" % match_id, amount):
			config["_chips_earned"] = int(config.get("_chips_earned", 0)) + amount
	# Nur die lokale Partie besitzt den Spielstand; Gast und Online-Host loeschen nie eine fremde.
	if _owns_save():
		app.saves.clear()
