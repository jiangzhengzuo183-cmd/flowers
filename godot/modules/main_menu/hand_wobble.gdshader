shader_type canvas_item;
#include "res://modules/main_menu/paper_motion.gdshaderinc"
uniform sampler2D tear_mask : filter_linear;
uniform bool tear_enabled=false;
uniform vec2 paper_origin=vec2(0.0);
uniform vec2 paper_size=vec2(1920.0,1080.0);
varying vec2 tear_position;
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
	if(tear_enabled) VERTEX=paper_attached_vertex(VERTEX,MODEL_MATRIX,paper_origin,paper_size);
	tear_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}

void fragment() {
	if(tear_enabled) {
		vec2 uv=paper_unmotion(tear_position-paper_origin,paper_size,1.86,1.35)/paper_size;
		COLOR.a*=1.0-texture(tear_mask,uv).g;
	}
}
