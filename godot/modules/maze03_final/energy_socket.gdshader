shader_type spatial;
uniform float power = 0.0;
void fragment(){
	ALBEDO=vec3(0.22,0.49,0.76);
	ROUGHNESS=0.28;
	SPECULAR=0.32;
	EMISSION=vec3(0.16,0.48,0.95)*(0.60+power*0.55);
}

