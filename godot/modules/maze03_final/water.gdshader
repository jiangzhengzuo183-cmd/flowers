shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D reflection_image : filter_linear, repeat_disable;
uniform mat4 reflection_view_projection;
uniform bool reflection_ready = false;
uniform vec4 step_ripples[4];
uniform vec3 water_color : source_color = vec3(0.50, 0.65, 0.71);
varying vec3 water_world;

void vertex() {
	water_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 corner=max(abs(water_world.xz-vec2(24.0,22.8))-vec2(7.55),vec2(0.0));
	// The rectangular carrier is clipped to the actual rounded basin, under the thin wall.
	if(length(corner)>0.85) discard;
	vec4 projected = reflection_view_projection * vec4(water_world, 1.0);
	vec2 reflection_uv = projected.xy / max(projected.w, 0.001) * 0.5 + 0.5;
	reflection_uv.y = 1.0 - reflection_uv.y;
	vec2 ripple = vec2(sin(water_world.z * 2.8 + TIME * 0.55), cos(water_world.x * 3.4 - TIME * 0.42)) * 0.00065;
	float footsteps = 0.0;
	vec2 disturbance = vec2(0.0);
	for(int i=0;i<4;i++) {
		vec4 hit=step_ripples[i];
		vec2 delta=water_world.xz-hit.xy;
		float d=length(delta);
		float age=hit.z;
		float ring=exp(-pow((d-age*1.05)*20.0,2.0));
		float inner=exp(-pow((d-age*0.65)*25.0,2.0))*0.55;
		float fade=max(0.0,1.0-age/0.95)*hit.w*smoothstep(0.0,0.06,age);
		footsteps+=(ring+inner)*fade;
		disturbance+=delta/max(d,0.03)*ring*fade*0.0018;
	}
	ripple+=disturbance;
	vec3 reflected = texture(reflection_image, clamp(reflection_uv + ripple, vec2(0.001), vec2(0.999))).rgb;
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.0);
	float reflection_strength = mix(0.59, 0.82, fresnel);
	ALBEDO = reflection_ready ? mix(water_color, reflected, reflection_strength) : water_color;
	float light_ripple = pow(0.5 + 0.5 * sin(water_world.x * 4.0 + water_world.z * 2.2 - TIME * 0.6), 32.0);
	ALBEDO += vec3(0.01, 0.014, 0.016) * light_ripple;
	ALBEDO += vec3(0.24,0.31,0.34)*footsteps;
	float bank_distance=min(min(abs(water_world.x-15.6),abs(water_world.x-32.4)),min(abs(water_world.z-14.4),abs(water_world.z-31.2)));
	float waterline=1.0-smoothstep(0.015,0.085,bank_distance);
	ALBEDO=mix(ALBEDO,water_color*0.72,waterline*0.28);
	ALPHA = 0.89;
}


