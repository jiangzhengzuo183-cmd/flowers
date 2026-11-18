shader_type spatial;
render_mode cull_disabled;
uniform vec4 stone_color : source_color = vec4(0.91,0.91,0.90,1.0);
uniform bool legacy_winding=false;
uniform sampler2D grain : filter_linear_mipmap,repeat_enable;
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	if(legacy_winding && !FRONT_FACING) NORMAL=-NORMAL;
	vec3 w=pow(abs(world_normal),vec3(4.0));w/=max(w.x+w.y+w.z,0.001);
	vec3 p=world_point*1.4;
	vec3 detail=texture(grain,p.yz).rgb*w.x+texture(grain,p.xz).rgb*w.y+texture(grain,p.xy).rgb*w.z;
	ALBEDO=stone_color.rgb;
	ROUGHNESS=0.90;
	SPECULAR=0.18;
	vec3 relief=mat3(VIEW_MATRIX)*vec3(detail.rg*2.0-1.0,0.0);
	NORMAL=normalize(NORMAL+relief*0.035);
	EMISSION=stone_color.rgb*vec3(0.025,0.035,0.048);
}
