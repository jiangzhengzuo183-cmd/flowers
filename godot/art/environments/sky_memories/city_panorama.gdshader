shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D skyline : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 window_warmth : source_color = vec4(1.0, 0.84, 0.56, 1.0);
uniform vec4 silhouette_tint : source_color = vec4(0.49, 0.47, 0.66, 1.0);
uniform vec4 distant_tint : source_color = vec4(0.74, 0.70, 0.84, 1.0);
uniform float opacity = 0.73;

float seed(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float edge_mask = texture(skyline, UV).a;
	vec4 broad = textureLod(skyline, UV, 3.85);
	float coverage = mix(edge_mask, broad.a, 0.42);
	// The join and the faded base leave the authored sky visible around the city.
	float join = smoothstep(0.0, 0.045, UV.x) * (1.0 - smoothstep(0.955, 1.0, UV.x));
	float ground_fade = 1.0 - smoothstep(0.71, 0.98, UV.y);
	float distance_to_viewer = length(VERTEX);
	float air = smoothstep(22.0, 59.0, distance_to_viewer)
		* (1.0 - smoothstep(102.0, 207.0, distance_to_viewer) * 0.30);
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		air *= 1.0 - smoothstep(167.0, 198.0, -VERTEX.z);
	}
	// Read the image as silhouettes and broad planes rather than masonry detail.
	float tone = dot(broad.rgb, vec3(0.2126, 0.7152, 0.0722));
	float masonry = 1.0 - smoothstep(0.71, 0.88, tone);
	vec2 grid = UV * vec2(156.0, 18.0);
	vec2 cell = floor(grid);
	float random = seed(cell);
	vec2 pane = fract(grid) - vec2(0.5);
	float lit = step(0.938, random) * smoothstep(0.43, 0.77, coverage);
	float aperture = 1.0 - smoothstep(0.55, 1.0, length(pane * vec2(9.8, 6.0)));
	float amber = (aperture * 0.67 + exp(-dot(pane,pane) * 49.0) * 0.24) * lit;
	vec3 outline = mix(distant_tint.rgb, silhouette_tint.rgb, masonry * 0.71);
	ALBEDO = mix(outline, window_warmth.rgb, amber * 0.68);
	float density = smoothstep(0.060, 0.42, coverage) * coverage * mix(0.44, 0.81, masonry);
	ALPHA = (density * opacity + amber * 0.17) * join * ground_fade * air;
}
