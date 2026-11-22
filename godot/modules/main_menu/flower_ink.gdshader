shader_type canvas_item;
#include "res://modules/main_menu/paper_motion.gdshaderinc"
uniform sampler2D tear_mask : filter_linear;
uniform bool tear_enabled=false;
uniform vec2 paper_origin=vec2(0.0);
uniform vec2 paper_size=vec2(1920.0,1080.0);
varying vec2 tear_position;
uniform float progress=0.0;
uniform float seed=0.0;
uniform vec2 flower_size=vec2(120.0);
varying vec2 drawing_uv;
varying vec4 tint;
void vertex() {
	drawing_uv=VERTEX/flower_size;
	tint=COLOR;
	float phase=mod(floor(TIME*7.0+seed),3.0);
	vec2 shift=phase<0.5?vec2(-0.55,0.22):(phase<1.5?vec2(0.45,-0.30):vec2(0.10,0.08));
	VERTEX+=shift;
	if(tear_enabled) VERTEX=paper_attached_vertex(VERTEX,MODEL_MATRIX,paper_origin,paper_size);
	tear_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
	vec2 d=drawing_uv-vec2(0.5);
	float angle=mod(atan(d.y,d.x)+1.57079632679+6.28318530718,6.28318530718)/6.28318530718;
	float brush=1.0-smoothstep(progress*1.14-0.025,progress*1.14+0.025,angle+sin(length(d)*34.0+seed)*0.010);
	float center=1.0-smoothstep(0.075,0.15,length(d));
	brush=mix(brush,smoothstep(0.82,1.0,progress),center);
	if(progress>=0.999) brush=1.0;
	COLOR=texture(TEXTURE,UV)*tint;
	COLOR.a*=brush*smoothstep(0.0,0.035,progress);
	if(tear_enabled) {
		vec2 uv=paper_unmotion(tear_position-paper_origin,paper_size,1.86,1.35)/paper_size;
		COLOR.a*=1.0-texture(tear_mask,uv).g;
	}
}
