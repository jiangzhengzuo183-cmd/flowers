shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 1.0;
uniform float core_height=1.22;
uniform float energy_pulse=1.0;
varying float world_height;
void vertex(){world_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;}
void fragment() {
	float x=abs(UV.x-0.5)*2.0;
	float distance_from_core=abs(world_height-core_height);
	// The shaft converges into the floating energy core and reopens above it.
	float neck=1.0-0.62*exp(-pow(distance_from_core/0.90,2.0));
	x/=neck;
	float connection=smoothstep(0.34,0.43,distance_from_core);
	float core=exp(-x*x*32.0);
	float halo=pow(max(0.0,1.0-x),3.0);
	float ends=smoothstep(0.0,0.035,UV.y)*(1.0-smoothstep(0.985,1.0,UV.y));
	float shimmer=0.98+0.02*sin(UV.y*7.0-TIME*0.45);
	ALBEDO=mix(vec3(0.24,0.66,0.94),vec3(0.78,0.94,1.0),core);
	EMISSION=vec3(0.18,0.62,0.98)*(core*0.65+halo*0.15);
	ALPHA=(core*0.65+halo*0.14)*ends*strength*shimmer*connection*energy_pulse;
}



