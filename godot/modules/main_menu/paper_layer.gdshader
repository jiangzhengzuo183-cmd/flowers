shader_type canvas_item;
#include "res://modules/main_menu/paper_motion.gdshaderinc"
uniform vec2 corner_a=vec2(0.0);
uniform vec2 corner_b=vec2(1.0,0.0);
uniform vec2 corner_c=vec2(1.0);
uniform vec2 corner_d=vec2(0.0,1.0);
uniform vec2 paper_size=vec2(1920.0,1080.0);
uniform vec2 art_scale=vec2(1.0);
uniform vec2 art_offset=vec2(0.0);
uniform float rest_angle=0.0;
uniform bool paper_tone=false;
uniform vec4 paper_color : source_color=vec4(1.0);
uniform bool shadow_only=false;
uniform vec2 shadow_offset=vec2(1.2,3.2);
uniform float shadow_blur=3.5;
uniform float shadow_strength=0.20;
uniform float phase=0.0;
uniform float amount=1.0;
varying vec4 tint;
float half_plane(vec2 p,vec2 a,vec2 b) {
	vec2 edge=b-a;
	return smoothstep(-0.00035,0.00035,(edge.x*(p.y-a.y)-edge.y*(p.x-a.x))/length(edge));
}
void vertex() {
	tint=COLOR;
	vec2 placed=paper_rotate((VERTEX-paper_size*0.5)*art_scale,rest_angle)+paper_size*0.5*art_scale+art_offset;
	VERTEX=paper_motion(placed,paper_size,phase,amount);
	if (shadow_only) VERTEX+=shadow_offset;
}
void fragment() {
	float mask=half_plane(UV,corner_a,corner_b)*half_plane(UV,corner_b,corner_c)*half_plane(UV,corner_c,corner_d)*half_plane(UV,corner_d,corner_a);
	vec4 source=texture(TEXTURE,UV);
	COLOR=source*tint;
	if(paper_tone) {
		float grain=clamp(dot(source.rgb,vec3(0.3333))/0.945,0.86,1.04);
		COLOR.rgb=paper_color.rgb*grain*tint.rgb;
	}
	COLOR.a*=mask;
	if (shadow_only) {
		float soft=0.0;
		for(int x=-1;x<=1;x++) {
			for(int y=-1;y<=1;y++) {
				vec2 p=UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE*shadow_blur;
				float inside=half_plane(p,corner_a,corner_b)*half_plane(p,corner_b,corner_c)*half_plane(p,corner_c,corner_d)*half_plane(p,corner_d,corner_a);
				soft+=texture(TEXTURE,p).a*inside;
			}
		}
		COLOR=vec4(0.27,0.18,0.11,soft/9.0*shadow_strength)*tint;
	}
}
