extends Node3D
## Sample the actual posed character surface, then let small light grains drift with +X sand wind.
signal started
signal finished
const Motes := preload("res://art/maze02/memory_shade/MemoryMotes.tscn")
const MASK := "res://modules/maze02_ghosts/shade_dissolve_mask.gdshaderinc"
const MOTION := "res://art/maze02/memory_shade/shade_motion.gdshaderinc"
@export_range(100, 500) var particle_count := 260
@export var wind_velocity := Vector3(1.05, 0.12, 0.08)
@export var dissolve_seconds := 1.45
@export var total_seconds := 3.6
var active := false
var completed := false
var elapsed := 0.0
var play_count := 0
var cloud: MultiMeshInstance3D
var glow_cloud: MultiMeshInstance3D
var _source: Node3D
var _points := PackedVector3Array()
var _release := PackedFloat32Array()
var _life := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _materials: Array[ShaderMaterial] = []
var _original_shaders: Array[Shader] = []

func _ready() -> void:
	set_process(false)

func prepare(shade: Node3D) -> void:
	_source = shade
	var material: Material = shade.depth_material
	while material is ShaderMaterial:
		_add_mask(material)
		material = material.next_pass

func play(shade: Node3D) -> void:
	if active or completed:
		return
	if _materials.is_empty():
		prepare(shade)
	_source.player.pause()
	_source.particles_enabled = false
	var anchor := shade.global_position
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, anchor)
	_capture_surface(shade)
	_make_cloud()
	active = true
	elapsed = 0.0
	play_count += 1
	set_process(true)
	started.emit()

func _capture_surface(shade: Node3D) -> void:
	_points.clear()
	_release.clear()
	_life.clear()
	_sizes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115
	var mesh_node: MeshInstance3D = shade._mesh_nodes[0]
	var skeleton: Skeleton3D = shade.skeleton
	var skin: Skin = mesh_node.skin
	var transforms: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(i))
		transforms.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(i))
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	for i in particle_count:
		var index := rng.randi_range(0, vertices.size() - 1)
		var posed := Vector3.ZERO
		for j in influences:
			var at := index * influences + j
			posed += (transforms[bones[at]] * vertices[index]) * weights[at]
		var point := to_local(skeleton.to_global(posed))
		_points.append(point)
		_release.append(rng.randf_range(0.18, 1.16))
		_life.append(rng.randf_range(1.35, 2.20))
		_sizes.append(rng.randf_range(0.85, 1.65))

func _make_cloud() -> void:
	var template := Motes.instantiate() as CPUParticles3D
	var mesh := template.mesh.duplicate(true) as QuadMesh
	var material := mesh.material as StandardMaterial3D
	mesh.size = Vector2(0.027, 0.027)
	material.albedo_color = Color(0.55, 0.86, 1.0, 0.95)
	material.emission_enabled = true
	material.emission = Color(0.16, 0.48, 0.85)
	material.vertex_color_use_as_albedo = true
	template.free()
	cloud = MultiMeshInstance3D.new()
	cloud.name = "WindborneMemoryGrains"
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.custom_aabb = AABB(Vector3(-1,-0.2,-1), Vector3(5.0,3.2,3.0))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = particle_count
	for i in particle_count:
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, _points[i]))
		multi.set_instance_color(i, Color(1,1,1,0))
	cloud.multimesh = multi
	add_child(cloud)
	# A second, wider pass supplies a real soft halo without enabling global bloom.
	glow_cloud = MultiMeshInstance3D.new()
	glow_cloud.name = "MemoryGrainSoftGlow"
	glow_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_cloud.custom_aabb = cloud.custom_aabb
	var glow_mesh := mesh.duplicate(true) as QuadMesh
	glow_mesh.size = Vector2(0.076, 0.076)
	var glow_material := glow_mesh.material as StandardMaterial3D
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_material.albedo_color = Color(0.12, 0.48, 1.0, 0.24)
	glow_material.emission = Color(0.04, 0.16, 0.38)
	glow_material.render_priority = 1
	var glows := MultiMesh.new()
	glows.transform_format = MultiMesh.TRANSFORM_3D
	glows.use_colors = true
	glows.mesh = glow_mesh
	glows.instance_count = particle_count
	for i in particle_count:
		glows.set_instance_transform(i, Transform3D(Basis.IDENTITY, _points[i]))
		glows.set_instance_color(i, Color(1,1,1,0))
	glow_cloud.multimesh = glows
	add_child(glow_cloud)

func _add_mask(material: ShaderMaterial) -> void:
	_materials.append(material)
	_original_shaders.append(material.shader)
	var include_token := "#" + "include"
	var code := material.shader.code.replace(include_token + ' "shade_motion.gdshaderinc"', include_token + ' "' + MOTION + '"')
	code = code.replace("void vertex() {", include_token + ' "' + MASK + '"\nvoid vertex() {\n\tshade_dissolve_position = VERTEX;')
	var end := code.rfind("}")
	code = code.insert(end, "\n\tfloat dissolve_mask = shade_dissolve_mask(shade_dissolve_position);\n\tif (dissolve_mask < 0.005) { discard; }\n\tALPHA *= dissolve_mask;\n")
	var variant := Shader.new()
	variant.code = code
	material.shader = variant
	material.set_shader_parameter("shade_dissolve_progress", 0.0)

func _process(delta: float) -> void:
	elapsed += delta
	var dissolve := clampf((elapsed - 0.10) / dissolve_seconds, 0.0, 1.0)
	for material in _materials:
		material.set_shader_parameter("shade_dissolve_progress", dissolve)
	for i in particle_count:
		var age := elapsed - _release[i]
		var point := _points[i]
		var alpha := 0.0
		if age > 0.0:
			var phase := float(i) * 1.618
			var drift := wind_velocity * age * (0.72 + fposmod(phase, 0.56))
			drift += Vector3(sin(age * 2.3 + phase) * 0.09, sin(age * 1.7 + phase) * 0.075,
				cos(age * 2.0 + phase) * 0.12) * minf(age, 1.0)
			point += drift
			alpha = smoothstep(0.0, 0.14, age) * (1.0 - smoothstep(_life[i] * 0.45, _life[i], age))
			alpha *= 0.88 + 0.12 * sin(age * 2.8 + phase)
		var size := _sizes[i] * (1.0 - minf(maxf(age,0.0) / _life[i], 1.0) * 0.30)
		cloud.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point))
		cloud.multimesh.set_instance_color(i, Color(0.82,0.94,1.0,alpha * 0.9))
		glow_cloud.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point))
		glow_cloud.multimesh.set_instance_color(i, Color(0.65,0.88,1.0,alpha * 0.9))
	if dissolve >= 1.0:
		_source.hide()
	if elapsed >= total_seconds:
		active = false
		completed = true
		cloud.hide()
		glow_cloud.hide()
		set_process(false)
		finished.emit()

func reset_effect() -> void:
	_restore_materials()
	if is_instance_valid(cloud):
		cloud.queue_free()
		cloud = null
	if is_instance_valid(glow_cloud):
		glow_cloud.queue_free()
		glow_cloud = null
	active = false
	completed = false
	elapsed = 0.0
	play_count = 0
	top_level = false
	transform = Transform3D.IDENTITY
	set_process(false)

func _restore_materials() -> void:
	for i in _materials.size():
		_materials[i].shader = _original_shaders[i]
	_materials.clear()
	_original_shaders.clear()

func _exit_tree() -> void:
	_restore_materials()
	_source = null
