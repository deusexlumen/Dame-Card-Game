extends Node3D

# Eine Spielkarte im Raum. Lokale Oberseite (+Y) ist das Gesicht, Kartenkopf zeigt nach -Z.
# Inhalt kommt nur aus der Sicht (DameView): leeres card oder known=false zeigt nie Rang/Farbe.

const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")

const W := 0.064
const H := 0.09
const T := 0.0016
const RANK_LABELS := {"J": "B", "Q": "D", "K": "K", "A": "A"}
const SUIT_SYMBOLS := {"hearts": "♥", "diamonds": "♦", "clubs": "♣", "spades": "♠"}
const RED := Color(0.72, 0.08, 0.1)
const BLACK := Color(0.07, 0.07, 0.08)

static var _mat_cache := {}
static var _back_cache := {}

var seat := -1
var index := -1
var kind := "hand"
var card: Dictionary = {}
var face_up := false
var accent := Color(0.55, 1.0, 0.55)
var back_style := "raster"

var _flip: Node3D
var _face_root: Node3D
var _back_mesh: MeshInstance3D
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _rank: Label3D
var _corner_suit: Label3D
var _center: Label3D
var _points: Label3D
var _rank2: Label3D
var _flip_tween: Tween

func _init() -> void:
	_flip = Node3D.new()
	add_child(_flip)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(W, T, H)
	body.mesh = box
	body.material_override = _mat("edge", Color(0.93, 0.92, 0.88), 0.7)
	_flip.add_child(body)

	var face := MeshInstance3D.new()
	face.mesh = _plane(W - 0.001, H - 0.001)
	face.position.y = T / 2.0 + 0.0002
	face.material_override = _mat("face", Color(0.96, 0.94, 0.88), 0.75)
	_flip.add_child(face)
	_face_root = Node3D.new()
	_face_root.position.y = T / 2.0 + 0.0004
	_flip.add_child(_face_root)
	_rank = _label(46, Vector3(-W / 2.0 + 0.009, 0, -H / 2.0 + 0.011))
	_corner_suit = _label(36, Vector3(-W / 2.0 + 0.009, 0, -H / 2.0 + 0.026))
	_center = _label(118, Vector3(0, 0, 0.002))
	_points = _label(26, Vector3(W / 2.0 - 0.011, 0, H / 2.0 - 0.008))
	# Rang unten rechts, auf dem Kopf wie bei echten Karten.
	_rank2 = _label(46, Vector3(W / 2.0 - 0.009, 0, H / 2.0 - 0.022))
	_rank2.rotate_y(PI)

	_back_mesh = MeshInstance3D.new()
	_back_mesh.mesh = _plane(W - 0.001, H - 0.001)
	_back_mesh.position.y = -T / 2.0 - 0.0002
	_back_mesh.rotation.z = PI
	_flip.add_child(_back_mesh)

	_marker = MeshInstance3D.new()
	_marker.mesh = _plane(W + 0.012, H + 0.012)
	_marker.position.y = -T / 2.0 - 0.0012
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker.material_override = _marker_mat
	_marker.visible = false
	add_child(_marker)
	_flip.rotation.z = PI


