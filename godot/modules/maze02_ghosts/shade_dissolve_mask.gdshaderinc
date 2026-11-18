// Added only to duplicated, instance-owned shaders during the farewell effect.
uniform float shade_dissolve_progress = 0.0;
varying vec3 shade_dissolve_position;

float shade_grain_hash(vec3 cell) {
	return fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float shade_grain_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(shade_grain_hash(cell), shade_grain_hash(cell + vec3(1,0,0)), f.x);
	float b = mix(shade_grain_hash(cell + vec3(0,1,0)), shade_grain_hash(cell + vec3(1,1,0)), f.x);
	float c = mix(shade_grain_hash(cell + vec3(0,0,1)), shade_grain_hash(cell + vec3(1,0,1)), f.x);
	float d = mix(shade_grain_hash(cell + vec3(0,1,1)), shade_grain_hash(cell + vec3(1,1,1)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float shade_dissolve_mask(vec3 p) {
	float grain = shade_grain_noise(p * 39.0);
	float order = 0.12 + grain * 0.66 + clamp(p.y, 0.0, 1.0) * 0.10;
	return 1.0 - smoothstep(order - 0.15, order + 0.15, shade_dissolve_progress);
}
