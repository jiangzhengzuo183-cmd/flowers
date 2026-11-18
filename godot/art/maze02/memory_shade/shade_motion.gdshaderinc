uniform float effect_time = 0.0;
uniform float hair_motion = 0.0015;
uniform float hem_motion = 0.010;
uniform vec3 left_elbow = vec3(1000.0);
uniform vec3 left_hand = vec3(1000.0);
uniform vec3 left_tip = vec3(1000.0);
uniform vec3 right_elbow = vec3(1000.0);
uniform vec3 right_hand = vec3(1000.0);
uniform vec3 right_tip = vec3(1000.0);
uniform vec3 torso_center = vec3(0.0, 0.5, 0.0);

vec3 clear_arm(vec3 p, vec3 a, vec3 b, float radius) {
	vec3 axis = b - a;
	float t = clamp(dot(p - a, axis) / max(dot(axis, axis), 0.000001), 0.0, 1.0);
	vec3 nearest = a + axis * t;
	vec3 delta = p - nearest;
	if (dot(delta, delta) >= radius * radius) {
		return p;
	}
	vec3 escape = torso_center - nearest;
	escape.y = 0.0;
	escape = normalize(escape + vec3(0.00001, 0.0, 0.0));
	float along = dot(delta, escape);
	float distance = -along + sqrt(max(along * along + radius * radius - dot(delta, delta), 0.0));
	return p + escape * (distance + 0.003);
}

vec3 shade_offset(vec3 p, vec2 mask) {
	float hair_mask = max(mask.x, 0.0);
	float hair_wave = sin(effect_time * 1.05 + p.z * 15.0 + p.y * 5.0);
	float hem_wave = sin(effect_time * 0.95 + p.z * 8.0 + p.y * 4.0) * 0.72
		+ sin(effect_time * 1.37 - p.x * 12.0 + p.z * 6.0) * 0.28;
	vec3 shifted = p + vec3(hair_wave * hair_mask * hair_motion + hem_wave * mask.y * hem_motion,
		cos(effect_time * 0.9 + p.z * 10.0) * hair_mask * hair_motion * 0.4
			+ sin(effect_time * 1.1 + p.z * 9.0) * mask.y * hem_motion * 0.35,
		cos(effect_time * 0.83 + p.y * 8.0 + p.x * 9.0) * mask.y * hem_motion * 0.65);
	if (mask.x < -1.5) {
		for (int pass = 0; pass < 2; pass++) {
			shifted = clear_arm(shifted, left_elbow, left_hand, 0.038);
			shifted = clear_arm(shifted, left_hand, left_tip, 0.046);
			shifted = clear_arm(shifted, right_elbow, right_hand, 0.038);
			shifted = clear_arm(shifted, right_hand, right_tip, 0.046);
		}
	}
	return shifted - p;
}
