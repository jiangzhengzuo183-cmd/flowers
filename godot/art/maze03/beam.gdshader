shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
void fragment() {
	float feather = pow(sin(UV.x * 3.14159265), 3.0);
	float vertical_fade = smoothstep(0.0, 0.10, UV.y) * (1.0-smoothstep(0.65, 1.0, UV.y));
	float dust = 0.85 + sin(UV.y*24.0 - TIME*0.22)*0.1;
	ALBEDO = vec3(0.72, 0.88, 1.0);
	ALPHA = feather * vertical_fade * dust * 0.045;
}
