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
		host.narrative.enter_scene(i)
		host.loaded_scene=i
		if not host.narrative.scene().has("report"):continue
		host.narrative.finish_scene()
		while host.narrative.phase=="chapter_end":
			var id: String=host.narrative.scene().report
			host._refresh()
			await create_timer(0.06,true).timeout
			assert(is_instance_valid(host.report_book),"Report did not open: "+id)
			var opened_book: Control=host.report_book
			var frame: Control=opened_book.frame
			for step in 80:
				if frame.phase=="reading":break
				await create_timer(0.03,true).timeout
			assert(frame.phase=="reading")
			actual.append(id)
			frame._action()
			assert(host.narrative.phase=="chapter_end","Story advanced before book closed")
			frame._action() # Rapid repeated Continue must be ignored during closing.
			for step in 80:
				await create_timer(0.03,true).timeout
				if not is_instance_valid(opened_book) or host.report_book!=opened_book:break
			assert(not is_instance_valid(opened_book) or host.report_book!=opened_book)
			if not is_instance_valid(host.report_book):assert(not paused)
			if id=="report9":
				assert("report9" in host.narrative.unlocked_reports)
				assert("report10-0406" not in host.narrative.unlocked_reports)
				assert(actual==["report2-0304","report2-0306-maze","report2-0306-decision","report2-0308","report3","report4","report5","report6-0324","report6-0325","report7","report8-0330","report8-0330-volume","report8-0331","report9"])
				print("PASS main Godot report triggers through report 9, shared-page unlock order, rapid Continue, close-before-advance, no report 10 unlock")
				quit();return
			if host.narrative.scene_index!=i:break
	push_error("Report 9 was not reached");quit(1)
