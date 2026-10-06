extends Control
class_name CardView

# Eine Karte als gezeichnetes Control. Inhalt kommt nur aus der Sicht (DameView).
# Leeres Dictionary = leerer Platz. known=false oder face_visible=false = Rueckseite.

signal pressed(card_view: CardView)

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
var back_style := "raster"
var accent := Color(0.55, 1.0, 0.55)
var red_tint := Color(1.0, 0.62, 0.5)
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
	custom_minimum_size = Vector2(62, 88) if small else Vector2(92, 130)
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
		return "Verdeckte Karte"
	var rank := str(card.rank)
	var name := str(RANK_NAMES.get(rank, rank))
	return "%s %s (%d Punkte)" % [SUIT_NAMES.get(str(card.suit), ""), name, int(card.value)]


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
	var radius := 5 if small else 7
	var dim_c := UiTheme.dim(accent)
	if card.is_empty():
		_draw_round_rect(r, Color(0, 0, 0, 0), UiTheme.dim(accent, 0.25), 1, radius)
		return
	var border := accent if (selected or has_focus() or _hover) else dim_c
	var width := 3 if selected else (2 if has_focus() or _hover or targetable else 1)
	if targetable and not selected:
		border = accent.lightened(0.2)
	if shows_face():
		_draw_face(r, border, width, radius)
	else:
		_draw_back(r, border, width, radius)
	if selected:
		# Gewaehlte Karte: leicht getoent und mit Pfeil darueber.
		_draw_round_rect(r.grow(-3), Color(accent.r, accent.g, accent.b, 0.14), Color(0, 0, 0, 0), 0, radius)
		var tip := Vector2(r.get_center().x, r.position.y - 1)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-7, -9), tip + Vector2(7, -9)]), accent)
	if targetable:
		# Zielmarkierung: Ecken.
		var c := accent.lightened(0.3)
		var l := 10.0
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x == r.position.x else -1.0
			var sy := 1.0 if corner.y == r.position.y else -1.0
			draw_line(corner - Vector2(sx, sy) * 3, corner + Vector2(sx * l, -sy * 3), c, 2)
			draw_line(corner - Vector2(sx, sy) * 3, corner + Vector2(-sx * 3, sy * l), c, 2)


func _draw_round_rect(r: Rect2, fill: Color, border: Color, width: int, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _draw_face(r: Rect2, border: Color, width: int, radius: int) -> void:
	_draw_round_rect(r, Color(0.04, 0.08, 0.04), border, width, radius)
	var suit := str(card.suit)
	var rank := str(card.rank)
	var color := accent
	if suit == "hearts" or suit == "diamonds":
		color = accent.lerp(red_tint, 0.65)
	var f := UiTheme.bold_font()
	var corner_size := 15 if small else 20
	var label := str(RANK_LABELS.get(rank, rank))
	var sym := str(SUIT_SYMBOLS.get(suit, "?"))
	draw_string(f, r.position + Vector2(6, corner_size + 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, corner_size, color)
	draw_string(f, r.position + Vector2(6, corner_size * 2 + 4), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, corner_size - 2, color)
	var big := 34 if small else 50
	var center_text := sym
	if rank == "Q":
		center_text = "D"
	elif rank == "J" or rank == "K":
		center_text = label
	var w := f.get_string_size(center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	draw_string(f, r.get_center() + Vector2(-w / 2.0, big * 0.36), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, color)
	var pts := "%dP" % int(card.value)
	var ps := 11 if small else 14
	var pw := f.get_string_size(pts, HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x
	draw_string(UiTheme.font(), r.end - Vector2(pw + 6, 6), pts, HORIZONTAL_ALIGNMENT_LEFT, -1, ps, UiTheme.dim(color, 0.8))


func _draw_back(r: Rect2, border: Color, width: int, radius: int) -> void:
	_draw_round_rect(r, Color(0.03, 0.055, 0.03), border, width, radius)
	var inner := r.grow(-6 if small else -8)
	var line := UiTheme.dim(accent, 0.38)
	match back_style:
		"diagonal":
			var step := 8.0
			var x := inner.position.x - inner.size.y
			while x < inner.end.x:
				var a := Vector2(maxf(x, inner.position.x), inner.position.y + maxf(0.0, inner.position.x - x))
				var b_x := x + inner.size.y
				var b := Vector2(minf(b_x, inner.end.x), inner.end.y - maxf(0.0, b_x - inner.end.x))
				if a.x < b.x:
					draw_line(a, b, line, 1)
				x += step
		"punkte":
			var gap := 9.0
			var y := inner.position.y + gap / 2.0
			while y < inner.end.y:
				var xx := inner.position.x + gap / 2.0
				while xx < inner.end.x:
					draw_circle(Vector2(xx, y), 1.4, line)
					xx += gap
				y += gap
		"rauten":
			var s := 10.0
			var yy := inner.position.y
			var row := 0
			while yy < inner.end.y:
				var off := s / 2.0 if row % 2 == 1 else 0.0
				var xd := inner.position.x + off
				while xd < inner.end.x:
					var c := Vector2(xd, yy)
					draw_polyline(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0), c + Vector2(0, -4)]), line, 1)
					xd += s
				yy += s * 0.7
				row += 1
		"scanline":
			var ys := inner.position.y
			while ys < inner.end.y:
				draw_line(Vector2(inner.position.x, ys), Vector2(inner.end.x, ys), line, 1)
				ys += 3.0
		_:
			var g := 8.0
			var gx := inner.position.x
			while gx <= inner.end.x:
				draw_line(Vector2(gx, inner.position.y), Vector2(gx, inner.end.y), line, 1)
				gx += g
			var gy := inner.position.y
			while gy <= inner.end.y:
				draw_line(Vector2(inner.position.x, gy), Vector2(inner.end.x, gy), line, 1)
				gy += g
	_draw_round_rect(inner, Color(0, 0, 0, 0), UiTheme.dim(accent, 0.6), 1, 3)
	# Schriftzug in der Mitte (kein einzelnes "D", das waere mit der Dame verwechselbar).
	var f := UiTheme.bold_font()
	var es := 11 if small else 15
	var word := "DAME"
	var ew := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, es).x
	var center := r.get_center()
	var band := Rect2(center.x - ew / 2.0 - 5, center.y - es * 0.75, ew + 10, es * 1.5)
	_draw_round_rect(band, Color(0.03, 0.055, 0.03), UiTheme.dim(accent, 0.7), 1, 3)
	draw_string(f, Vector2(center.x - ew / 2.0, center.y + es * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, es, UiTheme.dim(accent, 0.85))
