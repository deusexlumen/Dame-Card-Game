extends Control
class_name CardView

# Eine Karte als gezeichnetes Control. Inhalt kommt nur aus der Sicht (DameView).
# Leeres Dictionary = leerer Platz. known=false oder face_visible=false = Rueckseite.

signal pressed(card_view: CardView)

const CardArtScript = preload("res://scripts/ui/card_art.gd")

const SUIT_SYMBOLS := {"hearts": "♥", "diamonds": "♦", "clubs": "♣", "spades": "♠"}
const SUIT_NAMES := {"hearts": "Herz", "diamonds": "Karo", "clubs": "Kreuz", "spades": "Pik"}
# Deutsche Kartenbuchstaben: Bube, Dame, Koenig, Ass.
const RANK_LABELS := {"J": "B", "Q": "D", "K": "K", "A": "A"}
const RANK_NAMES := {"J": "Bube", "Q": "Dame", "K": "König", "A": "Ass"}

var card: Dictionary = {}
var face_visible := false
var selected := false
var targetable := false
var small := false
var back_style := "bordeaux"
var face_skin := "klassisch"
var lang := "de"
var accent := Color(0.86, 0.7, 0.4)
var seat := -1
var index := -1
var _hover := false

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func setup(p_small: bool) -> void:
	small = p_small
	custom_minimum_size = Vector2(64, 90) if small else Vector2(92, 129)
	size = custom_minimum_size


func set_card(data, visible_face: bool) -> void:
	var next: Dictionary = data if data is Dictionary else {}
	var changed := var_to_str(next) != var_to_str(card) or visible_face != face_visible
	card = next
	face_visible = visible_face
	tooltip_text = describe()
	if changed:
		queue_redraw()


func is_empty_slot() -> bool:
	return card.is_empty()


func shows_face() -> bool:
	return face_visible and not card.is_empty() and bool(card.get("known", false))


# Text fuer Tooltip und Barrierefreiheit. Unbekannte Karte nennt nie Rang oder Farbe.
func describe() -> String:
	if card.is_empty():
		return ""
	if not shows_face():
		return tr("Verdeckte Karte")
	var rank := str(card.rank)
	var name := str(RANK_NAMES.get(rank, rank))
	return tr("%s %s (%d Punkte)") % [tr(SUIT_NAMES.get(str(card.suit), "")), tr(name), int(card.value)]


func pop() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.09)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14)


func flash() -> void:
	modulate = Color(1.6, 1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.45)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit(self)
			accept_event()
	elif event.is_action_pressed("ui_accept"):
		pressed.emit(self)
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var radius := 6 if small else 9
	if card.is_empty():
		_draw_round_rect(r, Color(0, 0, 0, 0.18), Color(accent.r, accent.g, accent.b, 0.25), 1, radius)
		return
	var tex: Texture2D = CardArtScript.face(card, face_skin, lang) if shows_face() else CardArtScript.back(back_style)
	if tex != null:
		draw_texture_rect(tex, r, false)
	if selected or has_focus() or _hover or targetable:
		var width := 3 if selected else 2
		var a := 1.0 if (selected or has_focus() or _hover) else 0.55
		_draw_round_rect(r.grow(1), Color(0, 0, 0, 0), Color(accent.r, accent.g, accent.b, a), width, radius)
	if selected:
		var tip := Vector2(r.get_center().x, r.position.y - 2)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -9), tip + Vector2(7, -9)]), accent)


func _draw_round_rect(r: Rect2, fill: Color, border: Color, width: int, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	draw_style_box(sb, r)
