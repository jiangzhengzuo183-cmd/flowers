extends "res://scripts/levels/greybox_player.gd"

var capsule_speed_factor := 1.0
var tv_reversed := false
var _movement_gesture := Vector2.ZERO
var _gesture_reversed := false

func reset_player() -> void:
	super()
	_movement_gesture = Vector2.ZERO
	_gesture_reversed = false

func _movement_modifier() -> float:
	var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) \
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var forward := float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) \
		- float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var gesture := Vector2(horizontal, forward)
	# Preserve a held movement across the field edge. A fresh direction uses the current field.
	if gesture.is_zero_approx() or not gesture.is_equal_approx(_movement_gesture):
		_gesture_reversed = tv_reversed
	_movement_gesture = gesture
	return move_speed_multiplier * capsule_speed_factor * (-1.0 if _gesture_reversed else 1.0)
