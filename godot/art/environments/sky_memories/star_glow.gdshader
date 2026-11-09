shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 a = abs(p);
	float radial = length(p);
	float pearl = 1.0 - smoothstep(0.087, 0.28, radial);
	float cross = pow(max(0.0, 1.0-a.x*1.26-a.y*5.8), 2.1)
		+ pow(max(0.0, 1.0-a.y*1.18-a.x*6.6), 2.1);
	float diamond = 1.0 - smoothstep(0.14, 0.46, a.x*1.44 + a.y);
	float shape = COLOR.r < 0.30 ? pearl : max(pearl, COLOR.r < 0.74 ? cross : diamond);
	float breath = 0.81 + 0.19 * sin(TIME * 0.81 + COLOR.g * TAU);
	float blink = pow(max(0.0, sin(TIME * 0.63 + COLOR.g * TAU)), 19.0) * COLOR.b * 0.29;
	float glow = exp(-dot(p,p) * 5.1);
	ALBEDO = mix(vec3(0.55, 0.82, 1.0), vec3(0.98, 1.0, 1.0), clamp(shape, 0.0, 1.0));
	ALPHA = clamp((0.33 * glow + shape * 0.92) * COLOR.a * (breath + blink), 0.0, 0.93);
}
