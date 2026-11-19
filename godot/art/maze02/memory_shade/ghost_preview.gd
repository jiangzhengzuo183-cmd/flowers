extends Node3D

var ghost: Node3D
var camera: Camera3D
var environment: Environment
var _yaw: float = 0.35
var _distance: float = 2.3
var _dragging: bool = false
var _status: Label

func _ready() -> void:
	var folder := (get_script() as Script).resource_path.get_base_dir()
	ghost = (load(folder.path_join("MemoryShade.tscn")) as PackedScene).instantiate()
	add_child(ghost)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("303840")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	light.light_energy = 0.5
	add_child(light)
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.01
	camera.far = 30.0
	add_child(camera)
	camera.current = true
	_update_camera()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_status = Label.new()
	_status.position = Vector2(24, 20)
	_status.text = "MAZE 02 / MEMORY SHADE\n1 Idle   2 Walk   3 Look around   4 Sob\nDrag to orbit / Wheel to zoom / B background / P particles"
	_status.add_theme_font_size_override("font_size", 16)
	canvas.add_child(_status)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - 0.15, 1.3)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance + 0.15, 4.0)
		_update_camera()
	if event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: ghost.set_state(0)
			KEY_2: ghost.set_state(1)
			KEY_3: ghost.set_state(2)
			KEY_4: ghost.set_state(3)
			KEY_P: ghost.particles_enabled = not ghost.particles_enabled
			KEY_B:
				environment.background_color = Color("c6c9cc") if environment.background_color.r < 0.5 else Color("303840")

func _update_camera() -> void:
	camera.position = Vector3(sin(_yaw) * _distance, 0.59, cos(_yaw) * _distance)
	camera.look_at(Vector3(0, 0.5, 0))
