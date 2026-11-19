shader_type canvas_item;
uniform sampler2D clean_paper : source_color,filter_linear_mipmap;
uniform vec2 corner_a=vec2(0.035,0.034);
uniform vec2 corner_b=vec2(0.968,0.032);
uniform vec2 corner_c=vec2(0.967,0.956);
uniform vec2 corner_d=vec2(0.035,0.958);
uniform vec2 paper_size=vec2(1920.0,1080.0);
uniform float phase=0.0;
uniform float amount=1.0;
varying vec4 tint;
float half_plane(vec2 p,vec2 a,vec2 b) {
	vec2 edge=b-a;
	return smoothstep(-0.00035,0.00035,(edge.x*(p.y-a.y)-edge.y*(p.x-a.x))/length(edge));
}
void vertex() {
	tint=COLOR;
	float frame=mod(floor(TIME*7.0+phase),3.0);
	vec2 shift=frame<0.5?vec2(-0.6,0.22):(frame<1.5?vec2(0.48,-0.30):vec2(0.12,0.08));
	float turn=sin(frame*2.1+phase)*0.00017*amount;
	vec2 d=VERTEX-paper_size*0.5;
	VERTEX=paper_size*0.5+vec2(d.x*cos(turn)-d.y*sin(turn),d.x*sin(turn)+d.y*cos(turn))+shift*amount;
}
void fragment() {
	vec4 original=texture(TEXTURE,UV);
	vec4 clean=texture(clean_paper,UV);
	float interior=smoothstep(0.38,0.58,UV.x)*(1.0-smoothstep(0.945,0.965,UV.x));
	interior*=smoothstep(0.039,0.062,UV.y)*(1.0-smoothstep(0.935,0.956,UV.y));
	float mask=half_plane(UV,corner_a,corner_b)*half_plane(UV,corner_b,corner_c)*half_plane(UV,corner_c,corner_d)*half_plane(UV,corner_d,corner_a);
	COLOR=mix(original,clean,interior)*tint;
	COLOR.a*=mask;
}
