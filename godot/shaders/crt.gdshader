shader_type canvas_item;

// Leichter Bildroehren-Look: Zeilen und dunkle Raender. Laeuft auf GL Compatibility.
uniform float line_strength : hint_range(0.0, 0.5) = 0.10;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	vec2 uv = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.35, 0.85, length(uv * vec2(1.0, 1.25)));
	COLOR = vec4(0.0, 0.0, 0.0, line * line_strength + edge * vignette);
}
