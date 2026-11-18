extends Node3D
## F6: isolated preview; drag to orbit, wheel to zoom, Space toggles the light.

var fixture: Node3D
var camera: Camera3D
var _yaw := 0.60
var _pitch := 0.14
var _distance := 2.1
var _dragging := false
var _status: Label

func _ready() -> void:
	fixture = preload("crystal_chandelier.tscn").instantiate()
	add_child(fixture)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("292d3b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e2e5f5")
	environment.ambient_light_energy = 0.45
	# The fixture has its own local halos; no global bloom is required.
	environment.glow_enabled = false
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_color = Color("e9e8ff")
	key.light_energy = 0.60
	add_child(key)
	_box("BackWall", Vector3(12, 12, 0.1), Vector3(0, -1, -1.1), Color("63697e"))
	_box("Floor", Vector3(12, 0.1, 12), Vector3(0, -2.15, 0), Color("b8b2a6"))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	_update_camera()
	var layer := CanvasLayer.new()
	add_child(layer)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC"])
	var title := Label.new()
	title.text = "水晶吊灯 · 暖白光"
	title.add_theme_font_override("font", font)
	title.position = Vector2(34, 28)
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("f4e7d4"))
	layer.add_child(title)
	_status = Label.new()
	_status.add_theme_font_override("font", font)
	_status.position = Vector2(35, 64)
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color("cec4b5"))
	layer.add_child(_status)
	_update_status()
	var hint := Label.new()
	hint.add_theme_font_override("font", font)
	hint.text = "拖动旋转视角   /   滚轮缩放   /   空格开关灯   /   R 重置视角"
	hint.position = Vector2(35, get_viewport().get_visible_rect().size.y - 42)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color("c8c8d0"))
	layer.add_child(hint)

func _box(id: String, size: Vector3, point: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = id
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh.material_override = material
	add_child(mesh)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 1.6, 4.0)
			_update_camera()
	if event is InputEventMouseMotion and _dragging:
		_yaw = clampf(_yaw - event.relative.x * 0.006, -1.2, 1.2)
		_pitch = clampf(_pitch + event.relative.y * 0.004, -0.4, 0.6)
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			fixture.set_lit(not fixture.lit)
			_update_status()
		if event.keycode == KEY_R:
			_yaw = 0.60
			_pitch = 0.14
			_distance = 2.1
			_update_camera()

func _update_camera() -> void:
	var target := Vector3(0, -0.75, 0)
	camera.size = _distance
	camera.look_at_from_position(target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw)) * 5, target)

func _update_status() -> void:
	_status.text = "已点亮 · 柔和光晕" if fixture.lit else "已关闭 · 原始表面"
