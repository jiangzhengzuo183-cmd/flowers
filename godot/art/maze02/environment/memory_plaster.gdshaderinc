float stone_course(vec3 local_point, float half_height, float top_face) {
	float top = half_height - local_point.y;
	float bottom = local_point.y + half_height;
	float side = 1.0 - smoothstep(0.15, 0.72, top_face);
	float cap = 1.0 - smoothstep(0.052, 0.085, top);
	float lip = smoothstep(0.070, 0.089, top) * (1.0 - smoothstep(0.096, 0.119, top));
	float base = 1.0 - smoothstep(0.065, 0.31, bottom);
	return 1.0 + side * (cap * 0.04 - lip * 0.026 - base * 0.16);
}

float powder_hash(vec2 point) {
	vec3 p = fract(vec3(point.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float powder_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(point));
	return mix(mix(powder_hash(cell), powder_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(powder_hash(cell + vec2(0.0, 1.0)), powder_hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

vec2 stone_plane(vec3 position, vec3 normal) {
	if (abs(normal.y) > 0.55) { return position.xz; }
	vec2 tangent = normalize(vec2(-normal.z, normal.x));
	return vec2(dot(position.xz, tangent), position.y);
}

float stone_grit(vec2 p, float exposed) {
	float bed = powder_noise(p * vec2(3.4, 7.8));
	float aggregate = powder_noise(p * vec2(51.0, 45.0));
	float grain = powder_noise(p * 148.0);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float resolve_aggregate = 1.0 - smoothstep(0.006, 0.025, footprint);
	float resolve_grain = 1.0 - smoothstep(0.002, 0.010, footprint);
	float pits = smoothstep(0.65, 0.96, aggregate);
	return (bed - 0.52) * (0.055 + exposed * 0.04)
		- pits * (0.046 + exposed * 0.098) * resolve_aggregate
		+ (grain - 0.5) * 0.035 * resolve_grain;
}

float plaster_grit(vec3 position, vec3 normal, vec3 local_point, float half_height) {
	vec2 plane = stone_plane(position, normal);
	float gathering = mix(0.37, 0.92, powder_noise(plane * vec2(1.0, 1.4)));
	if (half_height > 0.0) {
		float height_from_floor = half_height + local_point.y;
		gathering = max(gathering, 0.70 * (1.0 - smoothstep(0.12, 0.75, height_from_floor)));
	}
	float grit = stone_grit(plane, 0.18) * gathering * 0.83;
	if (half_height > 0.0 && abs(normal.y) < 0.8) {
		float lane = plane.x / 1.24;
		float seed = powder_hash(vec2(floor(lane), floor(position.y - local_point.y + 0.1)));
		float from_edge = half_height - abs(local_point.y);
		float center = mix(0.05, 0.21, seed);
		vec2 chip = vec2((fract(lane) - 0.22 - seed * 0.55) * 14.2, (from_edge - center) * 19.0);
		float cut = length(chip * vec2(0.90, 1.3)) + powder_noise(plane * 33.0) * 0.27;
		float pixel = max(fwidth(cut), 0.035);
		float rim = 1.0 - smoothstep(0.79, 0.84 + pixel, cut);
		float hollow = 1.0 - smoothstep(0.62, 0.71 + pixel, cut + chip.y * 0.14);
		grit += (rim * 0.024 - hollow * 0.105) * (1.0 - smoothstep(0.3, 1.4, pixel));
	}
	return grit;
}
