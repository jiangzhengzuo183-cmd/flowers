shader_type spatial;
render_mode cull_disabled;
uniform vec4 stone_color : source_color = vec4(0.73,0.80,0.83,1.0);
uniform float relief = 0.025;
uniform float pattern_enabled = 0.0;
uniform float pattern_front = 5.0;
uniform float pattern_center_x = 0.0;
uniform float pattern_center_y = 36.0;
varying vec3 local_point;
varying vec3 world_point;
varying vec3 local_normal;
void vertex(){local_point=VERTEX;local_normal=NORMAL;world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float segment(vec2 p,vec2 a,vec2 b){vec2 ab=b-a;return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.001),0.0,1.0));}
void fragment(){
	float grain=sin(world_point.x*31.0+world_point.z*19.0)*sin(world_point.y*29.0+world_point.z*7.0);
	float foot=0.90+0.10*smoothstep(-5.0,36.0,local_point.y);
	ALBEDO=stone_color.rgb*foot*(1.0+grain*relief*0.35);
	ROUGHNESS=0.82+grain*0.025;
	SPECULAR=0.22;
	if(pattern_enabled>0.5 && local_normal.z>0.8 && abs(local_point.z-pattern_front)<0.7){
		vec2 p=local_point.xy-vec2(pattern_center_x,pattern_center_y);
		float d=segment(p,vec2(-1.7,-15),vec2(-1.7,13));
		d=min(d,segment(p,vec2(-1.7,13),vec2(3.2,13)));
		d=min(d,segment(p,vec2(3.2,13),vec2(3.2,4.0)));
		d=min(d,segment(p,vec2(3.2,4.0),vec2(0.4,4.0)));
		d=min(d,segment(p,vec2(0.4,4.0),vec2(0.4,-6.5)));
		d=min(d,segment(p,vec2(0.4,-6.5),vec2(3.8,-6.5)));
		float groove=1.0-smoothstep(0.58,0.74,d);
		float core=1.0-smoothstep(0.31,0.48,d);
		float moving=pow(0.5+0.5*sin(local_point.y*0.13-TIME*0.52),6.0);
		ALBEDO=mix(ALBEDO,stone_color.rgb*0.62,groove*0.68);
		ALBEDO=mix(ALBEDO,vec3(0.30,0.66,0.85),core*0.90);
		EMISSION=vec3(0.15,0.51,0.78)*core*(0.52+moving*0.72);
	}
}
