extends Node3D
## Reusable prop. Source mesh/material/transform remain unchanged.

const CRT_SHADER := preload("crt_screen.gdshader")
const HALO_SHADER := preload("blue_halo.gdshader")
const SCREEN_CENTER := Vector2(0.0, 58.3)
const SCREEN_HALF_SIZE := Vector2(34.7, 24.8)

@export var effects_enabled := true
@export_range(0.0, 1.0) var intensity := 0.45
@export var symbols_enabled := true
@export var snow_enabled := true
@export var scanlines_enabled := true
@export var flicker_enabled := true
@export var content_motion_enabled := true
@export var blue_glow_enabled := true
@export_range(0.0, 2.0) var blue_glow_strength := 1.45
@export_range(0.0, 1.0) var spill_energy_scale := 1.0
@export_range(0.0, 1.0) var screen_brightness := 1.0
@export var animation_paused := false

var effect_time := 0.0
var burst_remaining := 0.0
var burst_duration := 0.8
var screen_material: ShaderMaterial
var screen_overlay: MeshInstance3D
var source_mesh: MeshInstance3D
var halo: MeshInstance3D
var halo_material: ShaderMaterial
var blue_light: OmniLight3D
@onready var symbols: Node3D = $NoiseSymbols

func _ready() -> void:
	source_mesh = $Model.find_child("tripo_node_0b78e457", true, false) as MeshInstance3D
	if source_mesh == null or source_mesh.mesh.get_surface_count() != 1:
		push_error("TV FX: source mesh changed; inspect the model before rebuilding the screen overlay.")
		set_process(false)
		return
	_build_screen_overlay()
	_build_blue_glow()
	_sync_effects()

func _build_blue_glow() -> void:
	halo = MeshInstance3D.new()
	halo.name = "BlueGlowHalo"
	var quad := QuadMesh.new()
	quad.size = Vector2(94.0, 74.0)
	halo.mesh = quad
	halo.position = Vector3(43.5, SCREEN_CENTER.y, 0.0)
	halo.rotation.y = PI / 2.0
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo_material = ShaderMaterial.new()
	halo_material.shader = HALO_SHADER
	halo.material_override = halo_material
	add_child(halo)
	blue_light = OmniLight3D.new()
	blue_light.name = "BlueScreenSpill"
	blue_light.position = Vector3(48.0, SCREEN_CENTER.y, 0.0)
	blue_light.light_color = Color(0.07, 0.43, 1.0)
	blue_light.omni_range = 78.0
	blue_light.omni_attenuation = 1.5
	blue_light.shadow_enabled = false
	add_child(blue_light)

func _build_screen_overlay() -> void:
	var source := source_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var points := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var screen_uv := PackedVector2Array()
	for offset in range(0, indices.size(), 3):
		var ids := [indices[offset], indices[offset + 1], indices[offset + 2]]
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		var average_normal := Vector3.ZERO
		for id in ids:
			low = low.min(vertices[id])
			high = high.max(vertices[id])
			average_normal += normals[id]
		# Broad phase includes boundary triangles. The shader clips the precise
		# inset screen silhouette, following the original curved glass surface.
		if low.x < 24.0 or average_normal.x < 1.2:
			continue
		if high.y < 33.0 or low.y > 84.0 or high.z < -36.0 or low.z > 36.0:
			continue
		for id in ids:
			var p := vertices[id]
			points.append(p + normals[id] * 0.055)
			out_normals.append(normals[id])
			out_uv.append(uv[id])
			screen_uv.append((Vector2(-p.z, p.y) - SCREEN_CENTER) / (SCREEN_HALF_SIZE * 2.0) + Vector2(0.5, 0.5))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_TEX_UV] = out_uv
	arrays[Mesh.ARRAY_TEX_UV2] = screen_uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	screen_material = ShaderMaterial.new()
	screen_material.shader = CRT_SHADER
	var original := source_mesh.get_active_material(0) as BaseMaterial3D
	screen_material.set_shader_parameter("original_albedo", original.albedo_texture)
	screen_overlay = MeshInstance3D.new()
	screen_overlay.name = "ScreenFXOverlay"
	screen_overlay.mesh = mesh
	screen_overlay.material_override = screen_material
	screen_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	source_mesh.add_child(screen_overlay)

func _process(delta: float) -> void:
	if not animation_paused:
		effect_time += delta
		burst_remaining = maxf(0.0, burst_remaining - delta)
	_sync_effects()

func _sync_effects() -> void:
	if screen_material == null:
		return
	intensity = clampf(intensity, 0.0, 1.0)
	var burst := burst_remaining / burst_duration
	screen_overlay.visible = effects_enabled and (intensity > 0.0 or burst > 0.0) and (snow_enabled or scanlines_enabled or flicker_enabled or content_motion_enabled)
	screen_material.set_shader_parameter("effect_time", effect_time)
	screen_material.set_shader_parameter("intensity", intensity)
	screen_material.set_shader_parameter("burst", burst)
	screen_material.set_shader_parameter("snow_enabled", snow_enabled)
	screen_material.set_shader_parameter("scanlines_enabled", scanlines_enabled)
	screen_material.set_shader_parameter("flicker_enabled", flicker_enabled)
	screen_material.set_shader_parameter("content_motion_enabled", content_motion_enabled)
	var pulse := 1.0
	if flicker_enabled:
		var random_tick := sin(floorf(effect_time * 9.0) * 127.1 + 31.7) * 43758.5453
		pulse = 0.8 + 0.8 * (random_tick - floorf(random_tick))
	var glow := (intensity * pulse + burst * 0.65) * clampf(blue_glow_strength, 0.0, 2.0)
	if not effects_enabled or not blue_glow_enabled:
		glow = 0.0
	screen_overlay.visible = screen_overlay.visible or glow > 0.0
	screen_material.set_shader_parameter("blue_glow", glow)
	screen_material.set_shader_parameter("screen_brightness", screen_brightness)
	halo_material.set_shader_parameter("blue_glow", glow)
	halo.visible = glow > 0.0
	blue_light.visible = glow > 0.0
	blue_light.light_energy = glow * 4.2 * spill_energy_scale
	symbols.is_enabled = effects_enabled and symbols_enabled
	symbols.update_animation(effect_time, burst, intensity)

func set_effects_enabled(enabled: bool) -> void:
	effects_enabled = enabled
	_sync_effects()

func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	_sync_effects()

func set_symbols_enabled(enabled: bool) -> void:
	symbols_enabled = enabled
	_sync_effects()

func set_blue_glow_enabled(enabled: bool) -> void:
	blue_glow_enabled = enabled
	_sync_effects()

func trigger_burst(duration: float = 0.8) -> void:
	burst_duration = clampf(duration, 0.1, 3.0)
	burst_remaining = burst_duration
	_sync_effects()
