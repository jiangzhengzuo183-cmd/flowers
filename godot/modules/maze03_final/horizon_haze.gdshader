shader_type spatial;
render_mode unshaded,cull_back,shadows_disabled,fog_disabled;
#include "res://modules/maze03_final/trial_sky.gdshaderinc"
uniform vec4 mist : source_color=vec4(0.91,0.94,0.96,1.0);
uniform vec4 shade : source_color=vec4(0.70,0.77,0.83,1.0);
uniform vec4 amber : source_color=vec4(1.0,0.95,0.85,1.0);
uniform float clarity=0.52;
uniform bool windows=false;
uniform vec3 sun_direction=vec3(-0.4,0.8,-0.5);
varying float altitude;
varying vec3 face;
void vertex(){altitude=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;face=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
	float bank=smoothstep(-18.0,16.0,altitude);
	float distance_fade=1.0-smoothstep(260.0,430.0,length(VERTEX.xz))*0.10;
	float facet=dot(normalize(face),normalize(sun_direction));
	vec3 view_ray=-(mat3(INV_VIEW_MATRIX)*VIEW);
	vec3 haze=trial_background(view_ray);
	vec3 facade=windows?amber.rgb:mix(shade.rgb,mist.rgb,smoothstep(0.02,0.48,facet));
	float contrast=bank*distance_fade*clarity;
	ALBEDO=mix(haze,facade,contrast);
	if(windows) ALBEDO+=vec3(0.08,0.07,0.045)*bank*distance_fade;
}


