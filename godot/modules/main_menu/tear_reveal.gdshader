shader_type canvas_item;
render_mode unshaded;
#include "res://modules/main_menu/paper_motion.gdshaderinc"
uniform sampler2D tear_mask : filter_linear;
uniform sampler2D notes : source_color,filter_linear;
uniform vec2 canvas_size=vec2(1920.0,1080.0);
uniform bool notes_ready=false;
uniform vec2 front_quad[4];
uniform vec2 lower_quads[12];
float side(vec2 p,vec2 a,vec2 b) {
	vec2 edge=b-a;
	return smoothstep(-0.00045,0.00045,(edge.x*(p.y-a.y)-edge.y*(p.x-a.x))/length(edge));
}
float front_cover(vec2 p) {
	return side(p,front_quad[0],front_quad[1])*side(p,front_quad[1],front_quad[2])*side(p,front_quad[2],front_quad[3])*side(p,front_quad[3],front_quad[0]);
}
float lower_cover(vec2 p) {
	float coverage=0.0;
	for(int layer=0;layer<3;layer++) {
		float phase=layer==0?2.72:(layer==1?0.0:0.93);
		float amount=layer==0?1.90:(layer==1?1.70:2.15);
		vec2 a=paper_motion(lower_quads[layer*4]*canvas_size,canvas_size,phase,amount)/canvas_size;
		vec2 b=paper_motion(lower_quads[layer*4+1]*canvas_size,canvas_size,phase,amount)/canvas_size;
		vec2 c=paper_motion(lower_quads[layer*4+2]*canvas_size,canvas_size,phase,amount)/canvas_size;
		vec2 d=paper_motion(lower_quads[layer*4+3]*canvas_size,canvas_size,phase,amount)/canvas_size;
		coverage=max(coverage,side(p,a,b)*side(p,b,c)*side(p,c,d)*side(p,d,a));
	}
	return coverage;
}
void vertex() {
	VERTEX=paper_motion(VERTEX,canvas_size,1.86,1.35);
}
void fragment() {
	vec2 mask=texture(tear_mask,UV).rg;
	if(mask.r<0.001) discard;
	vec2 on_page=paper_motion(UV*canvas_size,canvas_size,1.86,1.35);
	vec2 below=paper_unmotion(on_page,canvas_size,0.93,2.15)/canvas_size;
	vec3 lower_paper=notes_ready?texture(notes,below).rgb:vec3(0.96,0.93,0.87);
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
	float surface=front_cover(UV);
	float under=lower_cover(on_page/canvas_size);
	COLOR=vec4(mix(torn_edge,lower_paper,inside),mask.r*surface*mix(1.0,under,inside));
}
