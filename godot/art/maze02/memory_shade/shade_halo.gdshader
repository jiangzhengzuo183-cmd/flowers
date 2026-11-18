shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
#include "shade_motion.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(0.51, 0.81, 0.98, 1.0);
uniform float expansion = 0.005;
uniform float strength = 0.22;

void vertex() {
	VERTEX += shade_offset(VERTEX, UV2);
	VERTEX += NORMAL * expansion;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.0) * smoothstep(0.0, 0.28, facing);
	float breath = 1.0 + sin(effect_time * 1.14) * 0.025;
	ALBEDO = glow_color.rgb;
	ALPHA = edge * strength * breath;
}
