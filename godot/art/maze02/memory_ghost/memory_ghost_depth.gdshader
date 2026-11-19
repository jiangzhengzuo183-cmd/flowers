shader_type spatial;
// Invisible depth pass keeps overlapping hair surfaces from shining through the face.
// The next material pass supplies the actual translucent appearance.
render_mode unshaded, blend_mix, cull_back, depth_draw_always;

uniform float dissolve = 0.0;
uniform float opacity = 0.58;

void fragment() {
	if (dissolve >= 0.999 || opacity <= 0.0001) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
