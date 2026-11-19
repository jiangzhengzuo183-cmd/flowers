shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float opacity = 0.0;

void fragment() {
	float path = 0.50 + 0.18 * (1.0-UV.x) * (1.0-UV.x);
	float across = abs(UV.y - path);
	float along = smoothstep(0.035, 0.88, UV.x) * (1.0 - smoothstep(0.90, 0.99, UV.x));
	float width = mix(0.018, 0.11, smoothstep(0.1, 0.92, UV.x));
	float core = (1.0 - smoothstep(width*0.44, width, across)) * along;
	float tail_halo = (1.0 - smoothstep(width*0.4, width+0.20, across)) * along;
	float head = 1.0 - smoothstep(0.18, 0.83, length((UV - vec2(0.88,0.503))*vec2(13.0,3.0)));
	ALBEDO = mix(vec3(0.36, 0.89, 0.91), vec3(0.94, 1.0, 1.0), max(head, core * 0.71));
	ALPHA = max(core * 0.69, head * 0.79) * opacity + tail_halo * opacity * 0.18;
}
