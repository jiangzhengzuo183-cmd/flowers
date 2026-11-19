shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float strength=0.95;
void fragment(){
	float x=abs(UV.x-0.5)*2.0;
	float core=exp(-x*x*38.0);
	float halo=exp(-x*x*5.5);
	float ends=smoothstep(0.0,0.12,UV.y)*(1.0-smoothstep(0.90,1.0,UV.y));
	ALBEDO=mix(vec3(0.72,0.87,0.97),vec3(1.0,1.0,0.99),core);
	EMISSION=vec3(0.18,0.24,0.28)*core;
	ALPHA=(core*0.62+halo*0.12)*ends*strength;
}
