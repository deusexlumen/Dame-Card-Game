extends Control

# Spieltisch. Besitzt genau ein DameRules-Objekt und ist der einzige Schreiber.
# Zeigt nur DameView-Daten. KI-Zuege laufen schrittweise ueber einen Timer.

signal state_changed

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")
const DameViewScript = preload("res://scripts/dame_view.gd")
const SeatViewScript = preload("res://scripts/ui/seat_view.gd")
const CardViewScript = preload("res://scripts/ui/card_view.gd")
const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")
const CatalogScript = preload("res://scripts/services/catalog.gd")
const Table3DScript = preload("res://scripts/table3d/table_3d.gd")

const REVEAL_DEAL_MS := 5000
const REVEAL_PEEK_MS := 3000
const REVEAL_SWAP_MS := 2200

var rules = null
var ai = null
var config: Dictionary = {}
var match_id := ""
var viewer_seat := 0
var human_seats: Array = []
var instant_ai := false
var settings_override: Dictionary = {}
# Gesetzt vor add_child: Tisch startet mit dieser Konfiguration (Tests).
var pending_config: Dictionary = {}
var handoff_pending := false
var spectating := false
var selected := -1
var king_own := -1

var _view: Dictionary = {}
var _reveal_until := {}
var _recorded_deal := -1
var _game_recorded := false
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

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_cosmetics()
	_use_3d = bool(_setting("table_3d"))
	_build_ui()
	# Marker fuer den Web-Smoke-Test.
	print("TABLE_READY 3d=%s" % str(_use_3d))
	if rules != null:
		return
	if not pending_config.is_empty():
		start(pending_config)
		return
	var app := _app()
	var job: Dictionary = app.take_pending() if app != null else {}
	if str(job.get("mode", "")) == "resume" and _try_resume():
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
	config = cfg.duplicate(true)
	if not config.has("seed"):
		config.seed = int(Time.get_unix_time_from_system()) % 1000000 + randi() % 1000
	match_id = str(config.get("match_id", "m%d" % int(config.seed)))
	config.match_id = match_id
	rules = DameRulesScript.new()
	rules.start_match(config)
	ai = DameAIScript.new(int(config.seed) + 7)
	_after_start()
	_reveal_own_known(REVEAL_DEAL_MS)
	_save()
	_after_change()


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
	rules = r
	config = data.meta.get("config", {})
	match_id = str(data.meta.get("match_id", "resume"))
	_recorded_deal = int(data.meta.get("recorded_deal", -1))
	ai = DameAIScript.new(int(config.get("seed", 1)) + int(rules.state.deal) * 31)
	_after_start()
	_toast_text("Spiel fortgesetzt.")
	_after_change()
	return true


func _after_start() -> void:
	human_seats.clear()
	for p in rules.state.players:
		if not bool(p.is_ai):
			human_seats.append(int(p.seat))
	viewer_seat = int(human_seats[0]) if not human_seats.is_empty() else 0
	if is_hotseat():
		# Erster Mensch am Zug bekommt das Geraet nach der Uebergabe.
		viewer_seat = -1
	_layout_seats()


func is_hotseat() -> bool:
	return human_seats.size() > 1


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
	var n: int = rules.seat_count()
	var anchor_seat := viewer_seat if viewer_seat >= 0 else (int(human_seats[0]) if not human_seats.is_empty() else 0)
	for seat in range(n):
		var role: String = rules._seat_role(anchor_seat, seat)
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
		for seat in range(n):
			roles[seat] = rules._seat_role(anchor_seat, seat)
			names[seat] = str(rules.state.players[seat].name)
		_table3d.layout(roles, names)


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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	var again := Button.new()
	again.text = "Neues Spiel"
	again.pressed.connect(_on_play_again)
	row.add_child(again)
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


