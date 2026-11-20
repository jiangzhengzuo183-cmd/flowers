extends SceneTree
var host: Control
func _initialize() -> void:
	root.size=Vector2i(1600,900)
	_run.call_deferred()
func _run() -> void:
	host=load("res://scripts/story/continuation_chapter.gd").new()
	root.add_child(host)
	var actual: Array[String]=[]
	for i in host.narrative.data.scenes.size():
		if not str(host.narrative.data.scenes[i].id).begins_with("p4-"):continue
		host.narrative.enter_scene(i)
		host.loaded_scene=i
		if not host.narrative.scene().has("report"):continue
		host.narrative.finish_scene()
		while host.narrative.phase=="chapter_end":
			var id: String=host.narrative.scene().report
			host._refresh()
			for step in 12:
				await create_timer(0.03,true).timeout
				if is_instance_valid(host.report_book):break
			assert(is_instance_valid(host.report_book),"Late report did not open: "+id)
			var opened_book: Control=host.report_book
			var frame: Control=opened_book.frame
			for step in 70:
				if frame.phase=="reading":break
				await create_timer(0.03,true).timeout
			assert(frame.phase=="reading")
			actual.append(id)
			frame._action()
			assert(host.narrative.phase=="chapter_end","Story advanced before book closed")
			for step in 70:
				await create_timer(0.03,true).timeout
				if not is_instance_valid(opened_book) or host.report_book!=opened_book:break
			assert(not is_instance_valid(opened_book) or host.report_book!=opened_book,"Late book was not disposed")
			# April 6 immediately opens April 8 in the same authored node, so a new book may own pause.
			if not is_instance_valid(host.report_book):assert(not paused)
			if host.narrative.phase=="complete" or host.narrative.scene_index!=i:break
	assert(actual==["report9","report10-0406","report10-0408","report11","report12","report13","report14"])
	assert(host.narrative.phase=="complete")
	assert(host.end_screen.visible)
	print("PASS native main story: March 29 through April 28, all reports 9–14, separate April 6/8 unlocks, close-before-advance and final chapter screen")
	quit()
