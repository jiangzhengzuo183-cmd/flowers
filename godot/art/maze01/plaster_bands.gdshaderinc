float stone_course(vec3 local_point, float half_height, float top_face) {
	float top = half_height - local_point.y;
	float bottom = local_point.y + half_height;
	float side = 1.0 - smoothstep(0.15, 0.72, top_face);
	float cap = 1.0 - smoothstep(0.052, 0.085, top);
	float lip = smoothstep(0.070, 0.089, top) * (1.0 - smoothstep(0.096, 0.119, top));
	float base = 1.0 - smoothstep(0.065, 0.31, bottom);
	return 1.0 + side * (cap * 0.04 - lip * 0.026 - base * 0.16);
}
