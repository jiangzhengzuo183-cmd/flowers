shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
#include "res://modules/maze03_final/trial_sky.gdshaderinc"
uniform float air_perspective = 0.12;
uniform vec3 sun_direction = vec3(-0.4,0.8,-0.5);
varying vec3 world_normal;
varying float altitude;
void vertex(){
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	altitude=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;
}
void fragment(){
	vec3 eye_ray=-(mat3(INV_VIEW_MATRIX)*VIEW);
	vec3 normal=normalize(world_normal);
	vec3 reflection=reflect(eye_ray,normal);
	vec3 reflected_sky=trial_background(reflection);
	float fresnel=pow(1.0-clamp(abs(dot(normal,-eye_ray)),0.0,1.0),3.0);
	float sheen=exp(-pow((UV.x*0.7+UV.y*0.15-0.47)*16.0,2.0));
	float sun=pow(max(dot(reflection,normalize(sun_direction)),0.0),96.0);
	// Neutral reflective glazing: most of its colour comes from the actual sky function.
	vec3 surface=mix(vec3(0.77,0.80,0.83),reflected_sky,0.79+fresnel*0.12);
	surface+=vec3(0.15)*sheen+vec3(0.55,0.54,0.51)*sun;
	float haze=max(air_perspective,1.0-smoothstep(-20.0,7.0,altitude));
	ALBEDO=mix(surface,trial_background(eye_ray),haze);
	ALPHA=0.86+fresnel*0.10;
}