func _build_pause() -> void:
	_pause_panel = _panel(Vector2(490, 230), Vector2(300, 220))
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
	if rules == null:
		return
	var phase := str(rules.state.phase)
	var current := int(rules.state.current_index)
	var current_is_ai := bool(rules.state.players[current].is_ai)
	if phase == "round_end" or phase == "game_over":
		spectating = false
		if is_hotseat() and viewer_seat < 0:
			viewer_seat = int(human_seats[0])
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
	_refresh()
	if (phase == "play" or phase == "dame_called") and current_is_ai and not handoff_pending:
		if instant_ai:
			_ai_timer.stop()
			call_deferred("_ai_step")
		else:
			_ai_timer.start(maxf(_ai_delay(), 0.05))
	state_changed.emit()


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
	var name := str(rules.state.players[seat].name)
	_handoff_label.text = "Gerät an %s weitergeben.\nNiemand sonst schaut hin." % name
	_handoff_button.text = "Ich bin %s – Karten zeigen [Enter]" % name
	_handoff.visible = true
	_handoff_button.grab_focus()


func confirm_handoff() -> void:
	if not handoff_pending:
		return
	handoff_pending = false
	_handoff.visible = false
	var seat := int(rules.state.current_index)
	var relayout: bool = viewer_seat < 0 or rules._seat_role(viewer_seat, seat) != "self"
	viewer_seat = seat
	if relayout:
		_layout_seats()
	_reveal_own_known(REVEAL_DEAL_MS if int(rules.state.round) == 1 else REVEAL_SWAP_MS)
	_sound("click")
	_after_change()


func _ai_step() -> void:
	if rules == null:
		return
	var phase := str(rules.state.phase)
	if phase != "play" and phase != "dame_called":
		return
	if not bool(rules.current_player().is_ai):
		return
	var before := _snapshot()
	var result: Dictionary = ai.step(rules)
	if _table3d != null and bool(result.get("ok", false)):
		_table3d.queue_action(ai.last_action)
	_feedback(before, result, int(before.current))
	_save()
	_after_change()


# Fuer Tests: alle anstehenden KI-Schritte sofort ausfuehren.
func run_ai_until_human(max_steps: int = 400) -> void:
	var guard := 0
	while guard < max_steps and rules != null:
		guard += 1
		var phase := str(rules.state.phase)
		if phase != "play" and phase != "dame_called":
			return
		if not bool(rules.current_player().is_ai):
			return
		_ai_timer.stop()
		_ai_step()


func act(action: Dictionary) -> Dictionary:
	if rules == null or handoff_pending:
		return {"ok": false, "reason": "Nicht bereit"}
	action.seat = int(rules.state.current_index)
	var before := _snapshot()
	var result: Dictionary = rules.apply_action(action)
	_feedback(before, result, int(before.current))
	if bool(result.ok):
		if _table3d != null:
			_table3d.queue_action(action)
		selected = -1
		king_own = -1
		_after_human_action(action)
	else:
		_toast_text(str(result.reason))
	_save()
	_after_change()
	return result


func _after_human_action(action: Dictionary) -> void:
	var seat := int(action.seat)
	match str(action.type):
		"swap":
			_reveal(seat, int(action.hand_index), REVEAL_SWAP_MS)
		"look_card":
			_reveal(int(action.target_seat), int(action.hand_index), REVEAL_PEEK_MS)
		"king_swap":
			var look = rules.state.last_look
			if look != null:
				_toast_text("König: angesehen %s, dann blind getauscht." % _card_name(look))


func _snapshot() -> Dictionary:
	return {
		"current": int(rules.state.current_index),
		"penalties": _penalty_total(),
		"phase": str(rules.state.phase),
		"discard": rules.state.discard.size(),
	}


func _penalty_total() -> int:
	var n := 0
	for p in rules.state.players:
		n += p.penalty_cards.size()
	return n


func _feedback(before: Dictionary, result: Dictionary, _seat: int) -> void:
	var phase := str(rules.state.phase)
	if _penalty_total() > int(before.penalties) and phase != "round_end":
		_sound("penalty")
	elif not bool(result.get("ok", false)):
		_sound("error")
		return
	if phase == "dame_called" and str(before.phase) == "play":
		_sound("dame")
	elif phase == "game_over":
		_sound("win")
	elif phase == "round_end":
		_sound("flip")
	elif rules.state.discard.size() != int(before.discard):
		_sound("place")
	else:
		_sound("draw")


