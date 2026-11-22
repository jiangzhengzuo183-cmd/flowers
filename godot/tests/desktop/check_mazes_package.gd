extends SceneTree
const Preferences := preload("res://modules/game_hud/game_settings.gd")
var checks := 0
var failures := 0
var shots: String
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	print("MAZE_PACKAGE_CHECK ",ok," ",label)
	if not ok:
		failures += 1
		push_error(label)
func loading() -> void:
	await frames(5)
	var deadline := Time.get_ticks_msec()+60000
	while has_meta(&"paper_loading_screen") and Time.get_ticks_msec()<deadline: await process_frame
	check(not has_meta(&"paper_loading_screen"),"loading screen finishes")
	await frames(5)
func shot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(shots.path_join(label+".png"))
func run() -> void:
	shots = OS.get_environment("FLOWERS_VERIFY_DIR")
	check(OS.has_feature("maze_desktop"),"maze-only export feature is active")
	var entry: String = ProjectSettings.get_setting_with_override("application/run/main_scene")
	check(entry=="res://scenes/main.tscn","default entry is the standalone picker")
	check(ProjectSettings.get_setting_with_override("application/config/icon")=="res://assets/app_icon/maze_flowers.png","maze logo is the active project icon")
	check(not FileAccess.file_exists("res://modules/visual_novel/data/continuation.json"),"story data is absent from the standalone maze package")
	Preferences.loaded = true
	Preferences.quality = 2
	Preferences.aspect = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.position = Vector2i(-2300,-1600)
	var app: Control = load(entry).instantiate()
	root.add_child(app)
	current_scene = app
	await loading()
	check(app.active_id=="maze_select" and app.active_scene.scene_file_path=="res://scenes/levels/MazeSelect.tscn","original selector and original layout are retained")
	await shot("maze-edition-selector")
	for number in [1,2,3]:
		Preferences.aspect = 1 if number==2 else 0
		app.active_scene.get_node("Picker/Choices/Maze%02d"%number).pressed.emit()
		await loading()
		var level: Control = app.active_scene
		check(is_instance_valid(level),"choice %d loads a level"%number)
		if not is_instance_valid(level): quit(1);return
		var view: SubViewportContainer = level.get_node("%ViewportContainer")
		check(view.get_global_rect().size.distance_to(root.get_visible_rect().size)<0.1,"Maze%d uses the full game canvas"%number)
		check(is_instance_valid(level.game_hud.hud),"Maze%d retains the unified HUD"%number)
		check(not level.game_hud.actor.controls_enabled,"Maze%d locks controls during intro"%number)
		var ready_deadline := Time.get_ticks_msec()+60000
		while not level.game_hud.actor.controls_enabled and Time.get_ticks_msec()<ready_deadline: await process_frame
		check(level.game_hud.actor.controls_enabled,"Maze%d releases controls after intro/countdown"%number)
		check(level.game_hud.clock.ready_to_play,"Maze%d starts its gameplay clock"%number)
		if number==3:
			check(level.race.current_mode=="Race","Maze03 defaults to competition")
			await shot("maze-edition-maze3")
			var old: Control = level
			level.game_hud._restart_level()
			await loading()
			level = app.active_scene
			check(is_instance_valid(level) and level!=old,"HUD restart replaces the level through the standalone host")
			check(level.race.current_mode=="Race","restart preserves competition mode")
		else: await shot("maze-edition-maze%d"%number)
		level.game_hud._exit_level()
		await loading()
		check(app.active_id=="maze_select" and app.active_scene.scene_file_path=="res://scenes/levels/MazeSelect.tscn","Maze%d returns to the original picker"%number)
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not paused,"return restores cursor and pause state")
		check(app.active_scene.get_node("Picker").get_global_rect().size.x>0.0,"original picker remains visible after return")
	app.queue_free()
	await frames(5)
	for child in root.get_children(): child.queue_free()
	await frames(5)
	print("MAZES_PACKAGE_RESULTS ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
