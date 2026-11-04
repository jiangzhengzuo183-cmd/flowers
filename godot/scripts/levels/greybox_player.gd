extends "res://scripts/maze/walk_player.gd"

func _ready() -> void:
	super()
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(40)
	floor_constant_speed = false
	floor_stop_on_slope = true
