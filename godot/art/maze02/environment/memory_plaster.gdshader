shader_type spatial;
render_mode cull_disabled;
#include "res://art/maze02/environment/memory_plaster.gdshaderinc"

uniform vec4 finish_color : source_color;
uniform vec4 finish_side_color : source_color;
uniform float finish_roughness = 0.9;
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
	float grain_value = texture(grain, p.yz).r * weights.x
		+ texture(grain, p.xz).r * weights.y + texture(grain, p.xy).r * weights.z;
	float up = abs(normalize(world_normal).y);
	float powder = 0.008 * (grain_value - 0.5);
	if (weather_strength > 0.0) {
		powder += plaster_grit(world_position, world_normal, mesh_position, wall_half_height) * weather_strength;
	}
	vec3 plaster = mix(finish_side_color.rgb, finish_color.rgb, smoothstep(0.12, 0.62, up));
	ALBEDO = plaster * (1.0 + powder) + max(-powder, 0.0) * vec3(0.30, 0.16, 0.0);
	if (wall_half_height > 0.0) {
		ALBEDO *= stone_course(mesh_position, wall_half_height, up);
	}
	ROUGHNESS = clamp(finish_roughness + 0.038 + powder * 1.25, 0.0, 1.0);
	SPECULAR = 0.23;
}
