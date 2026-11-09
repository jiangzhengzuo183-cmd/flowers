shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
#include "res://art/maze02/environment/dream_sky_background.gdshaderinc"

uniform vec4 mist : source_color = vec4(0.72, 0.62, 0.79, 1.0);
uniform vec4 shade : source_color = vec4(0.54, 0.48, 0.68, 1.0);
uniform vec4 amber : source_color = vec4(1.0, 0.87, 0.65, 1.0);
uniform vec4 skyline_blush : source_color = vec4(0.86,0.70,0.83,1.0);
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

void vertex() {
	altitude = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	face = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float distance_to_view = -VERTEX.z;
	bool outside = distance(CAMERA_POSITION_WORLD.xz,city_center) > 67.0;
	if (INV_VIEW_MATRIX[2].y > 0.73 || (outside && distance_to_view < 91.0) || altitude < -17.5) { discard; }
	float bank = smoothstep(-17.5, 7.0, altitude);
	float distance_fade = 1.0 - smoothstep(123.0, 205.0, length(VERTEX.xz)) * 0.43;
	float facet = clamp(dot(normalize(face), normalize(vec3(-0.63, 0.65, 0.41))) * 0.5 + 0.5, 0.0, 1.0);
	vec3 view_ray = -(mat3(INV_VIEW_MATRIX) * VIEW);
	vec3 haze = dream_background(view_ray,zenith.rgb,middle.rgb,horizon.rgb,nadir.rgb,cloud_color.rgb,sky_details);
	vec3 facade = windows ? amber.rgb : mix(shade.rgb, mist.rgb, facet * 0.87);
	float blush = (1.0-smoothstep(-3.5,22.0,altitude))*0.25;
	facade = mix(facade,skyline_blush.rgb,blush * (windows ? 0.18 : 1.0));
	// Haze changes the surface color. Opaque depth keeps neighboring roofs behind walls.
	ALBEDO = mix(haze,facade,bank * distance_fade * clarity);
}
