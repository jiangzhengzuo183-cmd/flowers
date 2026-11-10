shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core : source_color = vec4(1.0, 0.98, 0.86, 1.0);
uniform vec4 limb : source_color = vec4(0.94, 0.86, 0.76, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float disc = 1.0 - smoothstep(0.715, 0.754, r);
	float fade = 1.0 - smoothstep(-0.28, 0.44, p.y + p.x * 0.035);
	float halo = (1.0 - smoothstep(0.73, 0.97, r)) * (1.0 - disc) * fade;
	vec3 sphere_normal = vec3(p / 0.74, sqrt(max(0.0, 1.0 - pow(r / 0.74, 2.0))));
	float light = clamp(dot(sphere_normal, normalize(vec3(-0.31,-0.48,0.82))), 0.0, 1.0);
	vec2 basin = (p - vec2(-0.17,-0.19)) * vec2(4.1,3.4);
	vec2 second = (p - vec2(0.16,-0.08)) * vec2(4.9,5.8);
	vec2 third = (p - vec2(-0.32,-0.40)) * vec2(5.9,7.6);
	float maria = exp(-dot(basin,basin))*0.51 + exp(-dot(second,second))*0.36 + exp(-dot(third,third))*0.35;
	ALBEDO = mix(limb.rgb, core.rgb, 0.34 + light * 0.62) * (1.0 - maria * 0.058);
	ALPHA = disc * fade * (0.43 + 0.20 * light) + halo * 0.043;
}