# ---------------------------------------------------------------- Eingabe

func _human_turn() -> bool:
	if rules == null or handoff_pending:
		return false
	var phase := str(rules.state.phase)
	if phase != "play" and phase != "dame_called":
		return false
	var current := int(rules.state.current_index)
	return not bool(rules.state.players[current].is_ai) and current == viewer_seat


func _on_deck() -> void:
	if _human_turn() and str(rules.state.turn_step) == "draw":
		act({"type": "draw_deck"})


func _on_discard() -> void:
	if not _human_turn():
		return
	var step := str(rules.state.turn_step)
	if step == "draw":
		act({"type": "draw_discard"})
	elif step == "play":
		act({"type": "discard_drawn"})


func _on_drawn() -> void:
	if _human_turn() and str(rules.state.turn_step) == "play":
		act({"type": "discard_drawn"})


func _on_card(seat: int, index: int) -> void:
	if not _human_turn():
		return
	match str(rules.state.turn_step):
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
	if str(rules.state.turn_step) == "king":
		king_own = index
	_refresh()


func call_dame() -> void:
	if _human_turn():
		act({"type": "call_dame"})


func end_turn() -> void:
	if _human_turn():
		act({"type": "end_turn"})


func next_deal() -> void:
	if rules != null and str(rules.state.phase) == "round_end":
		rules.apply_action({"type": "start_next_round"})
		_reveal_until.clear()
		if is_hotseat():
			viewer_seat = -1
			spectating = true
		else:
			_reveal_own_known(REVEAL_DEAL_MS)
		_sound("draw")
		_save()
		_after_change()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
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
	var phase := str(rules.state.phase) if rules != null else ""
	if phase == "round_end" and (key == KEY_ENTER or key == KEY_KP_ENTER):
		next_deal()
		accept_event()
		return
	if key >= KEY_1 and key <= KEY_6:
		select(key - KEY_1)
		accept_event()
		return
	var step := str(rules.state.turn_step) if rules != null else ""
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
	var app := _app()
	if app != null:
		app.goto(app.MAIN_MENU)


func _on_play_again() -> void:
	var cfg := config.duplicate(true)
	cfg.erase("seed")
	cfg.erase("match_id")
	cfg.erase("_chips_earned")
	var app := _app()
	if app != null:
		app.new_match(cfg)
	else:
		start(cfg)


# ---------------------------------------------------------------- Zugtimer

func _process(delta: float) -> void:
	if rules == null:
		return
	var running := bool(_setting("turn_timer")) and _human_turn() and not _pause_panel.visible
	_timer_bar.visible = running
	if not running:
		_turn_owner = -1
		return
	var owner := int(rules.state.current_index) * 1000 + int(rules.state.round)
	var total := float(_setting("turn_timer_seconds"))
	if owner != _turn_owner:
		_turn_owner = owner
		_turn_left = total
	_turn_left -= delta
	_timer_bar.max_value = total
	_timer_bar.value = maxf(_turn_left, 0.0)
	if _turn_left <= 0.0:
		_turn_owner = -1
		timeout_turn()


# Zeit abgelaufen: Zug mit sicheren Standardaktionen beenden.
func timeout_turn() -> void:
	if not _human_turn():
		return
	var seat := int(rules.state.current_index)
	var guard := 0
	while guard < 8 and int(rules.state.current_index) == seat and _human_turn():
		guard += 1
		var fallback: Dictionary = ai.fallback_action(rules, seat)
		var r: Dictionary = rules.apply_action(fallback)
		if not bool(r.ok):
			break
		if _table3d != null:
			_table3d.queue_action(fallback)
	_toast_text("Zeit abgelaufen – Zug automatisch beendet.")
	_sound("error")
	_save()
	_after_change()


