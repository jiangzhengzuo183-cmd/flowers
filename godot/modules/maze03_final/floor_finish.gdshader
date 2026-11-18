shader_type spatial;
render_mode cull_disabled;
uniform vec4 floor_color : source_color = vec4(0.78,0.75,0.70,1.0);
uniform sampler2D wall_contact : filter_linear, repeat_disable;
uniform sampler2D grain : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap, repeat_enable;
uniform bool legacy_winding=false;
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	if(legacy_winding && !FRONT_FACING) NORMAL=-NORMAL;
	float up=abs(world_normal.y);
	vec2 uv=world_point.xz*0.34;
	vec3 grain_normal=texture(grain,uv).rgb;
	float contact=texture(wall_contact,(world_point.xz+vec2(0.7))/47.0).r;
	ALBEDO=floor_color.rgb*mix(1.0,contact,smoothstep(0.60,0.95,up));
	ROUGHNESS=mix(0.88,texture(stone_roughness,uv).r,0.25);
	SPECULAR=0.20;
	vec2 slope=grain_normal.rg*2.0-1.0;
	vec3 relief=mat3(VIEW_MATRIX)*vec3(slope.x,0,-slope.y);
	NORMAL=normalize(NORMAL+relief*0.058*smoothstep(0.6,0.95,up));
}
