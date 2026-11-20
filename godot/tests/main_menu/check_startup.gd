extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var entry: Control = load(path).instantiate()
	root.add_child(entry)
	current_scene = entry
	for i in 300: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/main-menu/startup-fullscreen.png"))
	print("STARTUP ",path," mode=",root.mode," physical=",root.size," logical=",root.get_visible_rect().size)
	var ok: bool = path.ends_with("MainMenu.tscn") and root.mode == Window.MODE_FULLSCREEN and is_equal_approx(root.get_visible_rect().size.x/root.get_visible_rect().size.y,16.0/9.0)
	entry.queue_free()
	var cursor:=root.get_node_or_null("HandDrawnCursor")
	if cursor: cursor.queue_free()
	for i in 3: await process_frame
	quit(0 if ok else 1)
