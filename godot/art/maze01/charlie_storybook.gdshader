shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D base_color : source_color, filter_linear_mipmap, repeat_enable;
uniform bool charlie_palette = true;
uniform vec4 hair_light : source_color = vec4(0.71, 0.41, 0.30, 1.0);
uniform vec4 hair_shade : source_color = vec4(0.47, 0.255, 0.206, 1.0);
uniform vec4 apron_blue : source_color = vec4(0.19, 0.33, 0.63, 1.0);
uniform vec4 paper_light : source_color = vec4(0.84, 0.78, 0.89, 1.0);
varying vec3 model_point;

void vertex() {
	model_point = VERTEX;
	// Keep the authored silhouette while lighting the hair as a few rounded masses.
	float crown = charlie_palette ? smoothstep(0.68, 0.87, VERTEX.y) : smoothstep(0.74, 0.90, VERTEX.y);
	vec3 head_center = charlie_palette ? vec3(0.005, 0.767, 0.0) : vec3(-0.018, 0.784, 0.0);
	vec3 dome = normalize((VERTEX - head_center) * vec3(0.98, 1.19, 1.10) + vec3(0.0001));
	NORMAL = normalize(mix(NORMAL, dome, crown * 0.62));
}

void fragment() {
	float model_height = model_point.y;
	vec3 fine = texture(base_color, UV, charlie_palette ? 0.0 : 0.42).rgb;
	vec3 broad = texture(base_color, UV, charlie_palette ? 2.30 : 3.15).rgb;
	float edge_delta = length(fine - broad);
	float detail = charlie_palette ? 0.22 + 0.66 * smoothstep(0.11, 0.31, edge_delta)
		: 0.13 + 0.69 * smoothstep(0.14, 0.33, edge_delta);
	vec3 color = mix(broad, fine, detail);
	float tone = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float seams = 1.0 - smoothstep(0.075, 0.45, tone);
	vec3 softened = mix(color, sqrt(max(color, vec3(0.0))), seams * 0.30);
	float warm = smoothstep(0.08, 0.26, color.r - color.b);
	vec3 painted_hair = mix(hair_shade.rgb, hair_light.rgb, smoothstep(0.08, 0.47, tone));
	if (charlie_palette) {
		float blue = smoothstep(0.025, 0.14, color.b - color.r);
		float crown = smoothstep(0.68, 0.77, model_height);
		float hair = crown * warm * (1.0 - smoothstep(0.43, 0.63, tone)) * smoothstep(0.052, 0.14, tone);
		vec3 painted_apron = apron_blue.rgb * mix(0.84, 1.13, smoothstep(0.09, 0.49, tone));
		softened = mix(softened, painted_hair, hair * 0.79);
		softened = mix(softened, painted_apron, blue * 0.70);
		// Temper the hard orange highlights without changing the facial features.
		float fabric = (1.0 - crown) * warm * smoothstep(0.38, 0.79, tone);
		softened = mix(softened, softened * vec3(0.94, 0.94, 1.04), fabric * 0.58);
	} else {
		// Keep the eyes and glasses crisp while grouping the hair and coat into broader color shapes.
		float forehead = smoothstep(0.075, 0.136, model_point.x)
			* (1.0 - smoothstep(0.040, 0.095, abs(model_point.z)))
			* (1.0 - smoothstep(0.82, 0.91, model_height));
		float hair = smoothstep(0.74, 0.84, model_height) * warm * (1.0 - forehead)
			* smoothstep(0.10, 0.26, tone);
		painted_hair = mix(hair_shade.rgb, hair_light.rgb, smoothstep(0.18, 0.68, tone));
		softened = mix(softened, painted_hair, hair * 0.84);

		float chroma = max(max(color.r, color.g), color.b) - min(min(color.r, color.g), color.b);
		float coat = smoothstep(0.28, 0.37, model_height) * (1.0 - smoothstep(0.62, 0.70, model_height))
			* (1.0 - smoothstep(0.07, 0.20, chroma)) * smoothstep(0.26, 0.59, tone);
		vec3 painted_coat = mix(vec3(0.54, 0.51, 0.53), vec3(0.79, 0.75, 0.72), smoothstep(0.28, 0.95, tone));
		softened = mix(softened, painted_coat, coat * 0.84);
	}
	ALBEDO = softened;
	ROUGHNESS = 0.83;
	float grazing = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	EMISSION = softened * (0.09 + 0.13 * seams) + paper_light.rgb * smoothstep(0.48, 0.96, grazing) * 0.035;
}
