extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func click(button: Button) -> void:
	var at := button.get_global_rect().get_center()*Vector2(root.size)/root.get_visible_rect().size
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=at
	event.pressed=true
	Input.parse_input_event(event)
	await frames(1)
	event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=at
	event.pressed=false
	Input.parse_input_event(event)
	await frames(30)
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	var menu: Control=load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await frames(250)
	await click(menu.buttons[2])
	if not menu.exit_open or not menu.exit_note.active or not menu.exit_note.note.size.is_equal_approx(menu.exit_note.dimensions):
		push_error("Desktop button did not open a compact confirmation note")
		quit(1)
		return
	await click(menu.exit_note.cancel_button)
	if menu.exit_open:
		push_error("Cancel did not restore the menu")
		quit(1)
		return
	await click(menu.buttons[2])
	print("QUIT_CONFIRM_CLICKED")
	await click(menu.exit_note.confirm_button)
	await frames(90)
	push_error("Desktop button did not quit the application")
	quit(1)
