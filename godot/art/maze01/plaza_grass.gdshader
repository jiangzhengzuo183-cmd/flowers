shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 turf : source_color = vec4(0.51, 0.62, 0.37, 1.0);
uniform vec4 fresh : source_color = vec4(0.67, 0.74, 0.45, 1.0);
varying vec2 ground;
varying vec2 meadow_local;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	meadow_local = VERTEX.xz;
}

float hash_grass(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float grass_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 w = fract(p);
	w = w * w * (3.0 - 2.0 * w);
	return mix(mix(hash_grass(cell), hash_grass(cell + vec2(1,0)), w.x),
		mix(hash_grass(cell + vec2(0,1)), hash_grass(cell + vec2(1,1)), w.x), w.y);
}

void fragment() {
	vec2 p = meadow_local;
	float fields = grass_noise(ground * 2.7);
	float wild_edge = (grass_noise(ground * 3.4) - 0.5) * 0.32
		+ (grass_noise(ground * 9.1) - 0.5) * 0.10;
	float core = 3.40 - max(abs(p.x), abs(p.y));
	float north = (1.0 - length((p - vec2(0.09,-3.41)) / vec2(0.76,0.97))) * 0.59;
	float west = (1.0 - length((p - vec2(-3.41,2.23)) / vec2(0.94,0.72))) * 0.57;
	float edge = smoothstep(-0.055,0.24,max(core,max(north,west))+wild_edge);
	vec2 tuft = ground * vec2(23.0, 15.0);
	float texture_grain = grass_noise(tuft) * 0.54 + grass_noise(tuft * 1.83 + 11.0) * 0.46;
	float shade = clamp(0.20 + fields * 0.52 + (texture_grain - 0.5) * 0.46, 0.0, 1.0);
	ALBEDO = mix(turf.rgb, fresh.rgb, shade);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
	ALPHA = edge * (0.88 + fields * 0.10);
}
