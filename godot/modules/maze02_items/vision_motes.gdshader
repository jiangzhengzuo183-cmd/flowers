shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

varying float life;
varying float seed;
varying float breath;

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	float phase = fract(TIME * (0.76 + seed * 0.32) + seed);
	breath = 0.66 + 0.34 * sin(TIME * 2.45 - INSTANCE_CUSTOM.w * TAU);
	life = smoothstep(0.0, 0.19, phase) * (1.0 - smoothstep(0.66, 1.0, phase));
	vec3 at = MODELVIEW_MATRIX[3].xyz + MODELVIEW_MATRIX[2].xyz * (phase * INSTANCE_CUSTOM.z);
	at.y += sin(phase * PI) * (0.035 + breath * 0.055);
	vec2 along = MODELVIEW_MATRIX[2].xy;
	along = length(along) > 0.005 ? normalize(along) : vec2(1.0, 0.0);
	vec2 across = vec2(-along.y, along.x);
	float size = (0.046 + INSTANCE_CUSTOM.y * 0.067) * (0.69 + 0.31 * life);
	at.xy += (along * VERTEX.x * (1.02 + seed * 0.52) + across * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * vec4(at, 1.0);
}

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float core = 1.0 - smoothstep(0.09, 0.43, r);
	float aura = exp(-6.0 * r * r) * (1.0 - smoothstep(0.65, 1.0, r));
	ALBEDO = mix(vec3(0.07, 0.58, 1.0), vec3(0.76, 0.94, 1.0), core);
	ALPHA = (aura * 0.43 + core * 0.57) * life * (0.71 + 0.29 * seed) * (0.58 + breath * 0.42);
}
