shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_view : repeat_disable, filter_linear;
uniform sampler2D cue_view : repeat_disable, filter_linear;
uniform float strength : hint_range(0, 1) = 0.0;
uniform float cue_strength : hint_range(0, 1) = 0.0;
uniform float entry_progress : hint_range(0, 1) = 0.0;

// Red-only pixels carry the pickup mask. They are never drawn as color.
float pickup_mask(vec3 cue) {
	return max(cue.r - max(cue.g, cue.b), 0.0);
}

vec3 cue_light(vec3 cue) {
	return cue - vec3(pickup_mask(cue), 0.0, 0.0);
}

void fragment() {
	vec2 center = UV - 0.5;
	float edge = smoothstep(0.23, 0.71, length(center));
	vec3 scene = texture(scene_view, UV).rgb;
	vec3 smeared = scene * 0.52 + texture(scene_view, UV - center * 0.009).rgb * 0.30
		+ texture(scene_view, UV - center * 0.021).rgb * 0.18;
	float luminance = dot(mix(scene, smeared, edge), vec3(0.2126, 0.7152, 0.0722));
	vec3 night = vec3(0.014, 0.034, 0.048) + pow(luminance, 1.26) * vec3(0.21, 0.31, 0.38);
	float breath = 0.94 + 0.06 * sin(TIME * 3.5);
	night *= 1.0 - edge * 0.45;
	night += vec3(0.015, 0.048, 0.075) * edge * breath;

	vec2 pixel = 1.0 / vec2(textureSize(cue_view, 0));
	vec3 cue = texture(cue_view, UV).rgb;
	vec3 glow = vec3(0.0);
	float item = pickup_mask(cue);
	float outline = 0.0;
	float item_glow = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * PI * 0.25;
		vec2 direction = vec2(cos(angle), sin(angle)) * pixel;
		vec3 near_cue = texture(cue_view, UV + direction * 1.45).rgb;
		vec3 far_cue = texture(cue_view, UV + direction * 5.2).rgb;
		glow += cue_light(near_cue) * 0.075 + cue_light(far_cue) * 0.027;
		outline = max(outline, abs(item - pickup_mask(near_cue)));
		item_glow += max(pickup_mask(far_cue) - item, 0.0) * 0.06;
	}
	vec3 item_edge = vec3(0.46, 0.85, 1.0) * (outline * 1.12 + item_glow * 0.50);
	vec3 highlights = cue_light(cue) * 1.18 + glow * breath + item_edge;
	float radius = length(center) * 1.42;
	float convergence = exp(-pow((radius - (1.0 - entry_progress) * 0.86) * 12.0, 2.0))
		* sin(entry_progress * PI) * 0.024;
	vec3 focused = mix(scene, night, strength) + highlights * cue_strength
		+ vec3(0.10, 0.39, 0.60) * convergence;
	COLOR = vec4(focused, 1.0);
}