func _label(size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font = UiThemeScript.bold_font()
	l.font_size = size
	l.pixel_size = 0.0004
	l.outline_size = 0
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.position = pos
	# Liegt flach auf der Kartenflaeche, Schriftkopf Richtung Kartenkopf (-Z).
	l.rotation.x = -PI / 2.0
	_face_root.add_child(l)
	return l


static func _plane(w: float, h: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(w, h)
	return p


static func _mat(key: String, color: Color, rough: float) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	_mat_cache[key] = m
	return m


func setup_style(p_accent: Color, p_back: String) -> void:
	accent = p_accent
	back_style = p_back
	_back_mesh.material_override = _back_material(accent, back_style)


# Rueckseite: dunkler Grund mit Muster in der Akzentfarbe, einmal pro Stil erzeugt.
static func _back_material(acc: Color, style: String) -> StandardMaterial3D:
	var key := "%s|%s" % [acc.to_html(false), style]
	if _back_cache.has(key):
		return _back_cache[key]
	var w := 128
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Color(0.06, 0.09, 0.07)
	var line := Color(acc.r * 0.55, acc.g * 0.55, acc.b * 0.55)
	var frame := Color(acc.r * 0.8, acc.g * 0.8, acc.b * 0.8)
	img.fill(Color(0.9, 0.89, 0.85))
	img.fill_rect(Rect2i(6, 6, w - 12, h - 12), bg)
	for y in range(12, h - 12):
		for x in range(12, w - 12):
			var on := false
			match style:
				"diagonal":
					on = (x + y) % 9 == 0
				"punkte":
					on = (x % 9 - 4) * (x % 9 - 4) + (y % 9 - 4) * (y % 9 - 4) <= 2
				"rauten":
					on = (x + y) % 10 == 0 or (x - y + 1000) % 10 == 0
				"scanline":
					on = y % 3 == 0
				_:
					on = x % 8 == 4 or y % 8 == 4
			if on:
				img.set_pixel(x, y, line)
	for i in range(2):
		var r := Rect2i(10 + i, 10 + i, w - 20 - i * 2, h - 20 - i * 2)
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, r.position.y, frame)
			img.set_pixel(x, r.end.y - 1, frame)
		for y in range(r.position.y, r.end.y):
			img.set_pixel(r.position.x, y, frame)
			img.set_pixel(r.end.x - 1, y, frame)
	# Mittelband fuer den Schriftzug.
	img.fill_rect(Rect2i(26, 78, w - 52, 24), bg)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_back_cache[key] = m
	return m


func shows_face() -> bool:
	return face_up and not card.is_empty() and bool(card.get("known", false))


func set_card(data: Dictionary, show_face: bool, animate: bool) -> void:
	card = data
	visible = not data.is_empty()
	var want := show_face and bool(data.get("known", false))
	if want:
		_fill_face()
	if want == face_up:
		return
	face_up = want
	var target := 0.0 if face_up else PI
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	if not animate or not is_inside_tree():
		_flip.rotation.z = target
		_flip.position.y = 0.0
		return
	# Umdrehen mit kurzem Anheben, damit die Karte nicht durch den Tisch dreht.
	_flip_tween = create_tween().set_parallel(true)
	_flip_tween.tween_property(_flip, "rotation:z", target, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_property(_flip, "position:y", 0.05, 0.16).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(_flip, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN).set_delay(0.16)


func _fill_face() -> void:
	var suit := str(card.get("suit", ""))
	var rank := str(card.get("rank", ""))
	var color := RED if suit == "hearts" or suit == "diamonds" else BLACK
	var label := str(RANK_LABELS.get(rank, rank))
	var sym := str(SUIT_SYMBOLS.get(suit, "?"))
	_rank.text = label
	_rank2.text = label
	_corner_suit.text = sym
	var center := sym
	if rank == "Q":
		center = "D"
	elif rank == "J" or rank == "K":
		center = label
	_center.text = center
	_points.text = "%dP" % int(card.get("value", 0))
	for l in [_rank, _rank2, _corner_suit, _center]:
		l.modulate = color
	_points.modulate = Color(color.r, color.g, color.b, 0.75)


# mode: "" aus, "target" Ziel, "hover" unter Maus, "selected" gewaehlt.
func set_marker(mode: String) -> void:
	_marker.visible = mode != ""
	match mode:
		"selected":
			_marker_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.95)
		"hover":
			_marker_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.75)
		"target":
			_marker_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.32)


# Abstand entlang des Strahls bis zur Karte, -1 wenn verfehlt.
func hit(origin: Vector3, dir: Vector3) -> float:
	if not visible or not is_visible_in_tree():
		return -1.0
	var inv := global_transform.affine_inverse()
	var o: Vector3 = inv * origin
	var d: Vector3 = inv.basis * dir
	if absf(d.y) < 0.00001:
		return -1.0
	var t := -o.y / d.y
	if t < 0.0:
		return -1.0
	var p := o + d * t
	if absf(p.x) <= W / 2.0 + 0.006 and absf(p.z) <= H / 2.0 + 0.006:
		return (global_transform * p).distance_to(origin)
	return -1.0
