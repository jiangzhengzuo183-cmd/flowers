shader_type canvas_item;
render_mode unshaded;
uniform vec2 paper_size = vec2(980.0,850.0);
uniform float fold_size = 58.0;
varying vec2 paper_position;
void vertex() { paper_position=VERTEX; }
void fragment() {
	float corner=paper_position.x+paper_position.y-(paper_size.x+paper_size.y-fold_size);
	COLOR.a *= 1.0-smoothstep(-0.6,0.6,corner);
}
