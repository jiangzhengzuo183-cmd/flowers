shader_type canvas_item;
render_mode unshaded;

uniform float age = 0.0;
uniform float opacity = 1.0;

vec4 powder_puff(vec4 behind, vec2 p, vec2 center, vec2 radii, float phase) {
	float swell = 1.0 + 0.045 * sin(age * 3.5 + phase);
	vec2 drift = vec2(sin(age * 1.4 + phase), cos(age * 1.1 + phase)) * 0.035;
	vec2 local = (p - center - drift) / (radii * swell);
	float distance_to_center = length(local);
	float alpha = (1.0 - smoothstep(0.78, 1.09, distance_to_center)) * 0.985;
	float lit = 1.0 - smoothstep(-0.48, 0.92, dot(local, vec2(0.26, 0.89)));
	vec3 powder = mix(vec3(0.875, 0.862, 0.886), vec3(1.0, 0.987, 0.965), lit);
	return vec4(powder * alpha, alpha) + behind * (1.0 - alpha);
}

void fragment() {
	float growth = 1.0 - pow(1.0 - clamp(age / 0.28, 0.0, 1.0), 3.0);
	vec2 center = vec2(0.49 + age * 0.009, 0.52 - age * 0.016);
	vec2 p = (UV - center) / (vec2(0.48, 0.56) * mix(0.19, 1.0, growth));
	float spread = mix(0.42, 1.0, growth);
	float fringe = 1.0 - smoothstep(0.42, 1.05, age);
	vec4 cloud = powder_puff(vec4(0.0), p, vec2(-0.85, -0.65) * spread, vec2(0.13, 0.16), 4.8) * fringe;
	cloud += powder_puff(vec4(0.0), p, vec2(0.79, -0.67) * spread, vec2(0.14, 0.12), 2.9) * fringe;
	cloud = powder_puff(cloud, p, vec2(-0.61, 0.08) * spread, vec2(0.49, 0.62), 0.3);
	cloud = powder_puff(cloud, p, vec2(0.58, 0.13) * spread, vec2(0.49, 0.55), 2.6);
	cloud = powder_puff(cloud, p, vec2(-0.38, -0.39) * spread, vec2(0.57, 0.46), 1.1);
	cloud = powder_puff(cloud, p, vec2(0.27, -0.40) * spread, vec2(0.59, 0.47), 4.2);
	cloud = powder_puff(cloud, p, vec2(0.37, 0.39) * spread, vec2(0.60, 0.51), 3.4);
	cloud = powder_puff(cloud, p, vec2(0.02, 0.03), vec2(0.74, 0.65), 5.4);
	cloud = powder_puff(cloud, p, vec2(-0.27, 0.42) * spread, vec2(0.58, 0.47), 2.0);
	COLOR = vec4(cloud.rgb / max(cloud.a, 0.0001), cloud.a * opacity);
}
