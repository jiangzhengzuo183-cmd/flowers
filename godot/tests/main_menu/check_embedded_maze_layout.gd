extends SceneTree
const Chapter:=preload("res://modules/visual_novel/scripts/story/continuation_chapter.gd")
const GamePreferences:=preload("res://modules/game_hud/game_settings.gd")
const StoryPreferences:=preload("res://modules/visual_novel/scripts/story/story_preferences.gd")
var errors:=0
var checks:=0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,text: String) -> void:
	checks+=1
	print("LAYOUT_CHECK ",ok," ",text)
	if not ok: errors+=1;push_error(text)
func wait_loading() -> void:
	await frames(4)
	var deadline:=Time.get_ticks_msec()+60000
	while has_meta(&"paper_loading_screen") and Time.get_ticks_msec()<deadline: await process_frame
	check(not has_meta(&"paper_loading_screen"),"loading completes")
	await frames(6)
func run() -> void:
	GamePreferences.loaded=true
	GamePreferences.quality=2
	StoryPreferences.shared().values.fullscreen=false
	for aspect in 2:
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1920,1080 if aspect==0 else 1200)
		root.position=Vector2i(-2300,-1700)
		root.content_scale_size=Vector2i(1600,900)
		root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
		StoryPreferences.shared().values.aspect=aspect*2
		GamePreferences.aspect=aspect
		var chapter: Control=Chapter.new()
		root.add_child(chapter)
		current_scene=chapter
		await frames(5)
		var story_size:=root.content_scale_size
		for number in [1,2,3]:
			for index in chapter.narrative.data.scenes.size():
				if chapter.narrative.data.scenes[index].get("maze",0)==number:
					chapter.narrative.enter_scene(index)
					break
			chapter.loaded_scene=chapter.narrative.scene_index
			chapter.narrative.phase="maze"
			chapter._refresh()
			await wait_loading()
			var gateway: Control=chapter.race
			var bridge: Control=gateway.active_game
			var level: Control=bridge.maze
			var view: SubViewportContainer=level.get_node("%ViewportContainer")
			var expected:=root.get_visible_rect()
			var rect:=view.get_global_rect()
			print("EMBEDDED_RECT aspect=",aspect," maze=",number," stage=",chapter.stage.get_global_rect()," view=",rect," root=",expected)
			check(rect.position.distance_to(expected.position)<0.1 and rect.size.distance_to(expected.size)<0.1,"embedded Maze%d fills the complete logical viewport, aspect %d"%[number,aspect])
			var hud: Control=level.game_hud.hud.get_node("HUDRoot")
			check(hud.get_global_rect().size.distance_to(view.size)<0.1,"3D view and HUD have the same canvas")
			check((view.get_child(0) as SubViewport).size==Vector2i(expected.size),"3D render resolution follows the full view")
			if is_instance_valid(level.game_hud.race): check(level.game_hud.race.current_mode=="Race","Maze03 keeps race mode")
			if number==1 and aspect==1:
				await frames(700)
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/story-handoff/embedded-maze01-fullscreen.png"))
			if number==3:
				var old: Control=level
				level.game_hud._restart_level()
				await wait_loading()
				level=bridge.maze
				view=level.get_node("%ViewportContainer")
				check(level!=old and view.get_global_rect().size.distance_to(root.get_visible_rect().size)<0.1,"restart replaces Maze03 and keeps the full canvas")
				if aspect==1:
					RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../.verification/story-handoff/embedded-maze03-fullscreen.png"))
			bridge.development_finish()
			await frames(8)
			check(root.content_scale_size==story_size,"return restores the story canvas")
			check(not is_instance_valid(bridge),"maze display layer is released on return")
			check(not chapter.narrative.maze_results[str(number)].score_valid,"layout rehearsal does not create a measured score")
		chapter.queue_free()
		await frames(5)
	for child in root.get_children(): child.queue_free()
	await frames(5)
	print("EMBEDDED_LAYOUT_RESULTS ",checks," checks; failures=",errors)
	quit(1 if errors else 0)
