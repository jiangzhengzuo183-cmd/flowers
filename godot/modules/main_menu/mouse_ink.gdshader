shader_type canvas_item;
#include "res://modules/main_menu/mouse_tail.gdshaderinc"
#include "res://modules/main_menu/mouse_pawless.gdshaderinc"
uniform float movement=0.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
	float frame = mod(floor(TIME*8.0),3.0);
	vec2 shift = frame<0.5 ? vec2(-0.9,0.35) : (frame<1.5 ? vec2(0.75,-0.5) : vec2(0.15,0.15));
	VERTEX += shift;
}
void fragment() {
	float frame = mod(floor(TIME*8.0),3.0);
	vec2 wobble = vec2(sin(UV.y*28.0+frame*2.3),cos(UV.x*23.0+frame*2.0));
	vec2 at=mouse_tail_uv(UV,movement)+wobble*TEXTURE_PIXEL_SIZE*1.15;
	vec4 ink=mouse_without_paws(texture(TEXTURE,at),at);
	COLOR = ink*vertex_tint;
}
