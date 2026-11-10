shader_type sky;
#include "res://art/maze02/environment/dream_sky_background.gdshaderinc"

uniform vec4 zenith : source_color;
uniform vec4 middle : source_color;
uniform vec4 horizon : source_color;
uniform vec4 nadir : source_color;
uniform vec4 cloud_color : source_color;
uniform bool sky_details = false;

float mote(vec2 p, vec2 center, vec2 radius) {
	vec2 d = p - center;
	d.x = mod(d.x + PI, TAU) - PI;
	float glow = length(d / radius);
	return 1.0 - smoothstep(0.08, 1.0, glow);
}

void sky() {
	COLOR = dream_background(EYEDIR, zenith.rgb, middle.rgb, horizon.rgb, nadir.rgb, cloud_color.rgb, sky_details);
	if (sky_details && !AT_CUBEMAP_PASS && EYEDIR.y > 0.14) {
		vec2 p = vec2(atan(EYEDIR.x, EYEDIR.z), asin(clamp(EYEDIR.y, -1.0, 1.0)));
		float glint = mote(p, vec2(1.36, 0.26), vec2(0.009, 0.004)) * 0.44;
		glint += mote(p, vec2(1.95, 0.35), vec2(0.005, 0.004)) * 0.51;
		glint += mote(p, vec2(2.11, 0.49), vec2(0.014, 0.004)) * 0.43;
		glint += mote(p, vec2(-1.12, 0.34), vec2(0.012, 0.004)) * 0.40;
		glint += mote(p, vec2(-1.57, 0.56), vec2(0.005, 0.005)) * 0.44;
		glint += mote(p, vec2(1.73, 0.71), vec2(0.005, 0.003)) * 0.22;
		glint += mote(p, vec2(1.28, 0.86), vec2(0.006, 0.003)) * 0.16;
		glint += mote(p, vec2(-0.98, 0.82), vec2(0.006, 0.003)) * 0.17;
		COLOR = mix(COLOR, vec3(1.0, 0.977, 0.90), glint);
	}
}
