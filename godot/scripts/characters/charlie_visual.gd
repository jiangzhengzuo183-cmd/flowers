extends Node3D
## Self-contained visual module. Parent it to a moving CharacterBody3D.
## Forward is -Z; origin is at the feet. Jump optionally includes a vertical arc.

signal jump_finished

const WALK_SPEED := 1.2
const RUN_SPEED := 2.7
var animation_player: AnimationPlayer
var _jumping := false
var _requested_speed := 0.0

func _ready() -> void:
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Per-instance animation copies keep JumpInPlace and settings local to this actor.
	var library := animation_player.get_animation_library(&"").duplicate(true) as AnimationLibrary
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library)
	for clip in [&"Idle", &"Walk", &"Run"]:
		animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var jump := animation_player.get_animation(&"Jump")
	jump.loop_mode = Animation.LOOP_NONE
	var in_place := jump.duplicate(true) as Animation
	for track in in_place.get_track_count():
		if in_place.track_get_type(track) == Animation.TYPE_POSITION_3D and str(in_place.track_get_path(track)).ends_with(":Root"):
			for key in in_place.track_get_key_count(track):
				in_place.track_set_key_value(track, key, Vector3.ZERO)
	library.add_animation(&"JumpInPlace", in_place)
	animation_player.animation_finished.connect(_on_animation_finished)
	play_clip(&"Idle")

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

func set_locomotion(speed_metres_per_second: float) -> void:
	var speed := absf(speed_metres_per_second)
	_requested_speed = speed
	if _jumping:
		return
	if speed < 0.05:
		play_clip(&"Idle")
	elif speed < 2.0:
		play_clip(&"Walk", clampf(speed / WALK_SPEED, 0.5, 1.6))
	else:
		play_clip(&"Run", clampf(speed / RUN_SPEED, 0.6, 1.8))

func play_jump(use_baked_height: bool = true) -> void:
	if _jumping or not is_instance_valid(animation_player):
		return
	_jumping = true
	animation_player.active = true
	animation_player.speed_scale = 1.0
	animation_player.play(&"Jump" if use_baked_height else &"JumpInPlace", 0.08)

func _on_animation_finished(clip: StringName) -> void:
	if _jumping and (clip == &"Jump" or clip == &"JumpInPlace"):
		_jumping = false
		set_locomotion(_requested_speed)
		jump_finished.emit()
