shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
#include "res://art/maze02/environment/dream_sky_background.gdshaderinc"

uniform vec4 mist : source_color = vec4(0.72, 0.62, 0.79, 1.0);
uniform vec4 shade : source_color = vec4(0.54, 0.48, 0.68, 1.0);
uniform vec4 amber : source_color = vec4(1.0, 0.87, 0.65, 1.0);
uniform vec4 skyline_blush : source_color = vec4(0.85,0.77,0.61,1.0);
uniform vec4 zenith : source_color = vec4(0.53, 0.63, 0.91, 1.0);
uniform vec4 middle : source_color = vec4(0.79, 0.65, 0.91, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.89, 0.92, 1.0);
uniform vec4 nadir : source_color = vec4(0.66, 0.64, 0.88, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.99,0.97,1.0,1.0);
uniform bool sky_details = true;
uniform float clarity = 0.84;
uniform vec2 city_center = vec2(22.8);
uniform bool windows = false;
varying float altitude;
varying vec3 face;
varying vec2 district_position;

void vertex() {
	vec3 point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	altitude = point.y;
	district_position = point.xz;
	face = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float distance_to_view = -VERTEX.z;
	bool outside = distance(CAMERA_POSITION_WORLD.xz,city_center) > 67.0;
	if (INV_VIEW_MATRIX[2].y > 0.73 || (outside && distance_to_view < 91.0) || altitude < -17.5) { discard; }
	float bank = smoothstep(-8.0, 17.0, altitude);
	float distance_fade = 1.0 - smoothstep(101.0, 211.0, length(VERTEX.xz)) * 0.73;
	float facet = clamp(dot(normalize(face), normalize(vec3(-0.63, 0.65, 0.41))) * 0.5 + 0.5, 0.0, 1.0);
	vec3 view_ray = -(mat3(INV_VIEW_MATRIX) * VIEW);
	vec3 haze = dream_background(view_ray,zenith.rgb,middle.rgb,horizon.rgb,nadir.rgb,cloud_color.rgb,sky_details);
	vec3 facade = windows ? amber.rgb : mix(shade.rgb, mist.rgb, facet * 0.87);
	float blush = (1.0-smoothstep(-3.5,22.0,altitude))*0.25;
	facade = mix(facade,skyline_blush.rgb,blush * (windows ? 0.18 : 1.0));
	float far_layer = 1.0 - smoothstep(0.49, 0.78, clarity);
	facade = mix(facade, vec3(0.91, 0.81, 0.69), far_layer * (windows ? 0.12 : 0.28));
	// Slow, broad dust swells keep the lower streets diffused.
	float front = dot(district_position, vec2(0.067, 0.039)) - TIME * 0.29;
	float gust = smoothstep(0.03, 0.92, sin(front + sin(front * 0.47) * 0.85));
	float lower = 1.0 - smoothstep(2.3, 18.5, altitude + sin(front * 1.32) * 3.9);
	float swell = 1.0 - smoothstep(0.1, 5.6, abs(altitude - (7.6 + sin(front) * 3.0)));
	float reveal = 1.0 - min(0.96, lower * 0.38 + gust * (lower * 0.44 + swell * 0.23));
	float windows_keep = smoothstep(-0.36, 0.48, sin(district_position.x * 0.41 + district_position.y * 0.29 + altitude * 0.62));
	float contrast = bank * distance_fade * clarity * reveal * 0.58;
	vec3 color = mix(haze, facade, contrast);
	if (windows) {
		// Small lit surfaces stay legible after the darker city mass fades into dust.
		float transmission = smoothstep(-9.0, 9.0, altitude) * distance_fade * mix(0.40, 0.91, reveal);
		color = mix(haze, facade, contrast * 0.38)
			+ vec3(0.42, 0.24, 0.083) * transmission * mix(0.13, 1.0, windows_keep);
	} else {
		float bright_face = smoothstep(0.67, 0.99, facet) * smoothstep(6.0, 19.0, altitude);
		color += vec3(0.17, 0.108, 0.039) * bright_face * distance_fade * mix(0.58, 1.0, reveal);
	}
	// Haze changes the surface color. Opaque depth keeps neighboring roofs behind walls.
	ALBEDO = color;
}
