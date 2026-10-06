shader_type canvas_item;

// Farbiger Rand fuer Ereignisse (Dame-Ruf). Mitte bleibt frei.
uniform vec4 tint : source_color = vec4(0.85, 0.08, 0.1, 1.0);
uniform float strength = 0.0;

void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float edge = max(d.x * 0.92, d.y);
	float a = smoothstep(0.55, 1.0, edge) * strength;
	COLOR = vec4(tint.rgb, a * tint.a);
}
