extends Control

# Effekte fuer besondere Momente ueber dem Tisch (Spec Visual Polish):
# Dame-Ruf (roter Puls + Banner), Spielerwechsel-Banner, Konfetti beim Sieg.
# Rein optisch, faengt keine Maus ab.

const UiThemeScript = preload("res://scripts/ui/ui_theme.gd")
const VignetteShader = preload("res://shaders/vignette.gdshader")

var animate := true
var _vignette: ColorRect
var _mat: ShaderMaterial
var _banner: Label
var _sub: Label
var _turn: Label
var _dame_on := false
var _pulse_t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = VignetteShader
	_vignette.material = _mat
	add_child(_vignette)
	_banner = _label(96, UiThemeScript.heading_font(), Color(0.95, 0.25, 0.25))
	_banner.position = Vector2(0, 250)
	_sub = _label(26, UiThemeScript.bold_font(), UiThemeScript.IVORY)
	_sub.position = Vector2(0, 370)
	_turn = _label(30, UiThemeScript.heading_font(), UiThemeScript.GOLD)
	_turn.position = Vector2(0, 150)


func _label(size: int, f: Font, c: Color) -> Label:
	var l := Label.new()
	l.size = Vector2(1280, size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	l.pivot_offset = l.size / 2.0
	add_child(l)
	return l


func _process(delta: float) -> void:
	# Waehrend der Dame-Runde pulsiert der Rand langsam weiter.
	if _dame_on:
		_pulse_t += delta
		_mat.set_shader_parameter("strength", 0.35 + 0.2 * sin(_pulse_t * 3.0))


func set_dame_active(on: bool) -> void:
	if on == _dame_on:
		return
	_dame_on = on
	if not on:
		_mat.set_shader_parameter("strength", 0.0)


# Grosser Moment: jemand ruft Dame.
func dame_called(name: String) -> void:
	set_dame_active(true)
	_banner.text = tr("DAME!")
	_sub.text = tr("%s ruft Dame – jeder hat noch einen Zug!") % name
	if not animate:
		return
	var flash := create_tween()
	flash.tween_method(func(v: float) -> void: _mat.set_shader_parameter("strength", v), 1.2, 0.4, 0.8)
	for l in [_banner, _sub]:
		l.modulate.a = 0.0
		l.scale = Vector2.ONE * 1.6
		var tw := create_tween().set_parallel(true)
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
		tw.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_interval(1.4)
		tw.chain().tween_property(l, "modulate:a", 0.0, 0.5)


# Weiche Ueberblendung beim Spielerwechsel.
func turn_banner(text: String) -> void:
	_turn.text = text
	if not animate:
		return
	_turn.modulate.a = 0.0
	_turn.position.y = 165
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_turn, "modulate:a", 1.0, 0.25)
	tw.tween_property(_turn, "position:y", 150.0, 0.25)
	tw.chain().tween_interval(0.8)
	tw.chain().tween_property(_turn, "modulate:a", 0.0, 0.4)


# Sieger-Feier: Konfetti in Gold, Rot und Elfenbein.
func confetti() -> void:
	if not animate:
		return
	for i in range(3):
		var p := CPUParticles2D.new()
		p.position = Vector2(320 + i * 320, -20)
		p.amount = 90
		p.lifetime = 3.2
		p.one_shot = true
		p.explosiveness = 0.85
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(300, 10)
		p.direction = Vector2(0, 1)
		p.spread = 35.0
		p.gravity = Vector2(0, 260)
		p.initial_velocity_min = 80.0
		p.initial_velocity_max = 260.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.scale_amount_min = 4.0
		p.scale_amount_max = 8.0
		var g := Gradient.new()
		g.colors = PackedColorArray([UiThemeScript.GOLD, Color(0.8, 0.15, 0.2), UiThemeScript.IVORY])
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		p.color_initial_ramp = g
		add_child(p)
		p.emitting = true
		get_tree().create_timer(4.0).timeout.connect(p.queue_free)
