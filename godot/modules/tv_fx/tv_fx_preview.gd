extends Node3D

@onready var tv = $TVFX
@onready var camera: Camera3D = $Camera3D
var yaw := 0.25
var pitch := 0.1
var dragging := false
var status: Label
var effects_button: CheckButton
var pause_button: CheckButton

func _ready() -> void:
	_build_lighting()
	_build_ui()
	_update_camera()

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("f3efdf")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.75
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 0.65
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 125, 0)
	fill.light_energy = 0.25
	add_child(fill)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PreviewUI"
	add_child(canvas)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = preload("res://ui/game_theme.tres")
	canvas.add_child(ui)
	var heading := Label.new()
	heading.text = "失真的频道"
	heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heading.offset_left = -100
	heading.offset_right = 100
	heading.offset_top = 16
	heading.offset_bottom = 54
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	ui.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "电视机特效试验 · CRT / 漫画噪音"
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_left = -180
	subtitle.offset_right = 180
	subtitle.offset_top = 58
	subtitle.offset_bottom = 86
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	ui.add_child(subtitle)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -190
	panel.offset_bottom = -20
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var panel_style: StyleBox = ui.theme.get_stylebox("panel", "PanelContainer").duplicate()
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_content_margin(side, 12)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	column.add_child(row)
	effects_button = _toggle(row, "特效", true, func(value: bool): tv.set_effects_enabled(value))
	_toggle(row, "漫画符号", true, func(value: bool): tv.set_symbols_enabled(value))
	_toggle(row, "雪花", true, func(value: bool): tv.snow_enabled = value)
	_toggle(row, "扫描线", true, func(value: bool): tv.scanlines_enabled = value)
	_toggle(row, "闪烁", true, func(value: bool): tv.flicker_enabled = value)
	_toggle(row, "画面抖动", true, func(value: bool): tv.content_motion_enabled = value)
	_toggle(row, "蓝光", true, func(value: bool): tv.set_blue_glow_enabled(value))
	pause_button = _toggle(row, "暂停", false, func(value: bool): tv.animation_paused = value)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	var burst := Button.new()
	burst.text = "干扰爆发  B"
	burst.pressed.connect(func(): tv.trigger_burst())
	actions.add_child(burst)
	var reset := Button.new()
	reset.text = "正面视角  R"
	reset.pressed.connect(_front_view)
	actions.add_child(reset)
	var strength := Label.new()
	strength.text = "强度"
	actions.add_child(strength)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = tv.intensity
	slider.custom_minimum_size.x = 130
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(tv.set_intensity)
	actions.add_child(slider)
	status = Label.new()
	status.text = "拖动旋转 · 滚轮缩放 · 空格暂停 · 1 对比原模型"
	status.add_theme_font_size_override("font_size", 14)
	column.add_child(status)

func _toggle(parent: Node, text: String, initial: bool, action: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = text
	button.button_pressed = initial
	button.toggled.connect(action)
	parent.add_child(button)
	return button

func _front_view() -> void:
	yaw = 0.0
	pitch = 0.0
	camera.size = 161.0
	_update_camera()

func _update_camera() -> void:
	var target := Vector3(0, 41, 0)
	camera.position = target + Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)) * 240.0
	camera.look_at(target)

func _input(event: InputEvent) -> void:
	# Release even when the mouse is now over a UI control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_B: tv.trigger_burst()
			KEY_R: _front_view()
			KEY_1: effects_button.button_pressed = not effects_button.button_pressed
			KEY_SPACE: pause_button.button_pressed = not pause_button.button_pressed
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(115.0, camera.size - 7.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(230.0, camera.size + 7.0)
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.005, -0.5, 1.0)
		_update_camera()
