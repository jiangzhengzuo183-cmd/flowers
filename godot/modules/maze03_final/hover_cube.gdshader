shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never;
uniform float energy_pulse=1.0;
uniform vec3 sun_direction=vec3(-0.4,0.8,0.3);
varying vec3 face_normal;
varying vec3 local_point;
void vertex(){face_normal=MODEL_NORMAL_MATRIX*NORMAL;local_point=VERTEX;}
void fragment(){
	float face=0.75+0.25*smoothstep(-0.2,0.9,dot(normalize(face_normal),normalize(sun_direction)));
	float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	float flow=exp(-pow((local_point.y-fract(TIME*0.12)*0.7+0.35)*22.0,2.0));
	vec3 to_edge=abs(abs(local_point)-vec3(0.21));
	float edge=exp(-min(max(to_edge.x,to_edge.y),min(max(to_edge.y,to_edge.z),max(to_edge.x,to_edge.z)))*180.0);
	vec3 blue=vec3(0.22,0.55,0.86);
	vec3 ice=vec3(0.56,0.81,1.0);
	ALBEDO=mix(blue*face,ice,rim*0.30+flow*0.12);
	EMISSION=vec3(0.18,0.58,0.95)*(0.30+rim*0.18+flow*0.12+edge*0.66)*energy_pulse;
	ALPHA=0.42+rim*0.10+flow*0.06+edge*0.18;
}



