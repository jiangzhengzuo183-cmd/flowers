shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
#include "shade_motion.gdshaderinc"

uniform vec4 body_color : source_color = vec4(0.55, 0.83, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.82, 0.96, 1.0, 1.0);
uniform float opacity : hint_range(0.1, 0.7) = 0.24;
uniform float garment_opacity : hint_range(0.2, 0.7) = 0.48;
uniform float hair_opacity : hint_range(0.2, 0.7) = 0.38;
uniform float rim_strength : hint_range(0.0, 0.5) = 0.28;
uniform float breath_amount : hint_range(0.0, 0.1) = 0.025;
uniform bool debug_solid = false;
varying vec3 soft_normal;
varying vec3 local_point;
varying float garment_mask;
varying float hair_mask;

void vertex() {
	local_point = VERTEX;
	float appearance_code = UV2.x < -1.5 ? UV2.x + 2.0 : UV2.x;
	garment_mask = clamp(-appearance_code - 0.01, 0.0, 1.0);
	hair_mask = clamp(UV2.x, 0.0, 1.0);
	VERTEX += shade_offset(VERTEX, UV2);
	// Keep facial relief quiet while preserving every original vertex.
	vec3 head_normal = normalize((local_point - vec3(0.025, 0.842, 0.0)) / vec3(0.13, 0.15, 0.15));
	float head_mask = smoothstep(0.70, 0.79, local_point.y);
	soft_normal = MODELVIEW_NORMAL_MATRIX * normalize(mix(NORMAL, head_normal, head_mask * 0.94));
}

void fragment() {
	vec3 surface_normal = normalize(NORMAL);
	float head_mask = smoothstep(0.70, 0.79, local_point.y);
	vec3 quiet_normal = normalize(mix(surface_normal, normalize(soft_normal), head_mask * 0.72 * (1.0 - hair_mask * 0.60)));
	float rim = pow(1.0 - clamp(dot(quiet_normal, normalize(VIEW)), 0.0, 1.0), 2.4);
	float breathing = 1.0 + sin(effect_time * 1.14) * breath_amount;
	float variation = 0.015 * sin(local_point.y * 14.0 + effect_time * 0.3);
	float garment_gradient = smoothstep(0.15, 0.67, local_point.y);
	vec3 shade = body_color.rgb;
	shade = mix(shade, rim_color.rgb, rim * rim_strength);
	float volume = 1.05 + 0.12 * max(dot(quiet_normal, normalize(vec3(-0.45, 0.65, 0.8))), 0.0);
	ALBEDO = shade * (volume + variation) * breathing;
	EMISSION = shade * (0.25 + rim * 0.10) * breathing;
	float cloth_alpha = garment_opacity * mix(0.6667, 1.0, garment_gradient);
	float layer_opacity = mix(mix(opacity, cloth_alpha, garment_mask), hair_opacity, hair_mask);
	ALPHA = clamp(layer_opacity + rim * 0.035, 0.0, 0.70);
	if (debug_solid) {
		ALBEDO = mix(vec3(0.75, 0.48, 0.40), vec3(0.32, 0.48, 0.70), garment_mask);
		EMISSION = vec3(0.0);
		ALPHA = 1.0;
	}
}
