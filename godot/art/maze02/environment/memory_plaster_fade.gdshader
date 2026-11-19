shader_type spatial;
render_mode blend_mix, cull_disabled;
#include "res://art/maze02/environment/memory_plaster.gdshaderinc"

uniform vec4 stone_color : source_color;
uniform float stone_roughness = 0.9;
uniform float opacity : hint_range(0, 1) = 1.0;
uniform bool legacy_winding = false;
uniform float wall_half_height = 0.0;
uniform float weather_strength = 0.0;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 mesh_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	mesh_position = VERTEX;
}

void fragment() {
	if (legacy_winding && !FRONT_FACING) { NORMAL = -NORMAL; }
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 p = world_position * 1.4;
	vec3 detail = texture(grain, p.yz).rgb * weights.x
		+ texture(grain, p.xz).rgb * weights.y + texture(grain, p.xy).rgb * weights.z;
	float powder = 0.008 * (detail.r - 0.5);
	if (weather_strength > 0.0) {
		powder += plaster_grit(world_position, world_normal, mesh_position, wall_half_height) * weather_strength;
	}
	ALBEDO = stone_color.rgb * (1.0 + powder) + max(-powder, 0.0) * vec3(0.30, 0.16, 0.0);
	if (wall_half_height > 0.0) {
		ALBEDO *= stone_course(mesh_position, wall_half_height, abs(world_normal.y));
	}
	ROUGHNESS = clamp(stone_roughness + 0.038 + powder * 1.25, 0.0, 1.0);
	SPECULAR = 0.23;
	NORMAL_MAP = detail;
	NORMAL_MAP_DEPTH = 0.12;
	ALPHA = opacity;
}
