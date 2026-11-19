extends Node3D
## Small world-space trails driven by actual wrist, foot and body motion.

var enabled: bool = true
var last_motion_strength: float = 0.0
var _skeleton: Skeleton3D
var _emitters: Array[CPUParticles3D] = []
var _bones: Array[int] = []
var _previous: Array[Vector3] = []
var _previous_body: Quaternion
var _delta: float = 1.0 / 60.0
var _initialized: bool = false
var _sample_age: float = 0.0
var _previous_root_position: Vector3
var _previous_root_rotation: Quaternion
var _root_initialized: bool = false

func _ready() -> void:
	var folder := (get_script() as Script).resource_path.get_base_dir()
	for index in range(3):
		var emitter := (load(folder.path_join("MemoryMotes.tscn")) as PackedScene).instantiate() as CPUParticles3D
		emitter.name = ["LeftHandTrail", "RightHandTrail", "FootAndTurnTrail"][index]
		emitter.amount = 5 if index < 2 else 10
		emitter.lifetime = 0.75 if index < 2 else 1.0
		emitter.preprocess = 0.0
		emitter.local_coords = false
		emitter.emitting = false
		emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents = Vector3(0.012, 0.012, 0.012) if index < 2 else Vector3(0.12, 0.04, 0.08)
		emitter.initial_velocity_min = 0.015
		emitter.initial_velocity_max = 0.04
		emitter.gravity = Vector3(0, 0.012, 0)
		emitter.scale_amount_min = 0.4
		emitter.scale_amount_max = 1.1
		var mesh := emitter.mesh.duplicate() as QuadMesh
		mesh.size = Vector2(0.018, 0.018)
		var material := mesh.material.duplicate() as StandardMaterial3D
		material.albedo_color = Color(0.48, 0.79, 1.0, 0.95)
		material.emission_enabled = true
		material.emission = Color(0.12, 0.32, 0.55)
		mesh.material = material
		emitter.mesh = mesh
		add_child(emitter)
		_emitters.append(emitter)

func configure(skeleton: Skeleton3D, modifier: SkeletonModifier3D) -> void:
	_skeleton = skeleton
	for bone_name in ["L_Hand", "R_Hand", "L_Foot", "R_Foot", "Spine02"]:
		_bones.append(skeleton.find_bone(bone_name))
	modifier.modification_processed.connect(_sample_motion)

func _process(delta: float) -> void:
	_delta = maxf(delta, 0.001)
	_sample_age += delta
	if _sample_age > 0.12:
		for emitter in _emitters:
			emitter.emitting = false
	if _emitters.size() != 3:
		return
	var position_now := global_position
	var rotation_now := global_basis.orthonormalized().get_rotation_quaternion()
	if _root_initialized:
		var root_speed := position_now.distance_to(_previous_root_position) / _delta
		var turn_speed := rotation_now.angle_to(_previous_root_rotation) / _delta
		if enabled and maxf(root_speed, turn_speed * 0.20) > 0.06:
			_emitters[2].emitting = true
			_emitters[2].global_position = position_now + Vector3.UP * 0.10
	_previous_root_position = position_now
	_previous_root_rotation = rotation_now
	_root_initialized = true

func _sample_motion() -> void:
	if _skeleton == null or _emitters.size() != 3:
		return
	_sample_age = 0.0
	var points: Array[Vector3] = []
	for bone in _bones:
		points.append(_skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin))
	var body := (_skeleton.global_basis * _skeleton.get_bone_global_pose(_bones[4]).basis).orthonormalized().get_rotation_quaternion()
	if not _initialized:
		_previous = points
		_previous_body = body
		_initialized = true
	var speeds: Array[float] = []
	for index in range(5):
		speeds.append(points[index].distance_to(_previous[index]) / _delta)
	var turn_speed := _previous_body.angle_to(body) / _delta
	last_motion_strength = maxf(maxf(speeds[0], speeds[1]), maxf(speeds[2], speeds[3]))
	for index in range(2):
		_emitters[index].global_position = points[index]
		_emitters[index].emitting = enabled and speeds[index] > 0.055
	_emitters[2].global_position = points[2].lerp(points[3], 0.5) + Vector3.UP * 0.03
	_emitters[2].emitting = enabled and maxf(maxf(speeds[2], speeds[3]), turn_speed * 0.20) > 0.06
	_previous = points
	_previous_body = body
