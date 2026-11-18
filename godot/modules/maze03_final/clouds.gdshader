shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(0.84,0.91,0.97,1.0);
uniform float opacity = 0.65;
uniform float pattern_scale = 0.035;
uniform vec2 drift = vec2(0.008,0.003);
uniform float phase = 0.0;
uniform bool outside_only = true;
uniform bool vertical_bank = false;
varying vec3 world_point;
void vertex(){ world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float hash21(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p){
	vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);
}
void fragment(){
	vec2 p=world_point.xz*pattern_scale+TIME*drift+vec2(phase,phase*2.3);
	if(vertical_bank) p=vec2(UV.x*4.0,UV.y*1.8)+vec2(phase+TIME*0.009,0);
	float broad=noise2(p), detail=noise2(p*2.7+4.2);
	float form=smoothstep(0.17,0.72,broad*0.77+detail*0.23);
	vec2 q=(UV-0.5)*2.0;
	float edge=(1.0-smoothstep(0.58,1.0,abs(q.x)))*(1.0-smoothstep(0.32,1.0,abs(q.y)));
	vec2 from_center=abs(world_point.xz-vec2(23.0));
	float outside=outside_only?smoothstep(25.0,39.0,max(from_center.x,from_center.y)):1.0;
	if(vertical_bank){
		float top=0.20+0.065*sin(UV.x*10.0+phase)+0.04*sin(UV.x*24.0+phase*0.7);
		float profile=smoothstep(top-0.12,top+0.16,UV.y)*(1.0-smoothstep(0.69,1.0,UV.y));
		edge=(1.0-smoothstep(0.60,1.0,abs(q.x)))*profile;
		form=0.64+0.36*form;
	}
	ALBEDO=tint.rgb*mix(0.92,1.06,broad);
	ALPHA=form*edge*outside*opacity;
}
