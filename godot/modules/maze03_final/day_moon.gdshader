shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never,shadows_disabled,fog_disabled;
uniform vec3 moon_light=vec3(1.0,0.0,0.0);
varying vec3 world_normal;
float hash31(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
	vec3 n=normalize(world_normal);
	float illumination=dot(n,normalize(moon_light));
	float day=smoothstep(-0.06,0.42,illumination);
	float limb=smoothstep(0.0,0.12,abs(dot(normalize(NORMAL),normalize(VIEW))));
	float relief=noise3(n*7.0)*0.65+noise3(n*18.0)*0.35;
	ALBEDO=vec3(0.85,0.92,0.98)*(0.94+relief*0.06);
	ALPHA=day*limb*0.57;
}

