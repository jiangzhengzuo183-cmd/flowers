shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float age = 1.0;
uniform float strength = 0.0;

void fragment() {
	float radius = length(UV - vec2(0.5));
	float front = mix(0.045, 0.46, age);
	float main = 1.0 - smoothstep(0.012, 0.028, abs(radius - front));
	float tail = (1.0 - smoothstep(0.008, 0.022, abs(radius - front * 0.69))) * 0.43;
	float rim = 1.0 - smoothstep(0.43, 0.50, radius);
	ALBEDO = vec3(0.84, 0.94, 0.86);
	ALPHA = (main + tail) * rim * (1.0 - age) * strength;
}
