shader_type canvas_item;
uniform float strength = 0.65;
uniform float seed = 0.0;
void vertex() {
	float phase = mod(floor(TIME*7.0+seed*0.31),3.0);
	float cell = floor(VERTEX.x/28.0)+floor(VERTEX.y/36.0)*5.0+seed;
	VERTEX += vec2(sin(cell*1.9+phase*2.2)*0.55,cos(cell*1.3+phase*2.1))*strength;
}
