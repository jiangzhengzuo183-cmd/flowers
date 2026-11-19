extends Node3D

@onready var charlie = $CharlieVisual
@onready var camera: Camera3D = $Camera3D
var angle := 0.35
var elevation := 0.12
var distance := 4.0
var dragging := false

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.theme = preload("res://ui/game_theme.tres")
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "查理 · 动画预览"
	column.add_child(title)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for pair in [["待机  1", &"Idle"], ["走路  2", &"Walk"], ["跑步  3", &"Run"], ["跳跃  4", &"Jump"]]:
		var button := Button.new()
		button.text = pair[0]
		button.pressed.connect(_play.bind(pair[1]))
		buttons.add_child(button)
	var hint := Label.new()
	hint.text = "拖动鼠标旋转 · 滚轮缩放\n空格暂停/继续 · 跳跃单次播放后返回待机"
	column.add_child(hint)
	_update_camera()

func _play(clip: StringName) -> void:
	charlie.play_clip(clip)
	charlie.animation_player.active = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _play(&"Idle")
			KEY_2: _play(&"Walk")
			KEY_3: _play(&"Run")
			KEY_4: _play(&"Jump")
			KEY_SPACE: charlie.animation_player.active = not charlie.animation_player.active
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(1.8, distance - 0.2)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(6.0, distance + 0.2)
		_update_camera()
	if event is InputEventMouseMotion and dragging:
		angle -= event.relative.x * 0.008
		elevation = clampf(elevation + event.relative.y * 0.005, -0.1, 0.9)
		_update_camera()

func _update_camera() -> void:
	var target := Vector3(0, 1.0, 0)
	camera.position = target + Vector3(sin(angle) * cos(elevation), sin(elevation), -cos(angle) * cos(elevation)) * distance
	camera.look_at(target)
