shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform float pulse = 0.0;
uniform float ripple_age = 10.0;
void vertex() {
	VERTEX.z += sin(VERTEX.y * 3.2 + TIME * 1.4) * 0.012;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = pow(max(abs(p.x), abs(p.y)), 55.0);
	float flow = pow(0.5 + 0.5 * sin(UV.y * 52.0 - TIME * 1.3 + sin(UV.x * 12.0 + TIME) * 1.4), 14.0);
	float radius = length(p * vec2(1.0, 1.6));
	float ring = exp(-pow((radius - ripple_age * 2.6) * 14.0, 2.0)) * exp(-ripple_age * 2.0);
	ALBEDO = mix(vec3(0.13, 0.50, 0.78), vec3(0.72, 0.93, 1.0), edge * 0.7 + ring * 0.8);
	EMISSION = ALBEDO * (0.06 + edge * 0.12 + pulse * 0.16 + ring * 0.20);
	ALPHA = 0.30 + edge * 0.18 + flow * 0.035 + pulse * 0.12 + ring * 0.20;
}
