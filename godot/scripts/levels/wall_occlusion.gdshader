shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 stone_color : source_color = vec4(0.45, 0.49, 0.50, 1.0);
uniform float stone_roughness = 0.9;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	ALBEDO = stone_color.rgb;
	ROUGHNESS = stone_roughness;
	ALPHA = opacity;
}
