extends SceneTree
var menu: Control
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i.ZERO
	root.size = Vector2i(1920, 1200)
	menu = load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 300: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/main-menu/quick-capture.png"))
	print("FIRST_MENU_CAPTURED ", root.size, " logical=", root.get_visible_rect().size)
	quit()
