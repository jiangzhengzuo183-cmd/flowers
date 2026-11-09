shader_type spatial;

uniform sampler2D carved_detail : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 limestone : source_color = vec4(0.91, 0.84, 0.76, 1.0);

void fragment() {
	vec3 baked = texture(carved_detail, UV).rgb;
	float tone = dot(baked, vec3(0.2126, 0.7152, 0.0722));
	// Leave the globe engravings and sculpted folds visible under the level's light.
	float relief = mix(0.77, 1.035, smoothstep(0.06, 0.79, tone));
	ALBEDO = limestone.rgb * relief;
	ROUGHNESS = 0.87;
	SPECULAR = 0.18;
}
