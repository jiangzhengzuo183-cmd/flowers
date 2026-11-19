extends Node3D
## A floating H6 ornament with its own pass sensor, light, and chime.

const REST_EMISSION := 0.14
const PEAK_EMISSION := 0.53
const REST_LIGHT := 0.08
const PEAK_LIGHT := 0.39
const SPIN_SECONDS := 1.04

var _pivot: Node3D
var _light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _materials: Array[BaseMaterial3D] = []
var _animation: Tween

func install(model: PackedScene, chime: AudioStream, tint: Color, facing: Basis, actor: CharacterBody3D) -> void:
	_pivot = Node3D.new()
	_pivot.name = "SpinPivot"
	add_child(_pivot)
	var mount := Node3D.new()
	mount.name = "ModelMount"
	_pivot.add_child(mount)
	var ornament: Node3D = model.instantiate()
	mount.add_child(ornament)
	var meshes := ornament.find_children("*", "MeshInstance3D", true, false)
	if ornament is MeshInstance3D:
		meshes.push_front(ornament)
	var bounds := AABB()
	for i in meshes.size():
		var mesh: MeshInstance3D = meshes[i]
		var relative := mount.global_transform.affine_inverse() * mesh.global_transform
		var box: AABB = relative * mesh.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var luminous: BaseMaterial3D = original.duplicate()
			luminous.emission_enabled = true
			luminous.emission = Color.WHITE
			luminous.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			luminous.emission_texture = luminous.albedo_texture
			luminous.emission_energy_multiplier = REST_EMISSION
			mesh.set_surface_override_material(surface, luminous)
			_materials.append(luminous)
		mesh.set_meta("art_role", "niche_star")
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var factor := 0.44 / maxf(bounds.get_longest_axis_size(), 0.001)
	mount.basis = facing.scaled(Vector3.ONE * factor)
	mount.position = -(mount.basis * bounds.get_center())

	_light = OmniLight3D.new()
	_light.name = "NicheLight"
	_light.position = Vector3(-0.13, 0.12, 0)
	_light.omni_range = 0.65
	_light.omni_attenuation = 1.6
	_light.light_color = tint
	_light.light_energy = REST_LIGHT
	_light.light_specular = 0.15
	add_child(_light)

	_audio = AudioStreamPlayer3D.new()
	_audio.name = "Chime"
	_audio.stream = chime
	_audio.unit_size = 3.0
	_audio.max_distance = 10.0
	_audio.volume_db = -5.0
	add_child(_audio)

	var sensor := Area3D.new()
	sensor.name = "PassSensor"
	sensor.position = Vector3(3.60 - position.x, 0.12, 0)
	sensor.collision_layer = 0
	sensor.collision_mask = actor.collision_layer
	sensor.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.26, 1.70, 0.78)
	shape.shape = box
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_pass.bind(actor))
	add_child(sensor)

func _on_pass(body: Node3D, actor: CharacterBody3D) -> void:
	if body != actor or (_animation != null and _animation.is_running()):
		return
	_audio.play()
	_pivot.rotation.y = 0.0
	_animation = create_tween().set_parallel(true)
	_animation.tween_property(_pivot, "rotation:y", TAU, SPIN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animation.tween_method(_set_glow, 0.0, 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animation.tween_method(_set_glow, 1.0, 0.0, 0.83).set_delay(0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_animation.chain().tween_callback(func() -> void: _pivot.rotation.y = 0.0)

func _set_glow(amount: float) -> void:
	_light.light_energy = lerpf(REST_LIGHT, PEAK_LIGHT, amount)
	for material: BaseMaterial3D in _materials:
		material.emission_energy_multiplier = lerpf(REST_EMISSION, PEAK_EMISSION, amount)
