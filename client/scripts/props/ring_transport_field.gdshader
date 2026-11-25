shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float sweep = 0.0;
uniform bool receiving = false;
varying vec3 local_point;

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	float angle = atan(local_point.z, local_point.x) * 0.1591549;
	float y = (local_point.y + 1.45) / 2.9;
	float beamlet = pow(max(0.0, sin(angle * TAU * 23.0 + 0.7 * sin(y * 20.0))), 14.0);
	float grain = 0.7 + 0.3 * sin(y * 112.0 + angle * 65.0 - TIME * 14.0);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float front = receiving ? 1.0 - sweep : sweep;
	float traveling = exp(-abs(y - front) * 40.0);
	float edge_fade = smoothstep(0.0, 0.09, y) * smoothstep(0.0, 0.09, 1.0 - y);
	vec3 amber = vec3(1.0, 0.38, 0.055);
	vec3 white_gold = vec3(1.0, 0.82, 0.49);
	ALBEDO = mix(amber, white_gold, traveling);
	ALPHA = (0.035 * rim + 0.095 * beamlet * grain + 0.43 * traveling) * strength * edge_fade;
}