# ---------------------------------------------------------------- Darstellung

func _reveal(seat: int, index: int, ms: int) -> void:
	_reveal_until["%d:%d" % [seat, index]] = Time.get_ticks_msec() + ms
	get_tree().create_timer(ms / 1000.0 + 0.05).timeout.connect(_refresh)


func _reveal_own_known(ms: int) -> void:
	if viewer_seat < 0 or rules == null:
		return
	for i in rules.state.players[viewer_seat].known:
		_reveal(viewer_seat, int(i), ms)


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
	var step := str(rules.state.turn_step)
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
	if rules == null:
		return
	var vs := viewer_seat if viewer_seat >= 0 else (int(human_seats[0]) if not human_seats.is_empty() else 0)
	_view = DameViewScript.for_viewer(rules, vs)
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
	_deck_view.targetable = _human_turn() and str(rules.state.turn_step) == "draw" and not bool(_view.must_take_queen)
	_deck_label.text = "Stapel (%d)" % int(_view.deck_count)
	var top = _view.discard_top
	var top_changed := var_to_str(top) != var_to_str(_discard_view.card if not _discard_view.card.is_empty() else null)
	_discard_view.set_card(top if top != null else {}, top != null)
	if top_changed and top != null and bool(_setting("animations")):
		_discard_view.pop()
	var step := str(rules.state.turn_step)
	_discard_view.targetable = _human_turn() and ((step == "draw" and top != null) or step == "play")
	_discard_label.text = "Ablage (%d)" % int(_view.discard_count)
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
	_log.text = "\n".join(PackedStringArray(_view.log.slice(maxi(0, _view.log.size() - 9))))
	_update_actions()
	_round_panel.visible = phase == "round_end"
	_over_panel.visible = phase == "game_over"
	if phase == "round_end":
		_round_text.text = _round_summary()
		if not _round_button.has_focus():
			_round_button.grab_focus()
	if phase == "game_over":
		_over_text.text = _game_summary()
	if selected >= 0 and _seats.has(viewer_seat):
		var cv = _seats[viewer_seat].card_at(selected)
		if cv != null and not cv.has_focus():
			cv.grab_focus()


func _info_text() -> String:
	var parts: Array = ["Ausgabe %d" % int(_view.deal), "Runde %d" % int(_view.round)]
	if bool(_view.safe_phase) and str(_view.phase) == "play":
		parts.append("Safe Phase (Dame ab Runde 3)")
	if str(_view.phase) == "dame_called":
		parts.append("DAME gerufen – noch %d Züge" % int(_view.dame_turns_left))
	return "  ·  ".join(PackedStringArray(parts))


func _prompt_text() -> String:
	var phase := str(_view.phase)
	if phase == "round_end":
		return "Ausgabe vorbei. Alle Karten liegen offen."
	if phase == "game_over":
		return "Spiel vorbei."
	if handoff_pending:
		return ""
	var current := int(_view.current_index)
	var name := str(_view.current_name)
	if bool(rules.state.players[current].is_ai):
		return "%s ist am Zug …" % name
	if current != viewer_seat:
		return "%s ist am Zug." % name
	match str(rules.state.turn_step):
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
	var step := str(rules.state.turn_step)
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


func _round_summary() -> String:
	var lines: Array = []
	var caller := int(_view.dame_caller_index)
	if caller >= 0:
		var cname := str(_view.players[caller].name)
		var me := caller == _local_seat()
		if bool(_view.last_round_false_call):
			if me:
				lines.append("[b]Du hast dich verrechnet![/b] Strafkarte in der nächsten Ausgabe.")
			else:
				lines.append("[b]%s hat sich verrechnet![/b] Strafkarte in der nächsten Ausgabe." % cname)
		elif me:
			lines.append("[b]Du hast Dame richtig gerufen![/b]")
		else:
			lines.append("[b]%s hat Dame richtig gerufen.[/b]" % cname)
	lines.append("")
	lines.append("Spieler          Ausgabe  Gesamt")
	for p in _view.players:
		var status := ""
		if bool(p.eliminated):
			status = "  raus"
		lines.append("%-16s %7d  %6d%s" % [str(p.name).substr(0, 16), int(p.score), int(p.total_score), status])
	lines.append("")
	lines.append("Über 50 scheidet aus, genau 50 setzt auf 0.")
	return "\n".join(PackedStringArray(lines))


