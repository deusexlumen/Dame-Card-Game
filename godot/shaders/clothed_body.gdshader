shader_type spatial;

// Koerper mit aufgemalter Kleidung. Maske: R = Oberteil, G = Hose, B = Schuhe.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap;
uniform vec3 top_color : source_color = vec3(0.4, 0.1, 0.12);
uniform vec3 bottom_color : source_color = vec3(0.12, 0.12, 0.14);
uniform vec3 shoe_color : source_color = vec3(0.08, 0.05, 0.04);
// 0 = Strick, 1 = glatter Stoff (Hemd/Bluse)
uniform float top_knit = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 m = texture(mask_tex, UV).rgb;
	vec3 skin = texture(albedo_tex, UV).rgb;
	// Feines Strickmuster und Stoffkoernung, damit Flaechen nicht wie Plastik wirken.
	float rib = mix(1.0, 0.9 + 0.1 * sin(UV.x * 1400.0), top_knit);
	float grain = mix(0.94, 1.0, hash(floor(UV * 900.0)));
	vec3 col = skin;
	col = mix(col, top_color * rib * grain, m.r);
	col = mix(col, bottom_color * grain, m.g);
	col = mix(col, shoe_color, m.b);
	ALBEDO = col;
	float cloth = clamp(m.r + m.g + m.b, 0.0, 1.0);
	// Muskeln verschwinden unter dem Stoff: Normalmap dort fast flach.
	NORMAL_MAP = mix(texture(normal_tex, UV).rgb, vec3(0.5, 0.5, 1.0), cloth * 0.85);
	float r = mix(texture(rough_tex, UV).r, 0.95, cloth);
	ROUGHNESS = mix(r, 0.4, m.b);
	SPECULAR = mix(0.5, 0.2, cloth);
}
