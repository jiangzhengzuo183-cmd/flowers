shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float foot_side = 1.0;
uniform vec4 dust_tint : source_color = vec4(0.40, 0.29, 0.24, 1.0);

float sole(vec2 p, vec2 center, vec2 radii) {
	return 1.0 - smoothstep(0.81, 1.0, length((p - center) / radii));
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= foot_side;
	float forefoot = sole(p, vec2(-0.03, -0.14), vec2(0.35, 0.29));
	float heel = sole(p, vec2(0.07, 0.26), vec2(0.24, 0.16));
	float instep = sole(p, vec2(0.05, 0.09), vec2(0.22, 0.22));
	float tread = 0.80 + 0.20 * smoothstep(0.12, 0.38, abs(fract(p.y * 8.0 + p.x * 0.18) - 0.5));
	ALBEDO = dust_tint.rgb;
	ALPHA = max(max(forefoot, heel), instep * 0.55) * tread * fade * 0.27;
}
