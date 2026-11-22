extends SceneTree
const Preferences := preload("res://modules/game_hud/game_settings.gd")
const StoryPreferences := preload("res://modules/visual_novel/scripts/story/story_preferences.gd")
const Chapter := preload("res://modules/visual_novel/scripts/story/continuation_chapter.gd")
var failures := 0
var checks := 0
var screenshots: String
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for index in count: await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PACKAGE_CHECK ",ok," ",label)
	if not ok:
		failures += 1
		push_error(label)
func shot(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(screenshots.path_join(label+".png"))
func loading() -> void:
	await frames(5)
	var deadline := Time.get_ticks_msec()+60000
	while has_meta(&"paper_loading_screen") and Time.get_ticks_msec()<deadline: await process_frame
	check(not has_meta(&"paper_loading_screen"),"loading finishes")
	await frames(5)
func run() -> void:
	screenshots = OS.get_environment("FLOWERS_VERIFY_DIR")
	check(FileAccess.file_exists("res://project.binary") and not FileAccess.file_exists("res://project.godot"),"running the exported pack without the source project")
	check(ProjectSettings.get_setting("application/config/icon")=="res://assets/app_icon/flower_bouquet.png","bouquet application icon is configured")
	for path in ["res://modules/main_menu/assets/layout.json","res://modules/visual_novel/data/continuation.json","res://modules/visual_novel/data/chapter4.json","res://modules/visual_novel/data/report_book_catalog.json","res://modules/visual_novel/data/report_book_pages.json","res://data/levels/maze_01_greybox.json","res://data/levels/maze03_openings.json"]:
		check(FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path))!=null,"pack includes "+path)
	Preferences.loaded = true
	Preferences.aspect = 0
	Preferences.quality = 2
	StoryPreferences.shared().values.fullscreen = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.position = Vector2i(-2300,-1600)
	var menu: Control = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(250)
	check(menu.title_complete,"default main menu and title animation finish")
	await shot("packaged-main-menu")
	menu._activate(0)
	await frames(30)
	await loading()
	var novel: Control = current_scene
	check(novel.scene_file_path=="res://modules/visual_novel/VisualNovel.tscn","start opens the integrated visual novel")
	var day: Control = novel.story.bakery
	check(day.runtime.hud.name==&"PaperToolbar","updated story toolbar is present")
	day.runtime.reports()
	await frames(160)
	check(is_instance_valid(day.report_book) and day.report_book.active,"native progress report opens from the package")
	await shot("packaged-progress-report")
	current_scene = null
	novel.queue_free()
	await frames(8)
	var chapter: Control = Chapter.new()
	root.add_child(chapter)
	current_scene = chapter
	await frames(8)
	for number in [1,2,3]:
		for index in chapter.narrative.data.scenes.size():
			if chapter.narrative.data.scenes[index].get("maze",0)==number:
				chapter.narrative.enter_scene(index)
				break
		chapter.loaded_scene = chapter.narrative.scene_index
		chapter.narrative.phase = "maze"
		chapter._refresh()
		await loading()
		var bridge: Control = chapter.race.active_game
		var level: Control = bridge.maze
		var view: SubViewportContainer = level.get_node("%ViewportContainer")
		check(view.get_global_rect().size.distance_to(root.get_visible_rect().size)<0.1,"Maze%d fills the game canvas"%number)
		check(is_instance_valid(level.game_hud.hud),"Maze%d HUD is present"%number)
		if number==3: check(level.race.current_mode=="Race","finished Maze03 keeps competition mode")
		await frames(680)
		await shot("packaged-maze%d"%number)
		bridge.development_finish()
		await frames(8)
		check(not is_instance_valid(bridge),"Maze%d returns and releases its display"%number)
	for index in chapter.narrative.data.scenes.size():
		if not chapter.narrative.data.scenes[index].get("video",{}).is_empty():
			chapter.narrative.enter_scene(index)
			break
	chapter.loaded_scene = chapter.narrative.scene_index
	chapter.narrative.phase = "video"
	chapter._refresh()
	await frames(30)
	var video: Node = chapter.story_video
	check(is_instance_valid(video) and video.has_node("NativeStoryVideo"),"desktop video starts instead of being skipped")
	var native: Node = video.get_node("NativeStoryVideo")
	check(native.player.is_playing() and native.player.stream_position>0.1,"offline video decodes and advances")
	await shot("packaged-story-video")
	var end_deadline := Time.get_ticks_msec()+12000
	while is_instance_valid(video) and Time.get_ticks_msec()<end_deadline: await process_frame
	check(not is_instance_valid(video) and chapter.narrative.phase!="video" and chapter.stage.visible,"video ends and resumes the story")
	var skips := [0]
	var second_video: Node = load("res://modules/visual_novel/scripts/story/story_video.gd").new()
	root.add_child(second_video)
	second_video.completed.connect(func() -> void: skips[0]+=1)
	second_video.play({"title":"test"},{"mute":true})
	await frames(10)
	second_video.get_node("NativeStoryVideo").skip.pressed.emit()
	await frames(3)
	check(skips[0]==1 and not is_instance_valid(second_video),"skip completes exactly once and releases video")
	chapter.queue_free()
	await frames(6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in root.get_children(): child.queue_free()
	await frames(4)
	print("WINDOWS_PACKAGE_RESULTS ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
