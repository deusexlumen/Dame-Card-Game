extends PanelContainer
class_name SeatView

# Ein Platz am Tisch: Name, Punkte, Status, Handkarten. Zeigt nur Sicht-Daten.

signal card_pressed(seat: int, index: int)

const CardViewScript = preload("res://scripts/ui/card_view.gd")

var seat := -1
var small := true
var accent := Color(0.55, 1.0, 0.55)
var back_style := "raster"
var _title: Label
var _info: Label
var _cards_box: HBoxContainer
var _cards: Array = []
var _last: Array = []
var animate := true
# Im 3D-Tisch: unsichtbar, nur noch fuer Tastaturfokus und Tests.
var ghost := false

func setup(p_seat: int, p_small: bool) -> void:
	seat = p_seat
	small = p_small
	mouse_filter = Control.MOUSE_FILTER_PASS
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16 if small else 18)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 13 if small else 15)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_info)
	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 6 if small else 10)
	vb.add_child(_cards_box)


func cards() -> Array:
	return _cards


func card_at(i: int):
	return _cards[i] if i >= 0 and i < _cards.size() else null


# data: Spielereintrag aus DameView. face_for: Callable(seat, index, card) -> bool.
func update(data: Dictionary, face_for: Callable, targets: Array, selected_index: int) -> void:
	var marker := "▶ " if bool(data.is_current) else ""
	var tags: Array = []
	if bool(data.is_ai):
		tags.append("KI " + {"easy": "Einfach", "medium": "Mittel", "hard": "Schwer"}.get(str(data.difficulty), ""))
	if bool(data.locked):
		tags.append("DAME!")
	if bool(data.eliminated):
		tags.append("ausgeschieden")
	_title.text = marker + str(data.name) + ("  [" + ", ".join(PackedStringArray(tags)) + "]" if not tags.is_empty() else "")
	var info := "Gesamt %d" % int(data.total_score)
	if int(data.penalty_count) > 0:
		info += "  ·  Strafe +%d" % int(data.penalty_count)
	_info.text = info
	modulate = Color(1, 1, 1, 0.45) if bool(data.eliminated) else Color.WHITE
	if ghost:
		modulate = Color(1, 1, 1, 0)
	var list: Array = data.cards
	while _cards.size() < list.size():
		var cv: CardView = CardViewScript.new()
		cv.setup(small)
		cv.seat = seat
		cv.index = _cards.size()
		cv.pressed.connect(func(v: CardView) -> void: card_pressed.emit(v.seat, v.index))
		_cards_box.add_child(cv)
		_cards.append(cv)
	while _cards.size() > list.size():
		var gone: CardView = _cards.pop_back()
		_cards_box.remove_child(gone)
		gone.queue_free()
	var next_last: Array = []
	for i in range(list.size()):
		var cv: CardView = _cards[i]
		cv.accent = accent
		cv.back_style = back_style
		cv.targetable = targets.has(i)
		cv.selected = i == selected_index
		var face: bool = face_for.call(seat, i, list[i])
		var sig := var_to_str(list[i]) + str(face)
		# Geaenderte Karte kurz hervorheben (nicht beim ersten Aufbau).
		if animate and i < _last.size() and _last[i] != sig:
			cv.pop()
		next_last.append(sig)
		cv.set_card(list[i], face)
		cv.queue_redraw()
	_last = next_last


func clear_faces() -> void:
	for cv in _cards:
		cv.set_card(cv.card, false)
