extends Node3D

# Eine Spielkarte im Raum. Lokale Oberseite (+Y) ist das Gesicht, Kartenkopf zeigt nach -Z.
# Inhalt kommt nur aus der Sicht (DameView): leeres card oder known=false zeigt nie Rang/Farbe.

const CardArtScript = preload("res://scripts/ui/card_art.gd")
const MarkerShader = preload("res://shaders/card_marker.gdshader")

const W := 0.064
const H := 0.09
const T := 0.0016

static var _mat_cache := {}

var seat := -1
var index := -1
var kind := "hand"
var card: Dictionary = {}
var face_up := false
var accent := Color(0.86, 0.7, 0.4)
var face_skin := "klassisch"
var back_skin := "bordeaux"
var lang := "de"

var _flip: Node3D
var _face_mesh: MeshInstance3D
var _back_mesh: MeshInstance3D
var _marker: MeshInstance3D
var _marker_mat: ShaderMaterial
var _flip_tween: Tween
var _face_key := ""

func _init() -> void:
	_flip = Node3D.new()
	add_child(_flip)
	# Kern etwas kleiner als die Bildflaechen, damit die runden Ecken sauber bleiben.
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(W - 0.006, T, H - 0.006)
	body.mesh = box
	body.material_override = _plain("edge", Color(0.93, 0.92, 0.88))
	_flip.add_child(body)
	_face_mesh = MeshInstance3D.new()
	_face_mesh.mesh = _plane(W, H)
	_face_mesh.position.y = T / 2.0 + 0.0002
	_flip.add_child(_face_mesh)
	_back_mesh = MeshInstance3D.new()
	_back_mesh.mesh = _plane(W, H)
	_back_mesh.position.y = -T / 2.0 - 0.0002
	_back_mesh.rotation.z = PI
	_flip.add_child(_back_mesh)

	_marker = MeshInstance3D.new()
	_marker.mesh = _plane(W + 0.012, H + 0.012)
	_marker.position.y = -T / 2.0 - 0.0012
	_marker_mat = ShaderMaterial.new()
	_marker_mat.shader = MarkerShader
	_marker.material_override = _marker_mat
	_marker.visible = false
	add_child(_marker)
	_flip.rotation.z = PI


static func _plane(w: float, h: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(w, h)
	return p


static func _plain(key: String, color: Color) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	_mat_cache[key] = m
	return m


# Bildmaterial je Textur, geteilt zwischen allen Karten.
static func _tex_mat(tex: Texture2D) -> StandardMaterial3D:
	var key := "tex:" + (tex.resource_path if tex != null else "none")
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


func setup_style(p_face: String, p_back: String, p_lang: String = "de", p_accent: Color = Color(0.86, 0.7, 0.4)) -> void:
	face_skin = p_face
	back_skin = p_back
	lang = p_lang
	accent = p_accent
	_back_mesh.material_override = _tex_mat(CardArtScript.back(back_skin))
	_face_key = ""


func shows_face() -> bool:
	return face_up and not card.is_empty() and bool(card.get("known", false))


func set_card(data: Dictionary, show_face: bool, animate: bool, delay: float = 0.0) -> void:
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
	_flip_tween.tween_property(_flip, "rotation:z", target, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
	_flip_tween.tween_property(_flip, "position:y", 0.05, 0.16).set_ease(Tween.EASE_OUT).set_delay(delay)
	_flip_tween.tween_property(_flip, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN).set_delay(delay + 0.16)


func _fill_face() -> void:
	var key := "%s|%s|%s|%s" % [face_skin, lang, str(card.get("rank", "")), str(card.get("suit", ""))]
	if key == _face_key:
		return
	_face_key = key
	_face_mesh.material_override = _tex_mat(CardArtScript.face(card, face_skin, lang))


# mode: "" aus, "target" Ziel, "hover" unter Maus, "selected" gewaehlt.
func set_marker(mode: String) -> void:
	_marker.visible = mode != ""
	var a: float = {"selected": 1.0, "hover": 0.85, "target": 0.4}.get(mode, 0.0)
	_marker_mat.set_shader_parameter("color", Color(accent.r, accent.g, accent.b, a))
	_marker_mat.set_shader_parameter("width", 0.09 if mode == "selected" else 0.06)


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
