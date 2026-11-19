shader_type canvas_item;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	ink.a = min(1.0, ink.a * 1.35);
	COLOR = ink * vertex_tint;
}
