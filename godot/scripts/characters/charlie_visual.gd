extends Node3D
## Self-contained visual module. Parent it to a moving CharacterBody3D.
## Forward is -Z; origin is at the feet. Jump optionally includes a vertical arc.

signal jump_finished

const SOFT_LIGHT := preload("res://assets/characters/charlie/charlie_soft_light.gdshader")
const WALK_SPEED := 0.80
const RUN_SPEED := 2.89
const IDLE_DELAY := 4.0
const IDLE_LEG_SPREAD := deg_to_rad(6.0)
const JUMP_PREPARE := 0.48
const JUMP_TAKEOFF := 0.55
const JUMP_APEX := 0.75
const JUMP_CONTACT := 0.99
const VICTORY_DURATION := 7.2
var celebration_remaining := 0.0
const CLIP_NAMES := {
	&"idle_001": &"Idle", &"walk_001": &"Walk", &"run_001": &"Run",
	&"jump_001": &"Jump", &"dance_01_001": &"Dance",
}
var animation_player: AnimationPlayer
var _jumping := false
var _physics_jump := false
var celebrating := false
var _requested_speed := 0.0

func _ready() -> void:
	_apply_soft_light()
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	var hip := skeleton.find_bone("Hip")
	var hip_rest := skeleton.get_bone_rest(hip).origin
	var parent_basis := skeleton.get_bone_global_rest(skeleton.get_bone_parent(hip)).basis
	var imported := animation_player.get_animation_library(&"")
	var library := AnimationLibrary.new()
	for source: StringName in imported.get_animation_list():
		var clip: StringName = CLIP_NAMES.get(source, source)
		var animation := imported.get_animation(source)
		if CLIP_NAMES.has(source):
			animation = animation.duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR if clip in [&"Idle", &"Walk", &"Run", &"Dance"] else Animation.LOOP_NONE
			_pin_hip(animation, hip_rest, parent_basis, false)
			if clip == &"Idle":
				_open_idle_stance(animation, skeleton)
		library.add_animation(clip, animation)
	var in_place := library.get_animation(&"Jump").duplicate() as Animation
	_pin_hip(in_place, hip_rest, parent_basis, true)
	library.add_animation(&"JumpInPlace", in_place)
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library)
	animation_player.animation_finished.connect(_on_animation_finished)
	play_clip(&"Idle")

func _apply_soft_light() -> void:
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if original == null or original.albedo_texture == null:
				continue
			var finish := ShaderMaterial.new()
			finish.shader = SOFT_LIGHT
			finish.set_shader_parameter(&"base_color", original.albedo_texture)
			mesh.set_surface_override_material(surface, finish)

## The export stores travel in Hip along the rotated parent axes. Remove
## horizontal travel, and for the physics jump remove only the baked lift.
func _pin_hip(animation: Animation, rest: Vector3, parent_basis: Basis, remove_lift: bool) -> void:
	var inverse := parent_basis.inverse()
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or path.get_concatenated_subnames() != &"Hip":
			continue
		for key in animation.track_get_key_count(track):
			var authored: Vector3 = animation.track_get_key_value(track, key)
			var vertical := (parent_basis * (authored - rest)).y
			if remove_lift:
				vertical = minf(vertical, 0.0)
			animation.track_set_key_value(track, key, rest + inverse * Vector3.UP * vertical)

func _open_idle_stance(animation: Animation, skeleton: Skeleton3D) -> void:
	# The imported skeleton faces +X. Spread from the hips, then counter-roll
	# each ankle so the shoes keep their original contact angle.
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var name := String(animation.track_get_path(track).get_concatenated_subnames())
		var thigh := name == "L_Thigh" or name == "R_Thigh"
		if not thigh and name != "L_Foot" and name != "R_Foot":
			continue
		var bone := skeleton.find_bone(name)
		var reference := skeleton.get_bone_parent(bone) if thigh else bone
		var axis := (skeleton.get_bone_global_rest(reference).basis.inverse() * Vector3.RIGHT).normalized()
		var angle := IDLE_LEG_SPREAD if name.begins_with("L_") else -IDLE_LEG_SPREAD
		var correction := Quaternion(axis, angle if thigh else -angle)
		for key in animation.track_get_key_count(track):
			var authored: Quaternion = animation.track_get_key_value(track, key)
			var adjusted := correction * authored if thigh else authored * correction
			animation.track_set_key_value(track, key, adjusted.normalized())

