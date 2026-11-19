shader_type spatial;
// Local additive halo: works in Compatibility without changing WorldEnvironment.
render_mode unshaded, blend_add, cull_back, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(0.48, 0.83, 0.94, 1.0);
uniform float model_height = 99.6792678833;
uniform float bottom_y = 0.0;
uniform float expansion = 0.004;
uniform float strength = 0.18;
uniform float effect_time = 0.0;
uniform float dissolve = 0.0;
uniform float opacity = 0.58;
varying vec3 p;
varying vec3 glow_normal;

void vertex() {
	p = (VERTEX - vec3(0.0,bottom_y,0.0)) / max(model_height,0.0001);
	vec3 head_normal = normalize((p - vec3(0.0,0.845,0.0))/vec3(0.022,0.026,0.025));
	vec3 smooth_normal = normalize(mix(NORMAL, head_normal, smoothstep(0.70,0.80,p.y)*0.88));
	glow_normal = MODELVIEW_NORMAL_MATRIX * smooth_normal;
	VERTEX += smooth_normal * expansion * model_height;
}

void fragment() {
	float facing = clamp(dot(normalize(glow_normal),normalize(VIEW)),0.0,1.0);
	// Fade to zero at the outer silhouette, avoiding a hard doubled outline.
	float rim = pow(1.0-facing,2.2) * smoothstep(0.0,0.35,facing);
	float fade = smoothstep(0.01,0.30,p.y);
	float disappear = smoothstep(dissolve*1.22-0.12,dissolve*1.22+0.08,p.y*0.83+0.085);
	ALBEDO = glow_color.rgb;
	ALPHA = rim * fade * disappear * strength * (opacity/0.58) * (0.96+sin(effect_time*2.0943951)*0.04);
}
