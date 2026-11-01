extends Node3D

@onready var camera: Camera3D = $Camera3D
var center := Vector3.ZERO
var extent := 45.6
var yaw := 0.7
var pitch := 0.94
var zoom := 1.0

func configure(width: float, depth: float) -> void:
	center = Vector3(width / 2, 0, depth / 2)
	extent = maxf(width, depth)
	reset_view()
	get_viewport().size_changed.connect(_update_camera)

func reset_view() -> void:
	yaw = 0.7
	pitch = 0.94
	zoom = 1.0
	position = Vector3.ZERO
	_update_camera()

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 1.12, 0.5, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom / 1.12, 0.5, 5.0)
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch + event.relative.y * 0.008, 0.15, 1.5)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			var scale := camera.size / maxf(get_viewport().get_visible_rect().size.y, 1)
			var delta: Vector3 = (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * scale
			delta.y = 0
			position += delta
	_update_camera()

func _update_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1)
	camera.size = extent * 1.55 * maxf(1, 1 / maxf(aspect, 0.01)) / zoom
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * extent * 2.5
	camera.position = center + offset
	camera.look_at(to_global(center), Vector3.UP)
