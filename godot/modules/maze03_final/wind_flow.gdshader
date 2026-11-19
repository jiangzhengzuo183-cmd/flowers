shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 wind_direction = vec3(0.92,0.03,-0.39);
uniform vec3 wind_color = vec3(0.93,0.97,1.0);
uniform float speed = 12.0;
uniform float path_length = 46.0;
uniform float streak_length = 3.8;
uniform float streak_width = 0.035;
uniform float visibility = 0.32;
uniform float flow_gain = 1.0;
varying float life;
void vertex(){
	float age=fract(TIME*speed*UV2.y/path_length+UV2.x);
	float u=UV.x;
	vec3 center=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	center+=wind_direction*((age-0.5)*path_length+(u-0.5)*streak_length);
	vec3 camera_up=normalize(INV_VIEW_MATRIX[1].xyz);
	center+=camera_up*((UV.y-0.5)*streak_width);
	life=smoothstep(0.0,0.13,age)*(1.0-smoothstep(0.78,1.0,age));
	POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(center,1.0);
}
void fragment(){
	float along=pow(sin(UV.x*3.14159),1.5);
	float across=1.0-smoothstep(0.04,0.5,abs(UV.y-0.5));
	ALBEDO=wind_color;
	ALPHA=life*along*across*visibility*flow_gain;
}
