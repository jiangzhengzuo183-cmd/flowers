extends Resource
## Deterministic race balance. No random speed or pause locations.
@export_range(50.0,65.0,0.1) var target_seconds := 55.5
@export_range(0.6,1.0,0.05) var hesitation_seconds := 0.8
@export_range(0.0,1.0,0.05) var preparation_seconds := 0.6
@export_range(0.0,0.5,0.01) var tie_seconds := 0.3
@export_range(0.4,0.9,0.05) var mouse_height := 0.65
@export var fast_start := 1.18
@export var relaxed_middle := 0.86
@export var fast_finish := 1.20

## Opening burst and presentation; included in the same arrival-time calibration.
@export_range(1.0,2.2,0.05) var opening_multiplier := 1.65
@export_range(2.0,7.0,0.1) var opening_seconds := 4.5
@export_range(0.5,2.0,0.1) var opening_ease_seconds := 1.2
@export_range(3.0,8.0,0.1) var hide_after_seconds := 4.0
@export_range(4.0,12.0,0.5) var hide_minimum_gap := 6.0
@export_range(12.0,28.0,1.0) var reveal_remaining_metres := 20.0
@export_range(0.2,0.8,0.05) var visibility_fade_seconds := 0.4

## One use per race; the max includes the original capsule's fade-out.
@export_range(0.01,0.1,0.01) var sanctuary_mouse_speed := 0.05
@export_range(1.0,6.0,0.1) var sanctuary_max_seconds := 6.0
@export_range(0.0,3.0,0.1) var sanctuary_exit_seconds := 3.0
@export_range(0.8,1.8,0.05) var sanctuary_interaction_radius := 1.35
