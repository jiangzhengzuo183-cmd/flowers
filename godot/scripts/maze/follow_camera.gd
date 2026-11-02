extends Node3D

@onready var camera: Camera3D = $Camera3D
const DEFAULT_PITCH := 0.68
const DEFAULT_DISTANCE := 2.8
var target: CharacterBody3D
var yaw := 0.0
var pitch := DEFAULT_PITCH
var distance := DEFAULT_DISTANCE
var enabled := false

func configure(player: CharacterBody3D) -> void:
	target = player
	reset_view()

func reset_view() -> void:
	yaw = 0
	pitch = DEFAULT_PITCH
	distance = DEFAULT_DISTANCE
	if is_instance_valid(target):
		position = target.position + Vector3(0, 1.1, 0)
	_update_pose()

func _process(delta: float) -> void:
	if enabled and is_instance_valid(target):
		var focus := target.position + Vector3(0, 1.1, 0)
		var wide := smoothstep(15.0, 65.0, distance)
		focus = focus.lerp(Vector3(target.map_size.x / 2, 0, target.map_size.y / 2), wide)
		position = position.lerp(focus, 1 - exp(-12 * delta))
		_update_pose()

func handle_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
		yaw -= event.relative.x * 0.007
		pitch = clampf(pitch + event.relative.y * 0.007, 0.4, 1.48)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance / 1.18, 2.5, 150)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.18, 2.5, 150)
	_update_pose()

func _update_pose() -> void:
	var view_pitch := lerpf(pitch, maxf(pitch, 1.3), smoothstep(15.0, 65.0, distance))
	camera.position = Vector3(sin(yaw) * cos(view_pitch), sin(view_pitch), cos(yaw) * cos(view_pitch)) * distance
	camera.look_at(global_position, Vector3.UP)
