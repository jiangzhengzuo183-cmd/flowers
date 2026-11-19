shader_type canvas_item;
uniform vec2 sheet_size = vec2(1920.0,1080.0);
uniform float lift : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec2 p = UV * (sheet_size + vec2(40.0));
	vec2 lo = vec2(20.0,17.0 + lift * 3.0);
	vec2 hi = lo + sheet_size;
	vec2 outside = max(max(lo - p, p - hi), vec2(0.0));
	float distance_out = length(outside);
	float softness = 3.0 + lift * 4.0;
	float shadow = exp(-distance_out * distance_out / (softness * softness * 2.0));
	COLOR = vec4(0.32,0.25,0.17,shadow * (0.12 + lift * 0.04));
}