func _game_summary() -> String:
	var w := int(_view.winner_index)
	var lines: Array = []
	if w >= 0:
		if w == _local_seat():
			lines.append("[b]Du gewinnst![/b]")
		else:
			lines.append("[b]%s gewinnt![/b]" % str(_view.players[w].name))
	lines.append("")
	var order: Array = _view.players.duplicate()
	order.sort_custom(func(a, b) -> bool:
		if bool(a.eliminated) != bool(b.eliminated):
			return not bool(a.eliminated)
		return int(a.total_score) < int(b.total_score))
	var place := 1
	for p in order:
		lines.append("%d. %-16s %4d Punkte%s" % [place, str(p.name).substr(0, 16), int(p.total_score), "  (raus)" if bool(p.eliminated) else ""])
		place += 1
	var earned := int(config.get("_chips_earned", 0))
	if earned > 0:
		lines.append("")
		lines.append("Verdient in dieser Partie: %d Chips" % earned)
	return "\n".join(PackedStringArray(lines))


func _toast_text(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _card_name(card: Dictionary) -> String:
	var rank := str(card.rank)
	return "%s %s" % [CardViewScript.SUIT_NAMES.get(str(card.suit), ""), CardViewScript.RANK_NAMES.get(rank, rank)]


# ---------------------------------------------------------------- Speichern, Statistik, Chips

func _save() -> void:
	var app := _app()
	if app == null or rules == null:
		return
	if str(rules.state.phase) == "game_over":
		app.saves.clear()
		return
	app.saves.save_match(rules.to_dict(), {"config": config, "match_id": match_id, "recorded_deal": _recorded_deal})


func _local_seat() -> int:
	# Statistik und Chips nur fuer Partien mit genau einem Menschen.
	return int(human_seats[0]) if human_seats.size() == 1 else -1


func _has_hard_ai() -> bool:
	for p in rules.state.players:
		if bool(p.is_ai) and str(p.difficulty) == "hard":
			return true
	return false


func _record_round_once() -> void:
	var deal := int(rules.state.deal)
	if _recorded_deal == deal:
		return
	_recorded_deal = deal
	var app := _app()
	var me := _local_seat()
	if app == null or me < 0:
		_save()
		return
	var p: Dictionary = rules.state.players[me]
	var called := int(rules.state.dame_caller_index) == me
	var correct := called and not bool(rules.state.last_round_false_call)
	app.stats.record_round(int(p.score), called, correct, int(p.get("deal_penalties", 0)))
	var earned := 0
	if app.profile.award("%s-deal-%d" % [match_id, deal], CatalogScript.REWARD_ROUND):
		earned += CatalogScript.REWARD_ROUND
	if correct and app.profile.award("%s-call-%d" % [match_id, deal], CatalogScript.REWARD_CORRECT_CALL):
		earned += CatalogScript.REWARD_CORRECT_CALL
	config["_chips_earned"] = int(config.get("_chips_earned", 0)) + earned
	if earned > 0:
		_toast_text("+%d Chips" % earned)
	_save()


func _record_game_once() -> void:
	if _game_recorded:
		return
	_game_recorded = true
	var app := _app()
	var me := _local_seat()
	if app == null or me < 0:
		return
	var won := int(rules.state.winner_index) == me
	app.stats.record_game(won)
	if won:
		var amount := CatalogScript.REWARD_WIN * (CatalogScript.HARD_MULTIPLIER if _has_hard_ai() else 1)
		if app.profile.award("%s-win" % match_id, amount):
			config["_chips_earned"] = int(config.get("_chips_earned", 0)) + amount
	app.saves.clear()
