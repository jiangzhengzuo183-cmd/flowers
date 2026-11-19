shader_type canvas_item;
uniform float movement : hint_range(0.0,1.0)=0.0;
uniform float indentation : hint_range(0.0,1.0)=1.0;
uniform float airborne=0.0;
uniform float step_cycle=0.0;
uniform float turn_load=0.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
float paw(vec2 at,vec2 center) {
	vec2 d=(at-center)/vec2(0.022,0.010);
	return exp(-dot(d,d)*1.5);
}
void fragment() {
	float tight=0.0;
	float soft=0.0;
	for(int x=-1;x<=1;x++) {
		for(int y=-1;y<=1;y++) {
			vec2 direction=vec2(float(x),float(y));
			tight+=smoothstep(0.035,0.35,texture(TEXTURE,UV+direction*TEXTURE_PIXEL_SIZE*8.0).a);
			soft+=smoothstep(0.035,0.35,texture(TEXTURE,UV+direction*TEXTURE_PIXEL_SIZE*24.0).a);
		}
	}
	tight/=9.0;
	soft/=9.0;
	float stance_a=0.5+0.5*sin(step_cycle);
	float stance_b=1.0-stance_a;
	float feet=(paw(UV,vec2(0.292,0.350))+paw(UV,vec2(0.685,0.622)))*(0.075+stance_a*movement*0.17);
	feet+=(paw(UV,vec2(0.688,0.350))+paw(UV,vec2(0.315,0.622)))*(0.075+stance_b*movement*0.17);
	float weight=0.15+indentation*0.035+movement*0.025+turn_load*0.020;
	float alpha=(tight*weight+soft*0.13)*mix(1.0,0.46,airborne)+feet*(1.0-airborne);
	vec3 shade=vec3(0.36,0.27,0.18);
	COLOR=vec4(shade,clamp(alpha,0.0,0.48))*vertex_tint;
}
