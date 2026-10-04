extends Node2D

const DameRulesScript = preload("res://scripts/dame_rules.gd")
const DameAIScript = preload("res://scripts/dame_ai.gd")

var rules = null
var ai = null
var _status: Label
var _buttons: HBoxContainer
var _selected_hand := 0
var _target_seat := 1
var _busy := false
var viewer_seat := 0

func get_view_mode() -> String:
	return "first_person"

func _ready() -> void:
	rules = DameRulesScript.new()
	ai = DameAIScript.new()
	rules.start_match({"seed": 3, "ai_seat": 2})
	_status = $HUD/StatusLabel
	_buttons = $HUD/ActionBar
	_build_buttons()
	_refresh()

func _process(_delta: float) -> void:
	if _busy or rules == null:
		return
	var phase := str(rules.state.phase)
	if phase != "play" and phase != "dame_called":
		return
	var current: Dictionary = rules.current_player()
	if not bool(current.is_ai):
		return
	_busy = true
	ai.complete_turn(rules)
	_busy = false
	_refresh()

func _build_buttons() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	_add_button("Stapel", _on_draw_deck)
	_add_button("Ablage", _on_draw_discard)
	_add_button("Ablegen", _on_discard)
	_add_button("Tauschen", _on_swap)
	_add_button("Extra", _on_extra)
	_add_button("Ansehen", _on_look)
	_add_button("Königstausch", _on_king)
	_add_button("Ziel", _on_cycle_target)
	_add_button("Dame", _on_call)
	_add_button("Zug ende", _on_end)
	_add_button("Nächste Ausgabe", _on_next)

