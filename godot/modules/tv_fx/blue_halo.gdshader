shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform float blue_glow = 0.0;

void fragment() {
	vec2 p = abs((UV * 2.0 - 1.0) * vec2(47.0, 37.0));
	float radius = pow(pow(p.x / 34.7, 8.0) + pow(p.y / 24.8, 8.0), 0.125);
	float broad = exp(-pow((radius - 0.98) * 2.4, 2.0));
	float narrow = exp(-pow((radius - 0.99) * 16.0, 2.0));
	float rim_fade = 1.0 - smoothstep(0.88, 1.0, max(abs(UV.x * 2.0 - 1.0), abs(UV.y * 2.0 - 1.0)));
	ALBEDO = vec3(0.045, 0.38, 1.0);
	ALPHA = (broad * 0.55 + narrow * 0.32) * blue_glow * rim_fade;
}
