shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;

uniform vec4 body_color : source_color = vec4(0.64, 0.82, 0.90, 1.0);
uniform vec4 edge_color : source_color = vec4(0.86, 0.97, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.58;
uniform float rim_strength : hint_range(0.0, 1.0) = 1.0;
uniform float rim_power : hint_range(1.0, 8.0) = 2.2;
uniform float bottom_y = 0.0;
uniform float model_height = 99.6792678833;
uniform float bottom_fade : hint_range(0.02, 0.8) = 0.30;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.28;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;
uniform float breath_amount : hint_range(0.0, 0.2) = 0.025;
// Head shading is deliberately smoothed without moving a vertex.
uniform float soften_head : hint_range(0.0, 1.0) = 0.88;

varying vec3 normalized_position;
varying vec3 soft_view_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
		mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
		mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	normalized_position = (VERTEX - vec3(0.0, bottom_y, 0.0)) / max(model_height, 0.0001);
	vec3 head_normal = normalize((normalized_position - vec3(0.0, 0.845, 0.0)) / vec3(0.022, 0.026, 0.025));
	float head_mix = smoothstep(0.70, 0.80, normalized_position.y) * soften_head;
	soft_view_normal = MODELVIEW_NORMAL_MATRIX * normalize(mix(NORMAL, head_normal, head_mix));
}

void fragment() {
	vec3 p = normalized_position;
	float rim = pow(1.0 - clamp(dot(normalize(soft_view_normal), normalize(VIEW)), 0.0, 1.0), rim_power);
	float coarse = noise3(p * 14.0 + vec3(0.0, -effect_time * 0.11, 0.0));
	float fine = noise3(p * 37.0 + vec3(effect_time * 0.035, -effect_time * 0.19, 0.0));
	float lower = 1.0 - smoothstep(0.12, 0.38, p.y);
	float vertical = smoothstep(0.005, bottom_fade, p.y + (coarse - 0.5) * 0.075);
	float edge_mask = smoothstep(0.08, 0.65, rim);
	float erosion = 1.0 - noise_strength * (0.4 + 0.6 * lower) * edge_mask * (1.0 - smoothstep(0.25, 0.65, fine));
	float lower_wisps = 1.0 - 0.16 * lower * (1.0 - smoothstep(0.24, 0.62, fine));
	// 0 = full ghost; 1 = fully gone, with no hard bright burn line.
	float disappear = smoothstep(dissolve * 1.22 - 0.16, dissolve * 1.22 + 0.04, p.y * 0.83 + coarse * 0.17);
	float breathing = sin(effect_time * 2.0943951) * breath_amount;
	ALBEDO = mix(body_color.rgb, edge_color.rgb, rim * rim_strength);
	// Ignore the GLB alpha texture: recompute fade here, so it is applied only once.
	ALPHA = clamp(opacity * (1.0 + breathing / 0.58 + rim * 0.069) * vertical * erosion * lower_wisps * disappear, 0.0, 0.64);
}
