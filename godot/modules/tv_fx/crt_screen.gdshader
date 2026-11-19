shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;

uniform sampler2D original_albedo : source_color, filter_linear_mipmap;
uniform float effect_time = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.45;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float blue_glow = 0.0;
uniform float screen_brightness : hint_range(0.0, 1.0) = 1.0;
uniform bool snow_enabled = true;
uniform bool scanlines_enabled = true;
uniform bool flicker_enabled = true;
uniform bool content_motion_enabled = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// UV preserves the source atlas. UV2 is a continuous front projection,
	// so procedural scanlines do not inherit the source UV seams.
	vec2 q = abs(UV2 * 2.0 - 1.0);
	float edge = pow(q.x, 8.0) + pow(q.y, 8.0);
	float mask = 1.0 - smoothstep(0.88, 1.0, edge);
	if (mask < 0.001) { discard; }
	float frame = floor(effect_time * 24.0);
	float snow = hash(floor(UV2 * vec2(280.0, 200.0)) + vec2(frame, frame * 0.73));
	float line = 0.5 + 0.5 * sin(UV2.y * 200.0 * 6.283185 + effect_time * 3.0);
	float roll = exp(-pow((fract(UV2.y - effect_time * 0.16) - 0.5) * 22.0, 2.0));
	float pulse = hash(vec2(floor(effect_time * 7.0), 49.0));
	float flicker = mix(0.85, 1.07, pulse);
	float dropout = 1.0 - step(0.97, hash(vec2(floor(effect_time * 4.0), 3.0))) * 0.5;
	float strength = clamp(intensity + burst * 0.6, 0.0, 1.0);
	vec2 content_uv = UV;
	if (content_motion_enabled) {
		// Small horizontal offsets animate the warning image itself. Brief
		// row-wide jumps read as analog signal tearing, with no mesh movement.
		float drift = sin(effect_time * 12.0 + UV2.y * 28.0) * 0.0009;
		float row = floor(UV2.y * 24.0);
		float tear = step(0.925, hash(vec2(row, floor(effect_time * 10.0))));
		float jump = (hash(vec2(row + 37.0, frame)) - 0.5) * tear * 0.007;
		content_uv.x += (drift + jump) * strength;
	}
	vec3 base = texture(original_albedo, content_uv).rgb;
	vec3 color = base;
	if (snow_enabled) {
		color = mix(color, vec3(snow), strength * (0.48 + burst * 0.28));
	}
	if (scanlines_enabled) {
		color *= 1.0 - line * 0.25 * strength;
		color += roll * strength * 0.12;
	}
	if (flicker_enabled) {
		color *= mix(1.0, flicker * dropout, strength);
		color = mix(color, vec3(0.94, 0.97, 0.86), burst * step(0.91, pulse) * 0.3);
	}
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0)) * screen_brightness;
	ROUGHNESS = 0.9;
	SPECULAR = 0.5 * screen_brightness;
	METALLIC = 0.0;
	// Emission gives the glass a blue luminous core. A separate soft halo
	// and local light provide visible spill in the Compatibility renderer.
	EMISSION = (color * strength * 0.12 + vec3(0.035, 0.32, 1.25) * blue_glow * (0.45 + snow * 0.4)) * screen_brightness;
	ALPHA = mask;
}
