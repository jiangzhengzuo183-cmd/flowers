shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
void fragment(){
	float cross_section=exp(-pow((UV.x-0.5)*5.2,2.0));
	float ends=smoothstep(0.0,0.06,UV.y)*(1.0-smoothstep(0.80,1.0,UV.y));
	ALBEDO=vec3(1.0,0.97,0.88);
	ALPHA=cross_section*ends*0.065;
}

