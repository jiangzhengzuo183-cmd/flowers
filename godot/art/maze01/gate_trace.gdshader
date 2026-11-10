shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float floor_height = 0.0;
varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

float groove(float offset, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(offset));
}

void fragment() {
	if (world_y < floor_height) {
		discard;
	}
	vec2 p = UV - 0.5;
	vec2 aa = max(fwidth(p), vec2(0.001));
	float within = 1.0 - smoothstep(0.41, 0.44, abs(p.y));
	float rebate = groove(abs(p.x) - 0.356, 0.002, aa.x) * within;
	float head = groove(abs(p.y) - 0.405, 0.002, aa.y) * (1.0 - smoothstep(0.35, 0.36, abs(p.x)));
	float spread = 1.0 - smoothstep(charge * 0.40 - 0.03, charge * 0.40 + 0.045, abs(p.x));
	float light = max(rebate, head) * spread * charge * 0.63;
	float cut = max(rebate, head) * 0.23;
	ALBEDO = mix(vec3(0.19, 0.42, 0.43), vec3(0.85, 0.99, 0.96), light);
	ALPHA = max(cut, light);
}
