shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D base_color : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 lavender : source_color = vec4(0.80, 0.72, 0.88, 1.0);

void fragment() {
	vec3 color = texture(base_color, UV).rgb;
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float shadow_lift = 0.25 * (1.0 - smoothstep(0.07, 0.76, luminance));
	vec3 softened = mix(color, vec3(luminance), 0.08);
	// Ease the orange cast on hair and skin while keeping the blue fabric clear.
	softened.b += 0.045 * smoothstep(0.08, 0.44, color.r - color.b);
	ALBEDO = mix(softened, lavender.rgb, shadow_lift);
	ROUGHNESS = 0.72;
	SPECULAR = 0.30;

	// A little reflected color in the shade and along grazing angles.
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = smoothstep(0.50, 0.95, 1.0 - facing);
	EMISSION = ALBEDO * 0.09 + lavender.rgb * edge * 0.075;
}
