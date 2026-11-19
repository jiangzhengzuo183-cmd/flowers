shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float phase=0.0;
void fragment(){
	float edge=pow(1.0-abs(UV.y-0.5)*2.0,2.8);
	float ends=smoothstep(0.0,0.10,UV.x)*(1.0-smoothstep(0.88,1.0,UV.x));
	float flow=pow(0.5+0.5*sin(UV.x*11.0-TIME*0.28+phase),14.0);
	ALBEDO=vec3(0.53,0.86,1.0);
	EMISSION=vec3(0.25,0.65,1.0)*(0.23+flow*0.72);
	ALPHA=edge*ends*(0.38+flow*0.48);
}
