extends SceneTree
var errors:=0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func ck(ok: bool,text: String) -> void:
	print("CHECK ",ok," ",text)
	if not ok: errors+=1
func shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/story-handoff/"+name+".png"))
func loading() -> void:
	await frames(3)
	var limit:=Time.get_ticks_msec()+45000
	while has_meta(&"paper_loading_screen") and Time.get_ticks_msec()<limit: await process_frame
	ck(not has_meta(&"paper_loading_screen"),"loading screen completed")
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	var menu: Control=load("res://modules/main_menu/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await frames(250)
	menu._activate(0)
	await frames(30)
	await loading()
	await frames(10)
	var novel: Control=current_scene
	ck(novel.scene_file_path=="res://modules/visual_novel/VisualNovel.tscn","main menu opens updated visual novel")
	var day: Control=novel.story.bakery
	ck(day.runtime.hud.name==&"PaperToolbar" and is_instance_valid(day.runtime.settings_panel),"new paper UI is active")
	await shot("new-story-ui")
	day.runtime.reports()
	await frames(20)
	ck(is_instance_valid(day.report_book) and day.report_book.active,"new native progress-report book opens")
	await shot("new-report-book")
	if is_instance_valid(day.report_book): day.report_book._returned("closed")
	await frames(5)
	var bridge: Control=load("res://modules/visual_novel/scripts/story/story_race.gd").new()
	bridge.round_number=3
	novel.add_child(bridge)
	novel.story.hide()
	await loading()
	await frames(10)
	ck(is_instance_valid(bridge.maze) and bridge.maze.scene_file_path=="res://scenes/levels/Maze03.tscn","story adapter mounts the finished Maze03")
	ck(bridge.maze.get_script().resource_path=="res://modules/maze03_final/scene.gd" and bridge.maze.race.current_mode=="Race","finished maze visuals and race mode retained")
	await shot("new-story-maze03")
	print("NEW_STORY_SMOKE failures=",errors)
	quit(1 if errors else 0)