func _add_button(text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	_buttons.add_child(button)

func _on_draw_deck() -> void:
	_act({"type": "draw_deck", "seat": viewer_seat})

func _on_draw_discard() -> void:
	_act({"type": "draw_discard", "seat": viewer_seat})

func _on_discard() -> void:
	_act({"type": "discard_drawn", "seat": viewer_seat})

func _on_swap() -> void:
	_act({"type": "swap", "seat": viewer_seat, "hand_index": _selected_hand})

func _on_extra() -> void:
	_act({"type": "discard_extra", "seat": viewer_seat, "hand_index": _selected_hand})

func _on_look() -> void:
	_act({
		"type": "look_card",
		"seat": viewer_seat,
		"target_seat": _target_seat,
		"hand_index": _selected_hand,
	})

func _on_king() -> void:
	var opp := _target_seat
	if opp == viewer_seat:
		opp = (viewer_seat + 2) % 4
	_act({
		"type": "king_swap",
		"seat": viewer_seat,
		"opponent_seat": opp,
		"opponent_index": _selected_hand,
		"chosen_index": _selected_hand,
	})

func _on_cycle_target() -> void:
	_target_seat = (_target_seat + 1) % 4
	_refresh()

func _on_call() -> void:
	_act({"type": "call_dame", "seat": viewer_seat})

func _on_end() -> void:
	_act({"type": "end_turn", "seat": viewer_seat})

func _on_next() -> void:
	_act({"type": "start_next_round", "seat": viewer_seat})

func _act(action: Dictionary) -> void:
	var result: Dictionary = rules.apply_action(action)
	if not bool(result.get("ok", false)):
		_status.text = str(result.get("reason", ""))
		return
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		if key >= KEY_1 and key <= KEY_4:
			_selected_hand = key - KEY_1
			_refresh()

func _sync_viewer() -> void:
	var phase := str(rules.state.phase)
	if phase != "play" and phase != "dame_called":
		return
	var current: Dictionary = rules.current_player()
	if bool(current.is_ai):
		return
	var seat := int(current.seat)
	if seat != viewer_seat:
		viewer_seat = seat
		_selected_hand = 0
		_target_seat = (seat + 1) % 4

func _refresh() -> void:
	_sync_viewer()
	var view: Dictionary = rules.display_state(viewer_seat)
	_clear_cards($OwnHand)
	_clear_cards($DiscardPile)
	_clear_cards($OppositeSeat)
	var self_entry: Dictionary = {}
	var opposite: Dictionary = {}
	var left := ""
	var right := ""
	for entry in view.players:
		var role := str(entry.role)
		if role == "self":
			self_entry = entry
			_paint_cards($OwnHand, entry.cards, true)
		elif role == "opposite":
			opposite = entry
			_paint_cards($OppositeSeat, entry.cards, false)
		elif role == "left":
			left = "%s\nKarten: %d\nStrafe: %d\nPunkte: %d" % [entry.name, entry.card_count, entry.penalty_count, entry.total_score]
		elif role == "right":
			right = "%s\nKarten: %d\nStrafe: %d\nPunkte: %d" % [entry.name, entry.card_count, entry.penalty_count, entry.total_score]
	var top = view.discard_top
	if top != null:
		_paint_cards($DiscardPile, [top], false)
	var penalty = view.queen_penalty
	if penalty != null:
		var marker := _card_node("Strafe\n1", false)
		marker.position = Vector2(150, 0)
		$DiscardPile.add_child(marker)
	var drawn = ""
	if view.drawn != null:
		drawn = "Gezogen: %s %s" % [view.drawn.rank, view.drawn.suit]
	var queen_line = ""
	if penalty != null:
		queen_line = "Die offene Dame zeigt genau eine Strafkarte."
	var call_line = ""
	if int(view.dame_caller_index) >= 0:
		call_line = "Dame gerufen. Verbleibende Zuege der anderen: %d" % int(view.dame_turns_left)
	if bool(view.last_round_false_call) and str(view.phase) == "round_end":
		call_line = "Falsche Ansage. Naechste Ausgabe fuer den Ansager: 5 statt 4."
	var look_line = ""
	if view.private_look != null:
		look_line = "Angesehen: %s %s, bleibt verdeckt." % [str(view.private_look.rank), str(view.private_look.suit)]
	var names: Array = []
	for entry in view.players:
		names.append(str(entry.name))
	var target_name := str(names[_target_seat]) if _target_seat >= 0 and _target_seat < names.size() else str(_target_seat)
	_status.text = "First Person | Runde %d | %s | Schritt %s | Wahl Hand %d | Ziel %s\n%s\n%s\n%s\n%s\n%s" % [
		int(view.round),
		str(view.current_name),
		str(view.turn_step),
		_selected_hand + 1,
		target_name,
		str(view.last_action),
		drawn,
		look_line,
		queen_line,
		call_line,
	]
	$HUD/SideSeatLeft.text = left
	$HUD/SideSeatRight.text = right
	var opp_label: Label = $OppositeSeat/NameLabel
	if not opposite.is_empty():
		opp_label.text = "%s  %d Karten%s" % [opposite.name, opposite.card_count, "  KI" if bool(opposite.is_ai) else ""]
	var own_label: Label = $OwnHand/NameLabel
	if not self_entry.is_empty():
		own_label.text = "%s  (deine Hand, Karten 1-4)" % self_entry.name

func _clear_cards(node: Node) -> void:
	for child in node.get_children():
		if child.name == "NameLabel":
			continue
		child.queue_free()

func _paint_cards(node: Node2D, cards: Array, selectable: bool) -> void:
	var x := 0.0
	for i in range(cards.size()):
		var card = cards[i]
		var face := bool(card.get("face_up", false))
		var label := "?"
		if face:
			label = "%s\n%s" % [str(card.get("rank", "")), str(card.get("suit", ""))]
		var visual := _card_node(label, face)
		visual.position = Vector2(x, 0)
		if selectable:
			var index := int(card.get("index", i))
			visual.gui_input.connect(_select_card.bind(index))
			if index == _selected_hand:
				visual.modulate = Color(0.75, 1.0, 0.75)
		node.add_child(visual)
		x += 110.0

func _select_card(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_selected_hand = index
		_refresh()

func _card_node(text: String, face: bool) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(96, 132)
	panel.size = Vector2(96, 132)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.91, 0.84) if face else Color(0.12, 0.22, 0.18)
	style.border_color = Color(0.2, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1) if face else Color(0.75, 0.85, 0.75))
	panel.add_child(label)
	return panel
