extends Node3D

const Model := preload("res://art/maze01/landmarks/finish_doctor.glb")
const PortraitFinish := preload("res://art/maze01/charlie_storybook.gdshader")
const STANDING := &"pose/Standing"
const ENCOURAGE := &"clap_001"
const ENCOURAGEMENT_TIME := 4.4

var _player: AnimationPlayer
var _skeleton: Skeleton3D

func _ready() -> void:
	var model := Model.instantiate() as Node3D
	model.scale = Vector3.ONE * 1.60
	add_child(model)
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			var paint := ShaderMaterial.new()
			paint.shader = PortraitFinish
			paint.set_shader_parameter(&"base_color", material.albedo_texture)
			paint.set_shader_parameter(&"charlie_palette", false)
			paint.set_shader_parameter(&"hair_light", Color("be8968"))
			paint.set_shader_parameter(&"hair_shade", Color("815341"))
			mesh.set_surface_override_material(surface, paint)
	_build_standing_pose()
	_player.animation_finished.connect(_on_animation_finished)
	stand()

func encourage() -> void:
	_player.play_section(ENCOURAGE, 0.0, ENCOURAGEMENT_TIME, 0.25)

func stand() -> void:
	_player.play(STANDING, 0.0)
	_player.advance(0.0)

func _on_animation_finished(animation: StringName) -> void:
	if animation == ENCOURAGE:
		_player.play(STANDING, 0.32)

func _build_standing_pose() -> void:
	var source := _player.get_animation(ENCOURAGE)
	_player.play(ENCOURAGE, 0.0)
	_player.seek(0.0, true)
	_skeleton.force_update_all_bone_transforms()
	# Give the idle pose a little room at the shoulders and feet.
	for side: String in ["L_", "R_"]:
		var shoulder := _skeleton.find_bone(side + "Upperarm")
		var outward := signf(_skeleton.get_bone_global_pose(shoulder).origin.z
			- _skeleton.get_bone_global_pose(_skeleton.find_bone("Spine02")).origin.z)
		_aim_arm(side + "Upperarm", side + "Forearm", Vector3(0.02, -1.0, outward * 0.33))
		_aim_arm(side + "Forearm", side + "Hand", Vector3(0.20, -1.0, outward * 0.15))
		# Counter the thigh roll at the ankle to keep the sole flat.
		var spread := Quaternion(Vector3.RIGHT, -outward * deg_to_rad(3.8))
		_rotate_in_model_space(_skeleton.find_bone(side + "Thigh"), spread)
		_rotate_in_model_space(_skeleton.find_bone(side + "Foot"), spread.inverse())

	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	# Give the pose a key on the same channels as the clap so blending uses
	# this stance.
	for index in source.get_track_count():
		var path := source.track_get_path(index)
		var bone := _skeleton.find_bone(path.get_concatenated_subnames())
		if bone < 0:
			continue
		var type := source.track_get_type(index)
		var value: Variant
		match type:
			Animation.TYPE_POSITION_3D: value = _skeleton.get_bone_pose_position(bone)
			Animation.TYPE_ROTATION_3D: value = _skeleton.get_bone_pose_rotation(bone)
			Animation.TYPE_SCALE_3D: value = _skeleton.get_bone_pose_scale(bone)
			_: continue
		var track := idle.add_track(type)
		idle.track_set_path(track, path)
		idle.track_insert_key(track, 0.0, value)
	var library := AnimationLibrary.new()
	library.add_animation(&"Standing", idle)
	_player.add_animation_library(&"pose", library)

func _aim_arm(bone_name: String, tip_name: String, direction: Vector3) -> void:
	var bone := _skeleton.find_bone(bone_name)
	var tip := _skeleton.find_bone(tip_name)
	var from := _skeleton.get_bone_global_pose(bone).origin
	var to := _skeleton.get_bone_global_pose(tip).origin
	_rotate_in_model_space(bone, Quaternion((to - from).normalized(), direction.normalized()))

func _rotate_in_model_space(bone: int, rotation_delta: Quaternion) -> void:
	var pose := _skeleton.get_bone_global_pose(bone)
	var parent := _skeleton.get_bone_global_pose(_skeleton.get_bone_parent(bone)).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(bone, (parent.inverse() * rotation_delta * pose.basis.get_rotation_quaternion()).normalized())
	_skeleton.force_update_all_bone_transforms()
