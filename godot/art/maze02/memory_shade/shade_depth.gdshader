shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always;
#include "shade_motion.gdshaderinc"

void vertex() {
	VERTEX += shade_offset(VERTEX, UV2);
}

void fragment() {
	// A colorless depth pass hides back surfaces in the original layered hair.
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
