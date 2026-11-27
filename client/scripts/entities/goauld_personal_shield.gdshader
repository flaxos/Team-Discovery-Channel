shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec4 shield_color : source_color = vec4(1.0, 0.72, 0.22, 1.0);
uniform float idle_alpha = 0.20;
uniform float impact_flash = 0.0;
uniform float energy_ratio = 1.0;
uniform float overload_flash = 0.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	float shimmer = 0.92 + 0.08 * sin(TIME * 4.5 + VERTEX.y * 8.0);
	float ratio = clamp(energy_ratio, 0.15, 1.0);
	vec3 base_col = shield_color.rgb * (0.75 + 0.45 * ratio);
	vec3 flare_col = vec3(1.0, 0.95, 0.78) * impact_flash * 1.6;
	vec3 discharge_col = vec3(0.30, 0.85, 1.0) * overload_flash * 1.8;
	ALBEDO = base_col + flare_col + discharge_col;
	float alpha = (idle_alpha * ratio + fresnel * (0.38 + 0.45 * impact_flash)) * shimmer;
	alpha += impact_flash * 0.42 + overload_flash * 0.55;
	ALPHA = clamp(alpha, 0.0, 0.95);
}
