shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float phase=0.0;
uniform float ring_center_y=45.0;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){
	float angle=atan(local_point.y-ring_center_y,local_point.x);
	float travel=pow(0.5+0.5*cos(angle-TIME*0.20+phase),19.0);
	ALBEDO=vec3(0.69,0.86,0.91)*(0.68+travel*0.32);
	EMISSION=vec3(0.43,0.67,0.76)*(0.12+travel*0.35);
}
