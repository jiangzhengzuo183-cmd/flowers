extends Node3D

@onready var camera: Camera3D = $Camera3D
const ISOMETRIC_YAW := PI / 4.0
const ISOMETRIC_PITCH := 0.6154797087 # atan(1 / sqrt(2)): equal projected world axes.
const TURN_STEP := PI / 2.0
var center := Vector3.ZERO
var extent := 45.6
var world_size := Vector3(45.6, 4.0, 45.6)
var yaw := ISOMETRIC_YAW
var pitch := ISOMETRIC_PITCH
var zoom := 1.0

func configure(width: float, depth: float) -> void:
	center = Vector3(width / 2, 0, depth / 2)
	extent = maxf(width, depth)
	world_size = Vector3(width + 1.4, 4.0, depth + 1.4)
	reset_view()
	get_viewport().size_changed.connect(_update_camera)

func reset_view() -> void:
	yaw = ISOMETRIC_YAW
	pitch = ISOMETRIC_PITCH
	zoom = 1.0
	position = Vector3.ZERO
	_update_camera()

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		yaw = ISOMETRIC_YAW + roundf((yaw - ISOMETRIC_YAW) / TURN_STEP) * TURN_STEP
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 1.12, 0.5, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom / 1.12, 0.5, 5.0)
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= event.relative.x * 0.008
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			var scale := camera.size / maxf(get_viewport().get_visible_rect().size.y, 1)
			var delta: Vector3 = (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * scale
			delta.y = 0
			position += delta
	_update_camera()

func _update_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * extent * 2.5
	camera.position = center + offset
	camera.look_at(to_global(center), Vector3.UP)
	# Fit the projected scene bounds, including markers, rather than leaving a large margin.
	var projected_width := camera.basis.x.abs().dot(world_size)
	var projected_height := camera.basis.y.abs().dot(world_size)
	camera.size = maxf(projected_height, projected_width / maxf(aspect, 0.01)) * 1.15 / zoom
