shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.06, 0.35, 0.85, 0.95);
uniform vec4 ripple_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float speed : hint_range(0.1, 5.0) = 1.2;
uniform float frequency : hint_range(1.0, 30.0) = 8.0;
uniform float amplitude : hint_range(0.01, 0.2) = 0.04;
uniform float emission_energy : hint_range(0.5, 5.0) = 2.0;

void vertex() {
	// Circular water ripple outward from center
	vec2 center_uv = UV - vec2(0.5);
	float dist = length(center_uv);
	float wave = sin(dist * frequency - TIME * speed) * amplitude;
	VERTEX += NORMAL * wave;
}

void fragment() {
	vec2 center_uv = UV - vec2(0.5);
	float dist = length(center_uv);
	float ripple = sin(dist * frequency * 1.5 - TIME * speed * 1.2) * 0.5 + 0.5;

	// Circular rim fresnel
	float edge_factor = smoothstep(0.48, 0.5, dist);
	vec4 col = mix(deep_color, ripple_color, ripple * 0.5);
	col = mix(col, ripple_color, edge_factor);

	ALBEDO = col.rgb;
	ALPHA = col.a;
	EMISSION = col.rgb * emission_energy * (0.8 + ripple * 0.4);
	ROUGHNESS = 0.1;
	METALLIC = 0.2;
}
