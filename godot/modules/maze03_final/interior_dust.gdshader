shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float h=clamp(10.0-world_point.y,0.0,10.0);
	vec2 axis=vec2(24.0,22.8)+vec2(0.14,0.10)*h;
	float radius=0.25+h*0.12;
	float lit=1.0-smoothstep(radius*0.40,radius,length(world_point.xz-axis));
	ALBEDO=vec3(1.0,0.97,0.87);
	EMISSION=vec3(0.12,0.11,0.08)*lit;
	ALPHA=COLOR.a*lit*0.65;
}

