float dream_cloud(vec2 p, vec2 center, vec2 scale) {
	vec2 d = p-center;
	d.x = mod(d.x + PI, TAU) - PI;
	d /= scale;
	vec2 lobe = (d - vec2(0.32, 0.44))*vec2(1.28, 1.15);
	return max(exp(-dot(d,d)*2.0), exp(-dot(lobe,lobe)*2.0)*0.72);
}

vec3 dream_background(vec3 direction, vec3 zenith, vec3 middle, vec3 horizon,
		vec3 nadir, vec3 cloud_color, bool details) {
	float height = direction.y;
	vec3 upper = mix(horizon, middle, smoothstep(0.0, 0.42, height));
	upper = mix(upper, zenith, smoothstep(0.28, 0.92, height));
	vec3 lower = mix(nadir, middle, smoothstep(-0.98, -0.20, height));
	lower = mix(lower, horizon, smoothstep(-0.44, 0.0, height));
	vec3 gradient = mix(lower, upper, smoothstep(-0.015, 0.015, height));
	vec2 p = vec2(atan(direction.x, direction.z), asin(clamp(height, -1.0, 1.0)));
	float clouds = dream_cloud(p, vec2(-1.25, 0.16), vec2(0.44, 0.062))*0.39;
	clouds += dream_cloud(p, vec2(0.52, 0.26), vec2(0.48, 0.073))*0.34;
	clouds += dream_cloud(p, vec2(2.97, -0.27), vec2(0.38, 0.095))*0.40;
	clouds += dream_cloud(p, vec2(1.84, -0.32), vec2(0.43, 0.105))*0.34;
	if (details) {
		float sunrise = dream_cloud(p, vec2(-0.9, 0.03), vec2(1.14, 0.30));
		gradient = mix(gradient, vec3(1.0, 0.95, 0.90), sunrise * 0.30);
		float bank = dream_cloud(p, vec2(-1.64, -0.075), vec2(0.72, 0.076));
		bank = max(bank, dream_cloud(p, vec2(-1.12, -0.114), vec2(0.63, 0.045)) * 0.75);
		bank = max(bank, dream_cloud(p, vec2(1.68, -0.31), vec2(0.88, 0.12)) * 0.60);
		clouds = bank * 0.53 + clouds * 0.20;
	}
	return mix(gradient, cloud_color, clamp(clouds, 0.0, 0.55));
}
