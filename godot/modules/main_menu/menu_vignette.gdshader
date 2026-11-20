shader_type canvas_item;
render_mode unshaded;
uniform float strength : hint_range(0.0,0.4)=0.22;
void fragment() {
	vec2 from_center=(UV-vec2(0.5))*2.0;
	float distance_from_center=length(from_center*vec2(0.88,0.75));
	float edge=smoothstep(0.46,0.92,distance_from_center);
	COLOR=vec4(0.0,0.0,0.0,edge*strength);
}
