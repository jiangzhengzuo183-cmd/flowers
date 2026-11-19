extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	var menu: Control = load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 250: await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	var logical: Vector2 = root.get_visible_rect().size
	event.position = menu.buttons[2].get_global_rect().get_center() * Vector2(root.size) / logical
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	print("QUIT_BUTTON_CLICKED active=",menu.transitioning)
	for i in 90: await process_frame
	push_error("Desktop button did not quit the application")
	quit(1)
