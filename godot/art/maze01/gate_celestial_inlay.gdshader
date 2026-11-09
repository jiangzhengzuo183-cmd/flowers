shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform float elapsed = -1.0;
uniform float pulse = 0.0;
uniform float floor_height = 0.0;
varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y < floor_height) {
		discard;
	}
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	float awake = smoothstep(COLOR.r, COLOR.r + 0.09, elapsed);
	float bevel = COLOR.g;
	vec3 dormant = mix(vec3(0.28, 0.46, 0.48), vec3(0.54, 0.69, 0.70), bevel);
	ALBEDO = mix(dormant, vec3(0.35, 0.77, 0.79), awake);
	ROUGHNESS = 0.58;
	SPECULAR = 0.25;
	EMISSION = mix(vec3(0.18, 0.79, 0.83), vec3(0.69, 0.96, 1.0), bevel * 0.68 + pulse * 0.19)
		* awake * (0.53 + pulse * 0.59);
}
