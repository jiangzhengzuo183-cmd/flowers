shader_type spatial;
render_mode cull_disabled;
#include "res://art/maze01/plaster_bands.gdshaderinc"
uniform vec4 finish_color : source_color = vec4(0.6,0.7,0.7,1.0);
uniform vec4 finish_side_color : source_color = vec4(0.6,0.7,0.7,1.0);
uniform float finish_roughness = 0.8;
uniform bool legacy_winding = true;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
uniform bool limestone = false;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap, repeat_enable;
uniform float wall_half_height = 0.0;
uniform float waterline = -100.0;
uniform bool pool_entry_stone = false;
uniform int weathering_axis = 0;
uniform vec3 room_floor = vec3(0.0);
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 mesh_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	mesh_position = VERTEX;
}

void fragment() {
	// Original prism normals point outward, but its legacy front winding is
	// reversed. Undo only the automatic back-face lighting flip, without
	// changing a single mesh vertex, triangle or collision shape.
	if (legacy_winding && !FRONT_FACING) { NORMAL = -NORMAL; }
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 p = world_position * 1.4;
	float texture_grain = texture(grain, p.yz).r * weights.x
		+ texture(grain, p.xz).r * weights.y + texture(grain, p.xy).r * weights.z;
	float up = abs(normalize(world_normal).y);
	vec3 tint = mix(finish_side_color.rgb, finish_color.rgb, smoothstep(0.12, 0.62, up));
	ALBEDO = tint * (1.0 + (texture_grain - 0.5) * (limestone ? 0.0 : 0.04));
	if (wall_half_height > 0.0) {
		ALBEDO *= stone_course(mesh_position, wall_half_height, up);
	}
	ROUGHNESS = finish_roughness;
	SPECULAR = 0.30;
	if (limestone) {
		vec2 uv = world_position.xz * 0.34;
		float surface = smoothstep(0.20, 0.66, up);
		// Keep a clean color field. The texture only appears as subtle grain
		// and a soft change in sheen at grazing angles.
		ROUGHNESS = mix(finish_roughness, texture(stone_roughness, uv).r, surface * 0.29);
		vec2 slope = texture(stone_normal, uv).rg * 2.0 - 1.0;
		vec3 relief = mat3(VIEW_MATRIX) * vec3(slope.x, 0.0, -slope.y);
		NORMAL = normalize(NORMAL + relief * (surface * 0.076));
		float damp = 1.0 - smoothstep(0.015, 0.18, abs(world_position.y - waterline));
		ALBEDO *= mix(vec3(1.0), vec3(0.86, 0.93, 0.93), damp * 0.66);
	}
	// The southwest stair and its upper landing share one continuous stone finish.
	if (pool_entry_stone && world_position.x < 2.402 && world_position.z >= 11.998
		&& world_position.z <= 14.402) {
		ALBEDO = vec3(0.69, 0.693, 0.682) * (0.92 + texture_grain * 0.084);
		ROUGHNESS = 0.91;
		SPECULAR = 0.21;
	}
	if (weathering_axis != 0 && up < 0.22) {
		vec2 face = vec2(weathering_axis == 2 ? mesh_position.z : mesh_position.x,mesh_position.y);
		float broad_face = weathering_axis == 2 ? abs(world_normal.x) : abs(world_normal.z);
		float aa = max(0.004,fwidth(face.x)+fwidth(face.y));
		float patch_a = length(vec2((face.x+0.71)*4.8,(face.y+0.40+face.x*0.25)*6.5));
		float patch_b = length(vec2((face.x+0.52)*7.1,(face.y+0.26)*11.3));
		float ragged = 0.11*sin(face.x*49.0+face.y*27.0) + (texture_grain-0.5)*0.16;
		float flake = 1.0 - smoothstep(0.54,1.19,min(patch_a,patch_b)+ragged);
		float split = (1.0-smoothstep(0.006,0.018+aa,abs(face.x+0.69+0.31*face.y+0.026*sin(face.y*31.0))))
			* (1.0-smoothstep(0.12,0.29,abs(face.y+0.26)));
		ALBEDO *= 1.0 - broad_face*(flake*0.092+split*0.13);
	}
	if (room_floor.z > 0.0) {
		float at_wall = smoothstep(room_floor.z - 0.47, room_floor.z, length(world_position.xz - room_floor.xy));
		ALBEDO *= 1.0 - 0.065 * at_wall;
	}
}
