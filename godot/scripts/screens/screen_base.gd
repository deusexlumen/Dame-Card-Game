extends Control
class_name ScreenBase

# Gemeinsamer Rahmen fuer Menue-Bildschirme: Hintergrund, Titel, Zurueck mit Esc.

var content: VBoxContainer
var back_button: Button
var _title: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var app := app_node()
	bg.color = UiTheme.BG
	add_child(bg)
	_build_backdrop(app)
	build()
	print("SCREEN_READY ", name)


# Langsam kreisender 3D-Tisch hinter jedem Menue, abgedunkelt fuer Lesbarkeit.
func _build_backdrop(app) -> void:
	# Headless (Tests) ohne 3D: spart Zeit, zeigt ohnehin nichts.
	if DisplayServer.get_name() == "headless":
		return
	var box := SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(vp)
	var table = load("res://scripts/table3d/table_3d.gd").new()
	vp.add_child(table)
	var cos := {"showcase": true}
	if app != null:
		cos.merge({"accent": app.accent(), "back": app.back_skin(), "face": app.face_skin(), "felt": app.table_color(), "lang": app.language()}, true)
	table.build(cos)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.016, 0.02, 0.62)
	add_child(shade)


func app_node() -> Node:
	return get_node_or_null("/root/App")


# Baut Titel und eine zentrierte Spalte. Unterklassen fuellen content.
func frame(title: String, width: float = 760.0, with_back: bool = true) -> void:
	_title = Label.new()
	_title.text = title
	_title.position = Vector2(0, 26)
	_title.size = Vector2(1280, 50)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_font_override("font", UiTheme.heading_font())
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2((1280 - width) / 2.0, 92)
	scroll.size = Vector2(width, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	if with_back:
		back_button = Button.new()
		back_button.text = "Zurück [Esc]"
		back_button.position = Vector2(24, 664)
		back_button.pressed.connect(go_back)
		add_child(back_button)


func build() -> void:
	pass


func go_back() -> void:
	var app := app_node()
	if app != null:
		app.click()
		app.goto(app.MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and back_button != null:
		go_back()
		accept_event()


func label(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	return l


func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		var app := app_node()
		if app != null:
			app.click()
		cb.call())
	return b


func row(label_text: String, control: Control, label_width: float = 300.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := label(label_text, 17)
	l.custom_minimum_size = Vector2(label_width, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h


func option(items: Array, selected_index: int) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected_index, 0, maxi(items.size() - 1, 0)))
	return o
