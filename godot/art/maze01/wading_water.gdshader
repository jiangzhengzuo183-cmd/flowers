shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec4 pool_tint : source_color = vec4(0.28, 0.64, 0.59, 1.0);
uniform vec4 shoal_tint : source_color = vec4(0.50, 0.80, 0.77, 1.0);
uniform vec4 step_ripples[4];
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float depth = smoothstep(0.0, 0.88, UV.x);
	vec2 p = world_xz;
	float wave_a = dot(p, vec2(5.1, 2.7)) + TIME * 1.10;
	float wave_b = dot(p, vec2(-3.0, 6.2)) - TIME * 0.84;
	float wave_c = dot(p, vec2(3.9, -4.3)) + TIME * 0.56;
	vec2 slope = 0.039 * vec2(cos(wave_a), cos(wave_b))
		+ 0.017 * cos(wave_c) * vec2(1.0, -1.0);
	vec3 water_normal = normalize(vec3(slope.x, 1.0, slope.y));
	NORMAL = mat3(VIEW_MATRIX) * water_normal;
	float edge_reflection = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 view_world = mat3(INV_VIEW_MATRIX) * VIEW;
	vec3 sky_ray = reflect(-view_world, water_normal);
	vec3 sky_sheen = mix(vec3(0.94, 0.80, 0.92), vec3(0.70, 0.83, 0.98), smoothstep(0.0, 0.9, sky_ray.y));
	// Two slow, broken light bands suggest caustics through the shallow water.
	vec2 q = p * 3.8 + vec2(sin(wave_b), sin(wave_c)) * 0.35;
	float light_net = abs(sin(q.x + TIME * 0.62) + sin(q.y - TIME * 0.46));
	float caustic = (1.0 - smoothstep(0.02, 0.21, light_net))
		* (0.55 + 0.45 * sin(wave_a));
	float crest = smoothstep(0.57, 0.98, sin(wave_a + sin(wave_b) * 0.68))
		* (0.53 + 0.47 * sin(wave_c));
	float shore = smoothstep(0.005, 0.11, UV.x);
	float steps = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 hit = step_ripples[i];
		if (hit.w > 0.0 && hit.z < 0.95) {
			float radius = hit.z * (0.59 + 0.17 * hit.w) + 0.045;
			float d = length(p - hit.xy);
			float ring = 1.0 - smoothstep(0.008, 0.037, abs(d - radius));
			float echo = 1.0 - smoothstep(0.005, 0.025, abs(d - max(0.0, radius - 0.082)));
			steps += max(ring, 0.42 * echo) * hit.w * smoothstep(0.0, 0.10, hit.z) * (1.0 - smoothstep(0.23, 0.95, hit.z));
		}
	}
	vec3 tint = mix(shoal_tint.rgb, pool_tint.rgb, depth);
	ALBEDO = mix(tint, sky_sheen, edge_reflection * 0.36);
	EMISSION = tint * 0.075 + sky_sheen * edge_reflection * 0.12
		+ vec3(0.70, 0.91, 0.87) * ((caustic * 0.24 + crest * 0.105) * depth + steps * 0.20);
	ROUGHNESS = 0.20;
	SPECULAR = 0.53;
	ALPHA = shore * (0.25 + depth * 0.28 + edge_reflection * 0.10);
}
