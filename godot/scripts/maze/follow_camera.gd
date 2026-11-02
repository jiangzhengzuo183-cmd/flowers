extends Node3D

@onready var camera: Camera3D = $Camera3D
var target: CharacterBody3D
var yaw := 0.0
var pitch := 0.68
var distance := 6.0
var enabled := false

func configure(player: CharacterBody3D) -> void:
	target = player
	reset_view()

func reset_view() -> void:
	yaw = 0
	pitch = 0.68
	distance = 6
	if is_instance_valid(target):
		position = target.position + Vector3(0, 1.1, 0)
	_update_pose()

func _process(delta: float) -> void:
	if enabled and is_instance_valid(target):
		position = position.lerp(target.position + Vector3(0, 1.1, 0), 1 - exp(-12 * delta))
		_update_pose()

func handle_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
		yaw -= event.relative.x * 0.007
		pitch = clampf(pitch + event.relative.y * 0.007, 0.5, 1.15)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance / 1.12, 3.5, 10)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.12, 3.5, 10)
	_update_pose()

func _update_pose() -> void:
	camera.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(global_position, Vector3.UP)
