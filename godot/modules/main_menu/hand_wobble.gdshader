shader_type canvas_item;
uniform vec2 paw_position=vec2(-10000.0);
uniform float paw_strength=0.0;
varying vec2 ink_position;
uniform float strength = 0.65;
uniform float seed = 0.0;
void vertex() {
	ink_position=VERTEX;
	vec2 contact_distance=VERTEX-paw_position;
	float contact=exp(-dot(contact_distance,contact_distance)/4900.0)*paw_strength;
	VERTEX.y+=contact*1.6;
	VERTEX.x-=contact_distance.x*contact*0.010;
	float phase = mod(floor(TIME*7.0+seed*0.31),3.0);
	float cell = floor(VERTEX.x/28.0)+floor(VERTEX.y/36.0)*5.0+seed;
	VERTEX += vec2(sin(cell*1.9+phase*2.2)*0.55,cos(cell*1.3+phase*2.1))*strength;
}
