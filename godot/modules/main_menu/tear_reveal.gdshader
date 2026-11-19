shader_type canvas_item;
render_mode unshaded;
#include "res://modules/main_menu/paper_motion.gdshaderinc"
uniform sampler2D tear_mask : filter_linear;
uniform sampler2D notes : source_color,filter_linear;
uniform vec2 canvas_size=vec2(1920.0,1080.0);
void vertex() {
	VERTEX=paper_motion(VERTEX,canvas_size,1.86,1.35);
}
void fragment() {
	vec2 mask=texture(tear_mask,UV).rg;
	vec2 on_page=paper_motion(UV*canvas_size,canvas_size,1.86,1.35);
	vec2 below=paper_unmotion(on_page,canvas_size,0.93,2.15)/canvas_size;
	vec3 lower_paper=texture(notes,below).rgb;
	vec2 pixel=1.0/vec2(1920.0,1080.0);
	// The upper-left cut edge casts its shadow INSIDE the opening, onto the lower sheet.
	float cast=0.0;
	cast+=(1.0-texture(tear_mask,UV-vec2(1.8,2.6)*pixel).g)*0.10;
	cast+=(1.0-texture(tear_mask,UV-vec2(4.0,5.5)*pixel).g)*0.10;
	cast+=(1.0-texture(tear_mask,UV-vec2(6.5,8.5)*pixel).g)*0.055;
	float around=texture(tear_mask,UV+vec2(1.2,0.0)*pixel).g+texture(tear_mask,UV-vec2(1.2,0.0)*pixel).g;
	around+=texture(tear_mask,UV+vec2(0.0,1.2)*pixel).g+texture(tear_mask,UV-vec2(0.0,1.2)*pixel).g;
	float contact=(1.0-around*0.25)*0.18;
	lower_paper*=1.0-(cast+contact)*mask.g;
	float inside=clamp(mask.g/max(mask.r,0.0001),0.0,1.0);
	float fibers=fract(sin(dot(floor(UV*vec2(1920.0,1080.0)),vec2(12.9898,78.233)))*43758.5453);
	vec3 torn_edge=mix(vec3(0.982,0.966,0.918),vec3(1.0,0.995,0.958),0.25+fibers*0.60);
	COLOR=vec4(mix(torn_edge,lower_paper,inside),mask.r);
}