func play_clip(clip: StringName, playback_speed: float = 1.0) -> void:
	if not is_instance_valid(animation_player) or not animation_player.has_animation(clip):
		return
	if clip == &"Jump" or clip == &"JumpInPlace":
		play_jump(clip == &"Jump")
		return
	_jumping = false
	animation_player.speed_scale = maxf(playback_speed, 0.05)
	if animation_player.current_animation != clip:
		animation_player.play(clip, 0.16)
	elif animation_player.has_section():
		animation_player.reset_section()

func set_locomotion(speed_metres_per_second: float, inactive_seconds: float = 0.0) -> void:
	var speed := absf(speed_metres_per_second)
	_requested_speed = speed
	if _jumping or celebrating:
		return
	if speed < 0.05:
		if inactive_seconds >= IDLE_DELAY:
			play_clip(&"Idle")
		else:
			_rest_pose()
	elif speed < 2.0:
		play_clip(&"Walk", clampf(speed / WALK_SPEED, 0.5, 2.5))
	else:
		play_clip(&"Run", clampf(speed / RUN_SPEED, 0.6, 1.8))

func _rest_pose() -> void:
	if animation_player.current_animation != &"Idle" or not animation_player.has_section():
		animation_player.speed_scale = 1.0
		animation_player.play_section(&"Idle", 0.0, 1.0 / 30.0, 0.16)
		animation_player.seek(0.0, true)

func play_victory_dance() -> void:
	_jumping = false
	_physics_jump = false
	celebrating = true
	animation_player.active = true
	animation_player.speed_scale = 1.0
	celebration_remaining = VICTORY_DURATION
	animation_player.play_section(&"Dance", 0.0, 4.2, 0.16)

func _process(delta: float) -> void:
	if not celebrating: return
	celebration_remaining = maxf(0.0, celebration_remaining-delta)
	if celebration_remaining <= 0.0:
		celebrating = false
		_rest_pose()

func play_jump(use_baked_height: bool = true) -> void:
	if _jumping or not is_instance_valid(animation_player):
		return
	_jumping = true
	_physics_jump = false
	animation_player.active = true
	animation_player.speed_scale = 1.0
	animation_player.play_section(&"Jump" if use_baked_height else &"JumpInPlace", JUMP_PREPARE, JUMP_CONTACT, 0.08)

## Physics owns height and contact timing; sample the existing in-place pose.
func begin_physics_jump() -> void:
	_jumping = true
	_physics_jump = true
	animation_player.play(&"JumpInPlace",0.0)
	animation_player.speed_scale = 0.0
	animation_player.seek(JUMP_TAKEOFF, true)

func update_physics_jump(vertical_speed: float, launch_speed: float) -> void:
	if not _physics_jump:
		return
	var ratio := clampf(absf(vertical_speed)/launch_speed,0.0,1.0)
	var time := lerpf(JUMP_APEX, JUMP_TAKEOFF, ratio) if vertical_speed > 0 else lerpf(JUMP_APEX, JUMP_CONTACT, ratio)
	animation_player.seek(time,true)

func end_physics_jump() -> void:
	if not _physics_jump:
		return
	_physics_jump = false
	_jumping = false
	set_locomotion(_requested_speed)
	jump_finished.emit()

func cancel_jump() -> void:
	_physics_jump = false
	_jumping = false
	celebrating = false
	_requested_speed = 0.0
	_rest_pose()

func _on_animation_finished(clip: StringName) -> void:
	if celebrating and clip == &"Dance":
		celebrating = false
		_rest_pose()
	elif _jumping and not _physics_jump and (clip == &"Jump" or clip == &"JumpInPlace"):
		_jumping = false
		set_locomotion(_requested_speed)
		jump_finished.emit()
