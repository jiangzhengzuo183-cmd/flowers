shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, skip_vertex_transform;

uniform vec4 pale_gold : source_color = vec4(1.0, 0.95, 0.79, 1.0);
uniform vec4 weathered_gold : source_color = vec4(0.58, 0.49, 0.34, 1.0);
uniform vec3 drift_extent;
varying float visibility;
varying float tint;

void vertex() {
	float phase = INSTANCE_CUSTOM.r;
	float gust = INSTANCE_CUSTOM.b;
	float is_gust = step(0.05, gust);
	float crossing = fract(phase + TIME * mix(0.85, 1.39, INSTANCE_CUSTOM.g));
	float swirl = TIME * (2.5 + INSTANCE_CUSTOM.g * 1.5) + phase * TAU;
	float cycle = fract(TIME / (11.0 + gust * 7.0) + gust * 1.42);
	float spread = mix(1.0, smoothstep(0.04, 0.44, cycle), step(0.05, gust));
	vec3 offset = drift_extent * vec3(crossing * 2.0 - 1.0, sin(swirl),
		sin(swirl * 0.72 + gust * 6.0) * spread);
	vec3 origin = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz + offset, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec2 wind_on_screen = (mat3(VIEW_MATRIX) * vec3(1.0, 0.10, 0.0)).xy;
	vec2 along = normalize(wind_on_screen + vec2(0.001, 0.0));
	vec2 across = vec2(-along.y, along.x);
	float stretch = mix(2.05, 2.8, is_gust) * clamp(length(wind_on_screen), 0.56, 1.0);
	VERTEX = origin + vec3((along * VERTEX.x * stretch + across * VERTEX.y) * size, 0.0);
	// Each gust bank has its own cycle. Its flecks fade instead of appearing as fog.
	float burst = smoothstep(0.035, 0.18, cycle) * (1.0 - smoothstep(0.34, 0.61, cycle));
	visibility = smoothstep(0.0, 0.17, crossing) * (1.0 - smoothstep(0.83, 1.0, crossing));
	float gust_front = 0.72 + 0.28 * sin(MODEL_MATRIX[3].x * 0.68 + MODEL_MATRIX[3].z * 0.21 - TIME * 2.6);
	visibility *= mix(gust_front, burst, is_gust);
	visibility *= smoothstep(0.35, 1.0, -origin.z) * (1.0 - smoothstep(18.0, 34.0, -origin.z));
	tint = INSTANCE_CUSTOM.a;
}

void fragment() {
	float soft_edge = 1.0 - smoothstep(0.06, 0.50, length(UV - vec2(0.5)));
	ALBEDO = mix(pale_gold.rgb, weathered_gold.rgb, smoothstep(0.28, 0.94, tint));
	ALPHA = soft_edge * visibility * 0.94;
}
