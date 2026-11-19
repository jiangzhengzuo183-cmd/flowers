shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 cloud_tint : source_color = vec4(1.0, 0.94, 0.97, 1.0);
uniform float pattern_scale = 0.06;
uniform float opacity = 0.55;
uniform vec2 drift = vec2(0.01, 0.0);
uniform vec2 offset = vec2(0.0);
varying vec2 cloud_world;

void vertex() {
	cloud_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float cloud_hash(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cloud_hash(cell), cloud_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(cloud_hash(cell + vec2(0.0, 1.0)), cloud_hash(cell + vec2(1.0)), f.x), f.y);
}

float cloud_lobe(vec2 point, vec2 center, vec2 radius) {
	float border = length((point - center) / radius);
	return 1.0 - smoothstep(0.66, 1.0, border);
}

void fragment() {
	vec2 p = (cloud_world + offset) * pattern_scale * vec2(0.64, 1.0) + TIME * drift;
	float form = soft_noise(p) * 0.73 + soft_noise(p * 2.3 + vec2(4.2, 8.6)) * 0.27;
	float edge = 1.0 - smoothstep(110.0, 208.0, length(cloud_world - vec2(22.8)));
	vec2 q = cloud_world - vec2(22.8) + offset * 0.58 + drift * TIME * 18.0;
	float bank = cloud_lobe(q, vec2(41.0, -34.0), vec2(37.0, 14.0));
	bank = max(bank, cloud_lobe(q, vec2(30.0, -39.0), vec2(20.0, 14.0)) * 0.85);
	bank = max(bank, cloud_lobe(q, vec2(68.0, -29.0), vec2(24.0, 12.0)) * 0.72);
	float drift_cloud = cloud_lobe(q, vec2(-38.0, 26.0), vec2(26.0, 14.0));
	drift_cloud = max(drift_cloud, cloud_lobe(q, vec2(-22.0, 30.0), vec2(18.0, 10.0)) * 0.78);
	float angle_fade = smoothstep(0.035, 0.28, abs(dot(normalize(NORMAL), VIEW)));
	ALBEDO = cloud_tint.rgb;
	vec2 from_maze = abs(cloud_world - vec2(22.8));
	float outside = smoothstep(23.0, 36.0, max(from_maze.x, from_maze.y));
	float surrounding = outside * smoothstep(0.36, 0.75, form) * 0.74;
	float bank_shape = max(max(bank, drift_cloud * 0.65), surrounding) * (0.54 + 0.45 * form);
	ALPHA = (bank_shape + 0.19 * smoothstep(0.39, 0.79, form)) * edge * angle_fade * opacity;
}
