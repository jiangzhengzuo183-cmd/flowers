shader_type canvas_item;
render_mode unshaded;
// One continuous light field above the ink, mouse and paper. No captured-screen texture.
void fragment() {
	vec2 p = UV;
	vec2 light_distance = (p - vec2(0.20, 0.15)) * vec2(1.15, 1.30);
	float sunlight = exp(-dot(light_distance, light_distance) * 2.3) * 0.10;
	float falloff = smoothstep(0.25, 1.08, dot(p, vec2(0.58, 0.62))) * 0.14;
	// A wide, soft penumbra from outside the upper-right edge of the paper.
	float edge = p.x * 0.78 + p.y * 0.36 + sin(p.y * 3.7) * 0.015;
	float cast_shadow = smoothstep(0.62, 0.79, edge) * 0.15;
	float corner = smoothstep(0.65, 1.25, p.x + p.y * 0.46) * 0.035;
	float shadow = 1.0 - (1.0 - falloff) * (1.0 - cast_shadow) * (1.0 - corner);
	vec3 shadow_color = vec3(0.32, 0.29, 0.24);
	vec3 light_color = vec3(1.0, 0.95, 0.80);
	float opacity = sunlight + shadow * (1.0 - sunlight);
	vec3 lighting = (light_color * sunlight + shadow_color * shadow * (1.0 - sunlight)) / max(opacity, 0.0001);
	COLOR = vec4(lighting, opacity);
}
