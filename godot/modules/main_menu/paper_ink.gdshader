shader_type canvas_item;
uniform sampler2D clean_paper : source_color, filter_linear_mipmap;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
void fragment() {
	vec4 original=texture(TEXTURE,UV);
	vec4 clean=texture(clean_paper,UV);
	float interior=smoothstep(0.38,0.58,UV.x)*(1.0-smoothstep(0.945,0.965,UV.x));
	interior*=smoothstep(0.039,0.062,UV.y)*(1.0-smoothstep(0.935,0.956,UV.y));
	COLOR=mix(original,clean,interior)*vertex_tint;
}
