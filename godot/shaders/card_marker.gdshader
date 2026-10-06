shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Leuchtender Rahmen um eine Karte (Ziel, Maus, Auswahl). Innen durchsichtig.
uniform vec4 color : source_color = vec4(0.86, 0.7, 0.4, 0.5);
uniform float width = 0.06;

void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float edge = min(d.x * 1.4, d.y);
	float band = 1.0 - smoothstep(width * 0.6, width, edge);
	ALBEDO = color.rgb;
	ALPHA = color.a * band;
}
