shader_type spatial;

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform bool floor_plate = false;
varying vec3 local_point;

float mark(float coordinate, float center, float width) {
	return 1.0 - smoothstep(width, width + 0.009, abs(coordinate - center));
}

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	float theta = atan(local_point.z, local_point.x) / TAU + 0.5;
	float radius = length(local_point.xz);
	float panel = fract(theta * 12.0);
	float brass = smoothstep(0.030, 0.055, abs(local_point.y));
	float seam = 1.0 - mark(panel, 0.5, 0.46);
	float line = mark(abs(local_point.y), 0.046, 0.006);
	float px = fract(theta * 48.0);
	float code = floor(theta * 48.0);
	float py = local_point.y + 0.052;
	if (floor_plate) {
		brass = smoothstep(1.78, 1.92, radius);
		line = max(mark(radius, 2.21, 0.018), mark(radius, 1.91, 0.012));
		py = 2.105 - radius;
	}
	float glyph = mark(py, 0.033, 0.035) * (
		mark(px, 0.23, 0.045) + mark(px, 0.68, 0.035) * step(1.0, mod(code, 3.0))
	);
	glyph = max(glyph, mark(px, 0.46, 0.26) * mark(py, 0.020 + mod(code, 3.0) * 0.024, 0.005));
	float working = max(line * (1.0 - seam), glyph);
	vec3 bronze = vec3(0.27, 0.15, 0.065);
	vec3 gunmetal = vec3(0.108, 0.101, 0.094);
	float grain = 0.98 + 0.025 * sin(radius * 920.0 + 1.7 * sin(theta * 149.0));
	float panel_finish = 0.90 + 0.15 * sin(floor(theta * 12.0) * 2.7);
	ALBEDO = mix(gunmetal, bronze, brass * 0.82) * grain * panel_finish;
	ALBEDO *= 1.0 - 0.75 * seam;
	ALBEDO = mix(ALBEDO, vec3(0.41, 0.26, 0.11), working * 0.62);
	METALLIC = 0.64;
	ROUGHNESS = mix(0.46, 0.29, brass);
	float power = charge * charge;
	float chase = 0.67 + 0.33 * sin(theta * TAU * 3.0 - TIME * 7.0);
	EMISSION = vec3(1.0, 0.45, 0.10) * working * power * chase * 3.6;
}
