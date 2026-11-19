shader_type spatial;
render_mode unshaded,cull_back,shadows_disabled,fog_disabled;
#include "res://modules/maze03_final/trial_sky.gdshaderinc"
uniform float air_perspective : hint_range(0.0,0.6)=0.10;
uniform vec3 sun_direction=vec3(-0.4,0.8,-0.5);
uniform float foundation_base=0.0;
uniform float foundation_height=24.0;
varying vec3 model_point;
varying vec3 surface_normal;
varying float foundation_shift;
void vertex(){
	model_point=VERTEX;
	foundation_shift=noise2(VERTEX.xz*0.018)*min(3.5,foundation_height*0.12);
	surface_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec3 ray=-(mat3(INV_VIEW_MATRIX)*VIEW);
	vec3 sky=trial_background(ray);
	float facet=smoothstep(-0.60,0.40,dot(normalize(surface_normal),normalize(sun_direction)));
	vec3 facade=mix(vec3(0.79,0.86,0.93),vec3(0.99,0.99,0.975),facet);
	// Transition is tied to each mesh's real lower edge and follows its movement.
	float irregular=foundation_shift;
	float foundation=1.0-smoothstep(0.25+irregular,foundation_height+irregular,model_point.y-foundation_base);
	float haze=air_perspective+(1.0-air_perspective)*foundation;
	ALBEDO=mix(facade,sky,haze);
}

