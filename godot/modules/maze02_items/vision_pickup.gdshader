shader_type spatial;
render_mode unshaded, fog_disabled;

void fragment() {
	// The vision compositor turns this mask into a blue silhouette edge.
	ALBEDO = vec3(1.0, 0.0, 0.0);
}
