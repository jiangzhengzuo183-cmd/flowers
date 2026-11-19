@tool
extends Node3D
## Standalone fixture. The root is the ceiling attachment, Y points up.
## Original GLB and maze are untouched; all changes are per-instance materials.

const GlowShader = preload("crystal_glow.gdshader")
const HaloShader = preload("soft_halo.gdshader")
const MODEL_SCALE := 0.016
const MODEL_HEIGHT := 91.88525390625
const BULB_CENTRES := [
	Vector3(37.303, 43.190, -0.029), Vector3(27.149, 43.471, 27.066),
	Vector3(0.064, 43.345, 37.066), Vector3(-27.071, 43.405, 27.095),
	Vector3(-37.298, 43.254, -0.054), Vector3(-27.007, 43.164, -27.138),
	Vector3(0.045, 43.386, -37.117), Vector3(27.146, 43.059, -27.116),
]

@export var lit: bool = true:
	set(value):
		lit = value
		_apply_settings()
@export_range(0.0, 3.0, 0.05) var brightness: float = 1.0:
	set(value):
		brightness = value
		_apply_settings()
@export var light_color: Color = Color("ffdfb1"):
	set(value):
		light_color = value
		_apply_settings()
@export_range(0.0, 1.0, 0.01) var halo_strength: float = 0.32:
	set(value):
		halo_strength = value
		_apply_settings()
@export var illuminate_surroundings: bool = true:
	set(value):
		illuminate_surroundings = value
		_apply_settings()
@export_range(0.5, 8.0, 0.1) var light_range: float = 3.5:
	set(value):
		light_range = value
		_apply_settings()

var _materials: Array[ShaderMaterial] = []
var _halo_material: ShaderMaterial
var _halos: Node3D
var _light: OmniLight3D

func _ready() -> void:
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = GlowShader
			material.set_shader_parameter("base_texture", original.albedo_texture)
			mesh.set_surface_override_material(surface, material)
			_materials.append(material)
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = HaloShader
	_halos = Node3D.new()
	_halos.name = "BulbHalos"
	add_child(_halos)
	for point: Vector3 in BULB_CENTRES:
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.29, 0.29)
		halo.mesh = quad
		halo.material_override = _halo_material
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = (point - Vector3(0, MODEL_HEIGHT, 0)) * MODEL_SCALE
		_halos.add_child(halo)
	_light = OmniLight3D.new()
	_light.name = "WarmRoomLight"
	_light.position = Vector3(0, -0.86, 0)
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = false
	add_child(_light)
	_apply_settings()

func _apply_settings() -> void:
	var energy := brightness if lit else 0.0
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("brightness", energy)
		material.set_shader_parameter("light_color", light_color)
	if is_instance_valid(_halo_material):
		_halo_material.set_shader_parameter("light_color", light_color)
		_halo_material.set_shader_parameter("strength", minf(halo_strength * energy, 1.0))
	if is_instance_valid(_halos):
		_halos.visible = energy > 0.0
	if is_instance_valid(_light):
		_light.visible = illuminate_surroundings and energy > 0.0
		_light.light_color = light_color
		_light.light_energy = energy * 0.65
		_light.omni_range = light_range

func set_lit(enabled: bool) -> void:
	lit = enabled
