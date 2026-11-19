shader_type canvas_item;
uniform float movement : hint_range(0.0, 1.0) = 0.0;
uniform float indentation : hint_range(0.0, 1.0) = 1.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 3.0;
	float alpha = texture(TEXTURE, UV).a;
	float soft = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			soft += texture(TEXTURE, UV + vec2(float(x), float(y)) * step_uv).a;
		}
	}
	soft /= 9.0;
	float rim = max(soft - alpha * 0.3, 0.0);
	float upper = texture(TEXTURE, UV + step_uv).a;
	float lower = texture(TEXTURE, UV - step_uv).a;
	float tiny_light = max(upper - lower, 0.0) * indentation;
	vec3 tone = mix(vec3(0.38, 0.29, 0.20), vec3(1.0, 0.98, 0.91), tiny_light);
	COLOR = vec4(tone, rim * (0.20 + indentation * 0.04)) * vertex_tint;
}
