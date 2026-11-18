shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float presence : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float radius = length((UV - 0.5) * 2.0);
	float outer_edge = 1.0 - smoothstep(0.990, 1.0, radius);
	float gradient = smoothstep(0.918, 0.986, radius) * outer_edge;
	float thread = (1.0 - smoothstep(0.002, 0.012, abs(radius - 0.982))) * outer_edge;
	float breath = 0.91 + 0.09 * sin(TIME * 1.7);
	ALBEDO = mix(vec3(0.21, 0.57, 0.92), vec3(0.51, 0.85, 1.0), thread * 0.55);
	ALPHA = (gradient * 0.13 + thread * 0.065) * breath * presence;
}
