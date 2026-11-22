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
uniform float seed = 0.0;
uniform float settled : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() {
	ink_position=VERTEX;
	vec2 contact_distance=VERTEX-paw_position;
	float contact=exp(-dot(contact_distance,contact_distance)/4900.0)*paw_strength;
	VERTEX.y+=contact*1.6;
	VERTEX.x-=contact_distance.x*contact*0.010;
	vertex_tint = COLOR;
	float frame = mod(floor(TIME * 8.0 + seed * 0.41),3.0);
	vec2 jitter = frame < 0.5 ? vec2(-0.4,0.1) : (frame < 1.5 ? vec2(0.3,-0.25) : vec2(0.1,0.15));
	VERTEX += jitter * settled * 4.5;
	if(tear_enabled) VERTEX=paper_attached_vertex(VERTEX,MODEL_MATRIX,paper_origin,paper_size);
	tear_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}
void fragment() {
	float frame = mod(floor(TIME * 8.0 + seed * 0.41), 3.0);
	vec2 source_pixels = vec2(sin(UV.y * 23.0 + frame * 2.1 + seed), cos(UV.x * 19.0 + frame * 2.4 + seed * 0.7));
	vec2 shift = source_pixels * TEXTURE_PIXEL_SIZE * 0.95 * settled;
	vec4 ink = texture(TEXTURE, UV + shift);
	vec2 d=ink_position-paw_position;
	ink.rgb*=1.0-exp(-dot(d,d)/4900.0)*paw_strength*0.045;
	COLOR = ink * vertex_tint;
	if(tear_enabled) {
		vec2 uv=paper_unmotion(tear_position-paper_origin,paper_size,1.86,1.35)/paper_size;
		COLOR.a*=1.0-texture(tear_mask,uv).g;
	}
}
