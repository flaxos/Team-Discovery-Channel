shader_type spatial;

varying vec2 face_position;

void vertex() {
	face_position = VERTEX.xz;
}

void fragment() {
	vec2 point = face_position / 2.735;
	float radius = length(point);
	float sector = (atan(point.y, point.x + 0.00001) + 0.85 * (1.0 - radius)) * 1.90986;
	float phase = fract(sector);
	float joint = 1.0 - smoothstep(0.024, 0.052, min(phase, 1.0 - phase));
	joint *= smoothstep(0.045, 0.09, radius);
	float plate = 0.94 + 0.06 * cos(floor(sector) * 3.17);
	vec3 steel = mix(vec3(0.22, 0.29, 0.34), vec3(0.36, 0.44, 0.48), radius);
	ALBEDO = mix(steel * plate, vec3(0.057, 0.075, 0.086), joint);
	ROUGHNESS = 0.61;
	METALLIC = 0.18;
}
