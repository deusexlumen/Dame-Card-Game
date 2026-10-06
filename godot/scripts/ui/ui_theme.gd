extends RefCounted
class_name UiTheme

# Modern-Dark-Casino: fast schwarzer, warmer Grund, Gold als Akzent, Elfenbein-Text.
# Fliesstext Inter, Ueberschriften Playfair Display (beide OFL). DejaVu Sans als
# Ersatzschrift fuer Kartensymbole (♥♦♣♠), die Inter nicht enthaelt.

const INTER := "res://assets/fonts/Inter.ttf"
const PLAYFAIR := "res://assets/fonts/PlayfairDisplay.ttf"
const SYMBOLS := "res://assets/fonts/DejaVuSans.ttf"
const BG := Color(0.043, 0.039, 0.047)
const PANEL_BG := Color(0.075, 0.066, 0.078, 0.95)
const GOLD := Color(0.86, 0.7, 0.4)
const GOLD_DIM := Color(0.52, 0.42, 0.25)
const IVORY := Color(0.94, 0.91, 0.85)
const MUTED := Color(0.62, 0.58, 0.52)
const RED := Color(0.78, 0.2, 0.24)

static var _fonts := {}

static func _variation(path: String, weight: int) -> Font:
	var key := "%s@%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	var base: FontFile = load(path)
	var sym: FontFile = load(SYMBOLS)
	if base != null and sym != null and not base.fallbacks.has(sym):
		base.fallbacks = [sym]
	fv.base_font = base
	fv.variation_opentype = {"wght": weight}
	_fonts[key] = fv
	return fv


static func font() -> Font:
	return _variation(INTER, 450)


static func bold_font() -> Font:
	return _variation(INTER, 650)


static func heading_font() -> Font:
	return _variation(PLAYFAIR, 700)


static func dim(c: Color, amount: float = 0.45) -> Color:
	return Color(c.r * amount, c.g * amount, c.b * amount, 1.0)


static func box(bg: Color, border: Color, width: int = 1, radius: int = 8, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad * 1.4
	sb.content_margin_right = pad * 1.4
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.7
	sb.anti_aliasing = true
	return sb


static func build(_accent: Color = GOLD) -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 18
	var btn := Color(0.11, 0.095, 0.1)
	var btn_hover := Color(0.17, 0.14, 0.12)

	for type in ["Label", "RichTextLabel", "CheckBox", "CheckButton", "LinkButton"]:
		th.set_color("font_color", type, IVORY)
	th.set_color("default_color", "RichTextLabel", IVORY)
	th.set_font("bold_font", "RichTextLabel", bold_font())
	for type in ["CheckBox", "CheckButton"]:
		th.set_color("font_hover_color", type, GOLD)
		th.set_color("font_pressed_color", type, IVORY)
		th.set_color("font_focus_color", type, GOLD)

	# Knopf-Innenabstand so, dass jede Tippflaeche mindestens 44 px hoch ist (Touch).
	for type in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", type, box(btn, GOLD_DIM, 1, 8, 16))
		th.set_stylebox("hover", type, box(btn_hover, GOLD, 1, 8, 16))
		th.set_stylebox("pressed", type, box(GOLD, GOLD, 1, 8, 16))
		th.set_stylebox("focus", type, box(Color(0, 0, 0, 0), GOLD, 2, 8, 16))
		th.set_stylebox("disabled", type, box(Color(0.07, 0.065, 0.07), Color(0.22, 0.2, 0.18), 1, 8, 16))
		th.set_font("font", type, bold_font())
		th.set_color("font_color", type, IVORY)
		th.set_color("font_hover_color", type, GOLD)
		th.set_color("font_pressed_color", type, BG)
		th.set_color("font_focus_color", type, IVORY)
		th.set_color("font_disabled_color", type, Color(0.4, 0.38, 0.35))
		th.set_color("font_hover_pressed_color", type, BG)

	th.set_stylebox("panel", "Panel", box(PANEL_BG, GOLD_DIM, 1, 12))
	th.set_stylebox("panel", "PanelContainer", box(PANEL_BG, GOLD_DIM, 1, 12, 16))
	th.set_stylebox("panel", "PopupMenu", box(PANEL_BG, GOLD_DIM, 1, 8))
	th.set_stylebox("hover", "PopupMenu", box(btn_hover, btn_hover, 0, 6))
	th.set_color("font_color", "PopupMenu", IVORY)
	th.set_color("font_hover_color", "PopupMenu", GOLD)

	th.set_stylebox("normal", "LineEdit", box(btn, GOLD_DIM))
	th.set_stylebox("focus", "LineEdit", box(btn, GOLD, 2))
	th.set_color("font_color", "LineEdit", IVORY)
	th.set_color("caret_color", "LineEdit", GOLD)
	th.set_color("font_placeholder_color", "LineEdit", MUTED)
	th.set_color("selection_color", "LineEdit", GOLD_DIM)

	th.set_stylebox("slider", "HSlider", box(btn, GOLD_DIM, 1, 4, 2))
	th.set_stylebox("grabber_area", "HSlider", box(GOLD_DIM, GOLD_DIM, 0, 4, 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, GOLD, 0, 4, 2))

	th.set_stylebox("background", "ProgressBar", box(btn, GOLD_DIM, 1, 6, 0))
	th.set_stylebox("fill", "ProgressBar", box(GOLD, GOLD, 0, 6, 0))
	th.set_color("font_color", "ProgressBar", BG)

	th.set_stylebox("panel", "TabContainer", box(PANEL_BG, GOLD_DIM))
	th.set_stylebox("tab_selected", "TabContainer", box(GOLD, GOLD))
	th.set_stylebox("tab_unselected", "TabContainer", box(btn, GOLD_DIM))
	th.set_stylebox("tab_hovered", "TabContainer", box(btn_hover, GOLD))
	th.set_color("font_selected_color", "TabContainer", BG)
	th.set_color("font_unselected_color", "TabContainer", IVORY)
	th.set_color("font_hovered_color", "TabContainer", GOLD)

	th.set_stylebox("panel", "TooltipPanel", box(PANEL_BG, GOLD_DIM))
	th.set_color("font_color", "TooltipLabel", IVORY)

	th.set_stylebox("separator", "HSeparator", box(GOLD_DIM, GOLD_DIM, 0, 0, 0))
	th.set_constant("separation", "HSeparator", 14)
	return th
