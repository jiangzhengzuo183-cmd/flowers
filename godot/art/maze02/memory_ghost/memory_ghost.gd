extends Node3D
## Attach to the wrapper parent of the imported model, or instance memory_ghost.tscn.
## Does not resize, turn or edit the imported mesh. Float moves only the dedicated
## Visual wrapper, leaving this root node available for game positioning.

signal dissolved

@export_range(0.0, 1.0) var opacity: float = 0.58
@export_range(0.0, 1.0) var dissolve_amount: float = 0.0
@export_range(0.0, 0.05) var float_height_ratio: float = 0.012
@export_range(0.5, 10.0) var float_period: float = 3.2
@export var animate: bool = true

var effect_time: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _depth_materials: Array[ShaderMaterial] = []
var _halo_materials: Array[ShaderMaterial] = []
var _visual: Node3D
var _rest_position: Vector3
var _height: float = 99.6792678833
var _dissolve_tween: Tween

func _ready() -> void:
	_visual = get_node_or_null("Visual") as Node3D
	if _visual == null:
		push_error("Memory ghost needs a Visual Node3D containing the imported GLB; use memory_ghost.tscn.")
		set_process(false)
		return
	_rest_position = _visual.position
	var shader_path: String = (get_script() as Script).resource_path.get_base_dir().path_join("memory_ghost.gdshader")
	var shader := load(shader_path) as Shader
	_apply_to_meshes(_visual, shader)
	_update_effect()

func _apply_to_meshes(node: Node, shader: Shader) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var bounds: AABB = mesh_node.get_aabb()
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("bottom_y", bounds.position.y)
		material.set_shader_parameter("model_height", bounds.size.y)
		var depth := ShaderMaterial.new()
		depth.shader = load(shader.resource_path.get_base_dir().path_join("memory_ghost_depth.gdshader")) as Shader
		depth.render_priority = -1
		depth.next_pass = material
		var halo_shader := load(shader.resource_path.get_base_dir().path_join("memory_ghost_halo.gdshader")) as Shader
		var inner := ShaderMaterial.new()
		var outer := ShaderMaterial.new()
		for halo in [inner, outer]:
			halo.shader = halo_shader
			halo.set_shader_parameter("bottom_y", bounds.position.y)
			halo.set_shader_parameter("model_height", bounds.size.y)
			_halo_materials.append(halo)
		inner.set_shader_parameter("expansion", 0.0035)
		inner.set_shader_parameter("strength", 0.23)
		inner.render_priority = 1
		outer.set_shader_parameter("expansion", 0.008)
		outer.set_shader_parameter("strength", 0.085)
		outer.render_priority = 2
		material.next_pass = inner
		inner.next_pass = outer
		mesh_node.material_override = depth
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_materials.append(material)
		_depth_materials.append(depth)
		_height = bounds.size.y
	for child in node.get_children():
		_apply_to_meshes(child, shader)

func _process(delta: float) -> void:
	if animate:
		effect_time += delta
	_update_effect()

func _update_effect() -> void:
	if _visual == null:
		return
	_visual.position = _rest_position + Vector3.UP * sin(effect_time * TAU / maxf(float_period, 0.01)) * _height * float_height_ratio
	for material in _materials:
		material.set_shader_parameter("effect_time", effect_time)
		material.set_shader_parameter("opacity", opacity)
		material.set_shader_parameter("dissolve", dissolve_amount)
	for material in _depth_materials:
		material.set_shader_parameter("dissolve", dissolve_amount)
		material.set_shader_parameter("opacity", opacity)
	for material in _halo_materials:
		material.set_shader_parameter("dissolve", dissolve_amount)
		material.set_shader_parameter("effect_time", effect_time)
		material.set_shader_parameter("opacity", opacity)

## Deterministic preview hook. Set animate=false before calling.
func set_effect_time(seconds: float) -> void:
	effect_time = seconds
	_update_effect()

## Optional gameplay interface: fades from the current state to invisible.
func dissolve_over(seconds: float = 4.0) -> void:
	if _dissolve_tween != null and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
	_dissolve_tween = create_tween()
	_dissolve_tween.tween_property(self, "dissolve_amount", 1.0, maxf(seconds, 0.01))
	_dissolve_tween.tween_callback(func() -> void:
		_update_effect()
		dissolved.emit()
	)

func restore() -> void:
	if _dissolve_tween != null and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
	dissolve_amount = 0.0
	_update_effect()
