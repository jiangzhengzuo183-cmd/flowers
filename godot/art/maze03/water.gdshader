shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;
uniform sampler2D reflection_image : filter_linear;
uniform vec3 water_tint : source_color=vec3(0.50,0.65,0.71);
void fragment(){
	vec2 ripple=vec2(sin(UV.x*79.0+TIME*0.35+sin(UV.y*39.0)),cos(UV.y*83.0-TIME*0.28))*0.0012;
	vec3 reflected=texture(reflection_image,vec2(1.0-SCREEN_UV.x,SCREEN_UV.y)+ripple).rgb;
	float fresnel=pow(1.0-max(dot(NORMAL,VIEW),0.0),3.0);
	ALBEDO=mix(water_tint,reflected,0.59+fresnel*0.23);
	ALPHA=0.89;
}
