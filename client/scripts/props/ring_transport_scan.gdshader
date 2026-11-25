shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float frontier = 0.0;
uniform float floor_level = 0.0;
varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - floor_level;
}

void fragment() {
	float noise = 0.055 * sin(FRAGCOORD.x * 1.7 + FRAGCOORD.y * 2.3);
	float band = exp(-abs(height - frontier + noise) * 16.0);
	float fine_lines = 0.72 + 0.28 * sin(height * 169.0 - TIME * 18.0);
	ALBEDO = vec3(2.0, 0.97, 0.23);
	ALPHA = band * fine_lines * 0.88;
}
