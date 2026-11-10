shader_type spatial;
render_mode blend_mix, shadows_disabled, depth_draw_never;

#include "res://art/maze02/environment/memory_plaster.gdshaderinc"

void fragment() {
	vec2 p = UV - 0.5;
	float drift = powder_noise(UV * vec2(5.0, 9.0));
	float fringe = length(p * vec2(1.94, 2.24)) + (drift - 0.5) * 0.27;
	float pile = (1.0 - smoothstep(0.14, 0.52, fringe)) * (0.27 + drift * 0.29);
	float grain = powder_noise(UV * vec2(130.0, 83.0));
	ALBEDO = mix(vec3(0.47, 0.34, 0.20), vec3(0.68, 0.55, 0.35), grain);
	ROUGHNESS = 1.0;
	ALPHA = pile * (0.61 + grain * 0.37);
}
