extends RefCounted
class_name UiTheme

# Phosphor-Theme: schwarzer Grund, eine Akzentfarbe, Monospace-Schrift.
# Wird im Code gebaut, damit die Akzentfarbe (Kosmetik) wechseln kann.

const FONT_PATH := "res://assets/fonts/DejaVuSansMono.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/DejaVuSansMono-Bold.ttf"
const BG := Color(0.02, 0.035, 0.02)
const PANEL_BG := Color(0.035, 0.07, 0.035, 0.96)

static func font() -> Font:
	return load(FONT_PATH)


static func bold_font() -> Font:
	return load(FONT_BOLD_PATH)


static func dim(accent: Color, amount: float = 0.45) -> Color:
	return Color(accent.r * amount, accent.g * amount, accent.b * amount, 1.0)


static func box(bg: Color, border: Color, width: int = 1, radius: int = 4, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	sb.anti_aliasing = true
	return sb


static func build(accent: Color) -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 18
	var dim_c := dim(accent)
	var faint := dim(accent, 0.22)
	var dark := Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 1.0)

	for type in ["Label", "RichTextLabel", "CheckBox", "CheckButton", "LinkButton"]:
		th.set_color("font_color", type, accent)
	th.set_color("default_color", "RichTextLabel", accent)
	th.set_color("font_hover_color", "CheckBox", accent.lightened(0.3))
	th.set_color("font_hover_color", "CheckButton", accent.lightened(0.3))
	th.set_color("font_pressed_color", "CheckBox", accent)
	th.set_color("font_pressed_color", "CheckButton", accent)
	th.set_color("font_focus_color", "CheckBox", accent.lightened(0.3))
	th.set_color("font_focus_color", "CheckButton", accent.lightened(0.3))
	th.set_font("bold_font", "RichTextLabel", bold_font())

	for type in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", type, box(dark, dim_c))
		th.set_stylebox("hover", type, box(Color(dark, 1.0).lightened(0.06), accent))
		th.set_stylebox("pressed", type, box(dim_c, accent, 2))
		th.set_stylebox("focus", type, box(Color(0, 0, 0, 0), accent.lightened(0.25), 2))
		th.set_stylebox("disabled", type, box(BG, faint))
		th.set_color("font_color", type, accent)
		th.set_color("font_hover_color", type, accent.lightened(0.35))
		th.set_color("font_pressed_color", type, BG)
		th.set_color("font_focus_color", type, accent.lightened(0.25))
		th.set_color("font_disabled_color", type, faint)
		th.set_color("font_hover_pressed_color", type, BG)

	th.set_stylebox("panel", "Panel", box(PANEL_BG, dim_c, 1, 6))
	th.set_stylebox("panel", "PanelContainer", box(PANEL_BG, dim_c, 1, 6, 14))
	th.set_stylebox("panel", "PopupMenu", box(PANEL_BG, accent, 1, 4))
	th.set_stylebox("hover", "PopupMenu", box(dim_c, dim_c, 0, 2))
	th.set_color("font_color", "PopupMenu", accent)
	th.set_color("font_hover_color", "PopupMenu", BG)

	th.set_stylebox("normal", "LineEdit", box(dark, dim_c))
	th.set_stylebox("focus", "LineEdit", box(dark, accent, 2))
	th.set_color("font_color", "LineEdit", accent)
	th.set_color("caret_color", "LineEdit", accent)
	th.set_color("font_placeholder_color", "LineEdit", faint)
	th.set_color("selection_color", "LineEdit", dim_c)

	th.set_stylebox("slider", "HSlider", box(dark, dim_c, 1, 2, 2))
	th.set_stylebox("grabber_area", "HSlider", box(dim_c, dim_c, 0, 2, 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(accent, accent, 0, 2, 2))

	th.set_stylebox("background", "ProgressBar", box(dark, dim_c, 1, 2, 0))
	th.set_stylebox("fill", "ProgressBar", box(accent, accent, 0, 2, 0))
	th.set_color("font_color", "ProgressBar", BG)

	th.set_stylebox("panel", "TabContainer", box(PANEL_BG, dim_c))
	th.set_stylebox("tab_selected", "TabContainer", box(dim_c, accent))
	th.set_stylebox("tab_unselected", "TabContainer", box(dark, faint))
	th.set_stylebox("tab_hovered", "TabContainer", box(dark, accent))
	th.set_color("font_selected_color", "TabContainer", BG)
	th.set_color("font_unselected_color", "TabContainer", accent)
	th.set_color("font_hovered_color", "TabContainer", accent.lightened(0.3))

	th.set_stylebox("panel", "TooltipPanel", box(PANEL_BG, accent))
	th.set_color("font_color", "TooltipLabel", accent)

	th.set_stylebox("separator", "HSeparator", box(faint, faint, 0, 0, 0))
	th.set_constant("separation", "HSeparator", 12)
	return th
