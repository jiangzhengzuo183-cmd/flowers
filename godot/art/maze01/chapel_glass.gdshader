shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 clear_glass : source_color = vec4(0.392157, 0.662745, 0.658824, 1.0);
uniform vec4 sky_blue : source_color = vec4(0.57, 0.78, 0.82, 1.0);
uniform vec4 sky_pink : source_color = vec4(0.98, 0.85, 0.91, 1.0);
uniform vec4 room_gold : source_color = vec4(1.0, 0.77, 0.49, 1.0);
uniform vec3 chandelier_position = vec3(24.0, 3.8, 22.8);
uniform bool flower = false;
varying vec3 pane_world;

void vertex() {
	pane_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float petal(vec2 point, vec2 axis) {
	vec2 local = vec2(dot(point, axis), dot(point, vec2(-axis.y, axis.x)));
	float ellipse = length((local - vec2(0.09, 0.0)) / vec2(0.095, 0.034));
	return 1.0 - smoothstep(0.065, 0.15, abs(ellipse - 1.0));
}

void fragment() {
	vec3 reflected = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	vec3 sky = mix(sky_pink.rgb, sky_blue.rgb, smoothstep(-0.03, 0.66, reflected.y));
	float sheen = pow(max(0.0, dot(normalize(vec3(-0.43, 0.46, -0.77)), reflected)), 22.0);
	vec3 room_ray = normalize(chandelier_position - pane_world);
	float aligned = clamp(dot(reflected, room_ray), 0.0, 1.0);
	float lamp_glint = pow(aligned, 11.0) * 0.56 + pow(aligned, 37.0) * 0.44;
	vec2 amber_detail = (UV - vec2(FRONT_FACING ? 0.73 : 0.27, 0.68)) * vec2(5.7, 8.2);
	float room_reflection = clamp(lamp_glint * 0.83 + exp(-dot(amber_detail, amber_detail)) * 0.23, 0.0, 1.0);
	float edge = smoothstep(0.40, 0.49, abs(UV.x - 0.5));
	float mark = 0.0;
	if (flower) {
		vec2 p = (UV - vec2(0.50, 0.64)) * vec2(1.0, 2.22);
		mark = max(petal(p, vec2(0.0, 1.0)),
			max(petal(p, vec2(-0.82, 0.572)), petal(p, vec2(0.82, 0.572))));
	}
	ALBEDO = mix(clear_glass.rgb, sky, 0.07 + fresnel * 0.22);
	ALBEDO = mix(ALBEDO, room_gold.rgb, room_reflection * 0.57);
	ALBEDO = mix(ALBEDO, vec3(0.95, 0.88, 0.74), mark * 0.48);
	EMISSION = clear_glass.rgb * (0.135 + fresnel * 0.09) + sky * (0.025 + sheen * 0.12)
		+ room_gold.rgb * (room_reflection * 0.27 + lamp_glint * 0.23) + vec3(0.92, 0.88, 0.76) * mark * 0.12;
	ROUGHNESS = 0.27;
	SPECULAR = 0.47;
	ALPHA = min(0.41 + fresnel * 0.19 + edge * 0.07 + sheen * 0.06 + room_reflection * 0.10 + mark * 0.19, 0.72);
}
