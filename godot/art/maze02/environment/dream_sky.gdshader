shader_type sky;
#include "res://art/maze02/environment/dream_sky_background.gdshaderinc"

uniform vec4 zenith : source_color = vec4(0.70,0.75,0.97,1.0);
uniform vec4 middle : source_color = vec4(0.89,0.78,0.93,1.0);
uniform vec4 horizon : source_color = vec4(0.99,0.93,0.93,1.0);
uniform vec4 nadir : source_color = vec4(0.74,0.72,0.93,1.0);
uniform vec4 cloud_color : source_color = vec4(0.99,0.97,1.0,1.0);
uniform bool sky_details = false;

float night_seed(vec2 cell) {
	return fract(52.9829189 * fract(dot(cell, vec2(0.06711056, 0.00583715))));
}

float petal_link(vec2 point, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float along = clamp(dot(point - a, ab) / dot(ab, ab), 0.0, 1.0);
	return 1.0 - smoothstep(0.0008, 0.0037, length(point - a - along * ab));
}

float distant_stars(vec2 p) {
	vec2 grid = p * 27.0;
	vec2 cell = floor(grid);
	float seed = night_seed(cell);
	vec2 offset = 0.15 + 0.70 * vec2(seed, night_seed(cell + 17.0));
	float stars = (1.0 - smoothstep(0.024, 0.073, length(fract(grid) - offset))) * step(0.94, seed);
	vec2 q = p - vec2(0.26, 0.52);
	vec2 a = vec2(0.0, -0.073), b = vec2(-0.074, -0.013), c = vec2(-0.083, 0.065);
	vec2 d = vec2(0.0, 0.025), e = vec2(0.072, 0.070), f = vec2(0.066, -0.016);
	float flower = petal_link(q, a, b) + petal_link(q, b, c) + petal_link(q, c, d)
		+ petal_link(q, d, e) + petal_link(q, e, f) + petal_link(q, f, a);
	float tips = min(min(min(length(q - a), length(q - b)), min(length(q - c), length(q - d))), min(length(q - e), length(q - f)));
	float buds = 1.0 - smoothstep(0.0015, 0.0048, tips);
	return stars * 0.27 * smoothstep(0.21, 0.46, p.y) + flower * 0.13 + buds * 0.36;
}
void sky() {
	float height = EYEDIR.y;
	vec2 p = vec2(atan(EYEDIR.x, EYEDIR.z), asin(clamp(height, -1.0, 1.0)));
	COLOR = dream_background(EYEDIR,zenith.rgb,middle.rgb,horizon.rgb,nadir.rgb,cloud_color.rgb,sky_details);
	if (sky_details && !AT_CUBEMAP_PASS && height > 0.14) {
		COLOR = mix(COLOR, vec3(1.0, 0.96, 1.0), clamp(distant_stars(p), 0.0, 0.47));
	}
}
