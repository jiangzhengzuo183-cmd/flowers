shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float pulse = 0.0;
uniform float ripple_age = 10.0;
uniform vec2 contact_uv = vec2(0.5);
uniform vec2 actor_center = vec2(0.0,0.85);
uniform float actor_strength = 0.0;
uniform float push_direction = 1.0;
uniform float recovery_age = 10.0;
uniform sampler2D depth_texture : hint_depth_texture,repeat_disable,filter_nearest;
void vertex(){
	vec2 offset=VERTEX.xy+vec2(0.0,1.22)-actor_center;
	float influence=exp(-dot(offset*vec2(1.4,0.75),offset*vec2(1.4,0.75))*2.5);
	float recover=sin(recovery_age*12.0)*exp(-recovery_age*7.0)*0.035;
	VERTEX.z+=push_direction*influence*(actor_strength*0.15+recover);
}
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec4 honeycomb(vec2 p){
	vec2 spacing=vec2(1.0,1.7320508);
	vec2 a=mod(p,spacing)-spacing*0.5;
	vec2 b=mod(p-spacing*0.5,spacing)-spacing*0.5;
	vec2 local=dot(a,a)<dot(b,b)?a:b;
	return vec4(local,p-local);
}
float border(vec2 p){p=abs(p);return 0.5-max(p.x,dot(p,vec2(0.5,0.8660254)));}
void fragment(){
	vec2 offset=UV*vec2(1.97,2.45)-vec2(0.985,0.0)-actor_center;
	float influence=exp(-dot(offset*vec2(1.4,0.75),offset*vec2(1.4,0.75))*2.0)*actor_strength;
	vec2 warp=offset/max(length(offset),0.05)*influence*0.10/vec2(1.97,2.45);
	vec2 p=(UV-warp)*vec2(4.6,5.72);
	// The actual animated opaque mesh defines the contact contour, not a proxy capsule.
	float scene_depth=textureLod(depth_texture,SCREEN_UV,0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc=vec3(SCREEN_UV,scene_depth)*2.0-1.0;
	#else
	vec3 ndc=vec3(SCREEN_UV*2.0-1.0,scene_depth);
	#endif
	vec4 scene_view=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	float gap=abs((-scene_view.z/scene_view.w)-(-VERTEX.z));
	float contact_edge=(1.0-smoothstep(0.018,0.085,gap))*influence;

	vec4 hex=honeycomb(p);
	vec2 local=hex.xy;
	vec2 cell=hex.zw;
	float d=max(border(local),0.0);
	float line=1.0-smoothstep(0.010,0.025,d);
	float core=1.0-smoothstep(0.002,0.008,d);
	float halo=exp(-d*24.0);
	float seed=hash21(cell);
	// A short glint travels around selected cell edges, instead of flashing the whole pane.
	float angle=atan(local.y,local.x)/6.2831853;
	float head=fract(angle-TIME*0.23-seed);
	float glint=exp(-pow((head-0.5)*20.0,2.0))*smoothstep(0.40,0.75,seed);
	float delay=distance(cell,contact_uv*vec2(4.6,5.72))*0.065;
	float activation=exp(-pow((ripple_age-delay-0.10)/0.23,2.0));
	float fine=exp(-max(border(honeycomb(p*3.0+vec2(0.37,0.12)).xy),0.0)*80.0);
	float sheen=exp(-pow((UV.x-fract(TIME*0.055+0.14))*8.0,2.0));
	vec2 mote=vec2((seed-0.5)*0.60,fract(TIME*0.18+seed)*0.72-0.36);
	float sparkle=exp(-dot(local-mote,local-mote)*3200.0)*smoothstep(0.76,0.94,seed);
	float edge=1.0-smoothstep(0.010,0.045,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
	float brightness=contact_edge*1.20+line*(0.56+glint*1.40+activation*1.40)+core*0.18+halo*0.13+edge*0.32;
	vec3 blue=vec3(0.055,0.29,0.76);
	vec3 ice=vec3(0.56,0.81,1.0);
	ALBEDO=mix(blue,ice,clamp(brightness+sparkle,0.0,1.0));
	EMISSION=vec3(0.62,0.86,1.0)*contact_edge*1.8+vec3(0.025,0.12,0.42)*0.40+vec3(0.10,0.43,1.0)*brightness*1.05+ice*(core*glint*0.55+activation*line*0.70+sparkle*0.65);
	ALPHA=clamp(0.28+seed*0.045+fine*0.045+sheen*0.045+line*0.48+halo*0.10+edge*0.25+activation*0.18+sparkle*0.4+contact_edge*0.45,0.0,0.96);
}



