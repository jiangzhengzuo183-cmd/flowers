shader_type spatial;

#include "res://art/maze02/environment/memory_plaster.gdshaderinc"

uniform vec4 stone_color : source_color;
uniform float exposed = 0.0;
uniform bool fissure = false;
uniform float foot_shade = 0.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 local_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_position = VERTEX;
}

void fragment() {
	vec2 p = stone_plane(world_position, world_normal);
	float wear = stone_grit(p, exposed) - foot_shade * (1.0 - smoothstep(0.06, 0.56, local_position.y));
	if (fissure) {
		float h = local_position.y;
		float path = -0.14 - h * 0.48 + (powder_noise(vec2(h * 7.1, 1.25)) - 0.5) * 0.14;
		float line = abs(local_position.x - path);
		float pixel = max(fwidth(line), 0.001);
		float edge = 1.0 - smoothstep(0.003, 0.005 + pixel, line);
		wear -= edge * smoothstep(0.45, 0.68, h) * (1.0 - smoothstep(1.3, 1.53, h)) * 0.19;
	}
	ALBEDO = stone_color.rgb * (1.0 + wear);
	ROUGHNESS = 0.88 + exposed * 0.10;
	SPECULAR = 0.19;
}
